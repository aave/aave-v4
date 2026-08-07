// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

/// @title AaveV4SpokeConfiguratorRolesProcedure Library
/// @author Aave Labs
/// @notice Procedures for granting and setting up SpokeConfigurator roles on the AccessManager.
library AaveV4SpokeConfiguratorRolesProcedure {
  /// @notice Grants every SpokeConfigurator role (400-405) to `admin`.
  /// @param accessManager The address of the AccessManager contract.
  /// @param admin The address to receive the SpokeConfigurator roles.
  function grantSpokeConfiguratorAllRoles(address accessManager, address admin) internal {
    grantSpokeConfiguratorRole(accessManager, Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, admin);
    grantSpokeConfiguratorRole(accessManager, Roles.SPOKE_CONFIGURATOR_PAUSE_ROLE, admin);
    grantSpokeConfiguratorRole(accessManager, Roles.SPOKE_CONFIGURATOR_FREEZE_ROLE, admin);
    grantSpokeConfiguratorRole(accessManager, Roles.SPOKE_CONFIGURATOR_LISTING_ROLE, admin);
    grantSpokeConfiguratorRole(accessManager, Roles.SPOKE_CONFIGURATOR_EMERGENCY_ROLE, admin);
    grantSpokeConfiguratorRole(accessManager, Roles.SPOKE_CONFIGURATOR_RISK_MANAGEMENT_ROLE, admin);
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

  /// @notice Sets up every SpokeConfigurator role (400-405) with its target selectors.
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
      Roles.SPOKE_CONFIGURATOR_PAUSE_ROLE,
      Roles.getSpokeConfiguratorPauseRoleSelectors()
    );
    setupSpokeConfiguratorRole(
      accessManager,
      spokeConfigurator,
      Roles.SPOKE_CONFIGURATOR_FREEZE_ROLE,
      Roles.getSpokeConfiguratorFreezeRoleSelectors()
    );
    setupSpokeConfiguratorRole(
      accessManager,
      spokeConfigurator,
      Roles.SPOKE_CONFIGURATOR_LISTING_ROLE,
      Roles.getSpokeConfiguratorListingRoleSelectors()
    );
    setupSpokeConfiguratorRole(
      accessManager,
      spokeConfigurator,
      Roles.SPOKE_CONFIGURATOR_EMERGENCY_ROLE,
      Roles.getSpokeConfiguratorEmergencyRoleSelectors()
    );
    setupSpokeConfiguratorRole(
      accessManager,
      spokeConfigurator,
      Roles.SPOKE_CONFIGURATOR_RISK_MANAGEMENT_ROLE,
      Roles.getSpokeConfiguratorRiskManagementRoleSelectors()
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
