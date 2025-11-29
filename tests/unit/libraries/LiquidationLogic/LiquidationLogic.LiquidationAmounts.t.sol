// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicLiquidationAmountsTest is LiquidationLogicBaseTest {
  using MathUtils for uint256;
  using PercentageMath for uint256;

  function test_calculateLiquidationAmounts_fuzz_EnoughCollateral_NoCollateralDust(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) public {
    params = _bound(params);
    LiquidationLogic.LiquidationAmounts
      memory expectedLiquidationAmounts = _calculateRawLiquidationAmounts(params);

    params.collateralReserveBalance = bound(
      params.collateralReserveBalance,
      expectedLiquidationAmounts.collateralToLiquidate +
        _convertValueToAmount(
          LiquidationLogic.DUST_LIQUIDATION_THRESHOLD,
          params.collateralAssetPrice,
          params.collateralAssetUnit
        ) +
        1,
      expectedLiquidationAmounts.collateralToLiquidate +
        _convertValueToAmount(
          LiquidationLogic.DUST_LIQUIDATION_THRESHOLD,
          params.collateralAssetPrice,
          params.collateralAssetUnit
        ) +
        MAX_SUPPLY_AMOUNT
    );

    params.debtToCover = bound(
      params.debtToCover,
      expectedLiquidationAmounts.debtToLiquidate,
      MAX_SUPPLY_AMOUNT
    );

    LiquidationLogic.LiquidationAmounts memory liquidationAmounts = liquidationLogicWrapper
      .calculateLiquidationAmounts(params);

    assertEq(
      liquidationAmounts.collateralToLiquidate,
      expectedLiquidationAmounts.collateralToLiquidate,
      'collateralToLiquidate'
    );
    assertApproxEqAbs(
      liquidationAmounts.collateralToLiquidator,
      expectedLiquidationAmounts.collateralToLiquidator,
      1,
      'collateralToLiquidator'
    );
    assertEq(
      liquidationAmounts.debtToLiquidate,
      expectedLiquidationAmounts.debtToLiquidate,
      'debtToLiquidate'
    );
  }

  function test_calculateLiquidationAmounts_fuzz_EnoughCollateral_NoDebtLeft(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) public {
    params = _boundWithDebtDustAdjustment(params);

    LiquidationLogic.LiquidationAmounts
      memory expectedLiquidationAmounts = _calculateRawLiquidationAmounts(params);

    params.collateralReserveBalance = bound(
      params.collateralReserveBalance,
      expectedLiquidationAmounts.collateralToLiquidate,
      expectedLiquidationAmounts.collateralToLiquidate + MAX_SUPPLY_AMOUNT
    );

    params.debtToCover = bound(params.debtToCover, params.debtReserveBalance, UINT256_MAX);

    LiquidationLogic.LiquidationAmounts memory liquidationAmounts = liquidationLogicWrapper
      .calculateLiquidationAmounts(params);

    assertEq(
      liquidationAmounts.collateralToLiquidate,
      expectedLiquidationAmounts.collateralToLiquidate,
      'collateralToLiquidate'
    );
    assertApproxEqAbs(
      liquidationAmounts.collateralToLiquidator,
      expectedLiquidationAmounts.collateralToLiquidator,
      1,
      'collateralToLiquidator'
    );
    assertEq(liquidationAmounts.debtToLiquidate, params.debtReserveBalance, 'debtToLiquidate');
  }

  function test_calculateLiquidationAmounts_fuzz_EnoughCollateral_CollateralDust(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) public {
    params = _bound(params);
    params.debtToCover = bound(params.debtToCover, params.debtReserveBalance, UINT256_MAX);
    LiquidationLogic.LiquidationAmounts
      memory expectedLiquidationAmounts = _calculateRawLiquidationAmounts(params);

    params.collateralReserveBalance = bound(
      params.collateralReserveBalance,
      expectedLiquidationAmounts.collateralToLiquidate + 1,
      expectedLiquidationAmounts.collateralToLiquidate +
        _convertValueToAmount(
          LiquidationLogic.DUST_LIQUIDATION_THRESHOLD - 1,
          params.collateralAssetPrice,
          params.collateralAssetUnit
        )
    );

    if (expectedLiquidationAmounts.debtToLiquidate < params.debtReserveBalance) {
      expectedLiquidationAmounts = _calculateAdjustedLiquidationAmounts(params);
    }

    params.debtToCover = bound(
      params.debtToCover,
      expectedLiquidationAmounts.debtToLiquidate,
      MAX_SUPPLY_AMOUNT
    );

    LiquidationLogic.LiquidationAmounts memory liquidationAmounts = liquidationLogicWrapper
      .calculateLiquidationAmounts(params);

    assertEq(
      liquidationAmounts.collateralToLiquidate,
      expectedLiquidationAmounts.collateralToLiquidate,
      'collateralToLiquidate'
    );
    assertApproxEqAbs(
      liquidationAmounts.collateralToLiquidator,
      expectedLiquidationAmounts.collateralToLiquidator,
      1,
      'collateralToLiquidator'
    );
    assertEq(
      liquidationAmounts.debtToLiquidate,
      expectedLiquidationAmounts.debtToLiquidate,
      'debtToLiquidate'
    );
  }

  function test_calculateLiquidationAmounts_fuzz_InsufficientCollateral(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) public {
    params = _bound(params);
    LiquidationLogic.LiquidationAmounts
      memory rawLiquidationAmounts = _calculateRawLiquidationAmounts(params);
    vm.assume(rawLiquidationAmounts.collateralToLiquidate > 0);
    params.collateralReserveBalance = bound(
      params.collateralReserveBalance,
      0,
      rawLiquidationAmounts.collateralToLiquidate - 1
    );

    LiquidationLogic.LiquidationAmounts
      memory expectedLiquidationAmounts = _calculateAdjustedLiquidationAmounts(params);

    params.debtToCover = bound(
      params.debtToCover,
      expectedLiquidationAmounts.debtToLiquidate,
      MAX_SUPPLY_AMOUNT
    );

    LiquidationLogic.LiquidationAmounts memory liquidationAmounts = liquidationLogicWrapper
      .calculateLiquidationAmounts(params);

    assertEq(
      liquidationAmounts.collateralToLiquidate,
      expectedLiquidationAmounts.collateralToLiquidate,
      'collateralToLiquidate'
    );
    assertApproxEqAbs(
      liquidationAmounts.collateralToLiquidator,
      expectedLiquidationAmounts.collateralToLiquidator,
      1,
      'collateralToLiquidator'
    );
    assertEq(
      liquidationAmounts.debtToLiquidate,
      expectedLiquidationAmounts.debtToLiquidate,
      'debtToLiquidate'
    );
  }

  function test_calculateLiquidationAmounts_fuzz_revertsWith_MustNotLeaveDust_Debt(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) public {
    params = _boundWithDebtDustAdjustment(params);
    if (params.debtToCover >= params.debtReserveBalance) {
      params.debtToCover = params.debtReserveBalance - 1;
    }
    LiquidationLogic.LiquidationAmounts
      memory rawLiquidationAmounts = _calculateRawLiquidationAmounts(params);
    params.collateralReserveBalance = rawLiquidationAmounts.collateralToLiquidate;

    vm.expectRevert(ISpoke.MustNotLeaveDust.selector);
    liquidationLogicWrapper.calculateLiquidationAmounts(params);
  }

  function test_calculateLiquidationAmounts_fuzz_revertsWith_MustNotLeaveDust_Collateral(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) public {
    params = _bound(params);
    params.debtToCover = bound(params.debtToCover, params.debtReserveBalance, UINT256_MAX);

    LiquidationLogic.LiquidationAmounts
      memory expectedLiquidationAmounts = _calculateRawLiquidationAmounts(params);

    params.collateralReserveBalance = bound(
      params.collateralReserveBalance,
      expectedLiquidationAmounts.collateralToLiquidate + 1,
      expectedLiquidationAmounts.collateralToLiquidate +
        _convertValueToAmount(
          LiquidationLogic.DUST_LIQUIDATION_THRESHOLD - 1,
          params.collateralAssetPrice,
          params.collateralAssetUnit
        )
    );

    if (expectedLiquidationAmounts.debtToLiquidate < params.debtReserveBalance) {
      expectedLiquidationAmounts = _calculateAdjustedLiquidationAmounts(params);
    }

    vm.assume(expectedLiquidationAmounts.debtToLiquidate > 0);
    params.debtToCover = expectedLiquidationAmounts.debtToLiquidate - 1;

    vm.expectRevert(ISpoke.MustNotLeaveDust.selector);
    liquidationLogicWrapper.calculateLiquidationAmounts(params);
  }

  function test_calculateLiquidationAmounts_EnoughCollateral() public view {
    // variable liquidation bonus is max: 120%
    // liquidation penalty: 1.2 * 0.5 = 0.6
    // debtToTarget = $10000 * (1 - 0.8) / (1 - 0.6) / $2000 = 2.5
    // max debt to liquidate = min(2.5, 5, 3) = 2.5
    // collateral to liquidate = 2.5 * 120% * $2000 / $1 = 6000
    // bonus collateral = 6000 - 6000 / 120% = 1000
    // collateral fee = 1000 * 10% = 100
    // collateral to liquidator = 6000 - 100 = 5900
    LiquidationLogic.LiquidationAmounts memory liquidationAmounts = liquidationLogicWrapper
      .calculateLiquidationAmounts(
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
          debtAssetUnit: 10 ** 18,
          collateralAssetPrice: 1e8,
          collateralAssetUnit: 10 ** 6,
          liquidationFee: 10_00
        })
      );

    assertEq(liquidationAmounts.collateralToLiquidate, 6000e6, 'collateralToLiquidate');
    assertEq(liquidationAmounts.collateralToLiquidator, 5900e6, 'collateralToLiquidator');
    assertEq(liquidationAmounts.debtToLiquidate, 2.5e18, 'debtToLiquidate');
  }

  function test_calculateLiquidationAmounts_InsufficientCollateral() public view {
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
    LiquidationLogic.LiquidationAmounts memory liquidationAmounts = liquidationLogicWrapper
      .calculateLiquidationAmounts(
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
          debtAssetUnit: 10 ** 18,
          collateralAssetPrice: 1e8,
          collateralAssetUnit: 10 ** 6,
          liquidationFee: 10_00
        })
      );

    assertEq(liquidationAmounts.collateralToLiquidate, 3000e6, 'collateralToLiquidate');
    assertEq(liquidationAmounts.collateralToLiquidator, 2950e6, 'collateralToLiquidator');
    assertEq(liquidationAmounts.debtToLiquidate, 1.25e18, 'debtToLiquidate');
  }

  function _calculateRawLiquidationAmounts(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) internal view returns (LiquidationLogic.LiquidationAmounts memory) {
    uint256 liquidationBonus = liquidationLogicWrapper.calculateLiquidationBonus({
      healthFactorForMaxBonus: params.healthFactorForMaxBonus,
      liquidationBonusFactor: params.liquidationBonusFactor,
      healthFactor: params.healthFactor,
      maxLiquidationBonus: params.maxLiquidationBonus
    });

    uint256 debtToLiquidate = liquidationLogicWrapper.calculateDebtToLiquidate(
      _getCalculateDebtToLiquidateParams(params)
    );
    uint256 collateralToLiquidate = debtToLiquidate.mulDivDown(
      params.debtAssetPrice * params.collateralAssetUnit * liquidationBonus,
      params.debtAssetUnit * params.collateralAssetPrice * PercentageMath.PERCENTAGE_FACTOR
    );
    uint256 collateralToLiquidator = _calculateCollateralToLiquidator(
      collateralToLiquidate,
      liquidationBonus,
      params.liquidationFee
    );

    return
      LiquidationLogic.LiquidationAmounts({
        collateralToLiquidate: collateralToLiquidate,
        collateralToLiquidator: collateralToLiquidator,
        debtToLiquidate: debtToLiquidate
      });
  }

  function _calculateAdjustedLiquidationAmounts(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) internal view returns (LiquidationLogic.LiquidationAmounts memory) {
    uint256 liquidationBonus = liquidationLogicWrapper.calculateLiquidationBonus({
      healthFactorForMaxBonus: params.healthFactorForMaxBonus,
      liquidationBonusFactor: params.liquidationBonusFactor,
      healthFactor: params.healthFactor,
      maxLiquidationBonus: params.maxLiquidationBonus
    });

    uint256 collateralToLiquidate = params.collateralReserveBalance;
    uint256 collateralToLiquidator = _calculateCollateralToLiquidator(
      collateralToLiquidate,
      liquidationBonus,
      params.liquidationFee
    );
    uint256 debtToLiquidate = collateralToLiquidate
      .mulDivUp(
        params.collateralAssetPrice * params.debtAssetUnit * PercentageMath.PERCENTAGE_FACTOR,
        params.collateralAssetUnit * params.debtAssetPrice * liquidationBonus
      )
      .min(params.debtReserveBalance);

    return
      LiquidationLogic.LiquidationAmounts({
        collateralToLiquidate: collateralToLiquidate,
        collateralToLiquidator: collateralToLiquidator,
        debtToLiquidate: debtToLiquidate
      });
  }

  function _calculateCollateralToLiquidator(
    uint256 collateralToLiquidate,
    uint256 liquidationBonus,
    uint256 liquidationFee
  ) internal pure returns (uint256) {
    uint256 bonusCollateral = collateralToLiquidate -
      collateralToLiquidate.percentDivUp(liquidationBonus);
    return collateralToLiquidate - bonusCollateral.percentMulDown(liquidationFee);
  }
}
