// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

/// @title AaveV4SpokeRolesProcedure Library
/// @author Aave Labs
/// @notice Procedures for granting and setting up spoke roles on the AccessManager.
library AaveV4SpokeRolesProcedure {
  /// @notice Grants all spoke granular roles to `admin`.
  /// @param accessManager The address of the AccessManager contract.
  /// @param admin The address to receive all spoke roles.
  function grantSpokeAllRoles(address accessManager, address admin) internal {
    grantSpokeRole(accessManager, Roles.SPOKE_USER_POSITION_UPDATER_ROLE, admin);
    grantSpokeRole(accessManager, Roles.SPOKE_CONFIGURATOR_ROLE, admin);
  }

  /// @notice Grants a specific spoke role to the given address.
  /// @param accessManager The address of the AccessManager contract.
  /// @param role The role identifier to grant.
  /// @param admin The address to receive the role.
  function grantSpokeRole(address accessManager, uint64 role, address admin) internal {
    require(accessManager != address(0), 'invalid access manager');
    require(admin != address(0), 'invalid admin');
    IAccessManager(accessManager).grantRole({roleId: role, account: admin, executionDelay: 0});
  }

  /// @notice Sets up all spoke roles by assigning their target function selectors.
  /// @param accessManager The address of the AccessManager contract.
  /// @param spoke The address of the Spoke contract.
  function setupSpokeAllRoles(address accessManager, address spoke) internal {
    setupSpokeRole({
      accessManager: accessManager,
      spoke: spoke,
      roleId: Roles.SPOKE_USER_POSITION_UPDATER_ROLE,
      selectors: Roles.getSpokePositionUpdaterRoleSelectors()
    });
    setupSpokeRole({
      accessManager: accessManager,
      spoke: spoke,
      roleId: Roles.SPOKE_CONFIGURATOR_ROLE,
      selectors: Roles.getSpokeConfiguratorRoleSelectors()
    });
  }

  /// @notice Sets up a specific spoke role by assigning function selectors to the target.
  /// @param accessManager The address of the AccessManager contract.
  /// @param spoke The address of the Spoke contract.
  /// @param roleId The role identifier to associate with the selectors.
  /// @param selectors The function selectors to assign to the role.
  function setupSpokeRole(
    address accessManager,
    address spoke,
    uint64 roleId,
    bytes4[] memory selectors
  ) internal {
    require(accessManager != address(0), 'invalid access manager');
    require(spoke != address(0), 'invalid spoke');
    IAccessManager(accessManager).setTargetFunctionRole({
      target: spoke,
      selectors: selectors,
      roleId: roleId
    });
  }
}
