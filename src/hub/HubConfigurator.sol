// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {IERC20Metadata} from 'src/dependencies/openzeppelin/IERC20Metadata.sol';
import {AccessManagedUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/AccessManagedUpgradeable.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';

/// @title HubConfigurator
/// @author Aave Labs
/// @notice Handles administrative functions on the Hub.
/// @dev Must be granted permission by the Hub.
abstract contract HubConfigurator is AccessManagedUpgradeable, IHubConfigurator {
  using SafeCast for uint256;

  /// @dev To be overridden by the inheriting HubConfigurator instance contract.
  function initialize(address authority) external virtual;

  /// @inheritdoc IHubConfigurator
  function addAsset(
    address hub,
    address underlying,
    address feeReceiver,
    uint256 liquidityFee,
    address irStrategy,
    bytes calldata irData
  ) external restricted returns (uint256) {
    return
      _addAsset(
        IHub(hub),
        underlying,
        IERC20Metadata(underlying).decimals(),
        feeReceiver,
        liquidityFee,
        irStrategy,
        irData
      );
  }

  /// @inheritdoc IHubConfigurator
  function addAssetWithDecimals(
    address hub,
    address underlying,
    uint8 decimals,
    address feeReceiver,
    uint256 liquidityFee,
    address irStrategy,
    bytes calldata irData
  ) external restricted returns (uint256) {
    return
      _addAsset(IHub(hub), underlying, decimals, feeReceiver, liquidityFee, irStrategy, irData);
  }

  /// @inheritdoc IHubConfigurator
  function updateLiquidityFee(
    address hub,
    address underlying,
    uint256 liquidityFee
  ) external restricted {
    IHub targetHub = IHub(hub);
    uint256 assetId = targetHub.getAssetId(underlying);
    IHub.AssetConfig memory config = targetHub.getAssetConfig(assetId);
    uint256 oldLiquidityFee = config.liquidityFee;
    config.liquidityFee = liquidityFee.toUint16();
    targetHub.updateAssetConfig(assetId, config, new bytes(0));
    emit LiquidityFeeUpdated(hub, underlying, assetId, oldLiquidityFee, liquidityFee);
  }

  /// @inheritdoc IHubConfigurator
  function updateFeeReceiver(
    address hub,
    address underlying,
    address feeReceiver
  ) external restricted {
    IHub targetHub = IHub(hub);
    uint256 assetId = targetHub.getAssetId(underlying);
    IHub.AssetConfig memory config = targetHub.getAssetConfig(assetId);
    address oldFeeReceiver = config.feeReceiver;
    config.feeReceiver = feeReceiver;
    targetHub.updateAssetConfig(assetId, config, new bytes(0));
    emit FeeReceiverUpdated(hub, underlying, assetId, oldFeeReceiver, feeReceiver);
  }

  /// @inheritdoc IHubConfigurator
  function updateFeeConfig(
    address hub,
    address underlying,
    uint256 liquidityFee,
    address feeReceiver
  ) external restricted {
    IHub targetHub = IHub(hub);
    uint256 assetId = targetHub.getAssetId(underlying);
    IHub.AssetConfig memory config = targetHub.getAssetConfig(assetId);
    uint256 oldLiquidityFee = config.liquidityFee;
    address oldFeeReceiver = config.feeReceiver;
    config.liquidityFee = liquidityFee.toUint16();
    config.feeReceiver = feeReceiver;
    targetHub.updateAssetConfig(assetId, config, new bytes(0));
    emit LiquidityFeeUpdated(hub, underlying, assetId, oldLiquidityFee, liquidityFee);
    emit FeeReceiverUpdated(hub, underlying, assetId, oldFeeReceiver, feeReceiver);
  }

  /// @inheritdoc IHubConfigurator
  function updateInterestRateStrategy(
    address hub,
    address underlying,
    address irStrategy,
    bytes calldata irData
  ) external restricted {
    IHub targetHub = IHub(hub);
    uint256 assetId = targetHub.getAssetId(underlying);
    IHub.AssetConfig memory config = targetHub.getAssetConfig(assetId);
    address oldIrStrategy = config.irStrategy;
    IAssetInterestRateStrategy.InterestRateData memory oldIrData = _getInterestRateData(
      oldIrStrategy,
      assetId
    );
    config.irStrategy = irStrategy;
    targetHub.updateAssetConfig(assetId, config, irData);
    emit InterestRateStrategyUpdated(hub, underlying, assetId, oldIrStrategy, irStrategy);
    emit InterestRateDataUpdated(
      hub,
      underlying,
      assetId,
      oldIrData,
      _getInterestRateData(irStrategy, assetId)
    );
  }

  /// @inheritdoc IHubConfigurator
  function updateReinvestmentController(
    address hub,
    address underlying,
    address reinvestmentController
  ) external restricted {
    IHub targetHub = IHub(hub);
    uint256 assetId = targetHub.getAssetId(underlying);
    IHub.AssetConfig memory config = targetHub.getAssetConfig(assetId);
    address oldReinvestmentController = config.reinvestmentController;
    config.reinvestmentController = reinvestmentController;
    targetHub.updateAssetConfig(assetId, config, new bytes(0));
    emit ReinvestmentControllerUpdated(
      hub,
      underlying,
      assetId,
      oldReinvestmentController,
      reinvestmentController
    );
  }

  /// @inheritdoc IHubConfigurator
  function resetAssetCaps(address hub, address underlying) external restricted {
    IHub targetHub = IHub(hub);
    uint256 assetId = targetHub.getAssetId(underlying);
    uint256 spokesCount = targetHub.getSpokeCount(assetId);
    for (uint256 i = 0; i < spokesCount; ++i) {
      _updateSpokeCaps(targetHub, underlying, assetId, targetHub.getSpokeAddress(assetId, i), 0, 0);
    }
  }

  /// @inheritdoc IHubConfigurator
  function deactivateAsset(address hub, address underlying) external restricted {
    IHub targetHub = IHub(hub);
    uint256 assetId = targetHub.getAssetId(underlying);
    uint256 spokesCount = targetHub.getSpokeCount(assetId);
    for (uint256 i = 0; i < spokesCount; ++i) {
      _updateSpokeActive(
        targetHub,
        underlying,
        assetId,
        targetHub.getSpokeAddress(assetId, i),
        false
      );
    }
  }

  /// @inheritdoc IHubConfigurator
  function haltAsset(address hub, address underlying) external restricted {
    IHub targetHub = IHub(hub);
    uint256 assetId = targetHub.getAssetId(underlying);
    uint256 spokesCount = targetHub.getSpokeCount(assetId);
    for (uint256 i = 0; i < spokesCount; ++i) {
      _updateSpokeHalted(
        targetHub,
        underlying,
        assetId,
        targetHub.getSpokeAddress(assetId, i),
        true
      );
    }
  }

  /// @inheritdoc IHubConfigurator
  function addSpoke(
    address hub,
    address spoke,
    address underlying,
    IHub.SpokeConfig calldata config
  ) external restricted {
    _addSpoke(IHub(hub), spoke, underlying, config);
  }

  /// @inheritdoc IHubConfigurator
  function addSpokeToAssets(
    address hub,
    address spoke,
    address[] calldata underlyings,
    IHub.SpokeConfig[] calldata configs
  ) external restricted {
    uint256 assetCount = underlyings.length;
    require(assetCount == configs.length, MismatchedConfigs());
    for (uint256 i = 0; i < assetCount; ++i) {
      _addSpoke(IHub(hub), spoke, underlyings[i], configs[i]);
    }
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeActive(
    address hub,
    address underlying,
    address spoke,
    bool active
  ) external restricted {
    IHub targetHub = IHub(hub);
    _updateSpokeActive(targetHub, underlying, targetHub.getAssetId(underlying), spoke, active);
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeHalted(
    address hub,
    address underlying,
    address spoke,
    bool halted
  ) external restricted {
    IHub targetHub = IHub(hub);
    _updateSpokeHalted(targetHub, underlying, targetHub.getAssetId(underlying), spoke, halted);
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeAddCap(
    address hub,
    address underlying,
    address spoke,
    uint256 addCap
  ) external restricted {
    IHub targetHub = IHub(hub);
    uint256 assetId = targetHub.getAssetId(underlying);
    IHub.SpokeConfig memory config = targetHub.getSpokeConfig(assetId, spoke);
    uint256 oldAddCap = config.addCap;
    config.addCap = addCap.toUint40();
    targetHub.updateSpokeConfig(assetId, spoke, config);
    emit SpokeAddCapUpdated(hub, underlying, assetId, spoke, oldAddCap, addCap);
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeDrawCap(
    address hub,
    address underlying,
    address spoke,
    uint256 drawCap
  ) external restricted {
    IHub targetHub = IHub(hub);
    uint256 assetId = targetHub.getAssetId(underlying);
    IHub.SpokeConfig memory config = targetHub.getSpokeConfig(assetId, spoke);
    uint256 oldDrawCap = config.drawCap;
    config.drawCap = drawCap.toUint40();
    targetHub.updateSpokeConfig(assetId, spoke, config);
    emit SpokeDrawCapUpdated(hub, underlying, assetId, spoke, oldDrawCap, drawCap);
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeRiskPremiumThreshold(
    address hub,
    address underlying,
    address spoke,
    uint256 riskPremiumThreshold
  ) external restricted {
    IHub targetHub = IHub(hub);
    uint256 assetId = targetHub.getAssetId(underlying);
    IHub.SpokeConfig memory config = targetHub.getSpokeConfig(assetId, spoke);
    uint256 oldRiskPremiumThreshold = config.riskPremiumThreshold;
    config.riskPremiumThreshold = riskPremiumThreshold.toUint24();
    targetHub.updateSpokeConfig(assetId, spoke, config);
    emit SpokeRiskPremiumThresholdUpdated(
      hub,
      underlying,
      assetId,
      spoke,
      oldRiskPremiumThreshold,
      riskPremiumThreshold
    );
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeCaps(
    address hub,
    address underlying,
    address spoke,
    uint256 addCap,
    uint256 drawCap
  ) external restricted {
    IHub targetHub = IHub(hub);
    _updateSpokeCaps(
      targetHub,
      underlying,
      targetHub.getAssetId(underlying),
      spoke,
      addCap,
      drawCap
    );
  }

  /// @inheritdoc IHubConfigurator
  function deactivateSpoke(address hub, address spoke) external restricted {
    IHub targetHub = IHub(hub);
    uint256 assetCount = targetHub.getAssetCount();
    for (uint256 assetId = 0; assetId < assetCount; ++assetId) {
      if (targetHub.isSpokeListed(assetId, spoke)) {
        _updateSpokeActive(targetHub, _getUnderlying(targetHub, assetId), assetId, spoke, false);
      }
    }
  }

  /// @inheritdoc IHubConfigurator
  function haltSpoke(address hub, address spoke) external restricted {
    IHub targetHub = IHub(hub);
    uint256 assetCount = targetHub.getAssetCount();
    for (uint256 assetId = 0; assetId < assetCount; ++assetId) {
      if (targetHub.isSpokeListed(assetId, spoke)) {
        _updateSpokeHalted(targetHub, _getUnderlying(targetHub, assetId), assetId, spoke, true);
      }
    }
  }

  /// @inheritdoc IHubConfigurator
  function resetSpokeCaps(address hub, address spoke) external restricted {
    IHub targetHub = IHub(hub);
    uint256 assetCount = targetHub.getAssetCount();
    for (uint256 assetId = 0; assetId < assetCount; ++assetId) {
      if (targetHub.isSpokeListed(assetId, spoke)) {
        _updateSpokeCaps(targetHub, _getUnderlying(targetHub, assetId), assetId, spoke, 0, 0);
      }
    }
  }

  /// @inheritdoc IHubConfigurator
  function updateInterestRateData(
    address hub,
    address underlying,
    bytes calldata irData
  ) external restricted {
    IHub targetHub = IHub(hub);
    uint256 assetId = targetHub.getAssetId(underlying);
    address irStrategy = targetHub.getAssetConfig(assetId).irStrategy;
    IAssetInterestRateStrategy.InterestRateData memory oldIrData = _getInterestRateData(
      irStrategy,
      assetId
    );
    targetHub.setInterestRateData(assetId, irData);
    emit InterestRateDataUpdated(
      hub,
      underlying,
      assetId,
      oldIrData,
      _getInterestRateData(irStrategy, assetId)
    );
  }

  function _addAsset(
    IHub hub,
    address underlying,
    uint8 decimals,
    address feeReceiver,
    uint256 liquidityFee,
    address irStrategy,
    bytes calldata irData
  ) internal returns (uint256) {
    uint256 assetId = hub.addAsset(underlying, decimals, feeReceiver, irStrategy, irData);
    IHub.AssetConfig memory config = hub.getAssetConfig(assetId);
    config.liquidityFee = liquidityFee.toUint16();
    hub.updateAssetConfig(assetId, config, new bytes(0));

    IAssetInterestRateStrategy.InterestRateData memory emptyIrData;
    emit LiquidityFeeUpdated(address(hub), underlying, assetId, 0, liquidityFee);
    emit FeeReceiverUpdated(address(hub), underlying, assetId, address(0), feeReceiver);
    emit InterestRateStrategyUpdated(address(hub), underlying, assetId, address(0), irStrategy);
    emit InterestRateDataUpdated(
      address(hub),
      underlying,
      assetId,
      emptyIrData,
      _getInterestRateData(irStrategy, assetId)
    );
    emit ReinvestmentControllerUpdated(
      address(hub),
      underlying,
      assetId,
      address(0),
      config.reinvestmentController
    );
    return assetId;
  }

  function _addSpoke(
    IHub hub,
    address spoke,
    address underlying,
    IHub.SpokeConfig calldata config
  ) internal {
    uint256 assetId = hub.getAssetId(underlying);
    hub.addSpoke(assetId, spoke, config);
    emit SpokeAddCapUpdated(address(hub), underlying, assetId, spoke, 0, config.addCap);
    emit SpokeDrawCapUpdated(address(hub), underlying, assetId, spoke, 0, config.drawCap);
    emit SpokeRiskPremiumThresholdUpdated(
      address(hub),
      underlying,
      assetId,
      spoke,
      0,
      config.riskPremiumThreshold
    );
    emit SpokeActiveUpdated(address(hub), underlying, assetId, spoke, false, config.active);
    emit SpokeHaltedUpdated(address(hub), underlying, assetId, spoke, false, config.halted);
  }

  /// @dev Updates spoke caps without changing the active flag.
  function _updateSpokeCaps(
    IHub hub,
    address underlying,
    uint256 assetId,
    address spoke,
    uint256 addCap,
    uint256 drawCap
  ) internal {
    IHub.SpokeConfig memory config = hub.getSpokeConfig(assetId, spoke);
    uint256 oldAddCap = config.addCap;
    uint256 oldDrawCap = config.drawCap;
    config.addCap = addCap.toUint40();
    config.drawCap = drawCap.toUint40();
    hub.updateSpokeConfig(assetId, spoke, config);
    emit SpokeAddCapUpdated(address(hub), underlying, assetId, spoke, oldAddCap, addCap);
    emit SpokeDrawCapUpdated(address(hub), underlying, assetId, spoke, oldDrawCap, drawCap);
  }

  function _updateSpokeActive(
    IHub hub,
    address underlying,
    uint256 assetId,
    address spoke,
    bool active
  ) internal {
    IHub.SpokeConfig memory config = hub.getSpokeConfig(assetId, spoke);
    bool oldActive = config.active;
    config.active = active;
    hub.updateSpokeConfig(assetId, spoke, config);
    emit SpokeActiveUpdated(address(hub), underlying, assetId, spoke, oldActive, active);
  }

  function _updateSpokeHalted(
    IHub hub,
    address underlying,
    uint256 assetId,
    address spoke,
    bool halted
  ) internal {
    IHub.SpokeConfig memory config = hub.getSpokeConfig(assetId, spoke);
    bool oldHalted = config.halted;
    config.halted = halted;
    hub.updateSpokeConfig(assetId, spoke, config);
    emit SpokeHaltedUpdated(address(hub), underlying, assetId, spoke, oldHalted, halted);
  }

  function _getUnderlying(IHub hub, uint256 assetId) internal view returns (address underlying) {
    (underlying, ) = hub.getAssetUnderlyingAndDecimals(assetId);
  }

  function _getInterestRateData(
    address irStrategy,
    uint256 assetId
  ) internal view returns (IAssetInterestRateStrategy.InterestRateData memory) {
    return IAssetInterestRateStrategy(irStrategy).getInterestRateData(assetId);
  }
}
