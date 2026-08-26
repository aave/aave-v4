// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title ISpokeGate
/// @author Aave Labs
/// @notice Interface for a gate, which replaces the default authorization on position actions,
/// liquidations and user risk premium updates of a permissioned Spoke.
interface ISpokeGate {
  /// @notice Returns whether a call on the Spoke is allowed.
  /// @dev Called by the Spoke, so it can preserve the default authorization by calling back
  /// `ISpoke(msg.sender).isPositionManager` and allowing `liquidationCall` for anyone.
  /// @dev Denying `updateUserRiskPremium` or `updateUserDynamicConfig` leaves them callable by admins.
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
