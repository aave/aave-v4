// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';
import 'tests/Base.t.sol';
import 'tests/unit/Spoke/SpokeBase.t.sol';

contract LiquidationLogicBaseTest is SpokeBase {
  using PercentageMath for uint256;
  using WadRayMath for uint256;

  uint256 internal daiUnits;
  uint256 internal usdxUnits;
  uint256 internal wethUnits;
  uint256 internal wbtcUnits;

  struct TestDebtToRestoreCloseFactorParams {
    uint256 liquidationBonus;
    uint256 collateralFactor;
    uint256 closeFactor;
    uint256 totalDebtInBaseCurrency;
    uint256 debtAssetPrice;
    uint256 debtAssetUnit;
    uint256 healthFactor;
    uint256 totalBorrowerReserveDebt;
  }

  function setUp() public virtual override {
    super.setUp();
    _setTokenDecimals();
  }

  function _setTokenDecimals() internal {
    daiUnits = 10 ** tokenList.dai.decimals();
    usdxUnits = 10 ** tokenList.usdx.decimals();
    wethUnits = 10 ** tokenList.weth.decimals();
    wbtcUnits = 10 ** tokenList.wbtc.decimals();
  }

  // calculate threshold when close factor > effectiveLiquidationPenalty so that calculateDebtToRestoreCloseFactor denom is > 0
  function _calculateCloseFactorThreshold(
    uint256 liquidationBonus,
    uint256 collateralFactor
  ) internal pure returns (uint256) {
    return _calculateEffectiveLiquidationPenaltyThreshold(liquidationBonus, collateralFactor);
  }

  function _calculateEffectiveLiquidationPenaltyThreshold(
    uint256 liquidationBonus,
    uint256 collateralFactor
  ) internal pure returns (uint256) {
    return (liquidationBonus.toWad()).percentMulDown(collateralFactor - 1).fromBpsDown();
  }

  function _setStructFields(
    TestDebtToRestoreCloseFactorParams memory params
  ) internal pure returns (DataTypes.LiquidationCallLocalVars memory result) {
    result.liquidationBonus = params.liquidationBonus;
    result.collateralFactor = params.collateralFactor;
    result.closeFactor = params.closeFactor;
    result.totalDebtInBaseCurrency = params.totalDebtInBaseCurrency;
    result.debtAssetPrice = params.debtAssetPrice;
    result.debtAssetUnit = params.debtAssetUnit;
    result.healthFactor = params.healthFactor;
    result.totalBorrowerReserveDebt = params.totalBorrowerReserveDebt;
  }

  function _bound(
    TestDebtToRestoreCloseFactorParams memory params
  ) internal virtual returns (TestDebtToRestoreCloseFactorParams memory) {
    params.liquidationBonus = bound(
      params.liquidationBonus,
      MIN_LIQUIDATION_BONUS,
      MAX_LIQUIDATION_BONUS
    );
    params.collateralFactor = bound(params.collateralFactor, 1, MAX_COLLATERAL_FACTOR);
    params.totalDebtInBaseCurrency = bound(
      params.totalDebtInBaseCurrency,
      1,
      MAX_SUPPLY_IN_BASE_CURRENCY
    );
    params.debtAssetPrice = bound(params.debtAssetPrice, 1, MAX_ASSET_PRICE);
    params.closeFactor = bound(
      params.closeFactor,
      _calculateCloseFactorThreshold(params.liquidationBonus, params.collateralFactor),
      MAX_CLOSE_FACTOR
    );
    params.healthFactor = bound(params.healthFactor, 0, params.closeFactor);
    params.debtAssetUnit = 10 ** bound(params.debtAssetUnit, 0, MAX_TOKEN_DECIMALS_SUPPORTED);

    return params;
  }

  function calcNaiveDebtToLiquidate(
    uint256 debtToCover,
    DataTypes.LiquidationCallLocalVars memory params
  ) internal returns (uint256) {
    uint256 debtToRestoreCloseFactor = LiquidationLogic.calculateDebtToRestoreCloseFactor(params);
    // without accounting for dust, naively return min of debtToCover, totalBorrowerReserveDebt, and debtToRestoreCloseFactor
    return _min(params.totalBorrowerReserveDebt, _min(debtToRestoreCloseFactor, debtToCover));
  }

  function isDustAmountExpected(
    uint256 debtToCover,
    DataTypes.LiquidationCallLocalVars memory params
  ) internal returns (bool) {
    uint256 initialDebtToLiquidate = calcNaiveDebtToLiquidate(debtToCover, params);
    uint256 remainingDebtInBaseCurrency = _convertAmountToBaseCurrency(
      params.totalBorrowerReserveDebt - initialDebtToLiquidate,
      params.debtAssetPrice,
      params.debtAssetUnit
    );

    console.log('initialDebtToLiquidate %e', initialDebtToLiquidate);
    console.log('remainingDebtInBaseCurrency %e', remainingDebtInBaseCurrency);

    return
      remainingDebtInBaseCurrency < LiquidationLogic.MIN_LEFTOVER_BASE &&
      remainingDebtInBaseCurrency > 0;
  }
}
