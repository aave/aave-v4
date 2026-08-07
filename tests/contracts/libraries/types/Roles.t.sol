// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {Test} from 'forge-std/Test.sol';

contract RolesTest is Test {
  function test_constants() public pure {
    assertEq(Roles.ACCESS_MANAGER_ADMIN_ROLE, 0);
    assertEq(Roles.HUB_DOMAIN_ADMIN_ROLE, 100);
    assertEq(Roles.HUB_CONFIGURATOR_ROLE, 101);
    assertEq(Roles.HUB_FEE_MINTER_ROLE, 102);
    assertEq(Roles.HUB_DEFICIT_ELIMINATOR_ROLE, 103);
    assertEq(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, 200);
    assertEq(Roles.HUB_CONFIGURATOR_SPOKE_ACTIVE_ROLE, 201);
    assertEq(Roles.HUB_CONFIGURATOR_SPOKE_HALTED_ROLE, 202);
    assertEq(Roles.HUB_CONFIGURATOR_LISTING_ROLE, 203);
    assertEq(Roles.HUB_CONFIGURATOR_EMERGENCY_ROLE, 204);
    assertEq(Roles.HUB_CONFIGURATOR_RISK_MANAGEMENT_ROLE, 205);
    assertEq(Roles.SPOKE_DOMAIN_ADMIN_ROLE, 300);
    assertEq(Roles.SPOKE_CONFIGURATOR_ROLE, 301);
    assertEq(Roles.SPOKE_USER_POSITION_UPDATER_ROLE, 302);
    assertEq(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, 400);
    assertEq(Roles.SPOKE_CONFIGURATOR_PAUSE_ROLE, 401);
    assertEq(Roles.SPOKE_CONFIGURATOR_FREEZE_ROLE, 402);
    assertEq(Roles.SPOKE_CONFIGURATOR_LISTING_ROLE, 403);
    assertEq(Roles.SPOKE_CONFIGURATOR_EMERGENCY_ROLE, 404);
    assertEq(Roles.SPOKE_CONFIGURATOR_RISK_MANAGEMENT_ROLE, 405);
  }
}
