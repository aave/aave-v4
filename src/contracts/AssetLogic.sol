// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IReserveInterestRateStrategy} from 'src/interfaces/IReserveInterestRateStrategy.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

import {MathUtils} from 'src/contracts/MathUtils.sol';
import {SharesMath} from 'src/contracts/SharesMath.sol';
import {PercentageMath} from 'src/contracts/PercentageMath.sol';
import {WadRayMath} from 'src/contracts/WadRayMath.sol';

library AssetLogic {
  using AssetLogic for DataTypes.Asset;
  using PercentageMath for uint256;
  using SharesMath for uint256;
  using WadRayMath for uint256;

  // todo add remaining: accrue interest, validate*

  // todo: option for cached object

  function totalAssets(DataTypes.Asset storage asset) internal view returns (uint256) {
    // totalSupplyAssets = availableLiquidity + drawnAssets + totalPremium
    (uint256 drawnAssets, uint256 totalPremium) = asset.previewInterest();
    return asset.availableLiquidity + drawnAssets + totalPremium;
  }

  function getTotalDrawnAssets(DataTypes.Asset storage asset) internal view returns (uint256) {
    (uint256 drawnAssets, ) = asset.previewInterest();
    return drawnAssets;
  }

  function totalShares(DataTypes.Asset storage asset) internal view returns (uint256) {
    return asset.suppliedShares;
  }

  function getTotalDrawnShares(DataTypes.Asset storage asset) internal view returns (uint256) {
    return asset.drawnShares;
  }

  // @dev So solc doesn't inline
  function getTotalAssets(DataTypes.Asset storage asset) external view returns (uint256) {
    return asset.totalAssets();
  }

  function convertToSharesUp(
    DataTypes.Asset storage asset,
    uint256 assets
  ) external view returns (uint256) {
    return assets.toSharesUp(asset.totalAssets(), asset.totalShares());
  }

  function convertToSharesDown(
    DataTypes.Asset storage asset,
    uint256 assets
  ) external view returns (uint256) {
    return assets.toSharesDown(asset.totalAssets(), asset.totalShares());
  }

  function convertToAssetsUp(
    DataTypes.Asset storage asset,
    uint256 shares
  ) external view returns (uint256) {
    return shares.toAssetsUp(asset.totalAssets(), asset.totalShares());
  }

  function convertToAssetsDown(
    DataTypes.Asset storage asset,
    uint256 shares
  ) external view returns (uint256) {
    return shares.toAssetsDown(asset.totalAssets(), asset.totalShares());
  }

  function convertToDrawnSharesUp(
    DataTypes.Asset storage asset,
    uint256 assets
  ) external view returns (uint256) {
    return assets.toSharesUp(asset.getTotalDrawnAssets(), asset.getTotalDrawnShares());
  }

  function convertToDrawnSharesDown(
    DataTypes.Asset storage asset,
    uint256 assets
  ) external view returns (uint256) {
    return assets.toSharesDown(asset.getTotalDrawnAssets(), asset.getTotalDrawnShares());
  }

  function convertToDrawnAssetsUp(
    DataTypes.Asset storage asset,
    uint256 shares
  ) external view returns (uint256) {
    return shares.toAssetsUp(asset.getTotalDrawnAssets(), asset.getTotalDrawnShares());
  }

  function convertToDrawnAssetsDown(
    DataTypes.Asset storage asset,
    uint256 shares
  ) external view returns (uint256) {
    return shares.toAssetsDown(asset.getTotalDrawnAssets(), asset.getTotalDrawnShares());
  }

  function getInterestRate(DataTypes.Asset storage asset) external view returns (uint256) {
    // @dev we truncate (ie `derayify()`) before `percentMul` as we only have accurate data until bps
    return asset.baseBorrowRate;
  }

  function updateBorrowRate(
    DataTypes.Asset storage asset,
    uint256 liquidityAdded,
    uint256 liquidityTaken
  ) external {
    uint256 baseBorrowRate = IReserveInterestRateStrategy(asset.config.irStrategy)
      .calculateInterestRates(
        DataTypes.CalculateInterestRatesParams({
          liquidityAdded: liquidityAdded,
          liquidityTaken: liquidityTaken,
          totalDebt: asset.drawnAssets,
          reserveFactor: 0, // TODO
          assetId: asset.id,
          virtualUnderlyingBalance: asset.availableLiquidity, // without current liquidity change
          usingVirtualBalance: true
        })
      );
    asset.baseBorrowRate = baseBorrowRate;
  }

  function accrueInterest(DataTypes.Asset storage asset) internal {
    (uint256 cumulatedBaseDebt, uint256 cumulatedOutstandingPremium) = asset.previewInterest();

    asset.drawnAssets = cumulatedBaseDebt;
    asset.totalPremium = cumulatedOutstandingPremium;
    asset.lastUpdateTimestamp = block.timestamp;
  }

  function previewInterest(DataTypes.Asset storage asset) internal view returns (uint256, uint256) {
    uint256 existingBaseDebt = asset.drawnAssets;
    uint256 existingOutstandingPremium = asset.totalPremium;

    if (existingBaseDebt == 0 || asset.lastUpdateTimestamp == block.timestamp) {
      return (existingBaseDebt, existingOutstandingPremium);
    }

    uint256 cumulatedBaseDebt = existingBaseDebt.rayMul(
      MathUtils.calculateLinearInterest(asset.baseBorrowRate, uint40(asset.lastUpdateTimestamp))
    );

    return (cumulatedBaseDebt, existingOutstandingPremium);
  }
}
