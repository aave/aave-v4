// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

contract UnitPriceFeedTest is Base {
  using SafeCast for uint256;

  UnitPriceFeed public unitPriceFeed;

  uint8 private constant DECIMALS = 8;
  string private constant _description = 'Unit Price Feed (8 decimals)';

  function setUp() public override {
    super.setUp();
    unitPriceFeed = new UnitPriceFeed(DECIMALS, _description);
  }

  function test_constructor_revertsWith_Uint8Overflow() public {
    uint8 invalidDecimals = 77;
    vm.expectRevert(
      abi.encodeWithSelector(SafeCast.SafeCastOverflowedUintToInt.selector, 10 ** invalidDecimals)
    );
    new UnitPriceFeed(invalidDecimals, _description);
  }

  function testDECIMALS() public view {
    assertEq(unitPriceFeed.decimals(), DECIMALS);
  }

  function test_description() public view {
    assertEq(unitPriceFeed.description(), _description);
  }

  function test_version() public view {
    assertEq(unitPriceFeed.version(), 1);
  }

  function test_getRoundData() public {
    uint80 skipTime = vm.randomUint(80).toUint80();
    skip(skipTime);
    uint80 _roundId = vm.randomUint(0, skipTime).toUint80();
    (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    ) = unitPriceFeed.getRoundData(_roundId);
    assertEq(roundId, _roundId);
    assertEq(answer, (10 ** DECIMALS).toInt256());
    assertEq(startedAt, roundId);
    assertEq(updatedAt, roundId);
    assertEq(answeredInRound, roundId);
  }

  function test_getRoundData_futureRound() public {
    uint80 skipTime = vm.randomUint(0, type(uint80).max - 1).toUint80();
    skip(skipTime);
    uint80 _roundId = vm.randomUint(skipTime + 1, type(uint80).max).toUint80();
    (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    ) = unitPriceFeed.getRoundData(_roundId);
    assertEq(roundId, 0);
    assertEq(answer, 0);
    assertEq(startedAt, 0);
    assertEq(updatedAt, 0);
    assertEq(answeredInRound, 0);
  }

  function test_fuzz_latestRoundData(uint80 blockTimestamp) public {
    vm.warp(blockTimestamp);
    (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    ) = unitPriceFeed.latestRoundData();
    assertEq(roundId, blockTimestamp);
    assertEq(answer, (10 ** DECIMALS).toInt256());
    assertEq(startedAt, blockTimestamp);
    assertEq(updatedAt, blockTimestamp);
    assertEq(answeredInRound, blockTimestamp);
  }

  function test_fuzz_latestRoundData_DifferentDecimals(uint8 decimals) public {
    decimals = bound(decimals, 0, 18).toUint8();
    unitPriceFeed = new UnitPriceFeed(decimals, _description);
    (, int256 answer, , , ) = unitPriceFeed.latestRoundData();
    assertEq(answer, int256(10 ** decimals));
  }

  function test_latestAnswer() public view {
    assertEq(unitPriceFeed.latestAnswer(), (10 ** DECIMALS).toInt256());
  }

  function test_fuzz_latestAnswer_blockTimestamp(uint80 blockTimestamp) public {
    skip(blockTimestamp);
    assertEq(unitPriceFeed.latestAnswer(), int256(10 ** DECIMALS));
  }

  function test_fuzz_latestAnswer_differentDecimals(uint8 decimals) public {
    decimals = bound(decimals, 0, 18).toUint8();
    unitPriceFeed = new UnitPriceFeed(decimals, _description);
    assertEq(unitPriceFeed.latestAnswer(), int256(10 ** decimals));
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
