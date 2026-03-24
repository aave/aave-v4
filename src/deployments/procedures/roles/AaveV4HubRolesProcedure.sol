// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {RolesValidation} from 'src/deployments/utils/libraries/RolesValidation.sol';

library AaveV4HubRolesProcedure {
  /// @notice Grants all Hub granular roles to `admin`:
  ///   - HUB_CONFIGURATOR_ROLE
  ///   - HUB_FEE_MINTER_ROLE
  ///   - HUB_DEFICIT_ELIMINATOR_ROLE
  function grantHubAllRoles(address accessManager, address admin) internal {
    grantHubRole(accessManager, Roles.HUB_CONFIGURATOR_ROLE, admin);
    grantHubRole(accessManager, Roles.HUB_FEE_MINTER_ROLE, admin);
    grantHubRole(accessManager, Roles.HUB_DEFICIT_ELIMINATOR_ROLE, admin);
  }

  function grantHubRole(address accessManager, uint64 role, address admin) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(admin);
    IAccessManager(accessManager).grantRole({roleId: role, account: admin, executionDelay: 0});
  }

  function setupHubAllRoles(address accessManager, address hub) internal {
    setupHubRole(
      accessManager,
      hub,
      Roles.HUB_CONFIGURATOR_ROLE,
      Roles.getHubConfiguratorRoleSelectors()
    );
    setupHubRole(
      accessManager,
      hub,
      Roles.HUB_FEE_MINTER_ROLE,
      Roles.getHubFeeMinterRoleSelectors()
    );
    setupHubRole(
      accessManager,
      hub,
      Roles.HUB_DEFICIT_ELIMINATOR_ROLE,
      Roles.getHubDeficitEliminatorRoleSelectors()
    );
  }

  function setupHubRole(
    address accessManager,
    address hub,
    uint64 roleId,
    bytes4[] memory selectors
  ) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(hub);
    IAccessManager(accessManager).setTargetFunctionRole({
      target: hub,
      selectors: selectors,
      roleId: roleId
    });
  }
}
