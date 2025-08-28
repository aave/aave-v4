// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';
import {LiquidationLogicWrapper} from 'tests/mocks/LiquidationLogicWrapper.sol';
import 'tests/Base.t.sol';
import 'tests/unit/Spoke/SpokeBase.t.sol';

contract LiquidationLogicBaseTest is SpokeBase {
  using PercentageMath for uint256;
  using WadRayMath for uint256;

  LiquidationLogicWrapper public liquidationLogicWrapper;

  uint256 internal daiUnits;
  uint256 internal usdxUnits;
  uint256 internal wethUnits;
  uint256 internal wbtcUnits;

  function setUp() public virtual override {
    super.setUp();
    _setTokenDecimals();
    liquidationLogicWrapper = new LiquidationLogicWrapper();
  }

  function _setTokenDecimals() internal {
    daiUnits = 10 ** tokenList.dai.decimals();
    usdxUnits = 10 ** tokenList.usdx.decimals();
    wethUnits = 10 ** tokenList.weth.decimals();
    wbtcUnits = 10 ** tokenList.wbtc.decimals();
  }

  function _calculateLiquidationPenalty(
    uint256 liquidationBonus,
    uint256 collateralFactor
  ) internal pure returns (uint256) {
    return liquidationBonus.bpsToWad().percentMulUp(collateralFactor);
  }

  // generic bounds for liquidation logic params
  function _bound(
    LiquidationLogic.CalculateDebtToRestoreCloseFactorParams memory params
  ) internal virtual returns (LiquidationLogic.CalculateDebtToRestoreCloseFactorParams memory) {
    uint256 totalDebtInBaseCurrency = bound(
      params.totalDebtInBaseCurrency,
      1,
      MAX_SUPPLY_IN_BASE_CURRENCY
    );

    uint256 liquidationBonus = bound(
      params.variableLiquidationBonus,
      MIN_LIQUIDATION_BONUS,
      MAX_LIQUIDATION_BONUS
    );

    uint256 collateralFactor = bound(params.collateralFactor, 1, PercentageMath.PERCENTAGE_FACTOR.percentDivDown(liquidationBonus));

    uint256 closeFactor = bound(
      params.closeFactor,
      Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      MAX_CLOSE_FACTOR
    );

    uint256 healthFactor = bound(params.healthFactor, 0, closeFactor);
    uint256 debtAssetPrice = bound(params.debtAssetPrice, 1, MAX_ASSET_PRICE);
    uint256 debtAssetUnit = 10 ** bound(params.debtAssetUnit, 0, MAX_TOKEN_DECIMALS_SUPPORTED);

    return LiquidationLogic.CalculateDebtToRestoreCloseFactorParams({
      totalDebtInBaseCurrency: totalDebtInBaseCurrency,
      healthFactor: healthFactor,
      closeFactor: closeFactor,
      variableLiquidationBonus: liquidationBonus,
      collateralFactor: collateralFactor,
      debtAssetPrice: debtAssetPrice,
      debtAssetUnit: debtAssetUnit
    });
  }

  function _getDebtToRestoreCloseFactorParams(
    LiquidationLogic.CalculateMaxDebtToLiquidateParams memory params
  ) internal returns (LiquidationLogic.CalculateDebtToRestoreCloseFactorParams memory) {
    return LiquidationLogic.CalculateDebtToRestoreCloseFactorParams({
      totalDebtInBaseCurrency: params.totalDebtInBaseCurrency,
      healthFactor: params.healthFactor,
      closeFactor: params.closeFactor,
      variableLiquidationBonus: params.variableLiquidationBonus,
      collateralFactor: params.collateralFactor,
      debtAssetPrice: params.debtAssetPrice,
      debtAssetUnit: params.debtAssetUnit
    });
  }

  function _bound(
    LiquidationLogic.CalculateMaxDebtToLiquidateParams memory params
  ) internal returns (LiquidationLogic.CalculateMaxDebtToLiquidateParams memory) {
    LiquidationLogic.CalculateDebtToRestoreCloseFactorParams memory debtToRestoreCloseFactorParams = 
      _bound(_getDebtToRestoreCloseFactorParams(params));

    uint256 debtToCover = bound(params.debtToCover, 0, MAX_SUPPLY_AMOUNT);
    uint256 totalReserveDebt = bound(params.totalReserveDebt, 0, MAX_SUPPLY_AMOUNT);

    return LiquidationLogic.CalculateMaxDebtToLiquidateParams({
      totalReserveDebt: totalReserveDebt,
      debtToCover: debtToCover,
      totalDebtInBaseCurrency: debtToRestoreCloseFactorParams.totalDebtInBaseCurrency,
      healthFactor: debtToRestoreCloseFactorParams.healthFactor,
      closeFactor: debtToRestoreCloseFactorParams.closeFactor,
      variableLiquidationBonus: debtToRestoreCloseFactorParams.variableLiquidationBonus,
      collateralFactor: debtToRestoreCloseFactorParams.collateralFactor,
      debtAssetPrice: debtToRestoreCloseFactorParams.debtAssetPrice,
      debtAssetUnit: debtToRestoreCloseFactorParams.debtAssetUnit
    });
  }

  function _boundNoRevert(
    LiquidationLogic.CalculateMaxDebtToLiquidateParams memory params
  ) internal returns (LiquidationLogic.CalculateMaxDebtToLiquidateParams memory) {
    params = _bound(params);
    try liquidationLogicWrapper.calculateMaxDebtToLiquidate(params) returns (uint256) {
      return params;
    } catch {
      params.debtToCover = bound(params.debtToCover, params.totalReserveDebt, MAX_SUPPLY_AMOUNT);
      return params;
    }
  }

  function calcNaiveDebtToLiquidate(
    uint256 debtToCover,
    DataTypes.LiquidationCallLocalVars memory params
  ) internal returns (uint256) {
    // without accounting for dust, naively return min of debtToCover, totalBorrowerReserveDebt, and debtToRestoreCloseFactor
    return
      _min(params.totalBorrowerReserveDebt, _min(params.debtToRestoreCloseFactor, debtToCover));
  }

  /// @dev Check if the remaining debt in base currency is less than the minimum leftover base and greater than 0
  /// @return isDustAmountExpected True if the remaining debt in base currency is less than the minimum leftover base and greater than 0 (non zero dust remains)
  /// @return remainingDebtInBaseCurrency The remaining debt in base currency after naive debt to liquidate is applied
  /// @return naiveDebtToLiquidate The naive debt to liquidate, without adjustment for dust
  function isDustAmountExpected(
    uint256 debtToCover,
    DataTypes.LiquidationCallLocalVars memory params
  ) internal returns (bool, uint256, uint256) {
    uint256 naiveDebtToLiquidate = calcNaiveDebtToLiquidate(debtToCover, params);
    uint256 remainingDebtInBaseCurrency = _convertAmountToBaseCurrency(
      params.totalBorrowerReserveDebt - naiveDebtToLiquidate,
      params.debtAssetPrice,
      params.debtAssetUnit
    );

    return (
      remainingDebtInBaseCurrency < LiquidationLogic.MIN_LEFTOVER_BASE &&
        remainingDebtInBaseCurrency > 0,
      remainingDebtInBaseCurrency,
      naiveDebtToLiquidate
    );
  }
}
