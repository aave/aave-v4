// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/utils/BatchTestProcedures.sol';
import {IBabylonSpoke} from 'src/spoke/interfaces/IBabylonSpoke.sol';
import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';

contract AaveV4BatchDeploymentTest is BatchTestProcedures {
  function setUp() public override {
    super.setUp();

    _inputs = InputUtils.FullDeployInputs({
      accessManagerAdmin: makeAddr('accessManagerAdmin'),
      proxyAdminOwner: makeAddr('proxyAdminOwner'),
      hubAdmin: makeAddr('hubAdmin'),
      hubConfiguratorAdmin: makeAddr('hubConfiguratorAdmin'),
      treasurySpokeOwner: makeAddr('treasurySpokeOwner'),
      spokeAdmin: makeAddr('spokeAdmin'),
      spokeConfiguratorAdmin: makeAddr('spokeConfiguratorAdmin'),
      gatewayOwner: makeAddr('gatewayOwner'),
      positionManagerOwner: makeAddr('positionManagerOwner'),
      nativeWrapper: _weth9,
      deployNativeTokenGateway: true,
      deploySignatureGateway: true,
      deployPositionManagers: true,
      grantRoles: true,
      hubLabels: _hubLabels,
      spokeLabels: _spokeLabels,
      spokeMaxReservesLimits: _defaultSpokeMaxReservesLimits(_spokeLabels.length),
      babylonSpokeLabels: new string[](0),
      babylonSpokeMaxReservesLimits: new uint16[](0),
      salt: bytes32(0)
    });
  }

  function testAaveV4BatchDeployment() public {
    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withoutRoles() public {
    _inputs.grantRoles = false;
    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withoutGateways() public {
    _inputs.deployNativeTokenGateway = false;
    _inputs.deploySignatureGateway = false;
    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withoutNativeTokenGateway() public {
    _inputs.deployNativeTokenGateway = false;
    _inputs.deploySignatureGateway = true;
    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withoutSignatureGateway() public {
    _inputs.deployNativeTokenGateway = true;
    _inputs.deploySignatureGateway = false;
    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withoutHubs() public {
    _inputs.hubLabels = new string[](0);
    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withoutSpokes() public {
    _inputs.spokeLabels = new string[](0);
    _inputs.spokeMaxReservesLimits = new uint16[](0);

    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withZeroAccessManagerAdmin_withRoles_reverts() public {
    // only reverts if grantRoles is true, as access manager admin replaces deployer as default admin
    _inputs.accessManagerAdmin = address(0);
    _inputs.grantRoles = true;

    vm.expectRevert('invalid admin');
    this.checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withZeroAccessManagerAdmin_withoutRoles() public {
    _inputs.accessManagerAdmin = address(0);
    _inputs.grantRoles = false;

    checkedV4Deployment();
  }

  /// @dev Only reverts when grantRoles is true, as hubConfiguratorAdmin is
  /// now used to grant configurator roles, not as authority
  function testAaveV4BatchDeployment_fuzz_withZeroHubConfiguratorAdmin(bool grantRoles) public {
    _inputs.hubConfiguratorAdmin = address(0);
    _inputs.grantRoles = grantRoles;

    if (grantRoles && _inputs.hubLabels.length > 0) {
      vm.expectRevert('invalid admin');
      this.checkedV4Deployment();
    } else {
      checkedV4Deployment();
    }
  }

  /// @dev Reverts as treasurySpoke is always deployed and owner is required
  function testAaveV4BatchDeployment_fuzz_withZeroTreasurySpokeOwner(bool grantRoles) public {
    _inputs.treasurySpokeOwner = address(0);
    _inputs.grantRoles = grantRoles;

    (bool isExpectedError, bytes memory errorMessage) = _getExpectedError();
    if (isExpectedError) {
      vm.expectRevert(errorMessage);
      this.checkedV4Deployment();
    } else {
      checkedV4Deployment();
    }
  }

  function testAaveV4BatchDeployment_fuzz_withZeroProxyAdminOwner(
    bool withoutHubs,
    bool withoutSpokes,
    bool grantRoles
  ) public {
    _inputs.proxyAdminOwner = address(0);
    _inputs.grantRoles = grantRoles;
    if (withoutHubs) {
      _inputs.hubLabels = new string[](0);
    }
    if (withoutSpokes) {
      _inputs.spokeLabels = new string[](0);
      _inputs.spokeMaxReservesLimits = new uint16[](0);
    }

    (bool isExpectedError, bytes memory errorMessage) = _getExpectedError();
    if (isExpectedError) {
      vm.expectRevert(errorMessage);
      this.checkedV4Deployment();
    } else {
      checkedV4Deployment();
    }
  }

  /// @dev Only reverts when grantRoles is true, as spokeConfiguratorAdmin is
  /// now used to grant configurator roles, not as authority
  function testAaveV4BatchDeployment_fuzz_withZeroSpokeConfiguratorAdmin(bool grantRoles) public {
    _inputs.spokeConfiguratorAdmin = address(0);
    _inputs.grantRoles = grantRoles;

    if (grantRoles && _inputs.spokeLabels.length > 0) {
      vm.expectRevert('invalid admin');
      this.checkedV4Deployment();
    } else {
      checkedV4Deployment();
    }
  }

  function testAaveV4BatchDeployment_withZeroHubAdmin_withRoles_reverts() public {
    _inputs.hubAdmin = address(0);
    _inputs.grantRoles = true;

    vm.expectRevert('invalid admin');
    this.checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withZeroHubAdmin_withoutRoles() public {
    _inputs.hubAdmin = address(0);
    _inputs.grantRoles = false;

    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withZeroSpokeAdmin_withRoles_reverts() public {
    _inputs.spokeAdmin = address(0);
    _inputs.grantRoles = true;

    vm.expectRevert('invalid admin');
    this.checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withZeroSpokeAdmin_withoutRoles() public {
    _inputs.spokeAdmin = address(0);
    _inputs.grantRoles = false;

    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withZeroGatewayOwner_withGateways_reverts() public {
    _inputs.gatewayOwner = address(0);
    _inputs.deployNativeTokenGateway = true;
    _inputs.deploySignatureGateway = true;

    vm.expectRevert('invalid owner');
    this.checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withZeroGatewayOwner_withoutGateways() public {
    _inputs.gatewayOwner = address(0);
    _inputs.deployNativeTokenGateway = false;
    _inputs.deploySignatureGateway = false;

    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withZeroNativeWrapper_withNativeGateway_reverts() public {
    _inputs.nativeWrapper = address(0);
    _inputs.deployNativeTokenGateway = true;

    vm.expectRevert('invalid native wrapper');
    this.checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withZeroNativeWrapper_withoutNativeGateway() public {
    _inputs.nativeWrapper = address(0);
    _inputs.deployNativeTokenGateway = false;

    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withZeroPositionManagerOwner_withPositionManagers_reverts()
    public
  {
    _inputs.positionManagerOwner = address(0);
    _inputs.deployPositionManagers = true;

    vm.expectRevert('invalid owner');
    this.checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withZeroPositionManagerOwner_withoutPositionManagers() public {
    _inputs.positionManagerOwner = address(0);
    _inputs.deployPositionManagers = false;

    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withoutPositionManagers() public {
    _inputs.deployPositionManagers = false;
    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withDuplicateHubLabels_reverts() public {
    _inputs.hubLabels = new string[](3);
    _inputs.hubLabels[0] = 'core';
    _inputs.hubLabels[1] = 'prime';
    _inputs.hubLabels[2] = 'core';

    vm.expectRevert('duplicate hub label: core');
    this.checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withDuplicateHubLabels_adjacentPair_reverts() public {
    _inputs.hubLabels = new string[](2);
    _inputs.hubLabels[0] = 'core';
    _inputs.hubLabels[1] = 'core';

    vm.expectRevert('duplicate hub label: core');
    this.checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withDuplicateSpokeLabels_reverts() public {
    _inputs.spokeLabels = new string[](3);
    _inputs.spokeLabels[0] = 'main';
    _inputs.spokeLabels[1] = 'lrt';
    _inputs.spokeLabels[2] = 'main';
    _inputs.spokeMaxReservesLimits = _defaultSpokeMaxReservesLimits(3);

    vm.expectRevert('duplicate spoke label: main');
    this.checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withDuplicateSpokeLabels_adjacentPair_reverts() public {
    _inputs.spokeLabels = new string[](2);
    _inputs.spokeLabels[0] = 'main';
    _inputs.spokeLabels[1] = 'main';
    _inputs.spokeMaxReservesLimits = _defaultSpokeMaxReservesLimits(2);

    vm.expectRevert('duplicate spoke label: main');
    this.checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withEmptySpokeMaxReservesLimits_usesDefaults() public {
    _inputs.spokeMaxReservesLimits = new uint16[](0);
    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withMismatchedSpokeMaxReservesLimits_reverts() public {
    _inputs.spokeMaxReservesLimits = new uint16[](1);
    _inputs.spokeMaxReservesLimits[0] = 128;

    vm.expectRevert('spoke labels/limits length mismatch');
    this.checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_accessManagerAdminTransfer() public {
    address newAdmin = makeAddr('newAccessManagerAdmin');
    _inputs.accessManagerAdmin = newAdmin;

    bytes memory hubBytecode = BytecodeHelper.getHubBytecode();
    bytes memory spokeBytecode = BytecodeHelper.getSpokeBytecode();
    bytes memory babylonSpokeBytecode = BytecodeHelper.getBabylonSpokeBytecode();

    vm.startPrank(_deployer);
    OrchestrationReports.FullDeploymentReport memory report = AaveV4DeployOrchestration
      .deployAaveV4(_logger, _deployer, _inputs, hubBytecode, spokeBytecode, babylonSpokeBytecode);
    vm.stopPrank();

    IAccessManagerEnumerable accessManager = IAccessManagerEnumerable(
      report.authorityBatchReport.accessManager
    );

    // newAdmin has DEFAULT_ADMIN_ROLE
    (bool newAdminHasRole, ) = accessManager.hasRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, newAdmin);
    assertTrue(newAdminHasRole, 'new admin should have DEFAULT_ADMIN_ROLE');

    // deployer no longer has DEFAULT_ADMIN_ROLE
    (bool deployerHasRole, ) = accessManager.hasRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, _deployer);
    assertFalse(deployerHasRole, 'deployer should not have DEFAULT_ADMIN_ROLE after transfer');

    // exactly one admin
    assertEq(
      accessManager.getRoleMemberCount(Roles.ACCESS_MANAGER_ADMIN_ROLE),
      1,
      'should have exactly one DEFAULT_ADMIN'
    );
    assertEq(
      accessManager.getRoleMember(Roles.ACCESS_MANAGER_ADMIN_ROLE, 0),
      newAdmin,
      'sole admin should be newAdmin'
    );
  }

  function testAaveV4BatchDeployment_withBabylonSpoke() public {
    _inputs.babylonSpokeLabels = new string[](1);
    _inputs.babylonSpokeLabels[0] = 'babylonSpoke1';

    bytes memory hubBytecode = BytecodeHelper.getHubBytecode();
    bytes memory spokeBytecode = BytecodeHelper.getSpokeBytecode();
    bytes memory babylonSpokeBytecode = BytecodeHelper.getBabylonSpokeBytecode();

    vm.startPrank(_deployer);
    OrchestrationReports.FullDeploymentReport memory report = AaveV4DeployOrchestration
      .deployAaveV4(_logger, _deployer, _inputs, hubBytecode, spokeBytecode, babylonSpokeBytecode);
    vm.stopPrank();

    assertEq(report.babylonSpokeInstanceBatchReports.length, 1, 'babylon spoke report count');
    BatchReports.SpokeInstanceBatchReport memory babylonReport = report
      .babylonSpokeInstanceBatchReports[0]
      .report;
    assertNotEq(babylonReport.spokeProxy, address(0), 'babylon spoke proxy');
    assertNotEq(babylonReport.spokeImplementation, address(0), 'babylon spoke implementation');
    assertNotEq(babylonReport.aaveOracle, address(0), 'babylon spoke oracle');
    assertEq(
      IAccessManaged(babylonReport.spokeProxy).authority(),
      report.authorityBatchReport.accessManager,
      'babylon spoke authority'
    );

    // the babylon config selector is wired to the granular role, granted to the spoke admin
    (bool immediate, ) = IAccessManagerEnumerable(report.authorityBatchReport.accessManager)
      .canCall(
        _inputs.spokeAdmin,
        babylonReport.spokeProxy,
        IBabylonSpoke.updateBabylonLiquidationConfig.selector
      );
    assertTrue(immediate, 'spoke admin can update the babylon liquidation config');
  }

  function testAaveV4BatchDeployment_accessManagerAdminSameAsDeployer() public {
    _inputs.accessManagerAdmin = _deployer;

    bytes memory hubBytecode = BytecodeHelper.getHubBytecode();
    bytes memory spokeBytecode = BytecodeHelper.getSpokeBytecode();
    bytes memory babylonSpokeBytecode = BytecodeHelper.getBabylonSpokeBytecode();

    vm.startPrank(_deployer);
    OrchestrationReports.FullDeploymentReport memory report = AaveV4DeployOrchestration
      .deployAaveV4(_logger, _deployer, _inputs, hubBytecode, spokeBytecode, babylonSpokeBytecode);
    vm.stopPrank();

    IAccessManagerEnumerable accessManager = IAccessManagerEnumerable(
      report.authorityBatchReport.accessManager
    );

    (bool deployerHasRole, ) = accessManager.hasRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, _deployer);
    assertTrue(deployerHasRole, 'deployer should retain DEFAULT_ADMIN_ROLE');
    assertEq(
      accessManager.getRoleMemberCount(Roles.ACCESS_MANAGER_ADMIN_ROLE),
      1,
      'should have exactly one DEFAULT_ADMIN'
    );
  }

  function testAaveV4BatchDeployment_withZeroDeployer_reverts() public {
    _deployer = address(0);

    vm.expectRevert('invalid admin');
    this.checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_fuzz_withoutRoles(
    InputUtils.FullDeployInputs memory deployInputs,
    address deployer,
    bool withoutHubs,
    bool withoutSpokes,
    bool deployNativeTokenGateway,
    bool deploySignatureGateway
  ) public {
    deployInputs.grantRoles = false;
    deployInputs.deployNativeTokenGateway = deployNativeTokenGateway;
    deployInputs.deploySignatureGateway = deploySignatureGateway;
    if (withoutHubs) {
      deployInputs.hubLabels = new string[](0);
    } else {
      deployInputs.hubLabels = _inputs.hubLabels;
    }
    if (withoutSpokes) {
      deployInputs.spokeLabels = new string[](0);
      deployInputs.spokeMaxReservesLimits = new uint16[](0);
    } else {
      deployInputs.spokeLabels = _inputs.spokeLabels;
      deployInputs.spokeMaxReservesLimits = _inputs.spokeMaxReservesLimits;
    }
    deployInputs.babylonSpokeLabels = new string[](0);
    deployInputs.babylonSpokeMaxReservesLimits = new uint16[](0);
    _deployer = deployer;
    _inputs = deployInputs;

    (bool isExpectedError, bytes memory errorMessage) = _getExpectedError();
    if (isExpectedError) {
      vm.expectRevert(errorMessage);
      this.checkedV4Deployment();
    } else {
      checkedV4Deployment();
    }
  }

  function testAaveV4BatchDeployment_fuzz_withRoles(
    InputUtils.FullDeployInputs memory deployInputs,
    address deployer,
    bool withoutHubs,
    bool withoutSpokes,
    bool deployNativeTokenGateway,
    bool deploySignatureGateway
  ) public {
    deployInputs.grantRoles = true;
    deployInputs.deployNativeTokenGateway = deployNativeTokenGateway;
    deployInputs.deploySignatureGateway = deploySignatureGateway;
    if (withoutHubs) {
      deployInputs.hubLabels = new string[](0);
    } else {
      deployInputs.hubLabels = _inputs.hubLabels;
    }
    if (withoutSpokes) {
      deployInputs.spokeLabels = new string[](0);
      deployInputs.spokeMaxReservesLimits = new uint16[](0);
    } else {
      deployInputs.spokeLabels = _inputs.spokeLabels;
      deployInputs.spokeMaxReservesLimits = _inputs.spokeMaxReservesLimits;
    }
    deployInputs.babylonSpokeLabels = new string[](0);
    deployInputs.babylonSpokeMaxReservesLimits = new uint16[](0);
    _deployer = deployer;
    _inputs = deployInputs;

    (bool isExpectedError, bytes memory errorMessage) = _getExpectedError();
    if (isExpectedError) {
      vm.expectRevert(errorMessage);
      this.checkedV4Deployment();
    } else {
      checkedV4Deployment();
    }
  }

  /// @dev Sanitized inputs should never fail when deploying
  function testAaveV4BatchDeployment_fuzz_sanitizedInputs(
    InputUtils.FullDeployInputs memory deployInputs
  ) public {
    deployInputs = _sanitizeInputs(deployInputs);

    assertNotEq(deployInputs.accessManagerAdmin, address(0));
    assertNotEq(deployInputs.hubConfiguratorAdmin, address(0));
    assertNotEq(deployInputs.treasurySpokeOwner, address(0));
    assertNotEq(deployInputs.proxyAdminOwner, address(0));
    assertNotEq(deployInputs.spokeConfiguratorAdmin, address(0));
    assertNotEq(deployInputs.gatewayOwner, address(0));
    assertNotEq(deployInputs.positionManagerOwner, address(0));
    assertNotEq(deployInputs.hubAdmin, address(0));
    assertNotEq(deployInputs.spokeAdmin, address(0));

    _inputs = deployInputs;
    checkedV4Deployment();
  }

  /// @dev Predicts the first revert error based on execution order in deployAaveV4:
  ///      1. AuthorityBatch (deployer as initial admin)
  ///      2. ConfiguratorBatch
  ///      3. TreasurySpokeBatch (treasurySpokeOwner)
  ///      4. Hubs (proxyAdminOwner)
  ///      5. Spokes (proxyAdminOwner)
  ///      6. Gateways (gatewayOwner, nativeWrapper)
  ///      7. PositionManagers (positionManagerOwner)
  ///      8. Roles (hubAdmin, hubConfiguratorAdmin, spokeAdmin, spokeConfiguratorAdmin, accessManagerAdmin)
  function _getExpectedError()
    internal
    view
    returns (bool isExpectedError, bytes memory errorMessage)
  {
    // 1. deployer is initial admin for access manager
    if (_deployer == address(0)) return (true, bytes('invalid admin'));

    // 2. treasury spoke requires owner
    if (_inputs.treasurySpokeOwner == address(0)) {
      return (true, bytes('invalid owner'));
    }

    // 3. hubs and spokes require proxy admin owner when deployed
    if (
      (_inputs.hubLabels.length > 0 || _inputs.spokeLabels.length > 0) &&
      _inputs.proxyAdminOwner == address(0)
    ) {
      return (true, bytes('invalid proxy admin owner'));
    }

    // 4. gateways: native gateway checks nativeWrapper, then owner;
    //    signature gateway checks owner
    if (_inputs.deployNativeTokenGateway && _inputs.nativeWrapper == address(0)) {
      return (true, bytes('invalid native wrapper'));
    }
    if (
      (_inputs.deployNativeTokenGateway || _inputs.deploySignatureGateway) &&
      _inputs.gatewayOwner == address(0)
    ) {
      return (true, bytes('invalid owner'));
    }

    // 5. position managers require owner when deployed
    if (_inputs.deployPositionManagers && _inputs.positionManagerOwner == address(0)) {
      return (true, bytes('invalid owner'));
    }

    if (_inputs.grantRoles) {
      bool hasHubs = _inputs.hubLabels.length > 0;
      bool hasSpokes = _inputs.spokeLabels.length > 0;

      if (
        (hasHubs &&
          (_inputs.hubAdmin == address(0) || _inputs.hubConfiguratorAdmin == address(0))) ||
        (hasSpokes &&
          (_inputs.spokeAdmin == address(0) || _inputs.spokeConfiguratorAdmin == address(0)))
      ) {
        return (true, bytes('invalid admin'));
      }
      if (_inputs.accessManagerAdmin == address(0)) {
        return (true, bytes('invalid admin'));
      }
    }
  }
}
