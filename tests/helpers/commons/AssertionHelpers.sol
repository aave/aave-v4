// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {VmSafe} from 'forge-std/Vm.sol';

/// @title AssertionHelpers
/// @notice Common assertion utilities for the Aave V4 test suite.
abstract contract AssertionHelpers is Test {
  function _assertEventNotEmitted(bytes32 eventSignature) internal {
    VmSafe.Log[] memory entries = vm.getRecordedLogs();
    for (uint256 i; i < entries.length; i++) {
      assertNotEq(entries[i].topics[0], eventSignature);
    }
    vm.recordLogs();
  }

  function _assertEventsNotEmitted(bytes32 event1Sig, bytes32 event2Sig) internal {
    VmSafe.Log[] memory entries = vm.getRecordedLogs();
    for (uint256 i; i < entries.length; i++) {
      assertNotEq(entries[i].topics[0], event1Sig);
      assertNotEq(entries[i].topics[0], event2Sig);
    }
    vm.recordLogs();
  }

  function _assertEventsNotEmitted(
    bytes32 event1Sig,
    bytes32 event2Sig,
    bytes32 event3Sig
  ) internal {
    VmSafe.Log[] memory entries = vm.getRecordedLogs();
    for (uint256 i; i < entries.length; i++) {
      assertNotEq(entries[i].topics[0], event1Sig);
      assertNotEq(entries[i].topics[0], event2Sig);
      assertNotEq(entries[i].topics[0], event3Sig);
    }
    vm.recordLogs();
  }
}
