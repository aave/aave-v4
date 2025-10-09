// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicLiquidationAmountsTest is LiquidationLogicBaseTest {
  using MathUtils for uint256;
  using PercentageMath for uint256;

  function test_calculateLiquidationAmounts_fuzz_EnoughCollateral(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) public {
    params = _bound(params);
    (
      uint256 expectedCollateralToLiquidate,
      uint256 expectedDebtToLiquidate
    ) = _calculateRawLiquidationAmounts(params);

    params.collateralReserveBalance = bound(
      params.collateralReserveBalance,
      expectedCollateralToLiquidate,
      MAX_SUPPLY_AMOUNT
    );
    (, uint256 expectedCollateralToLiquidator, ) = _calculateLiquidationAmounts(params);

    (
      uint256 collateralToLiquidate,
      uint256 collateralToLiquidator,
      uint256 debtToLiquidate
    ) = liquidationLogicWrapper.calculateLiquidationAmounts(params);

    assertEq(collateralToLiquidate, expectedCollateralToLiquidate, 'collateralToLiquidate');
    assertEq(collateralToLiquidator, expectedCollateralToLiquidator, 'collateralToLiquidator');
    assertEq(debtToLiquidate, expectedDebtToLiquidate, 'debtToLiquidate');
  }

  function test_calculateLiquidationAmounts_EnoughCollateral() public {
    // variable liquidation bonus is max: 120%
    // liquidation penalty: 1.2 * 0.5 = 0.6
    // debtToTarget = $10000 * (1 - 0.8) / (1 - 0.6) / $2000 = 2.5
    // max debt to liquidate = min(2.5, 5, 3) = 2.5
    // collateral to liquidate = 2.5 * 120% * $2000 / $1 = 6000
    // bonus collateral = 6000 - 6000 / 120% = 1000
    // collateral fee = 1000 * 10% = 100
    // collateral to liquidator = 6000 - 100 = 5900
    (
      uint256 collateralToLiquidate,
      uint256 collateralToLiquidator,
      uint256 debtToLiquidate
    ) = liquidationLogicWrapper.calculateLiquidationAmounts(
        LiquidationLogic.CalculateLiquidationAmountsParams({
          healthFactorForMaxBonus: 0.8e18,
          liquidationBonusFactor: 50_00,
          collateralReserveBalance: 11_000e6,
          debtReserveBalance: 5e18,
          debtToCover: 3e18,
          totalDebtValue: 10_000e26,
          healthFactor: 0.8e18,
          targetHealthFactor: 1e18,
          maxLiquidationBonus: 120_00,
          collateralFactor: 50_00,
          debtAssetPrice: 2000e8,
          debtAssetUnit: 1e18,
          collateralAssetPrice: 1e8,
          collateralAssetUnit: 1e6,
          liquidationFee: 10_00
        })
      );

    assertEq(collateralToLiquidate, 6000e6, 'collateralToLiquidate');
    assertEq(collateralToLiquidator, 5900e6, 'collateralToLiquidator');
    assertEq(debtToLiquidate, 2.5e18, 'debtToLiquidate');
  }

  function test_calculateLiquidationAmounts_fuzz_InsufficientCollateral(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) public {
    params = _bound(params);
    (
      uint256 rawCollateralToLiquidate,
      uint256 rawDebtToLiquidate
    ) = _calculateRawLiquidationAmounts(params);
    vm.assume(rawCollateralToLiquidate > 0);
    params.collateralReserveBalance = bound(
      params.collateralReserveBalance,
      0,
      rawCollateralToLiquidate - 1
    );

    (
      uint256 expectedCollateralToLiquidate,
      uint256 expectedCollateralToLiquidator,
      uint256 expectedDebtToLiquidate
    ) = _calculateLiquidationAmounts(params);
    assertTrue(
      expectedCollateralToLiquidate != rawCollateralToLiquidate,
      'adjusted collateralToLiquidate'
    );

    (
      uint256 collateralToLiquidate,
      uint256 collateralToLiquidator,
      uint256 debtToLiquidate
    ) = liquidationLogicWrapper.calculateLiquidationAmounts(params);

    assertEq(collateralToLiquidate, expectedCollateralToLiquidate, 'collateralToLiquidate');
    assertEq(collateralToLiquidator, expectedCollateralToLiquidator, 'collateralToLiquidator');
    assertEq(debtToLiquidate, expectedDebtToLiquidate, 'debtToLiquidate');
  }

  function test_calculateLiquidationAmounts_InsufficientCollateral() public {
    // variable liquidation bonus is max: 120%
    // liquidation penalty: 1.2 * 0.5 = 0.6
    // debtToTarget = $10000 * (1 - 0.8) / (1 - 0.6) / $2000 = 2.5
    // max debt to liquidate = min(2.5, 5, 3) = 2.5
    // collateral to liquidate = 2.5 * 120% * $2000 / $1 = 6000
    // total reserve collateral = 3000
    // adjusted debt to liquidate = 3000 / 120% * $1 / $2000 = 1.25
    // bonus collateral = 3000 - 3000 / 120% = 500
    // collateral fee = 500 * 10% = 50
    // collateral to liquidator = 3000 - 50 = 2950
    (
      uint256 collateralToLiquidate,
      uint256 collateralToLiquidator,
      uint256 debtToLiquidate
    ) = liquidationLogicWrapper.calculateLiquidationAmounts(
        LiquidationLogic.CalculateLiquidationAmountsParams({
          healthFactorForMaxBonus: 0.8e18,
          liquidationBonusFactor: 50_00,
          collateralReserveBalance: 3000e6,
          debtReserveBalance: 5e18,
          debtToCover: 3e18,
          totalDebtValue: 10_000e26,
          healthFactor: 0.8e18,
          targetHealthFactor: 1e18,
          maxLiquidationBonus: 120_00,
          collateralFactor: 50_00,
          debtAssetPrice: 2000e8,
          debtAssetUnit: 1e18,
          collateralAssetPrice: 1e8,
          collateralAssetUnit: 1e6,
          liquidationFee: 10_00
        })
      );

    assertEq(collateralToLiquidate, 3000e6, 'collateralToLiquidate');
    assertEq(collateralToLiquidator, 2950e6, 'collateralToLiquidator');
    assertEq(debtToLiquidate, 1.25e18, 'debtToLiquidate');
  }

  function _calculateRawLiquidationAmounts(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) internal returns (uint256, uint256) {
    uint256 debtToLiquidate = liquidationLogicWrapper.calculateMaxDebtToLiquidate(
      _getCalculateMaxDebtToLiquidateParams(params)
    );
    uint256 debtToCollateral = debtToLiquidate.mulDivDown(
      params.debtAssetPrice * params.collateralAssetUnit,
      params.debtAssetUnit * params.collateralAssetPrice
    );
    uint256 liquidationBonus = liquidationLogicWrapper.calculateLiquidationBonus({
      healthFactorForMaxBonus: params.healthFactorForMaxBonus,
      liquidationBonusFactor: params.liquidationBonusFactor,
      healthFactor: params.healthFactor,
      maxLiquidationBonus: params.maxLiquidationBonus
    });
    uint256 collateralToLiquidate = debtToLiquidate.mulDivDown(
      params.debtAssetPrice * params.collateralAssetUnit * liquidationBonus,
      params.debtAssetUnit * params.collateralAssetPrice * PercentageMath.PERCENTAGE_FACTOR
    );

    return (collateralToLiquidate, debtToLiquidate);
  }

  function _calculateLiquidationAmounts(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) internal returns (uint256, uint256, uint256) {
    (uint256 collateralToLiquidate, uint256 debtToLiquidate) = _calculateRawLiquidationAmounts(
      params
    );
    uint256 bonusCollateral = collateralToLiquidate -
      debtToLiquidate.mulDivDown(
        params.debtAssetPrice * params.collateralAssetUnit,
        params.debtAssetUnit * params.collateralAssetPrice
      );

    if (collateralToLiquidate > params.collateralReserveBalance) {
      uint256 liquidationBonus = liquidationLogicWrapper.calculateLiquidationBonus({
        healthFactorForMaxBonus: params.healthFactorForMaxBonus,
        liquidationBonusFactor: params.liquidationBonusFactor,
        healthFactor: params.healthFactor,
        maxLiquidationBonus: params.maxLiquidationBonus
      });

      collateralToLiquidate = params.collateralReserveBalance;
      bonusCollateral =
        collateralToLiquidate -
        collateralToLiquidate.percentDivUp(liquidationBonus);
      debtToLiquidate = collateralToLiquidate.mulDivUp(
        params.collateralAssetPrice * params.debtAssetUnit * PercentageMath.PERCENTAGE_FACTOR,
        params.debtAssetPrice * params.collateralAssetUnit * liquidationBonus
      );
    }

    uint256 collateralToLiquidator = collateralToLiquidate -
      bonusCollateral.percentMulDown(params.liquidationFee);

    return (collateralToLiquidate, collateralToLiquidator, debtToLiquidate);
  }
}
