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
   * @param availableLiquidity The current available liquidity of the asset
   * @param baseDebt The current base debt of the asset
   * @param premiumDebt The current premium debt of the asset
   * @return variableBorrowRate The variable borrow rate expressed in ray
   */
  function calculateInterestRate(
    uint256 assetId,
    uint256 availableLiquidity,
    uint256 baseDebt,
    uint256 premiumDebt
  ) external view returns (uint256);
}
