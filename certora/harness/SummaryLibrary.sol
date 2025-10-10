// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../../src/hub/libraries/AssetLogic.sol';

library SummaryLibrary {
  using AssetLogic for IHub.Asset;
  using SharesMath for uint256;

  function getFeeShares(
    IHub.Asset storage asset,
    uint256 indexDelta
  ) external view returns (uint256) {
    uint256 liquidityFee = asset.liquidityFee;
    if (indexDelta == 0 || liquidityFee == 0) {
      return 0;
    }
    uint256 totalDrawnShares = asset.drawnShares + asset.premiumShares;
    uint256 feesAmount = calcFees(indexDelta, totalDrawnShares, liquidityFee);
    return feesAmount.toSharesDown(asset.totalAddedAssets() - feesAmount, asset.addedShares);
  }

  function calcFees(
    uint256 indexDelta,
    uint256 totalDrawnShares,
    uint256 liquidityFee
  ) internal view returns (uint256 r) {
    require(true, 'cvl summarized only');
  }

  function getDrawnIndex(IHub.Asset storage asset) external view returns (uint256) {
    return asset.drawnIndex;
  }
}
