// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

/**
 * @title IBasicInterestRateStrategy
 * @author Aave Labs
 * @notice Basic interface for any rate strategy used by the Aave protocol
 */
interface IBasicInterestRateStrategy {
  struct CalculateInterestRateParams {
    /// @dev The id of the asset
    uint256 assetId;
    /// @dev The available liquidity of the asset
    uint256 availableLiquidity;
    /// @dev The amount of liquidity added to the asset
    uint256 liquidityAdded;
    /// @dev The amount of liquidity taken from the asset
    uint256 liquidityTaken;
    /// @dev The base debt of the asset
    uint256 baseDebt;
    /// @dev The amount of base added to the asset
    uint256 baseDebtAdded;
    /// @dev The amount of base taken from the asset
    uint256 baseDebtTaken;
    /// @dev The premium debt of the asset
    uint256 premiumDebt;
    /// @dev The amount of premium added to the asset
    uint256 premiumDebtAdded;
    /// @dev The amount of premium taken from the asset
    uint256 premiumDebtTaken;
  }

  /**
   * @notice Calculates the interest rate depending on the asset's state and configurations
   * @param params The parameters for the interest rate calculation
   * @return interestRate The interest rate expressed in ray
   */
  function calculateInterestRate(
    CalculateInterestRateParams calldata params
  ) external view returns (uint256);
}
