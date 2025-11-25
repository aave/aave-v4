// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {ReserveFlags, ReserveFlagsLib} from 'src/spoke/libraries/ReserveFlags.sol';

contract ReserveFlagsTests is Test {
  uint8 internal constant PAUSED_MASK = 0x001;
  uint8 internal constant FROZEN_MASK = 0x002;
  uint8 internal constant BORROWABLE_MASK = 0x004;
  uint8 internal constant RECEIVE_SHARES_ENABLED_MASK = 0x008;

  function test_initFlags_fuzz(
    bool paused,
    bool frozen,
    bool borrowable,
    bool receiveSharesEnabled
  ) public pure {
    ReserveFlags flags = ReserveFlagsLib.initFlags(
      paused,
      frozen,
      borrowable,
      receiveSharesEnabled
    );

    assertEq(ReserveFlagsLib.paused(flags), paused);
    assertEq(ReserveFlagsLib.frozen(flags), frozen);
    assertEq(ReserveFlagsLib.borrowable(flags), borrowable);
    assertEq(ReserveFlagsLib.receiveSharesEnabled(flags), receiveSharesEnabled);
  }

  function test_set_flags() public pure {
    ReserveFlags flags;
    assertEq(ReserveFlagsLib.paused(flags), false);
    assertEq(ReserveFlagsLib.frozen(flags), false);
    assertEq(ReserveFlagsLib.borrowable(flags), false);
    assertEq(ReserveFlagsLib.receiveSharesEnabled(flags), false);

    flags = ReserveFlagsLib.setPaused(flags, true);
    assertEq(ReserveFlagsLib.paused(flags), true);
    assertEq(ReserveFlagsLib.frozen(flags), false);
    assertEq(ReserveFlagsLib.borrowable(flags), false);
    assertEq(ReserveFlagsLib.receiveSharesEnabled(flags), false);

    flags = ReserveFlagsLib.setFrozen(flags, true);
    assertEq(ReserveFlagsLib.paused(flags), true);
    assertEq(ReserveFlagsLib.frozen(flags), true);
    assertEq(ReserveFlagsLib.borrowable(flags), false);
    assertEq(ReserveFlagsLib.receiveSharesEnabled(flags), false);

    flags = ReserveFlagsLib.setBorrowable(flags, true);
    assertEq(ReserveFlagsLib.paused(flags), true);
    assertEq(ReserveFlagsLib.frozen(flags), true);
    assertEq(ReserveFlagsLib.borrowable(flags), true);
    assertEq(ReserveFlagsLib.receiveSharesEnabled(flags), false);

    flags = ReserveFlagsLib.setReceiveSharesEnabled(flags, true);
    assertEq(ReserveFlagsLib.paused(flags), true);
    assertEq(ReserveFlagsLib.frozen(flags), true);
    assertEq(ReserveFlagsLib.borrowable(flags), true);
    assertEq(ReserveFlagsLib.receiveSharesEnabled(flags), true);

    flags = ReserveFlagsLib.setFrozen(flags, false);
    assertEq(ReserveFlagsLib.paused(flags), true);
    assertEq(ReserveFlagsLib.frozen(flags), false);
    assertEq(ReserveFlagsLib.borrowable(flags), true);
    assertEq(ReserveFlagsLib.receiveSharesEnabled(flags), true);

    flags = ReserveFlagsLib.setBorrowable(flags, false);
    assertEq(ReserveFlagsLib.paused(flags), true);
    assertEq(ReserveFlagsLib.frozen(flags), false);
    assertEq(ReserveFlagsLib.borrowable(flags), false);
    assertEq(ReserveFlagsLib.receiveSharesEnabled(flags), true);

    flags = ReserveFlagsLib.setReceiveSharesEnabled(flags, false);
    assertEq(ReserveFlagsLib.paused(flags), true);
    assertEq(ReserveFlagsLib.frozen(flags), false);
    assertEq(ReserveFlagsLib.borrowable(flags), false);
    assertEq(ReserveFlagsLib.receiveSharesEnabled(flags), false);

    flags = ReserveFlagsLib.setPaused(flags, false);
    assertEq(ReserveFlagsLib.paused(flags), false);
    assertEq(ReserveFlagsLib.frozen(flags), false);
    assertEq(ReserveFlagsLib.borrowable(flags), false);
    assertEq(ReserveFlagsLib.receiveSharesEnabled(flags), false);
  }

  function test_setPaused_fuzz(uint8 rawFlags) public pure {
    ReserveFlags flags = _sanitizeFlags(rawFlags);
    uint8 expectedRawFlags = ReserveFlags.unwrap(flags);

    expectedRawFlags = expectedRawFlags | PAUSED_MASK;

    flags = ReserveFlagsLib.setPaused(flags, true);

    assertEq(ReserveFlagsLib.paused(flags), true);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);

    expectedRawFlags = expectedRawFlags & ~PAUSED_MASK;

    flags = ReserveFlagsLib.setPaused(flags, false);

    assertEq(ReserveFlagsLib.paused(flags), false);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);
  }

  function test_setFrozen_fuzz(uint8 rawFlags) public pure {
    ReserveFlags flags = _sanitizeFlags(rawFlags);
    uint8 expectedRawFlags = ReserveFlags.unwrap(flags);

    expectedRawFlags = expectedRawFlags | FROZEN_MASK;

    flags = ReserveFlagsLib.setFrozen(flags, true);

    assertEq(ReserveFlagsLib.frozen(flags), true);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);

    expectedRawFlags = expectedRawFlags & ~FROZEN_MASK;

    flags = ReserveFlagsLib.setFrozen(flags, false);

    assertEq(ReserveFlagsLib.frozen(flags), false);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);
  }

  function test_setBorrowable_fuzz(uint8 rawFlags) public pure {
    ReserveFlags flags = _sanitizeFlags(rawFlags);
    uint8 expectedRawFlags = ReserveFlags.unwrap(flags);

    expectedRawFlags = expectedRawFlags | BORROWABLE_MASK;

    flags = ReserveFlagsLib.setBorrowable(flags, true);

    assertEq(ReserveFlagsLib.borrowable(flags), true);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);

    expectedRawFlags = expectedRawFlags & ~BORROWABLE_MASK;

    flags = ReserveFlagsLib.setBorrowable(flags, false);

    assertEq(ReserveFlagsLib.borrowable(flags), false);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);
  }

  function test_setReceiveSharesEnabled_fuzz(uint8 rawFlags) public pure {
    ReserveFlags flags = _sanitizeFlags(rawFlags);
    uint8 expectedRawFlags = ReserveFlags.unwrap(flags);

    expectedRawFlags = expectedRawFlags | RECEIVE_SHARES_ENABLED_MASK;

    flags = ReserveFlagsLib.setReceiveSharesEnabled(flags, true);

    assertEq(ReserveFlagsLib.receiveSharesEnabled(flags), true);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);

    expectedRawFlags = expectedRawFlags & ~RECEIVE_SHARES_ENABLED_MASK;

    flags = ReserveFlagsLib.setReceiveSharesEnabled(flags, false);

    assertEq(ReserveFlagsLib.receiveSharesEnabled(flags), false);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);
  }

  function _sanitizeFlags(uint8 rawFlags) internal pure returns (ReserveFlags) {
    uint8 sanitizedFlags = rawFlags &
      (PAUSED_MASK | FROZEN_MASK | BORROWABLE_MASK | RECEIVE_SHARES_ENABLED_MASK);
    return ReserveFlags.wrap(sanitizedFlags);
  }
}
