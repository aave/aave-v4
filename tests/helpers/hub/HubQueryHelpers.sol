// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {CommonsHelpers} from 'tests/helpers/commons/CommonsHelpers.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {IHub, IHubBase} from 'src/hub/interfaces/IHub.sol';
import {SharesMath} from 'src/hub/libraries/SharesMath.sol';

/// @title HubQueryHelpers
/// @notice Hub-level state-reading helpers and hub-specific calculations.
abstract contract HubQueryHelpers is CommonsHelpers {
  using WadRayMath for *;
  using MathUtils for uint256;
  using PercentageMath for uint256;
  using SafeCast for *;
  using SharesMath for uint256;

  uint256 internal constant MAX_SUPPLY_AMOUNT = 1e30;

  struct AssetPosition {
    uint256 assetId;
    uint256 addedShares;
    uint256 addedAmount;
    uint256 drawnShares;
    uint256 drawn;
    uint256 premiumShares;
    int256 premiumOffsetRay;
    uint256 premium;
    uint40 lastUpdateTimestamp;
    uint256 liquidity;
    uint256 drawnIndex;
    uint256 drawnRate;
  }

  struct HubSnapshot {
    uint256 liquidity;
    uint256 addedAssets;
    uint256 addedShares;
    uint256 drawnAssets;
    uint256 drawnShares;
  }

  // --- Hub-domain pure math ---

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

  function _calculateDebtAssetsToRestore(
    uint256 drawnSharesToLiquidate,
    uint256 premiumDebtRayToLiquidate,
    uint256 drawnIndex
  ) internal pure returns (uint256) {
    return drawnSharesToLiquidate.rayMulUp(drawnIndex) + premiumDebtRayToLiquidate.fromRayUp();
  }

  function _calculateExpectedDrawnIndex(
    uint256 initialDrawnIndex,
    uint96 borrowRate,
    uint40 startTime
  ) internal view returns (uint256) {
    return initialDrawnIndex.rayMulUp(MathUtils.calculateLinearInterest(borrowRate, startTime));
  }

  function calculateExpectedDebt(
    uint256 initialDrawnShares,
    uint256 initialDrawnIndex,
    uint96 borrowRate,
    uint40 startTime
  ) internal view returns (uint256 newDrawnIndex, uint256 newDrawnDebt) {
    newDrawnIndex = _calculateExpectedDrawnIndex(initialDrawnIndex, borrowRate, startTime);
    newDrawnDebt = initialDrawnShares.rayMulUp(newDrawnIndex);
  }

  function _calculateExpectedDrawnDebt(
    uint256 initialDebt,
    uint96 borrowRate,
    uint40 startTime
  ) internal view returns (uint256) {
    return MathUtils.calculateLinearInterest(borrowRate, startTime).rayMulUp(initialDebt);
  }

  function _calculateExpectedFees(
    uint256 drawnIncrease,
    uint256 premiumIncrease,
    uint256 liquidityFee
  ) internal pure returns (uint256) {
    return (drawnIncrease + premiumIncrease).percentMulDown(liquidityFee);
  }

  function _calculateExpectedFeesAmount(
    uint256 initialDrawnShares,
    uint256 initialPremiumShares,
    uint256 liquidityFee,
    uint256 indexDelta
  ) internal pure returns (uint256 feesAmount) {
    return
      indexDelta.rayMulUp(initialDrawnShares + initialPremiumShares).percentMulDown(liquidityFee);
  }

  function calculateEffectiveAddedAssets(
    uint256 assetsAmount,
    uint256 totalAddedAssets,
    uint256 totalAddedShares
  ) internal pure returns (uint256) {
    uint256 sharesAmount = assetsAmount.toSharesDown(totalAddedAssets, totalAddedShares);
    return
      sharesAmount.toAssetsDown(totalAddedAssets + assetsAmount, totalAddedShares + sharesAmount);
  }

  // --- Hub math helpers (require IHub) ---

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

  function _calculateBurntInterest(IHub hub, uint256 assetId) internal view returns (uint256) {
    return
      hub.getAddedAssets(assetId) - hub.previewRemoveByShares(assetId, hub.getAddedShares(assetId));
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

  // --- Hub query helpers (parameterized with IHub) ---

  function getAssetDrawnDebt(IHub hub, uint256 assetId) internal view returns (uint256) {
    (uint256 drawn, ) = hub.getAssetOwed(assetId);
    return drawn;
  }

  function _getAssetLiquidityFee(IHub hub, uint256 assetId) internal view returns (uint256) {
    return hub.getAssetConfig(assetId).liquidityFee;
  }

  function _getFeeReceiver(IHub hub, uint256 assetId) internal view returns (address) {
    return hub.getAssetConfig(assetId).feeReceiver;
  }

  function minimumAssetsPerAddedShare(IHub hub, uint256 assetId) internal view returns (uint256) {
    return hub.previewAddByShares(assetId, 1);
  }

  function minimumAssetsPerDrawnShare(IHub hub, uint256 assetId) internal view returns (uint256) {
    return hub.previewRestoreByShares(assetId, 1);
  }

  function getAddExRate(IHub hub, uint256 assetId) internal view returns (uint256) {
    return hub.previewRemoveByShares(assetId, MAX_SUPPLY_AMOUNT);
  }

  function getDebtExRate(IHub hub, uint256 assetId) internal view returns (uint256) {
    return hub.previewRestoreByShares(assetId, MAX_SUPPLY_AMOUNT);
  }

  // --- Hub snapshot builders ---

  function getAssetPosition(
    IHub hub,
    uint256 assetId
  ) internal view returns (AssetPosition memory) {
    IHub.Asset memory assetData = hub.getAsset(assetId);
    (uint256 drawn, uint256 premium) = hub.getAssetOwed(assetId);
    return
      AssetPosition({
        assetId: assetId,
        liquidity: assetData.liquidity,
        addedShares: assetData.addedShares,
        addedAmount: hub.getAddedAssets(assetId) - _calculateBurntInterest(hub, assetId),
        drawnShares: assetData.drawnShares,
        drawn: drawn,
        premiumShares: assetData.premiumShares,
        premiumOffsetRay: assetData.premiumOffsetRay,
        premium: premium,
        lastUpdateTimestamp: assetData.lastUpdateTimestamp.toUint40(),
        drawnIndex: assetData.drawnIndex,
        drawnRate: assetData.drawnRate
      });
  }

  // --- Random asset ID generators ---

  function _randomAssetId(IHub hub) internal returns (uint256) {
    return vm.randomUint(0, hub.getAssetCount() - 1);
  }

  function _randomInvalidAssetId(IHub hub) internal returns (uint256) {
    return vm.randomUint(hub.getAssetCount(), UINT256_MAX);
  }
}
