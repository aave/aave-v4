// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicLiquidationAmountsTest is LiquidationLogicBaseTest {
  using MathUtils for uint256;
  using PercentageMath for uint256;
  using WadRayMath for uint256;
  using LiquidationLogic for uint256;

  function test_calculateLiquidationAmounts_fuzz_EnoughCollateral_NoCollateralDust(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) public {
    params = _bound(params);
    LiquidationLogic.LiquidationAmounts
      memory expectedLiquidationAmounts = _calculateRawLiquidationAmounts(params);

    uint256 dustSharesBufferLowerBound = params.collateralReserveHub.previewRemoveByAssets(
      params.collateralReserveAssetId,
      _convertValueToAmount(
        LiquidationLogic.DUST_LIQUIDATION_THRESHOLD,
        params.collateralAssetPrice,
        10 ** params.collateralAssetDecimals
      ) + 1
    );

    params.suppliedShares = bound(
      params.suppliedShares,
      expectedLiquidationAmounts.collateralSharesToLiquidate + dustSharesBufferLowerBound + 1,
      expectedLiquidationAmounts.collateralSharesToLiquidate +
        dustSharesBufferLowerBound +
        1 +
        MAX_SUPPLY_AMOUNT
    );

    params.debtToCover = bound(
      params.debtToCover,
      _calculateDebtAssetsToRestore(
        expectedLiquidationAmounts.drawnSharesToLiquidate,
        expectedLiquidationAmounts.premiumDebtRayToLiquidate,
        params.drawnIndex
      ),
      UINT256_MAX
    );

    LiquidationLogic.LiquidationAmounts memory liquidationAmounts = liquidationLogicWrapper
      .calculateLiquidationAmounts(params);

    assertApproxEqAbs(liquidationAmounts, expectedLiquidationAmounts);
  }

  function test_calculateLiquidationAmounts_fuzz_EnoughCollateral_NoDebtLeft(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) public {
    params = _boundWithDebtDustAdjustment(params);

    LiquidationLogic.LiquidationAmounts
      memory expectedLiquidationAmounts = _calculateRawLiquidationAmounts(params);

    params.suppliedShares = bound(
      params.suppliedShares,
      expectedLiquidationAmounts.collateralSharesToLiquidate,
      expectedLiquidationAmounts.collateralSharesToLiquidate + MAX_SUPPLY_AMOUNT
    );

    params.debtToCover = bound(
      params.debtToCover,
      _calculateDebtAssetsToRestore(
        expectedLiquidationAmounts.drawnSharesToLiquidate,
        expectedLiquidationAmounts.premiumDebtRayToLiquidate,
        params.drawnIndex
      ),
      UINT256_MAX
    );

    LiquidationLogic.LiquidationAmounts memory liquidationAmounts = liquidationLogicWrapper
      .calculateLiquidationAmounts(params);

    assertApproxEqAbs(liquidationAmounts, expectedLiquidationAmounts);
  }

  function test_calculateLiquidationAmounts_fuzz_EnoughCollateral_CollateralDust(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) public {
    params = _boundWithCollateralDustAdjustment(params);
    LiquidationLogic.LiquidationAmounts
      memory expectedLiquidationAmounts = _calculateRawLiquidationAmounts(params);
    if (expectedLiquidationAmounts.drawnSharesToLiquidate < params.drawnShares) {
      expectedLiquidationAmounts = _calculateAdjustedLiquidationAmounts(params);
    }

    LiquidationLogic.LiquidationAmounts memory liquidationAmounts = liquidationLogicWrapper
      .calculateLiquidationAmounts(params);

    assertApproxEqAbs(liquidationAmounts, expectedLiquidationAmounts);
  }

  function test_calculateLiquidationAmounts_fuzz_InsufficientCollateral(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) public {
    params = _bound(params);
    LiquidationLogic.LiquidationAmounts
      memory rawLiquidationAmounts = _calculateRawLiquidationAmounts(params);
    vm.assume(rawLiquidationAmounts.collateralSharesToLiquidate > 0);
    params.suppliedShares = bound(
      params.suppliedShares,
      0,
      rawLiquidationAmounts.collateralSharesToLiquidate - 1
    );

    LiquidationLogic.LiquidationAmounts
      memory expectedLiquidationAmounts = _calculateAdjustedLiquidationAmounts(params);

    params.debtToCover = bound(
      params.debtToCover,
      _calculateDebtAssetsToRestore(
        expectedLiquidationAmounts.drawnSharesToLiquidate,
        expectedLiquidationAmounts.premiumDebtRayToLiquidate,
        params.drawnIndex
      ),
      MAX_SUPPLY_AMOUNT
    );

    LiquidationLogic.LiquidationAmounts memory liquidationAmounts = liquidationLogicWrapper
      .calculateLiquidationAmounts(params);

    assertApproxEqAbs(liquidationAmounts, expectedLiquidationAmounts);
  }

  function test_calculateLiquidationAmounts_fuzz_revertsWith_MustNotLeaveDust_Debt(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) public {
    params = _boundWithDebtDustAdjustment(params);
    uint256 debtAssetsToRestore = _calculateDebtAssetsToRestore(
      params.drawnShares,
      params.premiumDebtRay,
      params.drawnIndex
    );
    if (params.debtToCover >= debtAssetsToRestore) {
      params.debtToCover = debtAssetsToRestore - 1;
    }
    LiquidationLogic.LiquidationAmounts
      memory rawLiquidationAmounts = _calculateRawLiquidationAmounts(params);
    params.suppliedShares = rawLiquidationAmounts.collateralSharesToLiquidate;

    vm.expectRevert(ISpoke.MustNotLeaveDust.selector);
    liquidationLogicWrapper.calculateLiquidationAmounts(params);
  }

  function test_calculateLiquidationAmounts_fuzz_revertsWith_MustNotLeaveDust_Collateral(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) public {
    params = _boundWithCollateralDustAdjustment(params);
    LiquidationLogic.LiquidationAmounts
      memory expectedLiquidationAmounts = _calculateAdjustedLiquidationAmounts(params);
    vm.assume(expectedLiquidationAmounts.premiumDebtRayToLiquidate > 0);
    params.debtToCover =
      _calculateDebtAssetsToRestore(
        expectedLiquidationAmounts.drawnSharesToLiquidate,
        expectedLiquidationAmounts.premiumDebtRayToLiquidate,
        params.drawnIndex
      ) - 1;

    vm.expectRevert(ISpoke.MustNotLeaveDust.selector);
    liquidationLogicWrapper.calculateLiquidationAmounts(params);
  }

  function test_calculateLiquidationAmounts_EnoughCollateral() public {
    // variable liquidation bonus is max: 120%
    // liquidation penalty: 1.2 * 0.5 = 0.6
    // debtToTarget = $10000 * (1 - 0.8) / (1 - 0.6) / $2000 = 2.5
    // max debt to liquidate = min(2.5, 3 * 1.6 + 0.5, 3) = 2.5
    // premiumDebtRayToLiquidate = 0.5
    // drawnSharesToLiquidate = (2.5 - 0.5) / 1.6 = 1.25
    // collateral to liquidate = 2.5 * 120% * $2000 / $1 = 6000
    // collateral shares to liquidate = 6000 / 1.25 = 4800
    // bonus collateral shares = 4800 - 4800 / 120% = 800
    // collateral fee shares = 800 * 10% = 80
    // collateral shares to liquidator = 4800 - 80 = 4720
    IHub collateralReserveHub = hub1;
    uint256 collateralAssetId = vm.randomUint(0, collateralReserveHub.getAssetCount() - 1);
    _mockSupplySharePrice(collateralReserveHub, collateralAssetId, 12_500.25e6, 10_000e6);

    LiquidationLogic.LiquidationAmounts memory liquidationAmounts = liquidationLogicWrapper
      .calculateLiquidationAmounts(
        LiquidationLogic.CalculateLiquidationAmountsParams({
          collateralReserveHub: collateralReserveHub,
          collateralReserveAssetId: collateralAssetId,
          suppliedShares: 10_000e6,
          collateralAssetDecimals: 6,
          collateralAssetPrice: 1e8,
          drawnShares: 3e18,
          premiumDebtRay: 0.5e18 * 1e27,
          drawnIndex: 1.6e27,
          totalDebtValueRay: 10_000e26 * WadRayMath.RAY,
          debtAssetDecimals: 18,
          debtAssetPrice: 2000e8,
          debtToCover: 3e18,
          collateralFactor: 50_00,
          healthFactorForMaxBonus: 0.8e18,
          liquidationBonusFactor: 50_00,
          maxLiquidationBonus: 120_00,
          targetHealthFactor: 1e18,
          healthFactor: 0.8e18,
          liquidationFee: 10_00
        })
      );

    assertApproxEqAbs(
      liquidationAmounts,
      LiquidationLogic.LiquidationAmounts({
        collateralSharesToLiquidate: 4800e6,
        collateralSharesToLiquidator: 4720e6,
        drawnSharesToLiquidate: 1.25e18,
        premiumDebtRayToLiquidate: 0.5e18 * 1e27
      })
    );
  }

  function test_calculateLiquidationAmounts_InsufficientCollateral() public {
    // variable liquidation bonus is max: 120%
    // liquidation penalty: 1.2 * 0.5 = 0.6
    // debtToTarget = $10000 * (1 - 0.8) / (1 - 0.6) / $2000 = 2.5
    // max debt to liquidate = min(2.5, 3 * 1.6 + 0.5, 3) = 2.5
    // collateral to liquidate = 2.5 * 120% * $2000 / $1 = 6000
    // collateral shares to liquidate = 6000 / 1.25 = 4800
    // supplied shares: 4500
    // adjusted debt to liquidate = 4500 * 1.25 / 120% * $1 / $2000 = 2.34375
    // premiumDebtRayToLiquidate = 0.5
    // drawnSharesToLiquidate = (2.34375 - 0.5) / 1.6 = 1.15234375
    // bonus collateral shares = 4500 - 4500 / 120% = 750
    // collateral fee shares = 750 * 10% = 75
    // collateral shares to liquidator = 4500 - 75 = 4425
    IHub collateralReserveHub = hub1;
    uint256 collateralAssetId = vm.randomUint(0, collateralReserveHub.getAssetCount() - 1);
    _mockSupplySharePrice(collateralReserveHub, collateralAssetId, 12500.25e6, 10_000e6);

    LiquidationLogic.LiquidationAmounts memory liquidationAmounts = liquidationLogicWrapper
      .calculateLiquidationAmounts(
        LiquidationLogic.CalculateLiquidationAmountsParams({
          collateralReserveHub: collateralReserveHub,
          collateralReserveAssetId: collateralAssetId,
          suppliedShares: 4500e6,
          collateralAssetDecimals: 6,
          collateralAssetPrice: 1e8,
          drawnShares: 3e18,
          premiumDebtRay: 0.5e18 * 1e27,
          drawnIndex: 1.6e27,
          totalDebtValueRay: 10_000e26 * WadRayMath.RAY,
          debtAssetDecimals: 18,
          debtAssetPrice: 2000e8,
          debtToCover: 3e18,
          collateralFactor: 50_00,
          healthFactorForMaxBonus: 0.8e18,
          liquidationBonusFactor: 50_00,
          maxLiquidationBonus: 120_00,
          targetHealthFactor: 1e18,
          healthFactor: 0.8e18,
          liquidationFee: 10_00
        })
      );

    assertApproxEqAbs(
      liquidationAmounts,
      LiquidationLogic.LiquidationAmounts({
        collateralSharesToLiquidate: 4500e6,
        collateralSharesToLiquidator: 4425e6,
        drawnSharesToLiquidate: 1.15234375e18,
        premiumDebtRayToLiquidate: 0.5e18 * 1e27
      })
    );
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

    (uint256 drawnSharesToLiquidate, uint256 premiumDebtRayToLiquidate) = liquidationLogicWrapper
      .calculateDebtToLiquidate(_getCalculateDebtToLiquidateParams(params));
    uint256 debtRayToLiquidate = drawnSharesToLiquidate * params.drawnIndex +
      premiumDebtRayToLiquidate;
    uint256 collateralToLiquidate = Math.mulDiv(
      debtRayToLiquidate,
      params.debtAssetPrice * (10 ** params.collateralAssetDecimals) * liquidationBonus,
      (10 ** params.debtAssetDecimals) *
        params.collateralAssetPrice *
        PercentageMath.PERCENTAGE_FACTOR *
        WadRayMath.RAY,
      Math.Rounding.Floor
    );
    uint256 collateralSharesToLiquidate = params.collateralReserveHub.previewAddByAssets(
      params.collateralReserveAssetId,
      collateralToLiquidate
    );
    uint256 collateralSharesToLiquidator = _calculateCollateralSharesToLiquidator(
      collateralSharesToLiquidate,
      liquidationBonus,
      params.liquidationFee
    );

    return
      LiquidationLogic.LiquidationAmounts({
        collateralSharesToLiquidate: collateralSharesToLiquidate,
        collateralSharesToLiquidator: collateralSharesToLiquidator,
        drawnSharesToLiquidate: drawnSharesToLiquidate,
        premiumDebtRayToLiquidate: premiumDebtRayToLiquidate
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

    uint256 collateralSharesToLiquidate = params.suppliedShares;
    uint256 collateralSharesToLiquidator = _calculateCollateralSharesToLiquidator(
      collateralSharesToLiquidate,
      liquidationBonus,
      params.liquidationFee
    );

    uint256 debtRayToLiquidate = Math.mulDiv(
      params.collateralReserveHub.previewAddByShares(
        params.collateralReserveAssetId,
        collateralSharesToLiquidate
      ),
      params.collateralAssetPrice *
        (10 ** params.debtAssetDecimals) *
        PercentageMath.PERCENTAGE_FACTOR *
        WadRayMath.RAY,
      (10 ** params.collateralAssetDecimals) * params.debtAssetPrice * liquidationBonus,
      Math.Rounding.Ceil
    );

    uint256 premiumDebtRayToLiquidate = debtRayToLiquidate.fromRayUp().toRay().min(
      params.premiumDebtRay
    );
    uint256 drawnSharesToLiquidate;
    if (premiumDebtRayToLiquidate < debtRayToLiquidate) {
      drawnSharesToLiquidate = (debtRayToLiquidate - premiumDebtRayToLiquidate).divUp(
        params.drawnIndex
      );
    }

    if (drawnSharesToLiquidate > params.drawnShares) {
      drawnSharesToLiquidate = params.drawnShares;
    }

    return
      LiquidationLogic.LiquidationAmounts({
        collateralSharesToLiquidate: collateralSharesToLiquidate,
        collateralSharesToLiquidator: collateralSharesToLiquidator,
        drawnSharesToLiquidate: drawnSharesToLiquidate,
        premiumDebtRayToLiquidate: premiumDebtRayToLiquidate
      });
  }

  function _boundWithCollateralDustAdjustment(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) internal virtual returns (LiquidationLogic.CalculateLiquidationAmountsParams memory) {
    params = _bound(params);
    params.drawnShares = MAX_SUPPLY_ASSET_UNITS * 10 ** params.debtAssetDecimals;
    params.debtToCover = UINT256_MAX;

    // bound price such that 1 supply share is worth less than DUST_LIQUIDATION_THRESHOLD
    params.collateralAssetPrice = bound(
      params.collateralAssetPrice,
      1,
      params.collateralReserveHub.previewAddByAssets(
        params.collateralReserveAssetId,
        _convertDecimals(
          LiquidationLogic.DUST_LIQUIDATION_THRESHOLD,
          18,
          params.collateralAssetDecimals,
          false
        )
      )
    );

    LiquidationLogic.LiquidationAmounts
      memory expectedLiquidationAmounts = _calculateRawLiquidationAmounts(params);

    uint256 dustSharesBufferUpperBound = params.collateralReserveHub.previewAddByAssets(
      params.collateralReserveAssetId,
      _convertValueToAmount(
        LiquidationLogic.DUST_LIQUIDATION_THRESHOLD - 1,
        params.collateralAssetPrice,
        10 ** params.collateralAssetDecimals
      )
    );

    params.suppliedShares = bound(
      params.suppliedShares,
      expectedLiquidationAmounts.collateralSharesToLiquidate + 1,
      expectedLiquidationAmounts.collateralSharesToLiquidate + _max(1, dustSharesBufferUpperBound)
    );

    expectedLiquidationAmounts = _calculateAdjustedLiquidationAmounts(params);

    params.debtToCover = bound(
      params.debtToCover,
      _calculateDebtAssetsToRestore(
        expectedLiquidationAmounts.drawnSharesToLiquidate,
        expectedLiquidationAmounts.premiumDebtRayToLiquidate,
        params.drawnIndex
      ),
      UINT256_MAX
    );

    return params;
  }

  function _calculateCollateralSharesToLiquidator(
    uint256 collateralSharesToLiquidate,
    uint256 liquidationBonus,
    uint256 liquidationFee
  ) internal pure returns (uint256) {
    uint256 bonusCollateralShares = collateralSharesToLiquidate -
      collateralSharesToLiquidate.percentDivUp(liquidationBonus);
    return collateralSharesToLiquidate - bonusCollateralShares.percentMulDown(liquidationFee);
  }

  function assertApproxEqAbs(
    LiquidationLogic.LiquidationAmounts memory a,
    LiquidationLogic.LiquidationAmounts memory b
  ) internal pure {
    assertEq(
      a.collateralSharesToLiquidate,
      b.collateralSharesToLiquidate,
      'collateralSharesToLiquidate'
    );
    assertApproxEqAbs(
      a.collateralSharesToLiquidator,
      b.collateralSharesToLiquidator,
      1,
      'collateralSharesToLiquidator'
    );
    assertEq(a.drawnSharesToLiquidate, b.drawnSharesToLiquidate, 'drawnSharesToLiquidate');
    assertEq(a.premiumDebtRayToLiquidate, b.premiumDebtRayToLiquidate, 'premiumDebtRayToLiquidate');
  }
}
