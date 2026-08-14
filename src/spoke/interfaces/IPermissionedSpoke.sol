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
  /// @dev The gate replaces the default position manager authorization on position actions.
  /// @dev It reverts on the zero address; a gate is required from initialization onwards.
  /// @param gate The address of the gate.
  function updateGate(address gate) external;

  /// @notice Returns the address of the gate.
  function getGate() external view returns (address);
}
