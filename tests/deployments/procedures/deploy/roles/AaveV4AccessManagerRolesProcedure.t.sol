// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4AccessManagerRolesProcedureTest is ProceduresBase {
  AaveV4AccessManagerRolesProcedureWrapper public aaveV4AccessManagerRolesProcedureWrapper;
  function setUp() public override {
    super.setUp();
    aaveV4AccessManagerRolesProcedureWrapper = new AaveV4AccessManagerRolesProcedureWrapper();
  }

  function test_replaceDefaultAdminRole() public {
    address newAdmin = makeAddr('newAdmin');

    _replaceDefaultAdminRole(newAdmin);
    (bool hasRole, uint32 executionDelay) = IAccessManagerEnumerable(accessManager).hasRole(
      Roles.ACCESS_MANAGER_ADMIN_ROLE,
      newAdmin
    );
    assertTrue(hasRole);
    assertEq(executionDelay, 0);
  }

  function test_replaceDefaultAdminRole_reverts() public {
    address newAdmin = makeAddr('newAdmin');
    vm.expectRevert('invalid access manager');
    aaveV4AccessManagerRolesProcedureWrapper.replaceDefaultAdminRole({
      accessManager: address(0),
      adminToAdd: newAdmin,
      adminToRemove: accessManagerAdmin
    });

    vm.expectRevert('invalid admin');
    aaveV4AccessManagerRolesProcedureWrapper.replaceDefaultAdminRole({
      accessManager: accessManager,
      adminToAdd: address(0),
      adminToRemove: newAdmin
    });

    vm.prank(accessManagerAdmin);
    IAccessManager(accessManager).grantRole(
      Roles.ACCESS_MANAGER_ADMIN_ROLE,
      address(aaveV4AccessManagerRolesProcedureWrapper),
      0
    );
    vm.expectRevert('invalid admin');
    aaveV4AccessManagerRolesProcedureWrapper.replaceDefaultAdminRole({
      accessManager: accessManager,
      adminToAdd: newAdmin,
      adminToRemove: address(0)
    });
  }

  function test_grantAccessManagerAdminRole() public {
    address newAdmin = makeAddr('newAdmin');
    vm.prank(accessManagerAdmin);
    IAccessManager(accessManager).grantRole(
      Roles.ACCESS_MANAGER_ADMIN_ROLE,
      address(aaveV4AccessManagerRolesProcedureWrapper),
      0
    );
    aaveV4AccessManagerRolesProcedureWrapper.grantAccessManagerAdminRole({
      accessManager: accessManager,
      admin: newAdmin
    });

    (bool hasRole, uint32 executionDelay) = IAccessManagerEnumerable(accessManager).hasRole(
      Roles.ACCESS_MANAGER_ADMIN_ROLE,
      newAdmin
    );
    assertTrue(hasRole);
    assertEq(executionDelay, 0);
  }

  function test_grantAccessManagerAdminRole_reverts() public {
    vm.expectRevert('invalid access manager');
    aaveV4AccessManagerRolesProcedureWrapper.grantAccessManagerAdminRole({
      accessManager: address(0),
      admin: admin
    });

    vm.expectRevert('invalid admin');
    aaveV4AccessManagerRolesProcedureWrapper.grantAccessManagerAdminRole({
      accessManager: accessManager,
      admin: address(0)
    });
  }

  function test_labelAllRoles() public {
    vm.prank(accessManagerAdmin);
    IAccessManager(accessManager).grantRole(
      Roles.ACCESS_MANAGER_ADMIN_ROLE,
      address(aaveV4AccessManagerRolesProcedureWrapper),
      0
    );
    aaveV4AccessManagerRolesProcedureWrapper.labelAllRoles(accessManager);

    IAccessManagerEnumerable am = IAccessManagerEnumerable(accessManager);

    // Hub roles
    _assertRoleLabeled(am, Roles.HUB_DOMAIN_ADMIN_ROLE, 'HUB_DOMAIN_ADMIN_ROLE');
    _assertRoleLabeled(am, Roles.HUB_CONFIGURATOR_ROLE, 'HUB_CONFIGURATOR_ROLE');
    _assertRoleLabeled(am, Roles.HUB_FEE_MINTER_ROLE, 'HUB_FEE_MINTER_ROLE');
    _assertRoleLabeled(am, Roles.HUB_DEFICIT_ELIMINATOR_ROLE, 'HUB_DEFICIT_ELIMINATOR_ROLE');

    // HubConfigurator roles
    _assertRoleLabeled(
      am,
      Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      'HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE'
    );
    _assertRoleLabeled(
      am,
      Roles.HUB_CONFIGURATOR_SPOKE_ACTIVE_ROLE,
      'HUB_CONFIGURATOR_SPOKE_ACTIVE_ROLE'
    );
    _assertRoleLabeled(
      am,
      Roles.HUB_CONFIGURATOR_SPOKE_HALTED_ROLE,
      'HUB_CONFIGURATOR_SPOKE_HALTED_ROLE'
    );
    _assertRoleLabeled(am, Roles.HUB_CONFIGURATOR_LISTING_ROLE, 'HUB_CONFIGURATOR_LISTING_ROLE');
    _assertRoleLabeled(
      am,
      Roles.HUB_CONFIGURATOR_EMERGENCY_ROLE,
      'HUB_CONFIGURATOR_EMERGENCY_ROLE'
    );
    _assertRoleLabeled(
      am,
      Roles.HUB_CONFIGURATOR_RISK_MANAGEMENT_ROLE,
      'HUB_CONFIGURATOR_RISK_MANAGEMENT_ROLE'
    );

    // Spoke roles
    _assertRoleLabeled(am, Roles.SPOKE_DOMAIN_ADMIN_ROLE, 'SPOKE_DOMAIN_ADMIN_ROLE');
    _assertRoleLabeled(am, Roles.SPOKE_CONFIGURATOR_ROLE, 'SPOKE_CONFIGURATOR_ROLE');
    _assertRoleLabeled(
      am,
      Roles.SPOKE_USER_POSITION_UPDATER_ROLE,
      'SPOKE_USER_POSITION_UPDATER_ROLE'
    );

    // SpokeConfigurator roles
    _assertRoleLabeled(
      am,
      Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      'SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE'
    );
    _assertRoleLabeled(am, Roles.SPOKE_CONFIGURATOR_PAUSE_ROLE, 'SPOKE_CONFIGURATOR_PAUSE_ROLE');
    _assertRoleLabeled(am, Roles.SPOKE_CONFIGURATOR_FREEZE_ROLE, 'SPOKE_CONFIGURATOR_FREEZE_ROLE');
    _assertRoleLabeled(
      am,
      Roles.SPOKE_CONFIGURATOR_LISTING_ROLE,
      'SPOKE_CONFIGURATOR_LISTING_ROLE'
    );
    _assertRoleLabeled(
      am,
      Roles.SPOKE_CONFIGURATOR_EMERGENCY_ROLE,
      'SPOKE_CONFIGURATOR_EMERGENCY_ROLE'
    );
    _assertRoleLabeled(
      am,
      Roles.SPOKE_CONFIGURATOR_RISK_MANAGEMENT_ROLE,
      'SPOKE_CONFIGURATOR_RISK_MANAGEMENT_ROLE'
    );

    // Total label count
    assertEq(am.getRoleLabelCount(), 19, 'total label count');
  }

  function _assertRoleLabeled(
    IAccessManagerEnumerable am,
    uint64 role,
    string memory label
  ) internal view {
    assertTrue(am.isRoleLabeled(role), string.concat(label, ' labeled'));
    assertEq(am.getLabelOfRole(role), label);
    assertEq(am.getRoleOfLabel(label), role);
  }

  function test_labelAllRoles_reverts_zeroAddress() public {
    vm.expectRevert('invalid access manager');
    aaveV4AccessManagerRolesProcedureWrapper.labelAllRoles(address(0));
  }

  /// @dev Grants a temporary root admin role to the wrapper contract to execute the procedure.
  function _replaceDefaultAdminRole(address newAdmin) internal {
    vm.startPrank(accessManagerAdmin);
    IAccessManager(accessManager).grantRole(
      Roles.ACCESS_MANAGER_ADMIN_ROLE,
      address(aaveV4AccessManagerRolesProcedureWrapper),
      0
    );
    aaveV4AccessManagerRolesProcedureWrapper.replaceDefaultAdminRole({
      accessManager: accessManager,
      adminToAdd: newAdmin,
      adminToRemove: address(aaveV4AccessManagerRolesProcedureWrapper)
    });
    vm.stopPrank();
  }
}
