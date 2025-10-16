// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {SharesMath} from 'src/hub/libraries/SharesMath.sol';
import {IBasicInterestRateStrategy} from 'src/hub/interfaces/IBasicInterestRateStrategy.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

/// @title AssetLogic library
/// @author Aave Labs
/// @notice Implements the base logic and share price conversions for asset data.
library AssetLogic {
  using AssetLogic for IHub.Asset;
  using PercentageMath for uint256;
  using SharesMath for uint256;
  using WadRayMath for *;
  using MathUtils for uint256;
  using SafeCast for uint256;

  /// @notice Converts an amount of shares to the equivalent amount of drawn assets, rounding up.
  function toDrawnAssetsUp(
    IHub.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.rayMulUp(asset.getDrawnIndex());
  }

  /// @notice Converts an amount of shares to the equivalent amount of drawn assets, rounding down.
  function toDrawnAssetsDown(
    IHub.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.rayMulDown(asset.getDrawnIndex());
  }

  /// @notice Converts an amount of drawn assets to the equivalent amount of shares, rounding up.
  function toDrawnSharesUp(
    IHub.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.rayDivUp(asset.getDrawnIndex());
  }

  /// @notice Converts an amount of drawn assets to the equivalent amount of shares, rounding down.
  function toDrawnSharesDown(
    IHub.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.rayDivDown(asset.getDrawnIndex());
  }

  /// @notice Returns the total drawn assets amount for the specified asset.
  function drawn(IHub.Asset storage asset) internal view returns (uint256) {
    return asset.drawnShares.rayMulUp(asset.getDrawnIndex());
  }

  /// @notice Returns the total premium amount for the specified asset.
  function premium(IHub.Asset storage asset) internal view returns (uint256) {
    // sanity: utilize solc underflow check
    uint256 accruedPremium = asset.toDrawnAssetsUp(asset.premiumShares) - asset.premiumOffset;
    return asset.realizedPremium + accruedPremium;
  }

  /// @notice Returns the total amount owed for the specified asset, including drawn and premium.
  function totalOwed(IHub.Asset storage asset) internal view returns (uint256) {
    return asset.drawn() + asset.premium();
  }

  /// @notice Returns the total added assets for the specified asset.
  function totalAddedAssets(IHub.Asset storage asset) internal view returns (uint256) {
    return asset.liquidity + asset.swept + asset.deficit + asset.totalOwed() - asset.feeAmount - asset.getUnrealizedFeeAmount(asset.getDrawnIndex());
  }

  /// @notice Converts an amount of shares to the equivalent amount of added assets, rounding up.
  function toAddedAssetsUp(
    IHub.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.toAssetsUp(asset.totalAddedAssets(), asset.addedShares);
  }

  /// @notice Converts an amount of shares to the equivalent amount of added assets, rounding down.
  function toAddedAssetsDown(
    IHub.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.toAssetsDown(asset.totalAddedAssets(), asset.addedShares);
  }

  /// @notice Converts an amount of added assets to the equivalent amount of shares, rounding up.
  function toAddedSharesUp(
    IHub.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.toSharesUp(asset.totalAddedAssets(), asset.addedShares);
  }

  /// @notice Converts an amount of added assets to the equivalent amount of shares, rounding down.
  function toAddedSharesDown(
    IHub.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.toSharesDown(asset.totalAddedAssets(), asset.addedShares);
  }

  /// @notice Updates the drawn rate of a specified asset.
  /// @dev Premium debt is not used in the interest rate calculation.
  function updateDrawnRate(IHub.Asset storage asset, uint256 assetId) internal {
    uint256 newDrawnRate = IBasicInterestRateStrategy(asset.irStrategy).calculateInterestRate({
      assetId: assetId,
      liquidity: asset.liquidity,
      drawn: asset.drawn(),
      deficit: asset.deficit,
      swept: asset.swept
    });
    asset.drawnRate = newDrawnRate.toUint96();

    // asset accrual should have already occurred
    emit IHub.UpdateAsset(assetId, asset.drawnIndex, newDrawnRate);
  }

  /// @notice Accrues interest and fees for the specified asset.
  function accrue(IHub.Asset storage asset) internal {
    if (asset.lastUpdateTimestamp == block.timestamp) {
      return;
    }

    uint256 assetsBefore = asset.totalAddedAssets();

    uint256 newDrawnIndex = asset.getDrawnIndex();

    uint256 feeAmount = asset.getUnrealizedFeeAmount(newDrawnIndex);
    asset.feeAmount += feeAmount.toUint128();
    uint256 feeShares = asset.toAddedSharesDown(feeAmount);
    asset.feeShares += feeShares.toUint128();

    asset.drawnIndex = newDrawnIndex.toUint128();
    asset.lastUpdateTimestamp = block.timestamp.toUint32();

    uint256 assetsAfter = asset.totalAddedAssets();
    require(assetsAfter == assetsBefore, "AssetLogic: total added assets mismatch");
  }

  /// @notice Calculates the drawn index of a specified asset based on the existing drawn rate and index.
  function getDrawnIndex(IHub.Asset storage asset) internal view returns (uint256) {
    uint256 previousIndex = asset.drawnIndex;
    uint256 lastUpdateTimestamp = asset.lastUpdateTimestamp;
    if (
      lastUpdateTimestamp == block.timestamp || (asset.drawnShares == 0 && asset.premiumShares == 0)
    ) {
      return previousIndex;
    }
    return
      previousIndex.rayMulUp(
        MathUtils.calculateLinearInterest(asset.drawnRate, uint32(lastUpdateTimestamp))
      );
  }

  /// @notice Calculates the amount of fee shares derived from the index growth due to interest accrual.
  /// @dev The true liquidity growth is always greater than accrued fees, even with 100.00% liquidity fee.
  /// @param drawnIndex The current drawn index.
  function getUnrealizedFeeAmount(
    IHub.Asset storage asset,
    uint256 drawnIndex
  ) internal view returns (uint256) {
    if (drawnIndex == asset.drawnIndex) return 0;

    uint256 liquidityFee = asset.liquidityFee;
    if (liquidityFee == 0) return 0;

    uint256 lastDrawnIndex = asset.drawnIndex;
    uint256 liquidityGrowth = asset.drawnShares.rayMulUp(drawnIndex) -
      asset.drawnShares.rayMulUp(lastDrawnIndex) +
      asset.premiumShares.rayMulUp(drawnIndex) -
      asset.premiumShares.rayMulUp(lastDrawnIndex);
    return liquidityGrowth.percentMulDown(asset.liquidityFee);
  }
}
