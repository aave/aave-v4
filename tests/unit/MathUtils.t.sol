// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';

/// forge-config: default.allow_internal_expect_revert = true
contract MathUtilsTest is Test {
  int256 internal constant INT256_MAX = type(int256).max;

  function test_constants() public pure {
    assertEq(MathUtils.SECONDS_PER_YEAR, 365 days);
  }

  function test_calculateLinearInterest() public {
    uint40 previousTimestamp = uint40(vm.getBlockTimestamp());
    skip(365 days * 7);
    assertEq(MathUtils.calculateLinearInterest(0.08e27, previousTimestamp), 1.56e27);
  }

  function test_fuzz_calculateLinearInterest(
    uint256 rate,
    uint40 previousTimestamp,
    uint40 skipTime
  ) public {
    rate = bound(rate, 1, 100e27);
    vm.warp(previousTimestamp);
    skip(skipTime);
    assertEq(
      MathUtils.calculateLinearInterest(rate, previousTimestamp),
      1e27 + (rate * skipTime) / 365 days
    );
  }

  function test_min(uint256 a, uint256 b) public pure {
    assertEq(MathUtils.min(a, b), a < b ? a : b);
  }

  function test_add_positive_operand(uint256 a, int256 b) public {
    vm.assume(b >= 0);
    if (a > UINT256_MAX - uint256(b)) {
      vm.expectRevert(stdError.arithmeticError);
      MathUtils.add(a, b);
    } else {
      uint256 expected = a + uint256(b);
      assertEq(MathUtils.add(a, b), expected);
    }
  }

  function test_add_negative_operand(uint256 a, int256 b) public {
    b = bound(b, type(int256).min + 1, 0); // -b doesn't overflow uint256
    if (a < uint256(-b)) {
      vm.expectRevert(stdError.arithmeticError);
      MathUtils.add(a, b);
    } else {
      uint256 expected = a - uint256(-b);
      assertEq(MathUtils.add(a, b), expected);
    }
  }

  function test_add_edge_cases() public {
    assertEq(MathUtils.add(100, 0), 100);
    assertEq(MathUtils.add(0, 50), 50);

    vm.expectRevert(stdError.arithmeticError);
    MathUtils.add(0, -50);

    assertEq(MathUtils.add(0, INT256_MAX), uint256(INT256_MAX));

    vm.expectRevert(stdError.arithmeticError);
    MathUtils.add(0, type(int256).min);

    assertEq(MathUtils.add(uint256(INT256_MAX), type(int256).min + 1), 0);

    vm.expectRevert(stdError.arithmeticError);
    MathUtils.add(UINT256_MAX, 1);
  }

  function test_signedSub(uint256 a, uint256 b) public pure {
    a = bound(a, 0, uint256(INT256_MAX));
    b = bound(b, 0, uint256(INT256_MAX));

    int256 result = MathUtils.signedSub(a, b);
    assertEq(result, int256(a) - int256(b));

    assertTrue(result >= type(int256).min);
    assertTrue(result <= INT256_MAX);
  }

  function test_uncheckedSub(uint256 a, uint256 b) public pure {
    uint256 result = a >= b ? a - b : UINT256_MAX - b + a + 1;
    assertEq(MathUtils.uncheckedSub(a, b), result);
  }
}
