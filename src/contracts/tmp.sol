// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

library DataTypes {
  struct AssetConfig {
    uint256 decimals;
    bool active;
    address irStrategy;
  }
}

interface temp {
  struct Asset {
    uint256 id;
    uint256 suppliedShares;
    uint256 availableLiquidity;
    uint256 baseDebt;
    uint256 outstandingPremium;
    uint256 baseBorrowIndex;
    uint256 baseBorrowRate;
    uint256 riskPremiumRad;
    uint256 lastUpdateTimestamp;
    DataTypes.AssetConfig config;
  }

  function accrueInterest(Asset memory asset, uint256 nextBaseBorrowIndex) external;
  function getInterestRate(Asset memory asset) external view returns (uint256);
  function getTotalAssets(Asset memory asset) external view returns (uint256);
  function previewNextBorrowIndex(Asset memory asset) external view returns (uint256);
  function updateBorrowRate(
    Asset memory asset,
    uint256 liquidityAdded,
    uint256 liquidityTaken
  ) external;
}
