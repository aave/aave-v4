// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {PercentageMathExtended} from 'src/libraries/math/PercentageMathExtended.sol';

contract PercentageMathExtendedWrapper {
  function PERCENTAGE_FACTOR() public pure returns (uint256) {
    return PercentageMathExtended.PERCENTAGE_FACTOR;
  }

  function percentMulDown(uint256 value, uint256 percentage) public pure returns (uint256) {
    return PercentageMathExtended.percentMulDown(value, percentage);
  }

  function percentMulUp(uint256 value, uint256 percentage) public pure returns (uint256) {
    return PercentageMathExtended.percentMulUp(value, percentage);
  }

  function percentDivDown(uint256 value, uint256 percentage) public pure returns (uint256) {
    return PercentageMathExtended.percentDivDown(value, percentage);
  }

  function percentDivUp(uint256 value, uint256 percentage) public pure returns (uint256) {
    return PercentageMathExtended.percentDivUp(value, percentage);
  }

  function fromBps(uint256 bps) public pure returns (uint256) {
    return PercentageMathExtended.fromBps(bps);
  }
}
