// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBorrowModule {
  function calculateInterestRates() external pure returns (uint256);
  function getInterestRate() external view returns (uint256);

  function drawLiquidity(uint256 assetId, uint256 amount) external;
  function restoreLiquidity(uint256 assetId, uint256 amount) external;
}
