// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicLiquidationBonusTest is LiquidationLogicBaseTest {
  using PercentageMath for uint256;
  using SafeCast for uint256;

  function test_calculateLiquidationBonus_MinBonusDueToRounding() public view {
    uint256 liquidationBonus = liquidationLogicWrapper.calculateLiquidationBonus({
      healthFactorForMaxBonus: 0.8e18,
      liquidationBonusFactor: 50_00,
      healthFactor: 1e18 - 1,
      maxLiquidationBonus: 110_00
    });
    assertEq(liquidationBonus, 100_00 + 5_00);
  }

  function test_calculateLiquidationBonus_PartialBonus() public view {
    uint256 liquidationBonus = liquidationLogicWrapper.calculateLiquidationBonus({
      healthFactorForMaxBonus: 0.8e18,
      liquidationBonusFactor: 50_00,
      healthFactor: 0.96e18,
      maxLiquidationBonus: 110_00
    });
    assertEq(liquidationBonus, 100_00 + 6_00);
  }

  function test_calculateLiquidationBonus_fuzz_MaxBonus(
    uint256 healthFactorForMaxBonus,
    uint256 liquidationBonusFactor,
    uint256 healthFactor,
    uint256 maxLiquidationBonus
  ) public {
    (healthFactorForMaxBonus, liquidationBonusFactor, healthFactor, maxLiquidationBonus) = _bound(
      healthFactorForMaxBonus,
      liquidationBonusFactor,
      healthFactor,
      maxLiquidationBonus
    );
    healthFactor = bound(healthFactor, 0, healthFactorForMaxBonus);
    uint256 liquidationBonus = liquidationLogicWrapper.calculateLiquidationBonus({
      healthFactorForMaxBonus: healthFactorForMaxBonus,
      liquidationBonusFactor: liquidationBonusFactor,
      healthFactor: healthFactor,
      maxLiquidationBonus: maxLiquidationBonus
    });
    assertEq(liquidationBonus, maxLiquidationBonus);
    healthFactor = healthFactorForMaxBonus;
    liquidationBonus = liquidationLogicWrapper.calculateLiquidationBonus({
      healthFactorForMaxBonus: healthFactorForMaxBonus,
      liquidationBonusFactor: liquidationBonusFactor,
      healthFactor: healthFactor,
      maxLiquidationBonus: maxLiquidationBonus
    });
    assertEq(liquidationBonus, maxLiquidationBonus);
  }

  function test_calculateLiquidationBonus_fuzz_ConstantBonus(
    uint256 healthFactorForMaxBonus,
    uint256 liquidationBonusFactor,
    uint256 healthFactor,
    uint256 maxLiquidationBonus
  ) public {
    (healthFactorForMaxBonus, liquidationBonusFactor, healthFactor, maxLiquidationBonus) = _bound(
      healthFactorForMaxBonus,
      liquidationBonusFactor,
      healthFactor,
      maxLiquidationBonus
    );
    liquidationBonusFactor = PercentageMath.PERCENTAGE_FACTOR;
    uint256 liquidationBonus = liquidationLogicWrapper.calculateLiquidationBonus({
      healthFactorForMaxBonus: healthFactorForMaxBonus,
      liquidationBonusFactor: liquidationBonusFactor,
      healthFactor: healthFactor,
      maxLiquidationBonus: maxLiquidationBonus
    });
    assertEq(liquidationBonus, maxLiquidationBonus);
  }
}
