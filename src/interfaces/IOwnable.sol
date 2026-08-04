// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title IOwnable
/// @author Aave Labs
/// @notice Interface for contracts exposing Ownable access control.
interface IOwnable {
  /// @notice Returns the address of the current owner.
  function owner() external view returns (address);
}
