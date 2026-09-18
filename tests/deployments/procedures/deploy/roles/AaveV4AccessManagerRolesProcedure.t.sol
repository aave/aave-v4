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

    IAccessManagerEnumerable accessManager = IAccessManagerEnumerable(accessManager);

    // Hub roles
    assertTrue(
      accessManager.isRoleLabeled(Roles.HUB_DOMAIN_ADMIN_ROLE),
      'HUB_DOMAIN_ADMIN labeled'
    );
    assertEq(accessManager.getLabelOfRole(Roles.HUB_DOMAIN_ADMIN_ROLE), 'HUB_DOMAIN_ADMIN_ROLE');
    assertEq(accessManager.getRoleOfLabel('HUB_DOMAIN_ADMIN_ROLE'), Roles.HUB_DOMAIN_ADMIN_ROLE);

    assertTrue(
      accessManager.isRoleLabeled(Roles.HUB_CONFIGURATOR_ROLE),
      'HUB_CONFIGURATOR labeled'
    );
    assertEq(accessManager.getLabelOfRole(Roles.HUB_CONFIGURATOR_ROLE), 'HUB_CONFIGURATOR_ROLE');
    assertEq(accessManager.getRoleOfLabel('HUB_CONFIGURATOR_ROLE'), Roles.HUB_CONFIGURATOR_ROLE);

    assertTrue(accessManager.isRoleLabeled(Roles.HUB_FEE_MINTER_ROLE), 'HUB_FEE_MINTER labeled');
    assertEq(accessManager.getLabelOfRole(Roles.HUB_FEE_MINTER_ROLE), 'HUB_FEE_MINTER_ROLE');
    assertEq(accessManager.getRoleOfLabel('HUB_FEE_MINTER_ROLE'), Roles.HUB_FEE_MINTER_ROLE);

    assertTrue(
      accessManager.isRoleLabeled(Roles.HUB_DEFICIT_ELIMINATOR_ROLE),
      'HUB_DEFICIT_ELIMINATOR labeled'
    );
    assertEq(
      accessManager.getLabelOfRole(Roles.HUB_DEFICIT_ELIMINATOR_ROLE),
      'HUB_DEFICIT_ELIMINATOR_ROLE'
    );
    assertEq(
      accessManager.getRoleOfLabel('HUB_DEFICIT_ELIMINATOR_ROLE'),
      Roles.HUB_DEFICIT_ELIMINATOR_ROLE
    );

    // HubConfigurator roles
    assertTrue(
      accessManager.isRoleLabeled(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE),
      'HUB_CONFIGURATOR_DOMAIN_ADMIN labeled'
    );
    assertEq(
      accessManager.getLabelOfRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE),
      'HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE'
    );
    assertEq(
      accessManager.getRoleOfLabel('HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE'),
      Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE
    );

    // Spoke roles
    assertTrue(
      accessManager.isRoleLabeled(Roles.SPOKE_DOMAIN_ADMIN_ROLE),
      'SPOKE_DOMAIN_ADMIN labeled'
    );
    assertEq(
      accessManager.getLabelOfRole(Roles.SPOKE_DOMAIN_ADMIN_ROLE),
      'SPOKE_DOMAIN_ADMIN_ROLE'
    );
    assertEq(
      accessManager.getRoleOfLabel('SPOKE_DOMAIN_ADMIN_ROLE'),
      Roles.SPOKE_DOMAIN_ADMIN_ROLE
    );

    assertTrue(
      accessManager.isRoleLabeled(Roles.SPOKE_CONFIGURATOR_ROLE),
      'SPOKE_CONFIGURATOR labeled'
    );
    assertEq(
      accessManager.getLabelOfRole(Roles.SPOKE_CONFIGURATOR_ROLE),
      'SPOKE_CONFIGURATOR_ROLE'
    );
    assertEq(
      accessManager.getRoleOfLabel('SPOKE_CONFIGURATOR_ROLE'),
      Roles.SPOKE_CONFIGURATOR_ROLE
    );

    assertTrue(
      accessManager.isRoleLabeled(Roles.SPOKE_USER_POSITION_UPDATER_ROLE),
      'SPOKE_USER_POSITION_UPDATER labeled'
    );
    assertEq(
      accessManager.getLabelOfRole(Roles.SPOKE_USER_POSITION_UPDATER_ROLE),
      'SPOKE_USER_POSITION_UPDATER_ROLE'
    );
    assertEq(
      accessManager.getRoleOfLabel('SPOKE_USER_POSITION_UPDATER_ROLE'),
      Roles.SPOKE_USER_POSITION_UPDATER_ROLE
    );

    // SpokeConfigurator roles
    assertTrue(
      accessManager.isRoleLabeled(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE),
      'SPOKE_CONFIGURATOR_DOMAIN_ADMIN labeled'
    );
    assertEq(
      accessManager.getLabelOfRole(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE),
      'SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE'
    );
    assertEq(
      accessManager.getRoleOfLabel('SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE'),
      Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE
    );

    // Total label count
    assertEq(accessManager.getRoleLabelCount(), 9, 'total label count');
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
