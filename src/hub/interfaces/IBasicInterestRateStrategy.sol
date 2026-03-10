// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

/// @title IBasicInterestRateStrategy
/// @author Aave Labs
/// @notice Basic interface for any interest rate strategy.
interface IBasicInterestRateStrategy {
  /// @notice Thrown when the drawn rate data is not set for the asset.
  /// @param assetId The identifier of the asset with no drawn rate data set.
  error DrawnRateDataNotSet(uint256 assetId);

  /// @notice Sets the drawn rate parameters for a specified asset.
  /// @param assetId The identifier of the asset.
  /// @param data The encoded parameters used to configure the drawn rate of the asset.
  function setDrawnRateData(uint256 assetId, bytes calldata data) external;

  /// @notice Calculates the drawn rate depending on the asset's state and configurations.
  /// @param assetId The identifier of the asset.
  /// @param liquidity The current available liquidity of the asset.
  /// @param drawn The current drawn amount of the asset.
  /// @param deficit The current deficit of the asset.
  /// @param swept The current swept (reinvested) amount of the asset.
  /// @return The drawn rate, expressed in RAY.
  function calculateDrawnRate(
    uint256 assetId,
    uint256 liquidity,
    uint256 drawn,
    uint256 deficit,
    uint256 swept
  ) external view returns (uint256);
}
