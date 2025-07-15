// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20Metadata} from 'src/dependencies/openzeppelin/IERC20Metadata.sol';
import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {IHubConfigurator} from 'src/interfaces/IHubConfigurator.sol';

/**
 * @title HubConfigurator
 * @author Aave Labs
 * @notice HubConfigurator contract for the Aave protocol
 * @dev Must be granted permission by the Hub
 */
contract HubConfigurator is Ownable, IHubConfigurator {
  /**
   * @dev Constructor
   * @param owner_ The address of the owner
   */
  constructor(address owner_) Ownable(owner_) {}

  /// @inheritdoc IHubConfigurator
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

  /// @inheritdoc IHubConfigurator
  function addAsset(
    address hub,
    address underlying,
    address feeReceiver,
    address irStrategy
  ) external override onlyOwner returns (uint256) {
    ILiquidityHub targetHub = ILiquidityHub(hub);

    uint256 assetId = targetHub.addAsset(
      underlying,
      IERC20Metadata(underlying).decimals(),
      feeReceiver,
      irStrategy
    );

    targetHub.addSpoke(
      assetId,
      feeReceiver,
      DataTypes.SpokeConfig({
        supplyCap: type(uint256).max,
        drawCap: type(uint256).max,
        active: true
      })
    );

    return assetId;
  }

  /// @inheritdoc IHubConfigurator
  function addAsset(
    address hub,
    address underlying,
    uint8 decimals,
    address feeReceiver,
    address irStrategy
  ) external override onlyOwner returns (uint256) {
    ILiquidityHub targetHub = ILiquidityHub(hub);

    uint256 assetId = targetHub.addAsset(underlying, decimals, feeReceiver, irStrategy);

    targetHub.addSpoke(
      assetId,
      feeReceiver,
      DataTypes.SpokeConfig({
        supplyCap: type(uint256).max,
        drawCap: type(uint256).max,
        active: true
      })
    );

    return assetId;
  }

  /// @inheritdoc IHubConfigurator
  function updateActive(address hub, uint256 assetId, bool active) external override onlyOwner {
    ILiquidityHub targetHub = ILiquidityHub(hub);
    DataTypes.AssetConfig memory config = targetHub.getAssetConfig(assetId);
    config.active = active;
    targetHub.updateAssetConfig(assetId, config);
  }

  /// @inheritdoc IHubConfigurator
  function updatePaused(address hub, uint256 assetId, bool paused) external override onlyOwner {
    ILiquidityHub targetHub = ILiquidityHub(hub);
    DataTypes.AssetConfig memory config = targetHub.getAssetConfig(assetId);
    config.paused = paused;
    targetHub.updateAssetConfig(assetId, config);
  }

  /// @inheritdoc IHubConfigurator
  function updateFrozen(address hub, uint256 assetId, bool frozen) external override onlyOwner {
    ILiquidityHub targetHub = ILiquidityHub(hub);
    DataTypes.AssetConfig memory config = targetHub.getAssetConfig(assetId);
    config.frozen = frozen;
    targetHub.updateAssetConfig(assetId, config);
  }

  /// @inheritdoc IHubConfigurator
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

  /// @inheritdoc IHubConfigurator
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

  /// @inheritdoc IHubConfigurator
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

  /// @inheritdoc IHubConfigurator
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

  /// @inheritdoc IHubConfigurator
  function updateAssetConfig(
    address hub,
    uint256 assetId,
    DataTypes.AssetConfig calldata config
  ) external override onlyOwner {
    ILiquidityHub targetHub = ILiquidityHub(hub);
    _updateFeeReceiverSpokeConfig(
      targetHub,
      assetId,
      targetHub.getAssetConfig(assetId),
      config.feeReceiver
    );
    targetHub.updateAssetConfig(assetId, config);
  }

  function _updateFeeReceiverSpokeConfig(
    ILiquidityHub hub,
    uint256 assetId,
    DataTypes.AssetConfig memory oldConfig,
    address newFeeReceiver
  ) internal {
    if (oldConfig.feeReceiver == newFeeReceiver) {
      return;
    }

    hub.updateSpokeConfig(
      assetId,
      oldConfig.feeReceiver,
      DataTypes.SpokeConfig({supplyCap: 0, drawCap: 0, active: false})
    );

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
