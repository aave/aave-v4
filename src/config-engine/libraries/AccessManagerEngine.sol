// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {EngineFlags} from 'src/config-engine/libraries/EngineFlags.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';

/// @title AccessManagerEngine
/// @author Aave Labs
/// @notice Library containing access manager logic for AaveV4ConfigEngine.
library AccessManagerEngine {
  /// @notice Grants or revokes roles via AccessManager.
  /// @param memberships The role memberships to execute.
  function executeRoleMemberships(
    IAaveV4ConfigEngine.RoleMembership[] calldata memberships
  ) external {
    uint256 length = memberships.length;
    for (uint256 i; i < length; ++i) {
      if (memberships[i].granted) {
        IAccessManager(memberships[i].authority).grantRole(
          memberships[i].roleId,
          memberships[i].account,
          memberships[i].executionDelay
        );
      } else {
        IAccessManager(memberships[i].authority).revokeRole(
          memberships[i].roleId,
          memberships[i].account
        );
      }
    }
  }

  /// @notice Updates role configuration (admin, guardian, grant delay, label) via AccessManager.
  /// @param updates The role updates to execute.
  function executeRoleUpdates(IAaveV4ConfigEngine.RoleUpdate[] calldata updates) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      IAccessManager authority = IAccessManager(updates[i].authority);
      if (updates[i].admin != EngineFlags.KEEP_CURRENT_UINT64) {
        authority.setRoleAdmin(updates[i].roleId, updates[i].admin);
      }
      if (updates[i].guardian != EngineFlags.KEEP_CURRENT_UINT64) {
        authority.setRoleGuardian(updates[i].roleId, updates[i].guardian);
      }
      if (updates[i].grantDelay != EngineFlags.KEEP_CURRENT_UINT32) {
        authority.setGrantDelay(updates[i].roleId, updates[i].grantDelay);
      }
      if (bytes(updates[i].label).length > 0) {
        authority.labelRole(updates[i].roleId, updates[i].label);
      }
    }
  }

  /// @notice Updates target function roles via AccessManager.
  /// @param updates The target function role updates to execute.
  function executeTargetFunctionRoleUpdates(
    IAaveV4ConfigEngine.TargetFunctionRoleUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      IAccessManager(updates[i].authority).setTargetFunctionRole(
        updates[i].target,
        updates[i].selectors,
        updates[i].roleId
      );
    }
  }

  /// @notice Updates target admin delays via AccessManager.
  /// @param updates The target admin delay updates to execute.
  function executeTargetAdminDelayUpdates(
    IAaveV4ConfigEngine.TargetAdminDelayUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      IAccessManager(updates[i].authority).setTargetAdminDelay(
        updates[i].target,
        updates[i].newDelay
      );
    }
  }
}
