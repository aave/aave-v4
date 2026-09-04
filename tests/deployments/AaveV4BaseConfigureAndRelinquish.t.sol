// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4DeployBase} from 'scripts/deploy/AaveV4DeployBase.s.sol';
import {AaveV4BaseConfigInputs} from 'scripts/config/AaveV4BaseConfigInputs.sol';
import {AaveV4BaseConfiguration} from 'scripts/config/AaveV4BaseConfiguration.sol';
import {AaveV4BaseHandover} from 'scripts/config/AaveV4BaseHandover.sol';
import {AaveV4BaseParameters} from 'scripts/config/AaveV4BaseParameters.sol';

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

import {Create2TestHelper} from 'tests/utils/Create2TestHelper.sol';

import {Test} from 'forge-std/Test.sol';

/// @title AaveV4BaseConfigureAndRelinquishTest
/// @author Aave Labs
/// @notice Runs the whole Base operator path on a local deployment: deploy from config/base.json
///         with roles deferred, list a set of assets with the launch parameters, halt, then hand
///         over to the Security Council and the governance executor.
/// @dev config/base-config.json carries no assets yet, so the launch set is mocked here rather than
///      read from it: the point of these tests is the configuration and handover machinery, which
///      has to keep working for whatever set eventually lands there.
contract AaveV4BaseConfigureAndRelinquishTest is Test, Create2TestHelper, AaveV4DeployBase {
  /// @dev Matches `DeployConstants.ORACLE_DECIMALS`, which `AaveOracle` enforces on price sources.
  uint8 internal constant PRICE_FEED_DECIMALS = DeployConstants.ORACLE_DECIMALS;
  uint8 internal constant MOCK_ASSET_DECIMALS = 18;
  uint256 internal constant MOCK_PRICE = 1e8;

  address internal _deployer = makeAddr('deployer');

  AaveV4BaseConfigInputs.Market internal _market;
  AaveV4BaseConfigInputs.Handover internal _targets;
  AaveV4BaseConfigInputs.Asset[] internal _assets;

  function setUp() public {
    _etchCreate2Factory();

    _assets.push(_mockAsset('WETH', true));
    _assets.push(_mockAsset('USDC', false));

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
    _targets = AaveV4BaseConfigInputs.readHandover();
  }

  /// @notice The deploy leaves the deployer as AccessManager admin and nothing else granted.
  function test_deployDefersAllRoles() public view {
    _assertHasRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, _deployer, true);

    // the selectors are wired, but no address holds the roles that reach them yet
    _assertHasRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, _deployer, false);
    _assertHasRole(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, _deployer, false);
    _assertHasRole(Roles.HUB_CONFIGURATOR_ROLE, _market.hubConfigurator, false);
    _assertHasRole(Roles.SPOKE_CONFIGURATOR_ROLE, _market.spokeConfigurator, false);
    _assertHasRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, _targets.councilExecutor, false);
  }

  /// @notice Without the self-granted roles the deployer cannot configure anything.
  function test_configureRevertsWithoutRoles() public {
    vm.prank(_deployer);
    vm.expectRevert();
    IHubConfigurator(_market.hubConfigurator).haltAsset(_market.hub, 0);
  }

  /// @notice The AccessManager applies no delay, so the self-granted roles take effect at once.
  function test_noAccessManagerDelays() public view {
    AaveV4BaseConfiguration.requireNoDelays(_market);
  }

  /// @notice Configuration lists every asset everywhere and leaves it halted on every Spoke.
  function test_configureListsAndHalts() public {
    uint256[] memory assetIds = _configure();

    assertEq(assetIds.length, _assets.length, 'asset id count');
    assertEq(IHub(_market.hub).getAssetCount(), _assets.length, 'asset count');

    for (uint256 i; i < _assets.length; ++i) {
      assertEq(IHubBase(_market.hub).getAssetId(_assets[i].underlying), assetIds[i], 'asset id');

      // the treasury spoke is registered as the fee receiver on top of the configured spokes, and
      // the tokenized asset gets a tokenization spoke as well
      uint256 expectedSpokes = _market.spokes.length + (_assets[i].tokenize ? 2 : 1);
      uint256 spokeCount = IHub(_market.hub).getSpokeCount(assetIds[i]);
      assertEq(spokeCount, expectedSpokes, 'spoke count');

      for (uint256 j; j < spokeCount; ++j) {
        address spoke = IHub(_market.hub).getSpokeAddress(assetIds[i], j);
        assertTrue(IHub(_market.hub).getSpokeConfig(assetIds[i], spoke).halted, 'spoke halted');
      }

      for (uint256 j; j < _market.spokes.length; ++j) {
        ISpoke.ReserveConfig memory config = ISpoke(_market.spokes[j]).getReserveConfig(i);
        assertEq(config.collateralRisk, AaveV4BaseParameters.COLLATERAL_RISK, 'collateral risk');
        assertFalse(config.borrowable, 'borrowable');
      }
    }
  }

  /// @notice An empty launch set still configures the market, and lists nothing.
  function test_configureWithNoAssets() public {
    AaveV4BaseConfigInputs.Asset[] memory none = new AaveV4BaseConfigInputs.Asset[](0);

    vm.startPrank(_deployer);
    AaveV4BaseConfiguration.configure(_market, _deployer, none, _targets.proxyAdminOwner);
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

  /// @notice The tokenized asset's share token follows the live Ethereum and Avalanche naming.
  function test_tokenizationSpokeNaming() public {
    _configure();

    address tokenizationSpoke = _tokenizationSpokeOf(0);
    assertEq(IERC20Metadata(tokenizationSpoke).name(), 'Wrapped Aave Core WETH', 'share name');
    assertEq(IERC20Metadata(tokenizationSpoke).symbol(), 'waCoreWETH', 'share symbol');
    assertEq(
      Ownable(AaveV4BaseConfigInputs.proxyAdmin(tokenizationSpoke)).owner(),
      _targets.proxyAdminOwner,
      'tokenization spoke proxy admin'
    );
  }

  /// @notice The handover reproduces the role map of the live Ethereum market.
  function test_relinquishGrantsTheEthereumRoleMap() public {
    _configure();
    _relinquish();

    // reverts if anything is left behind
    AaveV4BaseHandover.verify(_market, _targets, _deployer);

    _assertHasRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, _targets.securityCouncil, true);
    _assertHasRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, _targets.governanceExecutor, true);

    // both configurator domain admin roles carry the same three holders
    address[3] memory admins = [
      _targets.securityCouncil,
      _targets.councilExecutor,
      _targets.governanceExecutor
    ];
    for (uint256 i; i < admins.length; ++i) {
      _assertHasRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, admins[i], true);
      _assertHasRole(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, admins[i], true);
    }
    _assertRoleMemberCount(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, admins.length);
    _assertRoleMemberCount(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, admins.length);

    // the roles that reach the Hub and Spokes directly are left unheld
    _assertRoleEmpty(Roles.HUB_DOMAIN_ADMIN_ROLE);
    _assertRoleEmpty(Roles.HUB_FEE_MINTER_ROLE);
    _assertRoleEmpty(Roles.HUB_DEFICIT_ELIMINATOR_ROLE);
    _assertRoleEmpty(Roles.SPOKE_DOMAIN_ADMIN_ROLE);
    _assertRoleEmpty(Roles.SPOKE_USER_POSITION_UPDATER_ROLE);

    // the configurators keep the roles they call the Hub and Spokes with
    _assertHasRole(Roles.HUB_CONFIGURATOR_ROLE, _market.hubConfigurator, true);
    _assertHasRole(Roles.SPOKE_CONFIGURATOR_ROLE, _market.spokeConfigurator, true);
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
        AaveV4BaseHandover.AssetNotHalted.selector,
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
      abi.encodeWithSelector(AaveV4BaseHandover.RoleNotEmpty.selector, Roles.HUB_FEE_MINTER_ROLE)
    );
    this.verifyHandover();
  }

  /// @notice A tokenization spoke whose ProxyAdmin went elsewhere fails verification.
  function test_verifyRejectsForeignTokenizationSpokeProxyAdminOwner() public {
    address foreignOwner = makeAddr('foreignOwner');

    vm.startPrank(_deployer);
    AaveV4BaseConfiguration.configure(_market, _deployer, _assets, foreignOwner);
    vm.stopPrank();
    _relinquish();

    vm.expectRevert(
      abi.encodeWithSelector(
        AaveV4BaseHandover.UnexpectedOwner.selector,
        AaveV4BaseConfigInputs.proxyAdmin(_tokenizationSpokeOf(0)),
        foreignOwner
      )
    );
    this.verifyHandover();
  }

  /// @dev Exposes the verification externally, so that `vm.expectRevert` sees a nested call.
  function verifyHandover() external view {
    AaveV4BaseHandover.verify(_market, _targets, _deployer);
  }

  /// @notice The Council owns the proxies and the treasury spoke throughout, and takes the managers
  ///         over with one `acceptOwnership` each.
  function test_ownershipReachesTheCouncil() public {
    _assertCouncilOwnsProxiesAndTreasury();
    _configure();
    _assertCouncilOwnsProxiesAndTreasury();

    // the deployer owns the managers until the handover, which is what lets it wire them
    assertEq(Ownable(_market.giverPositionManager).owner(), _deployer, 'giver owner');

    _relinquish();
    _assertCouncilOwnsProxiesAndTreasury();

    // no pending transfer left behind on the Ownable2Step treasury spoke
    assertEq(Ownable2Step(_market.treasurySpoke).pendingOwner(), address(0), 'pending owner');

    address[5] memory managers = [
      _market.giverPositionManager,
      _market.takerPositionManager,
      _market.configPositionManager,
      _market.nativeTokenGateway,
      _market.signatureGateway
    ];

    for (uint256 i; i < managers.length; ++i) {
      assertEq(Ownable2Step(managers[i]).pendingOwner(), _targets.gatewayOwner, 'pending manager');

      vm.prank(_targets.gatewayOwner);
      Ownable2Step(managers[i]).acceptOwnership();
      assertEq(Ownable(managers[i]).owner(), _targets.gatewayOwner, 'manager owner');
    }

    // still verifies once the transfers have completed
    AaveV4BaseHandover.verify(_market, _targets, _deployer);
  }

  function _assertCouncilOwnsProxiesAndTreasury() internal view {
    assertEq(
      Ownable(AaveV4BaseConfigInputs.proxyAdmin(_market.hub)).owner(),
      _targets.proxyAdminOwner,
      'hub proxy admin'
    );
    for (uint256 i; i < _market.spokes.length; ++i) {
      assertEq(
        Ownable(AaveV4BaseConfigInputs.proxyAdmin(_market.spokes[i])).owner(),
        _targets.proxyAdminOwner,
        'spoke proxy admin'
      );
    }
    assertEq(
      Ownable(AaveV4BaseConfigInputs.proxyAdmin(_market.treasurySpoke)).owner(),
      _targets.proxyAdminOwner,
      'treasury proxy admin'
    );
    assertEq(
      Ownable(_market.treasurySpoke).owner(),
      _targets.treasurySpokeOwner,
      'treasury spoke owner'
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
    assetIds = AaveV4BaseConfiguration.configure(
      _market,
      _deployer,
      _assets,
      _targets.proxyAdminOwner
    );
    vm.stopPrank();
  }

  function _relinquish() internal {
    vm.startPrank(_deployer);
    AaveV4BaseHandover.relinquish(_market, _targets, _deployer);
    vm.stopPrank();
  }

  /// @dev The tokenization spoke is the last Spoke registered for the asset, since configuration
  ///      adds it after the treasury spoke and the market's own spokes.
  function _tokenizationSpokeOf(uint256 assetId) internal view returns (address) {
    uint256 spokeCount = IHub(_market.hub).getSpokeCount(assetId);
    return IHub(_market.hub).getSpokeAddress(assetId, spokeCount - 1);
  }

  function _mockAsset(
    string memory symbol,
    bool tokenize
  ) internal returns (AaveV4BaseConfigInputs.Asset memory asset) {
    asset = AaveV4BaseConfigInputs.Asset({
      symbol: symbol,
      underlying: makeAddr(string.concat(symbol, '-underlying')),
      priceSource: makeAddr(string.concat(symbol, '-priceSource')),
      tokenize: tokenize
    });

    deployCodeTo(
      'TestnetERC20.sol:TestnetERC20',
      abi.encode(symbol, symbol, MOCK_ASSET_DECIMALS),
      asset.underlying
    );
    deployCodeTo(
      'MockPriceFeed.sol:MockPriceFeed',
      abi.encode(PRICE_FEED_DECIMALS, string.concat(symbol, ' / USD'), MOCK_PRICE),
      asset.priceSource
    );
  }

  function _toMarket(
    OrchestrationReports.FullDeploymentReport memory report
  ) internal pure returns (AaveV4BaseConfigInputs.Market memory market) {
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
