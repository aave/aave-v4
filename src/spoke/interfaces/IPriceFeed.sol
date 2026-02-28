// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

/// @title IPriceFeed
/// @author Aave Labs
/// @notice Defines the minimal functions needed to work with the AaveOracle contract.
interface IPriceFeed {
  /// @notice Returns the number of decimals used to represent the price.
  /// @return The number of decimals.
  function decimals() external view returns (uint8);

  /// @notice Returns the latest price answer.
  /// @return The latest price.
  function latestAnswer() external view returns (int256);
}
