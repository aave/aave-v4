// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {IConfigurator} from 'src/interfaces/IConfigurator.sol';

contract Configurator is IConfigurator {
  function setAssetActive(address hub, uint256 assetId, bool active) external override {
    // TODO: AccessControl

    DataTypes.AssetConfig memory config = ILiquidityHub(hub).getAssetConfig(assetId);
    ILiquidityHub(hub).updateAssetFlags({
      assetId: assetId,
      active: active,
      paused: config.paused,
      frozen: config.frozen
    });
  }

  function setAssetPaused(address hub, uint256 assetId, bool paused) external override {
    // TODO: AccessControl

    DataTypes.AssetConfig memory config = ILiquidityHub(hub).getAssetConfig(assetId);
    ILiquidityHub(hub).updateAssetFlags({
      assetId: assetId,
      active: config.active,
      paused: paused,
      frozen: config.frozen
    });
  }

  function setAssetFrozen(address hub, uint256 assetId, bool frozen) external override {
    // TODO: AccessControl

    DataTypes.AssetConfig memory config = ILiquidityHub(hub).getAssetConfig(assetId);
    ILiquidityHub(hub).updateAssetFlags({
      assetId: assetId,
      active: config.active,
      paused: config.paused,
      frozen: frozen
    });
  }

  function setReserveFactor(address hub, uint256 assetId, uint256 reserveFactor) external override {
    // TODO: AccessControl

    ILiquidityHub(hub).updateReserveFactor({assetId: assetId, reserveFactor: reserveFactor});
  }

  function setInterestRateStrategy(
    address hub,
    uint256 assetId,
    address irStrategy
  ) external override {
    // TODO: AccessControl

    ILiquidityHub(hub).updateInterestRateStrategy({assetId: assetId, irStrategy: irStrategy});
  }
}
