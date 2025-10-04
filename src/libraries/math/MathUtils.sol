// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

/// @title MathUtils library
/// @author Aave Labs
library MathUtils {
  /// @dev Ignoring leap years
  uint256 internal constant SECONDS_PER_YEAR = 365 days;
  uint256 internal constant RAY = 1e27;

  /// @notice Function to calculate the interest accumulated using a linear interest rate formula.
  /// @dev Calculates interest rate from provided `lastUpdateTimestamp` until present, and it has to be
  /// greater than `block.timestamp`.
  /// @param rate The interest rate in Ray units.
  /// @param lastUpdateTimestamp The timestamp to calculate interest rate from.
  /// @return result The interest rate linearly accumulated during the timeDelta in Ray units.
  function calculateLinearInterest(
    uint256 rate,
    uint32 lastUpdateTimestamp
  ) internal view returns (uint256 result) {
    assembly ('memory-safe') {
      result := add(div(mul(rate, sub(timestamp(), lastUpdateTimestamp)), SECONDS_PER_YEAR), RAY)
    }
  }

  /// @notice Returns the smaller of two unsigned integers.
  function min(uint256 a, uint256 b) internal pure returns (uint256 result) {
    assembly ('memory-safe') {
      result := xor(b, mul(xor(a, b), lt(a, b)))
    }
  }

  /// @notice Returns the sum of an unsigned and signed integer.
  /// @dev Reverts on underflow.
  function add(uint256 a, int256 b) internal pure returns (uint256) {
    if (b >= 0) return a + uint256(b);
    return a - uint256(-b);
  }

  /// @notice Returns the sum of two unsigned integers.
  /// @dev Does not revert on overflow.
  function uncheckedAdd(uint256 a, uint256 b) internal pure returns (uint256) {
    unchecked {
      return a + b;
    }
  }

  /// @notice Returns the difference of two unsigned integers as a signed integer.
  /// @dev Does not ensure the `a` and `b` values are within the range of a signed integer.
  function signedSub(uint256 a, uint256 b) internal pure returns (int256) {
    return int256(a) - int256(b);
  }

  /// @notice Returns the difference of two unsigned integers.
  /// @dev Does not revert on underflow.
  function uncheckedSub(uint256 a, uint256 b) internal pure returns (uint256) {
    unchecked {
      return a - b;
    }
  }

  /// @notice Raises an unsigned integer to the power of an unsigned integer.
  /// @dev Does not revert on overflow.
  function uncheckedExp(uint256 a, uint256 b) internal pure returns (uint256) {
    unchecked {
      return a ** b;
    }
  }

  /// @notice Multiplies `a` and `b` in 256 bits and divides the result by `c`, rounding down.
  /// @dev Reverts if division by zero or overflow occurs on intermediate multiplication.
  function mulDivDown(uint256 a, uint256 b, uint256 c) internal pure returns (uint256 d) {
    assembly ('memory-safe') {
      if iszero(c) {
        revert(0, 0)
      }
      if iszero(or(iszero(b), iszero(gt(a, div(not(0), b))))) {
        revert(0, 0)
      }
      d := div(mul(a, b), c)
    }
  }

  /// @notice Multiplies `a` and `b` in 256 bits and divides the result by `c`, rounding up.
  /// @dev Reverts if division by zero or overflow occurs on intermediate multiplication.
  function mulDivUp(uint256 a, uint256 b, uint256 c) internal pure returns (uint256 d) {
    assembly ('memory-safe') {
      if iszero(c) {
        revert(0, 0)
      }
      if iszero(or(iszero(b), iszero(gt(a, div(not(0), b))))) {
        revert(0, 0)
      }
      let product := mul(a, b)
      d := add(div(product, c), gt(mod(product, c), 0))
    }
  }
}
