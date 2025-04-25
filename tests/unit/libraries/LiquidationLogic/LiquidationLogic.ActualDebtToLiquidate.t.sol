// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicActualDebtToLiquidateTest is LiquidationLogicBaseTest {
  function test_calculateActualDebtToLiquidate_fuzz_totalDebt_zero(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    TestDebtToRestoreCloseFactorParams memory params = _bound(params);
    DataTypes.LiquidationCallLocalVars memory args = _setStructFields(params);

    // zero total debt; should be reverted by validation in practice
    args.totalDebt = 0;

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
    TestDebtToRestoreCloseFactorParams memory params = _bound(params);
    DataTypes.LiquidationCallLocalVars memory args = _setStructFields(params);

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
    TestDebtToRestoreCloseFactorParams memory params = _bound(params);
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

  function test_calculateActualDebtToLiquidate_fuzz_debtToRestoreCloseFactor_gt_maxLiquidatableDebt(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    TestDebtToRestoreCloseFactorParams memory params = _bound(params);
    DataTypes.LiquidationCallLocalVars memory args = _setStructFields(params);

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
    TestDebtToRestoreCloseFactorParams memory params = _bound(params);
    DataTypes.LiquidationCallLocalVars memory args = _setStructFields(params);

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
    TestDebtToRestoreCloseFactorParams memory params = _bound(params);
    DataTypes.LiquidationCallLocalVars memory args = _setStructFields(params);

    uint256 debtToRestoreCloseFactor = LiquidationLogic.calculateDebtToRestoreCloseFactor(args);
    vm.assume(debtToRestoreCloseFactor == 0);

    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      debtToCover,
      args
    );

    assertEq(actualDebtToLiquidate, 0, 'actualDebtToLiquidate should be min allowed debt');
  }

  function _bound(
    TestDebtToRestoreCloseFactorParams memory params
  ) internal override returns (TestDebtToRestoreCloseFactorParams memory) {
    params = super._bound(params);
    params.totalDebt = bound(
      params.totalDebt,
      1,
      MAX_TOTAL_ASSET_IN_BASE_CURRENCY / params.debtAssetUnit
    );
    return params;
  }
}
