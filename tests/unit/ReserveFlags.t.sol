// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {ReserveFlags} from 'src/spoke/interfaces/ISpoke.sol';
import {ReserveFlagsMapWrapper} from 'tests/mocks/ReserveFlagsMapWrapper.sol';

contract ReserveFlagsTests is Test {
  uint8 internal constant PAUSED_MASK = 0x01;
  uint8 internal constant FROZEN_MASK = 0x02;
  uint8 internal constant BORROWABLE_MASK = 0x04;
  uint8 internal constant LIQUIDATABLE_MASK = 0x08;
  uint8 internal constant RECEIVE_SHARES_ENABLED_MASK = 0x10;

  ReserveFlagsMapWrapper internal w;

  function setUp() public {
    w = new ReserveFlagsMapWrapper();
  }

  function test_constants() public view {
    assertEq(w.PAUSED_MASK(), PAUSED_MASK);
    assertEq(w.FROZEN_MASK(), FROZEN_MASK);
    assertEq(w.BORROWABLE_MASK(), BORROWABLE_MASK);
    assertEq(w.LIQUIDATABLE_MASK(), LIQUIDATABLE_MASK);
    assertEq(w.RECEIVE_SHARES_ENABLED_MASK(), RECEIVE_SHARES_ENABLED_MASK);
  }

  function test_create_fuzz(
    bool paused,
    bool frozen,
    bool borrowable,
    bool liquidatable,
    bool receiveSharesEnabled
  ) public view {
    ReserveFlags flags = w.create({
      initPaused: paused,
      initFrozen: frozen,
      initBorrowable: borrowable,
      initLiquidatable: liquidatable,
      initReceiveSharesEnabled: receiveSharesEnabled
    });

    assertEq(w.paused(flags), paused);
    assertEq(w.frozen(flags), frozen);
    assertEq(w.borrowable(flags), borrowable);
    assertEq(w.liquidatable(flags), liquidatable);
    assertEq(w.receiveSharesEnabled(flags), receiveSharesEnabled);
  }

  function test_set_flags() public view {
    ReserveFlags flags;
    assertEq(w.paused(flags), false);
    assertEq(w.frozen(flags), false);
    assertEq(w.borrowable(flags), false);
    assertEq(w.liquidatable(flags), false);
    assertEq(w.receiveSharesEnabled(flags), false);

    flags = w.setPaused(flags, true);
    assertEq(w.paused(flags), true);
    assertEq(w.frozen(flags), false);
    assertEq(w.borrowable(flags), false);
    assertEq(w.liquidatable(flags), false);
    assertEq(w.receiveSharesEnabled(flags), false);

    flags = w.setFrozen(flags, true);
    assertEq(w.paused(flags), true);
    assertEq(w.frozen(flags), true);
    assertEq(w.borrowable(flags), false);
    assertEq(w.liquidatable(flags), false);
    assertEq(w.receiveSharesEnabled(flags), false);

    flags = w.setBorrowable(flags, true);
    assertEq(w.paused(flags), true);
    assertEq(w.frozen(flags), true);
    assertEq(w.borrowable(flags), true);
    assertEq(w.liquidatable(flags), false);
    assertEq(w.receiveSharesEnabled(flags), false);

    flags = w.setLiquidatable(flags, true);
    assertEq(w.paused(flags), true);
    assertEq(w.frozen(flags), true);
    assertEq(w.borrowable(flags), true);
    assertEq(w.liquidatable(flags), true);
    assertEq(w.receiveSharesEnabled(flags), false);

    flags = w.setReceiveSharesEnabled(flags, true);
    assertEq(w.paused(flags), true);
    assertEq(w.frozen(flags), true);
    assertEq(w.borrowable(flags), true);
    assertEq(w.liquidatable(flags), true);
    assertEq(w.receiveSharesEnabled(flags), true);

    flags = w.setFrozen(flags, false);
    assertEq(w.paused(flags), true);
    assertEq(w.frozen(flags), false);
    assertEq(w.borrowable(flags), true);
    assertEq(w.liquidatable(flags), true);
    assertEq(w.receiveSharesEnabled(flags), true);

    flags = w.setBorrowable(flags, false);
    assertEq(w.paused(flags), true);
    assertEq(w.frozen(flags), false);
    assertEq(w.borrowable(flags), false);
    assertEq(w.liquidatable(flags), true);
    assertEq(w.receiveSharesEnabled(flags), true);

    flags = w.setLiquidatable(flags, false);
    assertEq(w.paused(flags), true);
    assertEq(w.frozen(flags), false);
    assertEq(w.borrowable(flags), false);
    assertEq(w.liquidatable(flags), false);
    assertEq(w.receiveSharesEnabled(flags), true);

    flags = w.setReceiveSharesEnabled(flags, false);
    assertEq(w.paused(flags), true);
    assertEq(w.frozen(flags), false);
    assertEq(w.borrowable(flags), false);
    assertEq(w.liquidatable(flags), false);
    assertEq(w.receiveSharesEnabled(flags), false);

    flags = w.setPaused(flags, false);
    assertEq(w.paused(flags), false);
    assertEq(w.frozen(flags), false);
    assertEq(w.borrowable(flags), false);
    assertEq(w.liquidatable(flags), false);
    assertEq(w.receiveSharesEnabled(flags), false);
  }

  function test_setPaused_fuzz(uint8 rawFlags) public view {
    ReserveFlags flags = _sanitizeFlags(rawFlags);
    uint8 expectedRawFlags = ReserveFlags.unwrap(flags);

    expectedRawFlags = expectedRawFlags | PAUSED_MASK;

    flags = w.setPaused(flags, true);

    assertEq(w.paused(flags), true);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);

    expectedRawFlags = expectedRawFlags & ~PAUSED_MASK;

    flags = w.setPaused(flags, false);

    assertEq(w.paused(flags), false);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);
  }

  function test_setFrozen_fuzz(uint8 rawFlags) public view {
    ReserveFlags flags = _sanitizeFlags(rawFlags);
    uint8 expectedRawFlags = ReserveFlags.unwrap(flags);

    expectedRawFlags = expectedRawFlags | FROZEN_MASK;

    flags = w.setFrozen(flags, true);

    assertEq(w.frozen(flags), true);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);

    expectedRawFlags = expectedRawFlags & ~FROZEN_MASK;

    flags = w.setFrozen(flags, false);

    assertEq(w.frozen(flags), false);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);
  }

  function test_setBorrowable_fuzz(uint8 rawFlags) public view {
    ReserveFlags flags = _sanitizeFlags(rawFlags);
    uint8 expectedRawFlags = ReserveFlags.unwrap(flags);

    expectedRawFlags = expectedRawFlags | BORROWABLE_MASK;

    flags = w.setBorrowable(flags, true);

    assertEq(w.borrowable(flags), true);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);

    expectedRawFlags = expectedRawFlags & ~BORROWABLE_MASK;

    flags = w.setBorrowable(flags, false);

    assertEq(w.borrowable(flags), false);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);
  }

  function test_setLiquidatable_fuzz(uint8 rawFlags) public view {
    ReserveFlags flags = _sanitizeFlags(rawFlags);
    uint8 expectedRawFlags = ReserveFlags.unwrap(flags);

    expectedRawFlags = expectedRawFlags | LIQUIDATABLE_MASK;

    flags = w.setLiquidatable(flags, true);

    assertEq(w.liquidatable(flags), true);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);

    expectedRawFlags = expectedRawFlags & ~LIQUIDATABLE_MASK;

    flags = w.setLiquidatable(flags, false);

    assertEq(w.liquidatable(flags), false);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);
  }

  function test_setReceiveSharesEnabled_fuzz(uint8 rawFlags) public view {
    ReserveFlags flags = _sanitizeFlags(rawFlags);
    uint8 expectedRawFlags = ReserveFlags.unwrap(flags);

    expectedRawFlags = expectedRawFlags | RECEIVE_SHARES_ENABLED_MASK;

    flags = w.setReceiveSharesEnabled(flags, true);

    assertEq(w.receiveSharesEnabled(flags), true);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);

    expectedRawFlags = expectedRawFlags & ~RECEIVE_SHARES_ENABLED_MASK;

    flags = w.setReceiveSharesEnabled(flags, false);

    assertEq(w.receiveSharesEnabled(flags), false);
    assertEq(ReserveFlags.unwrap(flags), expectedRawFlags);
  }

  /// @dev Sanitizes the raw flags by masking out any irrelevant bits.
  function _sanitizeFlags(uint8 rawFlags) internal pure returns (ReserveFlags) {
    uint8 sanitizedFlags = rawFlags &
      (PAUSED_MASK |
        FROZEN_MASK |
        BORROWABLE_MASK |
        LIQUIDATABLE_MASK |
        RECEIVE_SHARES_ENABLED_MASK);
    return ReserveFlags.wrap(sanitizedFlags);
  }
}
