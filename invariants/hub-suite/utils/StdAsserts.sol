// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

/// @notice Standard assertions for the test suite
abstract contract StdAsserts {
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                     ASSERTION HELPERS                                     //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @notice Assert that a value is true
  function assertTrue(bool condition, string memory errorMessage) internal pure {
    require(condition, errorMessage);
  }

  /// @notice Assert that a value is false
  function assertFalse(bool condition, string memory errorMessage) internal pure {
    require(!condition, errorMessage);
  }

  /// @notice Assert two values are equal
  function assertEqual(uint256 a, uint256 b, string memory errorMessage) internal pure {
    require(a == b, errorMessage);
  }

  /// @notice Assert a is less than or equal to b
  function assertLe(uint256 a, uint256 b, string memory errorMessage) internal pure {
    require(a <= b, errorMessage);
  }

  /// @notice Assert a is greater than or equal to b
  function assertGe(uint256 a, uint256 b, string memory errorMessage) internal pure {
    require(a >= b, errorMessage);
  }

  /// @notice Assert a is less than b
  function assertLt(uint256 a, uint256 b, string memory errorMessage) internal pure {
    require(a < b, errorMessage);
  }

  /// @notice Assert a is greater than b
  function assertGt(uint256 a, uint256 b, string memory errorMessage) internal pure {
    require(a > b, errorMessage);
  }

  /// @notice Assert two addresses are equal
  function assertEq(address a, address b, string memory errorMessage) internal pure {
    require(a == b, errorMessage);
  }
}
