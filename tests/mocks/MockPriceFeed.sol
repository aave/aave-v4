// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IPriceFeed} from 'src/spoke/interfaces/IPriceFeed.sol';

contract MockPriceFeed is IPriceFeed {
  uint8 public immutable override decimals;

  string public override description;

  int256 private _price;

  error OperationNotSupported();

  constructor(uint8 decimals_, string memory description_, uint256 price_) {
    decimals = decimals_;
    description = description_;
    _price = int256(price_);
  }

  function setPrice(uint256 price) external {
    _price = int256(price);
  }

  function latestAnswer() external view override returns (int256) {
    return _price;
  }
}
