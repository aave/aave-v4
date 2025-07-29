// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title PercentageMath library
 * @author Aave
 * @notice Provides functions to perform percentage calculations with explicit rounding
 * @dev Percentages are defined by default with 2 decimals of precision (100.00). The precision is indicated by PERCENTAGE_FACTOR
 */
library PercentageMath {
  // Maximum percentage factor (100.00%)
  uint256 internal constant PERCENTAGE_FACTOR = 1e4;

  /**
   * @dev Executes a percentage multiplication, rounded down
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param value The value of which the percentage needs to be calculated
   * @param percentage The percentage of the value to be calculated
   * @return result value percentMul percentage
   */
  function percentMulDown(
    uint256 value,
    uint256 percentage
  ) internal pure returns (uint256 result) {
    // to avoid overflow, value <= type(uint256).max / percentage
    assembly ('memory-safe') {
      if iszero(or(iszero(percentage), iszero(gt(value, div(not(0), percentage))))) {
        revert(0, 0)
      }

      result := div(mul(value, percentage), PERCENTAGE_FACTOR)
    }
  }

  /**
   * @dev Executes a percentage multiplication, rounded up
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param value The value of which the percentage needs to be calculated
   * @param percentage The percentage of the value to be calculated (in BPS)
   * @return result value percentMul percentage
   */
  function percentMulUp(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
    // to avoid overflow, value <= type(uint256).max / percentage
    assembly ('memory-safe') {
      if iszero(or(iszero(percentage), iszero(gt(value, div(not(0), percentage))))) {
        revert(0, 0)
      }
      result := mul(value, percentage)

      // Add 1 if (value * percentage) % PERCENTAGE_FACTOR > 0 to round up the division of (value * percentage) by PERCENTAGE_FACTOR
      result := add(div(result, PERCENTAGE_FACTOR), gt(mod(result, PERCENTAGE_FACTOR), 0))
    }
  }

  /**
   * @dev Executes a percentage division, rounded down
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param value The value of which the percentage needs to be calculated
   * @param percentage The percentage of the value to be calculated (in BPS)
   * @return result value percentDiv percentage
   */
  function percentDivDown(
    uint256 value,
    uint256 percentage
  ) internal pure returns (uint256 result) {
    // to avoid overflow, value <= type(uint256).max / PERCENTAGE_FACTOR
    assembly ('memory-safe') {
      if or(iszero(percentage), iszero(iszero(gt(value, div(not(0), PERCENTAGE_FACTOR))))) {
        revert(0, 0)
      }

      result := div(mul(value, PERCENTAGE_FACTOR), percentage)
    }
  }

  /**
   * @dev Executes a percentage division, rounded up
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param value The value of which the percentage needs to be calculated
   * @param percentage The percentage of the value to be calculated (in BPS)
   * @return result value percentDiv percentage
   */
  function percentDivUp(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
    // to avoid overflow, value <= type(uint256).max / PERCENTAGE_FACTOR
    assembly ('memory-safe') {
      if or(iszero(percentage), iszero(iszero(gt(value, div(not(0), PERCENTAGE_FACTOR))))) {
        revert(0, 0)
      }
      result := mul(value, PERCENTAGE_FACTOR)

      // Add 1 if (value * PERCENTAGE_FACTOR) % percentage > 0 to round up the division of (value * PERCENTAGE_FACTOR) by percentage
      result := add(div(result, percentage), gt(mod(result, percentage), 0))
    }
  }

  /**
   * @dev Truncates number from BPS precision, rounding down.
   * @param value The number in BPS precision.
   * @return result (value / 1e4)
   */
  function fromBpsDown(uint256 value) internal pure returns (uint256) {
    return value / PERCENTAGE_FACTOR;
  }
}
