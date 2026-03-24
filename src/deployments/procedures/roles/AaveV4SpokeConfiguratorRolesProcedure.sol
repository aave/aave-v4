// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {RolesValidation} from 'src/deployments/utils/libraries/RolesValidation.sol';

library AaveV4SpokeConfiguratorRolesProcedure {
  /// @notice Grants the SpokeConfigurator domain admin role (400) to `admin`.
  function grantSpokeConfiguratorAllRoles(address accessManager, address admin) internal {
    grantSpokeConfiguratorRole(accessManager, Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, admin);
  }

  function grantSpokeConfiguratorRole(address accessManager, uint64 role, address admin) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(admin);
    IAccessManager(accessManager).grantRole({roleId: role, account: admin, executionDelay: 0});
  }

  /// @notice Sets up the SpokeConfigurator domain admin role with all target selectors.
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
  }

  function setupSpokeConfiguratorRole(
    address accessManager,
    address spokeConfigurator,
    uint64 role,
    bytes4[] memory selectors
  ) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(spokeConfigurator);
    IAccessManager(accessManager).setTargetFunctionRole(spokeConfigurator, selectors, role);
  }
}
