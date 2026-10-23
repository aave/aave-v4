// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {RolesWrapper} from 'tests/helpers/mocks/deployments/libraries/RolesWrapper.sol';

contract RolesTest is Test {
  RolesWrapper internal _rolesWrapper;

  function setUp() public {
    _rolesWrapper = new RolesWrapper();
  }

  function test_getHubRoles() public pure {
    uint64[] memory roleIds = Roles.getHubRoles();
    assertEq(roleIds.length, 3);
    assertEq(roleIds[0], Roles.HUB_CONFIGURATOR_ROLE);
    assertEq(roleIds[1], Roles.HUB_FEE_MINTER_ROLE);
    assertEq(roleIds[2], Roles.HUB_DEFICIT_ELIMINATOR_ROLE);
  }

  function test_getHubRoleSelectors() public pure {
    _assertSelectorsEq(
      Roles.getHubRoleSelectors(Roles.HUB_CONFIGURATOR_ROLE),
      Roles.getHubConfiguratorRoleSelectors()
    );
    _assertSelectorsEq(
      Roles.getHubRoleSelectors(Roles.HUB_FEE_MINTER_ROLE),
      Roles.getHubFeeMinterRoleSelectors()
    );
    _assertSelectorsEq(
      Roles.getHubRoleSelectors(Roles.HUB_DEFICIT_ELIMINATOR_ROLE),
      Roles.getHubDeficitEliminatorRoleSelectors()
    );
  }

  function test_getHubRoleSelectors_revertsWith_unknownRole() public {
    vm.expectRevert('unknown hub role');
    _rolesWrapper.getHubRoleSelectors(Roles.HUB_DOMAIN_ADMIN_ROLE);
  }

  function test_getSpokeRoles() public pure {
    uint64[] memory roleIds = Roles.getSpokeRoles();
    assertEq(roleIds.length, 2);
    assertEq(roleIds[0], Roles.SPOKE_USER_POSITION_UPDATER_ROLE);
    assertEq(roleIds[1], Roles.SPOKE_CONFIGURATOR_ROLE);
  }

  function test_getSpokeRoleSelectors() public pure {
    _assertSelectorsEq(
      Roles.getSpokeRoleSelectors(Roles.SPOKE_USER_POSITION_UPDATER_ROLE),
      Roles.getSpokePositionUpdaterRoleSelectors()
    );
    _assertSelectorsEq(
      Roles.getSpokeRoleSelectors(Roles.SPOKE_CONFIGURATOR_ROLE),
      Roles.getSpokeConfiguratorRoleSelectors()
    );
  }

  function test_getSpokeRoleSelectors_revertsWith_unknownRole() public {
    vm.expectRevert('unknown spoke role');
    _rolesWrapper.getSpokeRoleSelectors(Roles.SPOKE_DOMAIN_ADMIN_ROLE);
  }

  function _assertSelectorsEq(bytes4[] memory a, bytes4[] memory b) internal pure {
    assertEq(abi.encode(a), abi.encode(b));
  }
}
