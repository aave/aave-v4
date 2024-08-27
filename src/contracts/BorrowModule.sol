// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WadRayMath} from './WadRayMath.sol';
import {IBorrowModule} from './IBorrowModule.sol';

contract BorrowModule is IBorrowModule {
  using WadRayMath for uint256;

  function calculateInterestRates() external pure returns (uint256) {
    // borrowRate
    return 0;
  }
}
