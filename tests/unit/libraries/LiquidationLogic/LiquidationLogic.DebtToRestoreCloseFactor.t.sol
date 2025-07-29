// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicDebtToRestoreCloseFactorTest is LiquidationLogicBaseTest {
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  /// fuzz test showing that the function does not revert when bounded properly
  function test_calculateDebtToRestoreCloseFactor_fuzz_non_negative(
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    DataTypes.LiquidationCallLocalVars memory args = _setStructFields(params);

    // cannot revert if all params are constrained
    LiquidationLogic.calculateDebtToRestoreCloseFactor(args);
  }

  /// if debtAssetUnit == 0, then result is 0 (should not happen in practice as unit is 10**decimals)
  function test_calculateDebtToRestoreCloseFactor_fuzz_debtAssetUnit_zero(
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    // so that default uint max is not returned
    vm.assume(
      (params.liquidationBonus.toWad()).percentMulDown(params.collateralFactor).fromBpsDown() - 1 <
        params.closeFactor
    );
    params.debtAssetUnit = 0;
    DataTypes.LiquidationCallLocalVars memory args = _setStructFields(params);

    assertEq(LiquidationLogic.calculateDebtToRestoreCloseFactor(args), 0, 'closeFactorDebt is 0');
  }

  /// if totalDebtInBaseCurrency == 0, then result is 0
  /// debtAssetPrice = 0 should not happen in practice
  function test_calculateDebtToRestoreCloseFactor_fuzz_debtAssetPrice_zero(
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    // so that default uint max is not returned
    // ie params.closeFactor > effectiveLiquidationPenalty
    vm.assume(
      (params.liquidationBonus.toWad()).percentMulDown(params.collateralFactor).fromBpsDown() - 1 <
        params.closeFactor
    );
    params.debtAssetPrice = 0;
    DataTypes.LiquidationCallLocalVars memory args = _setStructFields(params);

    vm.expectRevert(stdError.divisionError);
    this.calculateDebtToRestoreCloseFactor(args);
  }

  /// if close factor == HEALTH_FACTOR_LIQUIDATION_THRESHOLD, then result is 0
  function test_calculateDebtToRestoreCloseFactor_closeFactor_eq_healthFactor(
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    params.healthFactor = params.closeFactor;
    uint256 effectiveLiquidationPenalty = (params.liquidationBonus.toWad())
      .percentMulDown(params.collateralFactor)
      .fromBpsDown();
    // params.closeFactor >= effectiveLiquidationPenalty so that default uint max is not returned
    vm.assume(effectiveLiquidationPenalty <= params.closeFactor);
    DataTypes.LiquidationCallLocalVars memory args = _setStructFields(params);

    assertEq(LiquidationLogic.calculateDebtToRestoreCloseFactor(args), 0, 'closeFactorDebt is 0');
  }

  /// when close factor is less than health factor, should revert
  /// should not happen in practice
  function test_calculateDebtToRestoreCloseFactor_closeFactor_lt_healthFactor(
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    params.healthFactor = params.closeFactor + 1;
    // so that default uint max is not returned
    vm.assume(
      (params.liquidationBonus.toWad()).percentMulDown(params.collateralFactor).fromBpsDown() - 1 <
        params.closeFactor
    );
    DataTypes.LiquidationCallLocalVars memory args = _setStructFields(params);

    vm.expectRevert(stdError.arithmeticError);
    this.calculateDebtToRestoreCloseFactor(args);
  }

  /// if denom is ever negative (params.closeFactor < effectiveLiquidationPenalty), default to uint max
  function test_calculateDebtToRestoreCloseFactor_fuzz_closeFactor_lte_effectiveLiquidationPenalty_zero(
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    //
    vm.assume(
      _calculateCloseFactorThreshold(params.liquidationBonus, params.collateralFactor) >=
        HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );
    params.closeFactor = bound(
      params.closeFactor,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      _calculateCloseFactorThreshold(params.liquidationBonus, params.collateralFactor)
    );
    DataTypes.LiquidationCallLocalVars memory args = _setStructFields(params);

    assertEq(
      LiquidationLogic.calculateDebtToRestoreCloseFactor(args),
      type(uint256).max,
      'closeFactorDebt is max uint'
    );
  }

  // internal helper to trigger revert checks
  function calculateDebtToRestoreCloseFactor(
    DataTypes.LiquidationCallLocalVars memory params
  ) public pure {
    LiquidationLogic.calculateDebtToRestoreCloseFactor(params);
  }
}
