// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

/// @title WadRayMath library
/// @author Aave Labs
/// @notice Provides utility functions to work with Wad and Ray units with explicit rounding.
library WadRayMath {
  uint256 internal constant WAD = 1e18;
  uint256 internal constant RAY = 1e27;
  uint256 internal constant PERCENTAGE_FACTOR = 1e4;

  /// @notice Multiplies two Wad numbers, rounding down.
  /// @dev Reverts if intermediate multiplication overflows.
  /// @return c = floor(a * b / WAD) in Wad units.
  function wadMulDown(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // to avoid overflow, a <= type(uint256).max / b
    assembly ('memory-safe') {
      if iszero(or(iszero(b), iszero(gt(a, div(not(0), b))))) {
        revert(0, 0)
      }

      c := div(mul(a, b), WAD)
    }
  }

  /// @notice Multiplies two Wad numbers, rounding up.
  /// @dev Reverts if intermediate multiplication overflows.
  /// @return c = ceil(a * b / WAD) in Wad units.
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

  /// @notice Divides two Wad numbers, rounding down.
  /// @dev Reverts if division by zero or intermediate multiplication overflows.
  /// @return c = floor(a * WAD / b) in Wad units.
  function wadDivDown(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // to avoid overflow, a <= type(uint256).max / WAD
    assembly ('memory-safe') {
      if or(iszero(b), iszero(iszero(gt(a, div(not(0), WAD))))) {
        revert(0, 0)
      }

      c := div(mul(a, WAD), b)
    }
  }

  /// @notice Divides two Wad numbers, rounding up.
  /// @dev Reverts if division by zero or intermediate multiplication overflows.
  /// @return c = ceil(a * WAD / b) in Wad units.
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
  /// @dev Reverts if intermediate multiplication overflows.
  /// @return c = floor(a * b / RAY) in Ray units.
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
  /// @dev Reverts if intermediate multiplication overflows.
  /// @return c = ceil(a * b / RAY) in Ray units.
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
  /// @dev Reverts if division by zero or intermediate multiplication overflows.
  /// @return c = floor(a * RAY / b) in Ray units.
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
  /// @dev Reverts if division by zero or intermediate multiplication overflows.
  /// @return c = ceil(a * RAY / b) in Ray units.
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
  /// @dev Reverts if intermediate multiplication overflows.
  /// @return b = a * WAD in Wad units.
  function toWad(uint256 a) internal pure returns (uint256 b) {
    // to avoid overflow, b/WAD == a
    assembly {
      b := mul(a, WAD)

      if iszero(eq(div(b, WAD), a)) {
        revert(0, 0)
      }
    }
  }

  /// @notice Removes Wad precision from a given value, rounding down.
  /// @return b = a / WAD in Wad units.
  function fromWadDown(uint256 a) internal pure returns (uint256 b) {
    assembly {
      b := div(a, WAD)
    }
  }

  /// @notice Converts value from basis points to Wad, rounding down.
  /// @dev Reverts if intermediate multiplication overflows.
  /// @return c = floor(a * WAD / PERCENTAGE_FACTOR) in Wad units.
  function bpsToWad(uint256 a) internal pure returns (uint256) {
    return (a * WAD) / PERCENTAGE_FACTOR;
  }

  /// @notice Converts value from basis points to Ray, rounding down.
  /// @dev Reverts if intermediate multiplication overflows.
  /// @return c = a * RAY / PERCENTAGE_FACTOR in Ray units.
  function bpsToRay(uint256 a) internal pure returns (uint256) {
    return (a * RAY) / PERCENTAGE_FACTOR;
  }
}
