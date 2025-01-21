pragma solidity ^0.8.0;

import {Asset} from 'src/contracts/LiquidityHub.sol';
import {SharesMath} from 'src/contracts/SharesMath.sol';
import {PercentageMath} from 'src/contracts/PercentageMath.sol';
import {WadRayMath} from 'src/contracts/WadRayMath.sol';

library AssetLogic {
  using AssetLogic for Asset;
  using PercentageMath for uint256;
  using SharesMath for uint256;
  using WadRayMath for uint256;

  // todo add remaining: accrue interest, previewNextBorrowIndex

  // todo: option for cached object
  function totalAssets(Asset storage asset) internal view returns (uint256) {
    return asset.availableLiquidity + asset.outstandingPremium + asset.baseDebt;
  }

  function totalShares(Asset storage asset) internal view returns (uint256) {
    return asset.suppliedShares;
  }

  function convertToSharesUp(Asset storage asset, uint256 assets) internal view returns (uint256) {
    return assets.toSharesUp(asset.totalAssets(), asset.totalShares());
  }

  function convertToSharesDown(
    Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.toSharesDown(asset.totalAssets(), asset.totalShares());
  }

  function convertToAssetsUp(Asset storage asset, uint256 shares) internal view returns (uint256) {
    return shares.toAssetsUp(asset.totalAssets(), asset.totalShares());
  }

  function convertToAssetsDown(
    Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.toAssetsDown(asset.totalAssets(), asset.totalShares());
  }

  // todo carry out mul in rad for precision
  function getInterestRate(Asset storage asset) internal view returns (uint256) {
    return
      asset.baseBorrowRate.percentMul(
        PercentageMath.PERCENTAGE_FACTOR + asset.riskPremiumRad.radToBps()
      );
  }
}
