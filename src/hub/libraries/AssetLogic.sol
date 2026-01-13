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

  /// @notice Returns the total added assets for the specified asset.
  function totalAddedAssets(IHub.Asset storage asset) internal view returns (uint256) {
    (uint256 supplyIndex, , ) = asset.getIndexesAndFees();
    return asset.addedShares.rayMulDown(supplyIndex);
  }

  /// @notice Converts an amount of shares to the equivalent amount of added assets, rounding up.
  function toAddedAssetsUp(
    IHub.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    (uint256 supplyIndex, , ) = asset.getIndexesAndFees();
    return shares.rayMulUp(supplyIndex);
  }

  /// @notice Converts an amount of shares to the equivalent amount of added assets, rounding down.
  function toAddedAssetsDown(
    IHub.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    (uint256 supplyIndex, , ) = asset.getIndexesAndFees();
    return shares.rayMulDown(supplyIndex);
  }

  /// @notice Converts an amount of added assets to the equivalent amount of shares, rounding up.
  function toAddedSharesUp(
    IHub.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    (uint256 supplyIndex, , ) = asset.getIndexesAndFees();
    return assets.rayDivUp(supplyIndex);
  }

  /// @notice Converts an amount of added assets to the equivalent amount of shares, rounding down.
  function toAddedSharesDown(
    IHub.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    (uint256 supplyIndex, , ) = asset.getIndexesAndFees();
    return assets.rayDivDown(supplyIndex);
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

    emit IHub.UpdateAsset(assetId, drawnIndex, newDrawnRate, asset.realizedFees);
  }

  /// @notice Accrues interest and fees for the specified asset.
  function accrue(IHub.Asset storage asset) internal {
    if (asset.lastUpdateTimestamp == block.timestamp) {
      return;
    }

    (uint256 supplyIndex, uint256 drawnIndex, uint256 fees) = asset.getIndexesAndFees();
    asset.realizedFees += fees.toUint120();
    asset.drawnIndex = drawnIndex.toUint120();
    asset.supplyIndex = supplyIndex.toUint120();
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

  function getIndexesAndFees(
    IHub.Asset storage asset
  ) internal view returns (uint256, uint256, uint256) {
    uint256 previousDrawnIndex = asset.drawnIndex;
    uint256 previousSupplyIndex = asset.supplyIndex;
    uint40 lastUpdateTimestamp = asset.lastUpdateTimestamp;
    if (
      lastUpdateTimestamp == block.timestamp || (asset.drawnShares == 0 && asset.premiumShares == 0)
    ) {
      return (previousDrawnIndex, previousSupplyIndex, 0);
    }

    uint256 drawnIndex = previousDrawnIndex.rayMulUp(
      MathUtils.calculateLinearInterest(asset.drawnRate, lastUpdateTimestamp)
    );

    uint256 growth;
    {
      uint120 drawnShares = asset.drawnShares;
      uint120 premiumShares = asset.premiumShares;
      int256 premiumOffsetRay = asset.premiumOffsetRay;
      uint256 deficitRay = asset.deficitRay;

      growth =
        _calculateAggregatedOwedRay({
          drawnShares: drawnShares,
          premiumShares: premiumShares,
          premiumOffsetRay: premiumOffsetRay,
          deficitRay: deficitRay,
          drawnIndex: drawnIndex
        }).fromRayUp() -
        _calculateAggregatedOwedRay({
          drawnShares: drawnShares,
          premiumShares: premiumShares,
          premiumOffsetRay: premiumOffsetRay,
          deficitRay: deficitRay,
          drawnIndex: previousDrawnIndex
        }).fromRayUp();
    }
    uint256 fees = growth.percentMulDown(asset.liquidityFee);

    uint256 supplyIndex = cumulateToIndex(
      previousSupplyIndex,
      asset.addedShares.rayMulDown(previousSupplyIndex),
      growth - fees
    );

    return (supplyIndex, drawnIndex, fees);
  }

  function cumulateToIndex(
    uint256 index,
    uint256 totalAssets,
    uint256 amount
  ) internal pure returns (uint256) {
    // next index is calculated this way: `((amount / totalAssets) + 1) * index`
    // division `amount / totalAssets` done in ray for precision
    return (amount.toRay().rayDivDown(totalAssets.toRay()) + WadRayMath.RAY).rayMulDown(index);
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
