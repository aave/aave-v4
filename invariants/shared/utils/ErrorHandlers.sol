// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

/// @title ErrorHandlers
/// @notice Library for handling errors in the test suite
library ErrorHandlers {
  /// @dev Selector for Panic(uint256) as defined by Solidity
  bytes4 internal constant _PANIC_SELECTOR = 0x4e487b71;
  /// @dev Panic code for assertion failed (0x01)
  uint256 internal constant _PANIC_ASSERTION_FAILED = 0x01;

  event AssertFail(string);

  /// @notice Checks if a call failed due to an assertion error and propagates the error if found.
  /// @param success Indicates whether the call was successful.
  /// @param returnData The data returned from the call.
  function handleAssertionError(
    bool success,
    bytes memory returnData,
    bool detectNonAssertionErrors,
    string memory errorMessage
  ) internal {
    // Case 1: do nothing if success is true
    if (success) return;

    // Case 2: detect Panic(0x01) "Assertion" errors
    // Decode potential Panic(uint256) (selector + uint256 = 36 bytes)
    if (returnData.length == 36) {
      bytes4 selector;
      uint256 code;
      assembly {
        selector := mload(add(returnData, 0x20))
        code := mload(add(returnData, 0x24))
      }
      // Case 3: if Panic(0x01) "Assertion" -> assert(false), this propagates the assertion error to the Tester context
      if (selector == _PANIC_SELECTOR && code == _PANIC_ASSERTION_FAILED) {
        assert(false);
      }
    }

    // Case 3: detect non-assertion errors and assert with the error message
    if (detectNonAssertionErrors) {
      assertWithMsg(false, errorMessage);
    }
  }

  function assertWithMsg(bool b, string memory reason) internal {
    if (!b) {
      emit AssertFail(reason);
      assert(false);
    }
  }
}
