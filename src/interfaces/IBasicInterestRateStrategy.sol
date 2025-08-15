// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

/**
 * @title IBasicInterestRateStrategy
 * @author Aave Labs
 * @notice Basic interface for any rate strategy used by the Aave protocol
 */
interface IBasicInterestRateStrategy {
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
