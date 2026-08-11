// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title IMandatoryPositionManager
/// @author Aave Labs
/// @notice Interface for a mandatory position manager, which replaces the default position manager
/// authorization on position actions of a permissioned Spoke.
interface IMandatoryPositionManager {
  /// @notice Returns whether a position action on the Spoke is allowed.
  /// @dev It can preserve the default authorization by calling back `ISpoke.isPositionManager`.
  /// @param caller The transaction initiator on the Spoke.
  /// @param onBehalfOf The owner of the position being modified.
  /// @param data The full calldata of the Spoke call, allowing per-action decoding.
  /// @return True if the call is allowed.
  function isCallAllowed(
    address caller,
    address onBehalfOf,
    bytes calldata data
  ) external view returns (bool);
}
