// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4HubSpokeFactoryRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubSpokeFactoryRolesProcedure.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

contract AaveV4HubSpokeFactoryRolesProcedureWrapper {
  bool public IS_TEST = true;

  function grantHubSpokeFactoryAllRoles(address accessManager, address admin) external {
    AaveV4HubSpokeFactoryRolesProcedure.grantHubSpokeFactoryAllRoles(accessManager, admin);
  }

  function grantHubSpokeFactoryRole(address accessManager, uint64 role, address admin) external {
    AaveV4HubSpokeFactoryRolesProcedure.grantHubSpokeFactoryRole(accessManager, role, admin);
  }

  function setupHubSpokeFactoryRoles(address accessManager, address hubSpokeFactory) external {
    AaveV4HubSpokeFactoryRolesProcedure.setupHubSpokeFactoryAllRoles(
      accessManager,
      hubSpokeFactory
    );
  }

  function setupHubSpokeFactoryRole(
    address accessManager,
    address hubSpokeFactory,
    uint64 role,
    bytes4[] memory selectors
  ) external {
    AaveV4HubSpokeFactoryRolesProcedure.setupHubSpokeFactoryRole(
      accessManager,
      hubSpokeFactory,
      role,
      selectors
    );
  }

  function getHubSpokeFactoryDomainAdminRoleSelectors() external pure returns (bytes4[] memory) {
    return Roles.getHubSpokeFactoryDomainAdminRoleSelectors();
  }
}
