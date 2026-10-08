// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Create2TestHelper} from 'tests/utils/Create2TestHelper.sol';
import {AaveV4DeployBabylon} from 'scripts/markets/babylon/AaveV4DeployBabylon.s.sol';
import {AaveV4BabylonHandover} from 'scripts/markets/babylon/AaveV4BabylonHandover.s.sol';
import {AaveV4BabylonConfig} from 'scripts/markets/babylon/AaveV4BabylonConfig.sol';
import {AaveV4DeployOrchestration} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';
import {MetadataLogger} from 'src/deployments/utils/MetadataLogger.sol';
import {BytecodeHelper} from 'src/deployments/utils/libraries/BytecodeHelper.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {IAccessManagerEnumerable} from 'src/access/interfaces/IAccessManagerEnumerable.sol';
import {ProxyAdmin} from 'src/dependencies/openzeppelin/ProxyAdmin.sol';
import {Ownable2StepUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/Ownable2StepUpgradeable.sol';
import {IBabylonSpoke} from 'src/spoke/interfaces/IBabylonSpoke.sol';

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

  function _config() internal view override returns (AaveV4BabylonConfig.Config memory) {
    return _harnessConfig;
  }

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

contract AaveV4BabylonTest is Create2TestHelper {
  bytes32 internal constant ADMIN_SLOT =
    0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
  string internal constant OUTPUT_DIR = 'output/reports/deployments/';
  string internal constant REPORT_NAME = 'babylon-handover-test';

  address internal _deployer = DEFAULT_SENDER;
  address internal _admin = makeAddr('admin');
  address internal _liquidationManager = makeAddr('liquidationManager');
  AaveV4BabylonConfig.Config internal _config;

  function setUp() public {
    _etchCreate2Factory();
    _config = AaveV4BabylonConfig.Config({
      salt: keccak256('aave-v4-babylon'),
      hubLabel: 'babylon',
      babylonSpokeLabel: 'babylon',
      liquidationManager: _liquidationManager,
      managedCollateralReserveId: 0,
      admin: _admin,
      report: string.concat(OUTPUT_DIR, vm.toString(block.chainid), '-', REPORT_NAME, '.json')
    });
  }

  function test_sepoliaConfig() public {
    vm.chainId(AaveV4BabylonConfig.SEPOLIA_CHAIN_ID);
    AaveV4BabylonConfig.Config memory config = AaveV4BabylonConfig.read();
    assertEq(config.salt, keccak256('aave-v4-babylon'));
    assertEq(config.hubLabel, 'babylon');
    assertEq(config.babylonSpokeLabel, 'babylon');
    assertEq(config.managedCollateralReserveId, 0);
  }

  function test_unsupportedChain_reverts() public {
    vm.chainId(1);
    vm.expectRevert('unsupported chain');
    this.readConfig();
  }

  /// @dev The checked-in config still has placeholders, so it cannot deploy.
  function test_sepoliaConfig_placeholdersBlockDeployment() public {
    vm.chainId(AaveV4BabylonConfig.SEPOLIA_CHAIN_ID);
    AaveV4BabylonConfig.Config memory config = AaveV4BabylonConfig.read();
    assertEq(config.liquidationManager, address(0));
    assertEq(config.admin, address(0));

    InputUtils.FullDeployInputs memory inputs = new AaveV4DeployBabylonHarness(config)
      .sanitizedDeployInputs(_deployer);
    vm.expectRevert('invalid liquidation manager');
    this.deploy(inputs);
  }

  function test_deployInputs() public {
    InputUtils.FullDeployInputs memory inputs = new AaveV4DeployBabylonHarness(_config)
      .sanitizedDeployInputs(_deployer);

    assertFalse(inputs.grantRoles);
    assertEq(inputs.proxyAdminOwner, _deployer);
    assertEq(inputs.treasurySpokeOwner, _deployer);
    assertEq(inputs.hubLabels.length, 1);
    assertEq(inputs.hubLabels[0], 'babylon');
    assertEq(inputs.spokeLabels.length, 0);
    assertEq(inputs.babylonSpokeLabels.length, 1);
    assertEq(inputs.babylonSpokeLabels[0], 'babylon');
    assertEq(inputs.babylonLiquidationManagers[0], _liquidationManager);
    assertEq(inputs.babylonManagedCollateralReserveIds[0], 0);
    assertFalse(inputs.deployNativeTokenGateway);
    assertFalse(inputs.deploySignatureGateway);
    assertFalse(inputs.deployPositionManagers);
    assertEq(inputs.salt, keccak256('aave-v4-babylon'));
  }

  function test_deploy() public {
    OrchestrationReports.FullDeploymentReport memory report = this.deploy(
      new AaveV4DeployBabylonHarness(_config).sanitizedDeployInputs(_deployer)
    );

    assertEq(report.hubInstanceBatchReports.length, 1);
    assertEq(report.spokeInstanceBatchReports.length, 0);
    assertEq(report.babylonSpokeInstanceBatchReports.length, 1);
    assertEq(report.gatewaysBatchReport.signatureGateway, address(0));
    assertEq(report.gatewaysBatchReport.nativeGateway, address(0));
    assertEq(report.positionManagerBatchReport.giverPositionManager, address(0));

    address babylonSpoke = report.babylonSpokeInstanceBatchReports[0].report.spokeProxy;
    assertEq(IBabylonSpoke(babylonSpoke).LIQUIDATION_MANAGER(), _liquidationManager);
    assertEq(IBabylonSpoke(babylonSpoke).MANAGED_COLLATERAL_RESERVE_ID(), 0);

    assertEq(_proxyAdmin(report.hubInstanceBatchReports[0].report.hubProxy).owner(), _deployer);
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

  /// @dev Deferring roles and handing over must end in the role state `grantRoles = true` produces
  /// when every admin input is the handover admin.
  function test_handover_matchesGrantRolesDeployment() public {
    uint256 snapshotId = vm.snapshotState();
    InputUtils.FullDeployInputs memory direct = new AaveV4DeployBabylonHarness(_config)
      .sanitizedDeployInputs(_deployer);
    direct.grantRoles = true;
    direct.accessManagerAdmin = _admin;
    direct.hubAdmin = _admin;
    direct.hubConfiguratorAdmin = _admin;
    direct.spokeAdmin = _admin;
    direct.spokeConfiguratorAdmin = _admin;
    OrchestrationReports.FullDeploymentReport memory expected = this.deploy(direct);
    IAccessManagerEnumerable expectedManager = IAccessManagerEnumerable(
      expected.authorityBatchReport.accessManager
    );
    uint64[] memory roles = expectedManager.getRoles(0, expectedManager.getRoleCount());
    address[][] memory members = new address[][](roles.length);
    for (uint256 i; i < roles.length; ++i) {
      members[i] = expectedManager.getRoleMembers(
        roles[i],
        0,
        expectedManager.getRoleMemberCount(roles[i])
      );
    }

    vm.revertToState(snapshotId);
    OrchestrationReports.FullDeploymentReport memory report = _deployAndWriteReport();
    new AaveV4BabylonHandoverHarness(_config).run();

    IAccessManagerEnumerable accessManager = IAccessManagerEnumerable(
      report.authorityBatchReport.accessManager
    );
    assertEq(address(accessManager), address(expectedManager));
    assertEq(
      abi.encode(accessManager.getRoles(0, accessManager.getRoleCount())),
      abi.encode(roles)
    );
    for (uint256 i; i < roles.length; ++i) {
      address[] memory actual = accessManager.getRoleMembers(
        roles[i],
        0,
        accessManager.getRoleMemberCount(roles[i])
      );
      assertEq(_sorted(actual), _sorted(members[i]));
    }
    (bool adminIsAdmin, ) = accessManager.hasRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, _admin);
    assertTrue(adminIsAdmin);
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

  function readConfig() external view returns (AaveV4BabylonConfig.Config memory) {
    return AaveV4BabylonConfig.read();
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

  function _sorted(address[] memory values) internal pure returns (address[] memory) {
    for (uint256 i = 1; i < values.length; ++i) {
      for (uint256 j = i; j > 0 && values[j - 1] > values[j]; --j) {
        (values[j - 1], values[j]) = (values[j], values[j - 1]);
      }
    }
    return values;
  }
}
