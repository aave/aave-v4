// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicActualDebtToLiquidateTest is LiquidationLogicBaseTest {
  /// test calculateActualDebtToLiquidate when totalDebt is zero
  /// should not occur in practice, as validateLiquidation should revert prior
  function test_calculateActualDebtToLiquidate_fuzz_totalDebt_zero(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    // zero total debt; should be reverted by validation in practice
    params.totalDebt = 0;
    DataTypes.LiquidationCallLocalVars memory args = _setStructFields(params);

    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      debtToCover,
      args
    );

    assertEq(
      actualDebtToLiquidate,
      0,
      'if debtToRestoreCloseFactor == 0, actualDebtToLiquidate should be 0'
    );
  }

  /// test calculateActualDebtToLiquidate when debtToCover is zero
  /// should not occur in practice, as validateLiquidation should revert prior
  function test_calculateActualDebtToLiquidate_fuzz_debtToCover_zero(
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    DataTypes.LiquidationCallLocalVars memory args = _setStructFields(params);

    // zero debtToCover; should be reverted by validation in practice
    uint256 debtToCover = 0;

    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      debtToCover,
      args
    );

    assertEq(actualDebtToLiquidate, 0, 'if debtToCover == 0, actualDebtToLiquidate should be 0');
  }

  /// test calculateActualDebtToLiquidate when debtToRestoreCloseFactor <= totalDebt
  function test_calculateActualDebtToLiquidate_fuzz_debtToRestoreCloseFactor_lte_totalDebt(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    DataTypes.LiquidationCallLocalVars memory args = _setStructFields(params);

    uint256 debtToRestoreCloseFactor = LiquidationLogic.calculateDebtToRestoreCloseFactor(args);

    vm.assume(debtToRestoreCloseFactor > args.totalDebt);

    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      debtToCover,
      args
    );

    uint256 maxLiquidatableDebt = _min(debtToRestoreCloseFactor, args.totalDebt);

    assertEq(
      actualDebtToLiquidate,
      _min(debtToCover, maxLiquidatableDebt),
      'should return min allowed'
    );
  }

  /// test calculateActualDebtToLiquidate when debtToRestoreCloseFactor > maxLiquidatableDebt
  function test_calculateActualDebtToLiquidate_fuzz_debtToRestoreCloseFactor_gt_maxLiquidatableDebt(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    DataTypes.LiquidationCallLocalVars memory args = _setStructFields(params);

    uint256 debtToRestoreCloseFactor = LiquidationLogic.calculateDebtToRestoreCloseFactor(args);
    // args.totalDebt is the max liquidatable debt
    // ie user total debt for the debt reserve of interest
    vm.assume(debtToRestoreCloseFactor <= args.totalDebt);

    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      debtToCover,
      args
    );

    uint256 maxLiquidatableDebt = _min(debtToRestoreCloseFactor, args.totalDebt);

    assertEq(
      actualDebtToLiquidate,
      _min(debtToCover, maxLiquidatableDebt),
      'should return min allowed'
    );
  }

  /// test calculateActualDebtToLiquidate when debtToRestoreCloseFactor == 0
  /// can only occur if user's health factor is already at close factor
  /// should not occur in practice, as as close factor is restricted to >= 1
  /// and liquidation is only allowed when HF < 1
  function test_calculateActualDebtToLiquidate_fuzz_debtToRestoreCloseFactor_zero(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    DataTypes.LiquidationCallLocalVars memory args = _setStructFields(params);

    uint256 debtToRestoreCloseFactor = LiquidationLogic.calculateDebtToRestoreCloseFactor(args);
    vm.assume(debtToRestoreCloseFactor == 0);

    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      debtToCover,
      args
    );

    assertEq(actualDebtToLiquidate, 0, 'actualDebtToLiquidate should be 0');
  }

  /// bound fuzz inputs
  function _bound(
    TestDebtToRestoreCloseFactorParams memory params
  ) internal override returns (TestDebtToRestoreCloseFactorParams memory) {
    params = super._bound(params);
    params.totalDebt = bound(
      params.totalDebt,
      1,
      _convertBaseCurrencyToAmount(
        MAX_SUPPLY_IN_BASE_CURRENCY,
        params.debtAssetPrice,
        params.debtAssetUnit
      )
    );
    return params;
  }
}
