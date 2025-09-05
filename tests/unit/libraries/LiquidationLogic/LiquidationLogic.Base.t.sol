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

  function setUp() public virtual override {
    super.setUp();
    liquidationLogicWrapper = new LiquidationLogicWrapper();
  }

  // generic bounds for liquidation logic params
  function _bound(
    DataTypes.CalculateLiquidationBonusParams memory params
  ) internal virtual returns (DataTypes.CalculateLiquidationBonusParams memory) {
    params.healthFactorForMaxBonus = bound(
      params.healthFactorForMaxBonus,
      0,
      Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1
    );
    params.liquidationBonusFactor = bound(
      params.liquidationBonusFactor,
      0,
      PercentageMath.PERCENTAGE_FACTOR
    );
    params.healthFactor = bound(
      params.healthFactor,
      0,
      Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1
    );
    params.maxLiquidationBonus = bound(
      params.maxLiquidationBonus,
      MIN_LIQUIDATION_BONUS,
      MAX_LIQUIDATION_BONUS
    );
    return params;
  }

  function _bound(
    LiquidationLogic.CalculateDebtToRestoreCloseFactorParams memory params
  ) internal virtual returns (LiquidationLogic.CalculateDebtToRestoreCloseFactorParams memory) {
    uint256 totalDebtInBaseCurrency = bound(
      params.totalDebtInBaseCurrency,
      1,
      MAX_SUPPLY_IN_BASE_CURRENCY
    );

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

    uint256 closeFactor = bound(
      params.closeFactor,
      Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      MAX_CLOSE_FACTOR
    );

    uint256 healthFactor = bound(params.healthFactor, 0, closeFactor);
    uint256 debtAssetPrice = bound(params.debtAssetPrice, 1, MAX_ASSET_PRICE);
    uint256 debtAssetUnit = 10 ** bound(params.debtAssetUnit, 0, MAX_TOKEN_DECIMALS_SUPPORTED);

    return
      LiquidationLogic.CalculateDebtToRestoreCloseFactorParams({
        totalDebtInBaseCurrency: totalDebtInBaseCurrency,
        healthFactor: healthFactor,
        closeFactor: closeFactor,
        liquidationBonus: liquidationBonus,
        collateralFactor: collateralFactor,
        debtAssetPrice: debtAssetPrice,
        debtAssetUnit: debtAssetUnit
      });
  }

  function _getDebtToRestoreCloseFactorParams(
    LiquidationLogic.CalculateMaxDebtToLiquidateParams memory params
  ) internal returns (LiquidationLogic.CalculateDebtToRestoreCloseFactorParams memory) {
    return
      LiquidationLogic.CalculateDebtToRestoreCloseFactorParams({
        totalDebtInBaseCurrency: params.totalDebtInBaseCurrency,
        healthFactor: params.healthFactor,
        closeFactor: params.closeFactor,
        liquidationBonus: params.liquidationBonus,
        collateralFactor: params.collateralFactor,
        debtAssetPrice: params.debtAssetPrice,
        debtAssetUnit: params.debtAssetUnit
      });
  }

  function _bound(
    LiquidationLogic.CalculateMaxDebtToLiquidateParams memory params
  ) internal virtual returns (LiquidationLogic.CalculateMaxDebtToLiquidateParams memory) {
    LiquidationLogic.CalculateDebtToRestoreCloseFactorParams
      memory debtToRestoreCloseFactorParams = _bound(_getDebtToRestoreCloseFactorParams(params));

    uint256 debtToCover = bound(params.debtToCover, 0, MAX_SUPPLY_AMOUNT);
    uint256 reserveDebt = bound(
      params.reserveDebt,
      0,
      _convertBaseCurrencyToAmount(
        debtToRestoreCloseFactorParams.totalDebtInBaseCurrency,
        debtToRestoreCloseFactorParams.debtAssetPrice,
        debtToRestoreCloseFactorParams.debtAssetUnit
      )
    );

    return
      LiquidationLogic.CalculateMaxDebtToLiquidateParams({
        reserveDebt: reserveDebt,
        debtToCover: debtToCover,
        totalDebtInBaseCurrency: debtToRestoreCloseFactorParams.totalDebtInBaseCurrency,
        healthFactor: debtToRestoreCloseFactorParams.healthFactor,
        closeFactor: debtToRestoreCloseFactorParams.closeFactor,
        liquidationBonus: debtToRestoreCloseFactorParams.liquidationBonus,
        collateralFactor: debtToRestoreCloseFactorParams.collateralFactor,
        debtAssetPrice: debtToRestoreCloseFactorParams.debtAssetPrice,
        debtAssetUnit: debtToRestoreCloseFactorParams.debtAssetUnit
      });
  }

  function _boundNoDustRevert(
    LiquidationLogic.CalculateMaxDebtToLiquidateParams memory params
  ) internal virtual returns (LiquidationLogic.CalculateMaxDebtToLiquidateParams memory) {
    params = _bound(params);
    try liquidationLogicWrapper.calculateMaxDebtToLiquidate(params) returns (uint256) {
      return params;
    } catch {
      params.debtToCover = bound(params.debtToCover, params.reserveDebt, MAX_SUPPLY_AMOUNT);
      return params;
    }
  }

  function _getCalculateLiquidationBonusParams(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) internal returns (DataTypes.CalculateLiquidationBonusParams memory) {
    return
      DataTypes.CalculateLiquidationBonusParams({
        healthFactorForMaxBonus: params.healthFactorForMaxBonus,
        liquidationBonusFactor: params.liquidationBonusFactor,
        healthFactor: params.healthFactor,
        maxLiquidationBonus: params.maxLiquidationBonus
      });
  }

  function _getCalculateMaxDebtToLiquidateParams(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) internal returns (LiquidationLogic.CalculateMaxDebtToLiquidateParams memory) {
    uint256 liquidationBonus = LiquidationLogic.calculateLiquidationBonus(
      _getCalculateLiquidationBonusParams(params)
    );
    return
      LiquidationLogic.CalculateMaxDebtToLiquidateParams({
        reserveDebt: params.reserveDebt,
        debtToCover: params.debtToCover,
        totalDebtInBaseCurrency: params.totalDebtInBaseCurrency,
        healthFactor: params.healthFactor,
        closeFactor: params.closeFactor,
        liquidationBonus: liquidationBonus,
        collateralFactor: params.collateralFactor,
        debtAssetPrice: params.debtAssetPrice,
        debtAssetUnit: params.debtAssetUnit
      });
  }

  function _bound(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) internal virtual returns (LiquidationLogic.CalculateLiquidationAmountsParams memory) {
    DataTypes.CalculateLiquidationBonusParams
      memory liquidationBonusParams = _getCalculateLiquidationBonusParams(params);
    liquidationBonusParams = _bound(liquidationBonusParams);
    params.healthFactorForMaxBonus = liquidationBonusParams.healthFactorForMaxBonus;
    params.liquidationBonusFactor = liquidationBonusParams.liquidationBonusFactor;
    params.healthFactor = bound(
      params.healthFactor,
      0,
      liquidationBonusParams.healthFactorForMaxBonus
    );
    params.maxLiquidationBonus = liquidationBonusParams.maxLiquidationBonus;

    LiquidationLogic.CalculateMaxDebtToLiquidateParams
      memory maxDebtToLiquidateParams = _getCalculateMaxDebtToLiquidateParams(params);
    maxDebtToLiquidateParams = _boundNoDustRevert(maxDebtToLiquidateParams);

    params.reserveDebt = maxDebtToLiquidateParams.reserveDebt;
    params.debtToCover = maxDebtToLiquidateParams.debtToCover;
    params.totalDebtInBaseCurrency = maxDebtToLiquidateParams.totalDebtInBaseCurrency;
    params.healthFactor = maxDebtToLiquidateParams.healthFactor;
    params.closeFactor = maxDebtToLiquidateParams.closeFactor;
    params.collateralFactor = maxDebtToLiquidateParams.collateralFactor;
    params.debtAssetPrice = maxDebtToLiquidateParams.debtAssetPrice;
    params.debtAssetUnit = maxDebtToLiquidateParams.debtAssetUnit;

    params.collateralAssetPrice = bound(params.collateralAssetPrice, 1, MAX_ASSET_PRICE);
    params.collateralAssetUnit = bound(params.collateralAssetUnit, 0, MAX_TOKEN_DECIMALS_SUPPORTED);
    params.liquidationFee = bound(params.liquidationFee, 0, PercentageMath.PERCENTAGE_FACTOR);
    params.reserveCollateral = bound(params.reserveCollateral, 0, MAX_SUPPLY_AMOUNT);

    return params;
  }
}
