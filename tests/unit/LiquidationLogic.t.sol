// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {Base} from 'tests/Base.t.sol';

contract LiquidationLogicTest is Base {
  using PercentageMath for uint256;

  /// when < healthFactorBonusThreshold, return liquidationBonus
  function testCalculateVariableLiquidationBonus_lt_bonusThreshold() public {
    uint256 healthFactor = 0.8e18;
    uint256 healthFactorLiquidationThreshold = WadRayMath.WAD;
    uint256 liquidationBonus = 20_00; // 20%
    uint256 liquidationBonusFactor = 40_00; // 40%

    DataTypes.VariableLiquidationBonusConfig memory config = DataTypes
      .VariableLiquidationBonusConfig({
        healthFactorBonusThreshold: 0.9e18,
        liquidationBonusFactor: liquidationBonusFactor
      });

    uint256 result = LiquidationLogic.calculateVariableLiquidationBonus(
      healthFactor,
      config,
      healthFactorLiquidationThreshold,
      liquidationBonus
    );

    assertEq(result, liquidationBonus, 'should be liquidationBonus');
  }

  /// when < healthFactorBonusThreshold, return liquidationBonus
  function testCalculateVariableLiquidationBonus_eq_bonusThreshold() public {
    uint256 healthFactorBonusThreshold = 0.9e18;

    uint256 healthFactor = healthFactorBonusThreshold;
    uint256 healthFactorLiquidationThreshold = WadRayMath.WAD;
    uint256 liquidationBonus = 20_00; // 20%
    uint256 liquidationBonusFactor = 40_00; // 40%

    DataTypes.VariableLiquidationBonusConfig memory config = DataTypes
      .VariableLiquidationBonusConfig({
        healthFactorBonusThreshold: healthFactorBonusThreshold,
        liquidationBonusFactor: liquidationBonusFactor
      });

    uint256 result = LiquidationLogic.calculateVariableLiquidationBonus(
      healthFactor,
      config,
      healthFactorLiquidationThreshold,
      liquidationBonus
    );

    assertEq(result, liquidationBonus, 'should be liquidationBonus');
  }

  /// fuzz - when < healthFactorBonusThreshold, return liquidationBonus
  function testCalculateVariableLiquidationBonus_fuzz_lt_bonusThreshold(
    uint256 healthFactor,
    uint256 healthFactorBonusThreshold,
    uint256 liquidationBonus,
    uint256 liquidationBonusFactor
  ) public {
    liquidationBonus = bound(liquidationBonus, 0, MAX_LIQUIDATION_BONUS); // BPS
    liquidationBonusFactor = bound(liquidationBonusFactor, 0, MAX_LIQUIDATION_BONUS_FACTOR); // BPS

    uint256 healthFactorLiquidationThreshold = WadRayMath.WAD;

    healthFactorBonusThreshold = bound(
      healthFactorBonusThreshold,
      1,
      healthFactorLiquidationThreshold
    );
    healthFactor = bound(healthFactor, 0, healthFactorBonusThreshold - 1);

    DataTypes.VariableLiquidationBonusConfig memory config = DataTypes
      .VariableLiquidationBonusConfig({
        healthFactorBonusThreshold: healthFactorBonusThreshold,
        liquidationBonusFactor: liquidationBonusFactor
      });

    uint256 result = LiquidationLogic.calculateVariableLiquidationBonus(
      healthFactor,
      config,
      healthFactorLiquidationThreshold,
      liquidationBonus
    );

    assertEq(result, liquidationBonus, 'should be liquidationBonus');
  }

  /// when > healthFactorLiquidationThreshold, return minLiquidationBonus
  function testCalculateVariableLiquidationBonus_gt_liquidationThreshold() public {
    uint256 healthFactorLiquidationThreshold = WadRayMath.WAD;
    uint256 healthFactor = healthFactorLiquidationThreshold + 1;

    uint256 liquidationBonus = 20_00; // 20%
    uint256 liquidationBonusFactor = 40_00; // 40%

    DataTypes.VariableLiquidationBonusConfig memory config = DataTypes
      .VariableLiquidationBonusConfig({
        healthFactorBonusThreshold: 0.9e18,
        liquidationBonusFactor: liquidationBonusFactor
      });

    uint256 result = LiquidationLogic.calculateVariableLiquidationBonus(
      healthFactor,
      config,
      healthFactorLiquidationThreshold,
      liquidationBonus
    );

    assertEq(
      result,
      liquidationBonus.percentMul(liquidationBonusFactor),
      'should be minLiquidationBonus'
    );
  }

  /// fuzz - when > healthFactorLiquidationThreshold, return minLiquidationBonus
  function testCalculateVariableLiquidationBonus_fuzz_gt_liquidationThreshold(
    uint256 healthFactor,
    uint256 healthFactorBonusThreshold,
    uint256 liquidationBonus,
    uint256 liquidationBonusFactor
  ) public {
    liquidationBonus = bound(liquidationBonus, 0, MAX_LIQUIDATION_BONUS); // BPS
    liquidationBonusFactor = bound(liquidationBonusFactor, 0, MAX_LIQUIDATION_BONUS_FACTOR); // BPS

    uint256 healthFactorLiquidationThreshold = WadRayMath.WAD;
    uint256 healthFactor = healthFactorLiquidationThreshold + 1;

    healthFactorBonusThreshold = bound(
      healthFactorBonusThreshold,
      1,
      healthFactorLiquidationThreshold
    );
    vm.assume(healthFactor > healthFactorLiquidationThreshold);

    DataTypes.VariableLiquidationBonusConfig memory config = DataTypes
      .VariableLiquidationBonusConfig({
        healthFactorBonusThreshold: healthFactorBonusThreshold,
        liquidationBonusFactor: liquidationBonusFactor
      });

    uint256 result = LiquidationLogic.calculateVariableLiquidationBonus(
      healthFactor,
      config,
      healthFactorLiquidationThreshold,
      liquidationBonus
    );

    assertEq(
      result,
      liquidationBonus.percentMul(liquidationBonusFactor),
      'should be minLiquidationBonus'
    );
  }

  /// when healthFactorBonusThreshold < healthFactor < healthFactorLiquidationThreshold
  function testCalculateVariableLiquidationBonus_intermediateValue() public {
    uint256 healthFactorLiquidationThreshold = WadRayMath.WAD;
    uint256 healthFactor = healthFactorLiquidationThreshold + 1;

    uint256 liquidationBonus = 20_00; // 20%
    uint256 liquidationBonusFactor = 40_00; // 40%
    uint256 healthFactorBonusThreshold = 0.9e18;

    DataTypes.VariableLiquidationBonusConfig memory config = DataTypes
      .VariableLiquidationBonusConfig({
        healthFactorBonusThreshold: healthFactorBonusThreshold,
        liquidationBonusFactor: liquidationBonusFactor
      });

    uint256 result = LiquidationLogic.calculateVariableLiquidationBonus(
      healthFactor,
      config,
      healthFactorLiquidationThreshold,
      liquidationBonus
    );

    assertEq(
      result,
      _calculateVariableLiquidationBonus(
        healthFactor,
        config.healthFactorBonusThreshold,
        liquidationBonusFactor,
        healthFactorLiquidationThreshold,
        liquidationBonus
      ),
      'should be linear interpolation'
    );
  }

  function _calculateVariableLiquidationBonus(
    uint256 healthFactor,
    uint256 healthFactorBonusThreshold,
    uint256 liquidationBonusFactor,
    uint256 healthFactorLiquidationThreshold,
    uint256 liquidationBonus
  ) internal pure returns (uint256) {
    if (healthFactor < healthFactorBonusThreshold) {
      return liquidationBonus;
    }
    uint256 minLiquidationBonus = liquidationBonus.percentMul(liquidationBonusFactor);

    if (healthFactor >= healthFactorLiquidationThreshold) {
      return minLiquidationBonus;
    }

    return
      minLiquidationBonus +
      ((liquidationBonus - minLiquidationBonus) *
        (healthFactorLiquidationThreshold - healthFactor)) /
      (healthFactorLiquidationThreshold - healthFactorBonusThreshold);
  }

  /// fuzz - when healthFactorBonusThreshold <= healthFactor <= healthFactorLiquidationThreshold
  function testCalculateVariableLiquidationBonus_intermediateValue(
    uint256 healthFactor,
    uint256 healthFactorBonusThreshold,
    uint256 liquidationBonus,
    uint256 liquidationBonusFactor
  ) public {
    liquidationBonus = bound(liquidationBonus, 0, MAX_LIQUIDATION_BONUS); // BPS
    liquidationBonusFactor = bound(liquidationBonusFactor, 0, MAX_LIQUIDATION_BONUS_FACTOR); // BPS

    uint256 healthFactorLiquidationThreshold = WadRayMath.WAD;

    healthFactorBonusThreshold = bound(
      healthFactorBonusThreshold,
      1,
      healthFactorLiquidationThreshold
    );
    healthFactor = bound(
      healthFactor,
      healthFactorBonusThreshold,
      healthFactorLiquidationThreshold
    );

    DataTypes.VariableLiquidationBonusConfig memory config = DataTypes
      .VariableLiquidationBonusConfig({
        healthFactorBonusThreshold: healthFactorBonusThreshold,
        liquidationBonusFactor: liquidationBonusFactor
      });

    uint256 result = LiquidationLogic.calculateVariableLiquidationBonus(
      healthFactor,
      config,
      healthFactorLiquidationThreshold,
      liquidationBonus
    );

    assertEq(
      result,
      _calculateVariableLiquidationBonus(
        healthFactor,
        config.healthFactorBonusThreshold,
        liquidationBonusFactor,
        healthFactorLiquidationThreshold,
        liquidationBonus
      ),
      'should be linear interpolation'
    );
  }
}
