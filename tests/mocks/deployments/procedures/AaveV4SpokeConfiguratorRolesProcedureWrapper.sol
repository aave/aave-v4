// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4SpokeConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeConfiguratorRolesProcedure.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

contract AaveV4SpokeConfiguratorRolesProcedureWrapper {
  bool public IS_TEST = true;

  function grantSpokeConfiguratorAllRoles(address accessManager, address admin) external {
    AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorAllRoles(accessManager, admin);
  }

  function grantSpokeConfiguratorRole(address accessManager, uint64 role, address admin) external {
    AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorRole(accessManager, role, admin);
  }

  function setupSpokeConfiguratorRoles(address accessManager, address spokeConfigurator) external {
    AaveV4SpokeConfiguratorRolesProcedure.setupSpokeConfiguratorAllRoles(
      accessManager,
      spokeConfigurator
    );
  }

  function setupSpokeConfiguratorRole(
    address accessManager,
    address spokeConfigurator,
    uint64 role,
    bytes4[] memory selectors
  ) external {
    AaveV4SpokeConfiguratorRolesProcedure.setupSpokeConfiguratorRole(
      accessManager,
      spokeConfigurator,
      role,
      selectors
    );
  }

  function getSpokeConfiguratorDomainAdminRoleSelectors() external pure returns (bytes4[] memory) {
    return Roles.getSpokeConfiguratorDomainAdminRoleSelectors();
  }
}
