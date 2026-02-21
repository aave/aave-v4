// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from 'src/dependencies/chainlink/AggregatorV3Interface.sol';

contract MockPriceFeed is AggregatorV3Interface {
  uint8 public immutable override decimals;
  string public override description;

  int256 private immutable _price;

  error OperationNotSupported();

  constructor(uint8 decimals_, string memory description_, uint256 price_) {
    decimals = decimals_;
    description = description_;
    _price = int256(price_);
  }

  function version() external pure override returns (uint256) {
    return 1;
  }

  function getRoundData(
    uint80
  ) external pure override returns (uint80, int256, uint256, uint256, uint80) {
    revert OperationNotSupported();
  }

  function latestRoundData()
    external
    view
    virtual
    override
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    roundId = uint80(block.timestamp);
    answer = _price;
    startedAt = block.timestamp;
    updatedAt = block.timestamp;
    answeredInRound = roundId;
  }
}
