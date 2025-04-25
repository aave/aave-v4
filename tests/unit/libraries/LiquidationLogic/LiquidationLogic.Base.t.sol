// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import 'tests/Base.t.sol';

contract LiquidationLogicBaseTest is Base {
  using PercentageMath for uint256;
  using WadRayMath for uint256;

  uint256 internal constant MAX_TOTAL_ASSET_IN_BASE_CURRENCY = 1e58;

  uint256 constant SKIP_NONE = 0;
  uint256 constant SKIP_LIQUIDATION_BONUS = 1 << 0;
  uint256 constant SKIP_COLLATERAL_FACTOR = 1 << 1;
  uint256 constant SKIP_CLOSE_FACTOR = 1 << 2;
  uint256 constant SKIP_TOTAL_DEBT = 1 << 3;
  uint256 constant SKIP_DEBT_ASSET_PRICE = 1 << 4;
  uint256 constant SKIP_DEBT_ASSET_UNIT = 1 << 5;
  uint256 constant SKIP_HF = 1 << 6;

  struct FieldsToSkip {
    uint256 flags;
  }

  uint256 internal daiUnits = 1e18;
  uint256 internal usdxUnits = 1e6;
  uint256 internal wethUnits = 1e18;
  uint256 internal wbtcUnits = 1e8;

  struct TestCloseFactorDebtParams {
    uint256 liquidationBonus;
    uint256 collateralFactor;
    uint256 closeFactor;
    uint256 totalDebtInBaseCurrency;
    uint256 debtAssetPrice;
    uint256 debtAssetUnit;
    uint256 healthFactor;
  }

  function setUp() public virtual override {
    super.setUp();
    initEnvironment();
  }

  function _calcCloseFactorDebtZeroAvgCollateralFactor(
    TestCloseFactorDebtParams memory params
  ) internal pure returns (uint256) {
    uint256 effectiveLiquidationPenalty = (params.liquidationBonus.wadify())
      .percentMul(params.collateralFactor)
      .fromBps();

    return
      (params.totalDebtInBaseCurrency.wadMul(params.closeFactor) * params.debtAssetUnit) /
      ((params.closeFactor - effectiveLiquidationPenalty) * params.debtAssetPrice) +
      1;
  }

  // for close factor > effectiveLiquidationPenalty, and positive denominator in calc
  function _calculateCloseFactorThreshold(
    uint256 liquidationBonus,
    uint256 collateralFactor
  ) internal pure returns (uint256) {
    return _calculateEffectiveLiquidationPenaltyThreshold(liquidationBonus, collateralFactor) + 1;
  }

  function _calculateEffectiveLiquidationPenaltyThreshold(
    uint256 liquidationBonus,
    uint256 collateralFactor
  ) internal pure returns (uint256) {
    return (liquidationBonus.wadify()).percentMul(collateralFactor - 1).fromBps();
  }

  function _isSkipped(FieldsToSkip memory skip, uint256 field) internal pure returns (bool) {
    return (skip.flags & field) != 0;
  }

  function _skipOnly(uint256 flags) internal pure returns (FieldsToSkip memory) {
    return FieldsToSkip({flags: flags});
  }

  function _setFunctionArgs(
    TestCloseFactorDebtParams memory params
  ) internal pure returns (DataTypes.LiquidationCallLocalVars memory result) {
    result.liquidationBonus = params.liquidationBonus;
    result.collateralFactor = params.collateralFactor;
    result.closeFactor = params.closeFactor;
    result.totalDebtInBaseCurrency = params.totalDebtInBaseCurrency;
    result.debtAssetPrice = params.debtAssetPrice;
    result.debtAssetUnit = params.debtAssetUnit;
    result.healthFactor = params.healthFactor;
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

    if (!_isSkipped(skip, SKIP_TOTAL_DEBT)) {
      params.totalDebtInBaseCurrency = bound(
        params.totalDebtInBaseCurrency,
        1,
        MAX_TOTAL_ASSET_IN_BASE_CURRENCY
      );
    }

    if (!_isSkipped(skip, SKIP_DEBT_ASSET_PRICE)) {
      params.debtAssetPrice = bound(params.debtAssetPrice, 1, MAX_ASSET_PRICE);
    }

    if (!_isSkipped(skip, SKIP_CLOSE_FACTOR)) {
      params.closeFactor = bound(
        params.closeFactor,
        _calculateCloseFactorThreshold(params.liquidationBonus, params.collateralFactor),
        MAX_CLOSE_FACTOR
      );
    }

    params.healthFactor = bound(params.healthFactor, 0, params.closeFactor);

    if (!_isSkipped(skip, SKIP_DEBT_ASSET_UNIT)) {
      params.debtAssetUnit = bound(params.debtAssetUnit, 1, 10 ** MAX_TOKEN_DECIMALS_SUPPORTED);
    }

    return params;
  }
}
