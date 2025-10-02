// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicMaxDebtToLiquidateTest is LiquidationLogicBaseTest {
  using MathUtils for uint256;
  using WadRayMath for uint256;

  /// function always returns min between reserve debt, debt to cover and debt to restore target health factor,
  /// unless it leaves dust, in which case it returns reserve debt
  function test_calculateMaxDebtToLiquidate_fuzz(
    LiquidationLogic.CalculateMaxDebtToLiquidateParams memory params
  ) public {
    params = _bound(params);

    uint256 maxDebtToLiquidate = liquidationLogicWrapper.calculateMaxDebtToLiquidate(params);
    uint256 debtToTarget = liquidationLogicWrapper.calculateDebtToTargetHealthFactor(
      _getDebtToTargetHealthFactorParams(params)
    );
    uint256 rawMaxDebtToLiquidate = params.debtReserveBalance.min(params.debtToCover).min(
      debtToTarget
    );

    bool leavesDebtDust = _convertAmountToBaseCurrency(
      params.debtReserveBalance - rawMaxDebtToLiquidate,
      params.debtAssetPrice,
      params.debtAssetUnit
    ) < LiquidationLogic.DUST_LIQUIDATION_THRESHOLD;
    if (leavesDebtDust) {
      assertEq(maxDebtToLiquidate, params.debtReserveBalance);
    } else {
      assertEq(maxDebtToLiquidate, rawMaxDebtToLiquidate);
    }
  }

  /// function never adjusts for dust if 1 wei of debt is worth more than DUST_LIQUIDATION_THRESHOLD
  function test_calculateMaxDebtToLiquidate_fuzz_ImpossibleToAdjustForDust(
    LiquidationLogic.CalculateMaxDebtToLiquidateParams memory params
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

    uint256 maxDebtToLiquidate = liquidationLogicWrapper.calculateMaxDebtToLiquidate(params);
    assertEq(maxDebtToLiquidate, debtToTarget.min(params.debtToCover));
  }

  /// function returns total reserve debt if dust is left
  function test_calculateMaxDebtToLiquidate_fuzz_AmountAdjustedDueToDust(
    LiquidationLogic.CalculateMaxDebtToLiquidateParams memory params
  ) public {
    params = _boundWithDustAdjustment(params);
    uint256 maxDebtToLiquidate = liquidationLogicWrapper.calculateMaxDebtToLiquidate(params);
    assertEq(maxDebtToLiquidate, params.debtReserveBalance);
  }
}
