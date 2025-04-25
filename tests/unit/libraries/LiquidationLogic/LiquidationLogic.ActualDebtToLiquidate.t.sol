// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicActualDebtToLiquidateTest is LiquidationLogicBaseTest {
  function _bound(
    TestDebtToRestoreCloseFactorParams memory params,
    FieldsToSkip memory skip
  ) internal override returns (TestDebtToRestoreCloseFactorParams memory) {
    params = super._bound(params, skip);
    params.totalDebt = bound(
      params.totalDebt,
      1,
      MAX_TOTAL_ASSET_IN_BASE_CURRENCY / params.debtAssetUnit
    );
    return params;
  }

  function test_calculateActualDebtToLiquidate_fuzz_totalDebt_zero(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    FieldsToSkip memory skips = _skipOnly(SKIP_NONE);
    TestDebtToRestoreCloseFactorParams memory params = _bound(params, skips);
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    // zero total debt; should be reverted by validation in practice
    uint256 totalDebt = 0;
    args.totalDebt = totalDebt;

    uint256 debtToRestoreCloseFactor = LiquidationLogic.calculateDebtToRestoreCloseFactor(args);
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

  function test_calculateActualDebtToLiquidate_fuzz_debtToCover_zero(
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    FieldsToSkip memory skips = _skipOnly(SKIP_NONE);
    TestDebtToRestoreCloseFactorParams memory params = _bound(params, skips);
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    // zero debtToCover; should be reverted by validation in practice
    uint256 debtToCover = 0;

    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      debtToCover,
      args
    );

    assertEq(actualDebtToLiquidate, 0, 'if debtToCover == 0, actualDebtToLiquidate should be 0');
  }

  function test_calculateActualDebtToLiquidate_fuzz_debtToRestoreCloseFactor_lte_totalDebt(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    FieldsToSkip memory skips = _skipOnly(SKIP_NONE);
    TestDebtToRestoreCloseFactorParams memory params = _bound(params, skips);
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

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

  function test_calculateActualDebtToLiquidate_fuzz_debtToRestoreCloseFactor_gt_maxLiquidatableDebt(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    FieldsToSkip memory skips = _skipOnly(SKIP_NONE);
    TestDebtToRestoreCloseFactorParams memory params = _bound(params, skips);
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    uint256 debtToRestoreCloseFactor = LiquidationLogic.calculateDebtToRestoreCloseFactor(args);
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

  function test_calculateActualDebtToLiquidate_fuzz_debtToRestoreCloseFactor_zero(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    FieldsToSkip memory skips = _skipOnly(SKIP_NONE);
    TestDebtToRestoreCloseFactorParams memory params = _bound(params, skips);
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    uint256 debtToRestoreCloseFactor = LiquidationLogic.calculateDebtToRestoreCloseFactor(args);
    vm.assume(debtToRestoreCloseFactor == 0);

    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      debtToCover,
      args
    );

    assertEq(actualDebtToLiquidate, 0, 'actualDebtToLiquidate should be 0');
  }

  function test_calculateActualDebtToLiquidate_fuzz_debtToRestoreCloseFactor_min(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    FieldsToSkip memory skips = _skipOnly(SKIP_NONE);
    TestDebtToRestoreCloseFactorParams memory params = _bound(params, skips);
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    uint256 debtToRestoreCloseFactor = LiquidationLogic.calculateDebtToRestoreCloseFactor(args);
    vm.assume(debtToRestoreCloseFactor == 0);

    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      debtToCover,
      args
    );

    assertEq(actualDebtToLiquidate, 0, 'actualDebtToLiquidate should be min allowed debt');
  }
}
