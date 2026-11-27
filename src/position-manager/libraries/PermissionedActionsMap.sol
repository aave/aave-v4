// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.20;

import {
  IPermissionedPositionManager,
  PermissionedActions
} from 'src/position-manager/interfaces/IPermissionedPositionManager.sol';

/// @title PermissionedActionsMap Library
/// @author Aave Labs
/// @notice Implements the bitmap logic to handle the PermissionedActions configuration.
/// @dev Each `IPermissionedPositionManager.Action` maps to the bit at its enum index.
library PermissionedActionsMap {
  /// @notice Sets the permissioned status of the given action.
  /// @param self The current PermissionedActions.
  /// @param action The action to update.
  /// @param permissioned True if the action is permissioned.
  /// @return The updated PermissionedActions.
  function setPermissioned(
    PermissionedActions self,
    IPermissionedPositionManager.Action action,
    bool permissioned
  ) internal pure returns (PermissionedActions) {
    uint8 actions = PermissionedActions.unwrap(self);
    uint8 mask = _mask(action);
    return PermissionedActions.wrap(permissioned ? actions | mask : actions & ~mask);
  }

  /// @notice Returns whether the given action is permissioned.
  /// @param self The current PermissionedActions.
  /// @param action The action to check.
  /// @return True if the action is permissioned.
  function isPermissioned(
    PermissionedActions self,
    IPermissionedPositionManager.Action action
  ) internal pure returns (bool) {
    return (PermissionedActions.unwrap(self) & _mask(action)) != 0;
  }

  /// @notice Returns the bit mask of the given action.
  function _mask(IPermissionedPositionManager.Action action) private pure returns (uint8) {
    return uint8(1) << uint8(action);
  }
}
