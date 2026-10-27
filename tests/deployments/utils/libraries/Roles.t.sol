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

  function test_getHubConfiguratorTargetRoles() public pure {
    uint64[] memory roleIds = Roles.getHubConfiguratorTargetRoles();
    assertEq(roleIds.length, 1);
    assertEq(roleIds[0], Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE);
  }

  function test_getHubConfiguratorTargetRoleSelectors() public pure {
    _assertSelectorsEq(
      Roles.getHubConfiguratorTargetRoleSelectors(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE),
      Roles.getHubConfiguratorDomainAdminRoleSelectors()
    );
  }

  function test_getHubConfiguratorTargetRoleSelectors_revertsWith_unknownRole() public {
    vm.expectRevert('unknown hub configurator role');
    _rolesWrapper.getHubConfiguratorTargetRoleSelectors(Roles.HUB_CONFIGURATOR_ROLE);
  }

  function test_getSpokeConfiguratorTargetRoles() public pure {
    uint64[] memory roleIds = Roles.getSpokeConfiguratorTargetRoles();
    assertEq(roleIds.length, 1);
    assertEq(roleIds[0], Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE);
  }

  function test_getSpokeConfiguratorTargetRoleSelectors() public pure {
    _assertSelectorsEq(
      Roles.getSpokeConfiguratorTargetRoleSelectors(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE),
      Roles.getSpokeConfiguratorDomainAdminRoleSelectors()
    );
  }

  function test_getSpokeConfiguratorTargetRoleSelectors_revertsWith_unknownRole() public {
    vm.expectRevert('unknown spoke configurator role');
    _rolesWrapper.getSpokeConfiguratorTargetRoleSelectors(Roles.SPOKE_CONFIGURATOR_ROLE);
  }

  function test_getRoleLabels() public pure {
    (uint64[] memory roleIds, string[] memory labels) = Roles.getRoleLabels();
    assertEq(roleIds.length, 9);
    assertEq(labels.length, roleIds.length);
    assertEq(roleIds[0], Roles.HUB_DOMAIN_ADMIN_ROLE);
    assertEq(labels[0], 'HUB_DOMAIN_ADMIN_ROLE');
    assertEq(roleIds[4], Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE);
    assertEq(labels[4], 'HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE');
    assertEq(roleIds[8], Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE);
    assertEq(labels[8], 'SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE');
    for (uint256 i; i < roleIds.length; ++i) {
      assertNotEq(roleIds[i], Roles.ACCESS_MANAGER_ADMIN_ROLE);
      for (uint256 j = i + 1; j < roleIds.length; ++j) {
        assertNotEq(roleIds[i], roleIds[j]);
      }
    }
  }

  function _assertSelectorsEq(bytes4[] memory a, bytes4[] memory b) internal pure {
    assertEq(abi.encode(a), abi.encode(b));
  }
}
