// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

/// @title AaveV4SpokeConfiguratorRolesProcedure Library
/// @author Aave Labs
/// @notice Procedures for granting and setting up SpokeConfigurator roles on the AccessManager.
library AaveV4SpokeConfiguratorRolesProcedure {
  /// @notice Grants the SpokeConfigurator domain admin role (400) and EmergencySteward role (401) to `admin`.
  /// @param accessManager The address of the AccessManager contract.
  /// @param admin The address to receive the SpokeConfigurator roles.
  function grantSpokeConfiguratorAllRoles(address accessManager, address admin) internal {
    grantSpokeConfiguratorRole(accessManager, Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, admin);
    grantSpokeConfiguratorRole(
      accessManager,
      Roles.SPOKE_CONFIGURATOR_EMERGENCY_STEWARD_ROLE,
      admin
    );
  }

  /// @notice Grants the SpokeConfigurator EmergencySteward role (401) to the EmergencySteward contract.
  /// @param accessManager The address of the AccessManager contract.
  /// @param emergencySteward The address of the EmergencySteward contract.
  function grantSpokeConfiguratorEmergencyStewardRole(
    address accessManager,
    address emergencySteward
  ) internal {
    grantSpokeConfiguratorRole(
      accessManager,
      Roles.SPOKE_CONFIGURATOR_EMERGENCY_STEWARD_ROLE,
      emergencySteward
    );
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

  /// @notice Sets up the SpokeConfigurator domain admin and EmergencySteward roles with their target selectors.
  /// @param accessManager The address of the AccessManager contract.
  /// @param spokeConfigurator The address of the SpokeConfigurator contract.
  function setupSpokeConfiguratorAllRoles(
    address accessManager,
    address spokeConfigurator
  ) internal {
    setupSpokeConfiguratorRole(
      accessManager,
      spokeConfigurator,
      Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      Roles.getSpokeConfiguratorDomainAdminRoleSelectors()
    );
    setupSpokeConfiguratorRole(
      accessManager,
      spokeConfigurator,
      Roles.SPOKE_CONFIGURATOR_EMERGENCY_STEWARD_ROLE,
      Roles.getSpokeConfiguratorEmergencyStewardRoleSelectors()
    );
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
