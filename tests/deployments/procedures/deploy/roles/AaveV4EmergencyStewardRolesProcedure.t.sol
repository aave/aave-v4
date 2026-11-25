// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4EmergencyStewardRolesProcedureTest is ProceduresBase {
  AaveV4EmergencyStewardRolesProcedureWrapper public wrapper;
  address public emergencySteward = makeAddr('emergencySteward');

  function setUp() public override {
    super.setUp();
    wrapper = new AaveV4EmergencyStewardRolesProcedureWrapper();
  }

  function test_grantEmergencyStewardRole_reverts() public {
    vm.expectRevert('invalid access manager');
    wrapper.grantEmergencyStewardRole({
      accessManager: address(0),
      role: Roles.EMERGENCY_STEWARD_DOMAIN_ADMIN_ROLE,
      admin: admin
    });

    vm.expectRevert('invalid admin');
    wrapper.grantEmergencyStewardRole({
      accessManager: accessManager,
      role: Roles.EMERGENCY_STEWARD_DOMAIN_ADMIN_ROLE,
      admin: address(0)
    });
  }

  function test_setupEmergencyStewardRoles_reverts() public {
    vm.expectRevert('invalid access manager');
    wrapper.setupEmergencyStewardRoles({
      accessManager: address(0),
      emergencySteward: emergencySteward
    });

    vm.expectRevert('invalid emergency steward');
    wrapper.setupEmergencyStewardRoles({
      accessManager: accessManager,
      emergencySteward: address(0)
    });
  }

  function test_setupEmergencyStewardRole_reverts() public {
    bytes4[] memory selectors = wrapper.getEmergencyStewardDomainAdminRoleSelectors();

    vm.expectRevert('invalid access manager');
    wrapper.setupEmergencyStewardRole({
      accessManager: address(0),
      emergencySteward: emergencySteward,
      role: Roles.EMERGENCY_STEWARD_DOMAIN_ADMIN_ROLE,
      selectors: selectors
    });

    vm.expectRevert('invalid emergency steward');
    wrapper.setupEmergencyStewardRole({
      accessManager: accessManager,
      emergencySteward: address(0),
      role: Roles.EMERGENCY_STEWARD_DOMAIN_ADMIN_ROLE,
      selectors: selectors
    });
  }

  function test_grantEmergencyStewardAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantEmergencyStewardAllRoles({accessManager: accessManager, admin: admin});

    (bool hasRole, ) = IAccessManager(accessManager).hasRole(
      Roles.EMERGENCY_STEWARD_DOMAIN_ADMIN_ROLE,
      admin
    );
    assertTrue(hasRole);
  }

  function test_setupEmergencyStewardRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.setupEmergencyStewardRoles({
      accessManager: accessManager,
      emergencySteward: emergencySteward
    });

    bytes4[] memory selectors = wrapper.getEmergencyStewardDomainAdminRoleSelectors();
    for (uint256 i; i < selectors.length; i++) {
      assertEq(
        IAccessManager(accessManager).getTargetFunctionRole(emergencySteward, selectors[i]),
        Roles.EMERGENCY_STEWARD_DOMAIN_ADMIN_ROLE
      );
    }
  }

  function test_getEmergencyStewardDomainAdminRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getEmergencyStewardDomainAdminRoleSelectors();
    assertEq(selectors.length, 7);
    assertEq(selectors[0], IEmergencySteward.pauseAllReserves.selector);
    assertEq(selectors[1], IEmergencySteward.unpauseAllReserves.selector);
    assertEq(selectors[2], IEmergencySteward.freezeSpoke.selector);
    assertEq(selectors[3], IEmergencySteward.unfreezeSpoke.selector);
    assertEq(selectors[4], IEmergencySteward.freezeAsset.selector);
    assertEq(selectors[5], IEmergencySteward.unfreezeAsset.selector);
    assertEq(selectors[6], IEmergencySteward.deactivatePositionManager.selector);
  }

  function test_canCall_emergencyStewardAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantEmergencyStewardAllRoles({accessManager: accessManager, admin: admin});
    wrapper.setupEmergencyStewardRoles({
      accessManager: accessManager,
      emergencySteward: emergencySteward
    });

    _assertCanCall(emergencySteward, wrapper.getEmergencyStewardDomainAdminRoleSelectors());
  }

  function _grantAdminToWrapper(address _wrapper) internal {
    vm.prank(accessManagerAdmin);
    IAccessManager(accessManager).grantRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, _wrapper, 0);
  }
}
