// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBorrowModule {
  function calculateInterestRates() external pure returns (uint256);

  function onBorrow(
    uint256 assetId,
    address user,
    uint256 userRiskPremium,
    uint256 amount
  ) external;

  function drawLiquidity(uint256 assetId, uint256 amount) external;
  function restoreLiquidity(uint256 assetId, uint256 amount) external;
}
