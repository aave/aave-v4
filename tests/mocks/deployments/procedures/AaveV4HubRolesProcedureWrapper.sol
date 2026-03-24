// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4HubRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

contract AaveV4HubRolesProcedureWrapper {
  bool public IS_TEST = true;

  function grantHubAllRoles(address accessManager, address admin) external {
    AaveV4HubRolesProcedure.grantHubAllRoles(accessManager, admin);
  }

  function grantHubRole(address accessManager, uint64 role, address admin) external {
    AaveV4HubRolesProcedure.grantHubRole(accessManager, role, admin);
  }

  function setupHubRoles(address accessManager, address hub) external {
    AaveV4HubRolesProcedure.setupHubAllRoles(accessManager, hub);
  }

  function setupHubFeeMinterRole(address accessManager, address hub) external {
    AaveV4HubRolesProcedure.setupHubRole(
      accessManager,
      hub,
      Roles.HUB_FEE_MINTER_ROLE,
      Roles.getHubFeeMinterRoleSelectors()
    );
  }

  function setupHubConfiguratorRole(address accessManager, address hub) external {
    AaveV4HubRolesProcedure.setupHubRole(
      accessManager,
      hub,
      Roles.HUB_CONFIGURATOR_ROLE,
      Roles.getHubConfiguratorRoleSelectors()
    );
  }

  function getHubFeeMinterRoleSelectors() external pure returns (bytes4[] memory) {
    return Roles.getHubFeeMinterRoleSelectors();
  }

  function setupHubDeficitEliminatorRole(address accessManager, address hub) external {
    AaveV4HubRolesProcedure.setupHubRole(
      accessManager,
      hub,
      Roles.HUB_DEFICIT_ELIMINATOR_ROLE,
      Roles.getHubDeficitEliminatorRoleSelectors()
    );
  }

  function getHubConfiguratorRoleSelectors() external pure returns (bytes4[] memory) {
    return Roles.getHubConfiguratorRoleSelectors();
  }

  function getHubDeficitEliminatorRoleSelectors() external pure returns (bytes4[] memory) {
    return Roles.getHubDeficitEliminatorRoleSelectors();
  }
}
