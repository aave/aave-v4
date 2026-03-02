// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IPriceFeed} from 'src/spoke/interfaces/IPriceFeed.sol';

contract MockPriceFeed is IPriceFeed {
  uint8 public immutable decimals;

  string public description;

  int256 private immutable _price;

  error OperationNotSupported();

  constructor(uint8 decimals_, int256 price_) {
    decimals = decimals_;
    _price = price_;
    description = 'Mock Price Feed';
  }

  function latestAnswer() external view override returns (int256) {
    return _price;
  }
}
