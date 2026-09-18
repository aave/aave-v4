// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

/// @title AaveV4AccessManagerRolesProcedure Library
/// @author Aave Labs
/// @notice Procedures for labelling protocol roles and managing the default admin role on the AccessManager.
library AaveV4AccessManagerRolesProcedure {
  /// @notice Labels all protocol roles on the AccessManager.
  /// @param accessManager The address of the AccessManager contract.
  function labelAllRoles(address accessManager) internal {
    require(accessManager != address(0), 'invalid access manager');
    IAccessManager am = IAccessManager(accessManager);

    // Hub roles
    am.labelRole(Roles.HUB_DOMAIN_ADMIN_ROLE, 'HUB_DOMAIN_ADMIN_ROLE');
    am.labelRole(Roles.HUB_CONFIGURATOR_ROLE, 'HUB_CONFIGURATOR_ROLE');
    am.labelRole(Roles.HUB_FEE_MINTER_ROLE, 'HUB_FEE_MINTER_ROLE');
    am.labelRole(Roles.HUB_DEFICIT_ELIMINATOR_ROLE, 'HUB_DEFICIT_ELIMINATOR_ROLE');

    // HubConfigurator roles
    am.labelRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, 'HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE');

    // Spoke roles
    am.labelRole(Roles.SPOKE_DOMAIN_ADMIN_ROLE, 'SPOKE_DOMAIN_ADMIN_ROLE');
    am.labelRole(Roles.SPOKE_CONFIGURATOR_ROLE, 'SPOKE_CONFIGURATOR_ROLE');
    am.labelRole(Roles.SPOKE_USER_POSITION_UPDATER_ROLE, 'SPOKE_USER_POSITION_UPDATER_ROLE');

    // SpokeConfigurator roles
    am.labelRole(
      Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      'SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE'
    );
  }

  /// @notice Replaces the default admin by granting the role to a new address and revoking it from the old one.
  /// The adminToRemove must be the current default admin, otherwise the procedure will revert.
  /// @param accessManager The address of the AccessManager contract.
  /// @param adminToAdd The address to grant the default admin role to.
  /// @param adminToRemove The address to revoke the default admin role from.
  function replaceDefaultAdminRole(
    address accessManager,
    address adminToAdd,
    address adminToRemove
  ) internal {
    grantAccessManagerAdminRole(accessManager, adminToAdd);
    revokeAccessManagerAdminRole(accessManager, adminToRemove);
  }

  /// @notice Grants the AccessManager admin role to the given address.
  /// @param accessManager The address of the AccessManager contract.
  /// @param adminToAdd The address to grant the admin role to.
  function grantAccessManagerAdminRole(address accessManager, address adminToAdd) internal {
    require(accessManager != address(0), 'invalid access manager');
    require(adminToAdd != address(0), 'invalid admin');
    IAccessManager(accessManager).grantRole({
      roleId: Roles.ACCESS_MANAGER_ADMIN_ROLE,
      account: adminToAdd,
      executionDelay: 0
    });
  }

  /// @notice Revokes the AccessManager admin role from the given address.
  /// @param accessManager The address of the AccessManager contract.
  /// @param adminToRemove The address to revoke the admin role from.
  function revokeAccessManagerAdminRole(address accessManager, address adminToRemove) internal {
    require(accessManager != address(0), 'invalid access manager');
    require(adminToRemove != address(0), 'invalid admin');
    IAccessManager(accessManager).revokeRole({
      roleId: Roles.ACCESS_MANAGER_ADMIN_ROLE,
      account: adminToRemove
    });
  }
}
