// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {MathUtils} from 'src/libraries/math/MathUtils.sol';

contract MathUtilsWrapper {
  function RAY() public pure returns (uint256) {
    return MathUtils.RAY;
  }

  function SECONDS_PER_YEAR() public pure returns (uint256) {
    return MathUtils.SECONDS_PER_YEAR;
  }

  function calculateLinearInterest(
    uint96 rate,
    uint32 lastUpdateTimestamp
  ) public view returns (uint256) {
    return MathUtils.calculateLinearInterest(rate, lastUpdateTimestamp);
  }

  function min(uint256 a, uint256 b) public pure returns (uint256) {
    return MathUtils.min(a, b);
  }

  function add(uint256 a, int256 b) public pure returns (uint256) {
    return MathUtils.add(a, b);
  }

  function uncheckedAdd(uint256 a, uint256 b) public pure returns (uint256) {
    return MathUtils.uncheckedAdd(a, b);
  }

  function signedSub(uint256 a, uint256 b) public pure returns (int256) {
    return MathUtils.signedSub(a, b);
  }

  function uncheckedSub(uint256 a, uint256 b) public pure returns (uint256) {
    return MathUtils.uncheckedSub(a, b);
  }

  function uncheckedExp(uint256 a, uint256 b) public pure returns (uint256) {
    return MathUtils.uncheckedExp(a, b);
  }

  function mulDivDown(uint256 a, uint256 b, uint256 c) public pure returns (uint256) {
    return MathUtils.mulDivDown(a, b, c);
  }

  function mulDivUp(uint256 a, uint256 b, uint256 c) public pure returns (uint256) {
    return MathUtils.mulDivUp(a, b, c);
  }
}
