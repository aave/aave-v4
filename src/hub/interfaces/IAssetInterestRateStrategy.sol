// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IBasicInterestRateStrategy} from 'src/hub/interfaces/IBasicInterestRateStrategy.sol';

/// @title IAssetInterestRateStrategy
/// @author Aave Labs
/// @notice Interface of the optimal-usage-based asset interest rate strategy.
interface IAssetInterestRateStrategy is IBasicInterestRateStrategy {
  /// @notice Holds the interest rate data for a given asset.
  /// @dev optimalUsageRatio The optimal usage ratio, in BPS. Maximum and minimum values are defined by `MAX_OPTIMAL_RATIO` and `MIN_OPTIMAL_RATIO`.
  /// @dev baseBorrowRate The base borrow rate, in BPS.
  /// @dev rateGrowthBeforeOptimal The rate growth before the optimal usage ratio, in BPS.
  /// @dev rateGrowthAfterOptimal The rate growth after the optimal usage ratio, in BPS.
  struct InterestRateData {
    uint16 optimalUsageRatio;
    uint32 baseBorrowRate;
    uint32 rateGrowthBeforeOptimal;
    uint32 rateGrowthAfterOptimal;
  }

  /// @notice Emitted when interest rate data is updated for an asset.
  /// @param hub The address of the associated Hub.
  /// @param assetId The identifier of the asset whose interest rate data is updated.
  /// @param optimalUsageRatio The optimal usage ratio, in BPS.
  /// @param baseBorrowRate The base borrow rate, in BPS.
  /// @param rateGrowthBeforeOptimal The rate growth before the optimal usage ratio, in BPS.
  /// @param rateGrowthAfterOptimal The rate growth after the optimal usage ratio, in BPS.
  event UpdateInterestRateData(
    address indexed hub,
    uint256 indexed assetId,
    uint256 optimalUsageRatio,
    uint256 baseBorrowRate,
    uint256 rateGrowthBeforeOptimal,
    uint256 rateGrowthAfterOptimal
  );

  /// @notice Thrown when the given address is invalid.
  error InvalidAddress();

  /// @notice Thrown when the caller is not the Hub.
  error OnlyHub();

  /// @notice Thrown when the max possible rate is greater than `MAX_ALLOWED_BORROW_RATE`.
  error InvalidMaxBorrowRate();

  /// @notice Thrown when growth after optimal is less than growth before optimal.
  error GrowthAfterOptimalMustBeGteGrowthBeforeOptimal();

  /// @notice Thrown when the optimal usage ratio is less than `MIN_OPTIMAL_RATIO` or greater than `MAX_OPTIMAL_RATIO`.
  error InvalidOptimalUsageRatio();

  /// @notice Returns the full InterestRateData struct for the given asset.
  /// @param assetId The identifier of the asset for which to get the data.
  /// @return The InterestRateData struct for the given asset, all in BPS.
  function getInterestRateData(uint256 assetId) external view returns (InterestRateData memory);

  /// @notice Returns the optimal usage rate for the given asset.
  /// @param assetId The identifier of the asset for which to get the optimal usage ratio.
  /// @return The optimal usage ratio, in BPS.
  function getOptimalUsageRatio(uint256 assetId) external view returns (uint256);

  /// @notice Returns the base borrow rate.
  /// @param assetId The identifier of the asset for which to get the base borrow rate.
  /// @return The base borrow rate, in BPS.
  function getBaseBorrowRate(uint256 assetId) external view returns (uint256);

  /// @notice Returns the rate growth before the optimal usage ratio.
  /// @dev Applicable when usage ratio > 0 and <= OPTIMAL_USAGE_RATIO.
  /// @param assetId The identifier of the asset for which to get the rate growth before the optimal usage ratio.
  /// @return The rate growth, in BPS.
  function getRateGrowthBeforeOptimal(uint256 assetId) external view returns (uint256);

  /// @notice Returns the rate growth after the optimal usage ratio.
  /// @dev Applicable when usage ratio > OPTIMAL_USAGE_RATIO.
  /// @param assetId The identifier of the asset for which to get the rate growth after the optimal usage ratio.
  /// @return The rate growth, in BPS.
  function getRateGrowthAfterOptimal(uint256 assetId) external view returns (uint256);

  /// @notice Returns the maximum borrow rate.
  /// @param assetId The identifier of the asset for which to get the maximum borrow rate.
  /// @return The maximum borrow rate, in BPS.
  function getMaxBorrowRate(uint256 assetId) external view returns (uint256);

  /// @notice Returns the maximum allowed value for a borrow rate.
  /// @return The maximum borrow rate, in BPS.
  function MAX_ALLOWED_BORROW_RATE() external view returns (uint256);

  /// @notice Returns the minimum optimal usage ratio.
  /// @return The minimum optimal usage ratio, in BPS.
  function MIN_OPTIMAL_RATIO() external view returns (uint256);

  /// @notice Returns the maximum optimal usage ratio.
  /// @return The maximum optimal usage ratio, in BPS.
  function MAX_OPTIMAL_RATIO() external view returns (uint256);

  /// @notice Returns the associated address of the Hub.
  /// @return The address of the Hub.
  function HUB() external view returns (address);
}
