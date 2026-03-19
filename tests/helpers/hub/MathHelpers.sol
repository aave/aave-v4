// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {QueryHelpers} from 'tests/helpers/hub/QueryHelpers.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {IHub, IHubBase} from 'src/hub/interfaces/IHub.sol';
import {SharesMath} from 'src/hub/libraries/SharesMath.sol';

/// @title MathHelpers
/// @notice Hub-level math calculations: premium, debt, interest, fees,
///         and restore amount helpers for the Aave V4 test suite.
///         Extends QueryHelpers so hub math tests have access to query helpers.
abstract contract MathHelpers is QueryHelpers {
  using WadRayMath for *;
  using MathUtils for uint256;
  using PercentageMath for uint256;
  using SafeCast for *;
  using SharesMath for uint256;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                   PREMIUM CALCULATIONS                                    //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _getExpectedPremiumDelta(
    uint256 drawnIndex,
    uint256 oldPremiumShares,
    int256 oldPremiumOffsetRay,
    uint256 drawnShares,
    uint256 riskPremium,
    uint256 restoredPremiumRay
  ) internal pure returns (IHubBase.PremiumDelta memory) {
    uint256 premiumDebtRay = _calculatePremiumDebtRay(
      oldPremiumShares,
      oldPremiumOffsetRay,
      drawnIndex
    );

    uint256 newPremiumShares = drawnShares.percentMulUp(riskPremium);
    int256 newPremiumOffsetRay = _calculatePremiumAssetsRay(newPremiumShares, drawnIndex).signedSub(
      premiumDebtRay - restoredPremiumRay
    );

    return
      IHubBase.PremiumDelta({
        sharesDelta: newPremiumShares.toInt256() - oldPremiumShares.toInt256(),
        offsetRayDelta: newPremiumOffsetRay - oldPremiumOffsetRay,
        restoredPremiumRay: restoredPremiumRay
      });
  }

  function _calculatePremiumDebtRay(
    uint256 premiumShares,
    int256 premiumOffsetRay,
    uint256 drawnIndex
  ) internal pure returns (uint256) {
    return ((premiumShares * drawnIndex).toInt256() - premiumOffsetRay).toUint256();
  }

  function _calculatePremiumAssetsRay(
    uint256 premiumShares,
    uint256 drawnIndex
  ) internal pure returns (uint256) {
    return premiumShares * drawnIndex;
  }

  function _calculatePremiumDebtRay(
    IHub hub,
    uint256 assetId,
    uint256 premiumShares,
    int256 premiumOffsetRay
  ) internal view returns (uint256) {
    uint256 drawnIndex = hub.getAssetDrawnIndex(assetId);
    return _calculatePremiumDebtRay(premiumShares, premiumOffsetRay, drawnIndex);
  }

  function _calculatePremiumDebt(
    IHub hub,
    uint256 assetId,
    uint256 premiumShares,
    int256 premiumOffsetRay
  ) internal view returns (uint256) {
    return _calculatePremiumDebtRay(hub, assetId, premiumShares, premiumOffsetRay).fromRayUp();
  }

  function _calculatePremiumAssetsRay(
    IHub hub,
    uint256 assetId,
    uint256 premiumShares
  ) internal view returns (uint256) {
    return _calculatePremiumAssetsRay(premiumShares, hub.getAssetDrawnIndex(assetId));
  }

  function _getExpectedPremiumDelta(
    IHub hub,
    uint256 assetId,
    uint256 oldPremiumShares,
    int256 oldPremiumOffsetRay,
    uint256 drawnShares,
    uint256 riskPremium,
    uint256 restoredPremiumRay
  ) internal view returns (IHubBase.PremiumDelta memory) {
    return
      _getExpectedPremiumDelta({
        drawnIndex: hub.getAssetDrawnIndex(assetId),
        oldPremiumShares: oldPremiumShares,
        oldPremiumOffsetRay: oldPremiumOffsetRay,
        drawnShares: drawnShares,
        riskPremium: riskPremium,
        restoredPremiumRay: restoredPremiumRay
      });
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                   DEBT CALCULATIONS                                       //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _calculateDebtAssetsToRestore(
    uint256 drawnSharesToLiquidate,
    uint256 premiumDebtRayToLiquidate,
    uint256 drawnIndex
  ) internal pure returns (uint256) {
    return drawnSharesToLiquidate.rayMulUp(drawnIndex) + premiumDebtRayToLiquidate.fromRayUp();
  }

  function _calculateExpectedDrawnIndex(
    uint256 initialDrawnIndex,
    uint96 drawnRate,
    uint40 startTime
  ) internal view returns (uint256) {
    return initialDrawnIndex.rayMulUp(MathUtils.calculateLinearInterest(drawnRate, startTime));
  }

  function _calculateExpectedDebt(
    uint256 initialDrawnShares,
    uint256 initialDrawnIndex,
    uint96 drawnRate,
    uint40 startTime
  ) internal view returns (uint256 newDrawnIndex, uint256 newDrawnDebt) {
    newDrawnIndex = _calculateExpectedDrawnIndex(initialDrawnIndex, drawnRate, startTime);
    newDrawnDebt = initialDrawnShares.rayMulUp(newDrawnIndex);
  }

  function _calculateExpectedDrawnDebt(
    uint256 initialDebt,
    uint96 drawnRate,
    uint40 startTime
  ) internal view returns (uint256) {
    return MathUtils.calculateLinearInterest(drawnRate, startTime).rayMulUp(initialDebt);
  }

  function _calculateExactRestoreAmount(
    IHub hub,
    uint256 assetId,
    uint256 drawn,
    uint256 premium,
    uint256 restoreAmount
  ) internal view returns (uint256, uint256) {
    if (restoreAmount <= premium) {
      return (0, restoreAmount);
    }
    uint256 drawnRestored = _min(drawn, restoreAmount - premium);
    drawnRestored = hub.previewRestoreByShares(
      assetId,
      hub.previewRestoreByAssets(assetId, drawnRestored)
    );
    return (drawnRestored, premium);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                   FEE CALCULATIONS                                        //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _calculateExpectedFeesAmount(
    uint256 initialDrawnShares,
    uint256 initialPremiumShares,
    uint256 liquidityFee,
    uint256 indexDelta
  ) internal pure returns (uint256 feesAmount) {
    return
      indexDelta.rayMulUp(initialDrawnShares + initialPremiumShares).percentMulDown(liquidityFee);
  }

  function _calculateEffectiveAddedAssets(
    uint256 assetsAmount,
    uint256 totalAddedAssets,
    uint256 totalAddedShares
  ) internal pure returns (uint256) {
    uint256 sharesAmount = assetsAmount.toSharesDown(totalAddedAssets, totalAddedShares);
    return
      sharesAmount.toAssetsDown(totalAddedAssets + assetsAmount, totalAddedShares + sharesAmount);
  }

  function _calcUnrealizedFees(IHub hub, uint256 assetId) internal view returns (uint256) {
    IHub.Asset memory asset = hub.getAsset(assetId);
    uint256 previousIndex = asset.drawnIndex;
    uint256 drawnIndex = asset.drawnIndex.rayMulUp(
      MathUtils.calculateLinearInterest(asset.drawnRate, uint40(asset.lastUpdateTimestamp))
    );

    uint256 aggregatedOwedRayAfter = (((uint256(asset.drawnShares) + asset.premiumShares) *
      drawnIndex).toInt256() - asset.premiumOffsetRay).toUint256() + asset.deficitRay;
    uint256 aggregatedOwedRayBefore = (((uint256(asset.drawnShares) + asset.premiumShares) *
      previousIndex).toInt256() - asset.premiumOffsetRay).toUint256() + asset.deficitRay;

    return
      (aggregatedOwedRayAfter.fromRayUp() - aggregatedOwedRayBefore.fromRayUp()).percentMulDown(
        asset.liquidityFee
      );
  }

  function _getExpectedFeeReceiverAddedAssets(
    IHub hub,
    uint256 assetId
  ) internal view returns (uint256) {
    uint256 expectedFees = hub.getAsset(assetId).realizedFees + _calcUnrealizedFees(hub, assetId);
    assertEq(expectedFees, hub.getAssetAccruedFees(assetId), 'asset accrued fees');
    return hub.getSpokeAddedAssets(assetId, hub.getAsset(assetId).feeReceiver) + expectedFees;
  }

  function _getAddedAssetsWithFees(IHub hub, uint256 assetId) internal view returns (uint256) {
    return
      hub.getAddedAssets(assetId) +
      hub.getAsset(assetId).realizedFees +
      _calcUnrealizedFees(hub, assetId);
  }

  function _calculateBurntInterest(IHub hub, uint256 assetId) internal view returns (uint256) {
    return
      hub.getAddedAssets(assetId) - hub.previewRemoveByShares(assetId, hub.getAddedShares(assetId));
  }
}
