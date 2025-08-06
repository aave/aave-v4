// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

/// test calculateActualDebtToLiquidate without dust accumulation
contract LiquidationLogicActualDebtToLiquidateTest is LiquidationLogicBaseTest {
  /// test calculateActualDebtToLiquidate when totalBorrowerReserveDebt is zero
  /// should not occur in practice, as validateLiquidation should revert prior
  function test_calculateActualDebtToLiquidate_fuzz_totalBorrowerReserveDebt_zero(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    // zero total debt; should be reverted by validation in practice
    params.totalBorrowerReserveDebt = 0;
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);

    bool isDustAmountExpected = isDustAmountExpected(debtToCover, params);
    vm.assume(!isDustAmountExpected);

    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      debtToCover,
      params
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
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);

    // zero debtToCover; should be reverted by validation in practice
    uint256 debtToCover = 0;

    bool isDustAmountExpected = isDustAmountExpected(debtToCover, params);
    vm.assume(!isDustAmountExpected);

    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      debtToCover,
      params
    );

    assertEq(actualDebtToLiquidate, 0, 'if debtToCover == 0, actualDebtToLiquidate should be 0');
  }

  /// test calculateActualDebtToLiquidate when debtToRestoreCloseFactor <= totalBorrowerReserveDebt
  function test_calculateActualDebtToLiquidate_fuzz_debtToRestoreCloseFactor_lte_totalBorrowerReserveDebt(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);

    // console.log('totalBorrowerReserveDebt', params.totalBorrowerReserveDebt);
    // if (params.totalBorrowerReserveDebt < 1000e26) revert('bug');

    uint256 debtToRestoreCloseFactor = LiquidationLogic.calculateDebtToRestoreCloseFactor(params);
    vm.assume(debtToRestoreCloseFactor > params.totalBorrowerReserveDebt);

    bool isDustAmountExpected = isDustAmountExpected(debtToCover, params);
    vm.assume(!isDustAmountExpected);

    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      debtToCover,
      params
    );

    uint256 expectedDebtToLiquidate = _min(
      debtToCover,
      _min(debtToRestoreCloseFactor, params.totalBorrowerReserveDebt)
    );

    assertEq(actualDebtToLiquidate, expectedDebtToLiquidate, 'should return min allowed');
  }

  /// test calculateActualDebtToLiquidate when debtToRestoreCloseFactor > maxLiquidatableDebt
  function test_calculateActualDebtToLiquidate_fuzz_debtToRestoreCloseFactor_gt_maxLiquidatableDebt(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);

    uint256 debtToRestoreCloseFactor = LiquidationLogic.calculateDebtToRestoreCloseFactor(params);
    // params.totalBorrowerReserveDebt is the max liquidatable debt
    // ie user total debt for the debt reserve of interest
    vm.assume(debtToRestoreCloseFactor <= params.totalBorrowerReserveDebt);

    bool isDustAmountExpected = isDustAmountExpected(debtToCover, params);
    vm.assume(!isDustAmountExpected);

    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      debtToCover,
      params
    );

    uint256 maxLiquidatableDebt = _min(debtToRestoreCloseFactor, params.totalBorrowerReserveDebt);

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
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);

    uint256 debtToRestoreCloseFactor = LiquidationLogic.calculateDebtToRestoreCloseFactor(params);
    vm.assume(debtToRestoreCloseFactor == 0);

    bool isDustAmountExpected = isDustAmountExpected(debtToCover, params);
    vm.assume(!isDustAmountExpected);

    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      debtToCover,
      params
    );

    assertEq(actualDebtToLiquidate, 0, 'actualDebtToLiquidate should be 0');
  }

  // happy path without dust; should return min of debtToCover, totalBorrowerReserveDebt, and debtToRestoreCloseFactor
  function test_calculateActualDebtToLiquidate_fuzz(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);

    bool isDustAmountExpected = isDustAmountExpected(debtToCover, params);
    vm.assume(!isDustAmountExpected);

    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      debtToCover,
      params
    );
    uint256 expectedDebtToLiquidate = _min(
      _min(debtToCover, params.totalBorrowerReserveDebt),
      LiquidationLogic.calculateDebtToRestoreCloseFactor(params)
    );

    assertEq(actualDebtToLiquidate, expectedDebtToLiquidate, 'should return min allowed');
  }

  /// bound fuzz inputs
  function _bound(
    TestDebtToRestoreCloseFactorParams memory params
  ) internal override returns (TestDebtToRestoreCloseFactorParams memory) {
    params = super._bound(params);
    params.totalBorrowerReserveDebt = bound(
      params.totalBorrowerReserveDebt,
      _convertBaseCurrencyToAmount(
        LiquidationLogic.MIN_LEFTOVER_BASE * 10,
        params.debtAssetPrice,
        params.debtAssetUnit
      ), // initialize with enough base threshold to avoid dust
      _convertBaseCurrencyToAmount(
        MAX_SUPPLY_IN_BASE_CURRENCY,
        params.debtAssetPrice,
        params.debtAssetUnit
      )
    );
    return params;
  }
}
