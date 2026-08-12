// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title IPermissionedSpoke
/// @author Aave Labs
/// @notice Interface for the permissioned functionality of a Spoke.
interface IPermissionedSpoke {
  /// @notice Emitted when the gate is updated.
  /// @param gate The address of the gate, or the zero address if removed.
  event UpdateGate(address indexed gate);

  /// @notice Updates the gate.
  /// @dev When set, it replaces the default position manager authorization on position actions.
  /// @dev Setting the zero address removes it, restoring the default authorization.
  /// @param gate The address of the gate.
  function updateGate(address gate) external;

  /// @notice Returns the address of the gate, or the zero address if unset.
  function getGate() external view returns (address);
}
