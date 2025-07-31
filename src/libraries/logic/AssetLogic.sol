// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBasicInterestRateStrategy} from 'src/interfaces/IBasicInterestRateStrategy.sol';
import {IHub} from 'src/interfaces/IHub.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {SharesMath} from 'src/libraries/math/SharesMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';

library AssetLogic {
  using AssetLogic for DataTypes.Asset;
  using PercentageMath for uint256;
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using MathUtils for uint256;

  // todo: option for cached object
  // todo: add virtual offset for inflation attack

  // drawn exchange rate does not include premium to accrue base rate separately
  function toDrawnAssetsUp(
    DataTypes.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.rayMulUp(asset.getDrawnIndex());
  }

  function toDrawnAssetsDown(
    DataTypes.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.rayMulDown(asset.getDrawnIndex());
  }

  function toDrawnSharesUp(
    DataTypes.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.rayDivUp(asset.getDrawnIndex());
  }

  function toDrawnSharesDown(
    DataTypes.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.rayDivDown(asset.getDrawnIndex());
  }

  function drawn(DataTypes.Asset storage asset) internal view returns (uint256) {
    return asset.drawnShares.rayMulUp(asset.getDrawnIndex());
  }

  function premium(DataTypes.Asset storage asset) internal view returns (uint256) {
    // sanity: utilize solc underflow check
    uint256 accruedPremium = asset.toDrawnAssetsUp(asset.premiumShares) - asset.premiumOffset;
    return asset.realizedPremium + accruedPremium;
  }
  function totalOwed(DataTypes.Asset storage asset) internal view returns (uint256) {
    return asset.drawn() + asset.premium();
  }

  function totalAddedAssets(DataTypes.Asset storage asset) internal view returns (uint256) {
    return asset.liquidity + asset.deficit + asset.totalOwed();
  }

  function totalAddedShares(DataTypes.Asset storage asset) internal view returns (uint256) {
    return asset.addedShares + asset.getFeeShares(asset.getDrawnIndex(), asset.drawnIndex);
  }

  function toAddedAssetsUp(
    DataTypes.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.toAssetsUp(asset.totalAddedAssets(), asset.totalAddedShares());
  }

  function toAddedAssetsDown(
    DataTypes.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.toAssetsDown(asset.totalAddedAssets(), asset.totalAddedShares());
  }

  function toAddedSharesUp(
    DataTypes.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.toSharesUp(asset.totalAddedAssets(), asset.totalAddedShares());
  }

  function toAddedSharesDown(
    DataTypes.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.toSharesDown(asset.totalAddedAssets(), asset.totalAddedShares());
  }

  function updateDrawnRate(DataTypes.Asset storage asset, uint256 assetId) internal {
    uint256 newBorrowRate = IBasicInterestRateStrategy(asset.config.irStrategy)
      .calculateInterestRate({
        assetId: assetId,
        liquidity: asset.liquidity,
        drawn: asset.drawn(),
        premium: asset.premium()
      });
    asset.drawnRate = newBorrowRate;

    // asset accrual should have already occurred
    emit IHub.AssetUpdated(assetId, asset.drawnIndex, newBorrowRate, asset.lastUpdateTimestamp);
  }

  /**
   * @dev Accrues interest and fees for the specified asset.
   * @param asset The data struct of the asset with accruing interest
   * @param feeReceiver The data struct of the fee receiver spoke associated with the asset
   */
  function accrue(
    DataTypes.Asset storage asset,
    uint256 assetId,
    DataTypes.SpokeData storage feeReceiver
  ) internal {
    uint256 drawnIndex = asset.getDrawnIndex();
    uint256 feeShares = asset.getFeeShares(drawnIndex, asset.drawnIndex);

    // Accrue interest and fees
    asset.drawnIndex = drawnIndex;
    if (feeShares > 0) {
      feeReceiver.addedShares += feeShares;
      asset.addedShares += feeShares;
      emit IHub.AccrueFees(assetId, feeShares);
    }

    asset.lastUpdateTimestamp = block.timestamp;
  }

  /**
   * @dev Calculates the drawn index based on the base drawn rate and the previous index.
   * @param asset The data struct of the asset whose index is increasing.
   * @return The resulting drawn index.
   */
  function getDrawnIndex(DataTypes.Asset storage asset) internal view returns (uint256) {
    uint256 previousIndex = asset.drawnIndex;
    uint256 lastUpdateTimestamp = asset.lastUpdateTimestamp;
    if (lastUpdateTimestamp == block.timestamp || asset.drawnShares == 0) {
      return previousIndex;
    }
    return
      previousIndex.rayMulUp(
        MathUtils.calculateLinearInterest(asset.drawnRate, uint40(lastUpdateTimestamp))
      );
  }

  /**
   * @dev Calculates the amount of fee shares derived from the index growth due to interest accrual.
   * @param asset The data struct of the asset whose index is increasing.
   * @param nextDrawnIndex The next value of the asset drawn index resulting from interest accrual.
   * @param currentDrawnIndex The current value of the asset drawn index.
   * @return The amount of shares corresponding to the fees.
   */
  function getFeeShares(
    DataTypes.Asset storage asset,
    uint256 nextDrawnIndex,
    uint256 currentDrawnIndex
  ) internal view returns (uint256) {
    uint256 liquidityFee = asset.config.liquidityFee;
    if (nextDrawnIndex == currentDrawnIndex || liquidityFee == 0) {
      return 0;
    }

    // liquidity growth is always greater than accrued fees, even with 100.00% liquidity fee
    // prettier-ignore
    uint256 feesAmount = (
      asset.drawnShares.rayMulDown(nextDrawnIndex - currentDrawnIndex) +
      asset.premiumShares.rayMulDown(nextDrawnIndex) - asset.premiumOffset
    ).percentMulDown(liquidityFee);

    return feesAmount.toSharesDown(asset.totalAddedAssets() - feesAmount, asset.addedShares);
  }

  /**
   * @dev Calculates the amount of fee shares generated from the asset's accrued interest.
   * @dev It calculates the updated drawn index on the fly using the current index and the drawn rate.
   * @param asset The data struct of the asset with accruing interest
   * @return The amount of shares corresponding to the fees
   */
  function unrealizedFeeShares(DataTypes.Asset storage asset) internal view returns (uint256) {
    return asset.getFeeShares(asset.getDrawnIndex(), asset.drawnIndex);
  }
}
