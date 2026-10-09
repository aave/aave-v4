// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4DeploySentora} from 'scripts/deploy/AaveV4DeploySentora.s.sol';
import {AaveV4SentoraConfigInputs} from 'scripts/config/AaveV4SentoraConfigInputs.sol';
import {AaveV4SentoraConfiguration} from 'scripts/config/AaveV4SentoraConfiguration.sol';
import {AaveV4SentoraHandover} from 'scripts/config/AaveV4SentoraHandover.sol';
import {AaveV4SentoraParameters} from 'scripts/config/AaveV4SentoraParameters.sol';
import {AaveV4SentoraRoles} from 'scripts/config/AaveV4SentoraRoles.sol';

import {AaveV4DeployOrchestration} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';
import {BytecodeHelper} from 'src/deployments/utils/libraries/BytecodeHelper.sol';
import {MetadataLogger} from 'src/deployments/utils/MetadataLogger.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {DeployConstants} from 'src/deployments/utils/libraries/DeployConstants.sol';
import {IAccessManagerEnumerable} from 'src/access/interfaces/IAccessManagerEnumerable.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {IERC20Metadata} from 'src/dependencies/openzeppelin/IERC20Metadata.sol';
import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {Ownable2Step} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';

import {Create2TestHelper} from 'tests/utils/Create2TestHelper.sol';

import {Test} from 'forge-std/Test.sol';

