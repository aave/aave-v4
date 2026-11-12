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
    _checkRoles(report, inputs);
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
      IAccessManaged(report.hubConfigurator).authority(),
      report.accessManager,
      'HubConfigurator authority'
    );
    assertEq(
      IAccessManaged(report.spokeConfigurator).authority(),
      report.accessManager,
      'SpokeConfigurator authority'
    );
  }

  function _checkGatewayBatchDeployments(
    OrchestrationReports.FullDeploymentReport memory report,
    InputUtils.FullDeployInputs memory inputs
  ) internal view {
    if (inputs.deployNativeTokenGateway && !_skipNativeWrapperCheck) {
      assertEq(
        INativeTokenGateway(report.nativeGateway).NATIVE_TOKEN_WRAPPER(),
        inputs.nativeWrapper,
        'NativeGateway NATIVE_TOKEN_WRAPPER'
      );
    }
  }

  function _checkRoles(
    OrchestrationReports.FullDeploymentReport memory report,
    InputUtils.FullDeployInputs memory inputs
  ) internal view {
    IAccessManagerEnumerable accessManager = IAccessManagerEnumerable(report.accessManager);
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
      assertNotEq(report.nativeGateway, address(0), 'NativeGateway');
    } else {
      assertEq(report.nativeGateway, address(0), 'Zero NativeGateway');
    }
    if (inputs.deploySignatureGateway) {
      assertNotEq(report.signatureGateway, address(0), 'SignatureGateway');
    } else {
      assertEq(report.signatureGateway, address(0), 'Zero SignatureGateway');
    }
    if (inputs.deployPositionManagers) {
      assertNotEq(report.giverPositionManager, address(0), 'GiverPositionManager');
      assertNotEq(report.takerPositionManager, address(0), 'TakerPositionManager');
      assertNotEq(report.configPositionManager, address(0), 'ConfigPositionManager');
    } else {
      assertEq(report.giverPositionManager, address(0), 'Zero GiverPositionManager');
      assertEq(report.takerPositionManager, address(0), 'Zero TakerPositionManager');
      assertEq(report.configPositionManager, address(0), 'Zero ConfigPositionManager');
    }

    assertNotEq(report.accessManager, address(0), 'AccessManager');
    assertNotEq(report.spokeConfigurator, address(0), 'SpokeConfigurator');
    assertNotEq(report.hubConfigurator, address(0), 'HubConfigurator');
    assertNotEq(report.treasurySpoke, address(0), 'TreasurySpoke');
    for (uint256 i = 0; i < report.hubs.length; i++) {
      assertNotEq(report.hubs[i].hubProxy, address(0), 'Hub');
      assertNotEq(report.hubs[i].hubImplementation, address(0), 'HubImplementation');
      assertNotEq(report.hubs[i].irStrategy, address(0), 'IRStrategy');
    }
    for (uint256 i = 0; i < report.spokes.length; i++) {
      assertNotEq(report.spokes[i].spokeProxy, address(0), 'SpokeProxy');
      assertNotEq(report.spokes[i].spokeImplementation, address(0), 'SpokeImplementation');
      assertNotEq(report.spokes[i].aaveOracle, address(0), 'AaveOracle');
    }
    assertEq(report.hubs.length, inputs.hubLabels.length, 'HubReportsLength');
    assertEq(report.spokes.length, inputs.spokeLabels.length, 'SpokeReportsLength');
  }

  function _checkSpokeBatchDeployments(
    OrchestrationReports.FullDeploymentReport memory report,
    InputUtils.FullDeployInputs memory inputs
  ) internal view {
    string memory globalLabel = 'SpokeDeployment';
    for (uint256 i = 0; i < inputs.spokeLabels.length; i++) {
      string memory label = string.concat(globalLabel, ', ', inputs.spokeLabels[i]);
      OrchestrationReports.SpokeDeploymentReport memory spokeReport = report.spokes[i];
      _checkSpokeDeployment({
        report: spokeReport,
        accessManager: report.accessManager,
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
      ProxyHelper.getImplementation(report.spokeProxy),
      report.spokeImplementation,
      string.concat(label, ' implementation')
    );
    assertEq(
      ISpoke(report.spokeProxy).ORACLE(),
      report.aaveOracle,
      string.concat(label, ' oracle on spoke')
    );
    assertEq(
      IAccessManaged(report.spokeProxy).authority(),
      accessManager,
      string.concat(label, ' spoke authority')
    );
    assertEq(
      ISpoke(report.spokeProxy).MAX_USER_RESERVES_LIMIT(),
      expectedMaxReservesLimit,
      string.concat(label, ' max user reserves limit')
    );
    assertEq(
      ProxyHelper.getProxyInitializedVersion(ProxyHelper.getImplementation(report.spokeProxy)),
      type(uint64).max,
      string.concat(label, ' implementation initializers disabled')
    );
    // verify the non-immutable portions match
    _assertBytecodeMatchExcludingImmutables(
      ProxyHelper.getImplementation(report.spokeProxy).code,
      vm.getDeployedCode('src/spoke/instances/SpokeInstance.sol:SpokeInstance'),
      string.concat(label, ' spoke implementation bytecode')
    );
  }

  function _checkOracleDeployment(
    OrchestrationReports.SpokeDeploymentReport memory report,
    string memory label
  ) internal view {
    assertEq(
      IAaveOracle(report.aaveOracle).spoke(),
      report.spokeProxy,
      string.concat(label, ' spoke on oracle')
    );
    assertEq(
      IAaveOracle(report.aaveOracle).decimals(),
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
      OrchestrationReports.HubDeploymentReport memory hubReport = report.hubs[i];

      _checkHubDeployment({
        report: hubReport,
        accessManager: report.accessManager,
        expectedProxyAdminOwner: inputs.proxyAdminOwner,
        label: label
      });
      _checkInterestRateStrategyDeployment({report: hubReport, label: label});
    }
    _checkTreasurySpokeDeployment(report);
  }

  function _checkHubDeployment(
    OrchestrationReports.HubDeploymentReport memory report,
    address accessManager,
    address expectedProxyAdminOwner,
    string memory label
  ) internal view {
    assertEq(
      ProxyHelper.getImplementation(report.hubProxy),
      report.hubImplementation,
      string.concat(label, ' implementation')
    );
    address proxyAdminOwner = Ownable(ProxyHelper.getProxyAdmin(report.hubProxy)).owner();
    assertEq(proxyAdminOwner, expectedProxyAdminOwner, string.concat(label, ' proxy admin owner'));
    assertEq(
      IAccessManaged(report.hubProxy).authority(),
      accessManager,
      string.concat(label, ' hub authority')
    );
    assertEq(
      ProxyHelper.getProxyInitializedVersion(ProxyHelper.getImplementation(report.hubProxy)),
      type(uint64).max,
      string.concat(label, ' implementation initializers disabled')
    );
    assertEq(
      ProxyHelper.getImplementation(report.hubProxy).codehash,
      keccak256(vm.getDeployedCode('src/hub/instances/HubInstance.sol:HubInstance')),
      string.concat(label, ' hub implementation bytecode')
    );
  }

  function _checkInterestRateStrategyDeployment(
    OrchestrationReports.HubDeploymentReport memory report,
    string memory label
  ) internal view {
    assertEq(
      IAssetInterestRateStrategy(report.irStrategy).HUB(),
      report.hubProxy,
      string.concat(label, ' hub on interest rate strategy')
    );
  }

  function _checkTreasurySpokeDeployment(
    OrchestrationReports.FullDeploymentReport memory report
  ) internal pure {
    assertNotEq(report.treasurySpoke, address(0), 'treasury spoke deployed');
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
        report.spokeConfigurator,
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
            report.spokes[i].spokeProxy,
            _spokeConfiguratorRoleSelectors[j]
          ),
          Roles.SPOKE_CONFIGURATOR_ROLE,
          'SpokeConfiguratorRole target function'
        );

        (bool allowed, uint32 delay) = accessManager.canCall(
          report.spokeConfigurator,
          report.spokes[i].spokeProxy,
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
          report.spokes[i].spokeProxy,
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
      address proxyAdminOwner = Ownable(ProxyHelper.getProxyAdmin(report.spokes[i].spokeProxy))
        .owner();
      assertEq(
        proxyAdminOwner,
        inputs.proxyAdminOwner,
        string.concat(inputs.spokeLabels[i], ' proxy admin owner')
      );

      for (uint256 j = 0; j < _spokePositionUpdaterRoleSelectors.length; j++) {
        (bool allowed, uint32 delay) = accessManager.canCall(
          inputs.spokeAdmin,
          report.spokes[i].spokeProxy,
          _spokePositionUpdaterRoleSelectors[j]
        );
        assertEq(allowed, inputs.grantRoles ? true : false, 'SpokePositionUpdaterRole allowed');
        assertEq(delay, 0, 'SpokePositionUpdaterRole delay');

        assertEq(
          accessManager.getTargetFunctionRole(
            report.spokes[i].spokeProxy,
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
        1,
        'HubFeeMinterRoleCount'
      );
      assertEq(
        accessManager.getRoleMember(Roles.HUB_FEE_MINTER_ROLE, 0),
        inputs.hubAdmin,
        'HubFeeMinterRole member - hub admin'
      );
    } else {
      assertEq(
        accessManager.getRoleMemberCount(Roles.HUB_FEE_MINTER_ROLE),
        0,
        'HubFeeMinterRoleCount'
      );
    }
    _checkTreasurySpokeRoles(report.treasurySpoke, inputs);
    for (uint256 i = 0; i < inputs.hubLabels.length; i++) {
      for (uint256 j = 0; j < _hubFeeMinterRoleSelectors.length; j++) {
        assertEq(
          accessManager.getTargetFunctionRole(
            report.hubs[i].hubProxy,
            _hubFeeMinterRoleSelectors[j]
          ),
          Roles.HUB_FEE_MINTER_ROLE,
          'HubFeeMinterRole target function'
        );

        (bool allowed, uint32 delay) = accessManager.canCall(
          inputs.hubAdmin,
          report.hubs[i].hubProxy,
          _hubFeeMinterRoleSelectors[j]
        );
        assertEq(allowed, inputs.grantRoles ? true : false, 'HubFeeMinterRole allowed');
        assertEq(delay, 0, 'HubFeeMinterRole delay');
      }
    }
  }

  function _checkTreasurySpokeRoles(
    address treasurySpoke,
    InputUtils.FullDeployInputs memory inputs
  ) internal view {
    assertEq(Ownable(treasurySpoke).owner(), inputs.treasurySpokeOwner, 'treasury spoke owner');
    assertEq(
      Ownable(ProxyHelper.getProxyAdmin(treasurySpoke)).owner(),
      inputs.treasurySpokeOwner,
      'treasury spoke proxy admin owner'
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
        report.hubConfigurator,
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
            report.hubs[i].hubProxy,
            _hubConfiguratorRoleSelectors[j]
          ),
          Roles.HUB_CONFIGURATOR_ROLE,
          'HubConfiguratorRole target function'
        );
        bool allowed;
        uint32 delay;

        (allowed, delay) = accessManager.canCall(
          report.hubConfigurator,
          report.hubs[i].hubProxy,
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
          report.hubs[i].hubProxy,
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
      IAccessManaged(report.hubConfigurator).authority(),
      report.accessManager,
      'HubConfigurator authority'
    );
    assertEq(
      IAccessManaged(report.spokeConfigurator).authority(),
      report.accessManager,
      'SpokeConfigurator authority'
    );

    IAccessManagerEnumerable accessManager = IAccessManagerEnumerable(report.accessManager);

    _checkHubConfiguratorBatchRoles(accessManager, report, inputs);
    _checkSpokeConfiguratorBatchRoles(accessManager, report, inputs);
  }

  function _checkHubConfiguratorBatchRoles(
    IAccessManagerEnumerable accessManager,
    OrchestrationReports.FullDeploymentReport memory report,
    InputUtils.FullDeployInputs memory inputs
  ) internal view {
    address hubConfigurator = report.hubConfigurator;
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
    address spokeConfigurator = report.spokeConfigurator;
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
      assertEq(Ownable(report.nativeGateway).owner(), inputs.gatewayOwner, 'NativeGateway owner');
    }
    if (inputs.deploySignatureGateway) {
      assertEq(
        Ownable(report.signatureGateway).owner(),
        inputs.gatewayOwner,
        'SignatureGateway owner'
      );
    }
    if (inputs.deployPositionManagers) {
      assertEq(
        Ownable(report.giverPositionManager).owner(),
        inputs.positionManagerOwner,
        'GiverPositionManager owner'
      );
      assertEq(
        Ownable(report.takerPositionManager).owner(),
        inputs.positionManagerOwner,
        'TakerPositionManager owner'
      );
      assertEq(
        Ownable(report.configPositionManager).owner(),
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
    _assertHasCode(report.accessManager, 'accessManager');
    _assertHasCode(report.hubConfigurator, 'hubConfigurator');
    _assertHasCode(report.spokeConfigurator, 'spokeConfigurator');
    _assertHasCode(report.treasurySpoke, 'treasurySpoke');

    for (uint256 i; i < report.hubs.length; i++) {
      string memory label = report.hubs[i].label;
      _assertHasCode(report.hubs[i].hubProxy, string.concat('hub proxy: ', label));
      _assertHasCode(report.hubs[i].hubImplementation, string.concat('hub impl: ', label));
      _assertHasCode(report.hubs[i].irStrategy, string.concat('irStrategy: ', label));
    }

    for (uint256 i; i < report.spokes.length; i++) {
      string memory label = report.spokes[i].label;
      _assertHasCode(report.spokes[i].spokeProxy, string.concat('spoke proxy: ', label));
      _assertHasCode(report.spokes[i].spokeImplementation, string.concat('spoke impl: ', label));
      _assertHasCode(report.spokes[i].aaveOracle, string.concat('oracle: ', label));
    }

    if (report.nativeGateway != address(0)) {
      _assertHasCode(report.nativeGateway, 'nativeTokenGateway');
    }
    if (report.signatureGateway != address(0)) {
      _assertHasCode(report.signatureGateway, 'signatureGateway');
    }
    if (report.giverPositionManager != address(0)) {
      _assertHasCode(report.giverPositionManager, 'giverPositionManager');
    }
    if (report.takerPositionManager != address(0)) {
      _assertHasCode(report.takerPositionManager, 'takerPositionManager');
    }
    if (report.configPositionManager != address(0)) {
      _assertHasCode(report.configPositionManager, 'configPositionManager');
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
