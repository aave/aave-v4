// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

/// @title AaveV4HubConfiguratorRolesProcedure Library
/// @author Aave Labs
/// @notice Procedures for granting and setting up HubConfigurator roles on the AccessManager.
library AaveV4HubConfiguratorRolesProcedure {
  /// @notice Grants every HubConfigurator role (200-205) to `admin`.
  /// @param accessManager The address of the AccessManager contract.
  /// @param admin The address to receive the HubConfigurator roles.
  function grantHubConfiguratorAllRoles(address accessManager, address admin) internal {
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, admin);
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_SPOKE_ACTIVE_ROLE, admin);
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_SPOKE_HALTED_ROLE, admin);
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_LISTING_ROLE, admin);
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_EMERGENCY_ROLE, admin);
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_RISK_MANAGEMENT_ROLE, admin);
  }

  /// @notice Grants a specific HubConfigurator role to the given address.
  /// @param accessManager The address of the AccessManager contract.
  /// @param role The role identifier to grant.
  /// @param admin The address to receive the role.
  function grantHubConfiguratorRole(address accessManager, uint64 role, address admin) internal {
    require(accessManager != address(0), 'invalid access manager');
    require(admin != address(0), 'invalid admin');
    IAccessManager(accessManager).grantRole({roleId: role, account: admin, executionDelay: 0});
  }

  /// @notice Sets up every HubConfigurator role (200-205) with its target selectors.
  /// @param accessManager The address of the AccessManager contract.
  /// @param hubConfigurator The address of the HubConfigurator contract.
  function setupHubConfiguratorAllRoles(address accessManager, address hubConfigurator) internal {
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      Roles.getHubConfiguratorDomainAdminRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_SPOKE_ACTIVE_ROLE,
      Roles.getHubConfiguratorSpokeActiveRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_SPOKE_HALTED_ROLE,
      Roles.getHubConfiguratorSpokeHaltedRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_LISTING_ROLE,
      Roles.getHubConfiguratorListingRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_EMERGENCY_ROLE,
      Roles.getHubConfiguratorEmergencyRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_RISK_MANAGEMENT_ROLE,
      Roles.getHubConfiguratorRiskManagementRoleSelectors()
    );
  }

  /// @notice Sets up a specific HubConfigurator role by assigning function selectors to the target.
  /// @param accessManager The address of the AccessManager contract.
  /// @param hubConfigurator The address of the HubConfigurator contract.
  /// @param role The role identifier to associate with the selectors.
  /// @param selectors The function selectors to assign to the role.
  function setupHubConfiguratorRole(
    address accessManager,
    address hubConfigurator,
    uint64 role,
    bytes4[] memory selectors
  ) internal {
    require(accessManager != address(0), 'invalid access manager');
    require(hubConfigurator != address(0), 'invalid hub configurator');
    IAccessManager(accessManager).setTargetFunctionRole(hubConfigurator, selectors, role);
  }
}
