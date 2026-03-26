// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4SpokeRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

contract AaveV4SpokeRolesProcedureWrapper {
  bool public IS_TEST = true;

  function grantSpokeAllRoles(address accessManager, address admin) external {
    AaveV4SpokeRolesProcedure.grantSpokeAllRoles(accessManager, admin);
  }

  function grantSpokeRole(address accessManager, uint64 role, address admin) external {
    AaveV4SpokeRolesProcedure.grantSpokeRole(accessManager, role, admin);
  }

  function setupSpokeRoles(address accessManager, address spoke) external {
    AaveV4SpokeRolesProcedure.setupSpokeAllRoles(accessManager, spoke);
  }

  function setupSpokePositionUpdaterRole(address accessManager, address spoke) external {
    AaveV4SpokeRolesProcedure.setupSpokeRole(
      accessManager,
      spoke,
      Roles.SPOKE_USER_POSITION_UPDATER_ROLE,
      Roles.getSpokePositionUpdaterRoleSelectors()
    );
  }

  function setupSpokeConfiguratorRole(address accessManager, address spoke) external {
    AaveV4SpokeRolesProcedure.setupSpokeRole(
      accessManager,
      spoke,
      Roles.SPOKE_CONFIGURATOR_ROLE,
      Roles.getSpokeConfiguratorRoleSelectors()
    );
  }

  function getSpokePositionUpdaterRoleSelectors() external pure returns (bytes4[] memory) {
    return Roles.getSpokePositionUpdaterRoleSelectors();
  }

  function getSpokeConfiguratorRoleSelectors() external pure returns (bytes4[] memory) {
    return Roles.getSpokeConfiguratorRoleSelectors();
  }
}
