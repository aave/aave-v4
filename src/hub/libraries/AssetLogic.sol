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

library AssetLogic {
  using AssetLogic for IHub.Asset;
  using PercentageMath for uint256;
  using SharesMath for uint256;
  using WadRayMath for *;
  using MathUtils for uint256;
  using SafeCast for uint256;

  // drawn exchange rate does not include premium to accrue base rate separately
  function toDrawnAssetsUp(
    IHub.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.rayMulUp(asset.getDrawnIndex());
  }

  function toDrawnAssetsDown(
    IHub.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.rayMulDown(asset.getDrawnIndex());
  }

  function toDrawnSharesUp(
    IHub.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.rayDivUp(asset.getDrawnIndex());
  }

  function toDrawnSharesDown(
    IHub.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.rayDivDown(asset.getDrawnIndex());
  }

  function drawn(IHub.Asset storage asset) internal view returns (uint256) {
    return asset.drawnShares.rayMulUp(asset.getDrawnIndex());
  }

  function premium(IHub.Asset storage asset) internal view returns (uint256) {
    // sanity: utilize solc underflow check
    uint256 accruedPremium = asset.toDrawnAssetsUp(asset.premiumShares) - asset.premiumOffset;
    return asset.realizedPremium + accruedPremium;
  }

  function totalOwed(IHub.Asset storage asset) internal view returns (uint256) {
    return asset.drawn() + asset.premium();
  }

  function totalAddedAssets(IHub.Asset storage asset) internal view returns (uint256) {
    return asset.liquidity + asset.swept + asset.deficit + asset.totalOwed();
  }

  function totalAddedShares(IHub.Asset storage asset) internal view returns (uint256) {
    return asset.addedShares + asset.unrealizedFeeShares();
  }

  function toAddedAssetsUp(
    IHub.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.toAssetsUp(asset.totalAddedAssets(), asset.totalAddedShares());
  }

  function toAddedAssetsDown(
    IHub.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.toAssetsDown(asset.totalAddedAssets(), asset.totalAddedShares());
  }

  function toAddedSharesUp(
    IHub.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.toSharesUp(asset.totalAddedAssets(), asset.totalAddedShares());
  }

  function toAddedSharesDown(
    IHub.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.toSharesDown(asset.totalAddedAssets(), asset.totalAddedShares());
  }

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

  /**
   * @dev Accrues interest and fees for the specified asset.
   * @param asset The data struct of the asset with accruing interest
   * @param feeReceiver The data struct of the fee receiver spoke associated with the asset
   */
  function accrue(
    IHub.Asset storage asset,
    uint256 assetId,
    IHub.SpokeData storage feeReceiver
  ) internal {
    uint256 drawnIndex = asset.getDrawnIndex();
    uint256 indexDelta = drawnIndex.uncheckedSub(asset.drawnIndex);

    asset.drawnIndex = drawnIndex.toUint128();
    asset.lastUpdateTimestamp = block.timestamp.toUint32();

    uint128 feeShares = asset.getFeeShares(indexDelta).toUint128();
    if (feeShares > 0) {
      feeReceiver.addedShares += feeShares;
      asset.addedShares += feeShares;
      emit IHub.AccrueFees(assetId, feeShares);
    }
  }

  /**
   * @dev Calculates the drawn index based on the base drawn rate and the previous index.
   * @param asset The data struct of the asset whose index is increasing.
   * @return The resulting drawn index.
   */
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

  /**
   * @dev Calculates the amount of fee shares derived from the index growth due to interest accrual.
   * @dev The true liquidity growth is always greater than accrued fees, even with 100.00% liquidity fee.
   * @param asset The data struct of the asset whose index is increasing.
   * @param indexDelta The delta between the current and next drawn index.
   * @return The amount of shares corresponding to the fees.
   */
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

  /**
   * @dev Calculates the amount of fee shares generated from the asset's accrued interest.
   * @dev It calculates the updated drawn index on the fly using the current index and the drawn rate.
   * @param asset The data struct of the asset with accruing interest
   * @return The amount of shares corresponding to the fees
   */
  function unrealizedFeeShares(IHub.Asset storage asset) internal view returns (uint256) {
    return asset.getFeeShares(asset.getDrawnIndex().uncheckedSub(asset.drawnIndex));
  }
}
