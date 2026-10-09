// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {Spoke} from 'src/spoke/Spoke.sol';
import {ISpokeGate} from 'src/spoke/interfaces/ISpokeGate.sol';

/// @title PermissionedSpoke
/// @author Aave Labs
/// @notice Spoke where a gate replaces the default position manager authorization on position
/// actions.
abstract contract PermissionedSpoke is Spoke {
  /// @notice The gate deciding whether position actions are allowed.
  address public immutable GATE;

  /// @dev Constructor.
  /// @param gate_ The address of the gate.
  constructor(address gate_) {
    require(gate_ != address(0), InvalidAddress());
    GATE = gate_;
  }

  /// @dev The gate fully decides whether the current call is allowed. The external
  /// `isPositionManager` function preserves the underlying position manager semantics.
  function _isPositionManager(
    address user,
    address manager
  ) internal view virtual override returns (bool) {
    return
      ISpokeGate(GATE).isCallAllowed({
        caller: manager,
        onBehalfOf: user,
        data: msg.data
      });
  }

  /// @dev Returns the underlying position manager relationship without consulting the gate.
  function isPositionManager(
    address user,
    address positionManager
  ) external view virtual override returns (bool) {
    return Spoke._isPositionManager(user, positionManager);
  }
}
