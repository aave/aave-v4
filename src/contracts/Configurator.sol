// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {DataTypes} from 'src/libraries/types/DataTypes.sol';

import {IConfigurator, ILiquidityHub} from 'src/interfaces/IConfigurator.sol';

contract Configurator is IConfigurator {
  ILiquidityHub public immutable override HUB;

  constructor(address hubAddress) {
    HUB = ILiquidityHub(hubAddress);
  }

  function setAssetActive(uint256 assetId, bool active) external override {
    // TODO: AccessControl

    DataTypes.AssetConfig memory config = HUB.getAssetConfig(assetId);
    HUB.updateAssetFlags({
      assetId: assetId,
      active: active,
      paused: config.paused,
      frozen: config.frozen
    });
  }

  function setAssetPaused(uint256 assetId, bool paused) external override {
    // TODO: AccessControl

    DataTypes.AssetConfig memory config = HUB.getAssetConfig(assetId);
    HUB.updateAssetFlags({
      assetId: assetId,
      active: config.active,
      paused: paused,
      frozen: config.frozen
    });
  }

  function setAssetFrozen(uint256 assetId, bool frozen) external override {
    // TODO: AccessControl

    DataTypes.AssetConfig memory config = HUB.getAssetConfig(assetId);
    HUB.updateAssetFlags({
      assetId: assetId,
      active: config.active,
      paused: config.paused,
      frozen: frozen
    });
  }

  function setReserveFactor(uint256 assetId, uint256 reserveFactor) external override {
    // TODO: AccessControl

    HUB.updateReserveFactor({assetId: assetId, reserveFactor: reserveFactor});
  }

  function setInterestRateStrategy(uint256 assetId, address irStrategy) external override {
    // TODO: AccessControl

    HUB.updateInterestRateStrategy({assetId: assetId, irStrategy: irStrategy});
  }
}
