// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {IERC20Metadata} from 'src/dependencies/openzeppelin/IERC20Metadata.sol';
import {Ownable2Step, Ownable} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';

/// @title HubConfigurator
/// @author Aave Labs
/// @notice Handles administrative functions on the Hub.
/// @dev Must be granted permission by the Hub.
contract HubConfigurator is Ownable2Step, IHubConfigurator {
  using SafeCast for uint256;

  /// @dev Constructor.
  /// @param owner_ The address of the owner.
  constructor(address owner_) Ownable(owner_) {}

  /// @inheritdoc IHubConfigurator
  function addAsset(
    address hub,
    address underlying,
    address feeReceiver,
    uint256 liquidityFee,
    address irStrategy,
    bytes calldata irData
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    targetHub.addAsset(
      underlying,
      IERC20Metadata(underlying).decimals(),
      feeReceiver,
      irStrategy,
      irData
    );
    _updateLiquidityFee(targetHub, underlying, liquidityFee);
  }

  /// @inheritdoc IHubConfigurator
  function addAsset(
    address hub,
    address underlying,
    uint8 decimals,
    address feeReceiver,
    uint256 liquidityFee,
    address irStrategy,
    bytes calldata irData
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    targetHub.addAsset(underlying, decimals, feeReceiver, irStrategy, irData);
    _updateLiquidityFee(targetHub, underlying, liquidityFee);
  }

  /// @inheritdoc IHubConfigurator
  function updateLiquidityFee(address hub, address asset, uint256 liquidityFee) external onlyOwner {
    _updateLiquidityFee(IHub(hub), asset, liquidityFee);
  }

  /// @inheritdoc IHubConfigurator
  function updateFeeReceiver(address hub, address asset, address feeReceiver) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.AssetConfig memory config = targetHub.getAssetConfig(asset);
    config.feeReceiver = feeReceiver;
    targetHub.updateAssetConfig(asset, config, new bytes(0));
  }

  /// @inheritdoc IHubConfigurator
  function updateFeeConfig(
    address hub,
    address asset,
    uint256 liquidityFee,
    address feeReceiver
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.AssetConfig memory config = targetHub.getAssetConfig(asset);
    config.liquidityFee = liquidityFee.toUint16();
    config.feeReceiver = feeReceiver;
    targetHub.updateAssetConfig(asset, config, new bytes(0));
  }

  /// @inheritdoc IHubConfigurator
  function updateInterestRateStrategy(
    address hub,
    address asset,
    address irStrategy,
    bytes calldata irData
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.AssetConfig memory config = targetHub.getAssetConfig(asset);
    config.irStrategy = irStrategy;
    targetHub.updateAssetConfig(asset, config, irData);
  }

  /// @inheritdoc IHubConfigurator
  function updateReinvestmentController(
    address hub,
    address asset,
    address reinvestmentController
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.AssetConfig memory config = targetHub.getAssetConfig(asset);
    config.reinvestmentController = reinvestmentController;
    targetHub.updateAssetConfig(asset, config, new bytes(0));
  }

  /// @inheritdoc IHubConfigurator
  function freezeAsset(address hub, address asset) external onlyOwner {
    IHub targetHub = IHub(hub);
    uint256 spokesCount = targetHub.getSpokeCount(asset);

    for (uint256 i = 0; i < spokesCount; ++i) {
      address spoke = targetHub.getSpokeAddress(asset, i);
      IHub.SpokeConfig memory config = targetHub.getSpokeConfig(asset, spoke);
      config.addCap = 0;
      config.drawCap = 0;
      targetHub.updateSpokeConfig(asset, spoke, config);
    }
  }

  /// @inheritdoc IHubConfigurator
  function deactivateAsset(address hub, address asset) external onlyOwner {
    IHub targetHub = IHub(hub);
    uint256 spokesCount = targetHub.getSpokeCount(asset);
    for (uint256 i = 0; i < spokesCount; ++i) {
      address spoke = targetHub.getSpokeAddress(asset, i);
      IHub.SpokeConfig memory config = targetHub.getSpokeConfig(asset, spoke);
      config.active = false;
      targetHub.updateSpokeConfig(asset, spoke, config);
    }
  }

  /// @inheritdoc IHubConfigurator
  function pauseAsset(address hub, address asset) external onlyOwner {
    IHub targetHub = IHub(hub);
    uint256 spokesCount = targetHub.getSpokeCount(asset);
    for (uint256 i = 0; i < spokesCount; ++i) {
      address spoke = targetHub.getSpokeAddress(asset, i);
      IHub.SpokeConfig memory config = targetHub.getSpokeConfig(asset, spoke);
      config.paused = true;
      targetHub.updateSpokeConfig(asset, spoke, config);
    }
  }

  /// @inheritdoc IHubConfigurator
  function addSpoke(
    address hub,
    address spoke,
    address asset,
    IHub.SpokeConfig calldata config
  ) external onlyOwner {
    IHub(hub).addSpoke(asset, spoke, config);
  }

  /// @inheritdoc IHubConfigurator
  function addSpokeToAssets(
    address hub,
    address spoke,
    address[] calldata assets,
    IHub.SpokeConfig[] calldata configs
  ) external onlyOwner {
    uint256 assetCount = assets.length;
    require(assetCount == configs.length, MismatchedConfigs());
    for (uint256 i = 0; i < assetCount; ++i) {
      IHub(hub).addSpoke(assets[i], spoke, configs[i]);
    }
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeActive(
    address hub,
    address asset,
    address spoke,
    bool active
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.SpokeConfig memory config = targetHub.getSpokeConfig(asset, spoke);
    config.active = active;
    targetHub.updateSpokeConfig(asset, spoke, config);
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokePaused(
    address hub,
    address asset,
    address spoke,
    bool paused
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.SpokeConfig memory config = targetHub.getSpokeConfig(asset, spoke);
    config.paused = paused;
    targetHub.updateSpokeConfig(asset, spoke, config);
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeSupplyCap(
    address hub,
    address asset,
    address spoke,
    uint256 addCap
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.SpokeConfig memory config = targetHub.getSpokeConfig(asset, spoke);
    config.addCap = addCap.toUint40();
    targetHub.updateSpokeConfig(asset, spoke, config);
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeDrawCap(
    address hub,
    address asset,
    address spoke,
    uint256 drawCap
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.SpokeConfig memory config = targetHub.getSpokeConfig(asset, spoke);
    config.drawCap = drawCap.toUint40();
    targetHub.updateSpokeConfig(asset, spoke, config);
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeRiskPremiumThreshold(
    address hub,
    address asset,
    address spoke,
    uint256 riskPremiumThreshold
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.SpokeConfig memory config = targetHub.getSpokeConfig(asset, spoke);
    config.riskPremiumThreshold = riskPremiumThreshold.toUint24();
    targetHub.updateSpokeConfig(asset, spoke, config);
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeCaps(
    address hub,
    address asset,
    address spoke,
    uint256 addCap,
    uint256 drawCap
  ) external onlyOwner {
    _updateSpokeCaps(IHub(hub), asset, spoke, addCap, drawCap);
  }

  /// @inheritdoc IHubConfigurator
  function deactivateSpoke(address hub, address spoke) external onlyOwner {
    IHub targetHub = IHub(hub);
    uint256 assetCount = targetHub.getAssetCount();
    for (uint256 i = 0; i < assetCount; ++i) {
      address asset = targetHub.getUnderlyingAddress(i);
      if (targetHub.isSpokeListed(asset, spoke)) {
        IHub.SpokeConfig memory config = targetHub.getSpokeConfig(asset, spoke);
        config.active = false;
        targetHub.updateSpokeConfig(asset, spoke, config);
      }
    }
  }

  /// @inheritdoc IHubConfigurator
  function pauseSpoke(address hub, address spoke) external onlyOwner {
    IHub targetHub = IHub(hub);
    uint256 assetCount = targetHub.getAssetCount();
    for (uint256 i = 0; i < assetCount; ++i) {
      address asset = targetHub.getUnderlyingAddress(i);
      if (targetHub.isSpokeListed(asset, spoke)) {
        IHub.SpokeConfig memory config = targetHub.getSpokeConfig(asset, spoke);
        config.paused = true;
        targetHub.updateSpokeConfig(asset, spoke, config);
      }
    }
  }

  /// @inheritdoc IHubConfigurator
  function freezeSpoke(address hub, address spoke) external onlyOwner {
    IHub targetHub = IHub(hub);
    uint256 assetCount = targetHub.getAssetCount();
    for (uint256 i = 0; i < assetCount; ++i) {
      address asset = targetHub.getUnderlyingAddress(i);
      if (targetHub.isSpokeListed(asset, spoke)) {
        IHub.SpokeConfig memory config = targetHub.getSpokeConfig(asset, spoke);
        config.addCap = 0;
        config.drawCap = 0;
        targetHub.updateSpokeConfig(asset, spoke, config);
      }
    }
  }

  /// @inheritdoc IHubConfigurator
  function updateInterestRateData(
    address hub,
    address asset,
    bytes calldata irData
  ) external onlyOwner {
    IHub(hub).setInterestRateData(asset, irData);
  }

  /// @dev Updates spoke caps without changing the active flag.
  function _updateSpokeCaps(
    IHub hub,
    address asset,
    address spoke,
    uint256 addCap,
    uint256 drawCap
  ) internal {
    IHub.SpokeConfig memory config = hub.getSpokeConfig(asset, spoke);
    config.addCap = addCap.toUint40();
    config.drawCap = drawCap.toUint40();
    hub.updateSpokeConfig(asset, spoke, config);
  }

  function _updateLiquidityFee(IHub hub, address asset, uint256 liquidityFee) internal {
    IHub.AssetConfig memory config = hub.getAssetConfig(asset);
    config.liquidityFee = liquidityFee.toUint16();
    hub.updateAssetConfig(asset, config, new bytes(0));
  }
}
