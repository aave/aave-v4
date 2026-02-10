// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicDebtToLiquidateTest is LiquidationLogicBaseTest {
  using MathUtils for uint256;
  using WadRayMath for uint256;

  /// function always returns min between reserve debt, debt to cover and debt to restore target health factor,
  /// unless it leaves dust, in which case it returns reserve debt
  function test_calculateDebtToLiquidate_fuzz(
    LiquidationLogic.CalculateDebtToLiquidateParams memory params
  ) public {
    params = _bound(params);

    uint256 debtRayToTarget = liquidationLogicWrapper.calculateDebtToTargetHealthFactor(
      _getDebtToTargetHealthFactorParams(params)
    );
    uint256 rawPremiumDebtRayToLiquidate = debtRayToTarget.fromRayUp().toRay().min(
      params.premiumDebtRay
    );
    if (params.debtToCover <= rawPremiumDebtRayToLiquidate / WadRayMath.RAY) {
      rawPremiumDebtRayToLiquidate = params.debtToCover.toRay();
    }

    uint256 drawnSharesToTarget = (rawPremiumDebtRayToLiquidate == params.premiumDebtRay &&
      rawPremiumDebtRayToLiquidate < debtRayToTarget)
      ? (debtRayToTarget - rawPremiumDebtRayToLiquidate).divUp(params.drawnIndex)
      : 0;
    uint256 drawnSharesToCover = Math.mulDiv(
      params.debtToCover - rawPremiumDebtRayToLiquidate.fromRayUp(),
      WadRayMath.RAY,
      params.drawnIndex,
      Math.Rounding.Floor
    );
    uint256 rawDrawnSharesToLiquidate = drawnSharesToTarget.min(drawnSharesToCover).min(
      params.drawnShares
    );

    uint256 assetsRequired = _calculateDebtAssetsToRestore({
      drawnSharesToLiquidate: rawDrawnSharesToLiquidate,
      premiumDebtRayToLiquidate: rawPremiumDebtRayToLiquidate,
      drawnIndex: params.drawnIndex
    });
    assertLe(assetsRequired, params.debtToCover, 'assets required');

    uint256 debtRayRemaining = (params.drawnShares - rawDrawnSharesToLiquidate) *
      params.drawnIndex +
      params.premiumDebtRay -
      rawPremiumDebtRayToLiquidate;

    bool leavesDebtDust = _convertAmountToValue(
      debtRayRemaining,
      params.debtAssetPrice,
      params.debtAssetUnit
    ) < LiquidationLogic.DUST_LIQUIDATION_THRESHOLD.toRay();

    (uint256 drawnSharesToLiquidate, uint256 premiumDebtRayToLiquidate) = liquidationLogicWrapper
      .calculateDebtToLiquidate(params);
    if (leavesDebtDust) {
      assertEq(drawnSharesToLiquidate, params.drawnShares);
      assertEq(premiumDebtRayToLiquidate, params.premiumDebtRay);
    } else {
      assertEq(drawnSharesToLiquidate, rawDrawnSharesToLiquidate);
      assertEq(premiumDebtRayToLiquidate, rawPremiumDebtRayToLiquidate);
    }
  }

  /// function never adjusts for dust if 1 wei of debt is worth more than DUST_LIQUIDATION_THRESHOLD
  function test_calculateDebtToLiquidate_fuzz_ImpossibleToAdjustForDust(
    LiquidationLogic.CalculateDebtToLiquidateParams memory params
  ) public {
    params = _bound(params);
    params.debtAssetDecimals = bound(params.debtAssetDecimals, 1, 5);
    params.debtAssetUnit = 10 ** params.debtAssetDecimals;
    params.debtAssetPrice = bound(
      params.debtAssetPrice,
      LiquidationLogic.DUST_LIQUIDATION_THRESHOLD.fromWadDown() * params.debtAssetUnit,
      MAX_ASSET_PRICE
    );
    uint256 debtRayToTarget = liquidationLogicWrapper.calculateDebtToTargetHealthFactor(
      _getDebtToTargetHealthFactorParams(params)
    );

    uint256 rawPremiumDebtRayToLiquidate = debtRayToTarget.fromRayUp().toRay().min(
      params.premiumDebtRay
    );
    if (params.debtToCover <= rawPremiumDebtRayToLiquidate / WadRayMath.RAY) {
      rawPremiumDebtRayToLiquidate = params.debtToCover.toRay();
    }

    uint256 drawnSharesToTarget = (rawPremiumDebtRayToLiquidate == params.premiumDebtRay &&
      rawPremiumDebtRayToLiquidate < debtRayToTarget)
      ? (debtRayToTarget - rawPremiumDebtRayToLiquidate).divUp(params.drawnIndex)
      : 0;
    uint256 drawnSharesToCover = Math.mulDiv(
      params.debtToCover - rawPremiumDebtRayToLiquidate.fromRayUp(),
      WadRayMath.RAY,
      params.drawnIndex,
      Math.Rounding.Floor
    );
    params.drawnShares = bound(
      params.drawnShares,
      drawnSharesToTarget.min(drawnSharesToCover),
      MAX_SUPPLY_ASSET_UNITS * params.debtAssetUnit
    );

    (uint256 drawnSharesToLiquidate, uint256 premiumDebtRayToLiquidate) = liquidationLogicWrapper
      .calculateDebtToLiquidate(params);
    assertEq(drawnSharesToLiquidate, drawnSharesToTarget.min(drawnSharesToCover));
    assertEq(premiumDebtRayToLiquidate, rawPremiumDebtRayToLiquidate);
  }

  /// function returns total reserve debt if dust is left
  function test_calculateDebtToLiquidate_fuzz_AmountAdjustedDueToDust(
    LiquidationLogic.CalculateDebtToLiquidateParams memory params
  ) public {
    params = _boundWithDustAdjustment(params);
    (uint256 drawnSharesToLiquidate, uint256 premiumDebtRayToLiquidate) = liquidationLogicWrapper
      .calculateDebtToLiquidate(params);
    assertEq(drawnSharesToLiquidate, params.drawnShares);
    assertEq(premiumDebtRayToLiquidate, params.premiumDebtRay);
  }
}
