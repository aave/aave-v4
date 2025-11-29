// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
import {LiquidationLogicWrapper} from 'tests/mocks/LiquidationLogicWrapper.sol';

contract LiquidationLogicBaseTest is SpokeBase {
  using PercentageMath for uint256;
  using WadRayMath for uint256;
  using MathUtils for uint256;

  LiquidationLogicWrapper public liquidationLogicWrapper;

  function setUp() public virtual override {
    super.setUp();
    liquidationLogicWrapper = new LiquidationLogicWrapper(
      makeAddr('borrower'),
      makeAddr('liquidator')
    );
  }

  // generic bounds for liquidation logic params
  function _bound(
    uint256 healthFactorForMaxBonus,
    uint256 liquidationBonusFactor,
    uint256 healthFactor,
    uint256 maxLiquidationBonus
  ) internal virtual returns (uint256, uint256, uint256, uint256) {
    healthFactorForMaxBonus = bound(
      healthFactorForMaxBonus,
      0,
      Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1
    );
    liquidationBonusFactor = bound(liquidationBonusFactor, 0, PercentageMath.PERCENTAGE_FACTOR);
    healthFactor = bound(healthFactor, 0, Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1);
    maxLiquidationBonus = bound(maxLiquidationBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS);
    return (healthFactorForMaxBonus, liquidationBonusFactor, healthFactor, maxLiquidationBonus);
  }

  function _bound(
    LiquidationLogic.CalculateDebtToTargetHealthFactorParams memory params
  ) internal virtual returns (LiquidationLogic.CalculateDebtToTargetHealthFactorParams memory) {
    uint256 totalDebtValue = bound(params.totalDebtValue, 1, MAX_SUPPLY_IN_BASE_CURRENCY);

    uint256 liquidationBonus = bound(
      params.liquidationBonus,
      MIN_LIQUIDATION_BONUS,
      MAX_LIQUIDATION_BONUS
    );

    uint256 collateralFactor = bound(
      params.collateralFactor,
      1,
      (PercentageMath.PERCENTAGE_FACTOR - 1).percentDivDown(liquidationBonus)
    );

    uint256 targetHealthFactor = bound(
      params.targetHealthFactor,
      Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      MAX_CLOSE_FACTOR
    );

    uint256 healthFactor = bound(params.healthFactor, 0, targetHealthFactor);
    uint256 debtAssetPrice = bound(params.debtAssetPrice, 1, MAX_ASSET_PRICE);
    uint256 debtAssetUnit = 10 **
      bound(params.debtAssetUnit, MIN_TOKEN_DECIMALS_SUPPORTED, MAX_TOKEN_DECIMALS_SUPPORTED);

    return
      LiquidationLogic.CalculateDebtToTargetHealthFactorParams({
        totalDebtValue: totalDebtValue,
        healthFactor: healthFactor,
        targetHealthFactor: targetHealthFactor,
        liquidationBonus: liquidationBonus,
        collateralFactor: collateralFactor,
        debtAssetPrice: debtAssetPrice,
        debtAssetUnit: debtAssetUnit
      });
  }

  function _bound(
    LiquidationLogic.CalculateDebtToLiquidateParams memory params
  ) internal virtual returns (LiquidationLogic.CalculateDebtToLiquidateParams memory) {
    LiquidationLogic.CalculateDebtToTargetHealthFactorParams memory debtToTargetParams = _bound(
      _getDebtToTargetHealthFactorParams(params)
    );

    uint256 debtToCover = bound(params.debtToCover, 0, MAX_SUPPLY_AMOUNT);
    uint256 debtReserveBalance = bound(
      params.debtReserveBalance,
      0,
      _convertValueToAmount(
        debtToTargetParams.totalDebtValue,
        debtToTargetParams.debtAssetPrice,
        debtToTargetParams.debtAssetUnit
      ).min(MAX_SUPPLY_AMOUNT)
    );

    return
      LiquidationLogic.CalculateDebtToLiquidateParams({
        debtReserveBalance: debtReserveBalance,
        debtToCover: debtToCover,
        totalDebtValue: debtToTargetParams.totalDebtValue,
        healthFactor: debtToTargetParams.healthFactor,
        targetHealthFactor: debtToTargetParams.targetHealthFactor,
        liquidationBonus: debtToTargetParams.liquidationBonus,
        collateralFactor: debtToTargetParams.collateralFactor,
        debtAssetPrice: debtToTargetParams.debtAssetPrice,
        debtAssetUnit: debtToTargetParams.debtAssetUnit
      });
  }

  function _boundWithDustAdjustment(
    LiquidationLogic.CalculateDebtToLiquidateParams memory params
  ) internal virtual returns (LiquidationLogic.CalculateDebtToLiquidateParams memory) {
    params = _bound(params);
    uint256 debtToTarget = liquidationLogicWrapper.calculateDebtToTargetHealthFactor(
      _getDebtToTargetHealthFactorParams(params)
    );
    params.debtReserveBalance = bound(
      params.debtReserveBalance,
      debtToTarget.min(params.debtToCover) + 1,
      debtToTarget.min(params.debtToCover) +
        _convertValueToAmount(
          LiquidationLogic.DUST_LIQUIDATION_THRESHOLD - 1,
          params.debtAssetPrice,
          params.debtAssetUnit
        )
    );
    return params;
  }

  function _bound(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) internal virtual returns (LiquidationLogic.CalculateLiquidationAmountsParams memory) {
    (
      params.healthFactorForMaxBonus,
      params.liquidationBonusFactor,
      params.healthFactor,
      params.maxLiquidationBonus
    ) = _bound(
      params.healthFactorForMaxBonus,
      params.liquidationBonusFactor,
      params.healthFactor,
      params.maxLiquidationBonus
    );

    params.debtAssetUnit = bound(
      params.debtAssetUnit,
      10 ** MIN_TOKEN_DECIMALS_SUPPORTED,
      10 ** MAX_TOKEN_DECIMALS_SUPPORTED
    );

    LiquidationLogic.CalculateDebtToLiquidateParams
      memory debtToLiquidateParams = _getCalculateDebtToLiquidateParams(params);
    debtToLiquidateParams = _bound(debtToLiquidateParams);

    params.debtReserveBalance = debtToLiquidateParams.debtReserveBalance;
    params.debtToCover = debtToLiquidateParams.debtToCover;
    params.totalDebtValue = debtToLiquidateParams.totalDebtValue;
    params.healthFactor = debtToLiquidateParams.healthFactor;
    params.targetHealthFactor = debtToLiquidateParams.targetHealthFactor;
    params.collateralFactor = debtToLiquidateParams.collateralFactor;
    params.debtAssetPrice = debtToLiquidateParams.debtAssetPrice;

    params.collateralAssetPrice = bound(params.collateralAssetPrice, 1, MAX_ASSET_PRICE);
    params.collateralAssetUnit = bound(
      params.collateralAssetUnit,
      10 ** MIN_TOKEN_DECIMALS_SUPPORTED,
      10 ** MAX_TOKEN_DECIMALS_SUPPORTED
    );
    params.liquidationFee = bound(params.liquidationFee, 0, PercentageMath.PERCENTAGE_FACTOR);
    params.collateralReserveBalance = bound(params.collateralReserveBalance, 0, MAX_SUPPLY_AMOUNT);

    return params;
  }

  function _boundWithDebtDustAdjustment(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) internal virtual returns (LiquidationLogic.CalculateLiquidationAmountsParams memory) {
    params = _bound(params);
    LiquidationLogic.CalculateDebtToLiquidateParams
      memory debtToLiquidateParams = _getCalculateDebtToLiquidateParams(params);
    debtToLiquidateParams = _boundWithDustAdjustment(debtToLiquidateParams);

    params.debtReserveBalance = debtToLiquidateParams.debtReserveBalance;
    params.debtToCover = debtToLiquidateParams.debtToCover;
    params.totalDebtValue = debtToLiquidateParams.totalDebtValue;
    params.healthFactor = debtToLiquidateParams.healthFactor;
    params.targetHealthFactor = debtToLiquidateParams.targetHealthFactor;
    params.collateralFactor = debtToLiquidateParams.collateralFactor;
    params.debtAssetPrice = debtToLiquidateParams.debtAssetPrice;
    params.debtAssetUnit = debtToLiquidateParams.debtAssetUnit;

    return params;
  }

  function _getDebtToTargetHealthFactorParams(
    LiquidationLogic.CalculateDebtToLiquidateParams memory params
  ) internal pure returns (LiquidationLogic.CalculateDebtToTargetHealthFactorParams memory) {
    return
      LiquidationLogic.CalculateDebtToTargetHealthFactorParams({
        totalDebtValue: params.totalDebtValue,
        healthFactor: params.healthFactor,
        targetHealthFactor: params.targetHealthFactor,
        liquidationBonus: params.liquidationBonus,
        collateralFactor: params.collateralFactor,
        debtAssetPrice: params.debtAssetPrice,
        debtAssetUnit: params.debtAssetUnit
      });
  }

  function _getCalculateDebtToLiquidateParams(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) internal pure returns (LiquidationLogic.CalculateDebtToLiquidateParams memory) {
    uint256 liquidationBonus = LiquidationLogic.calculateLiquidationBonus({
      healthFactorForMaxBonus: params.healthFactorForMaxBonus,
      liquidationBonusFactor: params.liquidationBonusFactor,
      healthFactor: params.healthFactor,
      maxLiquidationBonus: params.maxLiquidationBonus
    });
    return
      LiquidationLogic.CalculateDebtToLiquidateParams({
        debtReserveBalance: params.debtReserveBalance,
        debtToCover: params.debtToCover,
        totalDebtValue: params.totalDebtValue,
        healthFactor: params.healthFactor,
        targetHealthFactor: params.targetHealthFactor,
        liquidationBonus: liquidationBonus,
        collateralFactor: params.collateralFactor,
        debtAssetPrice: params.debtAssetPrice,
        debtAssetUnit: params.debtAssetUnit
      });
  }

  /// naive log 10 exponent
  function _getExponent(uint256 value) internal pure returns (uint256) {
    uint256 exp = 0;
    while (value > 1) {
      value /= 10;
      exp++;
    }
    return exp;
  }
}
