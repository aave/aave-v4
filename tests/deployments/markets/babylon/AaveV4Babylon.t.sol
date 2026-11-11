// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Create2TestHelper} from 'tests/utils/Create2TestHelper.sol';
import {ProxyHelper} from 'tests/utils/ProxyHelper.sol';
import {AaveV4DeployBabylonHub} from 'scripts/markets/babylon/AaveV4DeployBabylonHub.s.sol';
import {AaveV4DeployBabylonTokenization} from 'scripts/markets/babylon/AaveV4DeployBabylonTokenization.s.sol';
import {
  AaveV4DeployBabylonSpoke,
  AaveV4BabylonSpokeDeployment,
  ICreateX
} from 'scripts/markets/babylon/AaveV4DeployBabylonSpoke.s.sol';
import {AaveV4BabylonHandover} from 'scripts/markets/babylon/AaveV4BabylonHandover.s.sol';
import {AaveV4BabylonConfigure} from 'scripts/markets/babylon/AaveV4BabylonConfigure.s.sol';
import {AaveV4BabylonConfig} from 'scripts/markets/babylon/AaveV4BabylonConfig.sol';
import {AaveV4BabylonVerify} from 'scripts/markets/babylon/AaveV4BabylonVerify.s.sol';
import {AaveV4BabylonVerification} from 'scripts/markets/babylon/AaveV4BabylonVerification.sol';
import {AaveV4DeployOrchestration} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';
import {MetadataLogger} from 'src/deployments/utils/MetadataLogger.sol';
import {BytecodeHelper} from 'src/deployments/utils/libraries/BytecodeHelper.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {IAccessManagerEnumerable} from 'src/access/interfaces/IAccessManagerEnumerable.sol';
import {ProxyAdmin} from 'src/dependencies/openzeppelin/ProxyAdmin.sol';
import {Ownable2StepUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/Ownable2StepUpgradeable.sol';
import {IBabylonSpoke} from 'src/spoke/interfaces/IBabylonSpoke.sol';
import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

contract AaveV4DeployBabylonHubHarness is AaveV4DeployBabylonHub {
  AaveV4BabylonConfig.Config internal _harnessConfig;

  constructor(AaveV4BabylonConfig.Config memory config) {
    _harnessConfig = config;
  }

  function sanitizedDeployInputs(
    address deployer
  ) external returns (InputUtils.FullDeployInputs memory) {
    return _loadWarningsAndSanitizeInputs(_getDeployInputs(), deployer);
  }

  function _config() internal view override returns (AaveV4BabylonConfig.Config memory) {
    return _harnessConfig;
  }

  function _executeUserPrompt() internal override {}
}

contract AaveV4DeployBabylonSpokeHarness is AaveV4DeployBabylonSpoke {
  AaveV4BabylonConfig.Config internal _harnessConfig;
  bool internal _skipLiquidationManagerCheck;

  constructor(AaveV4BabylonConfig.Config memory config, bool skipLiquidationManagerCheck) {
    _harnessConfig = config;
    _skipLiquidationManagerCheck = skipLiquidationManagerCheck;
  }

  function requireConfigLibraries(bytes32 librarySalt) external view {
    super._requireConfigLibraries(librarySalt);
  }

  function requireLiquidationManager(AaveV4BabylonConfig.Config memory config) external view {
    super._requireLiquidationManager(config);
  }

  function containsAddress(bytes memory code, address target) external pure returns (bool) {
    return _containsAddress(code, target);
  }

  function _config() internal view override returns (AaveV4BabylonConfig.Config memory) {
    return _harnessConfig;
  }

  /// @dev Updates the config report in place, so the next steps read the BabylonSpoke.
  function _outputReport() internal view override returns (string memory) {
    return _harnessConfig.report;
  }

  /// @dev Tests link the libraries foundry deploys, not the ones at the config salt.
  function _requireConfigLibraries(bytes32) internal view override {}

  /// @dev CreateX is not deployed in unit tests, `requireLiquidationManager` covers the check.
  function _requireLiquidationManager(
    AaveV4BabylonConfig.Config memory config
  ) internal view override {
    if (!_skipLiquidationManagerCheck) {
      super._requireLiquidationManager(config);
    }
  }
}

contract AaveV4BabylonHandoverHarness is AaveV4BabylonHandover {
  AaveV4BabylonConfig.Config internal _harnessConfig;
  string internal _marketJson = '{}';

  constructor(AaveV4BabylonConfig.Config memory config) {
    _harnessConfig = config;
  }

  function setMarketJson(string memory marketJson) external {
    _marketJson = marketJson;
  }

  function _config() internal view override returns (AaveV4BabylonConfig.Config memory) {
    return _harnessConfig;
  }

  function _externalSpokes(
    AaveV4BabylonConfig.Config memory config,
    AaveV4BabylonConfig.Deployment memory deployment
  ) internal view override returns (AaveV4BabylonConfig.ExternalSpoke[] memory) {
    return
      AaveV4BabylonConfig.parseExternalSpokes({
        json: _marketJson,
        config: config,
        deployment: deployment
      });
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

contract AaveV4DeployBabylonTokenizationHarness is AaveV4DeployBabylonTokenization {
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

  /// @dev Updates the config report in place, so the next steps read the TokenizationSpokes.
  function _outputReport(
    AaveV4BabylonConfig.Config memory config
  ) internal pure override returns (string memory) {
    return config.report;
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

  // tests link the libraries foundry deploys, not the ones at the config salt
  function _verifyLibraries(
    AaveV4BabylonConfig.Config memory,
    AaveV4BabylonConfig.Deployment memory
  ) internal view override {}
}

contract AaveV4BabylonTest is Create2TestHelper {
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
  address internal constant BABYLON_TEST_DEPLOYER = 0x2045C7414b28A37EDe726498920E06Ad07894Ac1;
  address internal constant BABYLON_MAINNET_DEPLOYER = 0x4df5D09841A716391E00fB9B118f3FaBCFD4c8D1;
  address internal constant SEPOLIA_BABYLON_DEPLOYER = 0x445Dfdc71003f000455BF3f7f1EcBA5D46CBBB91;
  address internal constant CREATEX = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;
  /// @dev CreateX's guarded salt of the Sepolia AaveAdapter proxy, which CreateX on Sepolia maps to
  /// `SEPOLIA_AAVE_ADAPTER`.
  bytes32 internal constant SEPOLIA_ADAPTER_GUARDED_SALT =
    0x4caf100053574dceefa50d90c3de863dc3d04a7c728813d8ad2daae76037bdd8;

  address internal _deployer = DEFAULT_SENDER;
  string internal _reportName = REPORT_NAME;
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
      deployer: _deployer,
      hubLabels: hubLabels,
      babylonSpokeLabel: 'babylon',
      liquidationManager: _liquidationManager,
      liquidationManagerDeployer: address(0),
      liquidationManagerSalt: bytes32(0),
      managedCollateralReserveId: 0,
      admin: _admin,
      authority: address(0),
      feeReceiver: address(0),
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
    assertEq(config.deployer, BABYLON_TEST_DEPLOYER);
    assertEq(config.liquidationManager, SEPOLIA_AAVE_ADAPTER);
    assertEq(config.liquidationManagerDeployer, SEPOLIA_BABYLON_DEPLOYER);
    assertEq(config.liquidationManagerSalt, keccak256('testnet-3.sepolia'));
    assertEq(config.managedCollateralReserveId, 0);
    assertEq(config.admin, SEPOLIA_ADMIN);
    assertEq(config.authority, address(0));
    assertEq(config.feeReceiver, address(0));
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
    assertEq(config.deployer, BABYLON_TEST_DEPLOYER);
    assertEq(config.liquidationManager, MAINNET_TEST_AAVE_ADAPTER);
    assertEq(config.liquidationManagerDeployer, address(0));
    assertEq(config.liquidationManagerSalt, bytes32(0));
    assertEq(config.managedCollateralReserveId, 0);
    assertEq(config.admin, SEPOLIA_ADMIN);
    assertEq(config.authority, address(0));
    assertEq(config.feeReceiver, address(0));
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
    AaveV4DeployBabylonSpokeHarness harness = new AaveV4DeployBabylonSpokeHarness(_config, true);
    vm.expectRevert('config libraries not deployed');
    harness.requireConfigLibraries(keccak256('aave-v4-babylon-mainnet-test-libraries-v1'));
  }

  function test_containsAddress() public {
    AaveV4DeployBabylonSpokeHarness harness = new AaveV4DeployBabylonSpokeHarness(_config, true);
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
    AaveV4BabylonConfig.Config memory config = AaveV4BabylonConfig.read('sepolia');
    OrchestrationReports.FullDeploymentReport memory report = this.deployAs(
      config,
      config.deployer
    );

    IBabylonSpoke babylonSpoke = IBabylonSpoke(
      report.babylonSpokeInstanceBatchReports[0].report.spokeProxy
    );
    assertEq(babylonSpoke.LIQUIDATION_MANAGER(), SEPOLIA_AAVE_ADAPTER);
    assertEq(babylonSpoke.MANAGED_COLLATERAL_RESERVE_ID(), 0);
  }

  function test_deployInputs() public {
    InputUtils.FullDeployInputs memory inputs = new AaveV4DeployBabylonHubHarness(_config)
      .sanitizedDeployInputs(_deployer);

    assertFalse(inputs.grantRoles);
    assertEq(inputs.proxyAdminOwner, _deployer);
    assertEq(inputs.treasurySpokeOwner, _deployer);
    assertEq(inputs.hubLabels.length, 2);
    assertEq(inputs.hubLabels[0], 'babylon-btc');
    assertEq(inputs.hubLabels[1], 'babylon-stables');
    assertEq(inputs.spokeLabels.length, 0);
    assertEq(inputs.babylonSpokeLabels.length, 0);
    assertEq(inputs.babylonLiquidationManagers.length, 0);
    assertEq(inputs.babylonManagedCollateralReserveIds.length, 0);
    assertFalse(inputs.deployNativeTokenGateway);
    assertFalse(inputs.deploySignatureGateway);
    assertFalse(inputs.deployPositionManagers);
    assertEq(inputs.salt, keccak256('aave-v4-babylon-v2'));
  }

  function test_deploy() public {
    OrchestrationReports.FullDeploymentReport memory report = this.deploy(_config);

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

  function test_deployHubs_withoutBabylonSpoke() public {
    OrchestrationReports.FullDeploymentReport memory report = this.deployHubsAs(_config, _deployer);

    assertEq(report.hubInstanceBatchReports.length, 2);
    assertEq(report.spokeInstanceBatchReports.length, 0);
    assertEq(report.babylonSpokeInstanceBatchReports.length, 0);
    address accessManager = report.authorityBatchReport.accessManager;
    for (uint256 i; i < 2; ++i) {
      address hub = report.hubInstanceBatchReports[i].report.hubProxy;
      assertEq(IAccessManaged(hub).authority(), accessManager);
      assertEq(_proxyAdmin(hub).owner(), _deployer);
    }
    (bool deployerIsAdmin, ) = IAccessManagerEnumerable(accessManager).hasRole(
      Roles.ACCESS_MANAGER_ADMIN_ROLE,
      _deployer
    );
    assertTrue(deployerIsAdmin);
  }

  function test_deployHub_run() public {
    uint256 snapshot = vm.snapshotState();
    OrchestrationReports.FullDeploymentReport memory expected = this.deployHubsAs(
      _config,
      _deployer
    );
    vm.revertToState(snapshot);
    address hub = expected.hubInstanceBatchReports[0].report.hubProxy;
    assertEq(hub.code.length, 0);

    new AaveV4DeployBabylonHubHarness(_config).run();

    assertEq(
      IAccessManaged(hub).authority(),
      expected.authorityBatchReport.accessManager,
      'hub authority'
    );
    assertEq(_proxyAdmin(hub).owner(), _deployer, 'hub proxy admin owner');
    assertGt(
      expected.hubInstanceBatchReports[1].report.hubProxy.code.length,
      0,
      'second hub deployed'
    );
  }

  /// @dev The split deployment puts the BabylonSpoke where the single-step deployment did.
  function test_deploySpoke_matchesSingleStepDeployment() public {
    uint256 snapshot = vm.snapshotState();
    InputUtils.FullDeployInputs memory inputs = new AaveV4DeployBabylonHubHarness(_config)
      .sanitizedDeployInputs(_deployer);
    inputs.babylonSpokeLabels = new string[](1);
    inputs.babylonSpokeLabels[0] = _config.babylonSpokeLabel;
    inputs.babylonLiquidationManagers = new address[](1);
    inputs.babylonLiquidationManagers[0] = _liquidationManager;
    inputs.babylonManagedCollateralReserveIds = new uint256[](1);
    BatchReports.SpokeInstanceBatchReport memory singleStep = this
      .deployInputs(inputs)
      .babylonSpokeInstanceBatchReports[0]
      .report;
    vm.revertToState(snapshot);

    OrchestrationReports.FullDeploymentReport memory report = this.deploy(_config);

    BatchReports.SpokeInstanceBatchReport memory split = report
      .babylonSpokeInstanceBatchReports[0]
      .report;
    assertEq(split.spokeProxy, singleStep.spokeProxy);
    assertEq(split.spokeImplementation, singleStep.spokeImplementation);
    assertEq(split.aaveOracle, singleStep.aaveOracle);
  }

  function test_deploySpoke_run() public {
    OrchestrationReports.FullDeploymentReport memory hubs = _deployHubsAndWriteReport(
      'babylon-split-run-test'
    );
    address accessManager = hubs.authorityBatchReport.accessManager;

    new AaveV4DeployBabylonSpokeHarness(_config, true).run();

    AaveV4BabylonConfig.Deployment memory deployment = AaveV4BabylonConfig.readDeployment(_config);
    assertEq(deployment.accessManager, accessManager);
    assertEq(deployment.hubs[0], hubs.hubInstanceBatchReports[0].report.hubProxy);
    assertEq(deployment.hubs[1], hubs.hubInstanceBatchReports[1].report.hubProxy);
    assertEq(deployment.treasurySpoke, hubs.treasurySpokeBatchReport.treasurySpoke);
    address babylonSpoke = deployment.babylonSpoke;
    assertEq(IBabylonSpoke(babylonSpoke).LIQUIDATION_MANAGER(), _liquidationManager);
    assertEq(IBabylonSpoke(babylonSpoke).MANAGED_COLLATERAL_RESERVE_ID(), 0);
    assertEq(IAccessManaged(babylonSpoke).authority(), accessManager);
    assertEq(_proxyAdmin(babylonSpoke).owner(), _deployer);
    assertEq(ISpoke(babylonSpoke).ORACLE(), deployment.oracle);
    _assertTargetRole(
      accessManager,
      babylonSpoke,
      Roles.getSpokeConfiguratorRoleSelectors(),
      Roles.SPOKE_CONFIGURATOR_ROLE
    );
    _assertTargetRole(
      accessManager,
      babylonSpoke,
      Roles.getSpokePositionUpdaterRoleSelectors(),
      Roles.SPOKE_USER_POSITION_UPDATER_ROLE
    );
  }

  function test_deploySpoke_run_revertsWith_babylonSpokeAlreadyInReport() public {
    _deployHubsAndWriteReport('babylon-split-twice-test');
    AaveV4DeployBabylonSpokeHarness harness = new AaveV4DeployBabylonSpokeHarness(_config, true);
    harness.run();
    vm.expectRevert('babylon spoke already in report');
    harness.run();
  }

  function test_deploySpoke_run_revertsWith_hubAuthority() public {
    OrchestrationReports.FullDeploymentReport memory hubs = _deployHubsAndWriteReport(
      'babylon-split-authority-test'
    );
    vm.writeJson(
      string.concat('"', vm.toString(hubs.configuratorBatchReport.hubConfigurator), '"'),
      _config.report,
      '.accessManager'
    );
    AaveV4DeployBabylonSpokeHarness harness = new AaveV4DeployBabylonSpokeHarness(_config, true);
    vm.expectRevert('hub authority');
    harness.run();
  }

  function test_deploySpoke_run_revertsWith_broadcasterNotDeployer() public {
    _deployHubsAndWriteReport('babylon-split-broadcaster-test');
    AaveV4BabylonConfig.Config memory config = _config;
    config.deployer = makeAddr('other deployer');
    AaveV4DeployBabylonSpokeHarness harness = new AaveV4DeployBabylonSpokeHarness(config, true);
    vm.expectRevert('broadcaster is not the config deployer');
    harness.run();
  }

  function test_deploySpoke_run_revertsWith_liquidationManagerDeployerUnsetOnEthereum() public {
    _deployHubsAndWriteReport('babylon-split-createx-test');
    vm.chainId(1);
    AaveV4DeployBabylonSpokeHarness harness = new AaveV4DeployBabylonSpokeHarness(_config, false);
    vm.expectRevert('liquidation manager deployer unset');
    harness.run();
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

  function test_externalSpoke_configureHandoverVerify() public {
    string memory json = _sepoliaJsonWithExternalSpoke();
    _deployAndWriteReport();
    _deploySepoliaTokensAndFeeds();
    new AaveV4BabylonConfigureHarness(_config, json).run();
    AaveV4BabylonConfig.Deployment memory deployment = AaveV4BabylonConfig.readDeployment(_config);

    IHub hub = IHub(deployment.hubs[1]);
    uint256 assetId = hub.getAssetId(SEPOLIA_WBTC);
    assertTrue(hub.isSpokeListed(assetId, _externalSpoke));
    assertEq(
      abi.encode(hub.getSpokeConfig(assetId, _externalSpoke)),
      abi.encode(_externalSpokeConfig())
    );

    AaveV4BabylonHandoverHarness handover = new AaveV4BabylonHandoverHarness(_config);
    handover.setMarketJson(json);
    handover.run();
    vm.prank(_admin);
    Ownable2StepUpgradeable(deployment.treasurySpoke).acceptOwnership();
    new AaveV4BabylonVerifyHarness(_config, json).run();
  }

  function test_verifyMarketConfig_revertsWith_externalSpokeConfig() public {
    string memory json = _sepoliaJsonWithExternalSpoke();
    _deployAndWriteReport();
    _deploySepoliaTokensAndFeeds();
    new AaveV4BabylonConfigureHarness(_config, json).run();
    AaveV4BabylonConfig.Deployment memory deployment = AaveV4BabylonConfig.readDeployment(_config);

    IHub hub = IHub(deployment.hubs[1]);
    uint256 assetId = hub.getAssetId(SEPOLIA_WBTC);
    vm.prank(_deployer);
    IHubConfigurator(deployment.hubConfigurator).updateSpokeDrawCap({
      hub: address(hub),
      assetId: assetId,
      spoke: _externalSpoke,
      drawCap: 101
    });
    vm.expectRevert('external spoke config');
    this.verifyMarketConfigJson(deployment, json);
  }

  function test_handover_revertsWith_unconfiguredExternalSpoke() public {
    _deployAndWriteReport();
    _deploySepoliaTokensAndFeeds();
    new AaveV4BabylonConfigureHarness(_config, _sepoliaJsonWithExternalSpoke()).run();
    AaveV4BabylonHandoverHarness handover = new AaveV4BabylonHandoverHarness(_config);
    vm.expectRevert('not a transparent proxy');
    handover.run();
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

  /// @dev Babylon's mocks and price feeds on the ARFC layout and risk parameters.
  function test_mainnetTestMarketConfig() public {
    AaveV4BabylonConfig.Deployment memory deployment;
    deployment.hubs = new address[](2);
    deployment.hubs[0] = makeAddr('babylon-btc');
    deployment.hubs[1] = makeAddr('babylon-stables');
    deployment.irStrategies = new address[](2);
    AaveV4BabylonConfig.MarketConfig memory marketConfig = this.parseMarketConfig(
      vm.readFile('scripts/markets/babylon/config/mainnet-test.json'),
      deployment
    );

    address vaultBtc = 0xb754C46a7975f3B5b834ac7e6eD6aBE87042462B;
    address usdt = 0x9585a58004b1ef6b994940AeF65b48e10EAF0f2e;
    address usdc = 0x80E8127F482eC1d75408aD7BD83f7fD3Ecb043AA;
    address wbtc = 0x549A9C66B3d310A0cb706B8Efacf46bb13Abf210;
    address usdFeed = 0xE12149A586c4548328b82F838E1e459F2a02d6E8;
    address btcFeed = 0xbd8c6A609e0D239C0a04cA4D4D526A61fE661bDC;

    AaveV4BabylonConfig.ReserveListing[] memory reserves = marketConfig.reserves;
    assertEq(reserves.length, 7);
    _assertMainnetTestReserve(reserves[0], deployment.hubs[0], vaultBtc, btcFeed, 300, 0, false);
    _assertMainnetTestReserve(
      reserves[1],
      deployment.hubs[0],
      usdt,
      usdFeed,
      5_000_000,
      5_000_000,
      true
    );
    _assertMainnetTestReserve(
      reserves[2],
      deployment.hubs[0],
      usdc,
      usdFeed,
      5_000_000,
      5_000_000,
      true
    );
    _assertMainnetTestReserve(reserves[3], deployment.hubs[0], wbtc, btcFeed, 100, 100, true);
    _assertMainnetTestReserve(
      reserves[4],
      deployment.hubs[1],
      usdt,
      usdFeed,
      8_000_000,
      8_000_000,
      true
    );
    _assertMainnetTestReserve(
      reserves[5],
      deployment.hubs[1],
      usdc,
      usdFeed,
      8_000_000,
      8_000_000,
      true
    );
    _assertMainnetTestReserve(reserves[6], deployment.hubs[1], wbtc, btcFeed, 100, 0, false);

    assertEq(reserves[0].dynamicConfig.collateralFactor, 78_00);
    assertEq(reserves[0].dynamicConfig.maxLiquidationBonus, 105_55);
    for (uint256 i = 1; i < reserves.length; ++i) {
      assertEq(reserves[i].dynamicConfig.collateralFactor, 0);
    }

    uint16[7] memory liquidityFees = [0, 10_00, 10_00, 20_00, 10_00, 10_00, 20_00];
    // optimal usage ratio, base drawn rate, growth before and after optimal, in BPS
    uint32[4][7] memory irData = [
      [uint32(99_00), 0, 0, 0],
      [uint32(92_00), 0, 4_50, 20_00],
      [uint32(92_00), 0, 4_50, 20_00],
      [uint32(80_00), 25, 4_00, 60_00],
      [uint32(92_00), 0, 4_50, 20_00],
      [uint32(92_00), 0, 5_00, 20_00],
      [uint32(80_00), 25, 4_00, 60_00]
    ];
    for (uint256 i; i < reserves.length; ++i) {
      assertEq(reserves[i].liquidityFee, liquidityFees[i]);
      assertEq(reserves[i].irData.optimalUsageRatio, irData[i][0]);
      assertEq(reserves[i].irData.baseDrawnRate, irData[i][1]);
      assertEq(reserves[i].irData.rateGrowthBeforeOptimal, irData[i][2]);
      assertEq(reserves[i].irData.rateGrowthAfterOptimal, irData[i][3]);
    }

    assertEq(marketConfig.externalSpokes.length, 1);
    assertEq(marketConfig.externalSpokes[0].hub, deployment.hubs[1]);
    assertEq(marketConfig.externalSpokes[0].underlying, wbtc);
    assertEq(marketConfig.externalSpokes[0].spoke, 0xA5f877cEfEAA7534460f19d7fc8b76CdE820a92A);
    assertEq(
      abi.encode(marketConfig.externalSpokes[0].spokeConfig),
      abi.encode(
        IHub.SpokeConfig({
          addCap: 0,
          drawCap: 100,
          riskPremiumThreshold: 0,
          active: true,
          halted: false
        })
      )
    );

    assertEq(marketConfig.liquidationConfig.targetHealthFactor, 1e18);
    assertEq(marketConfig.liquidationConfig.healthFactorForMaxBonus, 0.9e18);
    assertEq(marketConfig.liquidationConfig.liquidationBonusFactor, 90_00);
  }

  function _assertMainnetTestReserve(
    AaveV4BabylonConfig.ReserveListing memory listing,
    address hub,
    address underlying,
    address priceSource,
    uint256 addCap,
    uint256 drawCap,
    bool borrowable
  ) internal pure {
    assertEq(listing.hub, hub);
    assertEq(listing.underlying, underlying);
    assertEq(listing.priceSource, priceSource);
    assertEq(listing.spokeConfig.addCap, addCap);
    assertEq(listing.spokeConfig.drawCap, drawCap);
    assertEq(listing.spokeConfig.riskPremiumThreshold, 0);
    assertTrue(listing.spokeConfig.active);
    assertFalse(listing.spokeConfig.halted);
    assertEq(listing.reserveConfig.borrowable, borrowable);
    assertEq(listing.dynamicConfig.liquidationFee, 0);
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
  function test_configure_unconnectedReserve() public {
    _deployAndWriteReport();
    _deploySepoliaTokensAndFeeds();
    new AaveV4BabylonConfigureHarness(_config, _sepoliaJsonWithTokenization()).run();

    AaveV4BabylonConfig.Deployment memory deployment = AaveV4BabylonConfig.readDeployment(_config);
    IHub hub = IHub(deployment.hubs[0]);
    uint256 assetId = hub.getAssetId(SEPOLIA_USDC);
    assertFalse(hub.isSpokeListed(assetId, deployment.babylonSpoke), 'babylon spoke not connected');
    assertEq(hub.getSpokeCount(assetId), 1, 'only the fee receiver');
    ISpoke.Reserve memory reserve = ISpoke(deployment.babylonSpoke).getReserve(1);
    assertEq(address(reserve.hub), address(hub), 'reserve hub');
    assertEq(reserve.assetId, assetId, 'reserve asset id');
    assertTrue(
      hub.isSpokeListed(hub.getAssetId(SEPOLIA_BTC), deployment.babylonSpoke),
      'connected reserve'
    );
  }

  function test_verifyMarketConfig_revertsWith_unconnectedReserveConnected() public {
    _deployAndWriteReport();
    _deploySepoliaTokensAndFeeds();
    string memory json = _sepoliaJsonWithTokenization();
    new AaveV4BabylonConfigureHarness(_config, json).run();
    AaveV4BabylonConfig.Deployment memory deployment = AaveV4BabylonConfig.readDeployment(_config);
    uint256 assetId = IHub(deployment.hubs[0]).getAssetId(SEPOLIA_USDC);
    IHub.SpokeConfig memory spokeConfig = _externalSpokeConfig();
    vm.prank(_deployer);
    IHubConfigurator(deployment.hubConfigurator).addSpoke({
      hub: deployment.hubs[0],
      spoke: deployment.babylonSpoke,
      assetId: assetId,
      config: spokeConfig
    });
    vm.expectRevert('asset spoke count');
    this.verifyMarketConfigJson(deployment, json);
  }

  function test_deployTokenization() public {
    _useOwnReport('babylon-tokenization-test');
    AaveV4BabylonConfig.Deployment memory deployment = _configureForTokenization();
    new AaveV4DeployBabylonTokenizationHarness(_config, _sepoliaJsonWithTokenization()).run();

    _assertTokenizationSpoke({
      hub: deployment.hubs[0],
      underlying: SEPOLIA_USDC,
      name: 'Wrapped Aave Babylon BTC USDC',
      symbol: 'waBabylonBtcUSDC'
    });
    _assertTokenizationSpoke({
      hub: deployment.hubs[1],
      underlying: SEPOLIA_USDT,
      name: 'Wrapped Aave Babylon Stables USDT',
      symbol: 'waBabylonStablesUSDT'
    });
  }

  function test_deployTokenization_thenHandoverVerify() public {
    _useOwnReport('babylon-tokenization-verify-test');
    _configureForTokenization();
    string memory json = _sepoliaJsonWithTokenization();
    new AaveV4DeployBabylonTokenizationHarness(_config, json).run();
    new AaveV4BabylonHandoverHarness(_config).run();
    AaveV4BabylonConfig.Deployment memory deployment = AaveV4BabylonConfig.readDeployment(_config);
    vm.prank(_admin);
    Ownable2StepUpgradeable(deployment.treasurySpoke).acceptOwnership();

    new AaveV4BabylonVerifyHarness(_config, json).run();
  }

  function test_deployTokenization_revertsWith_alreadyInReport() public {
    _useOwnReport('babylon-tokenization-twice-test');
    _configureForTokenization();
    AaveV4DeployBabylonTokenizationHarness harness = new AaveV4DeployBabylonTokenizationHarness(
      _config,
      _sepoliaJsonWithTokenization()
    );
    harness.run();
    vm.expectRevert('tokenization spoke already in report');
    harness.run();
  }

  function test_deployTokenization_revertsWith_assetNotListed() public {
    _useOwnReport('babylon-tokenization-unlisted-test');
    _deployAndWriteReport();
    AaveV4DeployBabylonTokenizationHarness harness = new AaveV4DeployBabylonTokenizationHarness(
      _config,
      _sepoliaJsonWithTokenization()
    );
    vm.expectRevert(IHub.AssetNotListed.selector);
    harness.run();
  }

  function test_deployTokenization_revertsWith_broadcasterNotDeployer() public {
    _useOwnReport('babylon-tokenization-broadcaster-test');
    _configureForTokenization();
    AaveV4BabylonConfig.Config memory config = _config;
    config.deployer = makeAddr('other deployer');
    AaveV4DeployBabylonTokenizationHarness harness = new AaveV4DeployBabylonTokenizationHarness(
      config,
      _sepoliaJsonWithTokenization()
    );
    vm.expectRevert('broadcaster is not the config deployer');
    harness.run();
  }

  function test_deployTokenization_revertsWith_noTokenizationSpokes() public {
    _useOwnReport('babylon-tokenization-none-test');
    _configureForTokenization();
    AaveV4DeployBabylonTokenizationHarness harness = new AaveV4DeployBabylonTokenizationHarness(
      _config,
      vm.readFile(SEPOLIA_CONFIG)
    );
    vm.expectRevert('no tokenization spokes');
    harness.run();
  }

  function test_verify_revertsWith_tokenizationSpokeNotDeployed() public {
    _useOwnReport('babylon-tokenization-missing-test');
    _configureForTokenization();
    new AaveV4BabylonHandoverHarness(_config).run();
    AaveV4BabylonConfig.Deployment memory deployment = AaveV4BabylonConfig.readDeployment(_config);
    vm.prank(_admin);
    Ownable2StepUpgradeable(deployment.treasurySpoke).acceptOwnership();

    AaveV4BabylonVerifyHarness verifier = new AaveV4BabylonVerifyHarness(
      _config,
      _sepoliaJsonWithTokenization()
    );
    vm.expectRevert('tokenization spoke not deployed');
    verifier.run();
  }

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

  function verifyMarketConfigJson(
    AaveV4BabylonConfig.Deployment memory deployment,
    string memory json
  ) external view {
    AaveV4BabylonVerification.verifyMarketConfig({
      deployment: deployment,
      marketConfig: AaveV4BabylonConfig.parseMarketConfig({
        json: json,
        config: _config,
        deployment: deployment
      }),
      feeReceiver: deployment.treasurySpoke
    });
  }

  function verifyMarketConfig(AaveV4BabylonConfig.Deployment memory deployment) external view {
    AaveV4BabylonVerification.verifyMarketConfig({
      deployment: deployment,
      marketConfig: AaveV4BabylonConfig.parseMarketConfig({
        json: vm.readFile(SEPOLIA_CONFIG),
        config: _config,
        deployment: deployment
      }),
      feeReceiver: deployment.treasurySpoke
    });
  }

  function readConfig(
    string memory name
  ) external view returns (AaveV4BabylonConfig.Config memory) {
    return AaveV4BabylonConfig.read(name);
  }

  function deploy(
    AaveV4BabylonConfig.Config memory config
  ) external returns (OrchestrationReports.FullDeploymentReport memory) {
    return this.deployAs(config, _deployer);
  }

  function _deployAndWriteReport()
    internal
    returns (OrchestrationReports.FullDeploymentReport memory report)
  {
    report = this.deploy(_config);
    _writeReport(report, _reportName);
  }

  /// @dev Writes to its own report, since tests run in parallel and the others read the full one.
  function _deployHubsAndWriteReport(
    string memory reportName
  ) internal returns (OrchestrationReports.FullDeploymentReport memory report) {
    _config.report = string.concat(
      OUTPUT_DIR,
      vm.toString(block.chainid),
      '-',
      reportName,
      '.json'
    );
    report = this.deployHubsAs(_config, _deployer);
    _writeReport(report, reportName);
  }

  function _writeReport(
    OrchestrationReports.FullDeploymentReport memory report,
    string memory reportName
  ) internal {
    vm.createDir(OUTPUT_DIR, true);
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);
    logger.writeJsonReportMarket(report);
    logger.save({fileName: reportName, withTimestamp: false});
  }

  function _assertTargetRole(
    address accessManager,
    address target,
    bytes4[] memory selectors,
    uint64 roleId
  ) internal view {
    for (uint256 i; i < selectors.length; ++i) {
      assertEq(IAccessManager(accessManager).getTargetFunctionRole(target, selectors[i]), roleId);
    }
  }

  function _proxyAdmin(address proxy) internal view returns (ProxyAdmin) {
    return ProxyAdmin(ProxyHelper.getProxyAdmin(proxy));
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
        connected: true,
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

  address internal _externalSpoke = makeAddr('btcVaultSwap');

  function _externalSpokeConfig() internal pure returns (IHub.SpokeConfig memory) {
    return
      IHub.SpokeConfig({
        addCap: 0,
        drawCap: 100,
        riskPremiumThreshold: 0,
        active: true,
        halted: false
      });
  }

  /// @dev The Sepolia config with a spoke connected to WBTC on `babylon-stables`.
  function _sepoliaJsonWithExternalSpoke() internal view returns (string memory) {
    return
      vm.replace(
        vm.readFile(SEPOLIA_CONFIG),
        '"liquidationConfig"',
        string.concat(
          '"externalSpokes": [{"hub": "babylon-stables", "underlying": "',
          vm.toString(SEPOLIA_WBTC),
          '", "spoke": "',
          vm.toString(_externalSpoke),
          '", "spokeConfig": {"addCap": 0, "drawCap": 100, "riskPremiumThreshold": 0, "active": true, "halted": false}}],\n  "liquidationConfig"'
        )
      );
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

  address internal constant ETHEREUM_AAVE_ADAPTER = 0xadca531564f3B26d0aAF48a044d741fD6cD571Ea;
  address internal constant ETHEREUM_V4_SECURITY_COUNCIL =
    0x187AAE17d4931310B3fc75743e7F16Bdc9eD77e9;
  address internal constant ETHEREUM_ACCESS_MANAGER = 0x08aE3BE30958cDd1847ec58fFfd4C451a87fDF01;
  address internal constant ETHEREUM_TREASURY_SPOKE = 0xB9B0b8616f6Bf6841972a52058132BE08d723155;
  address internal constant ETHEREUM_CORE_HUB = 0xCca852Bc40e560adC3b1Cc58CA5b55638ce826c9;
  address internal constant ETHEREUM_USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
  address internal constant ETHEREUM_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address internal constant ETHEREUM_GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
  address internal constant ETHEREUM_WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
  address internal constant ETHEREUM_USDG = 0xe343167631d89B6Ffc58B88d6b7fB0228795491D;
  address internal constant ETHEREUM_RLUSD = 0x8292Bb45bf1Ee4d140127049757C2E0fF06317eD;
  address internal constant ETHEREUM_BTC_USD_SVR_FEED = 0xb41E773f507F7a7EA890b1afB7d2b660c30C8B0A;
  address internal constant ETHEREUM_USDT_FEED = 0x260326c220E469358846b187eE53328303Efe19C;
  address internal constant ETHEREUM_USDC_FEED = 0x3f73F03aa83B2A48ed27E964eD0fDb590332095B;
  address internal constant ETHEREUM_GHO_FEED = 0xD110cac5d8682A3b045D5524a9903E031d70FCCd;
  address internal constant ETHEREUM_WBTC_FEED = 0xDaa4B74C6bAc4e25188e64ebc68DB5050b690cAc;
  address internal constant ETHEREUM_USDG_FEED = 0x83D20dEEdcd4aC1313496c8CBcAad0fa298c0CE4;
  address internal constant ETHEREUM_RLUSD_FEED = 0xf0eaC18E908B34770FDEe46d069c846bDa866759;
  string internal constant MAINNET_CONFIG = 'scripts/markets/babylon/config/mainnet.json';

  address internal _governance = makeAddr('governance');

  /// @dev The production market from the LlamaRisk parameters, with the Babylon AaveAdapter Babylon precomputed.
  function test_mainnetConfig() public {
    vm.chainId(1);
    AaveV4BabylonConfig.Config memory config = AaveV4BabylonConfig.read('mainnet');
    assertEq(config.chainId, 1);
    assertEq(config.salt, keccak256('aave-v4-babylon-mainnet-v1'));
    // the canonical salt, so LiquidationLogic is the live AaveV4EthereumExternalLibraries.LIQUIDATION_LOGIC
    assertEq(config.librarySalt, CANONICAL_LIBRARY_SALT);
    assertEq(config.deployer, BABYLON_MAINNET_DEPLOYER);
    assertEq(config.hubLabels.length, 1);
    assertEq(config.hubLabels[0], 'babylon');
    assertEq(config.babylonSpokeLabel, 'babylon');
    assertEq(config.liquidationManager, ETHEREUM_AAVE_ADAPTER);
    assertEq(config.managedCollateralReserveId, 0);
    assertEq(config.admin, ETHEREUM_V4_SECURITY_COUNCIL);
    assertEq(config.authority, ETHEREUM_ACCESS_MANAGER);
    assertEq(config.feeReceiver, ETHEREUM_TREASURY_SPOKE);
    assertEq(config.report, 'scripts/markets/babylon/reports/mainnet.json');
  }

  /// @dev Every reserve against the LlamaRisk tables, with the Babylon Hub spoke configs inactive.
  function test_mainnetMarketConfig() public {
    address vaultBtc = makeAddr('vaultBTC');
    _useMainnetHubLabels();
    AaveV4BabylonConfig.Deployment memory deployment;
    deployment.hubs = new address[](1);
    deployment.hubs[0] = makeAddr('babylon hub');
    deployment.irStrategies = new address[](1);
    deployment.irStrategies[0] = makeAddr('babylon hub irStrategy');
    AaveV4BabylonConfig.MarketConfig memory marketConfig = this.parseMarketConfig(
      _mainnetJsonWithVaultBtc(vaultBtc),
      deployment
    );

    IAssetInterestRateStrategy.InterestRateData memory stables = IAssetInterestRateStrategy
      .InterestRateData({
        optimalUsageRatio: 92_00,
        baseDrawnRate: 0,
        rateGrowthBeforeOptimal: 4_50,
        rateGrowthAfterOptimal: 20_00
      });
    AaveV4BabylonConfig.ReserveListing[] memory expected = new AaveV4BabylonConfig.ReserveListing[](
      5
    );
    expected[0] = _mainnetListing({
      deployment: deployment,
      underlying: vaultBtc,
      priceSource: ETHEREUM_BTC_USD_SVR_FEED,
      liquidityFee: 0,
      irData: IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 99_00,
        baseDrawnRate: 0,
        rateGrowthBeforeOptimal: 0,
        rateGrowthAfterOptimal: 0
      }),
      borrowable: false,
      collateralFactor: 78_00,
      maxLiquidationBonus: 105_55
    });
    expected[1] = _mainnetListing({
      deployment: deployment,
      underlying: ETHEREUM_USDT,
      priceSource: ETHEREUM_USDT_FEED,
      liquidityFee: 10_00,
      irData: stables,
      borrowable: true,
      collateralFactor: 0,
      maxLiquidationBonus: 100_00
    });
    expected[2] = _mainnetListing({
      deployment: deployment,
      underlying: ETHEREUM_USDC,
      priceSource: ETHEREUM_USDC_FEED,
      liquidityFee: 10_00,
      irData: stables,
      borrowable: true,
      collateralFactor: 0,
      maxLiquidationBonus: 100_00
    });
    expected[3] = _mainnetListing({
      deployment: deployment,
      underlying: ETHEREUM_GHO,
      priceSource: ETHEREUM_GHO_FEED,
      liquidityFee: 10_00,
      irData: stables,
      borrowable: true,
      collateralFactor: 0,
      maxLiquidationBonus: 100_00
    });
    expected[4] = _mainnetListing({
      deployment: deployment,
      underlying: ETHEREUM_WBTC,
      priceSource: ETHEREUM_WBTC_FEED,
      liquidityFee: 20_00,
      irData: IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 80_00,
        baseDrawnRate: 25,
        rateGrowthBeforeOptimal: 4_00,
        rateGrowthAfterOptimal: 60_00
      }),
      borrowable: true,
      collateralFactor: 0,
      maxLiquidationBonus: 100_00
    });
    _assertListings(marketConfig.reserves, expected);

    // the Core Hub credit lines, WBTC excluded since the exit reserve is the Babylon Hub WBTC
    address[5] memory externalUnderlyings = [
      ETHEREUM_USDT,
      ETHEREUM_USDC,
      ETHEREUM_GHO,
      ETHEREUM_USDG,
      ETHEREUM_RLUSD
    ];
    address[5] memory externalFeeds = [
      ETHEREUM_USDT_FEED,
      ETHEREUM_USDC_FEED,
      ETHEREUM_GHO_FEED,
      ETHEREUM_USDG_FEED,
      ETHEREUM_RLUSD_FEED
    ];
    assertEq(marketConfig.externalReserves.length, 5);
    for (uint256 i; i < 5; ++i) {
      assertEq(
        abi.encode(marketConfig.externalReserves[i]),
        abi.encode(
          AaveV4BabylonConfig.ExternalReserve({
            hub: ETHEREUM_CORE_HUB,
            underlying: externalUnderlyings[i],
            priceSource: externalFeeds[i],
            reserveConfig: ISpoke.ReserveConfig({
              collateralRisk: 0,
              paused: false,
              frozen: false,
              borrowable: true,
              receiveSharesEnabled: false
            }),
            dynamicConfig: ISpoke.DynamicReserveConfig({
              collateralFactor: 0,
              maxLiquidationBonus: 100_00,
              liquidationFee: 0
            })
          })
        )
      );
    }

    assertEq(marketConfig.externalSpokes.length, 0);

    // LlamaRisk tokenized spokes on the Babylon Hub borrowable assets, named as every Ethereum V4
    // TokenizationSpoke
    address[4] memory tokenizedUnderlyings = [
      ETHEREUM_USDT,
      ETHEREUM_USDC,
      ETHEREUM_GHO,
      ETHEREUM_WBTC
    ];
    string[4] memory tokenizedSymbols = ['USDT', 'USDC', 'GHO', 'WBTC'];
    assertEq(marketConfig.tokenizationSpokes.length, 4);
    for (uint256 i; i < 4; ++i) {
      assertEq(
        abi.encode(marketConfig.tokenizationSpokes[i]),
        abi.encode(
          AaveV4BabylonConfig.TokenizationSpoke({
            hub: deployment.hubs[0],
            underlying: tokenizedUnderlyings[i],
            name: string.concat('Wrapped Aave Babylon ', tokenizedSymbols[i]),
            symbol: string.concat('waBabylon', tokenizedSymbols[i])
          })
        )
      );
    }

    assertEq(marketConfig.liquidationConfig.targetHealthFactor, 1e18);
    assertEq(marketConfig.liquidationConfig.healthFactorForMaxBonus, 0.9e18);
    assertEq(marketConfig.liquidationConfig.liquidationBonusFactor, 90_00);
  }

  function test_mainnetMarketConfig_revertsWith_vaultBtcUnset() public {
    _useMainnetHubLabels();
    AaveV4BabylonConfig.Deployment memory deployment;
    deployment.hubs = new address[](1);
    deployment.irStrategies = new address[](1);
    vm.expectRevert('reserve address unset');
    this.parseMarketConfig(vm.readFile(MAINNET_CONFIG), deployment);
  }

  function test_requireLiquidationManager() public {
    AaveV4BabylonConfig.Config memory config = _sepoliaAdapterConfig();
    _mockCreateX(SEPOLIA_ADAPTER_GUARDED_SALT, SEPOLIA_AAVE_ADAPTER);
    new AaveV4DeployBabylonSpokeHarness(config, true).requireLiquidationManager(config);
  }

  function test_requireLiquidationManager_revertsWith_notCreateXAddress() public {
    AaveV4BabylonConfig.Config memory config = _sepoliaAdapterConfig();
    config.liquidationManager = makeAddr('other adapter');
    _mockCreateX(SEPOLIA_ADAPTER_GUARDED_SALT, SEPOLIA_AAVE_ADAPTER);
    AaveV4DeployBabylonSpokeHarness harness = new AaveV4DeployBabylonSpokeHarness(config, true);
    vm.expectRevert('liquidation manager is not the createx address');
    harness.requireLiquidationManager(config);
  }

  function test_requireLiquidationManager_revertsWith_deployerUnsetOnEthereum() public {
    AaveV4DeployBabylonSpokeHarness harness = new AaveV4DeployBabylonSpokeHarness(_config, true);
    vm.chainId(1);
    vm.expectRevert('liquidation manager deployer unset');
    harness.requireLiquidationManager(_config);
  }

  function test_requireLiquidationManager_skipsUnsetDeployerOffEthereum() public {
    new AaveV4DeployBabylonSpokeHarness(_config, true).requireLiquidationManager(_config);
  }

  function test_deploy_revertsWith_broadcasterNotDeployer() public {
    AaveV4DeployBabylonHubHarness harness = new AaveV4DeployBabylonHubHarness(_config);
    vm.expectRevert('broadcaster is not the config deployer');
    harness.sanitizedDeployInputs(makeAddr('other deployer'));
  }

  function test_configure_revertsWith_broadcasterNotDeployer() public {
    _deployAndWriteReport();
    _deploySepoliaTokensAndFeeds();
    _config.deployer = makeAddr('other deployer');
    AaveV4BabylonConfigureHarness configure = new AaveV4BabylonConfigureHarness(
      _config,
      vm.readFile(SEPOLIA_CONFIG)
    );
    vm.expectRevert('broadcaster is not the config deployer');
    configure.run();
  }

  function test_handover_revertsWith_broadcasterNotDeployer() public {
    _deployAndWriteReport();
    _config.deployer = makeAddr('other deployer');
    AaveV4BabylonHandoverHarness handover = new AaveV4BabylonHandoverHarness(_config);
    vm.expectRevert('broadcaster is not the config deployer');
    handover.run();
  }

  /// @dev The production flow on a local stand-in for Ethereum: reserves on an external Hub, fee
  /// receiver and AccessManager of the external market, then the move to that AccessManager.
  function test_authority_configureHandoverVerify() public {
    (
      address externalHub,
      address externalAccessManager,
      address externalTreasury
    ) = _deployExternalMarket();
    _config.authority = externalAccessManager;
    _config.feeReceiver = externalTreasury;
    string memory json = _sepoliaJsonWithExternalReserves(externalHub);

    _deployAndWriteReport();
    new AaveV4BabylonConfigureHarness(_config, json).run();
    AaveV4BabylonConfig.Deployment memory deployment = AaveV4BabylonConfig.readDeployment(_config);

    ISpoke spoke = ISpoke(deployment.babylonSpoke);
    assertEq(spoke.getReserveCount(), 8);
    assertEq(address(spoke.getReserve(6).hub), externalHub);
    assertEq(spoke.getReserve(6).underlying, SEPOLIA_USDC);
    assertEq(address(spoke.getReserve(7).hub), externalHub);
    assertEq(spoke.getReserve(7).underlying, SEPOLIA_WBTC);
    assertFalse(IHub(externalHub).isSpokeListed(0, address(spoke)));
    for (uint256 i; i < deployment.hubs.length; ++i) {
      assertEq(IHub(deployment.hubs[i]).getAsset(0).feeReceiver, externalTreasury);
    }

    new AaveV4BabylonHandoverHarness(_config).run();

    IAccessManagerEnumerable accessManager = IAccessManagerEnumerable(deployment.accessManager);
    for (uint256 i; i < deployment.hubs.length; ++i) {
      assertEq(IAccessManaged(deployment.hubs[i]).authority(), externalAccessManager);
      assertEq(_proxyAdmin(deployment.hubs[i]).owner(), _admin);
    }
    assertEq(IAccessManaged(deployment.babylonSpoke).authority(), externalAccessManager);
    assertEq(_proxyAdmin(deployment.babylonSpoke).owner(), _admin);
    // the deployed TreasurySpoke is unused, the fee receiver is the external one
    assertEq(_proxyAdmin(deployment.treasurySpoke).owner(), _deployer);
    assertEq(Ownable2StepUpgradeable(deployment.treasurySpoke).owner(), _deployer);
    assertEq(Ownable2StepUpgradeable(deployment.treasurySpoke).pendingOwner(), address(0));

    (bool deployerIsAdmin, ) = accessManager.hasRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, _deployer);
    assertFalse(deployerIsAdmin);
    (bool adminIsAdmin, ) = accessManager.hasRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, _admin);
    assertFalse(adminIsAdmin);
    for (uint256 i; i < accessManager.getRoleCount(); ++i) {
      (bool hasRole, ) = accessManager.hasRole(accessManager.getRole(i), _deployer);
      assertFalse(hasRole);
    }

    // the deployer lost the market, the external AccessManager admin holds it
    IHub.SpokeConfig memory spokeConfig = IHub(deployment.hubs[0]).getSpokeConfig(
      0,
      deployment.babylonSpoke
    );
    spokeConfig.active = false;
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, _deployer)
    );
    vm.prank(_deployer);
    IHub(deployment.hubs[0]).updateSpokeConfig(0, deployment.babylonSpoke, spokeConfig);
    vm.prank(_governance);
    IHub(deployment.hubs[0]).updateSpokeConfig(0, deployment.babylonSpoke, spokeConfig);
    spokeConfig.active = true;
    vm.prank(_governance);
    IHub(deployment.hubs[0]).updateSpokeConfig(0, deployment.babylonSpoke, spokeConfig);

    new AaveV4BabylonVerifyHarness(_config, json).run();
  }

  function test_handover_revertsWith_authorityIsTheDeployedOne() public {
    OrchestrationReports.FullDeploymentReport memory report = _deployAndWriteReport();
    _config.authority = report.authorityBatchReport.accessManager;
    AaveV4BabylonHandoverHarness handover = new AaveV4BabylonHandoverHarness(_config);
    vm.expectRevert('authority is the deployed one');
    handover.run();
  }

  function test_handover_revertsWith_authorityWithoutCode() public {
    _deployAndWriteReport();
    _config.authority = makeAddr('no code');
    AaveV4BabylonHandoverHarness handover = new AaveV4BabylonHandoverHarness(_config);
    vm.expectRevert('authority code');
    handover.run();
  }

  function test_verify_revertsWith_authorityNotSwitched() public {
    _configureHandoverAndAccept();
    (, address externalAccessManager, ) = _deployExternalMarket();
    _config.authority = externalAccessManager;
    AaveV4BabylonVerifyHarness verifier = _verifier();
    vm.expectRevert('hub authority');
    verifier.run();
  }

  function test_handover_authority_revertsWith_strayRoleMember() public {
    (
      address externalHub,
      address externalAccessManager,
      address externalTreasury
    ) = _deployExternalMarket();
    _config.authority = externalAccessManager;
    _config.feeReceiver = externalTreasury;
    _deployAndWriteReport();
    new AaveV4BabylonConfigureHarness(_config, _sepoliaJsonWithExternalReserves(externalHub)).run();
    AaveV4BabylonConfig.Deployment memory deployment = AaveV4BabylonConfig.readDeployment(_config);
    vm.prank(_deployer);
    IAccessManager(deployment.accessManager).grantRole(
      Roles.HUB_FEE_MINTER_ROLE,
      makeAddr('stray'),
      0
    );
    AaveV4BabylonHandoverHarness handover = new AaveV4BabylonHandoverHarness(_config);
    vm.expectRevert('unexpected role members: 102');
    handover.run();
  }

  function _useMainnetHubLabels() internal {
    string[] memory hubLabels = new string[](1);
    hubLabels[0] = 'babylon';
    _config.hubLabels = hubLabels;
  }

  /// @dev The BabylonSpoke is not connected on the Babylon Hub before the launch AIP.
  function _mainnetListing(
    AaveV4BabylonConfig.Deployment memory deployment,
    address underlying,
    address priceSource,
    uint16 liquidityFee,
    IAssetInterestRateStrategy.InterestRateData memory irData,
    bool borrowable,
    uint16 collateralFactor,
    uint32 maxLiquidationBonus
  ) internal pure returns (AaveV4BabylonConfig.ReserveListing memory listing) {
    listing = _listing({
      hub: deployment.hubs[0],
      irStrategy: deployment.irStrategies[0],
      underlying: underlying,
      priceSource: priceSource,
      liquidityFee: liquidityFee,
      irData: irData,
      addCap: 0,
      drawCap: 0,
      borrowable: borrowable,
      collateralFactor: collateralFactor,
      maxLiquidationBonus: maxLiquidationBonus
    });
    listing.connected = false;
    listing.spokeConfig = IHub.SpokeConfig({
      addCap: 0,
      drawCap: 0,
      riskPremiumThreshold: 0,
      active: false,
      halted: false
    });
  }

  /// @dev The Sepolia config with reserve 1 left unconnected on its Hub and two TokenizationSpokes.
  function _sepoliaJsonWithTokenization() internal view returns (string memory json) {
    string memory reserve1SpokeConfig = string.concat(
      '"spokeConfig": {\n        "addCap": 50000,\n        "drawCap": 50000,\n',
      '        "riskPremiumThreshold": 16777215,\n        "active": true,\n',
      '        "halted": false\n      },\n      "reserveConfig"'
    );
    json = vm.readFile(SEPOLIA_CONFIG);
    assertEq(vm.split(json, reserve1SpokeConfig).length, 2, 'one reserve 1 spoke config');
    json = vm.replace(json, reserve1SpokeConfig, '"reserveConfig"');
    json = vm.replace(
      json,
      '"liquidationConfig"',
      string.concat(
        '"tokenizationSpokes": [{"hub": "babylon-btc", "underlying": "',
        vm.toString(SEPOLIA_USDC),
        '", "name": "Wrapped Aave Babylon BTC USDC", "symbol": "waBabylonBtcUSDC"}, ',
        '{"hub": "babylon-stables", "underlying": "',
        vm.toString(SEPOLIA_USDT),
        '", "name": "Wrapped Aave Babylon Stables USDT", "symbol": "waBabylonStablesUSDT"}],\n',
        '  "liquidationConfig"'
      )
    );
  }

  /// @dev Tests that add TokenizationSpokes to the report write their own, since tests run in parallel.
  function _useOwnReport(string memory reportName) internal {
    _reportName = reportName;
    _config.report = string.concat(
      OUTPUT_DIR,
      vm.toString(block.chainid),
      '-',
      reportName,
      '.json'
    );
  }

  function _configureForTokenization()
    internal
    returns (AaveV4BabylonConfig.Deployment memory deployment)
  {
    _deployAndWriteReport();
    _deploySepoliaTokensAndFeeds();
    new AaveV4BabylonConfigureHarness(_config, _sepoliaJsonWithTokenization()).run();
    deployment = AaveV4BabylonConfig.readDeployment(_config);
  }

  function _assertTokenizationSpoke(
    address hub,
    address underlying,
    string memory name,
    string memory symbol
  ) internal view {
    (address proxy, address implementation) = AaveV4BabylonConfig.readTokenizationSpoke(
      _config,
      symbol
    );
    ITokenizationSpoke tokenizationSpoke = ITokenizationSpoke(proxy);
    uint256 assetId = IHub(hub).getAssetId(underlying);
    assertEq(tokenizationSpoke.hub(), hub, 'tokenization spoke hub');
    assertEq(tokenizationSpoke.assetId(), assetId, 'tokenization spoke asset id');
    assertEq(tokenizationSpoke.asset(), underlying, 'tokenization spoke asset');
    assertEq(tokenizationSpoke.name(), name, 'tokenization spoke name');
    assertEq(tokenizationSpoke.symbol(), symbol, 'tokenization spoke symbol');
    assertEq(_proxyAdmin(proxy).owner(), _admin, 'tokenization spoke proxy admin owner');
    assertEq(
      ProxyHelper.getImplementation(proxy),
      implementation,
      'tokenization spoke implementation'
    );
    assertFalse(IHub(hub).isSpokeListed(assetId, proxy), 'tokenization spoke not connected');
  }

  function _mainnetJsonWithVaultBtc(address vaultBtc) internal view returns (string memory) {
    string memory json = vm.readFile(MAINNET_CONFIG);
    string memory placeholder = '"underlying": "0x0000000000000000000000000000000000000000"';
    assertEq(vm.split(json, placeholder).length, 2);
    return
      vm.replace(json, placeholder, string.concat('"underlying": "', vm.toString(vaultBtc), '"'));
  }

  function _sepoliaAdapterConfig()
    internal
    view
    returns (AaveV4BabylonConfig.Config memory config)
  {
    config = _config;
    config.liquidationManager = SEPOLIA_AAVE_ADAPTER;
    config.liquidationManagerDeployer = SEPOLIA_BABYLON_DEPLOYER;
    config.liquidationManagerSalt = keccak256('testnet-3.sepolia');
  }

  function _mockCreateX(bytes32 guardedSalt, address computed) internal {
    vm.etch(CREATEX, hex'00');
    vm.mockCall(
      CREATEX,
      abi.encodeCall(ICreateX.computeCreate3Address, (guardedSalt)),
      abi.encode(computed)
    );
  }

  /// @dev A one-Hub market of another deployer listing USDC and WBTC, standing in for the Core Hub.
  /// The governance deployer keeps the AccessManager admin role.
  function _deployExternalMarket()
    internal
    returns (address hub, address accessManager, address treasurySpoke)
  {
    _deploySepoliaTokensAndFeeds();
    AaveV4BabylonConfig.Config memory externalConfig = _config;
    externalConfig.salt = keccak256('external market');
    externalConfig.deployer = _governance;
    string[] memory hubLabels = new string[](1);
    hubLabels[0] = 'core';
    externalConfig.hubLabels = hubLabels;
    externalConfig.babylonSpokeLabel = 'external';
    OrchestrationReports.FullDeploymentReport memory report = this.deployAs(
      externalConfig,
      _governance
    );
    hub = report.hubInstanceBatchReports[0].report.hubProxy;
    accessManager = report.authorityBatchReport.accessManager;
    treasurySpoke = report.treasurySpokeBatchReport.treasurySpoke;
    bytes memory irData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00,
        baseDrawnRate: 0,
        rateGrowthBeforeOptimal: 0,
        rateGrowthAfterOptimal: 0
      })
    );
    address irStrategy = report.hubInstanceBatchReports[0].report.irStrategy;
    vm.startPrank(_governance);
    IAccessManager(accessManager).grantRole(Roles.HUB_CONFIGURATOR_ROLE, _governance, 0);
    IHub(hub).addAsset(SEPOLIA_USDT, 6, treasurySpoke, irStrategy, irData);
    IHub(hub).addAsset(SEPOLIA_USDC, 6, treasurySpoke, irStrategy, irData);
    IHub(hub).addAsset(SEPOLIA_WBTC, 8, treasurySpoke, irStrategy, irData);
    vm.stopPrank();
  }

  /// @dev Runs the orchestration on `inputs` as is, so it can deploy a BabylonSpoke in one step.
  function deployInputs(
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

  /// @dev Runs both deploy steps: the Hubs, then the BabylonSpoke under their AccessManager.
  function deployAs(
    AaveV4BabylonConfig.Config memory config,
    address deployer
  ) external returns (OrchestrationReports.FullDeploymentReport memory report) {
    report = this.deployHubsAs(config, deployer);
    vm.startPrank(deployer);
    BatchReports.SpokeInstanceBatchReport memory spokeReport = AaveV4BabylonSpokeDeployment.deploy({
      config: config,
      deployer: deployer,
      accessManager: report.authorityBatchReport.accessManager
    });
    vm.stopPrank();
    report.babylonSpokeInstanceBatchReports = new OrchestrationReports.SpokeDeploymentReport[](1);
    report.babylonSpokeInstanceBatchReports[0] = OrchestrationReports.SpokeDeploymentReport({
      label: config.babylonSpokeLabel,
      report: spokeReport
    });
  }

  function deployHubsAs(
    AaveV4BabylonConfig.Config memory config,
    address deployer
  ) external returns (OrchestrationReports.FullDeploymentReport memory report) {
    InputUtils.FullDeployInputs memory inputs = new AaveV4DeployBabylonHubHarness(config)
      .sanitizedDeployInputs(deployer);
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);
    bytes memory hubBytecode = BytecodeHelper.getHubBytecode();
    bytes memory spokeBytecode = BytecodeHelper.getSpokeBytecode();
    bytes memory babylonSpokeBytecode = BytecodeHelper.getBabylonSpokeBytecode();
    vm.startPrank(deployer);
    report = AaveV4DeployOrchestration.deployAaveV4({
      logger: logger,
      deployer: deployer,
      deployInputs: inputs,
      hubBytecode: hubBytecode,
      spokeBytecode: spokeBytecode,
      babylonSpokeBytecode: babylonSpokeBytecode
    });
    vm.stopPrank();
  }

  /// @dev The Sepolia config with external reserves on USDC and WBTC of `externalHub`.
  function _sepoliaJsonWithExternalReserves(
    address externalHub
  ) internal view returns (string memory) {
    return
      vm.replace(
        vm.readFile(SEPOLIA_CONFIG),
        '"liquidationConfig"',
        string.concat(
          '"externalReserves": [',
          _externalReserveJson(externalHub, SEPOLIA_USDC, SEPOLIA_USD_FEED, true),
          ', ',
          _externalReserveJson(externalHub, SEPOLIA_WBTC, SEPOLIA_BTC_FEED, false),
          '],\n  "liquidationConfig"'
        )
      );
  }

  function _externalReserveJson(
    address hub,
    address underlying,
    address priceSource,
    bool borrowable
  ) internal pure returns (string memory) {
    return
      string.concat(
        '{"hub": "',
        vm.toString(hub),
        '", "underlying": "',
        vm.toString(underlying),
        '", "priceSource": "',
        vm.toString(priceSource),
        '", "reserveConfig": {"collateralRisk": 0, "paused": false, "frozen": false, "borrowable": ',
        borrowable ? 'true' : 'false',
        ', "receiveSharesEnabled": false}, "dynamicConfig": {"collateralFactor": 0, "maxLiquidationBonus": 10000, "liquidationFee": 0}}'
      );
  }
}
