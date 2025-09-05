// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicLiquidationBonusTest is LiquidationLogicBaseTest {
  using PercentageMath for uint256;
  using SafeCast for uint256;

  function test_calculateLiquidationBonus_MinBonusDueToRounding() public {
    DataTypes.CalculateLiquidationBonusParams memory params = DataTypes
      .CalculateLiquidationBonusParams({
        healthFactorForMaxBonus: 0.8e18,
        healthFactor: 1e18 - 1,
        maxLiquidationBonus: 110_00,
        liquidationBonusFactor: 50_00
      });

    uint256 liquidationBonus = liquidationLogicWrapper.calculateLiquidationBonus(params);
    assertEq(liquidationBonus, 100_00 + 5_00);
  }

  function test_calculateLiquidationBonus_PartialBonus() public {
    DataTypes.CalculateLiquidationBonusParams memory params = DataTypes
      .CalculateLiquidationBonusParams({
        healthFactorForMaxBonus: 0.8e18,
        healthFactor: 0.96e18,
        maxLiquidationBonus: 110_00,
        liquidationBonusFactor: 50_00
      });

    uint256 liquidationBonus = liquidationLogicWrapper.calculateLiquidationBonus(params);
    assertEq(liquidationBonus, 100_00 + 6_00);
  }

  function test_calculateLiquidationBonus_fuzz_MaxBonus(
    DataTypes.CalculateLiquidationBonusParams memory params
  ) public {
    params = _bound(params);
    params.healthFactor = bound(params.healthFactor, 0, params.healthFactorForMaxBonus);
    uint256 liquidationBonus = liquidationLogicWrapper.calculateLiquidationBonus(params);
    assertEq(liquidationBonus, params.maxLiquidationBonus);
    params.healthFactor = params.healthFactorForMaxBonus;
    liquidationBonus = liquidationLogicWrapper.calculateLiquidationBonus(params);
    assertEq(liquidationBonus, params.maxLiquidationBonus);
  }

  function test_calculateLiquidationBonus_fuzz_ConstantBonus(
    DataTypes.CalculateLiquidationBonusParams memory params
  ) public {
    params = _bound(params);
    params.liquidationBonusFactor = PercentageMath.PERCENTAGE_FACTOR;
    uint256 liquidationBonus = liquidationLogicWrapper.calculateLiquidationBonus(params);
    assertEq(liquidationBonus, params.maxLiquidationBonus);
  }
}
