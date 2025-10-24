// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IBasicInterestRateStrategy} from 'src/hub/interfaces/IBasicInterestRateStrategy.sol';

/// @title IAssetInterestRateStrategy
/// @author Aave Labs
/// @notice Interface of the kink-based asset interest rate strategy.
interface IAssetInterestRateStrategy is IBasicInterestRateStrategy {
  /// @notice Holds the interest rate data for a given asset.
  /// @dev optimalUsageRatio The optimal usage ratio, in BPS. Maximum and minimum values are defined by `MAX_OPTIMAL_RATIO` and `MIN_OPTIMAL_RATIO`.
  /// @dev baseVariableBorrowRate The base variable borrow rate, in BPS.
  /// @dev variableRateSlope1 The slope of the variable interest curve, before hitting the optimal usage ratio, in BPS.
  /// @dev variableRateSlope2 The slope of the variable interest curve, after hitting the optimal usage ratio, in BPS.
  struct InterestRateData {
    uint16 optimalUsageRatio;
    uint32 baseVariableBorrowRate;
    uint32 variableRateSlope1;
    uint32 variableRateSlope2;
  }

  /// @notice Emitted when new interest rate data is set for an asset.
  /// @param hub The address of the associated Hub.
  /// @param assetId Identifier of the asset that has new interest rate data set.
  /// @param optimalUsageRatio The optimal usage ratio, in BPS.
  /// @param baseVariableBorrowRate The base variable borrow rate, in BPS.
  /// @param variableRateSlope1 The slope of the variable interest curve, before hitting the optimal usage ratio, in BPS.
  /// @param variableRateSlope2 The slope of the variable interest curve, after hitting the optimal usage ratio, in BPS.
  event UpdateRateData(
    address indexed hub,
    uint256 indexed assetId,
    uint256 optimalUsageRatio,
    uint256 baseVariableBorrowRate,
    uint256 variableRateSlope1,
    uint256 variableRateSlope2
  );

  /// @notice Thrown when the given address is invalid.
  error InvalidAddress();

  /// @notice Thrown when the caller is not the Hub.
  error OnlyHub();

  /// @notice Thrown when the max possible rate is greater than `MAX_BORROW_RATE`.
  error InvalidMaxRate();

  /// @notice Thrown when slope 2 (after kink point) is less than slope 1 (before kink point).
  error Slope2MustBeGteSlope1();

  /// @notice Thrown when the optimal usage ratio is less than `MIN_OPTIMAL_POINT` or greater than `MAX_OPTIMAL_POINT`.
  error InvalidOptimalUsageRatio();

  /// @notice Returns the full InterestRateData struct for the given asset.
  /// @param assetId The identifier of the asset to get the data for.
  /// @return The InterestRateData struct for the given asset, all in BPS.
  function getInterestRateData(uint256 assetId) external view returns (InterestRateData memory);

  /// @notice Returns the optimal usage rate for the given asset.
  /// @param assetId The identifier of the asset to get the optimal usage ratio for.
  /// @return The optimal usage ratio, in BPS.
  function getOptimalUsageRatio(uint256 assetId) external view returns (uint256);

  /// @notice Returns the base variable borrow rate.
  /// @param assetId The identifier of the asset to get the base variable borrow rate for.
  /// @return The base variable borrow rate, in BPS.
  function getBaseVariableBorrowRate(uint256 assetId) external view returns (uint256);

  /// @notice Returns the variable rate slope below optimal usage ratio.
  /// @dev Applicable when usage ratio > 0 and <= OPTIMAL_USAGE_RATIO.
  /// @param assetId The identifier of the asset to get the variable rate slope 1 for.
  /// @return The variable rate slope, in BPS.
  function getVariableRateSlope1(uint256 assetId) external view returns (uint256);

  /// @notice Returns the variable rate slope above optimal usage ratio.
  /// @dev Applicable when usage ratio > OPTIMAL_USAGE_RATIO.
  /// @param assetId The identifier of the asset to get the variable rate slope 2 for.
  /// @return The variable rate slope, in BPS.
  function getVariableRateSlope2(uint256 assetId) external view returns (uint256);

  /// @notice Returns the maximum variable borrow rate.
  /// @param assetId The identifier of the asset to get the maximum variable borrow rate for.
  /// @return The maximum variable borrow rate, in BPS.
  function getMaxVariableBorrowRate(uint256 assetId) external view returns (uint256);

  /// @notice Returns the maximum value achievable for the borrow rate.
  /// @return The maximum rate, in BPS.
  function MAX_BORROW_RATE() external view returns (uint256);

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
