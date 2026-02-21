// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Address} from 'src/dependencies/openzeppelin/Address.sol';

contract MockReentrantCaller {
  using Address for address;

  address public immutable TARGET;
  bytes4 public immutable TARGET_SELECTOR;

  constructor(address target, bytes4 targetSelector) {
    TARGET = target;
    TARGET_SELECTOR = targetSelector;
  }

  fallback() external {
    TARGET.functionCall(bytes.concat(TARGET_SELECTOR, new bytes(1000)));
  }
}
