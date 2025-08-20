// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {WadRayMath} from './WadRayMath.sol';

/**
 * @title MathUtils library
 * @author Aave Labs
 */
library MathUtils {
  using WadRayMath for uint256;

  /// @dev Ignoring leap years
  uint256 internal constant SECONDS_PER_YEAR = 365 days;

  /**
   * @dev Function to calculate the interest accumulated using a linear interest rate formula.
   * @param rate The interest rate, in ray.
   * @param lastUpdateTimestamp The timestamp of the last update of the interest.
   * @return The interest rate linearly accumulated during the timeDelta, in ray.
   */
  function calculateLinearInterest(
    uint256 rate,
    uint40 lastUpdateTimestamp
  ) internal view returns (uint256) {
    uint256 result = rate * (block.timestamp - uint256(lastUpdateTimestamp));
    unchecked {
      result = result / SECONDS_PER_YEAR;
    }

    return WadRayMath.RAY + result;
  }

  /**
   * @notice Returns the minimum of two values.
   * @param a The first value to compare.
   * @param b The second value to compare.
   * @return result The minimum of the two values.
   */
  function min(uint256 a, uint256 b) internal pure returns (uint256 result) {
    assembly ('memory-safe') {
      result := xor(b, mul(xor(a, b), lt(a, b)))
    }
  }

  /**
   * @notice Adds a signed integer to an unsigned integer.
   * @dev Reverts on underflow.
   * @param a The unsigned integer.
   * @param b The signed integer.
   * @return The result of the addition.
   */
  function add(uint256 a, int256 b) internal pure returns (uint256) {
    if (b >= 0) return a + uint256(b);
    return a - uint256(-b);
  }

  /**
   * @notice Subtracts an unsigned integer from an unsigned integer.
   * @param a The unsigned integer.
   * @param b The unsigned integer.
   * @return The signed result of the subtraction.
   */
  function signedSub(uint256 a, uint256 b) internal pure returns (int256) {
    return int256(a) - int256(b);
  }

  /**
   * @notice Subtracts an unsigned integer from an unsigned integer which does not revert on underflow.
   * @param a The unsigned integer.
   * @param b The unsigned integer.
   * @return The unsigned result of the subtraction.
   */
  function uncheckedSub(uint256 a, uint256 b) internal pure returns (uint256) {
    unchecked {
      return a - b;
    }
  }
}
