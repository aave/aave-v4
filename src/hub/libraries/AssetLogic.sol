// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {SharesMath} from 'src/hub/libraries/SharesMath.sol';
import {IOU} from 'src/hub/libraries/IOU.sol';
import {IBasicInterestRateStrategy} from 'src/hub/interfaces/IBasicInterestRateStrategy.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

/// @title AssetLogic library
/// @author Aave Labs
/// @notice Implements the base logic and share price conversions for asset data.
library AssetLogic {
  using AssetLogic for IHub.Asset;
  using SafeCast for uint256;
  using MathUtils for uint256;
  using PercentageMath for uint256;
  using WadRayMath for *;
  using SharesMath for uint256;

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

  function getAssetDrawn(
    IHub.Asset storage asset,
    uint256 drawnIndex
  ) internal view returns (uint256) {
    return IOU.calculateDrawnRay(asset.drawnShares, drawnIndex).fromRayUp();
  }

  /// @notice Returns the total added assets for the specified asset.
  function totalAddedAssets(IHub.Asset storage asset) internal view returns (uint256) {
    uint256 drawnIndex = asset.getDrawnIndex();

    uint256 totalOwedRay = IOU.calculateTotalOwedRay({
      drawnShares: asset.drawnShares,
      premiumShares: asset.premiumShares,
      premiumOffsetRay: asset.premiumOffsetRay,
      deficitRay: asset.deficitRay,
      drawnIndex: drawnIndex
    });

    return
      asset.liquidity +
      asset.swept +
      totalOwedRay.fromRayUp() -
      asset.realizedFees -
      asset.getUnrealizedFees(drawnIndex);
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
  /// @dev Premium owed is not used in the interest rate calculation.
  /// @dev Uses last stored index; asset accrual should have already occurred.
  /// @dev Imprecision from downscaling `deficitRay` does not accumulate.
  function updateDrawnRate(IHub.Asset storage asset, uint256 assetId) internal {
    uint256 drawnIndex = asset.drawnIndex;
    uint256 newDrawnRate = IBasicInterestRateStrategy(asset.irStrategy).calculateInterestRate({
      assetId: assetId,
      liquidity: asset.liquidity,
      drawn: asset.getAssetDrawn(drawnIndex),
      deficit: asset.deficitRay.fromRayUp(),
      swept: asset.swept
    });
    asset.drawnRate = newDrawnRate.toUint96();

    emit IHub.UpdateAsset(assetId, drawnIndex, newDrawnRate, asset.realizedFees);
  }

  /// @notice Accrues interest and fees for the specified asset.
  function accrue(IHub.Asset storage asset) internal {
    if (asset.lastUpdateTimestamp == block.timestamp) {
      return;
    }

    uint256 drawnIndex = asset.getDrawnIndex();
    asset.realizedFees += asset.getUnrealizedFees(drawnIndex).toUint120();
    asset.drawnIndex = drawnIndex.toUint120();
    asset.lastUpdateTimestamp = block.timestamp.toUint40();
  }

  /// @notice Calculates the drawn index of a specified asset based on the existing drawn rate and index.
  function getDrawnIndex(IHub.Asset storage asset) internal view returns (uint256) {
    uint256 previousIndex = asset.drawnIndex;
    uint40 lastUpdateTimestamp = asset.lastUpdateTimestamp;
    if (
      lastUpdateTimestamp == block.timestamp || (asset.drawnShares == 0 && asset.premiumShares == 0)
    ) {
      return previousIndex;
    }
    return
      previousIndex.rayMulUp(
        MathUtils.calculateLinearInterest(asset.drawnRate, lastUpdateTimestamp)
      );
  }

  /// @notice Calculates the amount of fees derived from the index growth due to interest accrual.
  /// @param drawnIndex The current drawn index.
  function getUnrealizedFees(
    IHub.Asset storage asset,
    uint256 drawnIndex
  ) internal view returns (uint256) {
    uint256 previousIndex = asset.drawnIndex;
    if (previousIndex == drawnIndex) {
      return 0;
    }

    uint256 liquidityFee = asset.liquidityFee;
    if (liquidityFee == 0) {
      return 0;
    }

    uint120 drawnShares = asset.drawnShares;
    uint120 premiumShares = asset.premiumShares;
    int256 premiumOffsetRay = asset.premiumOffsetRay;
    uint256 deficitRay = asset.deficitRay;

    uint256 totalOwedRayAfter = IOU.calculateTotalOwedRay({
      drawnShares: drawnShares,
      premiumShares: premiumShares,
      premiumOffsetRay: premiumOffsetRay,
      deficitRay: deficitRay,
      drawnIndex: drawnIndex
    });

    uint256 totalOwedRayBefore = IOU.calculateTotalOwedRay({
      drawnShares: drawnShares,
      premiumShares: premiumShares,
      premiumOffsetRay: premiumOffsetRay,
      deficitRay: deficitRay,
      drawnIndex: previousIndex
    });

    return
      (totalOwedRayAfter.fromRayUp() - totalOwedRayBefore.fromRayUp()).percentMulDown(liquidityFee);
  }
}
