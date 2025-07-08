// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBasicInterestRateStrategy} from 'src/interfaces/IBasicInterestRateStrategy.sol';
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {WadRayMathExtended} from 'src/libraries/math/WadRayMathExtended.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {SharesMath} from 'src/libraries/math/SharesMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {PercentageMathExtended} from 'src/libraries/math/PercentageMathExtended.sol';

library AssetLogic {
  using AssetLogic for DataTypes.Asset;
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;
  using SharesMath for uint256;
  using WadRayMathExtended for uint256;

  // todo: option for cached object
  // todo: add virtual offset for inflation attack

  // debt exchange rate does not incl premiumDebt to accrue base rate separately
  function toDrawnAssetsUp(
    DataTypes.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.rayMulUp(asset.previewDrawnIndex());
  }

  function toDrawnAssetsDown(
    DataTypes.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.rayMulDown(asset.previewDrawnIndex());
  }

  function toDrawnSharesUp(
    DataTypes.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.rayDivUp(asset.previewDrawnIndex());
  }

  function toDrawnSharesDown(
    DataTypes.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.rayDivDown(asset.previewDrawnIndex());
  }

  function baseDebt(DataTypes.Asset storage asset) internal view returns (uint256) {
    return asset.baseDrawnShares.rayMulUp(asset.previewDrawnIndex());
  }

  function premiumDebt(DataTypes.Asset storage asset) internal view returns (uint256) {
    // sanity: utilize solc underflow check
    uint256 accruedPremium = asset.toDrawnAssetsUp(asset.premiumDrawnShares) - asset.premiumOffset;
    return asset.realizedPremium + accruedPremium;
  }

  function debt(DataTypes.Asset storage asset) internal view returns (uint256, uint256) {
    return (asset.baseDebt(), asset.premiumDebt());
  }

  function totalDebt(DataTypes.Asset storage asset) internal view returns (uint256) {
    return asset.baseDebt() + asset.premiumDebt();
  }

  function totalSuppliedAssets(DataTypes.Asset storage asset) internal view returns (uint256) {
    return asset.availableLiquidity + asset.totalDebt();
  }

  function totalSuppliedShares(DataTypes.Asset storage asset) internal view returns (uint256) {
    return
      asset.suppliedShares +
      asset.previewFeeShares(asset.previewDrawnIndex() - asset.baseDebtIndex);
  }

  function toSuppliedAssetsUp(
    DataTypes.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.toAssetsUp(asset.totalSuppliedAssets(), asset.totalSuppliedShares());
  }

  function toSuppliedAssetsDown(
    DataTypes.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.toAssetsDown(asset.totalSuppliedAssets(), asset.totalSuppliedShares());
  }

  function toSuppliedSharesUp(
    DataTypes.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.toSharesUp(asset.totalSuppliedAssets(), asset.totalSuppliedShares());
  }

  function toSuppliedSharesDown(
    DataTypes.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.toSharesDown(asset.totalSuppliedAssets(), asset.totalSuppliedShares());
  }

  function updateBorrowRate(
    DataTypes.Asset storage asset,
    uint256 assetId,
    uint256 liquidityAdded,
    uint256 liquidityTaken
  ) internal {
    asset.baseBorrowRate = IBasicInterestRateStrategy(asset.config.irStrategy)
      .calculateInterestRate({
        assetId: assetId,
        availableLiquidity: asset.availableLiquidity,
        totalDebt: asset.baseDebt(),
        liquidityAdded: liquidityAdded,
        liquidityTaken: liquidityTaken
      });
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
    uint256 drawnIndex = asset.previewDrawnIndex();
    uint256 feeShares = asset.previewFeeShares(drawnIndex - asset.baseDebtIndex);

    // Accrue interest and fees
    asset.baseDebtIndex = drawnIndex;
    if (feeShares > 0) {
      feeReceiver.suppliedShares += feeShares;
      asset.suppliedShares += feeShares;
      emit ILiquidityHub.AccrueFees(assetId, feeShares);
    }

    asset.lastUpdateTimestamp = block.timestamp;
    emit ILiquidityHub.DrawnIndexUpdate(assetId, drawnIndex, block.timestamp);
  }

  /**
   * @dev Calculates the drawn index based on the borrow rate and the previous index.
   * @param asset The data struct of the asset whose index is increasing.
   * @return The resulting drawn index.
   */
  function previewDrawnIndex(DataTypes.Asset storage asset) internal view returns (uint256) {
    uint256 previousIndex = asset.baseDebtIndex;
    uint256 lastUpdateTimestamp = asset.lastUpdateTimestamp;
    if (lastUpdateTimestamp == block.timestamp || asset.baseDrawnShares == 0) {
      return previousIndex;
    }
    return
      previousIndex.rayMulUp(
        MathUtils.calculateLinearInterest(asset.baseBorrowRate, uint40(lastUpdateTimestamp))
      );
  }

  /**
   * @dev Calculates the amount of fee shares derived from the index growth due to interest accrual.
   * @param asset The data struct of the asset whose index is increasing.
   * @param indexDelta The increase in the asset index resulting from interest accrual.
   * @return The amount of shares corresponding to the fees
   */
  function previewFeeShares(
    DataTypes.Asset storage asset,
    uint256 indexDelta
  ) internal view returns (uint256) {
    uint256 liquidityFee = asset.config.liquidityFee;
    if (indexDelta == 0 || liquidityFee == 0) {
      return 0;
    }
    // liquidity growth is always greater than accrued fees, even with 100.00% liquidity fee
    uint256 feesAmount = indexDelta
      .rayMulDown(asset.baseDrawnShares + asset.premiumDrawnShares)
      .percentMulDown(liquidityFee);

    return feesAmount.toSharesDown(asset.totalSuppliedAssets() - feesAmount, asset.suppliedShares);
  }

  /**
   * @dev Calculates the amount of fee shares generated from the asset's accrued interest.
   * @dev It calculates the updated drawn index on the fly using the current index and the borrow rate.
   * @param asset The data struct of the asset with accruing interest
   * @return The amount of shares corresponding to the fees
   */
  function unrealizedFeeShares(DataTypes.Asset storage asset) internal view returns (uint256) {
    return asset.previewFeeShares(asset.previewDrawnIndex() - asset.baseDebtIndex);
  }
}
