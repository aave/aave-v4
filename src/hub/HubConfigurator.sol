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
/// @notice Handles administrative functions on the hub.
/// @dev Must be granted permission by the hub.
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
  ) external onlyOwner returns (uint256) {
    IHub targetHub = IHub(hub);
    uint256 assetId = targetHub.addAsset(
      underlying,
      IERC20Metadata(underlying).decimals(),
      feeReceiver,
      irStrategy,
      irData
    );
    _updateLiquidityFee(targetHub, assetId, liquidityFee);
    return assetId;
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
  ) external onlyOwner returns (uint256) {
    IHub targetHub = IHub(hub);
    uint256 assetId = targetHub.addAsset(underlying, decimals, feeReceiver, irStrategy, irData);
    _updateLiquidityFee(targetHub, assetId, liquidityFee);
    return assetId;
  }

  /// @inheritdoc IHubConfigurator
  function updateLiquidityFee(
    address hub,
    uint256 assetId,
    uint256 liquidityFee
  ) external onlyOwner {
    _updateLiquidityFee(IHub(hub), assetId, liquidityFee);
  }

  /// @inheritdoc IHubConfigurator
  function updateFeeReceiver(address hub, uint256 assetId, address feeReceiver) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.AssetConfig memory config = targetHub.getAssetConfig(assetId);
    config.feeReceiver = feeReceiver;
    targetHub.updateAssetConfig(assetId, config, new bytes(0));
  }

  /// @inheritdoc IHubConfigurator
  function updateFeeConfig(
    address hub,
    uint256 assetId,
    uint256 liquidityFee,
    address feeReceiver
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.AssetConfig memory config = targetHub.getAssetConfig(assetId);
    config.liquidityFee = liquidityFee.toUint16();
    config.feeReceiver = feeReceiver;
    targetHub.updateAssetConfig(assetId, config, new bytes(0));
  }

  /// @inheritdoc IHubConfigurator
  function updateInterestRateStrategy(
    address hub,
    uint256 assetId,
    address irStrategy,
    bytes calldata irData
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.AssetConfig memory config = targetHub.getAssetConfig(assetId);
    config.irStrategy = irStrategy;
    targetHub.updateAssetConfig(assetId, config, irData);
  }

  /// @inheritdoc IHubConfigurator
  function updateReinvestmentController(
    address hub,
    uint256 assetId,
    address reinvestmentController
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.AssetConfig memory config = targetHub.getAssetConfig(assetId);
    config.reinvestmentController = reinvestmentController;
    targetHub.updateAssetConfig(assetId, config, new bytes(0));
  }

  /// @inheritdoc IHubConfigurator
  function freezeAsset(address hub, uint256 assetId) external onlyOwner {
    IHub targetHub = IHub(hub);
    uint256 spokesCount = targetHub.getSpokeCount(assetId);

    for (uint256 i = 0; i < spokesCount; ++i) {
      address spoke = targetHub.getSpokeAddress(assetId, i);
      IHub.SpokeConfig memory config = targetHub.getSpokeConfig(assetId, spoke);
      config.addCap = 0;
      config.drawCap = 0;
      targetHub.updateSpokeConfig(assetId, spoke, config);
    }
  }

  /// @inheritdoc IHubConfigurator
  function deactivateAsset(address hub, uint256 assetId) external onlyOwner {
    IHub targetHub = IHub(hub);
    uint256 spokesCount = targetHub.getSpokeCount(assetId);
    for (uint256 i = 0; i < spokesCount; ++i) {
      address spoke = targetHub.getSpokeAddress(assetId, i);
      IHub.SpokeConfig memory config = targetHub.getSpokeConfig(assetId, spoke);
      config.active = false;
      targetHub.updateSpokeConfig(assetId, spoke, config);
    }
  }

  /// @inheritdoc IHubConfigurator
  function pauseAsset(address hub, uint256 assetId) external onlyOwner {
    IHub targetHub = IHub(hub);
    uint256 spokesCount = targetHub.getSpokeCount(assetId);
    for (uint256 i = 0; i < spokesCount; ++i) {
      address spoke = targetHub.getSpokeAddress(assetId, i);
      IHub.SpokeConfig memory config = targetHub.getSpokeConfig(assetId, spoke);
      config.paused = true;
      targetHub.updateSpokeConfig(assetId, spoke, config);
    }
  }

  /// @inheritdoc IHubConfigurator
  function addSpoke(
    address hub,
    address spoke,
    uint256 assetId,
    IHub.SpokeConfig calldata config
  ) external onlyOwner {
    IHub(hub).addSpoke(assetId, spoke, config);
  }

  /// @inheritdoc IHubConfigurator
  function addSpokeToAssets(
    address hub,
    address spoke,
    uint256[] calldata assetIds,
    IHub.SpokeConfig[] calldata configs
  ) external onlyOwner {
    uint256 assetCount = assetIds.length;
    require(assetCount == configs.length, MismatchedConfigs());
    for (uint256 i = 0; i < assetCount; ++i) {
      IHub(hub).addSpoke(assetIds[i], spoke, configs[i]);
    }
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeActive(
    address hub,
    uint256 assetId,
    address spoke,
    bool active
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.SpokeConfig memory config = targetHub.getSpokeConfig(assetId, spoke);
    config.active = active;
    targetHub.updateSpokeConfig(assetId, spoke, config);
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokePaused(
    address hub,
    uint256 assetId,
    address spoke,
    bool paused
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.SpokeConfig memory config = targetHub.getSpokeConfig(assetId, spoke);
    config.paused = paused;
    targetHub.updateSpokeConfig(assetId, spoke, config);
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeSupplyCap(
    address hub,
    uint256 assetId,
    address spoke,
    uint256 addCap
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.SpokeConfig memory config = targetHub.getSpokeConfig(assetId, spoke);
    config.addCap = addCap.toUint40();
    targetHub.updateSpokeConfig(assetId, spoke, config);
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeDrawCap(
    address hub,
    uint256 assetId,
    address spoke,
    uint256 drawCap
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.SpokeConfig memory config = targetHub.getSpokeConfig(assetId, spoke);
    config.drawCap = drawCap.toUint40();
    targetHub.updateSpokeConfig(assetId, spoke, config);
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeRiskPremiumCap(
    address hub,
    uint256 assetId,
    address spoke,
    uint256 riskPremiumCap
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.SpokeConfig memory config = targetHub.getSpokeConfig(assetId, spoke);
    config.riskPremiumCap = riskPremiumCap.toUint24();
    targetHub.updateSpokeConfig(assetId, spoke, config);
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeCaps(
    address hub,
    uint256 assetId,
    address spoke,
    uint256 addCap,
    uint256 drawCap,
    uint256 riskPremiumCap
  ) external onlyOwner {
    _updateSpokeCaps(IHub(hub), assetId, spoke, addCap, drawCap, riskPremiumCap);
  }

  /// @inheritdoc IHubConfigurator
  function deactivateSpoke(address hub, address spoke) external onlyOwner {
    IHub targetHub = IHub(hub);
    uint256 assetCount = targetHub.getAssetCount();
    for (uint256 assetId = 0; assetId < assetCount; ++assetId) {
      if (targetHub.isSpokeListed(assetId, spoke)) {
        IHub.SpokeConfig memory config = targetHub.getSpokeConfig(assetId, spoke);
        config.active = false;
        targetHub.updateSpokeConfig(assetId, spoke, config);
      }
    }
  }

  /// @inheritdoc IHubConfigurator
  function pauseSpoke(address hub, address spoke) external onlyOwner {
    IHub targetHub = IHub(hub);
    uint256 assetCount = targetHub.getAssetCount();
    for (uint256 assetId = 0; assetId < assetCount; ++assetId) {
      if (targetHub.isSpokeListed(assetId, spoke)) {
        IHub.SpokeConfig memory config = targetHub.getSpokeConfig(assetId, spoke);
        config.paused = true;
        targetHub.updateSpokeConfig(assetId, spoke, config);
      }
    }
  }

  /// @inheritdoc IHubConfigurator
  function freezeSpoke(address hub, address spoke) external onlyOwner {
    IHub targetHub = IHub(hub);
    uint256 assetCount = targetHub.getAssetCount();
    for (uint256 assetId = 0; assetId < assetCount; ++assetId) {
      if (targetHub.isSpokeListed(assetId, spoke)) {
        IHub.SpokeConfig memory config = targetHub.getSpokeConfig(assetId, spoke);
        config.addCap = 0;
        config.drawCap = 0;
        targetHub.updateSpokeConfig(assetId, spoke, config);
      }
    }
  }

  /// @inheritdoc IHubConfigurator
  function updateInterestRateData(
    address hub,
    uint256 assetId,
    bytes calldata irData
  ) external onlyOwner {
    IHub(hub).setInterestRateData(assetId, irData);
  }

  /// @dev Updates spoke caps without changing the active flag.
  function _updateSpokeCaps(
    IHub hub,
    uint256 assetId,
    address spoke,
    uint256 addCap,
    uint256 drawCap,
    uint256 riskPremiumCap
  ) internal {
    IHub.SpokeConfig memory config = hub.getSpokeConfig(assetId, spoke);
    config.addCap = addCap.toUint40();
    config.drawCap = drawCap.toUint40();
    config.riskPremiumCap = riskPremiumCap.toUint24();
    hub.updateSpokeConfig(assetId, spoke, config);
  }

  function _updateLiquidityFee(IHub hub, uint256 assetId, uint256 liquidityFee) internal {
    IHub.AssetConfig memory config = hub.getAssetConfig(assetId);
    config.liquidityFee = liquidityFee.toUint16();
    hub.updateAssetConfig(assetId, config, new bytes(0));
  }
}
