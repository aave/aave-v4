// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

/// @title WadRayMath library
/// @author Aave Labs
/// @notice Provides functions to perform calculations with Wad and Ray units with explicit rounding.
/// @dev Provides mul and div function for Wads (decimal numbers with 18 digits of precision) and Rays (decimal numbers
/// with 27 digits of precision).
library WadRayMath {
  uint256 internal constant WAD = 1e18;
  uint256 internal constant RAY = 1e27;
  uint256 internal constant PERCENTAGE_FACTOR = 1e4;

  /// @notice Multiplies two numbers in Wad precisions, rounding down.
  /// @param a First Number in Wad precision.
  /// @param b Second Number in Wad precision.
  /// @return c The result of the multiplication, in Wad.
  function wadMulDown(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // to avoid overflow, a <= type(uint256).max / b
    assembly ('memory-safe') {
      if iszero(or(iszero(b), iszero(gt(a, div(not(0), b))))) {
        revert(0, 0)
      }

      c := div(mul(a, b), WAD)
    }
  }

  /// @notice Multiplies two numbers in Wad precisions, rounding up.
  /// @param a First Number in Wad precision.
  /// @param b Second Number in Wad precision.
  /// @return c The result of the multiplication, in Wad.
  function wadMulUp(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // to avoid overflow, a <= type(uint256).max / b
    assembly ('memory-safe') {
      if iszero(or(iszero(b), iszero(gt(a, div(not(0), b))))) {
        revert(0, 0)
      }
      c := mul(a, b)
      // Add 1 if (a * b) % WAD > 0 to round up the division of (a * b) by WAD
      c := add(div(c, WAD), gt(mod(c, WAD), 0))
    }
  }

  /// @notice Divides two Number in Wad precisions, rounding down.
  /// @param a First Number in Wad precision.
  /// @param b Second Number in Wad precision.
  /// @return c The result of the division, in Wad.
  function wadDivDown(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // to avoid overflow, a <= type(uint256).max / WAD
    assembly ('memory-safe') {
      if or(iszero(b), iszero(iszero(gt(a, div(not(0), WAD))))) {
        revert(0, 0)
      }

      c := div(mul(a, WAD), b)
    }
  }

  /// @notice Divides two numbers in Wad precisions, rounding up.
  /// @param a First Number in Wad precision.
  /// @param b Second Number in Wad precision.
  /// @return c The result of the division, in Wad.
  function wadDivUp(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // to avoid overflow, a <= type(uint256).max / WAD
    assembly ('memory-safe') {
      if or(iszero(b), iszero(iszero(gt(a, div(not(0), WAD))))) {
        revert(0, 0)
      }
      c := mul(a, WAD)
      // Add 1 if (a * WAD) % b > 0 to round up the division of (a * WAD) by b
      c := add(div(c, b), gt(mod(c, b), 0))
    }
  }

  /// @notice Multiplies two Ray numbers, rounding down.
  /// @param a First Ray number.
  /// @param b Second Ray number.
  /// @return c The result of the multiplication, in Ray.
  function rayMulDown(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // to avoid overflow, a <= type(uint256).max / b
    assembly ('memory-safe') {
      if iszero(or(iszero(b), iszero(gt(a, div(not(0), b))))) {
        revert(0, 0)
      }

      c := div(mul(a, b), RAY)
    }
  }

  /// @notice Multiplies two Ray numbers, rounding up.
  /// @param a First Ray number.
  /// @param b Second Ray number.
  /// @return c The result of the multiplication, in Ray.
  function rayMulUp(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // to avoid overflow, a <= type(uint256).max / b
    assembly ('memory-safe') {
      if iszero(or(iszero(b), iszero(gt(a, div(not(0), b))))) {
        revert(0, 0)
      }
      c := mul(a, b)
      // Add 1 if (a * b) % RAY > 0 to round up the division of (a * b) by RAY
      c := add(div(c, RAY), gt(mod(c, RAY), 0))
    }
  }

  /// @notice Divides two Ray numbers, rounding down.
  /// @param a First Ray number.
  /// @param b Second Ray number.
  /// @return c The result of the division, in Ray.
  function rayDivDown(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // to avoid overflow, a <= type(uint256).max / RAY
    assembly ('memory-safe') {
      if or(iszero(b), iszero(iszero(gt(a, div(not(0), RAY))))) {
        revert(0, 0)
      }

      c := div(mul(a, RAY), b)
    }
  }

  /// @notice Divides two Ray numbers, rounding up.
  /// @param a First Ray number.
  /// @param b Second Ray number.
  /// @return c The result of the division, in Ray.
  function rayDivUp(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // to avoid overflow, a <= type(uint256).max / RAY
    assembly ('memory-safe') {
      if or(iszero(b), iszero(iszero(gt(a, div(not(0), RAY))))) {
        revert(0, 0)
      }
      c := mul(a, RAY)
      // Add 1 if (a * RAY) % b > 0 to round up the division of (a * RAY) by b
      c := add(div(c, b), gt(mod(c, b), 0))
    }
  }

  /// @notice Casts value to Wad, adding 18 digits of precision.
  /// @param a The number to cast to Wad.
  /// @return b The resulting casted value.
  function toWad(uint256 a) internal pure returns (uint256 b) {
    // to avoid overflow, b/WAD == a
    assembly {
      b := mul(a, WAD)

      if iszero(eq(div(b, WAD), a)) {
        revert(0, 0)
      }
    }
  }

  /// @notice Converts number from Wad precision, rounding down.
  /// @param a The number in Wad precision.
  /// @return b The resulting truncated value.
  function fromWadDown(uint256 a) internal pure returns (uint256 b) {
    assembly {
      b := div(a, WAD)
    }
  }

  /// @notice Converts value from basis points to Wad.
  /// @param a The value in basis points.
  /// @return The resulting value in Wad.
  function bpsToWad(uint256 a) internal pure returns (uint256) {
    return (a * WAD) / PERCENTAGE_FACTOR;
  }

  /// @notice Converts value from basis points to Ray.
  /// @param a The value in basis points.
  /// @return The resulting value in Ray.
  function bpsToRay(uint256 a) internal pure returns (uint256) {
    return (a * RAY) / PERCENTAGE_FACTOR;
  }
}
