// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

/// test calculateActualDebtToLiquidate without dust accumulation
contract LiquidationLogicActualDebtToLiquidateTest is LiquidationLogicBaseTest {
  using LiquidationLogic for DataTypes.LiquidationCallLocalVars;

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

    (bool isDustAmountExpected, , ) = isDustAmountExpected(debtToCover, params);
    vm.assume(!isDustAmountExpected);

    uint256 actualDebtToLiquidate = params.calculateActualDebtToLiquidate(debtToCover);

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

    (bool isDustAmountExpected, , ) = isDustAmountExpected(debtToCover, params);
    vm.assume(!isDustAmountExpected);

    uint256 actualDebtToLiquidate = params.calculateActualDebtToLiquidate(debtToCover);

    assertEq(actualDebtToLiquidate, 0, 'if debtToCover == 0, actualDebtToLiquidate should be 0');
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
    params.debtToRestoreCloseFactor = 0;

    (bool isDustAmountExpected, , ) = isDustAmountExpected(debtToCover, params);
    vm.assume(!isDustAmountExpected);

    uint256 actualDebtToLiquidate = params.calculateActualDebtToLiquidate(debtToCover);

    assertEq(actualDebtToLiquidate, 0, 'actualDebtToLiquidate should be 0');
  }

  /// test calculateActualDebtToLiquidate when debtToRestoreCloseFactor is lowest non-zero value among debtToCover, totalBorrowerReserveDebt, and debtToRestoreCloseFactor
  function test_calculateActualDebtToLiquidate_fuzz_debtToRestoreCloseFactor_lowest(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    debtToCover = bound(debtToCover, 1, type(uint256).max);
    params = _bound(params);
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);

    params.debtToRestoreCloseFactor = bound(
      params.debtToRestoreCloseFactor,
      1,
      _min(params.totalBorrowerReserveDebt, debtToCover)
    );

    (bool isDustAmountExpected, , uint256 expectedDebtToLiquidate) = isDustAmountExpected(
      debtToCover,
      params
    );
    vm.assume(!isDustAmountExpected);

    uint256 actualDebtToLiquidate = params.calculateActualDebtToLiquidate(debtToCover);

    assertEq(actualDebtToLiquidate, expectedDebtToLiquidate, 'should return min allowed');
  }

  /// test calculateActualDebtToLiquidate when debtToRestoreCloseFactor is intermediate value among debtToCover, totalBorrowerReserveDebt, and debtToRestoreCloseFactor
  /// debtToCover > totalBorrowerReserveDebt
  function test_calculateActualDebtToLiquidate_fuzz_debtToRestoreCloseFactor_intermediate(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);
    debtToCover = bound(debtToCover, params.totalBorrowerReserveDebt + 1, type(uint256).max);

    params.debtToRestoreCloseFactor = bound(
      params.debtToRestoreCloseFactor,
      params.totalBorrowerReserveDebt,
      debtToCover
    );

    (bool isDustAmountExpected, , uint256 expectedDebtToLiquidate) = isDustAmountExpected(
      debtToCover,
      params
    );
    vm.assume(!isDustAmountExpected);

    uint256 actualDebtToLiquidate = params.calculateActualDebtToLiquidate(debtToCover);

    assertEq(actualDebtToLiquidate, expectedDebtToLiquidate, 'should return min allowed');
  }

  /// test calculateActualDebtToLiquidate when debtToRestoreCloseFactor is intermediate value among debtToCover, totalBorrowerReserveDebt, and debtToRestoreCloseFactor
  /// debtToCover < totalBorrowerReserveDebt
  function test_calculateActualDebtToLiquidate_fuzz_debtToRestoreCloseFactor_intermediate2(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);
    debtToCover = bound(debtToCover, 0, params.totalBorrowerReserveDebt - 1);

    params.debtToRestoreCloseFactor = bound(
      params.debtToRestoreCloseFactor,
      debtToCover,
      params.totalBorrowerReserveDebt
    );

    (bool isDustAmountExpected, , uint256 expectedDebtToLiquidate) = isDustAmountExpected(
      debtToCover,
      params
    );
    vm.assume(!isDustAmountExpected);

    uint256 actualDebtToLiquidate = params.calculateActualDebtToLiquidate(debtToCover);

    assertEq(actualDebtToLiquidate, expectedDebtToLiquidate, 'should return min allowed');
  }

  // happy path without dust; should return min of debtToCover, totalBorrowerReserveDebt, and debtToRestoreCloseFactor
  function test_calculateActualDebtToLiquidate_fuzz(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);

    (bool isDustAmountExpected, , uint256 expectedDebtToLiquidate) = isDustAmountExpected(
      debtToCover,
      params
    );
    vm.assume(!isDustAmountExpected);

    uint256 actualDebtToLiquidate = params.calculateActualDebtToLiquidate(debtToCover);

    assertEq(actualDebtToLiquidate, expectedDebtToLiquidate, 'should return min allowed');
  }

  /// if totalBorrowerReserveDebt is lowest, then naive debt to liquidate is always totalBorrowerReserveDebt
  function test_calculateActualDebtToLiquidate_fuzz_totalBorrowerReserveDebt_lowest(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);

    vm.assume(params.totalBorrowerReserveDebt < _min(debtToCover, params.debtToRestoreCloseFactor));
    (bool isDustAmountExpected, , ) = isDustAmountExpected(debtToCover, params);
    vm.assume(!isDustAmountExpected);

    uint256 actualDebtToLiquidate = params.calculateActualDebtToLiquidate(debtToCover);
    assertEq(
      actualDebtToLiquidate,
      params.totalBorrowerReserveDebt,
      'should return totalBorrowerReserveDebt'
    );
  }

  /// bound fuzz inputs
  function _bound(
    TestDebtToRestoreCloseFactorParams memory params
  ) internal override returns (TestDebtToRestoreCloseFactorParams memory) {
    params = super._bound(params);
    params.totalBorrowerReserveDebt = bound(
      params.totalBorrowerReserveDebt,
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
