// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

/// @title AaveV4HubRolesProcedure Library
/// @author Aave Labs
/// @notice Procedures for granting and setting up Hub roles on the AccessManager.
library AaveV4HubRolesProcedure {
  /// @notice Grants all Hub granular roles to `admin`:
  ///   - HUB_CONFIGURATOR_ROLE
  ///   - HUB_FEE_MINTER_ROLE
  ///   - HUB_DEFICIT_ELIMINATOR_ROLE
  /// @param accessManager The address of the AccessManager contract.
  /// @param admin The address to receive all Hub roles.
  function grantHubAllRoles(address accessManager, address admin) internal {
    uint64[] memory roleIds = Roles.getHubRoles();
    for (uint256 i; i < roleIds.length; ++i) {
      grantHubRole(accessManager, roleIds[i], admin);
    }
  }

  /// @notice Grants a specific Hub role to the given address.
  /// @param accessManager The address of the AccessManager contract.
  /// @param role The role identifier to grant.
  /// @param admin The address to receive the role.
  function grantHubRole(address accessManager, uint64 role, address admin) internal {
    require(accessManager != address(0), 'invalid access manager');
    require(admin != address(0), 'invalid admin');
    IAccessManager(accessManager).grantRole({roleId: role, account: admin, executionDelay: 0});
  }

  /// @notice Sets up all Hub roles by assigning their target function selectors.
  /// @param accessManager The address of the AccessManager contract.
  /// @param hub The address of the Hub contract.
  function setupHubAllRoles(address accessManager, address hub) internal {
    uint64[] memory roleIds = Roles.getHubRoles();
    for (uint256 i; i < roleIds.length; ++i) {
      setupHubRole(accessManager, hub, roleIds[i], Roles.getHubRoleSelectors(roleIds[i]));
    }
  }

  /// @notice Sets up a specific Hub role by assigning function selectors to the target.
  /// @param accessManager The address of the AccessManager contract.
  /// @param hub The address of the Hub contract.
  /// @param roleId The role identifier to associate with the selectors.
  /// @param selectors The function selectors to assign to the role.
  function setupHubRole(
    address accessManager,
    address hub,
    uint64 roleId,
    bytes4[] memory selectors
  ) internal {
    require(accessManager != address(0), 'invalid access manager');
    require(hub != address(0), 'invalid hub');
    IAccessManager(accessManager).setTargetFunctionRole({
      target: hub,
      selectors: selectors,
      roleId: roleId
    });
  }
}
