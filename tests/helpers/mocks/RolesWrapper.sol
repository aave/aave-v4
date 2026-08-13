// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

contract RolesWrapper {
  function ACCESS_MANAGER_ADMIN_ROLE() external pure returns (uint64) { return Roles.ACCESS_MANAGER_ADMIN_ROLE; }
  function HUB_DOMAIN_ADMIN_ROLE() external pure returns (uint64) { return Roles.HUB_DOMAIN_ADMIN_ROLE; }
  function HUB_CONFIGURATOR_ROLE() external pure returns (uint64) { return Roles.HUB_CONFIGURATOR_ROLE; }
  function HUB_FEE_MINTER_ROLE() external pure returns (uint64) { return Roles.HUB_FEE_MINTER_ROLE; }
  function HUB_DEFICIT_ELIMINATOR_ROLE() external pure returns (uint64) { return Roles.HUB_DEFICIT_ELIMINATOR_ROLE; }
  function HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE() external pure returns (uint64) { return Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE; }
  function SPOKE_DOMAIN_ADMIN_ROLE() external pure returns (uint64) { return Roles.SPOKE_DOMAIN_ADMIN_ROLE; }
  function SPOKE_CONFIGURATOR_ROLE() external pure returns (uint64) { return Roles.SPOKE_CONFIGURATOR_ROLE; }
  function SPOKE_USER_POSITION_UPDATER_ROLE() external pure returns (uint64) { return Roles.SPOKE_USER_POSITION_UPDATER_ROLE; }
  function SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE() external pure returns (uint64) { return Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE; }
}
