// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MathUtils} from 'src/libraries/math/MathUtils.sol';

contract MathUtilsWrapper {
  function SECONDS_PER_YEAR() external pure returns (uint256) {
    return MathUtils.SECONDS_PER_YEAR;
  }

  function calculateLinearInterest(uint96 rate, uint40 lastUpdateTimestamp) external view returns (uint256) {
    return MathUtils.calculateLinearInterest(rate, lastUpdateTimestamp);
  }

  function min(uint256 a, uint256 b) external pure returns (uint256) { return MathUtils.min(a, b); }
  function zeroFloorSub(uint256 a, uint256 b) external pure returns (uint256) { return MathUtils.zeroFloorSub(a, b); }
  function add(uint256 a, int256 b) external pure returns (uint256) { return MathUtils.add(a, b); }
  function uncheckedAdd(uint256 a, uint256 b) external pure returns (uint256) { return MathUtils.uncheckedAdd(a, b); }
  function signedSub(uint256 a, uint256 b) external pure returns (int256) { return MathUtils.signedSub(a, b); }
  function uncheckedSub(uint256 a, uint256 b) external pure returns (uint256) { return MathUtils.uncheckedSub(a, b); }
  function uncheckedExp(uint256 a, uint256 b) external pure returns (uint256) { return MathUtils.uncheckedExp(a, b); }
  function divUp(uint256 a, uint256 b) external pure returns (uint256) { return MathUtils.divUp(a, b); }
  function mulDivDown(uint256 a, uint256 b, uint256 c) external pure returns (uint256) { return MathUtils.mulDivDown(a, b, c); }
  function mulDivUp(uint256 a, uint256 b, uint256 c) external pure returns (uint256) { return MathUtils.mulDivUp(a, b, c); }
}
