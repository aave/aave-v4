// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {console2 as console} from 'forge-std/console2.sol';

// dependencies
import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';

// orchestration
import {AaveV4DeployOrchestration} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';
import {WETHDeployProcedure} from 'tests/deployments/procedures/WETHDeployProcedure.sol';
import {AaveV4TestOrchestration} from 'tests/deployments/orchestration/AaveV4TestOrchestration.sol';
import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {Logger} from 'src/deployments/utils/Logger.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {Create2TestHelper} from 'tests/utils/Create2TestHelper.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {DeployConstants} from 'src/deployments/utils/libraries/DeployConstants.sol';

// libraries
import {ProxyHelper} from 'tests/utils/ProxyHelper.sol';
import {BytecodeHelper} from 'src/deployments/utils/libraries/BytecodeHelper.sol';

// interfaces
import {IAccessManagerEnumerable} from 'src/access/interfaces/IAccessManagerEnumerable.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ITreasurySpoke} from 'src/spoke/interfaces/ITreasurySpoke.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {INativeTokenGateway} from 'src/position-manager/interfaces/INativeTokenGateway.sol';

contract BatchTestProcedures is Test, Create2TestHelper, WETHDeployProcedure {
  Logger internal _logger;
  InputUtils.FullDeployInputs internal _inputs;
  address internal _weth9;

  string[] internal _hubLabels;
  string[] internal _spokeLabels;
  bytes4[] internal _spokePositionUpdaterRoleSelectors;
  bytes4[] internal _spokeConfiguratorRoleSelectors;
  bytes4[] internal _hubFeeMinterRoleSelectors;
  bytes4[] internal _hubConfiguratorRoleSelectors;
  address internal _deployer = makeAddr('deployer');
  // Skip native wrapper check when nativeWrapper address is not available (e.g. post-deployment JSON report)
  bool internal _skipNativeWrapperCheck;

  function setUp() public virtual {
    _spokePositionUpdaterRoleSelectors = Roles.getSpokePositionUpdaterRoleSelectors();
    _spokeConfiguratorRoleSelectors = Roles.getSpokeConfiguratorRoleSelectors();

    _hubFeeMinterRoleSelectors = Roles.getHubFeeMinterRoleSelectors();
    _hubConfiguratorRoleSelectors = Roles.getHubConfiguratorRoleSelectors();

    _weth9 = _deployWETH();
    _logger = new Logger('dummy/path');
    _hubLabels = ['hub1', 'hub2', 'hub3'];
    _spokeLabels = ['spoke1', 'spoke2', 'spoke3'];

    _etchCreate2Factory();
  }

  function checkedV4Deployment() public {
    bytes memory hubBytecode = BytecodeHelper.getHubBytecode();
    bytes memory spokeBytecode = BytecodeHelper.getSpokeBytecode();

    vm.startPrank(_deployer);
    OrchestrationReports.FullDeploymentReport memory report = AaveV4DeployOrchestration
      .deployAaveV4(_logger, _deployer, _inputs, hubBytecode, spokeBytecode);
    vm.stopPrank();
    _checkDeployment({report: report, inputs: _inputs});
  }

  function _checkDeployment(
    OrchestrationReports.FullDeploymentReport memory report,
    InputUtils.FullDeployInputs memory inputs
  ) internal view {
    _checkFullReport({report: report, inputs: inputs});
    _checkBatchDeployments({report: report, inputs: inputs});
    _checkRoles(report, _inputs);
  }

  function _checkBatchDeployments(
    OrchestrationReports.FullDeploymentReport memory report,
    InputUtils.FullDeployInputs memory inputs
  ) internal view {
    _checkSpokeBatchDeployments({report: report, inputs: inputs});
    _checkHubBatchDeployments({report: report, inputs: inputs});
    _checkConfiguratorBatchDeployments({report: report});
    _checkGatewayBatchDeployments({report: report, inputs: inputs});
  }

  function _checkConfiguratorBatchDeployments(
    OrchestrationReports.FullDeploymentReport memory report
  ) internal view {
    assertEq(
      IAccessManaged(report.configuratorBatchReport.hubConfigurator).authority(),
      report.authorityBatchReport.accessManager,
      'HubConfigurator authority'
    );
    assertEq(
      IAccessManaged(report.configuratorBatchReport.spokeConfigurator).authority(),
      report.authorityBatchReport.accessManager,
      'SpokeConfigurator authority'
    );
  }

  function _checkGatewayBatchDeployments(
    OrchestrationReports.FullDeploymentReport memory report,
    InputUtils.FullDeployInputs memory inputs
  ) internal view {
    if (inputs.deployNativeTokenGateway && !_skipNativeWrapperCheck) {
      assertEq(
        INativeTokenGateway(report.gatewaysBatchReport.nativeGateway).NATIVE_TOKEN_WRAPPER(),
        inputs.nativeWrapper,
        'NativeGateway NATIVE_TOKEN_WRAPPER'
      );
    }
  }

  function _checkRoles(
    OrchestrationReports.FullDeploymentReport memory report,
    InputUtils.FullDeployInputs memory inputs
  ) internal view {
    IAccessManagerEnumerable accessManager = IAccessManagerEnumerable(
      report.authorityBatchReport.accessManager
    );
    _checkAccessManagerRoles(accessManager, inputs);
    _checkRoleLabels(accessManager);
    _checkSpokeRoles(accessManager, report, inputs);
    _checkHubRoles(accessManager, report, inputs);
    _checkConfiguratorBatchRoles(report, inputs);
    _checkGatewayRoles(report, inputs);
  }

  /// @dev Sanitizes the inputs by defaulting to the deployer if the address is zero.
  function _sanitizeInputs(
    InputUtils.FullDeployInputs memory inputs
  ) internal view returns (InputUtils.FullDeployInputs memory) {
    inputs.accessManagerAdmin = inputs.accessManagerAdmin != address(0)
      ? inputs.accessManagerAdmin
      : _deployer;
    inputs.hubAdmin = inputs.hubAdmin != address(0) ? inputs.hubAdmin : _deployer;
    inputs.hubConfiguratorAdmin = inputs.hubConfiguratorAdmin != address(0)
      ? inputs.hubConfiguratorAdmin
      : _deployer;
    inputs.treasurySpokeOwner = inputs.treasurySpokeOwner != address(0)
      ? inputs.treasurySpokeOwner
      : _deployer;
    inputs.feeSharesMinterOwner = inputs.feeSharesMinterOwner != address(0)
      ? inputs.feeSharesMinterOwner
      : _deployer;
    inputs.spokeAdmin = inputs.spokeAdmin != address(0) ? inputs.spokeAdmin : _deployer;
    inputs.proxyAdminOwner = inputs.proxyAdminOwner != address(0)
      ? inputs.proxyAdminOwner
      : _deployer;
    inputs.spokeConfiguratorAdmin = inputs.spokeConfiguratorAdmin != address(0)
      ? inputs.spokeConfiguratorAdmin
      : _deployer;
    inputs.gatewayOwner = inputs.gatewayOwner != address(0) ? inputs.gatewayOwner : _deployer;
    inputs.positionManagerOwner = inputs.positionManagerOwner != address(0)
      ? inputs.positionManagerOwner
      : _deployer;

    // Sync parallel arrays with spokeLabels length
    inputs.hubLabels = _hubLabels;
    inputs.spokeLabels = _spokeLabels;
    inputs.spokeMaxReservesLimits = _defaultSpokeMaxReservesLimits(_spokeLabels.length);
    inputs.nativeWrapper = _weth9;
    inputs.deployNativeTokenGateway = true;
    inputs.deploySignatureGateway = true;
    inputs.deployPositionManagers = true;

    return inputs;
  }

  function _defaultSpokeMaxReservesLimits(
    uint256 count
  ) internal pure returns (uint16[] memory limits) {
    limits = new uint16[](count);
    for (uint256 i; i < count; i++) {
      limits[i] = DeployConstants.MAX_ALLOWED_USER_RESERVES_LIMIT;
    }
  }

  function _checkFullReport(
    OrchestrationReports.FullDeploymentReport memory report,
    InputUtils.FullDeployInputs memory inputs
  ) internal pure {
    if (inputs.deployNativeTokenGateway) {
      assertNotEq(report.gatewaysBatchReport.nativeGateway, address(0), 'NativeGateway');
    } else {
      assertEq(report.gatewaysBatchReport.nativeGateway, address(0), 'Zero NativeGateway');
    }
    if (inputs.deploySignatureGateway) {
      assertNotEq(report.gatewaysBatchReport.signatureGateway, address(0), 'SignatureGateway');
    } else {
      assertEq(report.gatewaysBatchReport.signatureGateway, address(0), 'Zero SignatureGateway');
    }
    if (inputs.deployPositionManagers) {
      assertNotEq(
        report.positionManagerBatchReport.giverPositionManager,
        address(0),
        'GiverPositionManager'
      );
      assertNotEq(
        report.positionManagerBatchReport.takerPositionManager,
        address(0),
        'TakerPositionManager'
      );
      assertNotEq(
        report.positionManagerBatchReport.configPositionManager,
        address(0),
        'ConfigPositionManager'
      );
    } else {
      assertEq(
        report.positionManagerBatchReport.giverPositionManager,
        address(0),
        'Zero GiverPositionManager'
      );
      assertEq(
        report.positionManagerBatchReport.takerPositionManager,
        address(0),
        'Zero TakerPositionManager'
      );
      assertEq(
        report.positionManagerBatchReport.configPositionManager,
        address(0),
        'Zero ConfigPositionManager'
      );
    }

    assertNotEq(report.authorityBatchReport.accessManager, address(0), 'AccessManager');
    assertNotEq(report.configuratorBatchReport.spokeConfigurator, address(0), 'SpokeConfigurator');
    assertNotEq(report.configuratorBatchReport.hubConfigurator, address(0), 'HubConfigurator');
    assertNotEq(report.treasurySpokeBatchReport.treasurySpoke, address(0), 'TreasurySpoke');
    assertNotEq(report.feeSharesMinterBatchReport.feeSharesMinter, address(0), 'FeeSharesMinter');
    for (uint256 i = 0; i < report.hubInstanceBatchReports.length; i++) {
      assertNotEq(report.hubInstanceBatchReports[i].report.hubProxy, address(0), 'Hub');
      assertNotEq(
        report.hubInstanceBatchReports[i].report.hubImplementation,
        address(0),
        'HubImplementation'
      );
      assertNotEq(report.hubInstanceBatchReports[i].report.irStrategy, address(0), 'IRStrategy');
    }
    for (uint256 i = 0; i < report.spokeInstanceBatchReports.length; i++) {
      assertNotEq(report.spokeInstanceBatchReports[i].report.spokeProxy, address(0), 'SpokeProxy');
      assertNotEq(
        report.spokeInstanceBatchReports[i].report.spokeImplementation,
        address(0),
        'SpokeImplementation'
      );
      assertNotEq(report.spokeInstanceBatchReports[i].report.aaveOracle, address(0), 'AaveOracle');
    }
    assertEq(
      report.hubInstanceBatchReports.length,
      inputs.hubLabels.length,
      'HubBatchReportsLength'
    );
    assertEq(
      report.spokeInstanceBatchReports.length,
      inputs.spokeLabels.length,
      'SpokeInstanceBatchReportsLength'
    );
  }

  function _checkSpokeBatchDeployments(
    OrchestrationReports.FullDeploymentReport memory report,
    InputUtils.FullDeployInputs memory inputs
  ) internal view {
    string memory globalLabel = 'SpokeDeployment';
    for (uint256 i = 0; i < inputs.spokeLabels.length; i++) {
      string memory label = string.concat(globalLabel, ', ', inputs.spokeLabels[i]);
      OrchestrationReports.SpokeDeploymentReport memory spokeReport = report
        .spokeInstanceBatchReports[i];
      _checkSpokeDeployment({
        report: spokeReport,
        accessManager: report.authorityBatchReport.accessManager,
        expectedMaxReservesLimit: inputs.spokeMaxReservesLimits.length > i
          ? inputs.spokeMaxReservesLimits[i]
          : DeployConstants.MAX_ALLOWED_USER_RESERVES_LIMIT,
        label: label
      });
      _checkOracleDeployment({report: spokeReport, label: label});
    }
  }

  function _checkSpokeDeployment(
    OrchestrationReports.SpokeDeploymentReport memory report,
    address accessManager,
    uint16 expectedMaxReservesLimit,
    string memory label
  ) internal view {
    assertEq(
      ProxyHelper.getImplementation(report.report.spokeProxy),
      report.report.spokeImplementation,
      string.concat(label, ' implementation')
    );
    assertEq(
      ISpoke(report.report.spokeProxy).ORACLE(),
      report.report.aaveOracle,
      string.concat(label, ' oracle on spoke')
    );
    assertEq(
      IAccessManaged(report.report.spokeProxy).authority(),
      accessManager,
      string.concat(label, ' spoke authority')
    );
    assertEq(
      ISpoke(report.report.spokeProxy).MAX_USER_RESERVES_LIMIT(),
      expectedMaxReservesLimit,
      string.concat(label, ' max user reserves limit')
    );
    assertEq(
      ProxyHelper.getProxyInitializedVersion(
        ProxyHelper.getImplementation(report.report.spokeProxy)
      ),
      type(uint64).max,
      string.concat(label, ' implementation initializers disabled')
    );
    // verify the non-immutable portions match
    _assertBytecodeMatchExcludingImmutables(
      ProxyHelper.getImplementation(report.report.spokeProxy).code,
      vm.getDeployedCode('src/spoke/instances/SpokeInstance.sol:SpokeInstance'),
      string.concat(label, ' spoke implementation bytecode')
    );
  }

  function _checkOracleDeployment(
    OrchestrationReports.SpokeDeploymentReport memory report,
    string memory label
  ) internal view {
    assertEq(
      IAaveOracle(report.report.aaveOracle).spoke(),
      report.report.spokeProxy,
      string.concat(label, ' spoke on oracle')
    );
    assertEq(
      IAaveOracle(report.report.aaveOracle).decimals(),
      DeployConstants.ORACLE_DECIMALS,
      string.concat(label, ' oracle decimals')
    );
  }

  function _checkHubBatchDeployments(
    OrchestrationReports.FullDeploymentReport memory report,
    InputUtils.FullDeployInputs memory inputs
  ) internal view {
    string memory globalLabel = 'HubDeployment';
    for (uint256 i = 0; i < inputs.hubLabels.length; i++) {
      string memory label = string.concat(globalLabel, ', ', inputs.hubLabels[i]);
      OrchestrationReports.HubDeploymentReport memory hubReport = report.hubInstanceBatchReports[i];

      _checkHubDeployment({
        report: hubReport,
        accessManager: report.authorityBatchReport.accessManager,
        expectedProxyAdminOwner: inputs.proxyAdminOwner,
        label: label
      });
      _checkInterestRateStrategyDeployment({report: hubReport, label: label});
    }
    _checkTreasurySpokeDeployment(report);
    _checkFeeSharesMinterDeployment(report);
  }

  function _checkHubDeployment(
    OrchestrationReports.HubDeploymentReport memory report,
    address accessManager,
    address expectedProxyAdminOwner,
    string memory label
  ) internal view {
    assertEq(
      ProxyHelper.getImplementation(report.report.hubProxy),
      report.report.hubImplementation,
      string.concat(label, ' implementation')
    );
    address proxyAdminOwner = Ownable(ProxyHelper.getProxyAdmin(report.report.hubProxy)).owner();
    assertEq(proxyAdminOwner, expectedProxyAdminOwner, string.concat(label, ' proxy admin owner'));
    assertEq(
      IAccessManaged(report.report.hubProxy).authority(),
      accessManager,
      string.concat(label, ' hub authority')
    );
    assertEq(
      ProxyHelper.getProxyInitializedVersion(ProxyHelper.getImplementation(report.report.hubProxy)),
      type(uint64).max,
      string.concat(label, ' implementation initializers disabled')
    );
    assertEq(
      ProxyHelper.getImplementation(report.report.hubProxy).codehash,
      keccak256(vm.getDeployedCode('src/hub/instances/HubInstance.sol:HubInstance')),
      string.concat(label, ' hub implementation bytecode')
    );
  }

  function _checkInterestRateStrategyDeployment(
    OrchestrationReports.HubDeploymentReport memory report,
    string memory label
  ) internal view {
    assertEq(
      IAssetInterestRateStrategy(report.report.irStrategy).HUB(),
      report.report.hubProxy,
      string.concat(label, ' hub on interest rate strategy')
    );
  }

  function _checkTreasurySpokeDeployment(
    OrchestrationReports.FullDeploymentReport memory report
  ) internal pure {
    assertNotEq(
      report.treasurySpokeBatchReport.treasurySpoke,
      address(0),
      'treasury spoke deployed'
    );
  }

  function _checkFeeSharesMinterDeployment(
    OrchestrationReports.FullDeploymentReport memory report
  ) internal pure {
    assertNotEq(
      report.feeSharesMinterBatchReport.feeSharesMinter,
      address(0),
      'fee shares minter deployed'
    );
  }

  function _checkAccessManagerRoles(
    IAccessManagerEnumerable accessManager,
    InputUtils.FullDeployInputs memory inputs
  ) internal view {
    address expectedAdmin = (inputs.grantRoles && inputs.accessManagerAdmin != address(0))
      ? inputs.accessManagerAdmin
      : _deployer;
    assertEq(
      accessManager.getRoleMember(Roles.ACCESS_MANAGER_ADMIN_ROLE, 0),
      expectedAdmin,
      'DefaultAdminRoleMember'
    );
    assertEq(
      accessManager.getRoleMemberCount(Roles.ACCESS_MANAGER_ADMIN_ROLE),
      1,
      'DefaultAdminRoleCount'
    );

    (bool adminHasRole, ) = accessManager.hasRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, expectedAdmin);
    assertTrue(adminHasRole, 'access manager admin has default admin role');
  }

  function _checkRoleLabels(IAccessManagerEnumerable accessManager) internal view {
    assertEq(accessManager.getRoleLabelCount(), 9, 'role label count');

    // Hub roles
    assertTrue(
      accessManager.isRoleLabeled(Roles.HUB_DOMAIN_ADMIN_ROLE),
      'HUB_DOMAIN_ADMIN labeled'
    );
    assertEq(accessManager.getLabelOfRole(Roles.HUB_DOMAIN_ADMIN_ROLE), 'HUB_DOMAIN_ADMIN_ROLE');
    assertEq(accessManager.getLabelOfRole(Roles.HUB_CONFIGURATOR_ROLE), 'HUB_CONFIGURATOR_ROLE');
    assertEq(accessManager.getLabelOfRole(Roles.HUB_FEE_MINTER_ROLE), 'HUB_FEE_MINTER_ROLE');
    assertEq(
      accessManager.getLabelOfRole(Roles.HUB_DEFICIT_ELIMINATOR_ROLE),
      'HUB_DEFICIT_ELIMINATOR_ROLE'
    );

    // HubConfigurator roles
    assertEq(
      accessManager.getLabelOfRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE),
      'HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE'
    );

    // Spoke roles
    assertEq(
      accessManager.getLabelOfRole(Roles.SPOKE_DOMAIN_ADMIN_ROLE),
      'SPOKE_DOMAIN_ADMIN_ROLE'
    );
    assertEq(
      accessManager.getLabelOfRole(Roles.SPOKE_CONFIGURATOR_ROLE),
      'SPOKE_CONFIGURATOR_ROLE'
    );
    assertEq(
      accessManager.getLabelOfRole(Roles.SPOKE_USER_POSITION_UPDATER_ROLE),
      'SPOKE_USER_POSITION_UPDATER_ROLE'
    );

    // SpokeConfigurator roles
    assertEq(
      accessManager.getLabelOfRole(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE),
      'SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE'
    );
  }

  function _checkSpokeRoles(
    IAccessManagerEnumerable accessManager,
    OrchestrationReports.FullDeploymentReport memory report,
    InputUtils.FullDeployInputs memory inputs
  ) internal view {
    _checkSpokeAdminRoles(accessManager, report, inputs);
    _checkSpokeConfiguratorRoles(accessManager, report, inputs);
  }

  function _checkSpokeConfiguratorRoles(
    IAccessManagerEnumerable accessManager,
    OrchestrationReports.FullDeploymentReport memory report,
    InputUtils.FullDeployInputs memory inputs
  ) internal view {
    if (inputs.spokeLabels.length > 0 && inputs.grantRoles) {
      assertEq(
        accessManager.getRoleMemberCount(Roles.SPOKE_CONFIGURATOR_ROLE),
        2,
        'SpokeConfiguratorRole member count'
      );
      assertEq(
        accessManager.getRoleMember(Roles.SPOKE_CONFIGURATOR_ROLE, 0),
        inputs.spokeAdmin,
        'SpokeConfiguratorRole member - spoke admin'
      );
      assertEq(
        accessManager.getRoleMember(Roles.SPOKE_CONFIGURATOR_ROLE, 1),
        report.configuratorBatchReport.spokeConfigurator,
        'SpokeConfiguratorRole member - spoke configurator'
      );
    } else {
      assertEq(
        accessManager.getRoleMemberCount(Roles.SPOKE_CONFIGURATOR_ROLE),
        0,
        'SpokeConfiguratorRole member count'
      );
    }

    for (uint256 i = 0; i < inputs.spokeLabels.length; i++) {
      for (uint256 j = 0; j < _spokeConfiguratorRoleSelectors.length; j++) {
        assertEq(
          accessManager.getTargetFunctionRole(
            report.spokeInstanceBatchReports[i].report.spokeProxy,
            _spokeConfiguratorRoleSelectors[j]
          ),
          Roles.SPOKE_CONFIGURATOR_ROLE,
          'SpokeConfiguratorRole target function'
        );

        (bool allowed, uint32 delay) = accessManager.canCall(
          report.configuratorBatchReport.spokeConfigurator,
          report.spokeInstanceBatchReports[i].report.spokeProxy,
          _spokeConfiguratorRoleSelectors[j]
        );
        assertEq(
          allowed,
          inputs.grantRoles ? true : false,
          'SpokeConfiguratorRole allowed - configurator'
        );
        assertEq(delay, 0, 'SpokeConfiguratorRole delay - configurator');

        // spoke admin role encompasses spoke configurator role
        (allowed, delay) = accessManager.canCall(
          inputs.spokeAdmin,
          report.spokeInstanceBatchReports[i].report.spokeProxy,
          _spokeConfiguratorRoleSelectors[j]
        );
        assertEq(
          allowed,
          inputs.grantRoles ? true : false,
          'SpokeConfiguratorRole allowed - spoke admin'
        );
        assertEq(delay, 0, 'SpokeConfiguratorRole delay - spoke admin');
      }
    }
  }

  function _checkSpokeAdminRoles(
    IAccessManagerEnumerable accessManager,
    OrchestrationReports.FullDeploymentReport memory report,
    InputUtils.FullDeployInputs memory inputs
  ) internal view {
    if (inputs.spokeLabels.length > 0 && inputs.grantRoles) {
      assertEq(
        accessManager.getRoleMemberCount(Roles.SPOKE_USER_POSITION_UPDATER_ROLE),
        1,
        'SpokePositionUpdaterRole member count'
      );
      assertEq(
        accessManager.getRoleMember(Roles.SPOKE_USER_POSITION_UPDATER_ROLE, 0),
        inputs.spokeAdmin,
        'SpokePositionUpdaterRole member - spoke admin'
      );
    } else {
      assertEq(
        accessManager.getRoleMemberCount(Roles.SPOKE_USER_POSITION_UPDATER_ROLE),
        0,
        'SpokePositionUpdaterRoleCount'
      );
    }

    for (uint256 i = 0; i < inputs.spokeLabels.length; i++) {
      address proxyAdminOwner = Ownable(
        ProxyHelper.getProxyAdmin(report.spokeInstanceBatchReports[i].report.spokeProxy)
      ).owner();
      assertEq(
        proxyAdminOwner,
        inputs.proxyAdminOwner,
        string.concat(inputs.spokeLabels[i], ' proxy admin owner')
      );

      for (uint256 j = 0; j < _spokePositionUpdaterRoleSelectors.length; j++) {
        (bool allowed, uint32 delay) = accessManager.canCall(
          inputs.spokeAdmin,
          report.spokeInstanceBatchReports[i].report.spokeProxy,
          _spokePositionUpdaterRoleSelectors[j]
        );
        assertEq(allowed, inputs.grantRoles ? true : false, 'SpokePositionUpdaterRole allowed');
        assertEq(delay, 0, 'SpokePositionUpdaterRole delay');

        assertEq(
          accessManager.getTargetFunctionRole(
            report.spokeInstanceBatchReports[i].report.spokeProxy,
            _spokePositionUpdaterRoleSelectors[j]
          ),
          Roles.SPOKE_USER_POSITION_UPDATER_ROLE,
          'SpokePositionUpdaterRole target function'
        );
      }
    }
  }

  function _checkHubRoles(
    IAccessManagerEnumerable accessManager,
    OrchestrationReports.FullDeploymentReport memory report,
    InputUtils.FullDeployInputs memory inputs
  ) internal view {
    _checkHubBatchRoles(accessManager, report, inputs);
    _checkHubSelectorRoles(accessManager, report, inputs);
  }

  function _checkHubBatchRoles(
    IAccessManagerEnumerable accessManager,
    OrchestrationReports.FullDeploymentReport memory report,
    InputUtils.FullDeployInputs memory inputs
  ) internal view {
    if (inputs.hubLabels.length > 0 && inputs.grantRoles) {
      assertEq(
        accessManager.getRoleMemberCount(Roles.HUB_FEE_MINTER_ROLE),
        2,
        'HubFeeMinterRoleCount'
      );
      assertEq(
        accessManager.getRoleMember(Roles.HUB_FEE_MINTER_ROLE, 0),
        inputs.hubAdmin,
        'HubFeeMinterRole member - hub admin'
      );
      assertEq(
        accessManager.getRoleMember(Roles.HUB_FEE_MINTER_ROLE, 1),
        report.feeSharesMinterBatchReport.feeSharesMinter,
        'HubFeeMinterRole member - fee shares minter'
      );
    } else {
      assertEq(
        accessManager.getRoleMemberCount(Roles.HUB_FEE_MINTER_ROLE),
        0,
        'HubFeeMinterRoleCount'
      );
    }
    _checkTreasurySpokeRoles(report.treasurySpokeBatchReport.treasurySpoke, inputs);
    _checkFeeSharesMinterRoles(report.feeSharesMinterBatchReport.feeSharesMinter, inputs);
    for (uint256 i = 0; i < inputs.hubLabels.length; i++) {
      for (uint256 j = 0; j < _hubFeeMinterRoleSelectors.length; j++) {
        assertEq(
          accessManager.getTargetFunctionRole(
            report.hubInstanceBatchReports[i].report.hubProxy,
            _hubFeeMinterRoleSelectors[j]
          ),
          Roles.HUB_FEE_MINTER_ROLE,
          'HubFeeMinterRole target function'
        );

        (bool allowed, uint32 delay) = accessManager.canCall(
          inputs.hubAdmin,
          report.hubInstanceBatchReports[i].report.hubProxy,
          _hubFeeMinterRoleSelectors[j]
        );
        assertEq(allowed, inputs.grantRoles ? true : false, 'HubFeeMinterRole allowed');
        assertEq(delay, 0, 'HubFeeMinterRole delay');

        (bool minterAllowed, uint32 minterDelay) = accessManager.canCall(
          report.feeSharesMinterBatchReport.feeSharesMinter,
          report.hubInstanceBatchReports[i].report.hubProxy,
          _hubFeeMinterRoleSelectors[j]
        );
        assertEq(
          minterAllowed,
          inputs.grantRoles ? true : false,
          'HubFeeMinterRole allowed - fee shares minter'
        );
        assertEq(minterDelay, 0, 'HubFeeMinterRole delay - fee shares minter');
      }
    }
  }

  function _checkTreasurySpokeRoles(
    address treasurySpoke,
    InputUtils.FullDeployInputs memory inputs
  ) internal view {
    assertEq(Ownable(treasurySpoke).owner(), inputs.treasurySpokeOwner, 'treasury spoke owner');
  }

  function _checkFeeSharesMinterRoles(
    address feeSharesMinter,
    InputUtils.FullDeployInputs memory inputs
  ) internal view {
    assertEq(
      Ownable(feeSharesMinter).owner(),
      inputs.feeSharesMinterOwner,
      'fee shares minter owner'
    );
  }

  function _checkHubSelectorRoles(
    IAccessManagerEnumerable accessManager,
    OrchestrationReports.FullDeploymentReport memory report,
    InputUtils.FullDeployInputs memory inputs
  ) internal view {
    if (inputs.hubLabels.length > 0 && inputs.grantRoles) {
      assertEq(
        accessManager.getRoleMemberCount(Roles.HUB_CONFIGURATOR_ROLE),
        2,
        'HubConfiguratorRole member count'
      );
      assertEq(
        accessManager.getRoleMember(Roles.HUB_CONFIGURATOR_ROLE, 0),
        inputs.hubAdmin,
        'HubConfiguratorRole member - hub admin'
      );
      assertEq(
        accessManager.getRoleMember(Roles.HUB_CONFIGURATOR_ROLE, 1),
        report.configuratorBatchReport.hubConfigurator,
        'HubConfiguratorRole member - hub configurator'
      );
    } else {
      assertEq(
        accessManager.getRoleMemberCount(Roles.HUB_CONFIGURATOR_ROLE),
        0,
        'HubConfiguratorRole member count'
      );
    }
    for (uint256 i = 0; i < inputs.hubLabels.length; i++) {
      for (uint256 j = 0; j < _hubConfiguratorRoleSelectors.length; j++) {
        assertEq(
          accessManager.getTargetFunctionRole(
            report.hubInstanceBatchReports[i].report.hubProxy,
            _hubConfiguratorRoleSelectors[j]
          ),
          Roles.HUB_CONFIGURATOR_ROLE,
          'HubConfiguratorRole target function'
        );
        bool allowed;
        uint32 delay;

        (allowed, delay) = accessManager.canCall(
          report.configuratorBatchReport.hubConfigurator,
          report.hubInstanceBatchReports[i].report.hubProxy,
          _hubConfiguratorRoleSelectors[j]
        );
        assertEq(
          allowed,
          inputs.grantRoles ? true : false,
          'HubConfiguratorRole allowed - configurator'
        );
        assertEq(delay, 0, 'HubConfiguratorRole delay - configurator');

        (allowed, delay) = accessManager.canCall(
          inputs.hubAdmin,
          report.hubInstanceBatchReports[i].report.hubProxy,
          _hubConfiguratorRoleSelectors[j]
        );
        assertEq(allowed, inputs.grantRoles ? true : false, 'HubConfiguratorRole allowed - admin');
        assertEq(delay, 0, 'HubConfiguratorRole delay - admin');
      }
    }
  }

  function _checkConfiguratorBatchRoles(
    OrchestrationReports.FullDeploymentReport memory report,
    InputUtils.FullDeployInputs memory inputs
  ) internal view {
    assertEq(
      IAccessManaged(report.configuratorBatchReport.hubConfigurator).authority(),
      report.authorityBatchReport.accessManager,
      'HubConfigurator authority'
    );
    assertEq(
      IAccessManaged(report.configuratorBatchReport.spokeConfigurator).authority(),
      report.authorityBatchReport.accessManager,
      'SpokeConfigurator authority'
    );

    IAccessManagerEnumerable accessManager = IAccessManagerEnumerable(
      report.authorityBatchReport.accessManager
    );

    _checkHubConfiguratorBatchRoles(accessManager, report, inputs);
    _checkSpokeConfiguratorBatchRoles(accessManager, report, inputs);
  }

  function _checkHubConfiguratorBatchRoles(
    IAccessManagerEnumerable accessManager,
    OrchestrationReports.FullDeploymentReport memory report,
    InputUtils.FullDeployInputs memory inputs
  ) internal view {
    address hubConfigurator = report.configuratorBatchReport.hubConfigurator;
    bytes4[] memory selectors = Roles.getHubConfiguratorDomainAdminRoleSelectors();

    for (uint256 i; i < selectors.length; i++) {
      assertEq(
        accessManager.getTargetFunctionRole(hubConfigurator, selectors[i]),
        Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
        'HubConfigurator domain admin selector role mapping'
      );
    }

    if (inputs.grantRoles && inputs.hubLabels.length > 0) {
      for (uint256 i; i < selectors.length; i++) {
        (bool allowed, ) = accessManager.canCall(
          inputs.hubConfiguratorAdmin,
          hubConfigurator,
          selectors[i]
        );
        assertTrue(allowed, 'HubConfigurator admin canCall selector');
      }
    }
  }

  function _checkSpokeConfiguratorBatchRoles(
    IAccessManagerEnumerable accessManager,
    OrchestrationReports.FullDeploymentReport memory report,
    InputUtils.FullDeployInputs memory inputs
  ) internal view {
    address spokeConfigurator = report.configuratorBatchReport.spokeConfigurator;
    bytes4[] memory selectors = Roles.getSpokeConfiguratorDomainAdminRoleSelectors();

    for (uint256 i; i < selectors.length; i++) {
      assertEq(
        accessManager.getTargetFunctionRole(spokeConfigurator, selectors[i]),
        Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
        'SpokeConfigurator domain admin selector role mapping'
      );
    }

    if (inputs.grantRoles && inputs.spokeLabels.length > 0) {
      for (uint256 i; i < selectors.length; i++) {
        (bool allowed, ) = accessManager.canCall(
          inputs.spokeConfiguratorAdmin,
          spokeConfigurator,
          selectors[i]
        );
        assertTrue(allowed, 'SpokeConfigurator admin canCall selector');
      }
    }
  }

  function _checkGatewayRoles(
    OrchestrationReports.FullDeploymentReport memory report,
    InputUtils.FullDeployInputs memory inputs
  ) internal view {
    if (inputs.deployNativeTokenGateway) {
      assertEq(
        Ownable(report.gatewaysBatchReport.nativeGateway).owner(),
        inputs.gatewayOwner,
        'NativeGateway owner'
      );
    }
    if (inputs.deploySignatureGateway) {
      assertEq(
        Ownable(report.gatewaysBatchReport.signatureGateway).owner(),
        inputs.gatewayOwner,
        'SignatureGateway owner'
      );
    }
    if (inputs.deployPositionManagers) {
      assertEq(
        Ownable(report.positionManagerBatchReport.giverPositionManager).owner(),
        inputs.positionManagerOwner,
        'GiverPositionManager owner'
      );
      assertEq(
        Ownable(report.positionManagerBatchReport.takerPositionManager).owner(),
        inputs.positionManagerOwner,
        'TakerPositionManager owner'
      );
      assertEq(
        Ownable(report.positionManagerBatchReport.configPositionManager).owner(),
        inputs.positionManagerOwner,
        'ConfigPositionManager owner'
      );
    }
  }

  function _etchSetup() internal {
    _etchCreate2Factory();
  }

  function _checkAddressesHaveCode(
    OrchestrationReports.FullDeploymentReport memory report
  ) internal view {
    _assertHasCode(report.authorityBatchReport.accessManager, 'accessManager');
    _assertHasCode(report.configuratorBatchReport.hubConfigurator, 'hubConfigurator');
    _assertHasCode(report.configuratorBatchReport.spokeConfigurator, 'spokeConfigurator');
    _assertHasCode(report.treasurySpokeBatchReport.treasurySpoke, 'treasurySpoke');
    _assertHasCode(report.feeSharesMinterBatchReport.feeSharesMinter, 'feeSharesMinter');

    for (uint256 i; i < report.hubInstanceBatchReports.length; i++) {
      string memory label = report.hubInstanceBatchReports[i].label;
      _assertHasCode(
        report.hubInstanceBatchReports[i].report.hubProxy,
        string.concat('hub proxy: ', label)
      );
      _assertHasCode(
        report.hubInstanceBatchReports[i].report.hubImplementation,
        string.concat('hub impl: ', label)
      );
      _assertHasCode(
        report.hubInstanceBatchReports[i].report.irStrategy,
        string.concat('irStrategy: ', label)
      );
    }

    for (uint256 i; i < report.spokeInstanceBatchReports.length; i++) {
      string memory label = report.spokeInstanceBatchReports[i].label;
      _assertHasCode(
        report.spokeInstanceBatchReports[i].report.spokeProxy,
        string.concat('spoke proxy: ', label)
      );
      _assertHasCode(
        report.spokeInstanceBatchReports[i].report.spokeImplementation,
        string.concat('spoke impl: ', label)
      );
      _assertHasCode(
        report.spokeInstanceBatchReports[i].report.aaveOracle,
        string.concat('oracle: ', label)
      );
    }

    if (report.gatewaysBatchReport.nativeGateway != address(0)) {
      _assertHasCode(report.gatewaysBatchReport.nativeGateway, 'nativeTokenGateway');
    }
    if (report.gatewaysBatchReport.signatureGateway != address(0)) {
      _assertHasCode(report.gatewaysBatchReport.signatureGateway, 'signatureGateway');
    }
    if (report.positionManagerBatchReport.giverPositionManager != address(0)) {
      _assertHasCode(
        report.positionManagerBatchReport.giverPositionManager,
        'giverPositionManager'
      );
    }
    if (report.positionManagerBatchReport.takerPositionManager != address(0)) {
      _assertHasCode(
        report.positionManagerBatchReport.takerPositionManager,
        'takerPositionManager'
      );
    }
    if (report.positionManagerBatchReport.configPositionManager != address(0)) {
      _assertHasCode(
        report.positionManagerBatchReport.configPositionManager,
        'configPositionManager'
      );
    }
  }

  function _assertHasCode(address addr, string memory label) internal view {
    assertTrue(addr.code.length > 0, string.concat('no code at ', label, ': ', vm.toString(addr)));
  }

  /// @dev Assert that actual bytecode matches artifact bytecode, ignoring immutable slots
  function _assertBytecodeMatchExcludingImmutables(
    bytes memory actual,
    bytes memory artifact,
    string memory label
  ) internal pure {
    assertEq(actual.length, artifact.length, string.concat(label, ': code size mismatch'));

    // Copy on-chain bytecode; zero out positions where artifact has zeros but on-chain doesn't.
    // These are immutable slots (values are validated separately)
    bytes memory masked = new bytes(actual.length);
    for (uint256 i; i < actual.length; i++) {
      masked[i] = (artifact[i] == 0x00) ? bytes1(0x00) : actual[i];
    }
    assertEq(keccak256(masked), keccak256(artifact), string.concat(label, ': bytecode mismatch'));
  }
}
