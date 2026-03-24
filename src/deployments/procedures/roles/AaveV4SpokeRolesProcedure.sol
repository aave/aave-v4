// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {RolesValidation} from 'src/deployments/utils/libraries/RolesValidation.sol';

library AaveV4SpokeRolesProcedure {
  /// @notice Grants all Spoke granular roles to `admin`:
  ///   - SPOKE_USER_POSITION_UPDATER_ROLE
  ///   - SPOKE_CONFIGURATOR_ROLE
  function grantSpokeAllRoles(address accessManager, address admin) internal {
    grantSpokeRole(accessManager, Roles.SPOKE_USER_POSITION_UPDATER_ROLE, admin);
    grantSpokeRole(accessManager, Roles.SPOKE_CONFIGURATOR_ROLE, admin);
  }

  function grantSpokeRole(address accessManager, uint64 role, address admin) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(admin);
    IAccessManager(accessManager).grantRole({roleId: role, account: admin, executionDelay: 0});
  }

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

  function setupSpokeRole(
    address accessManager,
    address spoke,
    uint64 roleId,
    bytes4[] memory selectors
  ) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(spoke);
    IAccessManager(accessManager).setTargetFunctionRole({
      target: spoke,
      selectors: selectors,
      roleId: roleId
    });
  }
}
