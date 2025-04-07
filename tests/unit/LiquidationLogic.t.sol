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

  DataTypes.VariableLiquidationBonusConfig internal _config;

  /// when hf < healthFactorBonusThreshold, return liquidationBonus
  function testCalculateVariableLiquidationBonus_lt_bonusThreshold() public {
    uint256 healthFactorBonusThreshold = 0.9e18;
    uint256 healthFactor = healthFactorBonusThreshold - 1;
    uint256 liquidationBonus = 20_00; // 20%
    uint256 liquidationBonusFactor = 40_00; // 40%

    testCalculateVariableLiquidationBonus_fuzz_lte_bonusThreshold(
      healthFactor,
      healthFactorBonusThreshold,
      liquidationBonus,
      liquidationBonusFactor
    );
  }

  /// when hf == healthFactorBonusThreshold, return liquidationBonus
  function testCalculateVariableLiquidationBonus_eq_bonusThreshold() public {
    uint256 healthFactorBonusThreshold = 0.9e18;
    uint256 healthFactor = healthFactorBonusThreshold;
    uint256 liquidationBonus = 20_00; // 20%
    uint256 liquidationBonusFactor = 40_00; // 40%

    testCalculateVariableLiquidationBonus_fuzz_lte_bonusThreshold(
      healthFactor,
      healthFactorBonusThreshold,
      liquidationBonus,
      liquidationBonusFactor
    );
  }

  /// fuzz - when hf <= healthFactorBonusThreshold, return liquidationBonus
  function testCalculateVariableLiquidationBonus_fuzz_lte_bonusThreshold(
    uint256 healthFactor,
    uint256 healthFactorBonusThreshold,
    uint256 liquidationBonus,
    uint256 liquidationBonusFactor
  ) public {
    liquidationBonus = bound(liquidationBonus, 0, MAX_LIQUIDATION_BONUS); // BPS
    liquidationBonusFactor = bound(liquidationBonusFactor, 0, MAX_LIQUIDATION_BONUS_FACTOR); // BPS

    healthFactorBonusThreshold = bound(
      healthFactorBonusThreshold,
      0,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1
    );
    healthFactor = bound(healthFactor, 0, healthFactorBonusThreshold);

    _config = DataTypes.VariableLiquidationBonusConfig({
      healthFactorBonusThreshold: healthFactorBonusThreshold,
      liquidationBonusFactor: liquidationBonusFactor
    });

    uint256 result = LiquidationLogic.calculateVariableLiquidationBonus(
      _config,
      healthFactor,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      liquidationBonus
    );

    assertEq(result, liquidationBonus, 'should be liquidationBonus');
  }

  /// when == HEALTH_FACTOR_LIQUIDATION_THRESHOLD, return minLiquidationBonus
  function testCalculateVariableLiquidationBonus_eq_liquidationThreshold() public {
    uint256 healthFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
    uint256 liquidationBonus = 20_00; // 20%
    uint256 liquidationBonusFactor = 40_00; // 40%
    uint256 healthFactorBonusThreshold = 0.9e18;

    testCalculateVariableLiquidationBonus_fuzz_gte_liquidationThreshold(
      healthFactor,
      healthFactorBonusThreshold,
      liquidationBonus,
      liquidationBonusFactor
    );
  }

  /// when > HEALTH_FACTOR_LIQUIDATION_THRESHOLD, return minLiquidationBonus
  function testCalculateVariableLiquidationBonus_gt_liquidationThreshold() public {
    uint256 healthFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD + 1;
    uint256 liquidationBonus = 20_00; // 20%
    uint256 liquidationBonusFactor = 40_00; // 40%
    uint256 healthFactorBonusThreshold = 0.9e18;

    testCalculateVariableLiquidationBonus_fuzz_gte_liquidationThreshold(
      healthFactor,
      healthFactorBonusThreshold,
      liquidationBonus,
      liquidationBonusFactor
    );
  }

  /// fuzz - when >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD, return minLiquidationBonus
  function testCalculateVariableLiquidationBonus_fuzz_gte_liquidationThreshold(
    uint256 healthFactor,
    uint256 healthFactorBonusThreshold,
    uint256 liquidationBonus,
    uint256 liquidationBonusFactor
  ) public {
    liquidationBonus = bound(liquidationBonus, 0, MAX_LIQUIDATION_BONUS); // BPS
    liquidationBonusFactor = bound(liquidationBonusFactor, 0, MAX_LIQUIDATION_BONUS_FACTOR); // BPS

    healthFactorBonusThreshold = bound(
      healthFactorBonusThreshold,
      1,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );
    healthFactor = bound(healthFactor, HEALTH_FACTOR_LIQUIDATION_THRESHOLD + 1, type(uint256).max);

    _config = DataTypes.VariableLiquidationBonusConfig({
      healthFactorBonusThreshold: healthFactorBonusThreshold,
      liquidationBonusFactor: liquidationBonusFactor
    });

    uint256 result = LiquidationLogic.calculateVariableLiquidationBonus(
      _config,
      healthFactor,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      liquidationBonus
    );

    assertEq(
      result,
      liquidationBonus.percentMul(liquidationBonusFactor),
      'should be minLiquidationBonus'
    );
  }

  /// when healthFactorBonusThreshold <= healthFactor <= healthFactorLiquidationThreshold
  function testCalculateVariableLiquidationBonus_intermediateValue() public {
    uint256 healthFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1;
    uint256 liquidationBonus = 20_00; // 20%
    uint256 liquidationBonusFactor = 40_00; // 40%
    uint256 healthFactorBonusThreshold = 0.9e18;

    testCalculateVariableLiquidationBonus_fuzz_intermediateValue(
      healthFactor,
      healthFactorBonusThreshold,
      liquidationBonus,
      liquidationBonusFactor
    );
  }

  /// fuzz - when healthFactorBonusThreshold <= healthFactor <= healthFactorLiquidationThreshold
  function testCalculateVariableLiquidationBonus_fuzz_intermediateValue(
    uint256 healthFactor,
    uint256 healthFactorBonusThreshold,
    uint256 liquidationBonus,
    uint256 liquidationBonusFactor
  ) public {
    liquidationBonus = bound(liquidationBonus, 0, MAX_LIQUIDATION_BONUS); // BPS
    liquidationBonusFactor = bound(liquidationBonusFactor, 0, MAX_LIQUIDATION_BONUS_FACTOR); // BPS

    healthFactorBonusThreshold = bound(
      healthFactorBonusThreshold,
      1,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );
    healthFactor = bound(
      healthFactor,
      healthFactorBonusThreshold,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );

    _config = DataTypes.VariableLiquidationBonusConfig({
      healthFactorBonusThreshold: healthFactorBonusThreshold,
      liquidationBonusFactor: liquidationBonusFactor
    });

    uint256 result = LiquidationLogic.calculateVariableLiquidationBonus(
      _config,
      healthFactor,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      liquidationBonus
    );

    assertEq(
      result,
      _calculateVariableLiquidationBonus(
        healthFactor,
        _config.healthFactorBonusThreshold,
        liquidationBonusFactor,
        HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
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
    if (healthFactor <= healthFactorBonusThreshold) {
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
}
