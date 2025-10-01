// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {SharesMath} from 'src/hub/libraries/SharesMath.sol';
import {IBasicInterestRateStrategy} from 'src/hub/interfaces/IBasicInterestRateStrategy.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

/// @title AssetLogic library
/// @author Aave Labs
/// @notice Implements the logic and calculations for asset data.
library AssetLogic {
  using AssetLogic for IHub.Asset;
  using PercentageMath for uint256;
  using SharesMath for uint256;
  using WadRayMath for *;
  using MathUtils for uint256;
  using SafeCast for uint256;

  /// @notice Converts an amount of shares to the equivalent amount of drawn assets, rounding up.
  /// @dev Drawn index does not account for premium, in order to accrue drawn assets separately.
  /// @param asset The data struct of the asset being converted.
  /// @param shares The amount of shares to be converted.
  /// @return The resulting amount of drawn assets.
  function toDrawnAssetsUp(
    IHub.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.rayMulUp(asset.getDrawnIndex());
  }

  /// @notice Converts an amount of shares to the equivalent amount of drawn assets, rounding down.
  /// @dev Drawn index does not account for premium, in order to accrue drawn assets separately.
  /// @param asset The data struct of the asset being converted.
  /// @param shares The amount of shares to be converted.
  /// @return The resulting amount of drawn assets.
  function toDrawnAssetsDown(
    IHub.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.rayMulDown(asset.getDrawnIndex());
  }

  /// @notice Converts an amount of drawn assets to the equivalent amount of shares, rounding up.
  /// @param asset The data struct of the asset being converted.
  /// @param assets The amount of drawn assets to be converted.
  /// @return The resulting amount of shares.
  function toDrawnSharesUp(
    IHub.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.rayDivUp(asset.getDrawnIndex());
  }

  /// @notice Converts an amount of drawn assets to the equivalent amount of shares, rounding down.
  /// @param asset The data struct of the asset being converted.
  /// @param assets The amount of drawn assets to be converted.
  /// @return The resulting amount of shares.
  function toDrawnSharesDown(
    IHub.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.rayDivDown(asset.getDrawnIndex());
  }

  /// @notice Returns the total drawn assets amount for the specified asset.
  /// @param asset The data struct of the asset.
  /// @return The total drawn assets.
  function drawn(IHub.Asset storage asset) internal view returns (uint256) {
    return asset.drawnShares.rayMulUp(asset.getDrawnIndex());
  }

  /// @notice Returns the total premium amount for the specified asset.
  /// @param asset The data struct of the asset.
  /// @return The total premium.
  function premium(IHub.Asset storage asset) internal view returns (uint256) {
    // sanity: utilize solc underflow check
    uint256 accruedPremium = asset.toDrawnAssetsUp(asset.premiumShares) - asset.premiumOffset;
    return asset.realizedPremium + accruedPremium;
  }

  /// @notice Returns the total amount owed for the specified asset, including drawn and premium.
  /// @param asset The data struct of the asset.
  /// @return The total amount owed.
  function totalOwed(IHub.Asset storage asset) internal view returns (uint256) {
    return asset.drawn() + asset.premium();
  }

  /// @notice Returns the total added assets for the specified asset.
  /// @param asset The data struct of the asset.
  /// @return The total added assets.
  function totalAddedAssets(IHub.Asset storage asset) internal view returns (uint256) {
    return asset.liquidity + asset.swept + asset.deficit + asset.totalOwed();
  }

  /// @notice Returns the total added shares for the specified asset.
  /// @param asset The data struct of the asset.
  /// @return The total added shares.
  function totalAddedShares(IHub.Asset storage asset) internal view returns (uint256) {
    return
      asset.addedShares + asset.getFeeShares(asset.getDrawnIndex().uncheckedSub(asset.drawnIndex));
  }

  /// @notice Converts an amount of shares to the equivalent amount of added assets, rounding up.
  /// @param asset The data struct of the asset being converted.
  /// @param shares The amount of shares to be converted.
  /// @return The resulting amount of added assets.
  function toAddedAssetsUp(
    IHub.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.toAssetsUp(asset.totalAddedAssets(), asset.totalAddedShares());
  }

  /// @notice Converts an amount of shares to the equivalent amount of added assets, rounding down.
  /// @param asset The data struct of the asset being converted.
  /// @param shares The amount of shares to be converted.
  /// @return The resulting amount of added assets.
  function toAddedAssetsDown(
    IHub.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.toAssetsDown(asset.totalAddedAssets(), asset.totalAddedShares());
  }

  /// @notice Converts an amount of added assets to the equivalent amount of shares, rounding up.
  /// @param asset The data struct of the asset being converted.
  /// @param assets The amount of added assets to be converted.
  /// @return The resulting amount of shares.
  function toAddedSharesUp(
    IHub.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.toSharesUp(asset.totalAddedAssets(), asset.totalAddedShares());
  }

  /// @notice Converts an amount of added assets to the equivalent amount of shares, rounding down.
  /// @param asset The data struct of the asset being converted.
  /// @param assets The amount of added assets to be converted.
  /// @return The resulting amount of shares.
  function toAddedSharesDown(
    IHub.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.toSharesDown(asset.totalAddedAssets(), asset.totalAddedShares());
  }

  /// @notice Updates the drawn rate of a specified asset.
  /// @dev Premium debt is not used in the interest rate calculation.
  /// @param asset The data struct of the asset.
  /// @param assetId The identifier of the asset.
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
    emit IHub.UpdateAsset(assetId, asset.drawnIndex, newDrawnRate, asset.lastUpdateTimestamp);
  }

  /// @notice Accrues interest and fees for the specified asset.
  /// @param asset The data struct of the asset.
  /// @param assetId The identifier of the asset.
  /// @param feeReceiver The data struct of the fee receiver spoke associated with the asset.
  function accrue(
    IHub.Asset storage asset,
    uint256 assetId,
    IHub.SpokeData storage feeReceiver
  ) internal {
    uint256 drawnIndex = asset.getDrawnIndex();
    uint256 indexDelta = drawnIndex.uncheckedSub(asset.drawnIndex);

    asset.drawnIndex = drawnIndex.toUint128();
    asset.lastUpdateTimestamp = block.timestamp.toUint40();

    uint128 feeShares = asset.getFeeShares(indexDelta).toUint128();
    if (feeShares > 0) {
      feeReceiver.addedShares += feeShares;
      asset.addedShares += feeShares;
      emit IHub.AccrueFees(assetId, feeShares);
    }
  }

  /// @notice Calculates the drawn index of a specified asset based on the drawn rate and the previous index.
  /// @param asset The data struct of the asset.
  /// @return The resulting drawn index.
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
        MathUtils.calculateLinearInterest(asset.drawnRate, uint40(lastUpdateTimestamp))
      );
  }

  /// @notice Calculates the amount of fee shares derived from the index growth due to interest accrual.
  /// @dev The true liquidity growth is always greater than accrued fees, even with 100.00% liquidity fee.
  /// @param asset The data struct of the asset.
  /// @param indexDelta The delta between the current and next drawn index.
  /// @return The amount of fee shares.
  function getFeeShares(
    IHub.Asset storage asset,
    uint256 indexDelta
  ) internal view returns (uint256) {
    if (indexDelta == 0) return 0;
    uint256 liquidityFee = asset.liquidityFee;
    if (liquidityFee == 0) return 0;

    // @dev we do not simplify further to avoid overestimating the liquidity growth
    uint256 feesAmount = (asset.drawnShares.rayMulDown(indexDelta) +
      asset.premiumShares.rayMulDown(indexDelta)).percentMulDown(liquidityFee);

    return feesAmount.toSharesDown(asset.totalAddedAssets() - feesAmount, asset.addedShares);
  }

  /// @notice Calculates the amount of fee shares generated from the asset's accrued interest.
  /// @dev Calculates the updated drawn index on the fly using the current index and the drawn rate.
  /// @param asset The data struct of the asset.
  /// @return The amount of fee shares.
  function unrealizedFeeShares(IHub.Asset storage asset) internal view returns (uint256) {
    return asset.getFeeShares(asset.getDrawnIndex().uncheckedSub(asset.drawnIndex));
  }
}
