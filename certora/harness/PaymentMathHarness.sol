// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Math} from 'src/dependencies/openzeppelin/Math.sol';

contract PaymentMathHarness {
  function mulDiv(uint256 x, uint256 y, uint256 denominator) external pure returns (uint256) {
    return Math.mulDiv(x, y, denominator);
  }

  function mulDivUp(uint256 x, uint256 y, uint256 denominator) external pure returns (uint256) {
    return Math.mulDiv(x, y, denominator, Math.Rounding.Ceil);
  }
}
