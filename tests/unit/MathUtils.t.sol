// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

/// forge-config: default.allow_internal_expect_revert = true
contract MathUtilsTest is Base {
  using SafeCast for uint256;

  int256 internal constant INT256_MAX = type(int256).max;

  function test_constants() public pure {
    assertEq(MathUtils.SECONDS_PER_YEAR, 365 days);
  }

  function test_calculateLinearInterest() public {
    uint32 previousTimestamp = uint32(vm.getBlockTimestamp());
    skip(365 days * 7);
    assertEq(MathUtils.calculateLinearInterest(0.08e27, previousTimestamp), 1.56e27);
  }

  function test_fuzz_calculateLinearInterest(
    uint96 rate,
    uint32 previousTimestamp,
    uint256 skipTime
  ) public {
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME);
    vm.warp(previousTimestamp);
    skip(skipTime);
    assertEq(
      MathUtils.calculateLinearInterest(rate, previousTimestamp),
      1e27 + (uint256(rate) * uint256(skipTime)) / 365 days
    );
  }

  function test_calculateLinearInterest_edge_cases() public {
    test_fuzz_calculateLinearInterest(type(uint96).max, type(uint32).max, 0);
    test_fuzz_calculateLinearInterest(type(uint96).max, type(uint32).max, 1);
    test_fuzz_calculateLinearInterest(type(uint96).max, type(uint32).max, MAX_SKIP_TIME);
    test_fuzz_calculateLinearInterest(type(uint96).max, type(uint32).max - 1, MAX_SKIP_TIME);
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

  function test_uncheckedAdd(uint256 a, uint256 b) public pure {
    uint256 result = MathUtils.uncheckedAdd(a, b);
    assertEq(result, b <= UINT256_MAX - a ? a + b : a - (UINT256_MAX - b) - 1);
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

  function test_uncheckedExp(uint256 a, uint256 b) public pure {
    uint256 result = MathUtils.uncheckedExp(a, b);

    uint256 expectedRes = 1;
    uint256 aPow = a;
    for (uint256 p = b; p != 0; p >>= 1) {
      if ((p & 1) == 1) {
        unchecked {
          expectedRes = expectedRes * aPow;
        }
      }

      unchecked {
        aPow = aPow * aPow;
      }
    }

    assertEq(result, expectedRes);
  }

  function test_mulDivDown_WithRemainder() external pure {
    assertEq(MathUtils.mulDivDown(2, 13, 3), 8); // 26 / 3 = 8.666 -> floor -> 8
  }

  function test_mulDivDown_NoRemainder() external pure {
    assertEq(MathUtils.mulDivDown(12, 6, 4), 18); // 72 / 4 = 18, no floor
  }

  function test_mulDivDown_ZeroAOrB() external pure {
    assertEq(MathUtils.mulDivDown(0, 10, 5), 0);
    assertEq(MathUtils.mulDivDown(10, 0, 5), 0);
  }

  function test_mulDivDown_RevertOnDivByZero() external {
    vm.expectRevert();
    MathUtils.mulDivDown(10, 10, 0);
  }

  function test_mulDivDown_RevertOnOverflow() external {
    uint256 max = type(uint256).max;
    vm.expectRevert();
    MathUtils.mulDivDown(max, 2, 1); // max * 2 will overflow
  }

  function test_fuzz_mulDivDown(uint256 a, uint256 b, uint256 c) external {
    uint256 result;
    bool safetyCheck;
    unchecked {
      result = a * b;
      safetyCheck = b == 0 || result / b == a;
    }

    if (!safetyCheck || c == 0) {
      vm.expectRevert();
      MathUtils.mulDivDown(a, b, c);
    } else {
      assertEq(MathUtils.mulDivDown(a, b, c), result / c);
    }
  }

  function test_mulDivUp_WithRemainder() external pure {
    assertEq(MathUtils.mulDivUp(5, 5, 3), 9); // 25 / 3 = 8.333 -> ceil -> 9
  }

  function test_mulDivUp_NoRemainder() external pure {
    assertEq(MathUtils.mulDivUp(12, 6, 4), 18); // 72 / 4 = 18, no ceil
  }

  function test_mulDivUp_ZeroAOrB() external pure {
    assertEq(MathUtils.mulDivUp(0, 10, 5), 0);
    assertEq(MathUtils.mulDivUp(10, 0, 5), 0);
  }

  function test_mulDivUp_RevertOnDivByZero() external {
    vm.expectRevert();
    MathUtils.mulDivUp(10, 10, 0);
  }

  function test_mulDivUp_RevertOnOverflow() external {
    uint256 max = type(uint256).max;
    vm.expectRevert();
    MathUtils.mulDivUp(max, 2, 1); // max * 2 will overflow
  }

  function test_fuzz_mulDivUp(uint256 a, uint256 b, uint256 c) external {
    uint256 result;
    bool safetyCheck;
    unchecked {
      result = a * b;
      safetyCheck = b == 0 || result / b == a;
    }
    if (!safetyCheck || c == 0) {
      vm.expectRevert();
      MathUtils.mulDivUp(a, b, c);
    } else {
      assertEq(MathUtils.mulDivUp(a, b, c), result / c + (result % c > 0 ? 1 : 0));
    }
  }
}
