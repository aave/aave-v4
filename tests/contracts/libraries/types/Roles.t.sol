// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Roles} from 'src/libraries/types/Roles.sol';
import {Test} from 'forge-std/Test.sol';

contract RolesTest is Test {
  function test_constants() public pure {
    assertEq(Roles.DEFAULT_ADMIN_ROLE, 0);
    assertEq(Roles.HUB_ADMIN_ROLE, 1);
    assertEq(Roles.SPOKE_ADMIN_ROLE, 2);
    assertEq(Roles.USER_POSITION_UPDATER_ROLE, 3);
    assertEq(Roles.HUB_CONFIGURATOR_ROLE, 4);
    assertEq(Roles.SPOKE_CONFIGURATOR_ROLE, 5);
    assertEq(Roles.DEFICIT_ELIMINATOR_ROLE, 6);
  }
}
