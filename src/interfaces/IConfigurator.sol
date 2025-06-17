// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IConfigurator {
  function setActive(address hub, uint256 assetId, bool active) external;

  function setPaused(address hub, uint256 assetId, bool paused) external;

  function setFrozen(address hub, uint256 assetId, bool frozen) external;

  function setLiquidityFee(address hub, uint256 assetId, uint256 liquidityFee) external;

  function setFeeReceiver(address hub, uint256 assetId, address feeReceiver) external;

  function setLiquidityFeeAndReceiver(
    address hub,
    uint256 assetId,
    uint256 liquidityFee,
    address feeReceiver
  ) external;

  function setInterestRateStrategy(address hub, uint256 assetId, address irStrategy) external;
}
