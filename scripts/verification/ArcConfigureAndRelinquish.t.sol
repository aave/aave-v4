// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4DeployArc} from 'scripts/deploy/AaveV4DeployArc.s.sol';
import {ArcConfigInputs} from 'scripts/config/ArcConfigInputs.sol';
import {ArcConfiguration} from 'scripts/config/ArcConfiguration.sol';
import {ArcParameters} from 'scripts/config/ArcParameters.sol';
import {ArcConfigEngine} from 'scripts/config/ArcConfigEngine.sol';
import {ArcHandover} from 'scripts/config/ArcHandover.sol';
import {ArcVerification} from 'scripts/config/ArcVerification.sol';

import {AaveV4DeployOrchestration} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';
import {BytecodeHelper} from 'src/deployments/utils/libraries/BytecodeHelper.sol';
import {MetadataLogger} from 'src/deployments/utils/MetadataLogger.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {DeployConstants} from 'src/deployments/utils/libraries/DeployConstants.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {Ownable2Step} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';

import {Create2TestHelper} from 'tests/utils/Create2TestHelper.sol';
import {MockPriceFeed} from 'tests/helpers/mocks/MockPriceFeed.sol';
import {TestnetERC20} from 'tests/helpers/mocks/TestnetERC20.sol';

import {Test} from 'forge-std/Test.sol';

