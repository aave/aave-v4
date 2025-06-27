// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20Metadata} from 'src/dependencies/openzeppelin/IERC20Metadata.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {IConfigurator} from 'src/interfaces/IConfigurator.sol';

contract Configurator is IConfigurator {
  /// @inheritdoc IConfigurator
  function addSpokes(
    address hub,
    address spoke,
    uint256[] calldata assetIds,
    DataTypes.SpokeConfig[] calldata configs
  ) external {
    // TODO: AccessControl

    require(assetIds.length == configs.length, MismatchedConfigs());
    for (uint256 i; i < assetIds.length; i++) {
      ILiquidityHub(hub).addSpoke(assetIds[i], spoke, configs[i]);
    }
  }

  /// @inheritdoc IConfigurator
  function addAsset(
    address hub,
    address asset,
    address irStrategy
  ) external override returns (uint256) {
    // TODO: AccessControl
    return ILiquidityHub(hub).addAsset(asset, IERC20Metadata(asset).decimals(), irStrategy);
  }

  /// @inheritdoc IConfigurator
  function addAsset(
    address hub,
    address asset,
    uint8 decimals,
    address irStrategy
  ) external override returns (uint256) {
    // TODO: AccessControl
    return ILiquidityHub(hub).addAsset(asset, decimals, irStrategy);
  }

  /// @inheritdoc IConfigurator
  function updateActive(address hub, uint256 assetId, bool active) external override {
    // TODO: AccessControl

    DataTypes.AssetConfig memory config = _getAssetConfig(hub, assetId);
    config.active = active;
    ILiquidityHub(hub).updateAssetConfig(assetId, config);
  }

  /// @inheritdoc IConfigurator
  function updatePaused(address hub, uint256 assetId, bool paused) external override {
    // TODO: AccessControl

    DataTypes.AssetConfig memory config = _getAssetConfig(hub, assetId);
    config.paused = paused;
    ILiquidityHub(hub).updateAssetConfig(assetId, config);
  }

  /// @inheritdoc IConfigurator
  function updateFrozen(address hub, uint256 assetId, bool frozen) external override {
    // TODO: AccessControl

    DataTypes.AssetConfig memory config = _getAssetConfig(hub, assetId);
    config.frozen = frozen;
    ILiquidityHub(hub).updateAssetConfig(assetId, config);
  }

  /// @inheritdoc IConfigurator
  function updateLiquidityFee(
    address hub,
    uint256 assetId,
    uint256 liquidityFee
  ) external override {
    // TODO: AccessControl

    DataTypes.AssetConfig memory config = _getAssetConfig(hub, assetId);
    config.liquidityFee = liquidityFee;
    ILiquidityHub(hub).updateAssetConfig(assetId, config);
  }

  /// @inheritdoc IConfigurator
  function updateFeeReceiver(address hub, uint256 assetId, address feeReceiver) external override {
    // TODO: AccessControl

    DataTypes.AssetConfig memory config = _getAssetConfig(hub, assetId);
    _adjustFeeReceiverConfig(hub, assetId, config, feeReceiver);
    config.feeReceiver = feeReceiver;
    ILiquidityHub(hub).updateAssetConfig(assetId, config);
  }

  /// @inheritdoc IConfigurator
  function updateFeeConfig(
    address hub,
    uint256 assetId,
    uint256 liquidityFee,
    address feeReceiver
  ) external override {
    // TODO: AccessControl

    DataTypes.AssetConfig memory config = _getAssetConfig(hub, assetId);
    _adjustFeeReceiverConfig(hub, assetId, config, feeReceiver);
    config.liquidityFee = liquidityFee;
    config.feeReceiver = feeReceiver;
    ILiquidityHub(hub).updateAssetConfig(assetId, config);
  }

  /// @inheritdoc IConfigurator
  function updateInterestRateStrategy(
    address hub,
    uint256 assetId,
    address irStrategy
  ) external override {
    // TODO: AccessControl

    DataTypes.AssetConfig memory config = _getAssetConfig(hub, assetId);
    config.irStrategy = irStrategy;
    ILiquidityHub(hub).updateAssetConfig(assetId, config);
  }

  function _getAssetConfig(
    address hub,
    uint256 assetId
  ) internal view returns (DataTypes.AssetConfig memory) {
    return ILiquidityHub(hub).getAssetConfig(assetId);
  }

  function _adjustFeeReceiverConfig(
    address hubAddress,
    uint256 assetId,
    DataTypes.AssetConfig memory config,
    address newFeeReceiver
  ) internal {
    if (config.feeReceiver == newFeeReceiver) {
      return;
    }

    ILiquidityHub hub = ILiquidityHub(hubAddress);

    if (config.feeReceiver != address(0)) {
      hub.updateSpokeConfig(
        assetId,
        config.feeReceiver,
        DataTypes.SpokeConfig({supplyCap: 0, drawCap: 0})
      );
    }

    if (newFeeReceiver != address(0)) {
      DataTypes.SpokeData memory spokeData = hub.getSpoke(assetId, newFeeReceiver);
      if (spokeData.lastUpdateTimestamp == 0) {
        hub.addSpoke(
          assetId,
          newFeeReceiver,
          DataTypes.SpokeConfig({supplyCap: type(uint256).max, drawCap: type(uint256).max})
        );
      } else {
        hub.updateSpokeConfig(
          assetId,
          newFeeReceiver,
          DataTypes.SpokeConfig({supplyCap: type(uint256).max, drawCap: type(uint256).max})
        );
      }
    }
  }
}
