// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicDebtToRestoreTargetHealthFactorTest is LiquidationLogicBaseTest {
  using MathUtils for uint256;

  uint256[] assetUnitList;

  function setUp() public override {
    super.setUp();
    assetUnitList.push(1);
    assetUnitList.push(1e6);
    assetUnitList.push(1e18);
  }

  /// function does not revert when input is bounded properly
  function test_calculateDebtToRestoreTargetHealthFactor_fuzz_NoRevert(
    LiquidationLogic.CalculateDebtToRestoreTargetHealthFactorParams memory params
  ) public {
    liquidationLogicWrapper.calculateDebtToRestoreTargetHealthFactor(_bound(params));
  }

  /// if debtAssetPrice == 0, then function reverts (should not happen in practice)
  function test_calculateDebtToRestoreTargetHealthFactor_fuzz_revertsWith_DivisionByZero_ZeroAssetPrice(
    LiquidationLogic.CalculateDebtToRestoreTargetHealthFactorParams memory params
  ) public {
    params = _bound(params);
    params.debtAssetPrice = 0;
    vm.expectRevert(); // MathUtils reverts with no data if division by zero
    liquidationLogicWrapper.calculateDebtToRestoreTargetHealthFactor(params);
  }

  /// if health factor == close factor, then result is 0
  function test_calculateDebtToRestoreTargetHealthFactor_HealthFactorEqualsTargetHealthFactor(
    LiquidationLogic.CalculateDebtToRestoreTargetHealthFactorParams memory params
  ) public {
    params = _bound(params);
    params.healthFactor = params.targetHealthFactor;
    assertEq(liquidationLogicWrapper.calculateDebtToRestoreTargetHealthFactor(params), 0);
  }

  /// if close factor is less than health factor, then function reverts (should not happen in practice)
  function test_calculateDebtToRestoreTargetHealthFactor_revertsWith_ArithmeticError_TargetHealthFactorLessThanHealthFactor(
    LiquidationLogic.CalculateDebtToRestoreTargetHealthFactorParams memory params
  ) public {
    params = _bound(params);
    params.healthFactor = params.targetHealthFactor + 1;
    vm.expectRevert(stdError.arithmeticError);
    liquidationLogicWrapper.calculateDebtToRestoreTargetHealthFactor(params);
  }

  function test_calculateDebtToRestoreTargetHealthFactor_UnitPrice() public {
    for (uint256 i = 0; i < assetUnitList.length; i++) {
      uint256 assetUnit = assetUnitList[i];
      uint256 debtToRestoreTargetHealthFactor = liquidationLogicWrapper
        .calculateDebtToRestoreTargetHealthFactor(
          LiquidationLogic.CalculateDebtToRestoreTargetHealthFactorParams({
            totalDebtInBaseCurrency: 10_000e26,
            healthFactor: 0.8e18,
            targetHealthFactor: 1.25e18,
            liquidationBonus: 150_00,
            collateralFactor: 50_00,
            debtAssetUnit: assetUnit,
            debtAssetPrice: 1e8
          })
        );

      // liquidationPenalty = 1.5 * 0.5 = 0.75
      // debtToRestoreTargetHealthFactor = $10000 * (1.25 - 0.8) / (1.25 - 0.75) / $1 = 9000
      assertEq(debtToRestoreTargetHealthFactor, 9000 * assetUnit);
    }
  }

  function test_calculateDebtToRestoreTargetHealthFactor_NoPrecisionLoss() public {
    for (uint256 i = 0; i < assetUnitList.length; i++) {
      uint256 assetUnit = assetUnitList[i];
      uint256 debtToRestoreTargetHealthFactor = liquidationLogicWrapper
        .calculateDebtToRestoreTargetHealthFactor(
          LiquidationLogic.CalculateDebtToRestoreTargetHealthFactorParams({
            totalDebtInBaseCurrency: 10_000e26,
            healthFactor: 0.8e18,
            targetHealthFactor: 1e18,
            liquidationBonus: 150_00,
            collateralFactor: 50_00,
            debtAssetUnit: assetUnit,
            debtAssetPrice: 2000e8
          })
        );

      // liquidationPenalty = 1.5 * 0.5 = 0.75
      // debtToRestoreTargetHealthFactor = $10000 * (1 - 0.8) / (1 - 0.75) / $2000 = 4
      assertEq(debtToRestoreTargetHealthFactor, 4 * assetUnit);
    }
  }

  function test_calculateDebtToRestoreTargetHealthFactor_PrecisionLoss() public {
    LiquidationLogic.CalculateDebtToRestoreTargetHealthFactorParams memory params = LiquidationLogic
      .CalculateDebtToRestoreTargetHealthFactorParams({
        totalDebtInBaseCurrency: 10_000e26,
        healthFactor: 0.8e18,
        targetHealthFactor: 1e18,
        liquidationBonus: 150_00,
        collateralFactor: 50_00,
        debtAssetUnit: 1,
        debtAssetPrice: 333e8
      });
    uint256 debtToRestoreTargetHealthFactor = liquidationLogicWrapper
      .calculateDebtToRestoreTargetHealthFactor(params);
    assertEq(debtToRestoreTargetHealthFactor, 25);

    params.debtAssetUnit = 1e6;
    debtToRestoreTargetHealthFactor = liquidationLogicWrapper
      .calculateDebtToRestoreTargetHealthFactor(params);
    assertEq(debtToRestoreTargetHealthFactor, 24.024025e6);

    params.debtAssetUnit = 1e18;
    debtToRestoreTargetHealthFactor = liquidationLogicWrapper
      .calculateDebtToRestoreTargetHealthFactor(params);
    assertEq(debtToRestoreTargetHealthFactor, 24.024024024024024025e18);
  }
}
