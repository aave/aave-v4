// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {SpokeUtils} from '../../src/spoke/libraries/SpokeUtils.sol';

contract SpokeUtilsHarness {
  function toValue(
    uint256 amount,
    uint256 decimals,
    uint256 price
  ) external pure returns (uint256) {
    return SpokeUtils.toValue(amount, decimals, price);
  }
}
