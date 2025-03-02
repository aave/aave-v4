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

  // todo add remaining: accrue interest, previewNextBorrowIndex, validate*

  // todo: option for cached object

  function totalAssets(DataTypes.Asset storage asset) internal view returns (uint256) {
    (uint256 baseDebt, uint256 outstandingPremium) = asset.previewInterest(
      asset.previewNextBorrowIndex()
    );
    return asset.availableLiquidity + baseDebt + outstandingPremium;
  }

  function totalShares(DataTypes.Asset storage asset) internal view returns (uint256) {
    return asset.suppliedShares;
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

  function getInterestRate(DataTypes.Asset storage asset) external view returns (uint256) {
    // @dev we truncate (ie `derayify()`) before `percentMul` as we only have accurate data until bps
    return
      asset.baseBorrowRate.percentMul(
        PercentageMath.PERCENTAGE_FACTOR + asset.riskPremium.derayify()
      );
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
          totalDebt: asset.baseDebt,
          reserveFactor: 0, // TODO
          assetId: asset.id,
          virtualUnderlyingBalance: asset.availableLiquidity, // without current liquidity change
          usingVirtualBalance: true
        })
      );
    asset.baseBorrowRate = baseBorrowRate;
  }

  // @dev Utilizes existing `asset.baseBorrowRate` & `asset.baseBorrowIndex`
  // @return nextBaseBorrowIndex (in ray)
  function previewNextBorrowIndex(DataTypes.Asset storage asset) internal view returns (uint256) {
    uint256 lastUpdateTimestamp = asset.lastUpdateTimestamp;
    if (lastUpdateTimestamp == block.timestamp) {
      return asset.baseBorrowIndex;
    }

    uint256 cumulatedBaseInterest = MathUtils.calculateLinearInterest(
      asset.baseBorrowRate,
      uint40(lastUpdateTimestamp)
    );
    return cumulatedBaseInterest.rayMul(asset.baseBorrowIndex);
  }

  // @dev Utilizes existing `asset.baseBorrowIndex` & `asset.riskPremium`
  function accrueInterest(DataTypes.Asset storage asset, uint256 nextBaseBorrowIndex) internal {
    (uint256 cumulatedBaseDebt, uint256 cumulatedOutstandingPremium) = asset.previewInterest(
      nextBaseBorrowIndex
    );

    asset.baseDebt = cumulatedBaseDebt;
    asset.outstandingPremium = cumulatedOutstandingPremium;
    asset.baseBorrowIndex = nextBaseBorrowIndex;
    asset.lastUpdateTimestamp = block.timestamp;
  }

  function previewInterest(
    DataTypes.Asset storage asset,
    uint256 nextBaseBorrowIndex
  ) internal view returns (uint256, uint256) {
    uint256 existingBaseDebt = asset.baseDebt;
    uint256 existingOutstandingPremium = asset.outstandingPremium;

    if (existingBaseDebt == 0 || asset.lastUpdateTimestamp == block.timestamp) {
      return (existingBaseDebt, existingOutstandingPremium);
    }

    uint256 cumulatedBaseDebt = existingBaseDebt.rayMul(nextBaseBorrowIndex).rayDiv(
      asset.baseBorrowIndex
    ); // precision loss avoidable

    return (
      cumulatedBaseDebt,
      existingOutstandingPremium +
        (cumulatedBaseDebt - existingBaseDebt).percentMul(asset.riskPremium.derayify())
    );
  }
}
