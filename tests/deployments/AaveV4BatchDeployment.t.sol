// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/utils/BatchTestProcedures.sol';

contract AaveV4BatchDeploymentTest is BatchTestProcedures {
  function setUp() public override {
    super.setUp();

    _inputs = InputUtils.FullDeployInputs({
      accessManagerAdmin: makeAddr('accessManagerAdmin'),
      proxyAdminOwner: makeAddr('proxyAdminOwner'),
      hubAdmin: makeAddr('hubAdmin'),
      hubConfiguratorAdmin: makeAddr('hubConfiguratorAdmin'),
      treasurySpokeOwner: makeAddr('treasurySpokeOwner'),
      feeSharesMinterOwner: makeAddr('feeSharesMinterOwner'),
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

  /// @dev Reverts as feeSharesMinter is always deployed and owner is required
  function testAaveV4BatchDeployment_fuzz_withZeroFeeSharesMinterOwner(bool grantRoles) public {
    _inputs.feeSharesMinterOwner = address(0);
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

    vm.startPrank(_deployer);
    OrchestrationReports.FullDeploymentReport memory report = AaveV4DeployOrchestration
      .deployAaveV4(_logger, _deployer, _inputs, hubBytecode, spokeBytecode);
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

  function testAaveV4BatchDeployment_accessManagerAdminSameAsDeployer() public {
    _inputs.accessManagerAdmin = _deployer;

    bytes memory hubBytecode = BytecodeHelper.getHubBytecode();
    bytes memory spokeBytecode = BytecodeHelper.getSpokeBytecode();

    vm.startPrank(_deployer);
    OrchestrationReports.FullDeploymentReport memory report = AaveV4DeployOrchestration
      .deployAaveV4(_logger, _deployer, _inputs, hubBytecode, spokeBytecode);
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
    assertNotEq(deployInputs.feeSharesMinterOwner, address(0));
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
  ///      4. FeeSharesMinterBatch (feeSharesMinterOwner)
  ///      5. Hubs (proxyAdminOwner)
  ///      6. Spokes (proxyAdminOwner)
  ///      7. Gateways (gatewayOwner, nativeWrapper)
  ///      8. PositionManagers (positionManagerOwner)
  ///      9. Roles (hubAdmin, hubConfiguratorAdmin, spokeAdmin, spokeConfiguratorAdmin, accessManagerAdmin)
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

    // 3. fee shares minter requires owner
    if (_inputs.feeSharesMinterOwner == address(0)) {
      return (true, bytes('invalid owner'));
    }

    // 5. hubs and spokes require proxy admin owner when deployed
    if (
      (_inputs.hubLabels.length > 0 || _inputs.spokeLabels.length > 0) &&
      _inputs.proxyAdminOwner == address(0)
    ) {
      return (true, bytes('invalid proxy admin owner'));
    }

    // 6. gateways: native gateway checks nativeWrapper, then owner;
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

    // 7. position managers require owner when deployed
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
