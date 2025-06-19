// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20Metadata} from 'src/dependencies/openzeppelin/IERC20Metadata.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {IReserveInterestRateStrategy} from 'src/interfaces/IReserveInterestRateStrategy.sol';
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {IConfigurator} from 'src/interfaces/IConfigurator.sol';

contract Configurator is IConfigurator {
  function addAsset(
    address hub,
    address asset,
    address irStrategy
  ) external override returns (uint256) {
    // TODO: AccessControl
    return ILiquidityHub(hub).addAsset(asset, IERC20Metadata(asset).decimals(), irStrategy);
  }

  function addAsset(
    address hub,
    address asset,
    uint8 decimals,
    address irStrategy
  ) external override returns (uint256) {
    // TODO: AccessControl
    return ILiquidityHub(hub).addAsset(asset, decimals, irStrategy);
  }

  function setActive(address hub, uint256 assetId, bool active) external override {
    // TODO: AccessControl

    DataTypes.AssetConfig memory config = ILiquidityHub(hub).getAssetConfig(assetId);
    config.active = active;
    ILiquidityHub(hub).updateAssetConfig(assetId, config);
  }

  function setPaused(address hub, uint256 assetId, bool paused) external override {
    // TODO: AccessControl

    DataTypes.AssetConfig memory config = ILiquidityHub(hub).getAssetConfig(assetId);
    config.paused = paused;
    ILiquidityHub(hub).updateAssetConfig(assetId, config);
  }

  function setFrozen(address hub, uint256 assetId, bool frozen) external override {
    // TODO: AccessControl

    DataTypes.AssetConfig memory config = ILiquidityHub(hub).getAssetConfig(assetId);
    config.frozen = frozen;
    ILiquidityHub(hub).updateAssetConfig(assetId, config);
  }

  function setLiquidityFee(address hub, uint256 assetId, uint256 liquidityFee) external override {
    // TODO: AccessControl

    DataTypes.AssetConfig memory config = ILiquidityHub(hub).getAssetConfig(assetId);
    config.liquidityFee = liquidityFee;
    ILiquidityHub(hub).updateAssetConfig(assetId, config);
  }

  function setFeeReceiver(address hub, uint256 assetId, address feeReceiver) external override {
    // TODO: AccessControl

    DataTypes.AssetConfig memory config = ILiquidityHub(hub).getAssetConfig(assetId);
    _adjustFeeReceiverConfig(hub, assetId, config, feeReceiver);
    config.feeReceiver = feeReceiver;
    ILiquidityHub(hub).updateAssetConfig(assetId, config);
  }

  function setLiquidityFeeAndReceiver(
    address hub,
    uint256 assetId,
    uint256 liquidityFee,
    address feeReceiver
  ) external override {
    // TODO: AccessControl

    DataTypes.AssetConfig memory config = ILiquidityHub(hub).getAssetConfig(assetId);
    _adjustFeeReceiverConfig(hub, assetId, config, feeReceiver);
    config.liquidityFee = liquidityFee;
    config.feeReceiver = feeReceiver;
    ILiquidityHub(hub).updateAssetConfig(assetId, config);
  }

  function setInterestRateStrategy(
    address hub,
    uint256 assetId,
    address irStrategy
  ) external override {
    // TODO: AccessControl

    DataTypes.AssetConfig memory config = ILiquidityHub(hub).getAssetConfig(assetId);
    config.irStrategy = IReserveInterestRateStrategy(irStrategy);
    ILiquidityHub(hub).updateAssetConfig(assetId, config);
  }

  function _adjustFeeReceiverConfig(
    address hub,
    uint256 assetId,
    DataTypes.AssetConfig memory config,
    address newFeeReceiver
  ) internal {
    if (config.feeReceiver != newFeeReceiver) {
      if (config.feeReceiver != address(0)) {
        ILiquidityHub(hub).updateSpokeConfig(
          assetId,
          config.feeReceiver,
          DataTypes.SpokeConfig({supplyCap: 0, drawCap: 0})
        );
      }

      if (newFeeReceiver != address(0)) {
        DataTypes.SpokeData memory spokeData = ILiquidityHub(hub).getSpoke(assetId, newFeeReceiver);
        if (spokeData.lastUpdateTimestamp == 0) {
          ILiquidityHub(hub).addSpoke(
            assetId,
            newFeeReceiver,
            DataTypes.SpokeConfig({supplyCap: type(uint256).max, drawCap: type(uint256).max})
          );
        } else {
          ILiquidityHub(hub).updateSpokeConfig(
            assetId,
            newFeeReceiver,
            DataTypes.SpokeConfig({supplyCap: type(uint256).max, drawCap: type(uint256).max})
          );
        }
      }
    }
  }
}
