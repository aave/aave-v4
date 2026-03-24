// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {RolesValidation} from 'src/deployments/utils/libraries/RolesValidation.sol';

library AaveV4HubConfiguratorRolesProcedure {
  /// @notice Grants the HubConfigurator domain admin role (200) to `admin`.
  function grantHubConfiguratorAllRoles(address accessManager, address admin) internal {
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, admin);
  }

  function grantHubConfiguratorRole(address accessManager, uint64 role, address admin) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(admin);
    IAccessManager(accessManager).grantRole({roleId: role, account: admin, executionDelay: 0});
  }

  /// @notice Sets up the HubConfigurator domain admin role with all target selectors.
  function setupHubConfiguratorAllRoles(address accessManager, address hubConfigurator) internal {
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      Roles.getHubConfiguratorDomainAdminRoleSelectors()
    );
  }

  function setupHubConfiguratorRole(
    address accessManager,
    address hubConfigurator,
    uint64 role,
    bytes4[] memory selectors
  ) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(hubConfigurator);
    IAccessManager(accessManager).setTargetFunctionRole(hubConfigurator, selectors, role);
  }
}
