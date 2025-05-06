// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WadRayMathExtended} from 'src/libraries/math/WadRayMathExtended.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {SharesMath} from 'src/libraries/math/SharesMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';

library AssetLogic {
  using AssetLogic for DataTypes.Asset;
  using PercentageMath for uint256;
  using SharesMath for uint256;
  using WadRayMathExtended for uint256;

  // todo: option for cached object
  // todo: add virtual offset for inflation attack

  // debt exchange rate does not incl premiumDebt to accrue base rate separately
  function toDrawnAssetsUp(
    DataTypes.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.rayMulUp(asset.previewIndex());
  }
  function toDrawnAssetsDown(
    DataTypes.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.rayMulDown(asset.previewIndex());
  }

  function toDrawnSharesUp(
    DataTypes.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.rayDivUp(asset.previewIndex());
  }
  function toDrawnSharesDown(
    DataTypes.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.rayDivDown(asset.previewIndex());
  }

  function baseDebt(DataTypes.Asset storage asset) internal view returns (uint256) {
    return asset.baseDrawnShares.rayMulUp(asset.previewIndex());
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
    return asset.suppliedShares;
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

  // risk premium interest rate is calculated offchain
  function baseInterestRate(DataTypes.Asset storage asset) internal view returns (uint256) {
    return asset.baseBorrowRate;
  }

  function updateBorrowRate(
    DataTypes.Asset storage asset,
    uint256 liquidityAdded,
    uint256 liquidityTaken
  ) internal {
    asset.baseBorrowRate = asset.config.irStrategy.calculateInterestRates(
      DataTypes.CalculateInterestRatesParams({
        liquidityAdded: liquidityAdded,
        liquidityTaken: liquidityTaken,
        totalDebt: asset.baseDebt(),
        reserveFactor: 0, // TODO
        assetId: asset.id,
        virtualUnderlyingBalance: asset.availableLiquidity, // without current liquidity change
        usingVirtualBalance: true
      })
    );
  }

  // @dev Utilizes existing `asset.baseBorrowRate`
  function accrue(DataTypes.Asset storage asset) internal {
    asset.baseDebtIndex = asset.previewIndex();
    asset.lastUpdateTimestamp = block.timestamp;
  }

  function previewIndex(DataTypes.Asset storage asset) internal view returns (uint256) {
    uint256 baseDebtIndex = asset.baseDebtIndex;
    uint256 lastUpdateTimestamp = asset.lastUpdateTimestamp;
    if (lastUpdateTimestamp == block.timestamp || asset.baseDrawnShares == 0) {
      return baseDebtIndex;
    }
    return
      baseDebtIndex.rayMulUp(
        MathUtils.calculateLinearInterest(asset.baseBorrowRate, uint40(lastUpdateTimestamp))
      );
  }
}
