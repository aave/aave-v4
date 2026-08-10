// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title ISpokeGate
/// @author Aave Labs
/// @notice Interface for a Spoke gate, adding access control validation to position actions.
interface ISpokeGate {
  /// @notice Returns whether an action on the Spoke is allowed.
  /// @dev For the `setUsingAsCollateral` action, `amount` is 1 when enabling and 0 when disabling.
  /// @param selector The selector of the Spoke function being called.
  /// @param caller The transaction initiator on the Spoke.
  /// @param onBehalfOf The owner of the position being modified.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount of the action, expressed in asset units.
  /// @return True if the action is allowed.
  function isActionAllowed(
    bytes4 selector,
    address caller,
    address onBehalfOf,
    uint256 reserveId,
    uint256 amount
  ) external view returns (bool);
}
