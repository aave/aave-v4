// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

/// @title AaveV4SpokeConfiguratorRolesProcedure Library
/// @author Aave Labs
/// @notice Procedures for granting and setting up SpokeConfigurator roles on the AccessManager.
library AaveV4SpokeConfiguratorRolesProcedure {
  /// @notice Grants all SpokeConfigurator roles to `admin`.
  /// @param accessManager The address of the AccessManager contract.
  /// @param admin The address to receive all SpokeConfigurator roles.
  function grantSpokeConfiguratorAllRoles(address accessManager, address admin) internal {
    uint64[] memory roleIds = Roles.getSpokeConfiguratorTargetRoles();
    for (uint256 i; i < roleIds.length; ++i) {
      grantSpokeConfiguratorRole(accessManager, roleIds[i], admin);
    }
  }

  /// @notice Grants a specific SpokeConfigurator role to the given address.
  /// @param accessManager The address of the AccessManager contract.
  /// @param role The role identifier to grant.
  /// @param admin The address to receive the role.
  function grantSpokeConfiguratorRole(address accessManager, uint64 role, address admin) internal {
    require(accessManager != address(0), 'invalid access manager');
    require(admin != address(0), 'invalid admin');
    IAccessManager(accessManager).grantRole({roleId: role, account: admin, executionDelay: 0});
  }

  /// @notice Sets up all SpokeConfigurator roles by assigning their target function selectors.
  function setupSpokeConfiguratorAllRoles(
    address accessManager,
    address spokeConfigurator
  ) internal {
    uint64[] memory roleIds = Roles.getSpokeConfiguratorTargetRoles();
    for (uint256 i; i < roleIds.length; ++i) {
      setupSpokeConfiguratorRole(
        accessManager,
        spokeConfigurator,
        roleIds[i],
        Roles.getSpokeConfiguratorTargetRoleSelectors(roleIds[i])
      );
    }
  }

  /// @notice Sets up a specific SpokeConfigurator role by assigning function selectors to the target.
  /// @param accessManager The address of the AccessManager contract.
  /// @param spokeConfigurator The address of the SpokeConfigurator contract.
  /// @param role The role identifier to associate with the selectors.
  /// @param selectors The function selectors to assign to the role.
  function setupSpokeConfiguratorRole(
    address accessManager,
    address spokeConfigurator,
    uint64 role,
    bytes4[] memory selectors
  ) internal {
    require(accessManager != address(0), 'invalid access manager');
    require(spokeConfigurator != address(0), 'invalid spoke configurator');
    IAccessManager(accessManager).setTargetFunctionRole(spokeConfigurator, selectors, role);
  }
}
