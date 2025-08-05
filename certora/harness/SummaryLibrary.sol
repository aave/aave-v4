// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;



import '../../src/libraries/logic/AssetLogic.sol';

library SummaryLibrary {
    using AssetLogic for DataTypes.Asset;
    using SharesMath for uint256;

function getFeeShares(
    DataTypes.Asset storage asset,
    uint256 indexDelta 
    ) external view returns (uint256) {
      uint256 liquidityFee = asset.config.liquidityFee;
      if (indexDelta == 0 || liquidityFee == 0) {
        return 0;
      }
      uint256 totalDrawnShares = asset.baseDrawnShares + asset.premiumDrawnShares;
      uint256 feesAmount = calcFees(indexDelta,totalDrawnShares, liquidityFee);
      return feesAmount.toSharesDown(asset.totalSuppliedAssets() -  feesAmount, asset.suppliedShares);
  }

  function calcFees(uint256 indexDelta, uint256 totalDrawnShares, uint256 liquidityFee) internal view returns (uint256 r) {
    require(true, "cvl summarized only") ; 
  }

  function getDrawnIndex(DataTypes.Asset storage asset) external view returns (uint256) {
    return  asset.baseDebtIndex;
    }

}
