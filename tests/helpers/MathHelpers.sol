// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BaseState} from 'tests/base/BaseState.sol';
import {Math} from 'src/dependencies/openzeppelin/Math.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {IHub, IHubBase} from 'src/hub/interfaces/IHub.sol';
import {SharesMath} from 'src/hub/libraries/SharesMath.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IPriceOracle} from 'src/spoke/interfaces/IPriceOracle.sol';
import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';

abstract contract MathHelpers is BaseState {
  using WadRayMath for *;
  using SharesMath for uint256;
  using PercentageMath for uint256;
  using SafeCast for *;
  using MathUtils for uint256;

  function _min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }

  function _max(uint256 a, uint256 b) internal pure returns (uint256) {
    return a > b ? a : b;
  }

  function _divUp(uint256 a, uint256 b) internal pure returns (uint256) {
    return (a + b - 1) / b;
  }

  function _convertAmountToValue(
    ISpoke spoke,
    uint256 reserveId,
    uint256 amount
  ) internal view returns (uint256) {
    return
      _convertAmountToValue(
        amount,
        IPriceOracle(spoke.ORACLE()).getReservePrice(reserveId),
        10 ** _underlying(spoke, reserveId).decimals()
      );
  }

  function _convertAmountToValue(
    uint256 amount,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal pure returns (uint256) {
    return (amount * assetPrice) * (WadRayMath.WAD / assetUnit);
  }

  function _convertValueToAmount(
    ISpoke spoke,
    uint256 reserveId,
    uint256 valueAmount
  ) internal view returns (uint256) {
    return
      _convertValueToAmount(
        valueAmount,
        IPriceOracle(spoke.ORACLE()).getReservePrice(reserveId),
        10 ** _underlying(spoke, reserveId).decimals()
      );
  }

  function _convertValueToAmount(
    uint256 valueAmount,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal pure returns (uint256) {
    return ((valueAmount * assetUnit) / assetPrice).fromWadDown();
  }

  function _convertAssetAmount(
    ISpoke spoke,
    uint256 reserveId,
    uint256 amount,
    uint256 toReserveId
  ) internal view returns (uint256) {
    return
      _convertValueToAmount(spoke, toReserveId, _convertAmountToValue(spoke, reserveId, amount));
  }

  function _convertDecimals(
    uint256 amount,
    uint256 fromDecimals,
    uint256 toDecimals,
    bool roundUp
  ) internal pure returns (uint256) {
    return
      Math.mulDiv(
        amount,
        10 ** toDecimals,
        10 ** fromDecimals,
        (roundUp) ? Math.Rounding.Ceil : Math.Rounding.Floor
      );
  }

  function _calculateExactRestoreAmount(
    uint256 drawn,
    uint256 premium,
    uint256 restoreAmount,
    uint256 assetId
  ) internal view returns (uint256, uint256) {
    if (restoreAmount <= premium) {
      return (0, restoreAmount);
    }
    uint256 drawnRestored = _min(drawn, restoreAmount - premium);
    drawnRestored = hub1.previewRestoreByShares(
      assetId,
      hub1.previewRestoreByAssets(assetId, drawnRestored)
    );
    return (drawnRestored, premium);
  }

  function _calculateExactRestoreAmount(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 repayAmount
  ) internal view returns (uint256 baseRestored, uint256 premiumRestored) {
    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke.getUserDebt(reserveId, user);
    return
      _calculateExactRestoreAmount(
        userDrawnDebt,
        userPremiumDebt,
        repayAmount,
        _reserveAssetId(spoke, reserveId)
      );
  }

  function _calculateRestoreAmounts(
    uint256 restoreAmount,
    uint256 drawn,
    uint256 premiumRay
  ) internal pure returns (uint256 drawnAmountToRestore, uint256 premiumRayToRestore) {
    if (restoreAmount <= premiumRay / WadRayMath.RAY) {
      return (0, restoreAmount.toRay());
    }
    return (drawn.min(restoreAmount - premiumRay.fromRayUp()), premiumRay);
  }

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

  function _calculatePremiumDebt(
    IHub hub,
    uint256 assetId,
    uint256 premiumShares,
    int256 premiumOffsetRay
  ) internal view returns (uint256) {
    return _calculatePremiumDebtRay(hub, assetId, premiumShares, premiumOffsetRay).fromRayUp();
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

  function _calculatePremiumDebtRay(
    uint256 premiumShares,
    int256 premiumOffsetRay,
    uint256 drawnIndex
  ) internal pure returns (uint256) {
    return ((premiumShares * drawnIndex).toInt256() - premiumOffsetRay).toUint256();
  }

  function _calculatePremiumDebtRay(
    ISpoke spoke,
    uint256 reserveId,
    uint256 premiumShares,
    int256 premiumOffsetRay
  ) internal view returns (uint256) {
    IHub hub = _hub(spoke, reserveId);
    uint256 assetId = _reserveAssetId(spoke, reserveId);
    return _calculatePremiumDebtRay(hub, assetId, premiumShares, premiumOffsetRay);
  }

  function _calculatePremiumDebtRay(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (uint256) {
    ISpoke.UserPosition memory userPosition = spoke.getUserPosition(reserveId, user);
    return
      _calculatePremiumDebtRay(
        spoke,
        reserveId,
        userPosition.premiumShares,
        userPosition.premiumOffsetRay
      );
  }

  function _calculatePremiumAssetsRay(
    uint256 premiumShares,
    uint256 drawnIndex
  ) internal pure returns (uint256) {
    return premiumShares * drawnIndex;
  }

  function _calculatePremiumAssetsRay(
    IHub hub,
    uint256 assetId,
    uint256 premiumShares
  ) internal view returns (uint256) {
    return _calculatePremiumAssetsRay(premiumShares, hub.getAssetDrawnIndex(assetId));
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

  function _calculateExpectedPremiumDebt(
    uint256 initialDrawnDebt,
    uint256 currentDrawnDebt,
    uint256 userRiskPremium
  ) internal pure returns (uint256) {
    return (currentDrawnDebt - initialDrawnDebt).percentMulUp(userRiskPremium);
  }

  function _calculateBurntInterest(IHub hub, uint256 assetId) internal view returns (uint256) {
    return
      hub.getAddedAssets(assetId) - hub.previewRemoveByShares(assetId, hub.getAddedShares(assetId));
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

  function _calculateMaxSupplyAmount(TestnetERC20 token) internal view returns (uint256) {
    return MAX_SUPPLY_ASSET_UNITS * 10 ** token.decimals();
  }

  function _calculateMaxSupplyAmount(
    IHubBase hub,
    uint256 assetId
  ) internal view returns (uint256) {
    (, uint8 decimals) = hub.getAssetUnderlyingAndDecimals(assetId);
    return MAX_SUPPLY_ASSET_UNITS * 10 ** decimals;
  }

  function _calculateMaxSupplyAmount(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (uint256) {
    return MAX_SUPPLY_ASSET_UNITS * 10 ** spoke.getReserve(reserveId).decimals;
  }

  function _calculateMaxSupplyAmount(
    ITokenizationSpoke tokenizationSpoke
  ) internal view returns (uint256) {
    return
      _calculateMaxSupplyAmount(IHubBase(tokenizationSpoke.hub()), tokenizationSpoke.assetId());
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
}
