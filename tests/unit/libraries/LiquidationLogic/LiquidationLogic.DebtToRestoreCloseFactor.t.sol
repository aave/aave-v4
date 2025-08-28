// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicDebtToRestoreCloseFactorTest is LiquidationLogicBaseTest {
  using MathUtils for uint256;

  uint256[] assetUnitList;

  function setUp() public override {
    super.setUp();
    assetUnitList.push(1);
    assetUnitList.push(1e6);
    assetUnitList.push(1e18);
  }

  /// function does not revert when input is bounded properly
  function test_calculateDebtToRestoreCloseFactor_fuzz_NoRevert(
    LiquidationLogic.CalculateDebtToRestoreCloseFactorParams memory params
  ) public {
    liquidationLogicWrapper.calculateDebtToRestoreCloseFactor(_bound(params));
  }

  /// if debtAssetPrice == 0, then function reverts (should not happen in practice)
  function test_calculateDebtToRestoreCloseFactor_fuzz_revertsWith_DivisionByZero_ZeroAssetPrice(
    LiquidationLogic.CalculateDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    params.debtAssetPrice = 0;
    vm.expectRevert(); // MathUtils reverts with no data if division by zero
    liquidationLogicWrapper.calculateDebtToRestoreCloseFactor(params);
  }

  /// if health factor == close factor, then result is 0
  function test_calculateDebtToRestoreCloseFactor_HealthFactorEqualsCloseFactor(
    LiquidationLogic.CalculateDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    params.healthFactor = params.closeFactor;
    assertEq(liquidationLogicWrapper.calculateDebtToRestoreCloseFactor(params), 0);
  }

  /// if close factor is less than health factor, then function reverts (should not happen in practice)
  function test_calculateDebtToRestoreCloseFactor_revertsWith_ArithmeticError_CloseFactorLessThanHealthFactor(
    LiquidationLogic.CalculateDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    params.healthFactor = params.closeFactor + 1;
    vm.expectRevert(stdError.arithmeticError);
    liquidationLogicWrapper.calculateDebtToRestoreCloseFactor(params);
  }

  function test_calculateDebtToRestoreCloseFactor_UnitPrice() public {
    for (uint256 i = 0; i < assetUnitList.length; i++) {
      uint256 assetUnit = assetUnitList[i];
      uint256 debtToRestoreCloseFactor = liquidationLogicWrapper.calculateDebtToRestoreCloseFactor(
        LiquidationLogic.CalculateDebtToRestoreCloseFactorParams({
          totalDebtInBaseCurrency: 10_000e26,
          healthFactor: 0.8e18,
          closeFactor: 1.25e18,
          variableLiquidationBonus: 150_00,
          collateralFactor: 50_00,
          debtAssetUnit: assetUnit,
          debtAssetPrice: 1e8
        })
      );

      // liquidationPenalty = 1.5 * 0.5 = 0.75
      // debtToRestoreCloseFactor = $10000 * (1.25 - 0.8) / (1.25 - 0.75) / $1 = 9000
      assertEq(debtToRestoreCloseFactor, 9000 * assetUnit);
    }
  }

  function test_calculateDebtToRestoreCloseFactor_NoPrecisionLoss() public {
    for (uint256 i = 0; i < assetUnitList.length; i++) {
      uint256 assetUnit = assetUnitList[i];
      uint256 debtToRestoreCloseFactor = liquidationLogicWrapper.calculateDebtToRestoreCloseFactor(
        LiquidationLogic.CalculateDebtToRestoreCloseFactorParams({
          totalDebtInBaseCurrency: 10_000e26,
          healthFactor: 0.8e18,
          closeFactor: 1e18,
          variableLiquidationBonus: 150_00,
          collateralFactor: 50_00,
          debtAssetUnit: assetUnit,
          debtAssetPrice: 2000e8
        })
      );

      // liquidationPenalty = 1.5 * 0.5 = 0.75
      // debtToRestoreCloseFactor = $10000 * (1 - 0.8) / (1 - 0.75) / $2000 = 4
      assertEq(debtToRestoreCloseFactor, 4 * assetUnit);
    }
  }

  function test_calculateDebtToRestoreCloseFactor_PrecisionLoss() public {
    LiquidationLogic.CalculateDebtToRestoreCloseFactorParams memory params = LiquidationLogic
      .CalculateDebtToRestoreCloseFactorParams({
        totalDebtInBaseCurrency: 10_000e26,
        healthFactor: 0.8e18,
        closeFactor: 1e18,
        variableLiquidationBonus: 150_00,
        collateralFactor: 50_00,
        debtAssetUnit: 1,
        debtAssetPrice: 333e8
      });
    uint256 debtToRestoreCloseFactor = liquidationLogicWrapper.calculateDebtToRestoreCloseFactor(
      params
    );
    assertEq(debtToRestoreCloseFactor, 25);

    params.debtAssetUnit = 1e6;
    debtToRestoreCloseFactor = liquidationLogicWrapper.calculateDebtToRestoreCloseFactor(params);
    assertEq(debtToRestoreCloseFactor, 24.024025e6);

    params.debtAssetUnit = 1e18;
    debtToRestoreCloseFactor = liquidationLogicWrapper.calculateDebtToRestoreCloseFactor(params);
    assertEq(debtToRestoreCloseFactor, 24.024024024024024025e18);
  }
}
