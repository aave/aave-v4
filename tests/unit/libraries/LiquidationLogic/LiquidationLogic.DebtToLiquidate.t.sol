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

    uint256 debtToLiquidate = liquidationLogicWrapper.calculateDebtToLiquidate(params);
    uint256 debtToTarget = liquidationLogicWrapper.calculateDebtToTargetHealthFactor(
      _getDebtToTargetHealthFactorParams(params)
    );
    uint256 rawDebtToLiquidate = params.debtReserveBalance.min(params.debtToCover).min(
      debtToTarget
    );

    bool leavesDebtDust = _convertAmountToValue(
      params.debtReserveBalance - rawDebtToLiquidate,
      params.debtAssetPrice,
      params.debtAssetUnit
    ) < LiquidationLogic.DUST_LIQUIDATION_THRESHOLD;
    if (leavesDebtDust) {
      assertEq(debtToLiquidate, params.debtReserveBalance);
    } else {
      assertEq(debtToLiquidate, rawDebtToLiquidate);
    }
  }

  /// function never adjusts for dust if 1 wei of debt is worth more than DUST_LIQUIDATION_THRESHOLD
  function test_calculateDebtToLiquidate_fuzz_ImpossibleToAdjustForDust(
    LiquidationLogic.CalculateDebtToLiquidateParams memory params
  ) public {
    params = _bound(params);
    params.debtAssetUnit = 10 ** bound(params.debtAssetUnit, 1, 5);
    params.debtAssetPrice = bound(
      params.debtAssetPrice,
      LiquidationLogic.DUST_LIQUIDATION_THRESHOLD.fromWadDown() * params.debtAssetUnit,
      MAX_ASSET_PRICE
    );
    uint256 debtToTarget = liquidationLogicWrapper.calculateDebtToTargetHealthFactor(
      _getDebtToTargetHealthFactorParams(params)
    );
    params.debtReserveBalance = bound(
      params.debtReserveBalance,
      debtToTarget.min(params.debtToCover),
      MAX_SUPPLY_AMOUNT
    );

    uint256 debtToLiquidate = liquidationLogicWrapper.calculateDebtToLiquidate(params);
    assertEq(debtToLiquidate, debtToTarget.min(params.debtToCover));
  }

  /// function returns total reserve debt if dust is left
  function test_calculateDebtToLiquidate_fuzz_AmountAdjustedDueToDust(
    LiquidationLogic.CalculateDebtToLiquidateParams memory params
  ) public {
    params = _boundWithDustAdjustment(params);
    uint256 debtToLiquidate = liquidationLogicWrapper.calculateDebtToLiquidate(params);
    assertEq(debtToLiquidate, params.debtReserveBalance);
  }
}
