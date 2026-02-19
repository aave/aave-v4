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
    uint256 totalDebtValueRay = bound(
      params.totalDebtValueRay,
      1,
      MAX_SUPPLY_IN_BASE_CURRENCY * WadRayMath.RAY
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
        totalDebtValueRay: totalDebtValueRay,
        debtAssetUnit: debtAssetUnit,
        debtAssetPrice: debtAssetPrice,
        collateralFactor: collateralFactor,
        liquidationBonus: liquidationBonus,
        healthFactor: healthFactor,
        targetHealthFactor: targetHealthFactor
      });
  }

  function _bound(
    LiquidationLogic.CalculateDebtToLiquidateParams memory params
  ) internal virtual returns (LiquidationLogic.CalculateDebtToLiquidateParams memory) {
    LiquidationLogic.CalculateDebtToTargetHealthFactorParams memory debtToTargetParams = _bound(
      _getDebtToTargetHealthFactorParams(params)
    );

    uint256 debtToCover = bound(params.debtToCover, 0, MAX_SUPPLY_AMOUNT);
    uint256 drawnIndex = bound(params.drawnIndex, MIN_DRAWN_INDEX, MAX_DRAWN_INDEX);
    uint256 drawnShares = bound(
      params.drawnShares,
      1,
      _convertValueToAmount(
        MAX_SUPPLY_AMOUNT,
        debtToTargetParams.debtAssetPrice,
        debtToTargetParams.debtAssetUnit
      )
    );
    uint256 premiumDebtRay = bound(
      params.premiumDebtRay,
      0,
      _convertValueToAmount(
        MAX_SUPPLY_AMOUNT,
        debtToTargetParams.debtAssetPrice,
        debtToTargetParams.debtAssetUnit
      )
    );

    return
      LiquidationLogic.CalculateDebtToLiquidateParams({
        drawnShares: drawnShares,
        premiumDebtRay: premiumDebtRay,
        drawnIndex: drawnIndex,
        totalDebtValueRay: debtToTargetParams.totalDebtValueRay,
        debtAssetDecimals: Math.log10(debtToTargetParams.debtAssetUnit),
        debtAssetUnit: debtToTargetParams.debtAssetUnit,
        debtAssetPrice: debtToTargetParams.debtAssetPrice,
        debtToCover: debtToCover,
        collateralFactor: debtToTargetParams.collateralFactor,
        liquidationBonus: debtToTargetParams.liquidationBonus,
        healthFactor: debtToTargetParams.healthFactor,
        targetHealthFactor: debtToTargetParams.targetHealthFactor
      });
  }

  function _boundWithDustAdjustment(
    LiquidationLogic.CalculateDebtToLiquidateParams memory params
  ) internal virtual returns (LiquidationLogic.CalculateDebtToLiquidateParams memory) {
    params = _bound(params);
    // bound price such that 1 drawn share is worth less than DUST_LIQUIDATION_THRESHOLD
    params.debtAssetPrice = bound(
      params.debtAssetPrice,
      1,
      _convertDecimals(
        LiquidationLogic.DUST_LIQUIDATION_THRESHOLD,
        18,
        params.debtAssetDecimals,
        false
      ).rayDivDown(params.drawnIndex)
    );

    uint256 debtRayToTarget = liquidationLogicWrapper.calculateDebtToTargetHealthFactor(
      _getDebtToTargetHealthFactorParams(params)
    );

    uint256 debtRayToLiquidate = debtRayToTarget.min(
      _max(
        _min(type(uint256).max / WadRayMath.RAY, params.debtToCover.toRay()),
        params.drawnIndex
      ) - params.drawnIndex // debtToCover acts as an upperbound
    );
    uint256 debtRay = vm.randomUint(
      debtRayToLiquidate + 1,
      debtRayToLiquidate +
        _convertValueToAmount(
          LiquidationLogic.DUST_LIQUIDATION_THRESHOLD - 1,
          params.debtAssetPrice,
          params.debtAssetUnit
        ).toRay()
    );

    params.drawnShares = bound(params.drawnShares, 0, debtRay / params.drawnIndex);
    vm.assume(params.drawnShares > 0);
    params.premiumDebtRay = debtRay - params.drawnShares * params.drawnIndex;

    return params;
  }

  function _bound(
    LiquidationLogic.CalculateCollateralToLiquidateParams memory params
  ) internal virtual returns (LiquidationLogic.CalculateCollateralToLiquidateParams memory) {
    params.collateralReserveHub = hub1;
    params.collateralReserveAssetId = bound(
      params.collateralReserveAssetId,
      0,
      IHub(address(params.collateralReserveHub)).getAssetCount() - 1
    );
    params.collateralAssetUnit =
      10 **
      bound(params.collateralAssetUnit, MIN_TOKEN_DECIMALS_SUPPORTED, MAX_TOKEN_DECIMALS_SUPPORTED);
    params.collateralAssetPrice = bound(params.collateralAssetPrice, 1, MAX_ASSET_PRICE);
    params.drawnIndex = bound(params.drawnIndex, MIN_DRAWN_INDEX, MAX_DRAWN_INDEX);
    params.drawnSharesToLiquidate = bound(
      params.drawnSharesToLiquidate,
      0,
      MAX_SUPPLY_AMOUNT / params.drawnIndex
    );
    params.premiumDebtRayToLiquidate = bound(
      params.premiumDebtRayToLiquidate,
      0,
      MAX_SUPPLY_AMOUNT - params.drawnSharesToLiquidate * params.drawnIndex
    );
    params.debtAssetUnit =
      10 ** bound(params.debtAssetUnit, MIN_TOKEN_DECIMALS_SUPPORTED, MAX_TOKEN_DECIMALS_SUPPORTED);
    uint256 debtRayToLiquidate = params.drawnSharesToLiquidate * params.drawnIndex +
      params.premiumDebtRayToLiquidate;
    params.debtAssetPrice = bound(
      params.debtAssetPrice,
      1,
      MAX_SUPPLY_AMOUNT /
        _max(1, _convertAmountToValue(debtRayToLiquidate.fromRayUp(), 1, params.debtAssetUnit))
    );
    params.liquidationBonus = bound(
      params.liquidationBonus,
      MIN_LIQUIDATION_BONUS,
      MAX_LIQUIDATION_BONUS
    );

    uint256 hubAddedShares = vm.randomUint(1, MAX_SUPPLY_AMOUNT);
    uint256 hubAddedAssets = vm.randomUint(
      hubAddedShares,
      MAX_SUPPLY_AMOUNT.min(
        MAX_SUPPLY_PRICE * (hubAddedShares + SharesMath.VIRTUAL_SHARES) - SharesMath.VIRTUAL_ASSETS
      )
    );
    _mockSupplySharePrice(
      IHub(address(params.collateralReserveHub)),
      params.collateralReserveAssetId,
      hubAddedAssets,
      hubAddedShares
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

    params.debtAssetDecimals = bound(
      params.debtAssetDecimals,
      MIN_TOKEN_DECIMALS_SUPPORTED,
      MAX_TOKEN_DECIMALS_SUPPORTED
    );

    LiquidationLogic.CalculateDebtToLiquidateParams
      memory debtToLiquidateParams = _getCalculateDebtToLiquidateParams(params);
    debtToLiquidateParams = _bound(debtToLiquidateParams);

    params.drawnShares = debtToLiquidateParams.drawnShares;
    params.premiumDebtRay = debtToLiquidateParams.premiumDebtRay;
    params.drawnIndex = debtToLiquidateParams.drawnIndex;
    params.totalDebtValueRay = debtToLiquidateParams.totalDebtValueRay;
    params.debtAssetPrice = debtToLiquidateParams.debtAssetPrice;
    params.debtToCover = debtToLiquidateParams.debtToCover;
    params.healthFactor = debtToLiquidateParams.healthFactor;
    params.targetHealthFactor = debtToLiquidateParams.targetHealthFactor;
    params.collateralFactor = debtToLiquidateParams.collateralFactor;

    params.collateralAssetPrice = bound(params.collateralAssetPrice, 1, MAX_ASSET_PRICE);
    params.collateralAssetDecimals = bound(
      params.collateralAssetDecimals,
      MIN_TOKEN_DECIMALS_SUPPORTED,
      MAX_TOKEN_DECIMALS_SUPPORTED
    );
    params.liquidationFee = bound(params.liquidationFee, 0, PercentageMath.PERCENTAGE_FACTOR);

    params.suppliedShares = bound(params.suppliedShares, 0, MAX_SUPPLY_AMOUNT);
    uint256 hubAddedShares = vm.randomUint(params.suppliedShares, MAX_SUPPLY_AMOUNT);
    uint256 hubAddedAssets = vm.randomUint(
      hubAddedShares,
      MAX_SUPPLY_AMOUNT.min(
        MAX_SUPPLY_PRICE * (hubAddedShares + SharesMath.VIRTUAL_SHARES) - SharesMath.VIRTUAL_ASSETS
      )
    );
    params.collateralReserveHub = hub1;
    params.collateralReserveAssetId = bound(
      params.collateralReserveAssetId,
      0,
      IHub(address(params.collateralReserveHub)).getAssetCount() - 1
    );
    _mockSupplySharePrice(
      IHub(address(params.collateralReserveHub)),
      params.collateralReserveAssetId,
      hubAddedAssets,
      hubAddedShares
    );

    return params;
  }

  function _boundWithDebtDustAdjustment(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) internal virtual returns (LiquidationLogic.CalculateLiquidationAmountsParams memory) {
    params = _bound(params);
    LiquidationLogic.CalculateDebtToLiquidateParams
      memory debtToLiquidateParams = _getCalculateDebtToLiquidateParams(params);
    debtToLiquidateParams = _boundWithDustAdjustment(debtToLiquidateParams);

    params.drawnShares = debtToLiquidateParams.drawnShares;
    params.premiumDebtRay = debtToLiquidateParams.premiumDebtRay;
    params.drawnIndex = debtToLiquidateParams.drawnIndex;
    params.totalDebtValueRay = debtToLiquidateParams.totalDebtValueRay;
    params.debtAssetDecimals = debtToLiquidateParams.debtAssetDecimals;
    params.debtAssetPrice = debtToLiquidateParams.debtAssetPrice;
    params.debtToCover = debtToLiquidateParams.debtToCover;
    params.collateralFactor = debtToLiquidateParams.collateralFactor;
    params.healthFactor = debtToLiquidateParams.healthFactor;
    params.targetHealthFactor = debtToLiquidateParams.targetHealthFactor;

    return params;
  }

  function _getDebtToTargetHealthFactorParams(
    LiquidationLogic.CalculateDebtToLiquidateParams memory params
  ) internal pure returns (LiquidationLogic.CalculateDebtToTargetHealthFactorParams memory) {
    return
      LiquidationLogic.CalculateDebtToTargetHealthFactorParams({
        totalDebtValueRay: params.totalDebtValueRay,
        debtAssetUnit: params.debtAssetUnit,
        debtAssetPrice: params.debtAssetPrice,
        collateralFactor: params.collateralFactor,
        liquidationBonus: params.liquidationBonus,
        healthFactor: params.healthFactor,
        targetHealthFactor: params.targetHealthFactor
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
        drawnShares: params.drawnShares,
        premiumDebtRay: params.premiumDebtRay,
        drawnIndex: params.drawnIndex,
        totalDebtValueRay: params.totalDebtValueRay,
        debtAssetDecimals: params.debtAssetDecimals,
        debtAssetUnit: 10 ** params.debtAssetDecimals,
        debtAssetPrice: params.debtAssetPrice,
        debtToCover: params.debtToCover,
        collateralFactor: params.collateralFactor,
        liquidationBonus: liquidationBonus,
        healthFactor: params.healthFactor,
        targetHealthFactor: params.targetHealthFactor
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
