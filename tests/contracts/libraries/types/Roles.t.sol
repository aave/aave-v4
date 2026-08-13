// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {Test} from 'forge-std/Test.sol';
import {RolesWrapper} from 'tests/helpers/mocks/RolesWrapper.sol';

contract RolesTest is Test {
  RolesWrapper internal roles;

  function setUp() public {
    roles = new RolesWrapper();
    if (vm.envOr('TEST_VYPER', false)) {
      vm.etch(address(roles), vm.getDeployedCode('RolesHarness.vy:RolesHarness'));
    }
  }

  function test_constants() public view {
    assertEq(roles.ACCESS_MANAGER_ADMIN_ROLE(), 0);
    assertEq(roles.HUB_DOMAIN_ADMIN_ROLE(), 100);
    assertEq(roles.HUB_CONFIGURATOR_ROLE(), 101);
    assertEq(roles.HUB_FEE_MINTER_ROLE(), 102);
    assertEq(roles.HUB_DEFICIT_ELIMINATOR_ROLE(), 103);
    assertEq(roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE(), 200);
    assertEq(roles.SPOKE_DOMAIN_ADMIN_ROLE(), 300);
    assertEq(roles.SPOKE_CONFIGURATOR_ROLE(), 301);
    assertEq(roles.SPOKE_USER_POSITION_UPDATER_ROLE(), 302);
    assertEq(roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE(), 400);
  }
}
