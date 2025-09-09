// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.10;

/**
 * @title IBasicInterestRateStrategy
 * @author Aave Labs
 * @notice Basic interface for any rate strategy used by the Aave protocol
 */
interface IBasicInterestRateStrategy {
  /**
   * @notice Thrown when the interest rate data is not set for the asset.
   * @param assetId The id of the asset with no interest rate data set.
   */
  error InterestRateDataNotSet(uint256 assetId);

  /**
   * @notice Sets interest rate data for an Aave rate strategy.
   * @param assetId The id of the asset to update.
   * @param data The interest rate data to apply to the given asset, all in bps, encoded in bytes.
   */
  function setInterestRateData(uint256 assetId, bytes calldata data) external;

  /**
   * @notice Calculates the interest rate depending on the asset's state and configurations.
   * @param assetId The id of the asset.
   * @param liquidity The current available liquidity of the asset.
   * @param drawn The current drawn amount of the asset.
   * @param premium The current premium amount of the asset.
   * @param deficit The current deficit of the asset.
   * @param swept The current swept (reinvested) amount of the asset.
   * @return interestRate The interest rate expressed in ray.
   */
  function calculateInterestRate(
    uint256 assetId,
    uint256 liquidity,
    uint256 drawn,
    uint256 premium,
    uint256 deficit,
    uint256 swept
  ) external view returns (uint256 interestRate);
}
