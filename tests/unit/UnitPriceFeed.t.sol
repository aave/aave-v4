// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {UnitPriceFeed} from 'src/misc/UnitPriceFeed.sol';
import 'tests/Base.t.sol';

contract UnitPriceFeedTest is Base {
  UnitPriceFeed public unitPriceFeed;

  uint8 private constant _decimals = 8;
  string private constant _description = 'Unit Price Feed (8 decimals)';

  function setUp() public override {
    super.setUp();
    unitPriceFeed = new UnitPriceFeed(_decimals, _description);
  }

  function test_decimals() public view {
    assertEq(unitPriceFeed.decimals(), _decimals);
  }

  function test_description() public view {
    assertEq(unitPriceFeed.description(), _description);
  }

  function test_version() public view {
    assertEq(unitPriceFeed.version(), 1);
  }

  function test_getRoundData_revertsWith_OperationNotSupported() public {
    vm.expectRevert(UnitPriceFeed.OperationNotSupported.selector);
    unitPriceFeed.getRoundData(0);
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
    assertEq(answer, int256(10 ** _decimals));
    assertEq(startedAt, blockTimestamp);
    assertEq(updatedAt, blockTimestamp);
    assertEq(answeredInRound, blockTimestamp);
  }

  function test_fuzz_latestRoundData_DifferentDecimals(uint8 decimals) public {
    decimals = uint8(bound(decimals, 0, 18));
    unitPriceFeed = new UnitPriceFeed(decimals, _description);
    (, int256 answer, , , ) = unitPriceFeed.latestRoundData();
    assertEq(answer, int256(10 ** decimals));
  }
}
