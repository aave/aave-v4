// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
import {LiquidationLogicWrapper} from 'tests/mocks/LiquidationLogicWrapper.sol';

contract LiquidationLogicBaseTest is SpokeBase {
  using PercentageMath for uint256;
  using WadRayMath for uint256;

  LiquidationLogicWrapper public liquidationLogicWrapper;

  function setUp() public virtual override {
    super.setUp();
    liquidationLogicWrapper = new LiquidationLogicWrapper();
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
    uint256 debtAssetUnit = 10 ** bound(params.debtAssetUnit, 0, MAX_TOKEN_DECIMALS_SUPPORTED);

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

  function _getDebtToTargetHealthFactorParams(
    LiquidationLogic.CalculateMaxDebtToLiquidateParams memory params
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

  function _bound(
    LiquidationLogic.CalculateMaxDebtToLiquidateParams memory params
  ) internal virtual returns (LiquidationLogic.CalculateMaxDebtToLiquidateParams memory) {
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
      )
    );

    return
      LiquidationLogic.CalculateMaxDebtToLiquidateParams({
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

  function _boundNoDustRevert(
    LiquidationLogic.CalculateMaxDebtToLiquidateParams memory params
  ) internal virtual returns (LiquidationLogic.CalculateMaxDebtToLiquidateParams memory) {
    params = _bound(params);
    try liquidationLogicWrapper.calculateMaxDebtToLiquidate(params) returns (uint256) {
      return params;
    } catch {
      params.debtToCover = bound(params.debtToCover, params.debtReserveBalance, MAX_SUPPLY_AMOUNT);
      return params;
    }
  }

  function _getCalculateMaxDebtToLiquidateParams(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) internal pure returns (LiquidationLogic.CalculateMaxDebtToLiquidateParams memory) {
    uint256 liquidationBonus = LiquidationLogic.calculateLiquidationBonus({
      healthFactorForMaxBonus: params.healthFactorForMaxBonus,
      liquidationBonusFactor: params.liquidationBonusFactor,
      healthFactor: params.healthFactor,
      maxLiquidationBonus: params.maxLiquidationBonus
    });
    return
      LiquidationLogic.CalculateMaxDebtToLiquidateParams({
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

    LiquidationLogic.CalculateMaxDebtToLiquidateParams
      memory maxDebtToLiquidateParams = _getCalculateMaxDebtToLiquidateParams(params);
    maxDebtToLiquidateParams = _boundNoDustRevert(maxDebtToLiquidateParams);

    params.debtReserveBalance = maxDebtToLiquidateParams.debtReserveBalance;
    params.debtToCover = maxDebtToLiquidateParams.debtToCover;
    params.totalDebtValue = maxDebtToLiquidateParams.totalDebtValue;
    params.healthFactor = maxDebtToLiquidateParams.healthFactor;
    params.targetHealthFactor = maxDebtToLiquidateParams.targetHealthFactor;
    params.collateralFactor = maxDebtToLiquidateParams.collateralFactor;
    params.debtAssetPrice = maxDebtToLiquidateParams.debtAssetPrice;
    params.debtAssetUnit = maxDebtToLiquidateParams.debtAssetUnit;

    params.collateralAssetPrice = bound(params.collateralAssetPrice, 1, MAX_ASSET_PRICE);
    params.collateralAssetUnit = bound(params.collateralAssetUnit, 0, MAX_TOKEN_DECIMALS_SUPPORTED);
    params.liquidationFee = bound(params.liquidationFee, 0, PercentageMath.PERCENTAGE_FACTOR);
    params.collateralReserveBalance = bound(params.collateralReserveBalance, 0, MAX_SUPPLY_AMOUNT);

    return params;
  }
}
