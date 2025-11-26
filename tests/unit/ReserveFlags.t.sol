// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {ReserveFlags, ReserveFlagsMap} from 'src/spoke/libraries/ReserveFlagsMap.sol';

contract ReserveFlagsTests is Test {
  uint8 internal constant PAUSED_MASK = 0x01;
  uint8 internal constant FROZEN_MASK = 0x02;
  uint8 internal constant BORROWABLE_MASK = 0x04;
  uint8 internal constant RECEIVE_SHARES_ENABLED_MASK = 0x08;

  function test_initFlags_fuzz(
    bool paused,
    bool frozen,
    bool borrowable,
    bool receiveSharesEnabled
  ) public pure {
    ReserveFlags flags = ReserveFlagsMap.initFlags(
      paused,
      frozen,
      borrowable,
      receiveSharesEnabled
    );

    assertEq(ReserveFlagsMap.paused(flags), paused);
    assertEq(ReserveFlagsMap.frozen(flags), frozen);
    assertEq(ReserveFlagsMap.borrowable(flags), borrowable);
    assertEq(ReserveFlagsMap.receiveSharesEnabled(flags), receiveSharesEnabled);
  }

  function test_set_flags() public pure {
    ReserveFlags flags;
    assertEq(ReserveFlagsMap.paused(flags), false);
    assertEq(ReserveFlagsMap.frozen(flags), false);
    assertEq(ReserveFlagsMap.borrowable(flags), false);
    assertEq(ReserveFlagsMap.receiveSharesEnabled(flags), false);

    flags = ReserveFlagsMap.setPaused(flags, true);
    assertEq(ReserveFlagsMap.paused(flags), true);
    assertEq(ReserveFlagsMap.frozen(flags), false);
    assertEq(ReserveFlagsMap.borrowable(flags), false);
    assertEq(ReserveFlagsMap.receiveSharesEnabled(flags), false);

    flags = ReserveFlagsMap.setFrozen(flags, true);
    assertEq(ReserveFlagsMap.paused(flags), true);
    assertEq(ReserveFlagsMap.frozen(flags), true);
    assertEq(ReserveFlagsMap.borrowable(flags), false);
    assertEq(ReserveFlagsMap.receiveSharesEnabled(flags), false);

    flags = ReserveFlagsMap.setBorrowable(flags, true);
    assertEq(ReserveFlagsMap.paused(flags), true);
    assertEq(ReserveFlagsMap.frozen(flags), true);
    assertEq(ReserveFlagsMap.borrowable(flags), true);
    assertEq(ReserveFlagsMap.receiveSharesEnabled(flags), false);

    flags = ReserveFlagsMap.setReceiveSharesEnabled(flags, true);
    assertEq(ReserveFlagsMap.paused(flags), true);
    assertEq(ReserveFlagsMap.frozen(flags), true);
    assertEq(ReserveFlagsMap.borrowable(flags), true);
    assertEq(ReserveFlagsMap.receiveSharesEnabled(flags), true);

    flags = ReserveFlagsMap.setFrozen(flags, false);
    assertEq(ReserveFlagsMap.paused(flags), true);
    assertEq(ReserveFlagsMap.frozen(flags), false);
    assertEq(ReserveFlagsMap.borrowable(flags), true);
    assertEq(ReserveFlagsMap.receiveSharesEnabled(flags), true);

    flags = ReserveFlagsMap.setBorrowable(flags, false);
    assertEq(ReserveFlagsMap.paused(flags), true);
    assertEq(ReserveFlagsMap.frozen(flags), false);
    assertEq(ReserveFlagsMap.borrowable(flags), false);
    assertEq(ReserveFlagsMap.receiveSharesEnabled(flags), true);

    flags = ReserveFlagsMap.setReceiveSharesEnabled(flags, false);
    assertEq(ReserveFlagsMap.paused(flags), true);
    assertEq(ReserveFlagsMap.frozen(flags), false);
    assertEq(ReserveFlagsMap.borrowable(flags), false);
    assertEq(ReserveFlagsMap.receiveSharesEnabled(flags), false);

    flags = ReserveFlagsMap.setPaused(flags, false);
    assertEq(ReserveFlagsMap.paused(flags), false);
    assertEq(ReserveFlagsMap.frozen(flags), false);
    assertEq(ReserveFlagsMap.borrowable(flags), false);
    assertEq(ReserveFlagsMap.receiveSharesEnabled(flags), false);
  }

  function test_setPaused_fuzz(uint8 rawFlags) public pure {
    ReserveFlags flags = _sanitizeFlags(rawFlags);
    uint8 expectedRawFlags = ReserveFlags.unwrap(flags);

    expectedRawFlags = expectedRawFlags | PAUSED_MASK;

    flags = ReserveFlagsMap.setPaused(flags, true);

    assertEq(ReserveFlagsMap.paused(flags), true);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);

    expectedRawFlags = expectedRawFlags & ~PAUSED_MASK;

    flags = ReserveFlagsMap.setPaused(flags, false);

    assertEq(ReserveFlagsMap.paused(flags), false);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);
  }

  function test_setFrozen_fuzz(uint8 rawFlags) public pure {
    ReserveFlags flags = _sanitizeFlags(rawFlags);
    uint8 expectedRawFlags = ReserveFlags.unwrap(flags);

    expectedRawFlags = expectedRawFlags | FROZEN_MASK;

    flags = ReserveFlagsMap.setFrozen(flags, true);

    assertEq(ReserveFlagsMap.frozen(flags), true);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);

    expectedRawFlags = expectedRawFlags & ~FROZEN_MASK;

    flags = ReserveFlagsMap.setFrozen(flags, false);

    assertEq(ReserveFlagsMap.frozen(flags), false);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);
  }

  function test_setBorrowable_fuzz(uint8 rawFlags) public pure {
    ReserveFlags flags = _sanitizeFlags(rawFlags);
    uint8 expectedRawFlags = ReserveFlags.unwrap(flags);

    expectedRawFlags = expectedRawFlags | BORROWABLE_MASK;

    flags = ReserveFlagsMap.setBorrowable(flags, true);

    assertEq(ReserveFlagsMap.borrowable(flags), true);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);

    expectedRawFlags = expectedRawFlags & ~BORROWABLE_MASK;

    flags = ReserveFlagsMap.setBorrowable(flags, false);

    assertEq(ReserveFlagsMap.borrowable(flags), false);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);
  }

  function test_setReceiveSharesEnabled_fuzz(uint8 rawFlags) public pure {
    ReserveFlags flags = _sanitizeFlags(rawFlags);
    uint8 expectedRawFlags = ReserveFlags.unwrap(flags);

    expectedRawFlags = expectedRawFlags | RECEIVE_SHARES_ENABLED_MASK;

    flags = ReserveFlagsMap.setReceiveSharesEnabled(flags, true);

    assertEq(ReserveFlagsMap.receiveSharesEnabled(flags), true);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);

    expectedRawFlags = expectedRawFlags & ~RECEIVE_SHARES_ENABLED_MASK;

    flags = ReserveFlagsMap.setReceiveSharesEnabled(flags, false);

    assertEq(ReserveFlagsMap.receiveSharesEnabled(flags), false);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);
  }

  /// @dev Sanitizes the raw flags by masking out any irrelevant bits.
  function _sanitizeFlags(uint8 rawFlags) internal pure returns (ReserveFlags) {
    uint8 sanitizedFlags = rawFlags &
      (PAUSED_MASK | FROZEN_MASK | BORROWABLE_MASK | RECEIVE_SHARES_ENABLED_MASK);
    return ReserveFlags.wrap(sanitizedFlags);
  }
}
