// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WadRayMath} from './WadRayMath.sol';
import {IBorrowModule} from './IBorrowModule.sol';

contract BorrowModule is IBorrowModule {
  function calculateInterestRates() external pure returns (uint256, uint256) {
    // supplyRate, borrowRate
    return (0, 0);
  }
}
