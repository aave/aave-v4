// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {CommonHelpers} from 'tests/helpers/commons/CommonHelpers.sol';
import {Constants} from 'tests/helpers/hub/Constants.sol';
import {Types} from 'tests/helpers/hub/Types.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

/// @title QueryHelpers
/// @notice Hub-level state-reading helpers, snapshot builders, and random utilities.
///         Math/calculation helpers live in MathHelpers.
abstract contract QueryHelpers is CommonHelpers, Constants, Types {
  using SafeCast for *;

  uint256 internal constant MAX_SUPPLY_AMOUNT = 1e30;

  // --- Asset queries ---

  function _getAssetDrawnDebt(IHub hub, uint256 assetId) internal view returns (uint256) {
    (uint256 drawn, ) = hub.getAssetOwed(assetId);
    return drawn;
  }

  function _getAssetLiquidityFee(IHub hub, uint256 assetId) internal view returns (uint256) {
    return hub.getAssetConfig(assetId).liquidityFee;
  }

  function _getFeeReceiver(IHub hub, uint256 assetId) internal view returns (address) {
    return hub.getAssetConfig(assetId).feeReceiver;
  }

  // --- Share/asset conversion queries ---

  function _minimumAssetsPerAddedShare(IHub hub, uint256 assetId) internal view returns (uint256) {
    return hub.previewAddByShares(assetId, 1);
  }

  function _minimumAssetsPerDrawnShare(IHub hub, uint256 assetId) internal view returns (uint256) {
    return hub.previewRestoreByShares(assetId, 1);
  }

  function _getAddExRate(IHub hub, uint256 assetId) internal view returns (uint256) {
    return hub.previewRemoveByShares(assetId, MAX_SUPPLY_AMOUNT);
  }

  function _getDebtExRate(IHub hub, uint256 assetId) internal view returns (uint256) {
    return hub.previewRestoreByShares(assetId, MAX_SUPPLY_AMOUNT);
  }

  // --- Interest helpers ---

  function _calculateBurntInterest(IHub hub, uint256 assetId) internal view returns (uint256) {
    return
      hub.getAddedAssets(assetId) - hub.previewRemoveByShares(assetId, hub.getAddedShares(assetId));
  }

  // --- Snapshot builders ---

  function _getAssetPosition(
    IHub hub,
    uint256 assetId
  ) internal view returns (AssetPosition memory) {
    IHub.Asset memory assetData = hub.getAsset(assetId);
    (uint256 drawn, uint256 premium) = hub.getAssetOwed(assetId);
    return
      AssetPosition({
        assetId: assetId,
        liquidity: assetData.liquidity,
        addedShares: assetData.addedShares,
        addedAmount: hub.getAddedAssets(assetId) - _calculateBurntInterest(hub, assetId),
        drawnShares: assetData.drawnShares,
        drawn: drawn,
        premiumShares: assetData.premiumShares,
        premiumOffsetRay: assetData.premiumOffsetRay,
        premium: premium,
        lastUpdateTimestamp: assetData.lastUpdateTimestamp.toUint40(),
        drawnIndex: assetData.drawnIndex,
        drawnRate: assetData.drawnRate
      });
  }
}
