// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Create2TestHelper} from 'tests/utils/Create2TestHelper.sol';
import {AaveV4DeployBabylon} from 'scripts/markets/babylon/AaveV4DeployBabylon.s.sol';
import {AaveV4BabylonHandover} from 'scripts/markets/babylon/AaveV4BabylonHandover.s.sol';
import {AaveV4BabylonConfigure} from 'scripts/markets/babylon/AaveV4BabylonConfigure.s.sol';
import {AaveV4BabylonConfig} from 'scripts/markets/babylon/AaveV4BabylonConfig.sol';
import {AaveV4BabylonVerify} from 'scripts/markets/babylon/AaveV4BabylonVerify.s.sol';
import {AaveV4BabylonVerification} from 'scripts/markets/babylon/AaveV4BabylonVerification.sol';
import {AaveV4DeployOrchestration} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';
import {MetadataLogger} from 'src/deployments/utils/MetadataLogger.sol';
import {BytecodeHelper} from 'src/deployments/utils/libraries/BytecodeHelper.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {IAccessManagerEnumerable} from 'src/access/interfaces/IAccessManagerEnumerable.sol';
import {ProxyAdmin} from 'src/dependencies/openzeppelin/ProxyAdmin.sol';
import {Ownable2StepUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/Ownable2StepUpgradeable.sol';
import {IBabylonSpoke} from 'src/spoke/interfaces/IBabylonSpoke.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

contract AaveV4DeployBabylonHarness is AaveV4DeployBabylon {
  AaveV4BabylonConfig.Config internal _harnessConfig;

  constructor(AaveV4BabylonConfig.Config memory config) {
    _harnessConfig = config;
  }

  function sanitizedDeployInputs(
    address deployer
  ) external returns (InputUtils.FullDeployInputs memory) {
    return _loadWarningsAndSanitizeInputs(_getDeployInputs(), deployer);
  }

  function requireConfigLibraries(bytes32 librarySalt) external view {
    super._requireConfigLibraries(librarySalt);
  }

  function containsAddress(bytes memory code, address target) external pure returns (bool) {
    return _containsAddress(code, target);
  }

  function _config() internal view override returns (AaveV4BabylonConfig.Config memory) {
    return _harnessConfig;
  }

  /// @dev Tests link the libraries foundry deploys, not the ones at the config salt.
  function _requireConfigLibraries(bytes32) internal view override {}

  function _executeUserPrompt() internal override {}
}

contract AaveV4BabylonHandoverHarness is AaveV4BabylonHandover {
  AaveV4BabylonConfig.Config internal _harnessConfig;

  constructor(AaveV4BabylonConfig.Config memory config) {
    _harnessConfig = config;
  }

  function _config() internal view override returns (AaveV4BabylonConfig.Config memory) {
    return _harnessConfig;
  }
}

contract AaveV4BabylonConfigureHarness is AaveV4BabylonConfigure {
  AaveV4BabylonConfig.Config internal _harnessConfig;
  string internal _marketJson;

  constructor(AaveV4BabylonConfig.Config memory config, string memory marketJson) {
    _harnessConfig = config;
    _marketJson = marketJson;
  }

  function _config() internal view override returns (AaveV4BabylonConfig.Config memory) {
    return _harnessConfig;
  }

  function _marketConfig(
    AaveV4BabylonConfig.Config memory config,
    AaveV4BabylonConfig.Deployment memory deployment
  ) internal view override returns (AaveV4BabylonConfig.MarketConfig memory) {
    return
      AaveV4BabylonConfig.parseMarketConfig({
        json: _marketJson,
        config: config,
        deployment: deployment
      });
  }
}

contract AaveV4BabylonVerifyHarness is AaveV4BabylonVerify {
  AaveV4BabylonConfig.Config internal _harnessConfig;
  string internal _marketJson;

  constructor(AaveV4BabylonConfig.Config memory config, string memory marketJson) {
    _harnessConfig = config;
    _marketJson = marketJson;
  }

  function _config() internal view override returns (AaveV4BabylonConfig.Config memory) {
    return _harnessConfig;
  }

  function _marketConfig(
    AaveV4BabylonConfig.Config memory config,
    AaveV4BabylonConfig.Deployment memory deployment
  ) internal view override returns (AaveV4BabylonConfig.MarketConfig memory) {
    return
      AaveV4BabylonConfig.parseMarketConfig({
        json: _marketJson,
        config: config,
        deployment: deployment
      });
  }
}

contract AaveV4BabylonTest is Create2TestHelper {
  bytes32 internal constant ADMIN_SLOT =
    0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
  string internal constant OUTPUT_DIR = 'output/reports/deployments/';
  string internal constant REPORT_NAME = 'babylon-handover-test';
  address internal constant SEPOLIA_AAVE_ADAPTER = 0x6A785E8fdF251E2aA758a6E1841e1470074f46BF;
  address internal constant SEPOLIA_ADMIN = 0x66501C33b8fA9DD06348469bA34d96D3dE7F2239;
  uint256 internal constant SEPOLIA_CHAIN_ID = 11155111;
  bytes32 internal constant CANONICAL_LIBRARY_SALT = bytes32(uint256(0x2bdf));
  address internal constant MAINNET_TEST_AAVE_ADAPTER = 0xF93892D520630d3eB0ed9A2157746E0a63a9E6f2;
  address internal constant SEPOLIA_BTC = 0x2ba819663bDB2C51205997187e75eb7D092D3444;
  address internal constant SEPOLIA_USDC = 0xB588C1bd8A6cd3F114A52a0AD916778B419ECf48;
  address internal constant SEPOLIA_USDT = 0xCFf21358114814258635524588f74521762A6c04;
  address internal constant SEPOLIA_WBTC = 0x504579d0424B7B7cB4b17e16626f6A2f67bCa054;
  address internal constant SEPOLIA_USD_FEED = 0xdd04B859B3bF9aAfBb3cBe175E6159b1ED998765;
  address internal constant SEPOLIA_BTC_FEED = 0xF9C48C4C694cb1101081c4402F95Cf5Dd33fb316;
  string internal constant SEPOLIA_CONFIG = 'scripts/markets/babylon/config/sepolia.json';

  address internal _deployer = DEFAULT_SENDER;
  address internal _admin = makeAddr('admin');
  address internal _liquidationManager = makeAddr('liquidationManager');
  AaveV4BabylonConfig.Config internal _config;

  function setUp() public {
    _etchCreate2Factory();
    string[] memory hubLabels = new string[](2);
    hubLabels[0] = 'babylon-btc';
    hubLabels[1] = 'babylon-stables';
    _config = AaveV4BabylonConfig.Config({
      chainId: block.chainid,
      salt: keccak256('aave-v4-babylon-v2'),
      librarySalt: CANONICAL_LIBRARY_SALT,
      hubLabels: hubLabels,
      babylonSpokeLabel: 'babylon',
      liquidationManager: _liquidationManager,
      managedCollateralReserveId: 0,
      admin: _admin,
      report: string.concat(OUTPUT_DIR, vm.toString(block.chainid), '-', REPORT_NAME, '.json')
    });
  }

  function test_sepoliaConfig() public {
    vm.chainId(SEPOLIA_CHAIN_ID);
    AaveV4BabylonConfig.Config memory config = AaveV4BabylonConfig.read('sepolia');
    assertEq(config.chainId, SEPOLIA_CHAIN_ID);
    assertEq(config.salt, keccak256('aave-v4-babylon-v2'));
    assertEq(config.librarySalt, CANONICAL_LIBRARY_SALT);
    assertEq(config.hubLabels.length, 2);
    assertEq(config.hubLabels[0], 'babylon-btc');
    assertEq(config.hubLabels[1], 'babylon-stables');
    assertEq(config.babylonSpokeLabel, 'babylon');
    assertEq(config.liquidationManager, SEPOLIA_AAVE_ADAPTER);
    assertEq(config.managedCollateralReserveId, 0);
    assertEq(config.admin, SEPOLIA_ADMIN);
  }

  function test_mainnetTestConfig() public {
    vm.chainId(1);
    AaveV4BabylonConfig.Config memory config = AaveV4BabylonConfig.read('mainnet-test');
    assertEq(config.chainId, 1);
    assertEq(config.salt, keccak256('aave-v4-babylon-mainnet-test-v1'));
    assertEq(config.librarySalt, keccak256('aave-v4-babylon-mainnet-test-libraries-v1'));
    assertEq(config.hubLabels.length, 2);
    assertEq(config.hubLabels[0], 'babylon-btc');
    assertEq(config.hubLabels[1], 'babylon-stables');
    assertEq(config.babylonSpokeLabel, 'babylon');
    assertEq(config.liquidationManager, MAINNET_TEST_AAVE_ADAPTER);
    assertEq(config.managedCollateralReserveId, 0);
    assertEq(config.admin, SEPOLIA_ADMIN);
    assertEq(config.report, 'scripts/markets/babylon/reports/mainnet-test.json');
  }

  function test_read_revertsWith_chainIdMismatch() public {
    vm.chainId(1);
    vm.expectRevert('config chain id mismatch');
    this.readConfig('sepolia');

    vm.chainId(SEPOLIA_CHAIN_ID);
    vm.expectRevert('config chain id mismatch');
    this.readConfig('mainnet-test');
  }

  function test_requireConfigLibraries_revertsWith_librariesNotDeployed() public {
    AaveV4DeployBabylonHarness harness = new AaveV4DeployBabylonHarness(_config);
    vm.expectRevert('config libraries not deployed');
    harness.requireConfigLibraries(keccak256('aave-v4-babylon-mainnet-test-libraries-v1'));
  }

  function test_containsAddress() public {
    AaveV4DeployBabylonHarness harness = new AaveV4DeployBabylonHarness(_config);
    address target = makeAddr('library');
    bytes memory code = abi.encodePacked(hex'6080', target, hex'5b');
    assertTrue(harness.containsAddress(code, target));
    assertTrue(harness.containsAddress(abi.encodePacked(target), target));
    assertFalse(
      harness.containsAddress(abi.encodePacked(hex'6080', bytes19(bytes20(target))), target)
    );
    assertFalse(harness.containsAddress(code, makeAddr('other')));
  }

  function test_sepoliaConfig_deploy() public {
    vm.chainId(SEPOLIA_CHAIN_ID);
    OrchestrationReports.FullDeploymentReport memory report = this.deploy(
      new AaveV4DeployBabylonHarness(AaveV4BabylonConfig.read('sepolia')).sanitizedDeployInputs(
        _deployer
      )
    );

    IBabylonSpoke babylonSpoke = IBabylonSpoke(
      report.babylonSpokeInstanceBatchReports[0].report.spokeProxy
    );
    assertEq(babylonSpoke.LIQUIDATION_MANAGER(), SEPOLIA_AAVE_ADAPTER);
    assertEq(babylonSpoke.MANAGED_COLLATERAL_RESERVE_ID(), 0);
  }

  function test_deployInputs() public {
    InputUtils.FullDeployInputs memory inputs = new AaveV4DeployBabylonHarness(_config)
      .sanitizedDeployInputs(_deployer);

    assertFalse(inputs.grantRoles);
    assertEq(inputs.proxyAdminOwner, _deployer);
    assertEq(inputs.treasurySpokeOwner, _deployer);
    assertEq(inputs.hubLabels.length, 2);
    assertEq(inputs.hubLabels[0], 'babylon-btc');
    assertEq(inputs.hubLabels[1], 'babylon-stables');
    assertEq(inputs.spokeLabels.length, 0);
    assertEq(inputs.babylonSpokeLabels.length, 1);
    assertEq(inputs.babylonSpokeLabels[0], 'babylon');
    assertEq(inputs.babylonLiquidationManagers[0], _liquidationManager);
    assertEq(inputs.babylonManagedCollateralReserveIds[0], 0);
    assertFalse(inputs.deployNativeTokenGateway);
    assertFalse(inputs.deploySignatureGateway);
    assertFalse(inputs.deployPositionManagers);
    assertEq(inputs.salt, keccak256('aave-v4-babylon-v2'));
  }

  function test_deploy() public {
    OrchestrationReports.FullDeploymentReport memory report = this.deploy(
      new AaveV4DeployBabylonHarness(_config).sanitizedDeployInputs(_deployer)
    );

    assertEq(report.hubInstanceBatchReports.length, 2);
    assertEq(report.hubInstanceBatchReports[0].label, 'babylon-btc');
    assertEq(report.hubInstanceBatchReports[1].label, 'babylon-stables');
    assertNotEq(
      report.hubInstanceBatchReports[0].report.hubProxy,
      report.hubInstanceBatchReports[1].report.hubProxy
    );
    assertNotEq(
      report.hubInstanceBatchReports[0].report.irStrategy,
      report.hubInstanceBatchReports[1].report.irStrategy
    );
    assertEq(report.spokeInstanceBatchReports.length, 0);
    assertEq(report.babylonSpokeInstanceBatchReports.length, 1);
    assertEq(report.gatewaysBatchReport.signatureGateway, address(0));
    assertEq(report.gatewaysBatchReport.nativeGateway, address(0));
    assertEq(report.positionManagerBatchReport.giverPositionManager, address(0));

    address babylonSpoke = report.babylonSpokeInstanceBatchReports[0].report.spokeProxy;
    assertEq(IBabylonSpoke(babylonSpoke).LIQUIDATION_MANAGER(), _liquidationManager);
    assertEq(IBabylonSpoke(babylonSpoke).MANAGED_COLLATERAL_RESERVE_ID(), 0);

    assertEq(_proxyAdmin(report.hubInstanceBatchReports[0].report.hubProxy).owner(), _deployer);
    assertEq(_proxyAdmin(report.hubInstanceBatchReports[1].report.hubProxy).owner(), _deployer);
    assertEq(_proxyAdmin(babylonSpoke).owner(), _deployer);
    assertEq(_proxyAdmin(report.treasurySpokeBatchReport.treasurySpoke).owner(), _deployer);
    assertEq(
      Ownable2StepUpgradeable(report.treasurySpokeBatchReport.treasurySpoke).owner(),
      _deployer
    );
    (bool deployerIsAdmin, ) = IAccessManagerEnumerable(report.authorityBatchReport.accessManager)
      .hasRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, _deployer);
    assertTrue(deployerIsAdmin);
  }

  function test_handover_leavesDeployerWithNothing() public {
    OrchestrationReports.FullDeploymentReport memory report = _deployAndWriteReport();
    new AaveV4BabylonHandoverHarness(_config).run();

    IAccessManagerEnumerable accessManager = IAccessManagerEnumerable(
      report.authorityBatchReport.accessManager
    );
    (bool deployerIsAdmin, ) = accessManager.hasRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, _deployer);
    assertFalse(deployerIsAdmin);
    (bool adminIsAdmin, ) = accessManager.hasRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, _admin);
    assertTrue(adminIsAdmin);
    for (uint256 i; i < accessManager.getRoleCount(); ++i) {
      (bool hasRole, ) = accessManager.hasRole(accessManager.getRole(i), _deployer);
      assertFalse(hasRole);
    }

    address treasurySpoke = report.treasurySpokeBatchReport.treasurySpoke;
    assertEq(_proxyAdmin(report.hubInstanceBatchReports[0].report.hubProxy).owner(), _admin);
    assertEq(_proxyAdmin(report.hubInstanceBatchReports[1].report.hubProxy).owner(), _admin);
    assertEq(
      _proxyAdmin(report.babylonSpokeInstanceBatchReports[0].report.spokeProxy).owner(),
      _admin
    );
    assertEq(_proxyAdmin(treasurySpoke).owner(), _admin);
    assertEq(Ownable2StepUpgradeable(treasurySpoke).owner(), _deployer);
    assertEq(Ownable2StepUpgradeable(treasurySpoke).pendingOwner(), _admin);

    vm.prank(_admin);
    Ownable2StepUpgradeable(treasurySpoke).acceptOwnership();
    assertEq(Ownable2StepUpgradeable(treasurySpoke).owner(), _admin);
  }

  /// @dev Roles granted by the deployer while configuring are revoked too.
  function test_handover_revokesRolesTheDeployerGrantedItself() public {
    OrchestrationReports.FullDeploymentReport memory report = _deployAndWriteReport();
    IAccessManagerEnumerable accessManager = IAccessManagerEnumerable(
      report.authorityBatchReport.accessManager
    );
    vm.startPrank(_deployer);
    accessManager.grantRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, _deployer, 0);
    accessManager.grantRole(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, _deployer, 0);
    vm.stopPrank();

    new AaveV4BabylonHandoverHarness(_config).run();

    (bool hubConfiguratorAdmin, ) = accessManager.hasRole(
      Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      _deployer
    );
    (bool spokeConfiguratorAdmin, ) = accessManager.hasRole(
      Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      _deployer
    );
    assertFalse(hubConfiguratorAdmin);
    assertFalse(spokeConfiguratorAdmin);
  }

  /// @dev The Ethereum role end state, with every governance holder collapsed into the admin.
  function test_handover_rolesMatchEthereum() public {
    OrchestrationReports.FullDeploymentReport memory report = _deployAndWriteReport();
    new AaveV4BabylonHandoverHarness(_config).run();
    _assertEthereumRoles(report);
  }

  function test_configure_thenHandover_rolesMatchEthereum() public {
    OrchestrationReports.FullDeploymentReport memory report = _deployAndWriteReport();
    _deploySepoliaTokensAndFeeds();
    new AaveV4BabylonConfigureHarness(_config, vm.readFile(SEPOLIA_CONFIG)).run();
    new AaveV4BabylonHandoverHarness(_config).run();
    _assertEthereumRoles(report);
  }

  function test_handover_revertsWith_strayRoleMember() public {
    OrchestrationReports.FullDeploymentReport memory report = _deployAndWriteReport();
    vm.prank(_deployer);
    IAccessManager(report.authorityBatchReport.accessManager).grantRole(
      Roles.HUB_FEE_MINTER_ROLE,
      makeAddr('stray'),
      0
    );
    AaveV4BabylonHandoverHarness handover = new AaveV4BabylonHandoverHarness(_config);
    vm.expectRevert('unexpected role members: 102');
    handover.run();
  }

  function test_verify() public {
    _configureHandoverAndAccept();
    _verifier().run();
  }

  function test_verify_revertsWith_adminUnset() public {
    _configureHandoverAndAccept();
    _config.admin = address(0);
    AaveV4BabylonVerifyHarness verifier = _verifier();
    vm.expectRevert('admin unset');
    verifier.run();
  }

  function test_verify_revertsWith_treasurySpokeOwnershipPending() public {
    _deployAndWriteReport();
    _deploySepoliaTokensAndFeeds();
    new AaveV4BabylonConfigureHarness(_config, vm.readFile(SEPOLIA_CONFIG)).run();
    new AaveV4BabylonHandoverHarness(_config).run();
    AaveV4BabylonVerifyHarness verifier = _verifier();
    vm.expectRevert('treasury spoke owner');
    verifier.run();
  }

  function test_verify_revertsWith_extraConfiguratorAdmin() public {
    AaveV4BabylonConfig.Deployment memory deployment = _configureHandoverAndAccept();
    vm.prank(_admin);
    IAccessManager(deployment.accessManager).grantRole(
      Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      makeAddr('stray'),
      0
    );
    AaveV4BabylonVerifyHarness verifier = _verifier();
    vm.expectRevert('unexpected role members: 400');
    verifier.run();
  }

  function test_verify_revertsWith_unheldRoleGranted() public {
    AaveV4BabylonConfig.Deployment memory deployment = _configureHandoverAndAccept();
    vm.prank(_admin);
    IAccessManager(deployment.accessManager).grantRole(Roles.HUB_DOMAIN_ADMIN_ROLE, _admin, 0);
    AaveV4BabylonVerifyHarness verifier = _verifier();
    vm.expectRevert('unexpected role members: 100');
    verifier.run();
  }

  function test_verify_revertsWith_unknownRoleGranted() public {
    AaveV4BabylonConfig.Deployment memory deployment = _configureHandoverAndAccept();
    vm.prank(_admin);
    IAccessManager(deployment.accessManager).grantRole(999, makeAddr('stray'), 0);
    AaveV4BabylonVerifyHarness verifier = _verifier();
    vm.expectRevert('unexpected role members: 999');
    verifier.run();
  }

  function test_verify_revertsWith_spokeWithoutProxyAdmin() public {
    AaveV4BabylonConfig.Deployment memory deployment = _configureHandoverAndAccept();
    vm.prank(_admin);
    IHubConfigurator(deployment.hubConfigurator).addSpoke({
      hub: deployment.hubs[0],
      spoke: makeAddr('stray spoke'),
      assetId: 0,
      config: IHub.SpokeConfig({
        addCap: 1,
        drawCap: 0,
        riskPremiumThreshold: 0,
        active: true,
        halted: false
      })
    });
    AaveV4BabylonVerifyHarness verifier = _verifier();
    vm.expectRevert('not a transparent proxy');
    verifier.run();
  }

  function test_verify_revertsWith_proxyAdminOwner() public {
    AaveV4BabylonConfig.Deployment memory deployment = _configureHandoverAndAccept();
    ProxyAdmin proxyAdmin = _proxyAdmin(deployment.hubs[1]);
    vm.prank(_admin);
    proxyAdmin.transferOwnership(makeAddr('stray'));
    AaveV4BabylonVerifyHarness verifier = _verifier();
    vm.expectRevert('proxy admin owner');
    verifier.run();
  }

  function test_verify_revertsWith_spokeConfigChanged() public {
    AaveV4BabylonConfig.Deployment memory deployment = _configureHandoverAndAccept();
    vm.prank(_admin);
    IHubConfigurator(deployment.hubConfigurator).updateSpokeAddCap({
      hub: deployment.hubs[0],
      assetId: 0,
      spoke: deployment.babylonSpoke,
      addCap: 11
    });
    AaveV4BabylonVerifyHarness verifier = _verifier();
    vm.expectRevert('babylon spoke config');
    verifier.run();
  }

  function test_verify_revertsWith_reserveConfigChanged() public {
    AaveV4BabylonConfig.Deployment memory deployment = _configureHandoverAndAccept();
    vm.prank(_admin);
    ISpokeConfigurator(deployment.spokeConfigurator).updateFrozen({
      spoke: deployment.babylonSpoke,
      reserveId: 1,
      frozen: true
    });
    AaveV4BabylonVerifyHarness verifier = _verifier();
    vm.expectRevert('reserve config');
    verifier.run();
  }

  function test_verify_revertsWith_liquidationConfigChanged() public {
    AaveV4BabylonConfig.Deployment memory deployment = _configureHandoverAndAccept();
    vm.prank(_admin);
    ISpokeConfigurator(deployment.spokeConfigurator).updateLiquidationBonusFactor(
      deployment.babylonSpoke,
      80_00
    );
    AaveV4BabylonVerifyHarness verifier = _verifier();
    vm.expectRevert('liquidation config');
    verifier.run();
  }

  function test_verify_revertsWith_liquidationManager() public {
    _configureHandoverAndAccept();
    _config.liquidationManager = makeAddr('other liquidation manager');
    AaveV4BabylonVerifyHarness verifier = _verifier();
    vm.expectRevert('liquidation manager');
    verifier.run();
  }

  function test_verifyMarketConfig_revertsWith_extraSpokeOnAsset() public {
    AaveV4BabylonConfig.Deployment memory deployment = _configureHandoverAndAccept();
    vm.prank(_admin);
    IHubConfigurator(deployment.hubConfigurator).addSpoke({
      hub: deployment.hubs[1],
      spoke: makeAddr('stray spoke'),
      assetId: 2,
      config: IHub.SpokeConfig({
        addCap: 1,
        drawCap: 0,
        riskPremiumThreshold: 0,
        active: true,
        halted: false
      })
    });
    vm.expectRevert('asset spoke count');
    this.verifyMarketConfig(deployment);
  }

  function test_verifyMarketConfig_revertsWith_extraAsset() public {
    AaveV4BabylonConfig.Deployment memory deployment = _configureHandoverAndAccept();
    address token = makeAddr('extra token');
    deployCodeTo('TestnetERC20.sol:TestnetERC20', abi.encode('X', 'X', uint8(18)), token);
    vm.prank(_admin);
    IHubConfigurator(deployment.hubConfigurator).addAsset({
      hub: deployment.hubs[0],
      underlying: token,
      feeReceiver: deployment.treasurySpoke,
      liquidityFee: 0,
      irStrategy: deployment.irStrategies[0],
      irData: abi.encode(
        IAssetInterestRateStrategy.InterestRateData({
          optimalUsageRatio: 90_00,
          baseDrawnRate: 0,
          rateGrowthBeforeOptimal: 0,
          rateGrowthAfterOptimal: 0
        })
      )
    });
    vm.expectRevert('hub asset count');
    this.verifyMarketConfig(deployment);
  }

  function test_handover_revertsWith_adminUnset() public {
    _deployAndWriteReport();
    _config.admin = address(0);
    AaveV4BabylonHandoverHarness handover = new AaveV4BabylonHandoverHarness(_config);
    vm.expectRevert('admin unset');
    handover.run();
  }

  function test_handover_revertsWith_adminIsDeployer() public {
    _deployAndWriteReport();
    _config.admin = _deployer;
    AaveV4BabylonHandoverHarness handover = new AaveV4BabylonHandoverHarness(_config);
    vm.expectRevert('admin is deployer');
    handover.run();
  }

  function test_sepoliaMarketConfig() public {
    AaveV4BabylonConfig.Deployment memory deployment;
    deployment.hubs = new address[](2);
    deployment.hubs[0] = makeAddr('babylon-btc');
    deployment.hubs[1] = makeAddr('babylon-stables');
    deployment.irStrategies = new address[](2);
    deployment.irStrategies[0] = makeAddr('babylon-btc irStrategy');
    deployment.irStrategies[1] = makeAddr('babylon-stables irStrategy');
    AaveV4BabylonConfig.MarketConfig memory marketConfig = AaveV4BabylonConfig.parseMarketConfig({
      json: vm.readFile(SEPOLIA_CONFIG),
      config: _config,
      deployment: deployment
    });

    _assertListings(marketConfig.reserves, _expectedSepoliaListings(deployment));
    assertEq(marketConfig.liquidationConfig.targetHealthFactor, 1e18);
    assertEq(marketConfig.liquidationConfig.healthFactorForMaxBonus, 0.9e18);
    assertEq(marketConfig.liquidationConfig.liquidationBonusFactor, 90_00);
  }

  /// @dev The mainnet test config keeps a zero vaultBTC address until Babylon deploys it, so the
  /// configure step cannot run on it before then.
  function test_mainnetTestMarketConfig_revertsWhileVaultBtcUnset() public {
    AaveV4BabylonConfig.Deployment memory deployment;
    deployment.hubs = new address[](2);
    deployment.irStrategies = new address[](2);
    vm.expectRevert('reserve address unset');
    this.parseMarketConfig(
      vm.readFile('scripts/markets/babylon/config/mainnet-test.json'),
      deployment
    );
  }

  function parseMarketConfig(
    string memory json,
    AaveV4BabylonConfig.Deployment memory deployment
  ) external view returns (AaveV4BabylonConfig.MarketConfig memory) {
    return
      AaveV4BabylonConfig.parseMarketConfig({json: json, config: _config, deployment: deployment});
  }

  function test_configure() public {
    OrchestrationReports.FullDeploymentReport memory report = _deployAndWriteReport();
    _deploySepoliaTokensAndFeeds();
    new AaveV4BabylonConfigureHarness(_config, vm.readFile(SEPOLIA_CONFIG)).run();

    AaveV4BabylonConfig.Deployment memory deployment = AaveV4BabylonConfig.readDeployment(_config);
    AaveV4BabylonConfig.ReserveListing[] memory expected = _expectedSepoliaListings(deployment);
    ISpoke spoke = ISpoke(deployment.babylonSpoke);
    IAaveOracle oracle = IAaveOracle(spoke.ORACLE());
    assertEq(spoke.getReserveCount(), expected.length);
    assertEq(IHub(deployment.hubs[0]).getAssetCount(), 3);
    assertEq(IHub(deployment.hubs[1]).getAssetCount(), 3);
    for (uint256 i; i < expected.length; ++i) {
      ISpoke.Reserve memory reserve = spoke.getReserve(i);
      assertEq(address(reserve.hub), expected[i].hub);
      assertEq(reserve.underlying, expected[i].underlying);
      assertEq(oracle.getReserveSource(i), expected[i].priceSource);
      assertEq(abi.encode(spoke.getReserveConfig(i)), abi.encode(expected[i].reserveConfig));
      assertEq(
        abi.encode(spoke.getDynamicReserveConfig(i, reserve.dynamicConfigKey)),
        abi.encode(expected[i].dynamicConfig)
      );

      IHub.Asset memory asset = IHub(expected[i].hub).getAsset(reserve.assetId);
      assertEq(asset.feeReceiver, report.treasurySpokeBatchReport.treasurySpoke);
      assertEq(asset.liquidityFee, expected[i].liquidityFee);
      assertEq(asset.irStrategy, expected[i].irStrategy);
      assertEq(asset.reinvestmentController, address(0));
      assertEq(
        abi.encode(
          IAssetInterestRateStrategy(expected[i].irStrategy).getInterestRateData(reserve.assetId)
        ),
        abi.encode(expected[i].irData)
      );
      assertEq(
        abi.encode(IHub(expected[i].hub).getSpokeConfig(reserve.assetId, address(spoke))),
        abi.encode(expected[i].spokeConfig)
      );
    }
    ISpoke.LiquidationConfig memory liquidationConfig = spoke.getLiquidationConfig();
    assertEq(liquidationConfig.targetHealthFactor, 1e18);
    assertEq(liquidationConfig.healthFactorForMaxBonus, 0.9e18);
    assertEq(liquidationConfig.liquidationBonusFactor, 90_00);

    IAccessManagerEnumerable accessManager = IAccessManagerEnumerable(deployment.accessManager);
    (bool hubConfiguratorHasRole, ) = accessManager.hasRole(
      Roles.HUB_CONFIGURATOR_ROLE,
      deployment.hubConfigurator
    );
    (bool spokeConfiguratorHasRole, ) = accessManager.hasRole(
      Roles.SPOKE_CONFIGURATOR_ROLE,
      deployment.spokeConfigurator
    );
    assertTrue(hubConfiguratorHasRole);
    assertTrue(spokeConfiguratorHasRole);
  }

  function test_configure_revertsWith_babylonSpokeHasReserves() public {
    _deployAndWriteReport();
    _deploySepoliaTokensAndFeeds();
    new AaveV4BabylonConfigureHarness(_config, vm.readFile(SEPOLIA_CONFIG)).run();

    AaveV4BabylonConfigureHarness configure = new AaveV4BabylonConfigureHarness(
      _config,
      vm.readFile(SEPOLIA_CONFIG)
    );
    vm.expectRevert('babylon spoke has reserves');
    configure.run();
  }

  function test_configure_revertsWith_grantDelay() public {
    OrchestrationReports.FullDeploymentReport memory report = _deployAndWriteReport();
    _deploySepoliaTokensAndFeeds();
    IAccessManager accessManager = IAccessManager(report.authorityBatchReport.accessManager);
    vm.prank(_deployer);
    accessManager.setGrantDelay(Roles.SPOKE_CONFIGURATOR_ROLE, 1 days);
    vm.warp(block.timestamp + accessManager.minSetback() + 1);

    AaveV4BabylonConfigureHarness configure = new AaveV4BabylonConfigureHarness(
      _config,
      vm.readFile(SEPOLIA_CONFIG)
    );
    vm.expectRevert('unexpected grant delay');
    configure.run();
  }

  function test_configure_revertsWith_adminDelay() public {
    OrchestrationReports.FullDeploymentReport memory report = _deployAndWriteReport();
    _deploySepoliaTokensAndFeeds();
    IAccessManager accessManager = IAccessManager(report.authorityBatchReport.accessManager);
    vm.prank(_deployer);
    accessManager.setTargetAdminDelay(address(accessManager), 1 days);
    vm.warp(block.timestamp + accessManager.minSetback() + 1);

    AaveV4BabylonConfigureHarness configure = new AaveV4BabylonConfigureHarness(
      _config,
      vm.readFile(SEPOLIA_CONFIG)
    );
    vm.expectRevert('unexpected admin delay');
    configure.run();
  }

  /// @dev The handover grants the configurator roles again and revokes the roles granted to the deployer.
  function test_configure_thenHandover_leavesDeployerWithNothing() public {
    OrchestrationReports.FullDeploymentReport memory report = _deployAndWriteReport();
    _deploySepoliaTokensAndFeeds();
    new AaveV4BabylonConfigureHarness(_config, vm.readFile(SEPOLIA_CONFIG)).run();
    new AaveV4BabylonHandoverHarness(_config).run();

    IAccessManagerEnumerable accessManager = IAccessManagerEnumerable(
      report.authorityBatchReport.accessManager
    );
    for (uint256 i; i < accessManager.getRoleCount(); ++i) {
      (bool hasRole, ) = accessManager.hasRole(accessManager.getRole(i), _deployer);
      assertFalse(hasRole);
    }
    (bool deployerIsAdmin, ) = accessManager.hasRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, _deployer);
    assertFalse(deployerIsAdmin);
  }

  function verifyMarketConfig(AaveV4BabylonConfig.Deployment memory deployment) external view {
    AaveV4BabylonVerification.verifyMarketConfig(
      deployment,
      AaveV4BabylonConfig.parseMarketConfig({
        json: vm.readFile(SEPOLIA_CONFIG),
        config: _config,
        deployment: deployment
      })
    );
  }

  function readConfig(
    string memory name
  ) external view returns (AaveV4BabylonConfig.Config memory) {
    return AaveV4BabylonConfig.read(name);
  }

  function deploy(
    InputUtils.FullDeployInputs memory inputs
  ) external returns (OrchestrationReports.FullDeploymentReport memory report) {
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);
    bytes memory hubBytecode = BytecodeHelper.getHubBytecode();
    bytes memory spokeBytecode = BytecodeHelper.getSpokeBytecode();
    bytes memory babylonSpokeBytecode = BytecodeHelper.getBabylonSpokeBytecode();
    vm.startPrank(_deployer);
    report = AaveV4DeployOrchestration.deployAaveV4({
      logger: logger,
      deployer: _deployer,
      deployInputs: inputs,
      hubBytecode: hubBytecode,
      spokeBytecode: spokeBytecode,
      babylonSpokeBytecode: babylonSpokeBytecode
    });
    vm.stopPrank();
  }

  function _deployAndWriteReport()
    internal
    returns (OrchestrationReports.FullDeploymentReport memory report)
  {
    report = this.deploy(new AaveV4DeployBabylonHarness(_config).sanitizedDeployInputs(_deployer));
    vm.createDir(OUTPUT_DIR, true);
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);
    logger.writeJsonReportMarket(report);
    logger.save({fileName: REPORT_NAME, withTimestamp: false});
  }

  function _proxyAdmin(address proxy) internal view returns (ProxyAdmin) {
    return ProxyAdmin(address(uint160(uint256(vm.load(proxy, ADMIN_SLOT)))));
  }

  function _deploySepoliaTokensAndFeeds() internal {
    deployCodeTo('TestnetERC20.sol:TestnetERC20', abi.encode('BTC', 'BTC', uint8(8)), SEPOLIA_BTC);
    deployCodeTo(
      'TestnetERC20.sol:TestnetERC20',
      abi.encode('USDC', 'USDC', uint8(6)),
      SEPOLIA_USDC
    );
    deployCodeTo(
      'TestnetERC20.sol:TestnetERC20',
      abi.encode('USDT', 'USDT', uint8(6)),
      SEPOLIA_USDT
    );
    deployCodeTo(
      'TestnetERC20.sol:TestnetERC20',
      abi.encode('WBTC', 'WBTC', uint8(8)),
      SEPOLIA_WBTC
    );
    deployCodeTo(
      'MockPriceFeed.sol:MockPriceFeed',
      abi.encode(uint8(8), 'USD', uint256(1e8)),
      SEPOLIA_USD_FEED
    );
    deployCodeTo(
      'MockPriceFeed.sol:MockPriceFeed',
      abi.encode(uint8(8), 'BTC / USD', uint256(100_000e8)),
      SEPOLIA_BTC_FEED
    );
  }

  /// @dev The approved Sepolia market parameters, in BabylonSpoke reserve order.
  function _expectedSepoliaListings(
    AaveV4BabylonConfig.Deployment memory deployment
  ) internal pure returns (AaveV4BabylonConfig.ReserveListing[] memory listings) {
    IAssetInterestRateStrategy.InterestRateData memory stables = IAssetInterestRateStrategy
      .InterestRateData({
        optimalUsageRatio: 92_00,
        baseDrawnRate: 0,
        rateGrowthBeforeOptimal: 4_00,
        rateGrowthAfterOptimal: 20_00
      });
    IAssetInterestRateStrategy.InterestRateData memory wbtc = IAssetInterestRateStrategy
      .InterestRateData({
        optimalUsageRatio: 80_00,
        baseDrawnRate: 25,
        rateGrowthBeforeOptimal: 4_00,
        rateGrowthAfterOptimal: 60_00
      });
    listings = new AaveV4BabylonConfig.ReserveListing[](6);
    listings[0] = _listing({
      hub: deployment.hubs[0],
      irStrategy: deployment.irStrategies[0],
      underlying: SEPOLIA_BTC,
      priceSource: SEPOLIA_BTC_FEED,
      liquidityFee: 0,
      irData: IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 99_00,
        baseDrawnRate: 0,
        rateGrowthBeforeOptimal: 0,
        rateGrowthAfterOptimal: 0
      }),
      addCap: 10,
      drawCap: 0,
      borrowable: false,
      collateralFactor: 78_00,
      maxLiquidationBonus: 105_55
    });
    listings[1] = _listing({
      hub: deployment.hubs[0],
      irStrategy: deployment.irStrategies[0],
      underlying: SEPOLIA_USDC,
      priceSource: SEPOLIA_USD_FEED,
      liquidityFee: 10_00,
      irData: stables,
      addCap: 50_000,
      drawCap: 50_000,
      borrowable: true,
      collateralFactor: 0,
      maxLiquidationBonus: 100_00
    });
    listings[2] = _listing({
      hub: deployment.hubs[0],
      irStrategy: deployment.irStrategies[0],
      underlying: SEPOLIA_WBTC,
      priceSource: SEPOLIA_BTC_FEED,
      liquidityFee: 20_00,
      irData: wbtc,
      addCap: 1,
      drawCap: 2,
      borrowable: true,
      collateralFactor: 0,
      maxLiquidationBonus: 100_00
    });
    listings[3] = _listing({
      hub: deployment.hubs[1],
      irStrategy: deployment.irStrategies[1],
      underlying: SEPOLIA_USDC,
      priceSource: SEPOLIA_USD_FEED,
      liquidityFee: 10_00,
      irData: stables,
      addCap: 100_000,
      drawCap: 350_000,
      borrowable: true,
      collateralFactor: 0,
      maxLiquidationBonus: 100_00
    });
    listings[4] = _listing({
      hub: deployment.hubs[1],
      irStrategy: deployment.irStrategies[1],
      underlying: SEPOLIA_USDT,
      priceSource: SEPOLIA_USD_FEED,
      liquidityFee: 10_00,
      irData: stables,
      addCap: 100_000,
      drawCap: 350_000,
      borrowable: true,
      collateralFactor: 0,
      maxLiquidationBonus: 100_00
    });
    listings[5] = _listing({
      hub: deployment.hubs[1],
      irStrategy: deployment.irStrategies[1],
      underlying: SEPOLIA_WBTC,
      priceSource: SEPOLIA_BTC_FEED,
      liquidityFee: 20_00,
      irData: wbtc,
      addCap: 1,
      drawCap: 2,
      borrowable: true,
      collateralFactor: 0,
      maxLiquidationBonus: 100_00
    });
  }

  /// @dev Fields equal across every approved Sepolia reserve are fixed here.
  function _listing(
    address hub,
    address irStrategy,
    address underlying,
    address priceSource,
    uint16 liquidityFee,
    IAssetInterestRateStrategy.InterestRateData memory irData,
    uint40 addCap,
    uint40 drawCap,
    bool borrowable,
    uint16 collateralFactor,
    uint32 maxLiquidationBonus
  ) internal pure returns (AaveV4BabylonConfig.ReserveListing memory) {
    return
      AaveV4BabylonConfig.ReserveListing({
        hub: hub,
        irStrategy: irStrategy,
        underlying: underlying,
        priceSource: priceSource,
        liquidityFee: liquidityFee,
        irData: irData,
        spokeConfig: IHub.SpokeConfig({
          addCap: addCap,
          drawCap: drawCap,
          riskPremiumThreshold: type(uint24).max,
          active: true,
          halted: false
        }),
        reserveConfig: ISpoke.ReserveConfig({
          collateralRisk: 0,
          paused: false,
          frozen: false,
          borrowable: borrowable,
          receiveSharesEnabled: false
        }),
        dynamicConfig: ISpoke.DynamicReserveConfig({
          collateralFactor: collateralFactor,
          maxLiquidationBonus: maxLiquidationBonus,
          liquidationFee: 0
        })
      });
  }

  function _assertListings(
    AaveV4BabylonConfig.ReserveListing[] memory actual,
    AaveV4BabylonConfig.ReserveListing[] memory expected
  ) internal pure {
    assertEq(actual.length, expected.length);
    for (uint256 i; i < expected.length; ++i) {
      assertEq(abi.encode(actual[i]), abi.encode(expected[i]));
    }
  }

  function _configureHandoverAndAccept()
    internal
    returns (AaveV4BabylonConfig.Deployment memory deployment)
  {
    _deployAndWriteReport();
    _deploySepoliaTokensAndFeeds();
    new AaveV4BabylonConfigureHarness(_config, vm.readFile(SEPOLIA_CONFIG)).run();
    new AaveV4BabylonHandoverHarness(_config).run();
    deployment = AaveV4BabylonConfig.readDeployment(_config);
    vm.prank(_admin);
    Ownable2StepUpgradeable(deployment.treasurySpoke).acceptOwnership();
  }

  function _verifier() internal returns (AaveV4BabylonVerifyHarness) {
    return new AaveV4BabylonVerifyHarness(_config, vm.readFile(SEPOLIA_CONFIG));
  }

  function _assertEthereumRoles(
    OrchestrationReports.FullDeploymentReport memory report
  ) internal view {
    IAccessManagerEnumerable accessManager = IAccessManagerEnumerable(
      report.authorityBatchReport.accessManager
    );
    _assertMembers(accessManager, Roles.ACCESS_MANAGER_ADMIN_ROLE, _admin);
    _assertMembers(
      accessManager,
      Roles.HUB_CONFIGURATOR_ROLE,
      report.configuratorBatchReport.hubConfigurator
    );
    _assertMembers(accessManager, Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, _admin);
    _assertMembers(
      accessManager,
      Roles.SPOKE_CONFIGURATOR_ROLE,
      report.configuratorBatchReport.spokeConfigurator
    );
    _assertMembers(accessManager, Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, _admin);
    assertEq(accessManager.getRoleMemberCount(Roles.HUB_DOMAIN_ADMIN_ROLE), 0);
    assertEq(accessManager.getRoleMemberCount(Roles.HUB_FEE_MINTER_ROLE), 0);
    assertEq(accessManager.getRoleMemberCount(Roles.HUB_DEFICIT_ELIMINATOR_ROLE), 0);
    assertEq(accessManager.getRoleMemberCount(Roles.SPOKE_DOMAIN_ADMIN_ROLE), 0);
    assertEq(accessManager.getRoleMemberCount(Roles.SPOKE_USER_POSITION_UPDATER_ROLE), 0);
  }

  function _assertMembers(
    IAccessManagerEnumerable accessManager,
    uint64 role,
    address member
  ) internal view {
    address[] memory members = accessManager.getRoleMembers(
      role,
      0,
      accessManager.getRoleMemberCount(role)
    );
    assertEq(members.length, 1);
    assertEq(members[0], member);
  }
}
