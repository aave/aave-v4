// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

/// @title IRescuable
/// @author Aave Labs
/// @notice Interface for Rescuable.
interface IRescuable {
  /// @notice Thrown when caller is not the rescue guardian.
  error OnlyRescueGuardian();

  /// @notice Recovers ERC20 tokens sent to this contract.
  /// @param token The address of the ERC20 token to rescue.
  /// @param to The address to send the rescued tokens to.
  /// @param amount Amount of tokens to rescue.
  function rescueToken(address token, address to, uint256 amount) external;

  /// @notice Recovers native assets remaining in this contract.
  /// @param to The address to send rescued native assets to.
  /// @param amount Amount of native assets to rescue.
  function rescueNative(address to, uint256 amount) external;

  /// @notice Returns the rescue guardian address.
  /// @return The address allowed to rescue funds.
  function rescueGuardian() external view returns (address);
}
