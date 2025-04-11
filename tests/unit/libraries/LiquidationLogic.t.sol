// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {Base} from 'tests/Base.t.sol';

contract LiquidationLogicTest is Base {
  using PercentageMath for uint256;

  DataTypes.LiquidationConfig internal _config;

  /// when hf < healthFactorBonusThreshold, return liquidationBonus
  function testCalculate_lt_bonusThreshold() public {
    uint256 healthFactorBonusThreshold = 0.9e18;
    uint256 healthFactor = healthFactorBonusThreshold - 1;
    uint256 liquidationBonus = 120_00; // 20% bonus
    uint256 liquidationBonusFactor = 40_00; // 40%

    testCalculate_fuzz_lte_bonusThreshold(
      DataTypes.LiquidationConfig({
        closeFactor: 0,
        healthFactorBonusThreshold: healthFactorBonusThreshold,
        liquidationBonusFactor: liquidationBonusFactor
      }),
      healthFactor,
      liquidationBonus
    );
  }

  /// when hf == healthFactorBonusThreshold, return liquidationBonus
  function testCalculate_eq_bonusThreshold() public {
    uint256 healthFactorBonusThreshold = 0.9e18;
    uint256 healthFactor = healthFactorBonusThreshold;
    uint256 liquidationBonus = 120_00; // 20% bonus
    uint256 liquidationBonusFactor = 40_00; // 40%

    testCalculate_fuzz_lte_bonusThreshold(
      DataTypes.LiquidationConfig({
        closeFactor: 0,
        healthFactorBonusThreshold: healthFactorBonusThreshold,
        liquidationBonusFactor: liquidationBonusFactor
      }),
      healthFactor,
      liquidationBonus
    );
  }

  /// fuzz - when hf <= healthFactorBonusThreshold, return liquidationBonus
  function testCalculate_fuzz_lte_bonusThreshold(
    DataTypes.LiquidationConfig memory config,
    uint256 healthFactor,
    uint256 liquidationBonus
  ) public {
    liquidationBonus = bound(liquidationBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS); // BPS
    config.healthFactorBonusThreshold = bound(
      config.healthFactorBonusThreshold,
      0,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1
    );

    healthFactor = bound(healthFactor, 0, config.healthFactorBonusThreshold);
    config.liquidationBonusFactor = bound(
      config.liquidationBonusFactor,
      0,
      MAX_LIQUIDATION_BONUS_FACTOR
    ); // BPS

    _config = config;

    uint256 result = LiquidationLogic.calculate(
      _config,
      healthFactor,
      liquidationBonus,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );

    assertEq(result, liquidationBonus, 'should be liquidationBonus');
  }

  /// when == HEALTH_FACTOR_LIQUIDATION_THRESHOLD, return minLiquidationBonus
  function testCalculate_eq_liquidationThreshold() public {
    uint256 healthFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
    uint256 liquidationBonus = 120_00; // 20%
    uint256 liquidationBonusFactor = 40_00; // 40%
    uint256 healthFactorBonusThreshold = 0.9e18;

    testCalculate_fuzz_gte_liquidationThreshold(
      healthFactor,
      healthFactorBonusThreshold,
      liquidationBonus,
      liquidationBonusFactor
    );
  }

  /// when > HEALTH_FACTOR_LIQUIDATION_THRESHOLD, return minLiquidationBonus
  function testCalculate_gt_liquidationThreshold() public {
    uint256 healthFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD + 1;
    uint256 liquidationBonus = 120_00; // 20%
    uint256 liquidationBonusFactor = 40_00; // 40%
    uint256 healthFactorBonusThreshold = 0.9e18;

    testCalculate_fuzz_gte_liquidationThreshold(
      healthFactor,
      healthFactorBonusThreshold,
      liquidationBonus,
      liquidationBonusFactor
    );
  }

  /// fuzz - when >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD, return minLiquidationBonus
  function testCalculate_fuzz_gte_liquidationThreshold(
    uint256 healthFactor,
    uint256 healthFactorBonusThreshold,
    uint256 liquidationBonus,
    uint256 liquidationBonusFactor
  ) public {
    liquidationBonus = bound(liquidationBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS); // BPS
    liquidationBonusFactor = bound(liquidationBonusFactor, 0, MAX_LIQUIDATION_BONUS_FACTOR); // BPS
    healthFactorBonusThreshold = bound(
      healthFactorBonusThreshold,
      1,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );
    healthFactor = bound(healthFactor, HEALTH_FACTOR_LIQUIDATION_THRESHOLD + 1, type(uint256).max);

    _config = DataTypes.LiquidationConfig({
      closeFactor: WadRayMath.WAD,
      healthFactorBonusThreshold: healthFactorBonusThreshold,
      liquidationBonusFactor: liquidationBonusFactor
    });

    uint256 result = LiquidationLogic.calculate(
      _config,
      healthFactor,
      liquidationBonus,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );

    assertEq(
      result,
      _calculateMinLiqBonus(liquidationBonus, liquidationBonusFactor),
      'should be minLiquidationBonus'
    );
  }

  /// when healthFactorBonusThreshold <= healthFactor <= healthFactorLiquidationThreshold
  function testCalculate_intermediateValue() public {
    uint256 liquidationBonus = 120_00; // 20% bonus
    uint256 liquidationBonusFactor = 40_00; // 40%
    uint256 healthFactorBonusThreshold = 0.9e18;
    uint256 healthFactor = (HEALTH_FACTOR_LIQUIDATION_THRESHOLD + healthFactorBonusThreshold) / 2; // hf is halfway through

    testCalculate_fuzz_intermediateValue(
      healthFactor,
      healthFactorBonusThreshold,
      liquidationBonus,
      liquidationBonusFactor
    );
  }

  /// fuzz - when healthFactorBonusThreshold <= healthFactor <= healthFactorLiquidationThreshold
  function testCalculate_fuzz_intermediateValue(
    uint256 healthFactor,
    uint256 healthFactorBonusThreshold,
    uint256 liquidationBonus,
    uint256 liquidationBonusFactor
  ) public {
    liquidationBonus = bound(liquidationBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS); // BPS
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

    _config = DataTypes.LiquidationConfig({
      closeFactor: 0,
      healthFactorBonusThreshold: healthFactorBonusThreshold,
      liquidationBonusFactor: liquidationBonusFactor
    });

    uint256 result = LiquidationLogic.calculate(
      _config,
      healthFactor,
      liquidationBonus,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );

    assertEq(
      result,
      _calculate(
        healthFactor,
        _config.healthFactorBonusThreshold,
        liquidationBonusFactor,
        liquidationBonus,
        HEALTH_FACTOR_LIQUIDATION_THRESHOLD
      ),
      'should be linear interpolation'
    );
    assertGe(
      result,
      _calculateMinLiqBonus(liquidationBonus, liquidationBonusFactor),
      'should be >= min liquidationBonus'
    );
    assertLe(result, liquidationBonus, 'should be =< max liquidationBonus');
  }

  function _calculate(
    uint256 healthFactor,
    uint256 healthFactorBonusThreshold,
    uint256 liquidationBonusFactor,
    uint256 liquidationBonus,
    uint256 healthFactorLiquidationThreshold
  ) internal pure returns (uint256) {
    if (healthFactor <= healthFactorBonusThreshold) {
      return liquidationBonus;
    }
    uint256 minLiquidationBonus = _calculateMinLiqBonus(liquidationBonus, liquidationBonusFactor);
    if (healthFactor >= healthFactorLiquidationThreshold) {
      return minLiquidationBonus;
    }
    return
      minLiquidationBonus +
      ((liquidationBonus - minLiquidationBonus) *
        (healthFactorLiquidationThreshold - healthFactor)) /
      (healthFactorLiquidationThreshold - healthFactorBonusThreshold);
  }

  function _calculateMinLiqBonus(
    uint256 liquidationBonus,
    uint256 liquidationBonusFactor
  ) internal pure returns (uint256) {
    return
      (liquidationBonus - PercentageMath.PERCENTAGE_FACTOR).percentMul(liquidationBonusFactor) +
      PercentageMath.PERCENTAGE_FACTOR;
  }
}
