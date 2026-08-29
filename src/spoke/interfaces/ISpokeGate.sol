// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title ISpokeGate
/// @author Aave Labs
/// @notice Interface for a gate, which can override the default authorization on position actions,
/// liquidations and user risk premium updates of a permissioned Spoke.
interface ISpokeGate {
  enum CallPolicy {
    USE_DEFAULT,
    ALLOW,
    DENY
  }

  /// @notice Returns the policy to apply to a call on the Spoke.
  /// @dev `USE_DEFAULT` delegates the final decision to the Spoke's default authorization.
  /// @dev Denying `updateUserRiskPremium` or `updateUserDynamicConfig` leaves them callable by admins.
  /// @param caller The transaction initiator on the Spoke.
  /// @param onBehalfOf The owner of the position being modified.
  /// @param data The full calldata of the Spoke call, allowing per-action decoding.
  /// @return The policy to apply to the call.
  function getCallPolicy(
    address caller,
    address onBehalfOf,
    bytes calldata data
  ) external view returns (CallPolicy);
}
