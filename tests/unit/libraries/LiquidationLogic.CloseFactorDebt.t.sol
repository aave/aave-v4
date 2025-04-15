// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
// import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
// import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import 'tests/Base.t.sol';

contract LiquidationLogicCloseFactorDebtTest is Base {
  using PercentageMath for uint256;
  using WadRayMath for uint256;

  // (debt * assetPrice).wadify() / assetUnit
  uint256 internal constant MAX_TOTAL_DEBT_IN_BASE_CURRENCY = 1e58;

  struct FieldsToSkip {
    uint256 flags;
  }

  uint256 constant SKIP_NONE = 0;
  uint256 constant SKIP_LIQUIDATION_BONUS = 1 << 0;
  uint256 constant SKIP_COLLATERAL_FACTOR = 1 << 1;
  uint256 constant SKIP_AVG_COLLATERAL_FACT = 1 << 2;
  uint256 constant SKIP_TOTAL_DEBT = 1 << 3;
  uint256 constant SKIP_DEBT_ASSET_PRICE = 1 << 4;
  uint256 constant SKIP_CLOSE_FACTOR = 1 << 5;
  uint256 constant SKIP_DEBT_ASSET_UNIT = 1 << 6;

  function _isSkipped(FieldsToSkip memory skip, uint256 field) internal pure returns (bool) {
    return (skip.flags & field) != 0;
  }

  function _skipOnly(uint256 flags) internal pure returns (FieldsToSkip memory) {
    return FieldsToSkip({flags: flags});
  }

  function _bound(
    TestCloseFactorDebtParams memory params,
    FieldsToSkip memory skip
  ) internal returns (TestCloseFactorDebtParams memory) {
    if (!_isSkipped(skip, SKIP_LIQUIDATION_BONUS)) {
      params.liquidationBonus = bound(
        params.liquidationBonus,
        MIN_LIQUIDATION_BONUS,
        MAX_LIQUIDATION_BONUS
      );
    }

    if (!_isSkipped(skip, SKIP_COLLATERAL_FACTOR)) {
      params.collateralFactor = bound(params.collateralFactor, 1, MAX_COLLATERAL_FACTOR);
    }

    if (!_isSkipped(skip, SKIP_AVG_COLLATERAL_FACT)) {
      params.avgCollateralFactor = bound(params.avgCollateralFactor, 1, MAX_COLLATERAL_FACTOR);
    }

    if (!_isSkipped(skip, SKIP_TOTAL_DEBT)) {
      params.totalDebtInBaseCurrency = bound(
        params.totalDebtInBaseCurrency,
        1,
        MAX_TOTAL_DEBT_IN_BASE_CURRENCY
      );
    }

    if (!_isSkipped(skip, SKIP_DEBT_ASSET_PRICE)) {
      params.debtAssetPrice = bound(params.debtAssetPrice, 1, MAX_DEBT_ASSET_PRICE);
    }

    if (!_isSkipped(skip, SKIP_CLOSE_FACTOR)) {
      params.closeFactor = bound(
        params.closeFactor,
        _calculateCloseFactorThreshold(params.liquidationBonus, params.collateralFactor),
        MAX_CLOSE_FACTOR
      );
    }

    if (!_isSkipped(skip, SKIP_DEBT_ASSET_UNIT)) {
      params.debtAssetUnit = bound(params.debtAssetUnit, 1, 10 ** MAX_TOKEN_DECIMALS_SUPPORTED);
    }

    return params;
  }

  struct TestCloseFactorDebtParams {
    uint256 liquidationBonus;
    uint256 collateralFactor;
    uint256 closeFactor;
    uint256 totalDebtInBaseCurrency;
    uint256 debtAssetPrice;
    uint256 avgCollateralFactor;
    uint256 debtAssetUnit;
  }

  // function _bound(
  //   TestCloseFactorDebtParams memory params
  // ) internal returns (TestCloseFactorDebtParams memory) {
  //   params.liquidationBonus = bound(
  //     params.liquidationBonus,
  //     MIN_LIQUIDATION_BONUS,
  //     MAX_LIQUIDATION_BONUS
  //   );
  //   params.collateralFactor = bound(params.collateralFactor, 1, MAX_COLLATERAL_FACTOR);
  //   params.avgCollateralFactor = bound(params.avgCollateralFactor, 1, MAX_COLLATERAL_FACTOR);
  //   params.totalDebtInBaseCurrency = bound(
  //     params.totalDebtInBaseCurrency,
  //     1,
  //     MAX_TOTAL_DEBT_IN_BASE_CURRENCY
  //   );
  //   params.debtAssetPrice = bound(params.debtAssetPrice, 1, MAX_DEBT_ASSET_PRICE);
  //   params.closeFactor = bound(
  //     params.closeFactor,
  //     _calculateCloseFactorThreshold(params.liquidationBonus, params.collateralFactor),
  //     MAX_CLOSE_FACTOR
  //   );

  //   return params;
  // }

  function _setFunctionArgs(
    TestCloseFactorDebtParams memory params
  ) internal returns (DataTypes.LiquidationCallLocalVars memory result) {
    result.liquidationBonus = params.liquidationBonus;
    result.collateralFactor = params.collateralFactor;
    result.closeFactor = params.closeFactor;
    result.totalDebtInBaseCurrency = params.totalDebtInBaseCurrency;
    result.debtAssetPrice = params.debtAssetPrice;
    result.avgCollateralFactor = params.avgCollateralFactor;
    result.debtAssetUnit = params.debtAssetUnit;
  }

  function testDebug() public {
    TestCloseFactorDebtParams memory params;
    testCalculateCloseFactorDebt_debtAssetUnit_zero(params);
  }

  /// if debtAssetUnit == 0, then result is 0 (should not happen in practice as unit is 10**decimals)
  function testCalculateCloseFactorDebt_debtAssetUnit_zero(
    TestCloseFactorDebtParams memory params
  ) public {
    // params = _bound(params);
    FieldsToSkip memory skips = _skipOnly(SKIP_DEBT_ASSET_UNIT);
    TestCloseFactorDebtParams memory params = _bound(params, skips);
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    // units is 0
    args.debtAssetUnit = 0;

    assertEq(LiquidationLogic.calculateCloseFactorDebt(args), 0, 'closeFactorDebt is 0');
  }

  function testCalculateCloseFactorDebt_debtAssetPrice_zero(
    TestCloseFactorDebtParams memory params
  ) public {
    // params = _bound(params);
    FieldsToSkip memory skips = _skipOnly(SKIP_DEBT_ASSET_PRICE);
    TestCloseFactorDebtParams memory params = _bound(params, skips);
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    // units is 0
    args.debtAssetPrice = 0;

    assertEq(
      LiquidationLogic.calculateCloseFactorDebt(args),
      type(uint256).max,
      'closeFactorDebt is 0'
    );
  }

  function testCalculateCloseFactorDebt_closeFactor_lte_effectiveLiquidationPenalty_zero(
    TestCloseFactorDebtParams memory params
  ) public {
    // params = _bound(params);
    FieldsToSkip memory skips = _skipOnly(SKIP_CLOSE_FACTOR);
    TestCloseFactorDebtParams memory params = _bound(params, skips);
    params.closeFactor = bound(
      params.closeFactor,
      1, // in practice CF >= 1e18
      _calculateCloseFactorThreshold(params.liquidationBonus, params.collateralFactor)
    );
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    // units is 0
    args.debtAssetPrice = 0;

    assertEq(
      LiquidationLogic.calculateCloseFactorDebt(args),
      type(uint256).max,
      'closeFactorDebt is max uint'
    );
  }

  // /// if debtAssetUnit == 0, then result is 0 (should not happen in practice as unit is 10**decimals)
  // function testCalculateCloseFactorDebt_avgCollateralFactor_zero(
  //   TestCloseFactorDebtParams memory params
  // ) public {
  //   params = _bound(params, FieldsToSkip.AvgCollateralFactor);
  //   DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

  //   args.avgCollateralFactor = 0;

  //   assertEq(LiquidationLogic.calculateCloseFactorDebt(args), 0, 'closeFactorDebt is 0');
  // }

  // for close factor > effectiveLiquidationPenalty, and positive denominator in calc
  function _calculateCloseFactorThreshold(
    uint256 liquidationBonus,
    uint256 collateralFactor
  ) internal returns (uint256) {
    return _calculateEffectiveLiquidationPenaltyThreshold(liquidationBonus, collateralFactor) + 1;
  }

  function _calculateEffectiveLiquidationPenaltyThreshold(
    uint256 liquidationBonus,
    uint256 collateralFactor
  ) internal returns (uint256) {
    return (liquidationBonus.wadify()).percentMul(collateralFactor).fromBps();
  }
}
