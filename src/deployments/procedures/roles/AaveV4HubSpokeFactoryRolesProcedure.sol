// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

/// @title AaveV4HubSpokeFactoryRolesProcedure Library
/// @author Aave Labs
/// @notice Procedures for granting and setting up HubSpokeFactory roles on the AccessManager.
library AaveV4HubSpokeFactoryRolesProcedure {
  /// @notice Grants the HubSpokeFactory domain admin role (500) to `admin`.
  /// @param accessManager The address of the AccessManager contract.
  /// @param admin The address to receive the HubSpokeFactory domain admin role.
  function grantHubSpokeFactoryAllRoles(address accessManager, address admin) internal {
    grantHubSpokeFactoryRole(accessManager, Roles.HUB_SPOKE_FACTORY_DOMAIN_ADMIN_ROLE, admin);
  }

  /// @notice Grants a specific HubSpokeFactory role to the given address.
  /// @param accessManager The address of the AccessManager contract.
  /// @param role The role identifier to grant.
  /// @param admin The address to receive the role.
  function grantHubSpokeFactoryRole(address accessManager, uint64 role, address admin) internal {
    require(accessManager != address(0), 'invalid access manager');
    require(admin != address(0), 'invalid admin');
    IAccessManager(accessManager).grantRole({roleId: role, account: admin, executionDelay: 0});
  }

  /// @notice Sets up the HubSpokeFactory domain admin role with all target selectors.
  /// @param accessManager The address of the AccessManager contract.
  /// @param hubSpokeFactory The address of the HubSpokeFactory contract.
  function setupHubSpokeFactoryAllRoles(address accessManager, address hubSpokeFactory) internal {
    setupHubSpokeFactoryRole(
      accessManager,
      hubSpokeFactory,
      Roles.HUB_SPOKE_FACTORY_DOMAIN_ADMIN_ROLE,
      Roles.getHubSpokeFactoryDomainAdminRoleSelectors()
    );
  }

  /// @notice Sets up a specific HubSpokeFactory role by assigning function selectors to the target.
  /// @param accessManager The address of the AccessManager contract.
  /// @param hubSpokeFactory The address of the HubSpokeFactory contract.
  /// @param role The role identifier to associate with the selectors.
  /// @param selectors The function selectors to assign to the role.
  function setupHubSpokeFactoryRole(
    address accessManager,
    address hubSpokeFactory,
    uint64 role,
    bytes4[] memory selectors
  ) internal {
    require(accessManager != address(0), 'invalid access manager');
    require(hubSpokeFactory != address(0), 'invalid hub spoke factory');
    IAccessManager(accessManager).setTargetFunctionRole(hubSpokeFactory, selectors, role);
  }
}
