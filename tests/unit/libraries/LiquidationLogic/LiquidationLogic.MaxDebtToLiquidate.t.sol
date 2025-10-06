// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicMaxDebtToLiquidateTest is LiquidationLogicBaseTest {
  using MathUtils for uint256;
  using WadRayMath for uint256;

  /// function always returns min between reserve debt, debt to cover and debt to restore target health factor (when not reverting)
  function test_calculateMaxDebtToLiquidate_fuzz(
    LiquidationLogic.CalculateMaxDebtToLiquidateParams memory params
  ) public {
    params = _boundNoDustRevert(params);
    uint256 maxDebtToLiquidate = liquidationLogicWrapper.calculateMaxDebtToLiquidate(params);
    uint256 debtToTarget = liquidationLogicWrapper.calculateDebtToTargetHealthFactor(
      _getDebtToTargetHealthFactorParams(params)
    );
    assertGe(
      maxDebtToLiquidate,
      params.debtReserveBalance.min(params.debtToCover).min(debtToTarget)
    );
  }

  /// function never reverts if 1 wei of debt is worth more than DUST_DEBT_LIQUIDATION_THRESHOLD
  function test_calculateMaxDebtToLiquidate_fuzz_ImpossibleToLeaveDust(
    LiquidationLogic.CalculateMaxDebtToLiquidateParams memory params
  ) public {
    params = _bound(params);
    params.debtAssetUnit = 10 ** bound(params.debtAssetUnit, 1, 5);
    params.debtAssetPrice = bound(
      params.debtAssetPrice,
      LiquidationLogic.DUST_DEBT_LIQUIDATION_THRESHOLD.fromWadDown() * params.debtAssetUnit,
      MAX_ASSET_PRICE
    );
    liquidationLogicWrapper.calculateMaxDebtToLiquidate(params);
  }

  /// function returns total reserve debt if dust is left, as long as debt to cover is >= total reserve debt (min is debtToTarget)
  function test_calculateMaxDebtToLiquidate_fuzz_AmountAdjustedDueToDust(
    LiquidationLogic.CalculateMaxDebtToLiquidateParams memory params
  ) public {
    params = _bound(params);
    params.debtAssetPrice = bound(
      params.debtAssetPrice,
      1,
      LiquidationLogic.DUST_DEBT_LIQUIDATION_THRESHOLD.fromWadDown() * params.debtAssetUnit - 1
    );
    uint256 debtToTarget = liquidationLogicWrapper.calculateDebtToTargetHealthFactor(
      _getDebtToTargetHealthFactorParams(params)
    );
    params.debtReserveBalance = bound(
      params.debtReserveBalance,
      debtToTarget + 1,
      debtToTarget +
        _convertValueToAmount(
          LiquidationLogic.DUST_DEBT_LIQUIDATION_THRESHOLD - 1,
          params.debtAssetPrice,
          params.debtAssetUnit
        )
    );
    params.debtToCover = bound(
      params.debtToCover,
      params.debtReserveBalance,
      _max(params.debtReserveBalance, MAX_SUPPLY_AMOUNT)
    );
    uint256 maxDebtToLiquidate = liquidationLogicWrapper.calculateMaxDebtToLiquidate(params);
    assertEq(maxDebtToLiquidate, params.debtReserveBalance);
  }

  /// function reverts with MustNotLeaveDust if remaining debt is less than DUST_DEBT_LIQUIDATION_THRESHOLD and debtToCover is not enough to cover all debt
  function test_calculateMaxDebtToLiquidate_fuzz_revertsWith_MustNotLeaveDust(
    LiquidationLogic.CalculateMaxDebtToLiquidateParams memory params
  ) public {
    params = _bound(params);
    params.debtAssetPrice = bound(
      params.debtAssetPrice,
      1,
      LiquidationLogic.DUST_DEBT_LIQUIDATION_THRESHOLD.fromWadDown() * params.debtAssetUnit - 1
    );
    uint256 debtToTarget = liquidationLogicWrapper.calculateDebtToTargetHealthFactor(
      _getDebtToTargetHealthFactorParams(params)
    );
    uint256 debtToLiquidate = params.debtToCover.min(debtToTarget);
    params.debtReserveBalance = bound(
      params.debtReserveBalance,
      debtToLiquidate + 1,
      debtToLiquidate +
        _convertValueToAmount(
          LiquidationLogic.DUST_DEBT_LIQUIDATION_THRESHOLD - 1,
          params.debtAssetPrice,
          params.debtAssetUnit
        )
    );
    if (debtToTarget < params.debtToCover) {
      params.debtToCover = bound(params.debtToCover, debtToTarget, params.debtReserveBalance - 1);
    }
    vm.expectRevert(ISpoke.MustNotLeaveDust.selector);
    liquidationLogicWrapper.calculateMaxDebtToLiquidate(params);
  }
}
