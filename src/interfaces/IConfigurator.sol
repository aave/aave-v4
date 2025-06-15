// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IConfigurator {
  function setAssetActive(address hub, uint256 assetId, bool active) external;

  function setAssetPaused(address hub, uint256 assetId, bool paused) external;

  function setAssetFrozen(address hub, uint256 assetId, bool frozen) external;

  function setLiquidityFee(address hub, uint256 assetId, uint256 liquidityFee) external;

  function setInterestRateStrategy(address hub, uint256 assetId, address irStrategy) external;
}
