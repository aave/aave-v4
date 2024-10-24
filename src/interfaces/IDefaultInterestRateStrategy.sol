// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IReserveInterestRateStrategy} from './IReserveInterestRateStrategy.sol';

/**
 * @title IDefaultInterestRateStrategy
 * @author Aave Labs
 * @notice Interface of the default interest rate strategy used by the Aave protocol
 */
interface IDefaultInterestRateStrategy is IReserveInterestRateStrategy {
  /**
   * @notice emitted when new interest rate data is set in a reserve
   *
   * @param assetId address of the reserve that has new interest rate data set
   * @param optimalUsageRatio The optimal usage ratio, in bps
   * @param baseVariableBorrowRate The base variable borrow rate, in bps
   * @param variableRateSlope1 The slope of the variable interest curve, before hitting the optimal ratio, in bps interest rate per bps usage ratio
   * @param variableRateSlope2 The slope of the variable interest curve, after hitting the optimal ratio, in bps interest rate per bps usage ratio
   */
  event RateDataUpdate(
    uint256 indexed assetId,
    uint256 optimalUsageRatio,
    uint256 baseVariableBorrowRate,
    uint256 variableRateSlope1,
    uint256 variableRateSlope2
  );

  struct CalcInterestRatesLocalVars {
    uint256 availableLiquidity;
    uint256 totalDebt;
    uint256 currentVariableBorrowRate;
    uint256 currentLiquidityRate;
    uint256 borrowUsageRatio;
    uint256 supplyUsageRatio;
    uint256 availableLiquidityPlusDebt;
  }

  /**
   * @notice Holds the interest rate data for a given reserve
   *
   * @dev All values are in basis points (bps), where 1 bps = 0.01%.
   * This means that 10000 bps = 100%.
   * The maximum supported interest rate is 4294967295 bps (2**32-1) or 42949672.95%.
   *
   * @param optimalUsageRatio The optimal usage ratio, in bps (0-10000)
   * @param baseVariableBorrowRate The base variable borrow rate, in bps
   * @param variableRateSlope1 The slope of the variable interest curve, before hitting the optimal ratio, in bps interest rate per bps usage ratio
   * @param variableRateSlope2 The slope of the variable interest curve, after hitting the optimal ratio, in bps interest rate per bps usage ratio
   */
  struct InterestRateData {
    uint16 optimalUsageRatio;
    uint32 baseVariableBorrowRate;
    uint32 variableRateSlope1;
    uint32 variableRateSlope2;
  }

  /**
   * @notice Sets interest rate data for an Aave rate strategy
   * @param assetId The assetId to update
   * @param rateData The reserve interest rate data to apply to the given reserve
   *   Being specific to this custom implementation, with custom struct type,
   *   overloading the function on the generic interface
   */
  function setInterestRateParams(uint256 assetId, InterestRateData calldata rateData) external;

  /**
   * @notice Returns the address of the PoolAddressesProvider
   * @return The address of the PoolAddressesProvider contract
   * TODO: Should be removed in favor of IPoolAddressesProvider ??
   */
  function ADDRESSES_PROVIDER() external view returns (address);

  /**
   * @notice Returns the maximum value achievable for variable borrow rate, in bps
   * @return The maximum rate
   */
  function MAX_BORROW_RATE() external view returns (uint256);

  /**
   * @notice Returns the minimum optimal point, in bps
   * @return The optimal point
   */
  function MIN_OPTIMAL_POINT() external view returns (uint256);

  /**
   * @notice Returns the maximum optimal point, in bps
   * @return The optimal point
   */
  function MAX_OPTIMAL_POINT() external view returns (uint256);

  /**
   * notice Returns the full InterestRateData object for the given reserve
   *
   * @param assetId The assetId to get the data of
   *
   * @return The InterestRateData object for the given reserve
   */
  function getInterestRateData(uint256 assetId) external view returns (InterestRateData memory);

  /**
   * @notice Returns the optimal usage rate for the given reserve in bps
   *
   * @param assetId The assetId to get the optimal usage rate of
   *
   * @return The optimal usage rate is the level of borrow / collateral at which the borrow rate
   */
  function getOptimalUsageRatio(uint256 assetId) external view returns (uint256);

  /**
   * @notice Returns the variable rate slope below optimal usage ratio in bps
   * @dev It's the variable rate when usage ratio > 0 and <= OPTIMAL_USAGE_RATIO
   *
   * @param assetId The assetId to get the variable rate slope 1 of
   *
   * @return The variable rate slope
   */
  function getVariableRateSlope1(uint256 assetId) external view returns (uint256);

  /**
   * @notice Returns the variable rate slope above optimal usage ratio in bps
   * @dev It's the variable rate when usage ratio > OPTIMAL_USAGE_RATIO
   *
   * @param assetId The assetId to get the variable rate slope 2 of
   *
   * @return The variable rate slope
   */
  function getVariableRateSlope2(uint256 assetId) external view returns (uint256);

  /**
   * @notice Returns the base variable borrow rate, in bps
   *
   * @param assetId The assetId to get the base variable borrow rate of
   *
   * @return The base variable borrow rate
   */
  function getBaseVariableBorrowRate(uint256 assetId) external view returns (uint256);

  /**
   * @notice Returns the maximum variable borrow rate, in bps
   *
   * @param assetId The assetId to get the maximum variable borrow rate of
   *
   * @return The maximum variable borrow rate
   */
  function getMaxVariableBorrowRate(uint256 assetId) external view returns (uint256);
}
