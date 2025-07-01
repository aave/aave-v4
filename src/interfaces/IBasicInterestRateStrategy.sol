// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

/**
 * @title IBasicInterestRateStrategy
 * @author Aave Labs
 * @notice Basic interface for any rate strategy used by the Aave protocol
 */
interface IBasicInterestRateStrategy {
  /**
   * @notice Calculates the interest rate depending on the asset's state and configurations
   * @param assetId The id of the asset
   * @param availableLiquidity The available liquidity of the asset
   * @param totalDebt The total debt of the asset
   * @param liquidityAdded The amount of liquidity added to the asset
   * @param liquidityTaken The amount of liquidity taken from the asset
   * @return variableBorrowRate The variable borrow rate expressed in ray
   */
  function calculateInterestRate(
    uint256 assetId,
    uint256 availableLiquidity,
    uint256 totalDebt,
    uint256 liquidityAdded,
    uint256 liquidityTaken
  ) external view returns (uint256);
}
