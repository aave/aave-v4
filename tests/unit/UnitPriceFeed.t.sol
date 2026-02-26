// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

contract UnitPriceFeedTest is Base {
  using SafeCast for uint256;

  UnitPriceFeed public unitPriceFeed;

  uint8 private constant DECIMALS = 8;

  function setUp() public override {
    super.setUp();
    unitPriceFeed = new UnitPriceFeed(DECIMALS);
  }

  function test_constructor_revertsWith_Uint8Overflow() public {
    uint8 invalidDecimals = 77;
    vm.expectRevert(
      abi.encodeWithSelector(SafeCast.SafeCastOverflowedUintToInt.selector, 10 ** invalidDecimals)
    );
    new UnitPriceFeed(invalidDecimals);
  }

  function test_latestAnswer() public view {
    assertEq(unitPriceFeed.latestAnswer(), (10 ** DECIMALS).toInt256());
  }

  function test_latestTimestamp() public {
    uint80 skipTime = vm.randomUint(80).toUint80();
    skip(skipTime);
    assertEq(unitPriceFeed.latestTimestamp(), block.timestamp);
  }

  function test_latestRound() public {
    uint80 skipTime = vm.randomUint(80).toUint80();
    skip(skipTime);
    assertEq(unitPriceFeed.latestRound(), block.timestamp);
  }

  function test_getAnswer() public {
    uint80 skipTime = vm.randomUint(80).toUint80();
    skip(skipTime);
    uint256 roundId = vm.randomUint(0, skipTime);
    assertEq(unitPriceFeed.getAnswer(roundId), (10 ** DECIMALS).toInt256());
  }

  function test_getAnswer_futureRound() public {
    uint80 skipTime = vm.randomUint(0, type(uint80).max - 1).toUint80();
    skip(skipTime);
    uint256 roundId = vm.randomUint(skipTime + 1, type(uint80).max);
    assertEq(unitPriceFeed.getAnswer(roundId), 0);
  }

  function test_getTimestamp() public {
    uint80 skipTime = vm.randomUint(80).toUint80();
    skip(skipTime);
    uint256 roundId = vm.randomUint(0, skipTime);
    assertEq(unitPriceFeed.getTimestamp(roundId), roundId);
  }

  function test_getTimestamp_futureRound() public {
    uint80 skipTime = vm.randomUint(0, type(uint80).max - 1).toUint80();
    skip(skipTime);
    uint256 roundId = vm.randomUint(skipTime + 1, type(uint80).max);
    assertEq(unitPriceFeed.getTimestamp(roundId), 0);
  }
}
