// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicActualDebtToLiquidateTest is LiquidationLogicBaseTest {
  function test_calculateActualDebtToLiquidate_fuzz_totalDebt_zero(
    uint256 debtToCover,
    TestCloseFactorDebtParams memory params
  ) public {
    FieldsToSkip memory skips = _skipOnly(SKIP_NONE);
    TestCloseFactorDebtParams memory params = _bound(params, skips);
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    // zero total debt; should be reverted by validation in practice
    uint256 totalDebt = 0;
    args.totalDebt = totalDebt;

    uint256 closeFactorDebt = LiquidationLogic.calculateCloseFactorDebt(args);
    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      debtToCover,
      args
    );

    assertEq(actualDebtToLiquidate, 0, 'if totalDebt == 0, actualDebtToLiquidate should be 0');
  }

  function test_calculateActualDebtToLiquidate_fuzz_debtToCover_zero(
    uint256 totalDebt,
    TestCloseFactorDebtParams memory params
  ) public {
    FieldsToSkip memory skips = _skipOnly(SKIP_NONE);
    TestCloseFactorDebtParams memory params = _bound(params, skips);
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    // zero debtToCover; should be reverted by validation in practice
    uint256 debtToCover = 0;
    args.totalDebt = totalDebt;

    uint256 closeFactorDebt = LiquidationLogic.calculateCloseFactorDebt(args);
    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      debtToCover,
      args
    );

    assertEq(actualDebtToLiquidate, 0, 'if debtToCover == 0, actualDebtToLiquidate should be 0');
  }

  function test_calculateActualDebtToLiquidate_fuzz_totalDebt_gt_closeFactorDebt(
    uint256 debtToCover,
    uint256 totalDebt,
    TestCloseFactorDebtParams memory params
  ) public {
    FieldsToSkip memory skips = _skipOnly(SKIP_NONE);
    TestCloseFactorDebtParams memory params = _bound(params, skips);
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    uint256 closeFactorDebt = LiquidationLogic.calculateCloseFactorDebt(args);

    // totalDebt > closeFactorDebt
    totalDebt = bound(totalDebt, closeFactorDebt + 1, type(uint256).max);
    args.totalDebt = totalDebt;

    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      debtToCover,
      args
    );

    if (debtToCover > closeFactorDebt) {
      assertEq(
        actualDebtToLiquidate,
        closeFactorDebt,
        'debtToCover > closeFactorDebt, should return closeFactorDebt'
      );
    } else {
      assertEq(
        actualDebtToLiquidate,
        debtToCover,
        'debtToCover <= closeFactorDebt, should return debtToCover'
      );
    }
  }

  function test_calculateActualDebtToLiquidate_fuzz_totalDebt_lte_closeFactorDebt(
    uint256 debtToCover,
    uint256 totalDebt,
    TestCloseFactorDebtParams memory params
  ) public {
    FieldsToSkip memory skips = _skipOnly(SKIP_NONE);
    TestCloseFactorDebtParams memory params = _bound(params, skips);
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    uint256 closeFactorDebt = LiquidationLogic.calculateCloseFactorDebt(args);
    vm.assume(closeFactorDebt > 0);

    // totalDebt <= closeFactorDebt
    totalDebt = bound(totalDebt, 1, closeFactorDebt);
    args.totalDebt = totalDebt;

    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      debtToCover,
      args
    );

    if (debtToCover > totalDebt) {
      assertEq(
        actualDebtToLiquidate,
        totalDebt,
        'debtToCover > totalDebt, should return totalDebt'
      );
    } else {
      assertEq(
        actualDebtToLiquidate,
        debtToCover,
        'debtToCover <= maxLiquidatableDebt, should return debtToCover'
      );
    }
  }

  function test_calculateActualDebtToLiquidate_fuzz_closeFactorDebt_min(
    uint256 debtToCover,
    uint256 totalDebt,
    TestCloseFactorDebtParams memory params
  ) public {
    FieldsToSkip memory skips = _skipOnly(SKIP_NONE);
    TestCloseFactorDebtParams memory params = _bound(params, skips);
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    uint256 closeFactorDebt = LiquidationLogic.calculateCloseFactorDebt(args);
    vm.assume(closeFactorDebt == 1);

    args.totalDebt = totalDebt;

    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      debtToCover,
      args
    );

    uint256 minAllowed = (totalDebt > closeFactorDebt) ? closeFactorDebt : totalDebt;

    if (debtToCover < minAllowed) {
      assertEq(
        actualDebtToLiquidate,
        debtToCover,
        'debtToCover < minAllowed, should return lowest allowed debt'
      );
    } else {
      assertEq(
        actualDebtToLiquidate,
        minAllowed,
        'debtToCover >= minAllowed, should return lowest allowed debt'
      );
    }
  }

  // TODO: unit test with specific numbers and expected output
}
