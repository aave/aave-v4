// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {SharesMath} from 'src/hub/libraries/SharesMath.sol';
import {Premium} from 'src/hub/libraries/Premium.sol';
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

  /// @notice Returns the total drawn assets amount for the specified asset.
  function drawn(IHub.Asset storage asset, uint256 drawnIndex) internal view returns (uint256) {
    return asset.drawnShares.rayMulUp(drawnIndex);
  }

  /// @notice Returns the total premium amount for the specified asset.
  function premium(IHub.Asset storage asset, uint256 drawnIndex) internal view returns (uint256) {
    return
      Premium
        .calculatePremiumRay({
          premiumShares: asset.premiumShares,
          drawnIndex: drawnIndex,
          premiumOffsetRay: asset.premiumOffsetRay
        })
        .fromRayUp();
  }

  /// @notice Returns the total amount owed for the specified asset, including drawn and premium.
  function totalOwed(IHub.Asset storage asset, uint256 drawnIndex) internal view returns (uint256) {
    return asset.drawn(drawnIndex) + asset.premium(drawnIndex);
  }

  function totalAddedAssets(IHub.Asset storage asset) internal view returns (uint256) {
    return asset.totalAddedAssets(asset.getDrawnIndex());
  }

  /// @notice Returns the total added assets for the specified asset.
  function totalAddedAssets(
    IHub.Asset storage asset,
    uint256 drawnIndex
  ) internal view returns (uint256) {
    uint256 aggregatedOwedRay = _calculateAggregatedOwedRay({
      drawnShares: asset.drawnShares,
      premiumShares: asset.premiumShares,
      premiumOffsetRay: asset.premiumOffsetRay,
      deficitRay: asset.deficitRay,
      drawnIndex: drawnIndex
    });

    return asset.liquidity + asset.swept + aggregatedOwedRay.fromRayUp();
  }

  function totalAddedShares(IHub.Asset storage asset) internal view returns (uint256) {
    return asset.addedShares + asset.unrealizedFeeShares();
  }

  function totalAddedShares(
    IHub.Asset storage asset,
    uint256 drawnIndex,
    uint256 previousIndex
  ) internal view returns (uint256) {
    return asset.addedShares + asset.getFeeShares(drawnIndex, previousIndex);
  }

  /// @notice Converts an amount of shares to the equivalent amount of added assets, rounding up.
  function toAddedAssetsUp(
    IHub.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    uint256 previousIndex = asset.drawnIndex;
    uint256 drawnIndex = asset.getDrawnIndex(previousIndex);
    return
      shares.toAssetsUp(
        asset.totalAddedAssets(drawnIndex),
        asset.totalAddedShares(drawnIndex, previousIndex)
      );
  }

  /// @notice Converts an amount of shares to the equivalent amount of added assets, rounding down.
  function toAddedAssetsDown(
    IHub.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    uint256 previousIndex = asset.drawnIndex;
    uint256 drawnIndex = asset.getDrawnIndex(previousIndex);
    return
      shares.toAssetsDown(
        asset.totalAddedAssets(drawnIndex),
        asset.totalAddedShares(drawnIndex, previousIndex)
      );
  }

  /// @notice Converts an amount of added assets to the equivalent amount of shares, rounding up.
  function toAddedSharesUp(
    IHub.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    uint256 previousIndex = asset.drawnIndex;
    uint256 drawnIndex = asset.getDrawnIndex(previousIndex);
    return
      assets.toSharesUp(
        asset.totalAddedAssets(drawnIndex),
        asset.totalAddedShares(drawnIndex, previousIndex)
      );
  }

  /// @notice Converts an amount of added assets to the equivalent amount of shares, rounding down.
  function toAddedSharesDown(
    IHub.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    uint256 previousIndex = asset.drawnIndex;
    uint256 drawnIndex = asset.getDrawnIndex(previousIndex);
    return
      assets.toSharesDown(
        asset.totalAddedAssets(drawnIndex),
        asset.totalAddedShares(drawnIndex, previousIndex)
      );
  }

  /// @notice Updates the drawn rate of a specified asset.
  /// @dev Premium debt is not used in the interest rate calculation.
  /// @dev Uses last stored index; asset accrual should have already occurred.
  /// @dev Imprecision from downscaling `deficitRay` does not accumulate.
  function updateDrawnRate(IHub.Asset storage asset, uint256 assetId) internal {
    uint256 drawnIndex = asset.drawnIndex;
    uint256 newDrawnRate = IBasicInterestRateStrategy(asset.irStrategy).calculateInterestRate({
      assetId: assetId,
      liquidity: asset.liquidity,
      drawn: asset.drawn(drawnIndex),
      deficit: asset.deficitRay.fromRayUp(),
      swept: asset.swept
    });
    asset.drawnRate = newDrawnRate.toUint96();

    emit IHub.UpdateAsset(assetId, drawnIndex, newDrawnRate);
  }

  /// @notice Accrues interest and fees for the specified asset.
  function accrue(
    IHub.Asset storage asset,
    mapping(uint256 => mapping(address => IHub.SpokeData)) storage spokes,
    uint256 assetId
  ) internal {
    if (asset.lastUpdateTimestamp == block.timestamp) {
      return;
    }

    uint256 previousIndex = asset.drawnIndex;
    uint256 drawnIndex = asset.getDrawnIndex(previousIndex);

    asset.drawnIndex = drawnIndex.toUint120();
    asset.lastUpdateTimestamp = block.timestamp.toUint40();

    uint120 feeShares = asset.getFeeShares(drawnIndex, previousIndex).toUint120();
    if (feeShares > 0) {
      address feeReceiver = asset.feeReceiver;
      asset.addedShares += feeShares;
      spokes[assetId][feeReceiver].addedShares += feeShares;
      emit IHub.AccrueFees(assetId, feeReceiver, feeShares);
    }
  }

  function getDrawnIndex(IHub.Asset storage asset) internal view returns (uint256) {
    return asset.getDrawnIndex({previousIndex: asset.drawnIndex});
  }

  /// @notice Calculates the drawn index of a specified asset based on the existing drawn rate and index.
  function getDrawnIndex(
    IHub.Asset storage asset,
    uint256 previousIndex
  ) internal view returns (uint256) {
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

  /// @notice Calculates the amount of unrealized fee shares since last accrual.
  function unrealizedFeeShares(IHub.Asset storage asset) internal view returns (uint256) {
    return asset.getFeeShares(asset.getDrawnIndex(), asset.drawnIndex);
  }

  /// @notice Calculates the amount of fee shares derived from the index growth due to interest accrual.
  /// @dev The true liquidity growth is always greater than accrued fees, even with 100.00% liquidity fee.
  function getFeeShares(
    IHub.Asset storage asset,
    uint256 drawnIndex,
    uint256 previousIndex
  ) internal view returns (uint256) {
    if (drawnIndex == previousIndex) {
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

    uint256 aggregatedOwedAfter = _calculateAggregatedOwedRay({
      drawnShares: drawnShares,
      premiumShares: premiumShares,
      premiumOffsetRay: premiumOffsetRay,
      deficitRay: deficitRay,
      drawnIndex: drawnIndex
    }).fromRayUp();

    uint256 aggregatedOwedBefore = _calculateAggregatedOwedRay({
      drawnShares: drawnShares,
      premiumShares: premiumShares,
      premiumOffsetRay: premiumOffsetRay,
      deficitRay: deficitRay,
      drawnIndex: previousIndex
    }).fromRayUp();

    uint256 feeAmount = (aggregatedOwedAfter - aggregatedOwedBefore).percentMulDown(liquidityFee);

    return
      feeAmount.toSharesDown(
        asset.liquidity + asset.swept + aggregatedOwedAfter - feeAmount,
        asset.addedShares
      );
  }

  /// @notice Calculates the aggregated owed amount for a specified asset, expressed in asset units and scaled by RAY.
  function _calculateAggregatedOwedRay(
    uint256 drawnShares,
    uint256 premiumShares,
    int256 premiumOffsetRay,
    uint256 deficitRay,
    uint256 drawnIndex
  ) internal pure returns (uint256) {
    uint256 premiumRay = Premium.calculatePremiumRay({
      premiumShares: premiumShares,
      premiumOffsetRay: premiumOffsetRay,
      drawnIndex: drawnIndex
    });
    return (drawnShares * drawnIndex) + premiumRay + deficitRay;
  }
}