/// @title ArcConfigureAndRelinquishTest
/// @author Aave Labs
/// @notice Runs the whole Arc operator path on a local deployment: deploy from scripts/config/arc.json with
///         roles deferred, configure with the placeholder parameters, halt, then hand over.
contract ArcConfigureAndRelinquishTest is Test, Create2TestHelper, AaveV4DeployArc {
  /// @dev Matches `DeployConstants.ORACLE_DECIMALS`, which `AaveOracle` enforces on price sources.
  uint8 internal constant PRICE_FEED_DECIMALS = DeployConstants.ORACLE_DECIMALS;
  /// @dev USDC and EURC are both 6 decimals on Arc.
  uint8 internal constant STABLE_DECIMALS = 6;

  address internal _deployer = makeAddr('deployer');

  ArcConfigInputs.Market internal _market;
  ArcConfigInputs.Handover internal _targets;
  /// @dev The launch set: USDC and EURC, the two assets listed on both spokes.
  ArcConfigInputs.AssetInput[] internal _assets;

  function setUp() public {
    _etchCreate2Factory();

    _pushAsset(ArcParameters.Asset.USDC);
    _pushAsset(ArcParameters.Asset.EURC);

    InputUtils.FullDeployInputs memory inputs = _loadWarningsAndSanitizeInputs(
      _getDeployInputs(),
      _deployer
    );

    vm.startPrank(_deployer);
    OrchestrationReports.FullDeploymentReport memory report = AaveV4DeployOrchestration
      .deployAaveV4({
        logger: new MetadataLogger(''),
        deployer: _deployer,
        deployInputs: inputs,
        hubBytecode: BytecodeHelper.getHubBytecode(),
        spokeBytecode: BytecodeHelper.getSpokeBytecode()
      });
    vm.stopPrank();

    // the config engine is deployed on its own, at a deterministic address
    ArcConfigEngine.deploy();

    _market = _toMarket(report);
    _targets = ArcConfigInputs.readHandover();
  }

  /// @notice The deploy leaves the deployer as AccessManager admin and nothing else granted.
  function test_deployDefersAllRoles() public view {
    _assertHasRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, _deployer, true);

    // the selectors are wired, but no address holds the roles that reach them yet
    _assertHasRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, _deployer, false);
    _assertHasRole(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, _deployer, false);
    _assertHasRole(Roles.HUB_CONFIGURATOR_ROLE, _market.hubConfigurator, false);
    _assertHasRole(Roles.SPOKE_CONFIGURATOR_ROLE, _market.spokeConfigurator, false);
    _assertHasRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, _targets.hubConfiguratorAdmin, false);
  }

  /// @notice Without the self-granted roles the deployer cannot configure anything.
  function test_configureRevertsWithoutRoles() public {
    vm.prank(_deployer);
    vm.expectRevert();
    IHubConfigurator(_market.hubConfigurator).haltAsset(_market.hub, 0);
  }

  /// @notice The AccessManager applies no delay, so the self-granted roles take effect at once.
  function test_noAccessManagerDelays() public view {
    ArcConfiguration.requireNoDelays(_market);
  }

  /// @notice Configuration lists every asset in the launch set and leaves each halted on the Hub.
  function test_configureListsAndHalts() public {
    _configure();

    assertEq(IHub(_market.hub).getAssetCount(), _assets.length, 'asset count');

    for (uint256 i; i < _assets.length; ++i) {
      uint256 assetId = IHubBase(_market.hub).getAssetId(_assets[i].underlying);

      // the two borrowing spokes, plus the treasury spoke registered as fee receiver by addAsset,
      // plus the asset's tokenization spoke
      uint256 spokeCount = IHub(_market.hub).getSpokeCount(assetId);
      assertEq(spokeCount, _market.spokes.length + 2, 'spoke count');

      for (uint256 j; j < spokeCount; ++j) {
        address spoke = IHub(_market.hub).getSpokeAddress(assetId, j);
        assertTrue(IHub(_market.hub).getSpokeConfig(assetId, spoke).halted, 'spoke halted');
      }
    }
  }

  /// @notice Each reserve lands with the parameters its own asset and spoke pair specifies, so the
  ///         same asset carries a different collateral factor on Main than on Forex.
  function test_configureAppliesPerPairParameters() public {
    _configure();

    for (uint256 i; i < _assets.length; ++i) {
      uint256 assetId = IHubBase(_market.hub).getAssetId(_assets[i].underlying);

      for (uint256 s; s < _market.spokes.length; ++s) {
        ArcParameters.ReserveParams memory expected = ArcParameters.reserveParams(
          _assets[i].key,
          ArcParameters.Spoke(s)
        );
        if (!expected.listed) continue;

        ISpoke spoke = ISpoke(_market.spokes[s]);
        uint256 reserveId = spoke.getReserveId(_market.hub, assetId);

        ISpoke.DynamicReserveConfig memory dynamicConfig = spoke.getDynamicReserveConfig(
          reserveId,
          0
        );
        assertEq(dynamicConfig.collateralFactor, expected.collateralFactor, 'collateral factor');
        assertEq(dynamicConfig.maxLiquidationBonus, expected.maxLiquidationBonus, 'max bonus');
        assertEq(dynamicConfig.liquidationFee, expected.liquidationFee, 'liquidation fee');
        assertEq(spoke.getReserveConfig(reserveId).borrowable, expected.borrowable, 'borrowable');

        IHub.SpokeConfig memory spokeConfig = IHub(_market.hub).getSpokeConfig(
          assetId,
          _market.spokes[s]
        );
        assertEq(spokeConfig.addCap, expected.addCap, 'add cap');
        assertEq(spokeConfig.drawCap, expected.drawCap, 'draw cap');
      }
    }
  }

  /// @notice Each spoke gets its own dynamic liquidation bonus configuration, set once.
  function test_configureAppliesLiquidationConfigPerSpoke() public {
    _configure();

    for (uint256 s; s < _market.spokes.length; ++s) {
      ISpoke.LiquidationConfig memory expected = ArcParameters.liquidationConfig(
        ArcParameters.Spoke(s)
      );
      ISpoke.LiquidationConfig memory actual = ISpoke(_market.spokes[s]).getLiquidationConfig();

      assertEq(actual.targetHealthFactor, expected.targetHealthFactor, 'target health factor');
      assertEq(
        actual.healthFactorForMaxBonus,
        expected.healthFactorForMaxBonus,
        'health factor for max bonus'
      );
      assertEq(
        actual.liquidationBonusFactor,
        expected.liquidationBonusFactor,
        'liquidation bonus factor'
      );
    }
  }

  /// @notice Each listed asset gets a tokenization spoke, registered supply-only at its published
  ///         add cap, with its ProxyAdmin owned by the Security Council rather than the deployer.
  function test_configureDeploysTokenizationSpokes() public {
    _configure();

    for (uint256 i; i < _assets.length; ++i) {
      uint256 assetId = IHubBase(_market.hub).getAssetId(_assets[i].underlying);
      address tokenizationSpoke = _tokenizationSpoke(assetId);
      assertTrue(tokenizationSpoke != address(0), 'tokenization spoke deployed');

      assertEq(
        Ownable(ArcConfigInputs.proxyAdmin(tokenizationSpoke)).owner(),
        _targets.proxyAdminOwner,
        'tokenization spoke proxy admin owner'
      );
      assertNotEq(
        Ownable(ArcConfigInputs.proxyAdmin(tokenizationSpoke)).owner(),
        _deployer,
        'proxy admin owner is not the deployer'
      );

      ArcParameters.AssetParams memory params = ArcParameters.assetParams(_assets[i].key);
      IHub.SpokeConfig memory config = IHub(_market.hub).getSpokeConfig(assetId, tokenizationSpoke);
      assertEq(config.addCap, params.tokenizationAddCap, 'tokenization add cap');
      assertEq(config.drawCap, 0, 'tokenization draw cap is supply-only');

      // the spoke is wired to the asset it tokenizes
      assertEq(ITokenizationSpoke(tokenizationSpoke).hub(), _market.hub, 'tokenization hub');
      assertEq(
        ITokenizationSpoke(tokenizationSpoke).asset(),
        _assets[i].underlying,
        'tokenization underlying'
      );
      string memory assetSymbol = ITokenizationSpoke(_assets[i].underlying).symbol();
      assertEq(
        ITokenizationSpoke(tokenizationSpoke).symbol(),
        ArcParameters.tokenizationShareSymbol(assetSymbol),
        'share symbol'
      );
      assertEq(
        ITokenizationSpoke(tokenizationSpoke).name(),
        ArcParameters.tokenizationShareName(assetSymbol),
        'share name'
      );
    }
  }

  /// @notice Configuration rejects an underlying whose decimals do not match the asset, which is
  ///         what pointing at the wrong live contract looks like.
  function test_configureRejectsWrongDecimals() public {
    uint8 wrongDecimals = STABLE_DECIMALS + 1;

    ArcConfigInputs.AssetInput[] memory assets = new ArcConfigInputs.AssetInput[](1);
    assets[0] = ArcConfigInputs.AssetInput({
      key: ArcParameters.Asset.USDC,
      underlying: address(new TestnetERC20('USDC', 'USDC', wrongDecimals)),
      priceSource: address(new MockPriceFeed(PRICE_FEED_DECIMALS, 'USDC / USD', 1e8))
    });

    vm.expectRevert(
      abi.encodeWithSelector(
        ArcConfiguration.UnexpectedDecimals.selector,
        'USDC',
        wrongDecimals,
        STABLE_DECIMALS
      )
    );
    this.externalConfigure(assets);
  }

  /// @dev External entry point so the test can expect a revert from configuration.
  function externalConfigure(ArcConfigInputs.AssetInput[] memory assets) external {
    vm.startPrank(_deployer);
    ArcConfiguration.configure(_market, _deployer, assets, _targets.proxyAdminOwner);
    vm.stopPrank();
  }

  /// @notice After the full flow the standalone verification passes: deployment, handover and every
  ///         configured parameter.
  function test_verificationPassesAfterFullFlow() public {
    _configure();

    vm.startPrank(_deployer);
    ArcHandover.relinquish(_market, _targets, _deployer);
    vm.stopPrank();

    _councilAcceptsOwnership();

    ArcVerification.verify(_market, _targets, _assets, _deployer);
  }

  /// @notice Configuration wires every manager and gateway to every spoke, both halves, leaving the
  ///         Council nothing to do but accept ownership.
  function test_configureWiresPositionManagersBothHalves() public {
    _configure();

    address[4] memory managers = _managers();
    for (uint256 i; i < managers.length; ++i) {
      assertTrue(managers[i] != address(0), 'manager deployed');
      for (uint256 j; j < _market.spokes.length; ++j) {
        assertTrue(
          ISpoke(_market.spokes[j]).isPositionManagerActive(managers[i]),
          'manager active on spoke'
        );
        assertTrue(
          IPositionManagerBase(managers[i]).isSpokeRegistered(_market.spokes[j]),
          'spoke registered on manager'
        );
      }
    }
  }

  /// @notice The handover offers manager ownership to the Council and leaves it pending, so the
  ///         Council's only outstanding action is `acceptOwnership`.
  function test_relinquishLeavesManagerOwnershipPending() public {
    _configure();

    vm.startPrank(_deployer);
    ArcHandover.relinquish(_market, _targets, _deployer);
    vm.stopPrank();

    address[4] memory managers = _managers();
    for (uint256 i; i < managers.length; ++i) {
      assertEq(Ownable(managers[i]).owner(), _deployer, 'still deployer until accepted');
      assertEq(
        Ownable2Step(managers[i]).pendingOwner(),
        _targets.positionManagerOwner,
        'Council is pending owner'
      );
    }

    _councilAcceptsOwnership();

    for (uint256 i; i < managers.length; ++i) {
      assertEq(Ownable(managers[i]).owner(), _targets.positionManagerOwner, 'Council owns');
      assertEq(Ownable2Step(managers[i]).pendingOwner(), address(0), 'nothing left pending');
    }
  }

  /// @notice Verification fails while the Council has not accepted, so the step cannot be skipped.
  function test_verificationFailsUntilCouncilAcceptsOwnership() public {
    _configure();

    vm.startPrank(_deployer);
    ArcHandover.relinquish(_market, _targets, _deployer);
    vm.stopPrank();

    vm.expectRevert(
      abi.encodeWithSelector(
        ArcVerification.ManagerOwnershipNotAccepted.selector,
        _market.giverPositionManager,
        _deployer,
        _targets.positionManagerOwner
      )
    );
    this.externalVerifyAll();
  }

  /// @notice The verification fails if configuration never ran, so it cannot pass vacuously on an
  ///         unconfigured market.
  function test_verificationFailsWithoutConfiguration() public {
    vm.startPrank(_deployer);
    ArcHandover.relinquish(_market, _targets, _deployer);
    vm.stopPrank();

    vm.expectRevert();
    this.externalVerifyAll();
  }

  /// @notice The verification catches a parameter that drifts from `ArcParameters` after the fact.
  function test_verificationCatchesDriftedParameter() public {
    _configure();

    uint256 assetId = IHubBase(_market.hub).getAssetId(_assets[0].underlying);
    ArcParameters.ReserveParams memory expected = ArcParameters.reserveParams(
      _assets[0].key,
      ArcParameters.Spoke.MAIN
    );

    vm.startPrank(_deployer);
    ArcHandover.relinquish(_market, _targets, _deployer);
    vm.stopPrank();

    _councilAcceptsOwnership();

    // the hub admin holds role 101 once the handover has run, so it can move caps on the Hub
    vm.prank(_targets.hubAdmin);
    IHub(_market.hub).updateSpokeConfig(
      assetId,
      _market.spokes[0],
      IHub.SpokeConfig({
        addCap: expected.addCap - 1,
        drawCap: expected.drawCap,
        riskPremiumThreshold: 0,
        active: true,
        halted: true
      })
    );

    vm.expectRevert(
      abi.encodeWithSelector(
        ArcVerification.UnexpectedUint.selector,
        string.concat(ArcParameters.symbol(_assets[0].key), ' addCap'),
        uint256(expected.addCap - 1),
        uint256(expected.addCap)
      )
    );
    this.externalVerifyAll();
  }

  /// @dev External entry point so the test can expect a revert from the full verification.
  function externalVerifyAll() external view {
    ArcVerification.verify(_market, _targets, _assets, _deployer);
  }

  /// @notice The handover verification catches a tokenization spoke proxy left with the deployer,
  ///         whatever route deployed it.
  function test_verifyCatchesDeployerOwnedTokenizationProxy() public {
    vm.startPrank(_deployer);
    ArcConfiguration.configure(_market, _deployer, _assets, _deployer);
    ArcHandover.relinquish(_market, _targets, _deployer);
    vm.stopPrank();

    uint256 assetId = IHubBase(_market.hub).getAssetId(_assets[0].underlying);
    address proxyAdmin = ArcConfigInputs.proxyAdmin(_tokenizationSpoke(assetId));

    vm.expectRevert(
      abi.encodeWithSelector(ArcHandover.UnexpectedOwner.selector, proxyAdmin, _deployer)
    );
    this.externalVerify();
  }

  /// @dev External entry point so the test can expect a revert from the verification.
  function externalVerify() external view {
    ArcHandover.verify(_market, _targets, _deployer);
  }

  /// @notice The halt reaches the tokenization spokes too, which only works because they are
  ///         registered on the Hub before `haltAsset` runs.
  function test_tokenizationSpokesAreHalted() public {
    _configure();

    for (uint256 i; i < _assets.length; ++i) {
      uint256 assetId = IHubBase(_market.hub).getAssetId(_assets[i].underlying);
      address tokenizationSpoke = _tokenizationSpoke(assetId);
      assertTrue(
        IHub(_market.hub).getSpokeConfig(assetId, tokenizationSpoke).halted,
        'tokenization spoke halted'
      );
    }
  }

  /// @notice An asset left out of the launch set is not listed, so a market can go live without the
  ///         assets whose token or price feed does not exist yet.
  function test_assetsOutsideLaunchSetAreNotListed() public {
    _configure();

    assertEq(IHub(_market.hub).getAssetCount(), 2, 'only the launch set is listed');
    assertTrue(
      ArcParameters.reserveParams(ArcParameters.Asset.WETH, ArcParameters.Spoke.MAIN).listed,
      'wETH parameters are still written'
    );
  }

  /// @notice The handover moves every role and ownership off the deployer.
  function test_relinquishLeavesDeployerWithNothing() public {
    _configure();

    vm.startPrank(_deployer);
    ArcHandover.relinquish(_market, _targets, _deployer);
    vm.stopPrank();

    // reverts if anything is left behind
    ArcHandover.verify(_market, _targets, _deployer);

    _assertHasRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, _targets.accessManagerAdmin, true);
    _assertHasRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, _targets.hubConfiguratorAdmin, true);
    _assertHasRole(
      Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      _targets.spokeConfiguratorAdmin,
      true
    );
  }

  /// @notice After the handover the deployer can no longer configure or grant.
  function test_relinquishRevokesDeployerPowers() public {
    _configure();

    vm.startPrank(_deployer);
    ArcHandover.relinquish(_market, _targets, _deployer);

    vm.expectRevert();
    IHubConfigurator(_market.hubConfigurator).haltAsset(_market.hub, 0);

    vm.expectRevert();
    IAccessManager(_market.accessManager).grantRole(
      Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      _deployer,
      0
    );
    vm.stopPrank();
  }

  /// @notice The deployer owns nothing at any point: every ownership is the Council's from deploy.
  function test_deployerNeverHoldsOwnership() public {
    _assertCouncilOwnsEverything();
    _configure();
    _assertCouncilOwnsEverything();

    vm.startPrank(_deployer);
    ArcHandover.relinquish(_market, _targets, _deployer);
    vm.stopPrank();

    _assertCouncilOwnsEverything();
    // no pending transfer left behind on the Ownable2Step treasury spoke
    assertEq(Ownable2Step(_market.treasurySpoke).pendingOwner(), address(0), 'pending owner');
  }

  function _assertCouncilOwnsEverything() internal view {
    assertEq(
      Ownable(ArcConfigInputs.proxyAdmin(_market.hub)).owner(),
      _targets.proxyAdminOwner,
      'hub proxy admin'
    );
    for (uint256 i; i < _market.spokes.length; ++i) {
      assertEq(
        Ownable(ArcConfigInputs.proxyAdmin(_market.spokes[i])).owner(),
        _targets.proxyAdminOwner,
        'spoke proxy admin'
      );
    }
    assertEq(
      Ownable(ArcConfigInputs.proxyAdmin(_market.treasurySpoke)).owner(),
      _targets.proxyAdminOwner,
      'treasury proxy admin'
    );
    assertEq(
      Ownable(_market.treasurySpoke).owner(),
      _targets.treasurySpokeOwner,
      'treasury spoke owner'
    );
    // the managers are deliberately deployer-owned until the Council accepts, so they are checked
    // by test_relinquishLeavesManagerOwnershipPending rather than here
  }

  function _configure() internal {
    vm.startPrank(_deployer);
    ArcConfiguration.configure(_market, _deployer, _assets, _targets.proxyAdminOwner);
    vm.stopPrank();
  }

  /// @dev The whole of what the Council has to do: accept the ownership the handover offered it.
  function _councilAcceptsOwnership() internal {
    vm.prank(_targets.gatewayOwner);
    Ownable2Step(_market.signatureGateway).acceptOwnership();

    address[3] memory managers = [
      _market.giverPositionManager,
      _market.takerPositionManager,
      _market.configPositionManager
    ];
    for (uint256 i; i < managers.length; ++i) {
      vm.prank(_targets.positionManagerOwner);
      Ownable2Step(managers[i]).acceptOwnership();
    }
  }

  function _managers() internal view returns (address[4] memory) {
    return
      [
        _market.giverPositionManager,
        _market.takerPositionManager,
        _market.configPositionManager,
        _market.signatureGateway
      ];
  }

  /// @dev The tokenization spoke of an asset is the spoke registered for it that is neither a
  ///      borrowing spoke nor the treasury spoke.
  function _tokenizationSpoke(uint256 assetId) internal view returns (address) {
    uint256 spokeCount = IHub(_market.hub).getSpokeCount(assetId);

    for (uint256 i; i < spokeCount; ++i) {
      address spoke = IHub(_market.hub).getSpokeAddress(assetId, i);
      if (spoke == _market.treasurySpoke) continue;
      if (spoke == _market.spokes[0] || spoke == _market.spokes[1]) continue;
      return spoke;
    }
    return address(0);
  }

  /// @dev Stands in a real ERC20 and an 8-decimal feed for an asset, which the configuration path
  ///      requires: the Hub reads `decimals()` and the oracle reads a price.
  function _pushAsset(ArcParameters.Asset key) internal {
    string memory name = ArcParameters.symbol(key);
    _assets.push(
      ArcConfigInputs.AssetInput({
        key: key,
        underlying: address(new TestnetERC20(name, name, STABLE_DECIMALS)),
        priceSource: address(
          new MockPriceFeed(PRICE_FEED_DECIMALS, string.concat(name, ' / USD'), 1e8)
        )
      })
    );
  }

  function _toMarket(
    OrchestrationReports.FullDeploymentReport memory report
  ) internal pure returns (ArcConfigInputs.Market memory market) {
    market.accessManager = report.authorityBatchReport.accessManager;
    market.hubConfigurator = report.configuratorBatchReport.hubConfigurator;
    market.spokeConfigurator = report.configuratorBatchReport.spokeConfigurator;
    market.treasurySpoke = report.treasurySpokeBatchReport.treasurySpoke;
    market.hub = report.hubInstanceBatchReports[0].report.hubProxy;
    market.irStrategy = report.hubInstanceBatchReports[0].report.irStrategy;

    market.spokes = new address[](report.spokeInstanceBatchReports.length);
    for (uint256 i; i < report.spokeInstanceBatchReports.length; ++i) {
      market.spokes[i] = report.spokeInstanceBatchReports[i].report.spokeProxy;
    }

    market.signatureGateway = report.gatewaysBatchReport.signatureGateway;
    market.giverPositionManager = report.positionManagerBatchReport.giverPositionManager;
    market.takerPositionManager = report.positionManagerBatchReport.takerPositionManager;
    market.configPositionManager = report.positionManagerBatchReport.configPositionManager;
  }

  function _assertHasRole(uint64 role, address account, bool expected) internal view {
    (bool isMember, ) = IAccessManager(_market.accessManager).hasRole(role, account);
    assertEq(isMember, expected, string.concat('role ', vm.toString(uint256(role))));
  }

  /// @dev Tests are non-interactive.
  function _executeUserPrompt() internal override {}
}
