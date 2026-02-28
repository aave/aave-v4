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

  function test_decimals() public view {
    assertEq(unitPriceFeed.decimals(), DECIMALS);
  }

  function test_fuzz_latestAnswer_blockTimestamp(uint80 blockTimestamp) public {
    skip(blockTimestamp);
    assertEq(unitPriceFeed.latestAnswer(), int256(10 ** DECIMALS));
  }

  function test_fuzz_latestAnswer_differentDecimals(uint8 decimals) public {
    decimals = bound(decimals, 0, 18).toUint8();
    unitPriceFeed = new UnitPriceFeed(decimals);
    assertEq(unitPriceFeed.decimals(), decimals);
    assertEq(unitPriceFeed.latestAnswer(), int256(10 ** decimals));
  }
}
