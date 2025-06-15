// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';

interface IConfigurator {
  function HUB() external view returns (ILiquidityHub);

  function setAssetActive(uint256 assetId, bool active) external;

  function setAssetPaused(uint256 assetId, bool paused) external;

  function setAssetFrozen(uint256 assetId, bool frozen) external;

  function setReserveFactor(uint256 assetId, uint256 reserveFactor) external;

  function setInterestRateStrategy(uint256 assetId, address irStrategy) external;
}
