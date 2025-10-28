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
  function updateLiquidityFee(
    address hub,
    address underlying,
    uint256 liquidityFee
  ) external onlyOwner {
    _updateLiquidityFee(IHub(hub), underlying, liquidityFee);
  }

  /// @inheritdoc IHubConfigurator
  function updateFeeReceiver(
    address hub,
    address underlying,
    address feeReceiver
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.AssetConfig memory config = targetHub.getAssetConfig(underlying);
    config.feeReceiver = feeReceiver;
    targetHub.updateAssetConfig(underlying, config, new bytes(0));
  }

  /// @inheritdoc IHubConfigurator
  function updateFeeConfig(
    address hub,
    address underlying,
    uint256 liquidityFee,
    address feeReceiver
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.AssetConfig memory config = targetHub.getAssetConfig(underlying);
    config.liquidityFee = liquidityFee.toUint16();
    config.feeReceiver = feeReceiver;
    targetHub.updateAssetConfig(underlying, config, new bytes(0));
  }

  /// @inheritdoc IHubConfigurator
  function updateInterestRateStrategy(
    address hub,
    address underlying,
    address irStrategy,
    bytes calldata irData
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.AssetConfig memory config = targetHub.getAssetConfig(underlying);
    config.irStrategy = irStrategy;
    targetHub.updateAssetConfig(underlying, config, irData);
  }

  /// @inheritdoc IHubConfigurator
  function updateReinvestmentController(
    address hub,
    address underlying,
    address reinvestmentController
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.AssetConfig memory config = targetHub.getAssetConfig(underlying);
    config.reinvestmentController = reinvestmentController;
    targetHub.updateAssetConfig(underlying, config, new bytes(0));
  }

  /// @inheritdoc IHubConfigurator
  function freezeAsset(address hub, address underlying) external onlyOwner {
    IHub targetHub = IHub(hub);
    uint256 spokesCount = targetHub.getSpokeCount(underlying);

    for (uint256 i = 0; i < spokesCount; ++i) {
      address spoke = targetHub.getSpokeAddress(underlying, i);
      IHub.SpokeConfig memory config = targetHub.getSpokeConfig(underlying, spoke);
      config.addCap = 0;
      config.drawCap = 0;
      targetHub.updateSpokeConfig(underlying, spoke, config);
    }
  }

  /// @inheritdoc IHubConfigurator
  function deactivateAsset(address hub, address underlying) external onlyOwner {
    IHub targetHub = IHub(hub);
    uint256 spokesCount = targetHub.getSpokeCount(underlying);
    for (uint256 i = 0; i < spokesCount; ++i) {
      address spoke = targetHub.getSpokeAddress(underlying, i);
      IHub.SpokeConfig memory config = targetHub.getSpokeConfig(underlying, spoke);
      config.active = false;
      targetHub.updateSpokeConfig(underlying, spoke, config);
    }
  }

  /// @inheritdoc IHubConfigurator
  function pauseAsset(address hub, address underlying) external onlyOwner {
    IHub targetHub = IHub(hub);
    uint256 spokesCount = targetHub.getSpokeCount(underlying);
    for (uint256 i = 0; i < spokesCount; ++i) {
      address spoke = targetHub.getSpokeAddress(underlying, i);
      IHub.SpokeConfig memory config = targetHub.getSpokeConfig(underlying, spoke);
      config.paused = true;
      targetHub.updateSpokeConfig(underlying, spoke, config);
    }
  }

  /// @inheritdoc IHubConfigurator
  function addSpoke(
    address hub,
    address spoke,
    address underlying,
    IHub.SpokeConfig calldata config
  ) external onlyOwner {
    IHub(hub).addSpoke(underlying, spoke, config);
  }

  /// @inheritdoc IHubConfigurator
  function addSpokeToAssets(
    address hub,
    address spoke,
    uint256[] calldata underlyings,
    IHub.SpokeConfig[] calldata configs
  ) external onlyOwner {
    uint256 assetCount = underlyings.length;
    require(assetCount == configs.length, MismatchedConfigs());
    // for (uint256 i = 0; i < assetCount; ++i) {
    //   IHub(hub).addSpoke(underlyings[i], spoke, configs[i]);
    // }
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeActive(
    address hub,
    address underlying,
    address spoke,
    bool active
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.SpokeConfig memory config = targetHub.getSpokeConfig(underlying, spoke);
    config.active = active;
    targetHub.updateSpokeConfig(underlying, spoke, config);
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokePaused(
    address hub,
    address underlying,
    address spoke,
    bool paused
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.SpokeConfig memory config = targetHub.getSpokeConfig(underlying, spoke);
    config.paused = paused;
    targetHub.updateSpokeConfig(underlying, spoke, config);
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeSupplyCap(
    address hub,
    address underlying,
    address spoke,
    uint256 addCap
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.SpokeConfig memory config = targetHub.getSpokeConfig(underlying, spoke);
    config.addCap = addCap.toUint40();
    targetHub.updateSpokeConfig(underlying, spoke, config);
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeDrawCap(
    address hub,
    address underlying,
    address spoke,
    uint256 drawCap
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.SpokeConfig memory config = targetHub.getSpokeConfig(underlying, spoke);
    config.drawCap = drawCap.toUint40();
    targetHub.updateSpokeConfig(underlying, spoke, config);
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeRiskPremiumThreshold(
    address hub,
    address underlying,
    address spoke,
    uint256 riskPremiumThreshold
  ) external onlyOwner {
    IHub targetHub = IHub(hub);
    IHub.SpokeConfig memory config = targetHub.getSpokeConfig(underlying, spoke);
    config.riskPremiumThreshold = riskPremiumThreshold.toUint24();
    targetHub.updateSpokeConfig(underlying, spoke, config);
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeCaps(
    address hub,
    address underlying,
    address spoke,
    uint256 addCap,
    uint256 drawCap
  ) external onlyOwner {
    _updateSpokeCaps(IHub(hub), underlying, spoke, addCap, drawCap);
  }

  /// @inheritdoc IHubConfigurator
  function deactivateSpoke(address hub, address spoke) external onlyOwner {
    IHub targetHub = IHub(hub);
    uint256 assetCount = targetHub.getAssetCount();
    // todo fix
    // for (address underlying = 0; underlying < assetCount; ++underlying) {
    //   if (targetHub.isSpokeListed(underlying, spoke)) {
    //     IHub.SpokeConfig memory config = targetHub.getSpokeConfig(underlying, spoke);
    //     config.active = false;
    //     targetHub.updateSpokeConfig(underlying, spoke, config);
    //   }
    // }
  }

  /// @inheritdoc IHubConfigurator
  function pauseSpoke(address hub, address spoke) external onlyOwner {
    IHub targetHub = IHub(hub);
    uint256 assetCount = targetHub.getAssetCount();
    // for (address underlying = 0; underlying < assetCount; ++underlying) {
    //   if (targetHub.isSpokeListed(underlying, spoke)) {
    //     IHub.SpokeConfig memory config = targetHub.getSpokeConfig(underlying, spoke);
    //     config.paused = true;
    //     targetHub.updateSpokeConfig(underlying, spoke, config);
    //   }
    // }
  }

  /// @inheritdoc IHubConfigurator
  function freezeSpoke(address hub, address spoke) external onlyOwner {
    IHub targetHub = IHub(hub);
    uint256 assetCount = targetHub.getAssetCount();
    // for (address underlying = 0; underlying < assetCount; ++underlying) {
    //   if (targetHub.isSpokeListed(underlying, spoke)) {
    //     IHub.SpokeConfig memory config = targetHub.getSpokeConfig(underlying, spoke);
    //     config.addCap = 0;
    //     config.drawCap = 0;
    //     targetHub.updateSpokeConfig(underlying, spoke, config);
    //   }
    // }
  }

  /// @inheritdoc IHubConfigurator
  function updateInterestRateData(
    address hub,
    address underlying,
    bytes calldata irData
  ) external onlyOwner {
    IHub(hub).setInterestRateData(underlying, irData);
  }

  /// @dev Updates spoke caps without changing the active flag.
  function _updateSpokeCaps(
    IHub hub,
    address underlying,
    address spoke,
    uint256 addCap,
    uint256 drawCap
  ) internal {
    IHub.SpokeConfig memory config = hub.getSpokeConfig(underlying, spoke);
    config.addCap = addCap.toUint40();
    config.drawCap = drawCap.toUint40();
    hub.updateSpokeConfig(underlying, spoke, config);
  }

  function _updateLiquidityFee(IHub hub, address underlying, uint256 liquidityFee) internal {
    IHub.AssetConfig memory config = hub.getAssetConfig(underlying);
    config.liquidityFee = liquidityFee.toUint16();
    hub.updateAssetConfig(underlying, config, new bytes(0));
  }
}
