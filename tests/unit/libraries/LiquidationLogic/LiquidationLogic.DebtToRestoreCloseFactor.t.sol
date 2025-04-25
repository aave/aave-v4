// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicDebtToRestoreCloseFactorTest is LiquidationLogicBaseTest {
  using PercentageMath for uint256;
  using WadRayMath for uint256;
  using WadRayMathExtended for uint256;

  function test_calculateDebtToRestoreCloseFactor_fuzz_non_negative(
    TestCloseFactorDebtParams memory params
  ) public {
    FieldsToSkip memory skips = _skipOnly(SKIP_NONE);
    TestCloseFactorDebtParams memory params = _bound(params, skips);
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    // cannot revert if all params are constrained
    LiquidationLogic.calculateDebtToRestoreCloseFactor(args);
  }

  /// if debtAssetUnit == 0, then result is 0 (should not happen in practice as unit is 10**decimals)
  function test_calculateDebtToRestoreCloseFactor_fuzz_debtAssetUnit_zero(
    TestCloseFactorDebtParams memory params
  ) public {
    FieldsToSkip memory skips = _skipOnly(SKIP_DEBT_ASSET_UNIT);
    TestCloseFactorDebtParams memory params = _bound(params, skips);
    // so that default uint max is not returned
    vm.assume(
      (params.liquidationBonus.wadify()).percentMul(params.collateralFactor + 1).fromBps() <
        params.closeFactor
    );

    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    args.debtAssetUnit = 0;

    assertEq(LiquidationLogic.calculateDebtToRestoreCloseFactor(args), 0, 'closeFactorDebt is 0');
  }

  function calculateDebtToRestoreCloseFactor(
    DataTypes.LiquidationCallLocalVars memory params
  ) public pure {
    LiquidationLogic.calculateDebtToRestoreCloseFactor(params);
  }

  /// should not happen in practice
  function test_calculateDebtToRestoreCloseFactor_fuzz_debtAssetPrice_zero(
    TestCloseFactorDebtParams memory params
  ) public {
    FieldsToSkip memory skips = _skipOnly(SKIP_DEBT_ASSET_PRICE);
    TestCloseFactorDebtParams memory params = _bound(params, skips);
    // so that default uint max is not returned
    vm.assume(
      (params.liquidationBonus.wadify()).percentMul(params.collateralFactor + 1).fromBps() <
        params.closeFactor
    );
    params.debtAssetPrice = 0;
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    vm.expectRevert(stdError.divisionError);
    this.calculateDebtToRestoreCloseFactor(args);
  }

  function test_calculateDebtToRestoreCloseFactor_cf_eq_hf(
    TestCloseFactorDebtParams memory params
  ) public {
    FieldsToSkip memory skips = _skipOnly(SKIP_NONE);
    TestCloseFactorDebtParams memory params = _bound(params, skips);
    params.healthFactor = params.closeFactor;
    // so that default uint max is not returned
    vm.assume(
      (params.liquidationBonus.wadify()).percentMul(params.collateralFactor).fromBps() <
        params.closeFactor
    );
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    assertEq(LiquidationLogic.calculateDebtToRestoreCloseFactor(args), 0, 'closeFactorDebt is 0');
  }

  function test_calculateDebtToRestoreCloseFactor_cf_lt_hf(
    TestCloseFactorDebtParams memory params
  ) public {
    FieldsToSkip memory skips = _skipOnly(SKIP_NONE);
    TestCloseFactorDebtParams memory params = _bound(params, skips);
    params.healthFactor = params.closeFactor + 1;
    // so that default uint max is not returned
    vm.assume(
      (params.liquidationBonus.wadify()).percentMul(params.collateralFactor + 1).fromBps() <
        params.closeFactor
    );
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    vm.expectRevert(stdError.arithmeticError);
    this.calculateDebtToRestoreCloseFactor(args);
  }

  /// if denom is ever negative, default to uint max
  function test_calculateDebtToRestoreCloseFactor_fuzz_closeFactor_lte_effectiveLiquidationPenalty_zero(
    TestCloseFactorDebtParams memory params
  ) public {
    FieldsToSkip memory skips = _skipOnly(SKIP_CLOSE_FACTOR);
    TestCloseFactorDebtParams memory params = _bound(params, skips);
    vm.assume(
      _calculateCloseFactorThreshold(params.liquidationBonus, params.collateralFactor) - 1 >=
        HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );
    params.closeFactor = bound(
      params.closeFactor,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      _calculateCloseFactorThreshold(params.liquidationBonus, params.collateralFactor) - 1
    );
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    assertEq(
      LiquidationLogic.calculateDebtToRestoreCloseFactor(args),
      type(uint256).max,
      'closeFactorDebt is max uint'
    );
  }
}
