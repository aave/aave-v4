// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title ISpokeGate
/// @author Aave Labs
/// @notice Interface for the immutable policy contract authorizing position actions on a Spoke.
interface ISpokeGate {
  /// @notice Returns whether a position action on the Spoke is allowed.
  /// @dev Called by the Spoke. Implementations can be stateful and shared by multiple Spokes;
  /// `msg.sender` identifies the calling Spoke.
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
