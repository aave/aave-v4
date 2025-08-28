// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicVariableLiquidationBonusTest is LiquidationLogicBaseTest {
  using PercentageMath for uint256;
  using SafeCast for uint256;

  function test_calculateVariableLiquidationBonus_MinBonusDueToRounding() public {
    DataTypes.CalculateVariableLiquidationBonusParams memory params = DataTypes
      .CalculateVariableLiquidationBonusParams({
        healthFactorForMaxBonus: 0.8e18,
        healthFactor: 1e18 - 1,
        liquidationBonus: 110_00,
        liquidationBonusFactor: 50_00
      });

    uint256 variableLiquidationBonus = liquidationLogicWrapper.calculateVariableLiquidationBonus(params);
    assertEq(variableLiquidationBonus, 100_00 + 5_00);
  }

  function test_calculateVariableLiquidationBonus_PartialBonus() public {
    DataTypes.CalculateVariableLiquidationBonusParams memory params = DataTypes
      .CalculateVariableLiquidationBonusParams({
        healthFactorForMaxBonus: 0.8e18,
        healthFactor: 0.96e18,
        liquidationBonus: 110_00,
        liquidationBonusFactor: 50_00
      });

    uint256 variableLiquidationBonus = liquidationLogicWrapper.calculateVariableLiquidationBonus(params);
    assertEq(variableLiquidationBonus, 100_00 + 6_00);
  }

  function test_calculateVariableLiquidationBonus_fuzz_MaxBonus(
    DataTypes.CalculateVariableLiquidationBonusParams memory params
  ) public {
    params = _bound(params);
    params.healthFactor = bound(params.healthFactor, 0, params.healthFactorForMaxBonus);
    uint256 variableLiquidationBonus = liquidationLogicWrapper.calculateVariableLiquidationBonus(params);
    assertEq(variableLiquidationBonus, params.liquidationBonus);
    params.healthFactor = params.healthFactorForMaxBonus;
    variableLiquidationBonus = liquidationLogicWrapper.calculateVariableLiquidationBonus(params);
    assertEq(variableLiquidationBonus, params.liquidationBonus);
  }

  function test_calculateVariableLiquidationBonus_fuzz_ConstantBonus(
    DataTypes.CalculateVariableLiquidationBonusParams memory params
  ) public {
    params = _bound(params);
    params.liquidationBonusFactor = PercentageMath.PERCENTAGE_FACTOR;
    uint256 variableLiquidationBonus = liquidationLogicWrapper.calculateVariableLiquidationBonus(params);
    assertEq(variableLiquidationBonus, params.liquidationBonus);
  }
}
