// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBorrowModule {
  function calculateInterestRates() external pure returns (uint256);
}
