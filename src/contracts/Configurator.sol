// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20Metadata} from 'src/dependencies/openzeppelin/IERC20Metadata.sol';
import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {IConfigurator} from 'src/interfaces/IConfigurator.sol';
import {IAssetInterestRateStrategy} from 'src/interfaces/IAssetInterestRateStrategy.sol';

contract Configurator is Ownable, IConfigurator {
  /**
   * @dev Constructor
   * @param owner_ The address of the owner
   */
  constructor(address owner_) Ownable(owner_) {}

  /// @inheritdoc IConfigurator
  function addSpokeToAssets(
    address hub,
    address spoke,
    uint256[] calldata assetIds,
    DataTypes.SpokeConfig[] calldata configs
  ) external onlyOwner {
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
  ) external override onlyOwner returns (uint256) {
    return ILiquidityHub(hub).addAsset(asset, IERC20Metadata(asset).decimals(), irStrategy);
  }

  /// @inheritdoc IConfigurator
  function addAsset(
    address hub,
    address asset,
    uint8 decimals,
    address irStrategy
  ) external override onlyOwner returns (uint256) {
    return ILiquidityHub(hub).addAsset(asset, decimals, irStrategy);
  }

  /// @inheritdoc IConfigurator
  function updateActive(address hub, uint256 assetId, bool active) external override onlyOwner {
    ILiquidityHub targetHub = ILiquidityHub(hub);
    DataTypes.AssetConfig memory config = targetHub.getAssetConfig(assetId);
    config.active = active;
    targetHub.updateAssetConfig(assetId, config);
  }

  /// @inheritdoc IConfigurator
  function updatePaused(address hub, uint256 assetId, bool paused) external override onlyOwner {
    ILiquidityHub targetHub = ILiquidityHub(hub);
    DataTypes.AssetConfig memory config = targetHub.getAssetConfig(assetId);
    config.paused = paused;
    targetHub.updateAssetConfig(assetId, config);
  }

  /// @inheritdoc IConfigurator
  function updateFrozen(address hub, uint256 assetId, bool frozen) external override onlyOwner {
    ILiquidityHub targetHub = ILiquidityHub(hub);
    DataTypes.AssetConfig memory config = targetHub.getAssetConfig(assetId);
    config.frozen = frozen;
    targetHub.updateAssetConfig(assetId, config);
  }

  /// @inheritdoc IConfigurator
  function updateLiquidityFee(
    address hub,
    uint256 assetId,
    uint256 liquidityFee
  ) external override onlyOwner {
    ILiquidityHub targetHub = ILiquidityHub(hub);
    DataTypes.AssetConfig memory config = targetHub.getAssetConfig(assetId);
    config.liquidityFee = liquidityFee;
    targetHub.updateAssetConfig(assetId, config);
  }

  /// @inheritdoc IConfigurator
  function updateFeeReceiver(
    address hub,
    uint256 assetId,
    address feeReceiver
  ) external override onlyOwner {
    ILiquidityHub targetHub = ILiquidityHub(hub);
    DataTypes.AssetConfig memory config = targetHub.getAssetConfig(assetId);
    _updateFeeReceiverSpokeConfig(targetHub, assetId, config, feeReceiver);
    config.feeReceiver = feeReceiver;
    targetHub.updateAssetConfig(assetId, config);
  }

  /// @inheritdoc IConfigurator
  function updateFeeConfig(
    address hub,
    uint256 assetId,
    uint256 liquidityFee,
    address feeReceiver
  ) external override onlyOwner {
    ILiquidityHub targetHub = ILiquidityHub(hub);
    DataTypes.AssetConfig memory config = targetHub.getAssetConfig(assetId);
    _updateFeeReceiverSpokeConfig(targetHub, assetId, config, feeReceiver);
    config.liquidityFee = liquidityFee;
    config.feeReceiver = feeReceiver;
    targetHub.updateAssetConfig(assetId, config);
  }

  /// @inheritdoc IConfigurator
  function updateInterestRateStrategy(
    address hub,
    uint256 assetId,
    address irStrategy
  ) external override onlyOwner {
    ILiquidityHub targetHub = ILiquidityHub(hub);
    DataTypes.AssetConfig memory config = targetHub.getAssetConfig(assetId);
    config.irStrategy = irStrategy;
    targetHub.updateAssetConfig(assetId, config);
  }

  function _updateFeeReceiverSpokeConfig(
    ILiquidityHub hub,
    uint256 assetId,
    DataTypes.AssetConfig memory config,
    address newFeeReceiver
  ) internal {
    if (config.feeReceiver == newFeeReceiver) {
      return;
    }

    if (config.feeReceiver != address(0)) {
      hub.updateSpokeConfig(
        assetId,
        config.feeReceiver,
        DataTypes.SpokeConfig({supplyCap: 0, drawCap: 0, active: false})
      );
    }

    if (newFeeReceiver != address(0)) {
      DataTypes.SpokeData memory spokeData = hub.getSpoke(assetId, newFeeReceiver);
      if (spokeData.lastUpdateTimestamp == 0) {
        hub.addSpoke(
          assetId,
          newFeeReceiver,
          DataTypes.SpokeConfig({
            supplyCap: type(uint256).max,
            drawCap: type(uint256).max,
            active: true
          })
        );
      } else {
        hub.updateSpokeConfig(
          assetId,
          newFeeReceiver,
          DataTypes.SpokeConfig({
            supplyCap: type(uint256).max,
            drawCap: type(uint256).max,
            active: true
          })
        );
      }
    }
  }
}
