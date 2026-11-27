// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {PermissionedPositionManager} from 'src/position-manager/PermissionedPositionManager.sol';

/// @title ExtendedPermissionedPositionManager
/// @author Aave Labs
/// @notice Permissioned position manager which also accepts calls relayed by other position managers on behalf of users.
/// @dev A relaying position manager must be active and approved by the user on the Spoke, and this contract must not be
/// set as exclusive on the Spoke.
/// @dev Permissioned actions are checked against the position owner.
contract ExtendedPermissionedPositionManager is PermissionedPositionManager {
  /// @dev Constructor.
  /// @param spoke_ The address of the Spoke.
  constructor(address spoke_) PermissionedPositionManager(spoke_) {}

  function _validateCaller(address onBehalfOf, Action action) internal view override {
    if (msg.sender != onBehalfOf) {
      require(
        !ISpoke(SPOKE).isPositionManagerExclusive(address(this)) &&
          ISpoke(SPOKE).isPositionManagerApproved(onBehalfOf, msg.sender),
        Unauthorized()
      );
    }
    _validatePermission(onBehalfOf, action);
  }
}
