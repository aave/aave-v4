// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IBasicInterestRateStrategy} from './IBasicInterestRateStrategy.sol';

/**
 * @title IAssetInterestRateStrategy
 * @author Aave Labs
 * @notice Interface of the asset interest rate strategy used by the Aave protocol
 */
interface IAssetInterestRateStrategy is IBasicInterestRateStrategy {
  /**
   * @notice Emitted when new interest rate data is set for an asset.
   * @param assetId id of the asset that has new interest rate data set.
   * @param optimalUsageRatio The optimal borrow usage ratio, in bps.
   * @param baseVariableBorrowRate The base variable borrow rate, in bps.
   * @param variableRateSlope1 The slope of the variable interest curve, before hitting the optimal  borrow usage ratio, in bps.
   * @param variableRateSlope2 The slope of the variable interest curve, after hitting the optimal borrow usage ratio, in bps.
   */
  event RateDataUpdate(
    uint256 indexed assetId,
    uint256 optimalUsageRatio,
    uint256 baseVariableBorrowRate,
    uint256 variableRateSlope1,
    uint256 variableRateSlope2
  );

  /**
   * @notice Holds the interest rate data for a given asset.
   *
   * @dev All values are in basis points (bps), where 1 bps = 0.01%.
   * This means that 10000 bps = 100%.
   * The maximum supported interest rate is 4294967295 bps (2**32-1) or 42949672.95%.
   *
   * @param optimalUsageRatio The optimal borrow usage ratio, in bps (1-9900).
   * @param baseVariableBorrowRate The base variable borrow rate, in bps.
   * @param variableRateSlope1 The slope of the variable interest curve, before hitting the optimal borrow usage ratio, in bps.
   * @param variableRateSlope2 The slope of the variable interest curve, after hitting the optimal borrow usage ratio, in bps.
   */
  struct InterestRateData {
    uint16 optimalUsageRatio;
    uint32 baseVariableBorrowRate;
    uint32 variableRateSlope1;
    uint32 variableRateSlope2;
  }

  /**
   * @notice Thrown when the caller is not the hub.
   */
  error OnlyHub();

  /**
   * @notice Thrown when the max possible rate is greater than `MAX_BORROW_RATE`.
   */
  error InvalidMaxRate();

  /**
   * @notice Thrown when slope 2 (after kink point) is less than slope 1 (before kink point).
   */
  error Slope2MustBeGteSlope1();

  /**
   * @notice Thrown when the optimal borrow usage ratio is less than `MIN_OPTIMAL_POINT` or greater than `MAX_OPTIMAL_POINT`.
   */
  error InvalidOptimalUsageRatio();

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
   * @notice Returns the maximum value achievable for variable borrow rate.
   * @return The maximum rate, in bps.
   */
  function MAX_BORROW_RATE() external view returns (uint256);

  /**
   * @notice Returns the minimum optimal borrow usage ratio.
   * @return The minimum optimal borrow usage ratio, in bps.
   */
  function MIN_OPTIMAL_RATIO() external view returns (uint256);

  /**
   * @notice Returns the maximum optimal borrow usage ratio.
   * @return The maximum optimal borrow usage ratio, in bps.
   */
  function MAX_OPTIMAL_RATIO() external view returns (uint256);

  /**
   * @notice Returns the address of the hub.
   * @return The address of the hub.
   */
  function HUB() external view returns (address);

  /**
   * @notice Returns the full InterestRateData object for the given asset.
   * @param assetId The id of the asset to get the data for.
   * @return The InterestRateData object for the given asset, all in bps.
   */
  function getInterestRateData(uint256 assetId) external view returns (InterestRateData memory);

  /**
   * @notice Returns the optimal borrow usage rate for the given asset.
   * @param assetId The id of the asset to get the optimal borrow usage ratio for.
   * @return The optimal borrow usage ratio, in bps.
   */
  function getOptimalUsageRatio(uint256 assetId) external view returns (uint256);

  /**
   * @notice Returns the base variable borrow rate.
   * @param assetId The id of the asset to get the base variable borrow rate for.
   * @return The base variable borrow rate, in bps.
   */
  function getBaseVariableBorrowRate(uint256 assetId) external view returns (uint256);

  /**
   * @notice Returns the variable rate slope below optimal borrow usage ratio.
   * @dev Applicable when usage ratio > 0 and <= OPTIMAL_USAGE_RATIO.
   * @param assetId The id of the asset to get the variable rate slope 1 for.
   * @return The variable rate slope, in bps.
   */
  function getVariableRateSlope1(uint256 assetId) external view returns (uint256);

  /**
   * @notice Returns the variable rate slope above optimal usage ratio.
   * @dev Applicable when usage ratio > OPTIMAL_USAGE_RATIO.
   * @param assetId The id of the asset to get the variable rate slope 2 for.
   * @return The variable rate slope, in bps.
   */
  function getVariableRateSlope2(uint256 assetId) external view returns (uint256);

  /**
   * @notice Returns the maximum variable borrow rate
   * @param assetId The id of the asset to get the maximum variable borrow rate for
   * @return The maximum variable borrow rate, in bps
   */
  function getMaxVariableBorrowRate(uint256 assetId) external view returns (uint256);
}
