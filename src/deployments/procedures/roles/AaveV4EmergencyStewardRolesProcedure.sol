// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

/// @title AaveV4EmergencyStewardRolesProcedure Library
/// @author Aave Labs
/// @notice Procedures for granting and setting up EmergencySteward roles on the AccessManager.
library AaveV4EmergencyStewardRolesProcedure {
  /// @notice Grants the EmergencySteward domain admin role (500) to `admin`.
  /// @param accessManager The address of the AccessManager contract.
  /// @param admin The address to receive the EmergencySteward domain admin role.
  function grantEmergencyStewardAllRoles(address accessManager, address admin) internal {
    grantEmergencyStewardRole(accessManager, Roles.EMERGENCY_STEWARD_DOMAIN_ADMIN_ROLE, admin);
  }

  /// @notice Grants a specific EmergencySteward role to the given address.
  /// @param accessManager The address of the AccessManager contract.
  /// @param role The role identifier to grant.
  /// @param admin The address to receive the role.
  function grantEmergencyStewardRole(address accessManager, uint64 role, address admin) internal {
    require(accessManager != address(0), 'invalid access manager');
    require(admin != address(0), 'invalid admin');
    IAccessManager(accessManager).grantRole({roleId: role, account: admin, executionDelay: 0});
  }

  /// @notice Sets up the EmergencySteward domain admin role with all target selectors.
  /// @param accessManager The address of the AccessManager contract.
  /// @param emergencySteward The address of the EmergencySteward contract.
  function setupEmergencyStewardAllRoles(address accessManager, address emergencySteward) internal {
    setupEmergencyStewardRole(
      accessManager,
      emergencySteward,
      Roles.EMERGENCY_STEWARD_DOMAIN_ADMIN_ROLE,
      Roles.getEmergencyStewardDomainAdminRoleSelectors()
    );
  }

  /// @notice Sets up a specific EmergencySteward role by assigning function selectors to the target.
  /// @param accessManager The address of the AccessManager contract.
  /// @param emergencySteward The address of the EmergencySteward contract.
  /// @param role The role identifier to associate with the selectors.
  /// @param selectors The function selectors to assign to the role.
  function setupEmergencyStewardRole(
    address accessManager,
    address emergencySteward,
    uint64 role,
    bytes4[] memory selectors
  ) internal {
    require(accessManager != address(0), 'invalid access manager');
    require(emergencySteward != address(0), 'invalid emergency steward');
    IAccessManager(accessManager).setTargetFunctionRole(emergencySteward, selectors, role);
  }
}