/// @title AaveV4SentoraConfigureAndRelinquishTest
/// @author Aave Labs
/// @notice Runs the whole Sentora operator path on a local deployment: deploy from
///         config/sentora.json with roles deferred, list a launch set, halt, then hand over to the
///         Security Council, the Sentora Executor, the Risk Steward and the Emergency Operator.
/// @dev The listing paths are driven by a local fixture of one collateral asset, listed on two of
///      the three Spokes, and one borrowable, tokenized asset listed on all three, with mock token
///      and feed code etched at their addresses. `test_configureAndRelinquishWithConfigFile` runs
///      the real config file end to end.
contract AaveV4SentoraConfigureAndRelinquishTest is Test, Create2TestHelper, AaveV4DeploySentora {
  /// @dev Matches `DeployConstants.ORACLE_DECIMALS`, which `AaveOracle` enforces on price sources.
  uint8 internal constant PRICE_FEED_DECIMALS = DeployConstants.ORACLE_DECIMALS;
  uint256 internal constant MOCK_PRICE = 1e8;
  /// @dev Decimals of the mock tokens etched for the config file's assets. The Hub reads them off
  ///      the token, so they only need to be valid.
  uint8 internal constant MOCK_TOKEN_DECIMALS = 18;

  address internal _deployer = makeAddr('deployer');

  AaveV4SentoraConfigInputs.Market internal _market;
  AaveV4SentoraConfigInputs.Handover internal _targets;
  AaveV4SentoraConfigInputs.Asset[] internal _assets;
  AaveV4SentoraConfigInputs.Reserve[] internal _reserves;

  /// @dev The fixture's collateral asset is not listed on this Spoke.
  uint256 internal constant SPOKE_WITHOUT_COLLATERAL = 1;

  function setUp() public {
    _etchCreate2Factory();

    _assets.push(_fixtureAsset('COLL', 18, false));
    _assets.push(_fixtureAsset('USDX', 6, true));

    _reserves.push(_fixtureReserve(0, 0));
    _reserves.push(_fixtureReserve(2, 0));
    _reserves.push(_fixtureReserve(0, 1));
    _reserves.push(_fixtureReserve(1, 1));
    _reserves.push(_fixtureReserve(2, 1));

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

    _market = _toMarket(report);
    _targets = AaveV4SentoraConfigInputs.readHandover();
  }

  /// @notice The deploy leaves the deployer as AccessManager admin and nothing else granted.
  function test_deployDefersAllRoles() public view {
    _assertHasRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, _deployer, true);

    // the selectors are wired, but no address holds the roles that reach them yet
    _assertHasRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, _deployer, false);
    _assertHasRole(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, _deployer, false);
    _assertHasRole(Roles.HUB_CONFIGURATOR_ROLE, _market.hubConfigurator, false);
    _assertHasRole(Roles.SPOKE_CONFIGURATOR_ROLE, _market.spokeConfigurator, false);
    _assertHasRole(AaveV4SentoraRoles.SENTORA_RISK_ROLE, _targets.riskSteward, false);
    _assertHasRole(AaveV4SentoraRoles.SENTORA_EMERGENCY_ROLE, _targets.emergencyOperator, false);
  }

  /// @notice Without the self-granted roles the deployer cannot configure anything.
  function test_configureRevertsWithoutRoles() public {
    vm.prank(_deployer);
    vm.expectRevert();
    IHubConfigurator(_market.hubConfigurator).haltAsset(_market.hub, 0);
  }

  /// @notice The AccessManager applies no delay, so the self-granted roles take effect at once.
  function test_noAccessManagerDelays() public view {
    AaveV4SentoraConfiguration.requireNoDelays(_market);
  }

  /// @notice Configuration lists every asset on the Hub and each reserve on its Spoke, and leaves
  ///         every asset halted on every Spoke.
  function test_configureListsAndHalts() public {
    uint256[] memory assetIds = _configure();

    assertEq(assetIds.length, _assets.length, 'asset id count');
    assertEq(IHub(_market.hub).getAssetCount(), _assets.length, 'asset count');

    for (uint256 i; i < _assets.length; ++i) {
      assertEq(IHubBase(_market.hub).getAssetId(_assets[i].underlying), assetIds[i], 'asset id');

      // the treasury spoke is registered as the fee receiver on top of the configured spokes, and
      // the tokenized asset gets a tokenization spoke as well
      uint256 expectedSpokes = _reserveCount(i) + (_assets[i].tokenize ? 2 : 1);
      uint256 spokeCount = IHub(_market.hub).getSpokeCount(assetIds[i]);
      assertEq(spokeCount, expectedSpokes, 'spoke count');

      for (uint256 j; j < spokeCount; ++j) {
        address spoke = IHub(_market.hub).getSpokeAddress(assetIds[i], j);
        assertTrue(IHub(_market.hub).getSpokeConfig(assetIds[i], spoke).halted, 'spoke halted');
      }
    }
  }

  /// @notice Every configured risk parameter reaches the Hub and the Spoke it was meant for.
  function test_configureAppliesTheRiskParameters() public {
    uint256[] memory assetIds = _configure();

    for (uint256 i; i < _assets.length; ++i) {
      assertEq(
        IHub(_market.hub).getAssetConfig(assetIds[i]).liquidityFee,
        _assets[i].liquidityFee,
        'liquidity fee'
      );
    }

    for (uint256 i; i < _reserves.length; ++i) {
      AaveV4SentoraConfigInputs.Reserve memory reserve = _reserves[i];
      uint256 assetId = assetIds[reserve.assetIndex];
      ISpoke spoke = ISpoke(_market.spokes[reserve.spokeIndex]);
      uint256 reserveId = spoke.getReserveId(_market.hub, assetId);

      IHub.SpokeConfig memory spokeConfig = IHub(_market.hub).getSpokeConfig(
        assetId,
        address(spoke)
      );
      assertEq(spokeConfig.addCap, reserve.addCap, 'add cap');
      assertEq(spokeConfig.drawCap, reserve.drawCap, 'draw cap');
      assertEq(
        spokeConfig.riskPremiumThreshold,
        reserve.riskPremiumThreshold,
        'risk premium threshold'
      );

      ISpoke.ReserveConfig memory config = spoke.getReserveConfig(reserveId);
      assertEq(config.collateralRisk, reserve.collateralRisk, 'collateral risk');
      assertEq(config.borrowable, reserve.borrowable, 'borrowable');
      assertEq(config.receiveSharesEnabled, reserve.receiveSharesEnabled, 'receive shares');
      assertFalse(config.paused, 'paused');
      assertFalse(config.frozen, 'frozen');

      ISpoke.DynamicReserveConfig memory dynamicConfig = spoke.getDynamicReserveConfig(
        reserveId,
        spoke.getReserve(reserveId).dynamicConfigKey
      );
      assertEq(dynamicConfig.collateralFactor, reserve.collateralFactor, 'collateral factor');
      assertEq(
        dynamicConfig.maxLiquidationBonus,
        reserve.maxLiquidationBonus,
        'max liquidation bonus'
      );
      assertEq(dynamicConfig.liquidationFee, reserve.liquidationFee, 'liquidation fee');
    }

    for (uint256 i; i < _market.spokes.length; ++i) {
      assertEq(
        abi.encode(ISpoke(_market.spokes[i]).getLiquidationConfig()),
        abi.encode(AaveV4SentoraParameters.liquidationConfig()),
        'liquidation config'
      );
    }
  }

  /// @notice An asset is listed only on the Spokes a reserve names.
  function test_configureListsReservesOnlyWhereConfigured() public {
    uint256[] memory assetIds = _configure();

    assertFalse(
      IHub(_market.hub).isSpokeListed(assetIds[0], _market.spokes[SPOKE_WITHOUT_COLLATERAL]),
      'collateral on hub'
    );
    assertEq(
      ISpoke(_market.spokes[SPOKE_WITHOUT_COLLATERAL]).getReserveCount(),
      1,
      'reserves on spoke'
    );
  }

  /// @notice The rate curve of each asset reaches the Hub's interest rate strategy.
  function test_configureAppliesTheInterestRateCurves() public {
    uint256[] memory assetIds = _configure();

    for (uint256 i; i < _assets.length; ++i) {
      IAssetInterestRateStrategy.InterestRateData memory irData = IAssetInterestRateStrategy(
        _market.irStrategy
      ).getInterestRateData(assetIds[i]);

      assertEq(irData.optimalUsageRatio, _assets[i].optimalUsageRatio, 'optimal usage ratio');
      assertEq(irData.baseDrawnRate, _assets[i].baseDrawnRate, 'base drawn rate');
      assertEq(
        irData.rateGrowthBeforeOptimal,
        _assets[i].rateGrowthBeforeOptimal,
        'rate growth before optimal'
      );
      assertEq(
        irData.rateGrowthAfterOptimal,
        _assets[i].rateGrowthAfterOptimal,
        'rate growth after optimal'
      );
    }
  }

  /// @notice An empty launch set still configures the market, and lists nothing.
  function test_configureWithNoAssets() public {
    vm.startPrank(_deployer);
    AaveV4SentoraConfiguration.configure(
      _market,
      _deployer,
      new AaveV4SentoraConfigInputs.Asset[](0),
      new AaveV4SentoraConfigInputs.Reserve[](0),
      _targets.proxyAdminOwner
    );
    vm.stopPrank();

    assertEq(IHub(_market.hub).getAssetCount(), 0, 'asset count');
    _assertHasRole(Roles.HUB_CONFIGURATOR_ROLE, _market.hubConfigurator, true);
    _assertHasRole(Roles.SPOKE_CONFIGURATOR_ROLE, _market.spokeConfigurator, true);
    _assertManagersWired();
  }

  /// @notice Every position manager and gateway is wired to every Spoke, both halves.
  function test_configureWiresPositionManagers() public {
    _configure();
    _assertManagersWired();
  }

  /// @notice The tokenized asset's share token follows the live Ethereum and Avalanche naming, and
  ///         its spoke is registered supply-only under its own cap.
  function test_tokenizationSpoke() public {
    uint256[] memory assetIds = _configure();
    uint256 index = _tokenizedAssetIndex();
    uint256 assetId = assetIds[index];

    address tokenizationSpoke = _tokenizationSpokeOf(assetId);
    assertEq(IERC20Metadata(tokenizationSpoke).name(), 'Wrapped Aave Sentora USDX', 'share name');
    assertEq(IERC20Metadata(tokenizationSpoke).symbol(), 'waSentoraUSDX', 'share symbol');
    assertEq(
      Ownable(AaveV4SentoraConfigInputs.proxyAdmin(tokenizationSpoke)).owner(),
      _targets.proxyAdminOwner,
      'tokenization spoke proxy admin'
    );

    IHub.SpokeConfig memory config = IHub(_market.hub).getSpokeConfig(assetId, tokenizationSpoke);
    assertEq(config.addCap, _assets[index].tokenizationAddCap, 'tokenization add cap');
    assertEq(config.drawCap, 0, 'tokenization draw cap');
  }

  /// @notice The handover leaves each admin role with exactly its end-state holder, so an extra
  ///         holder fails rather than passing unnoticed.
  function test_relinquishGrantsTheRoleMap() public {
    _configure();
    _relinquish();

    // reverts if anything is left behind
    AaveV4SentoraHandover.verify(_market, _targets, _deployer);

    _assertHasRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, _targets.admin, true);
    _assertRoleMemberCount(Roles.ACCESS_MANAGER_ADMIN_ROLE, 1);

    // no holder carries an execution delay: the Sentora Executor sits behind its own Timelock
    _assertRoleDelay(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, _targets.sentoraExecutor, 0);
    _assertRoleMemberCount(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, 1);
    _assertRoleDelay(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, _targets.sentoraExecutor, 0);
    _assertRoleMemberCount(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, 1);
    _assertRoleDelay(AaveV4SentoraRoles.SENTORA_RISK_ROLE, _targets.sentoraExecutor, 0);
    _assertRoleDelay(AaveV4SentoraRoles.SENTORA_RISK_ROLE, _targets.riskSteward, 0);
    _assertRoleMemberCount(AaveV4SentoraRoles.SENTORA_RISK_ROLE, 2);
    _assertRoleDelay(AaveV4SentoraRoles.SENTORA_EMERGENCY_ROLE, _targets.emergencyOperator, 0);
    _assertRoleDelay(AaveV4SentoraRoles.SENTORA_EMERGENCY_ROLE, _targets.admin, 0);
    _assertRoleMemberCount(AaveV4SentoraRoles.SENTORA_EMERGENCY_ROLE, 2);

    // the roles that reach the Hub and Spokes directly are left unheld
    _assertRoleEmpty(Roles.HUB_DOMAIN_ADMIN_ROLE);
    _assertRoleEmpty(Roles.HUB_FEE_MINTER_ROLE);
    _assertRoleEmpty(Roles.HUB_DEFICIT_ELIMINATOR_ROLE);
    _assertRoleEmpty(Roles.SPOKE_DOMAIN_ADMIN_ROLE);
    _assertRoleEmpty(Roles.SPOKE_USER_POSITION_UPDATER_ROLE);

    // the configurators keep the roles they call the Hub and Spokes with, and hold them alone
    _assertHasRole(Roles.HUB_CONFIGURATOR_ROLE, _market.hubConfigurator, true);
    _assertRoleMemberCount(Roles.HUB_CONFIGURATOR_ROLE, 1);
    _assertHasRole(Roles.SPOKE_CONFIGURATOR_ROLE, _market.spokeConfigurator, true);
    _assertRoleMemberCount(Roles.SPOKE_CONFIGURATOR_ROLE, 1);
  }

  /// @notice The Emergency Operator and the Security Council halt, pause and freeze but cannot undo
  ///         it, the Risk Steward moves caps and collateral factors only, and the Sentora Executor
  ///         reaches everything but the emergency actions, all without an AccessManager delay.
  function test_sentoraRolesReachTheirSelectors() public {
    uint256[] memory assetIds = _configure();
    _relinquish();

    IHubConfigurator hubConfigurator = IHubConfigurator(_market.hubConfigurator);
    ISpokeConfigurator spokeConfigurator = ISpokeConfigurator(_market.spokeConfigurator);
    address hub = _market.hub;
    address spoke = _market.spokes[0];
    uint32 dynamicConfigKey = ISpoke(spoke).getReserve(0).dynamicConfigKey;

    vm.startPrank(_targets.emergencyOperator);
    spokeConfigurator.freezeReserve(spoke, 0);
    hubConfigurator.haltSpoke(hub, spoke);
    vm.expectRevert();
    hubConfigurator.updateSpokeHalted(hub, assetIds[1], spoke, false);
    vm.expectRevert();
    hubConfigurator.updateSpokeCaps(hub, assetIds[1], spoke, 1, 1);
    vm.stopPrank();

    vm.startPrank(_targets.riskSteward);
    hubConfigurator.updateSpokeCaps(hub, assetIds[1], spoke, 500_000, 400_000);
    spokeConfigurator.updateCollateralFactor(spoke, 0, dynamicConfigKey, 70_00);
    vm.expectRevert();
    hubConfigurator.updateSpokeHalted(hub, assetIds[1], spoke, false);
    vm.expectRevert();
    hubConfigurator.haltSpoke(hub, spoke);
    vm.expectRevert();
    hubConfigurator.updateLiquidityFee(hub, assetIds[1], 50_00);
    vm.stopPrank();

    IHub.SpokeConfig memory spokeConfig = IHub(hub).getSpokeConfig(assetIds[1], spoke);
    assertEq(spokeConfig.addCap, 500_000, 'steward add cap');
    assertEq(spokeConfig.drawCap, 400_000, 'steward draw cap');
    assertEq(
      ISpoke(spoke).getDynamicReserveConfig(0, dynamicConfigKey).collateralFactor,
      70_00,
      'steward collateral factor'
    );

    vm.startPrank(_targets.sentoraExecutor);
    hubConfigurator.updateSpokeHalted(hub, assetIds[1], spoke, false);
    spokeConfigurator.updateFrozen(spoke, 0, false);
    hubConfigurator.updateSpokeCaps(hub, assetIds[1], spoke, 600_000, 500_000);
    vm.expectRevert();
    hubConfigurator.haltSpoke(hub, spoke);
    vm.stopPrank();

    assertFalse(IHub(hub).getSpokeConfig(assetIds[1], spoke).halted, 'executor unhalt');
    assertFalse(ISpoke(spoke).getReserveConfig(0).frozen, 'executor unfreeze');

    // the Security Council holds the emergency role too
    vm.prank(_targets.admin);
    hubConfigurator.haltAsset(hub, assetIds[1]);
    assertTrue(IHub(hub).getSpokeConfig(assetIds[1], spoke).halted, 'council halt');
  }

  /// @notice The config file configures and hands over the market end to end.
  /// @dev A mock feed stands in for each price source the config leaves unset.
  function test_configureAndRelinquishWithConfigFile() public {
    AaveV4SentoraConfigInputs.Asset[] memory assets = AaveV4SentoraConfigInputs.readAssets();
    AaveV4SentoraConfigInputs.Reserve[] memory reserves = AaveV4SentoraConfigInputs.readReserves(
      assets
    );
    for (uint256 i; i < assets.length; ++i) {
      if (assets[i].priceSource == address(0)) {
        assets[i].priceSource = makeAddr(string.concat(assets[i].symbol, ' adapter'));
      }
      _etchAsset(assets[i], MOCK_TOKEN_DECIMALS);
    }
    AaveV4SentoraConfigInputs.requireLiveAssets(assets);

    vm.startPrank(_deployer);
    AaveV4SentoraConfiguration.configure(
      _market,
      _deployer,
      assets,
      reserves,
      _targets.proxyAdminOwner
    );
    AaveV4SentoraHandover.relinquish(_market, _targets, _deployer);
    vm.stopPrank();

    AaveV4SentoraHandover.verify(_market, _targets, _deployer);
    assertEq(IHub(_market.hub).getAssetCount(), assets.length, 'asset count');

    uint256 listed;
    for (uint256 i; i < _market.spokes.length; ++i) {
      listed += ISpoke(_market.spokes[i]).getReserveCount();
    }
    assertEq(listed, reserves.length, 'reserve count');
  }

  /// @notice After the handover the deployer can no longer configure or grant.
  function test_relinquishRevokesDeployerPowers() public {
    _configure();
    _relinquish();

    vm.startPrank(_deployer);
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

  /// @notice Verification fails if an asset is left live on any Spoke.
  function test_verifyRejectsUnhaltedAsset() public {
    uint256[] memory assetIds = _configure();

    vm.prank(_deployer);
    IHubConfigurator(_market.hubConfigurator).updateSpokeHalted({
      hub: _market.hub,
      assetId: assetIds[0],
      spoke: _market.spokes[0],
      halted: false
    });
    _relinquish();

    vm.expectRevert(
      abi.encodeWithSelector(
        AaveV4SentoraHandover.AssetNotHalted.selector,
        assetIds[0],
        _market.spokes[0]
      )
    );
    this.verifyHandover();
  }

  /// @notice Verification fails if a role that must be left unheld has a member.
  function test_verifyRejectsUnexpectedRoleHolder() public {
    _configure();

    vm.prank(_deployer);
    IAccessManager(_market.accessManager).grantRole(
      Roles.HUB_FEE_MINTER_ROLE,
      makeAddr('intruder'),
      0
    );
    _relinquish();

    vm.expectRevert(
      abi.encodeWithSelector(AaveV4SentoraHandover.RoleNotEmpty.selector, Roles.HUB_FEE_MINTER_ROLE)
    );
    this.verifyHandover();
  }

  /// @notice Verification fails if a Sentora role gains a holder the end state does not call for,
  ///         even though every expected holder is still in place.
  function test_verifyRejectsExtraSentoraRoleHolder() public {
    _configure();
    _relinquish();

    vm.prank(_targets.admin);
    IAccessManager(_market.accessManager).grantRole(
      AaveV4SentoraRoles.SENTORA_RISK_ROLE,
      makeAddr('intruder'),
      0
    );

    vm.expectRevert(
      abi.encodeWithSelector(
        AaveV4SentoraHandover.UnexpectedRoleMemberCount.selector,
        AaveV4SentoraRoles.SENTORA_RISK_ROLE,
        3,
        2
      )
    );
    this.verifyHandover();
  }

  /// @notice Verification fails if a risk selector is rewired to the emergency role.
  function test_verifyRejectsRewiredSelector() public {
    _configure();
    _relinquish();

    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = IHubConfigurator.updateSpokeCaps.selector;
    vm.prank(_targets.admin);
    IAccessManager(_market.accessManager).setTargetFunctionRole(
      _market.hubConfigurator,
      selectors,
      AaveV4SentoraRoles.SENTORA_EMERGENCY_ROLE
    );

    vm.expectRevert(
      abi.encodeWithSelector(
        AaveV4SentoraHandover.UnexpectedSelectorRole.selector,
        _market.hubConfigurator,
        IHubConfigurator.updateSpokeCaps.selector,
        AaveV4SentoraRoles.SENTORA_EMERGENCY_ROLE
      )
    );
    this.verifyHandover();
  }

  /// @notice Verification fails if the risk role reaches a selector beyond its own, even when every
  ///         expected selector is still wired to it.
  function test_verifyRejectsExtraRiskSelector() public {
    _configure();
    _relinquish();

    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = IHubConfigurator.updateLiquidityFee.selector;
    vm.prank(_targets.admin);
    IAccessManager(_market.accessManager).setTargetFunctionRole(
      _market.hubConfigurator,
      selectors,
      AaveV4SentoraRoles.SENTORA_RISK_ROLE
    );

    vm.expectRevert(
      abi.encodeWithSelector(
        AaveV4SentoraHandover.UnexpectedSelectorCount.selector,
        AaveV4SentoraRoles.SENTORA_RISK_ROLE,
        _market.hubConfigurator,
        4,
        3
      )
    );
    this.verifyHandover();
  }

  /// @notice A tokenization spoke whose ProxyAdmin went elsewhere fails verification.
  function test_verifyRejectsForeignTokenizationSpokeProxyAdminOwner() public {
    address foreignOwner = makeAddr('foreignOwner');

    vm.startPrank(_deployer);
    AaveV4SentoraConfiguration.configure(_market, _deployer, _assets, _reserves, foreignOwner);
    vm.stopPrank();
    _relinquish();

    vm.expectRevert(
      abi.encodeWithSelector(
        AaveV4SentoraHandover.UnexpectedOwner.selector,
        AaveV4SentoraConfigInputs.proxyAdmin(_tokenizationSpokeOf(_tokenizedAssetIndex())),
        foreignOwner
      )
    );
    this.verifyHandover();
  }

  /// @dev Exposes the verification externally, so that `vm.expectRevert` sees a nested call.
  function verifyHandover() external view {
    AaveV4SentoraHandover.verify(_market, _targets, _deployer);
  }

  /// @notice The Security Council owns the Hub and Spoke ProxyAdmins throughout and takes the
  ///         treasury spoke's at handover, and the Sentora Executor takes the treasury spoke, the
  ///         managers and the gateways over with one `acceptOwnership` each.
  function test_ownershipReachesItsHolders() public {
    _assertProxyAdminOwners(_deployer);
    _configure();
    _assertProxyAdminOwners(_deployer);

    // the deployer owns the treasury spoke and the managers until the handover, which is what lets
    // it wire the managers and split the treasury spoke's ProxyAdmin off
    assertEq(Ownable(_market.treasurySpoke).owner(), _deployer, 'treasury owner');
    assertEq(Ownable(_market.giverPositionManager).owner(), _deployer, 'giver owner');

    _relinquish();
    _assertProxyAdminOwners(_targets.proxyAdminOwner);

    address[6] memory owned = [
      _market.treasurySpoke,
      _market.giverPositionManager,
      _market.takerPositionManager,
      _market.configPositionManager,
      _market.nativeTokenGateway,
      _market.signatureGateway
    ];

    for (uint256 i; i < owned.length; ++i) {
      assertEq(Ownable2Step(owned[i]).pendingOwner(), _targets.sentoraExecutor, 'pending owner');

      vm.prank(_targets.sentoraExecutor);
      Ownable2Step(owned[i]).acceptOwnership();
      assertEq(Ownable(owned[i]).owner(), _targets.sentoraExecutor, 'owner');
    }

    // still verifies once the transfers have completed
    AaveV4SentoraHandover.verify(_market, _targets, _deployer);
  }

  /// @dev The Hub and Spoke ProxyAdmins belong to `proxyAdminOwner` from the deploy onwards; the
  ///      treasury spoke's belongs to `treasuryProxyAdminOwner`.
  function _assertProxyAdminOwners(address treasuryProxyAdminOwner) internal view {
    assertEq(
      Ownable(AaveV4SentoraConfigInputs.proxyAdmin(_market.hub)).owner(),
      _targets.proxyAdminOwner,
      'hub proxy admin'
    );
    for (uint256 i; i < _market.spokes.length; ++i) {
      assertEq(
        Ownable(AaveV4SentoraConfigInputs.proxyAdmin(_market.spokes[i])).owner(),
        _targets.proxyAdminOwner,
        'spoke proxy admin'
      );
    }
    assertEq(
      Ownable(AaveV4SentoraConfigInputs.proxyAdmin(_market.treasurySpoke)).owner(),
      treasuryProxyAdminOwner,
      'treasury proxy admin'
    );
  }

  function _assertManagersWired() internal view {
    address[5] memory managers = [
      _market.giverPositionManager,
      _market.takerPositionManager,
      _market.configPositionManager,
      _market.nativeTokenGateway,
      _market.signatureGateway
    ];

    for (uint256 i; i < managers.length; ++i) {
      for (uint256 j; j < _market.spokes.length; ++j) {
        assertTrue(
          ISpoke(_market.spokes[j]).isPositionManagerActive(managers[i]),
          'position manager active on spoke'
        );
      }
    }
  }

  function _configure() internal returns (uint256[] memory assetIds) {
    vm.startPrank(_deployer);
    assetIds = AaveV4SentoraConfiguration.configure(
      _market,
      _deployer,
      _assets,
      _reserves,
      _targets.proxyAdminOwner
    );
    vm.stopPrank();
  }

  function _relinquish() internal {
    vm.startPrank(_deployer);
    AaveV4SentoraHandover.relinquish(_market, _targets, _deployer);
    vm.stopPrank();
  }

  /// @dev The tokenization spoke is the last Spoke registered for the asset, since configuration
  ///      adds it after the treasury spoke and the market's own spokes.
  function _tokenizationSpokeOf(uint256 assetId) internal view returns (address) {
    uint256 spokeCount = IHub(_market.hub).getSpokeCount(assetId);
    return IHub(_market.hub).getSpokeAddress(assetId, spokeCount - 1);
  }

  function _reserveCount(uint256 assetIndex) internal view returns (uint256 count) {
    for (uint256 i; i < _reserves.length; ++i) {
      if (_reserves[i].assetIndex == assetIndex) ++count;
    }
  }

  /// @dev The launch set tokenizes exactly one asset, and asset ids follow the order it is read in.
  function _tokenizedAssetIndex() internal view returns (uint256 index) {
    for (uint256 i; i < _assets.length; ++i) {
      if (_assets[i].tokenize) return i;
    }
    revert('no tokenized asset configured');
  }

  /// @dev A launch set asset at a fresh address, with mock token and feed code etched there. A
  ///      collateral asset has a flat curve; a borrowable one gets a tokenization spoke.
  function _fixtureAsset(
    string memory symbol,
    uint8 decimals,
    bool borrowable
  ) internal returns (AaveV4SentoraConfigInputs.Asset memory asset) {
    asset.symbol = symbol;
    asset.underlying = makeAddr(symbol);
    asset.priceSource = makeAddr(string.concat(symbol, ' / USD'));

    if (borrowable) {
      asset.liquidityFee = 10_00;
      asset.optimalUsageRatio = 90_00;
      asset.rateGrowthBeforeOptimal = 4_00;
      asset.rateGrowthAfterOptimal = 20_00;
      asset.tokenize = true;
      asset.tokenizationAddCap = 100_000;
    } else {
      asset.optimalUsageRatio = 1_00;
    }

    _etchAsset(asset, decimals);
  }

  /// @dev A reserve of a fixture asset on one Spoke. A collateral reserve is non-borrowable and
  ///      carries a collateral risk; a borrowable one is never collateral.
  function _fixtureReserve(
    uint256 spokeIndex,
    uint256 assetIndex
  ) internal view returns (AaveV4SentoraConfigInputs.Reserve memory reserve) {
    reserve.spokeIndex = spokeIndex;
    reserve.assetIndex = assetIndex;
    reserve.asset = _assets[assetIndex].symbol;
    reserve.addCap = 1_000_000;
    reserve.receiveSharesEnabled = true;

    if (_assets[assetIndex].tokenize) {
      reserve.drawCap = 800_000;
      reserve.riskPremiumThreshold = type(uint24).max;
      reserve.maxLiquidationBonus = 100_00;
      reserve.borrowable = true;
    } else {
      reserve.collateralRisk = 10_00;
      reserve.collateralFactor = 75_00;
      reserve.maxLiquidationBonus = 105_00;
      reserve.liquidationFee = 10_00;
    }
  }

  /// @dev Puts a token and a feed where the launch set expects them, so that the configured
  ///      addresses are the ones the configurators are handed.
  function _etchAsset(AaveV4SentoraConfigInputs.Asset memory asset, uint8 decimals) internal {
    deployCodeTo(
      'TestnetERC20.sol:TestnetERC20',
      abi.encode(asset.symbol, asset.symbol, decimals),
      asset.underlying
    );
    deployCodeTo(
      'MockPriceFeed.sol:MockPriceFeed',
      abi.encode(PRICE_FEED_DECIMALS, string.concat(asset.symbol, ' / USD'), MOCK_PRICE),
      asset.priceSource
    );
  }

  function _toMarket(
    OrchestrationReports.FullDeploymentReport memory report
  ) internal pure returns (AaveV4SentoraConfigInputs.Market memory market) {
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

    market.nativeTokenGateway = report.gatewaysBatchReport.nativeGateway;
    market.signatureGateway = report.gatewaysBatchReport.signatureGateway;
    market.giverPositionManager = report.positionManagerBatchReport.giverPositionManager;
    market.takerPositionManager = report.positionManagerBatchReport.takerPositionManager;
    market.configPositionManager = report.positionManagerBatchReport.configPositionManager;
  }

  function _assertHasRole(uint64 role, address account, bool expected) internal view {
    (bool isMember, ) = IAccessManager(_market.accessManager).hasRole(role, account);
    assertEq(isMember, expected, string.concat('role ', vm.toString(uint256(role))));
  }

  function _assertRoleDelay(uint64 role, address account, uint32 expectedDelay) internal view {
    (bool isMember, uint32 delay) = IAccessManager(_market.accessManager).hasRole(role, account);
    assertTrue(isMember, string.concat('role ', vm.toString(uint256(role))));
    assertEq(delay, expectedDelay, string.concat('role ', vm.toString(uint256(role)), ' delay'));
  }

  function _assertRoleEmpty(uint64 role) internal view {
    _assertRoleMemberCount(role, 0);
  }

  /// @dev Pins the exact member count, so a role gaining an unexpected holder fails even when every
  ///      expected holder is still in place.
  function _assertRoleMemberCount(uint64 role, uint256 expected) internal view {
    assertEq(
      IAccessManagerEnumerable(_market.accessManager).getRoleMemberCount(role),
      expected,
      string.concat('role ', vm.toString(uint256(role)), ' members')
    );
  }

  /// @dev Tests are non-interactive.
  function _executeUserPrompt() internal override {}
}
