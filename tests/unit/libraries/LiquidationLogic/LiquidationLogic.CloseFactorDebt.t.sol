// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicCloseFactorDebtTest is LiquidationLogicBaseTest {
  using PercentageMath for uint256;
  using WadRayMath for uint256;
  using WadRayMathExtended for uint256;

  function test_calculateCloseFactorDebt_fuzz_non_negative(
    TestCloseFactorDebtParams memory params
  ) public {
    FieldsToSkip memory skips = _skipOnly(SKIP_NONE);
    TestCloseFactorDebtParams memory params = _bound(params, skips);
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    assertGe(
      LiquidationLogic.calculateCloseFactorDebt(args),
      0,
      'closeFactorDebt cannot underflow'
    );
  }

  /// if debtAssetUnit == 0, then result is 0 (should not happen in practice as unit is 10**decimals)
  function test_calculateCloseFactorDebt_fuzz_debtAssetUnit_zero(
    TestCloseFactorDebtParams memory params
  ) public {
    // params = _bound(params);
    FieldsToSkip memory skips = _skipOnly(SKIP_DEBT_ASSET_UNIT);
    TestCloseFactorDebtParams memory params = _bound(params, skips);
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    args.debtAssetUnit = 0;

    assertEq(LiquidationLogic.calculateCloseFactorDebt(args), 1, 'closeFactorDebt is 1');
  }

  function test_calculateCloseFactorDebt_fuzz_debtAssetPrice_zero(
    TestCloseFactorDebtParams memory params
  ) public {
    FieldsToSkip memory skips = _skipOnly(SKIP_DEBT_ASSET_PRICE);
    TestCloseFactorDebtParams memory params = _bound(params, skips);
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    args.debtAssetPrice = 0;

    assertEq(
      LiquidationLogic.calculateCloseFactorDebt(args),
      type(uint256).max,
      'closeFactorDebt is 0'
    );
  }

  /// if denom is ever negative, default to uint max
  function test_calculateCloseFactorDebt_fuzz_closeFactor_lte_effectiveLiquidationPenalty_zero(
    TestCloseFactorDebtParams memory params
  ) public {
    FieldsToSkip memory skips = _skipOnly(SKIP_CLOSE_FACTOR);
    TestCloseFactorDebtParams memory params = _bound(params, skips);
    params.closeFactor = bound(
      params.closeFactor,
      1, // in practice CF >= 1e18
      _calculateCloseFactorThreshold(params.liquidationBonus, params.collateralFactor) - 1
    );
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    assertEq(
      LiquidationLogic.calculateCloseFactorDebt(args),
      type(uint256).max,
      'closeFactorDebt is max uint'
    );
  }

  function test_calculateCloseFactorDebt_fuzz_avgCollateralFactor_zero(
    TestCloseFactorDebtParams memory params
  ) public {
    FieldsToSkip memory skips = _skipOnly(SKIP_AVG_COLLATERAL_FACTOR);
    params = _bound(params, skips);

    params.avgCollateralFactor = 0;
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    assertEq(
      LiquidationLogic.calculateCloseFactorDebt(args),
      _calcCloseFactorDebtZeroAvgCollateralFactor(params),
      'closeFactorDebt is incorrect'
    );
  }
}
