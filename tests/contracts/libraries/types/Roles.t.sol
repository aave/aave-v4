// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {Test} from 'forge-std/Test.sol';

contract RolesTest is Test {
  function test_constants() public pure {
    assertEq(Roles.ACCESS_MANAGER_ADMIN_ROLE, 0);
    assertEq(Roles.HUB_DOMAIN_BASE_ROLE, 100);
    assertEq(Roles.HUB_CONFIGURATOR_ROLE, 101);
    assertEq(Roles.HUB_FEE_MINTER_ROLE, 102);
    assertEq(Roles.HUB_DEFICIT_ELIMINATOR_ROLE, 103);
    assertEq(Roles.HUB_CONFIGURATOR_DOMAIN_BASE_ROLE, 200);
    assertEq(Roles.HUB_CONFIGURATOR_RISK_MANAGEMENT_ROLE, 201);
    assertEq(Roles.HUB_CONFIGURATOR_EMERGENCY_ROLE, 202);
    assertEq(Roles.SPOKE_DOMAIN_BASE_ROLE, 300);
    assertEq(Roles.SPOKE_CONFIGURATOR_ROLE, 301);
    assertEq(Roles.SPOKE_USER_POSITION_UPDATER_ROLE, 302);
    assertEq(Roles.SPOKE_CONFIGURATOR_DOMAIN_BASE_ROLE, 400);
    assertEq(Roles.SPOKE_CONFIGURATOR_RISK_MANAGEMENT_ROLE, 401);
    assertEq(Roles.SPOKE_CONFIGURATOR_EMERGENCY_ROLE, 402);
  }
}
