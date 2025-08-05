// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicVariableLiquidationBonusTest is LiquidationLogicBaseTest {
  using PercentageMath for uint256;

  DataTypes.LiquidationConfig internal _config;

  /// fuzz - if liquidation bonus is set to 0%, liq bonus should always be 0% regardless of the health factor
  function testCalculate_fuzz_zero_liquidationBonus(
    uint256 healthFactor,
    uint256 healthFactorForMaxBonus,
    uint256 liquidationBonus,
    uint256 liquidationBonusFactor
  ) public {
    liquidationBonus = MIN_LIQUIDATION_BONUS;
    liquidationBonusFactor = bound(liquidationBonusFactor, 0, MAX_LIQUIDATION_BONUS_FACTOR);
    healthFactorForMaxBonus = bound(
      healthFactorForMaxBonus,
      1,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );
    healthFactor = bound(healthFactor, 0, UINT256_MAX);

    _config = DataTypes.LiquidationConfig({
      closeFactor: WadRayMath.WAD,
      healthFactorForMaxBonus: healthFactorForMaxBonus,
      liquidationBonusFactor: liquidationBonusFactor
    });

    uint256 result = LiquidationLogic.calculateVariableLiquidationBonus(
      _config,
      healthFactor,
      liquidationBonus,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );

    assertEq(result, liquidationBonus, 'should be liquidationBonus');
  }

  /// when hf < healthFactorForMaxBonus, return liquidationBonus
  function testCalculate_lt_bonusThreshold() public {
    uint256 healthFactorForMaxBonus = 0.9e18;
    uint256 healthFactor = healthFactorForMaxBonus - 1;
    uint256 liquidationBonus = 120_00; // 20% bonus
    uint256 liquidationBonusFactor = 40_00; // 40%

    testCalculate_fuzz_lte_bonusThreshold(
      DataTypes.LiquidationConfig({
        closeFactor: 0,
        healthFactorForMaxBonus: healthFactorForMaxBonus,
        liquidationBonusFactor: liquidationBonusFactor
      }),
      healthFactor,
      liquidationBonus
    );
  }

  /// when hf == healthFactorForMaxBonus, return liquidationBonus
  function testCalculate_eq_bonusThreshold() public {
    uint256 healthFactorForMaxBonus = 0.9e18;
    uint256 healthFactor = healthFactorForMaxBonus;
    uint256 liquidationBonus = 120_00; // 20% bonus
    uint256 liquidationBonusFactor = 40_00; // 40%

    testCalculate_fuzz_lte_bonusThreshold(
      DataTypes.LiquidationConfig({
        closeFactor: 0,
        healthFactorForMaxBonus: healthFactorForMaxBonus,
        liquidationBonusFactor: liquidationBonusFactor
      }),
      healthFactor,
      liquidationBonus
    );
  }

  /// fuzz - when hf <= healthFactorForMaxBonus, return liquidationBonus
  function testCalculate_fuzz_lte_bonusThreshold(
    DataTypes.LiquidationConfig memory config,
    uint256 healthFactor,
    uint256 liquidationBonus
  ) public {
    liquidationBonus = bound(liquidationBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS); // BPS
    config.healthFactorForMaxBonus = bound(
      config.healthFactorForMaxBonus,
      0,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1
    );

    healthFactor = bound(healthFactor, 0, config.healthFactorForMaxBonus);
    config.liquidationBonusFactor = bound(
      config.liquidationBonusFactor,
      0,
      MAX_LIQUIDATION_BONUS_FACTOR
    ); // BPS

    _config = config;

    uint256 result = LiquidationLogic.calculateVariableLiquidationBonus(
      _config,
      healthFactor,
      liquidationBonus,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );

    assertEq(result, liquidationBonus, 'should be liquidationBonus');
  }

  /// when HF == HEALTH_FACTOR_LIQUIDATION_THRESHOLD, return minLiquidationBonus
  function testCalculate_eq_liquidationThreshold() public {
    uint256 healthFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
    uint256 liquidationBonus = 120_00; // 20%
    uint256 liquidationBonusFactor = 40_00; // 40%
    uint256 healthFactorForMaxBonus = 0.9e18;

    testCalculate_fuzz_gte_liquidationThreshold(
      healthFactor,
      healthFactorForMaxBonus,
      liquidationBonus,
      liquidationBonusFactor
    );
  }

  /// when HF > HEALTH_FACTOR_LIQUIDATION_THRESHOLD, return minLiquidationBonus
  function testCalculate_gt_liquidationThreshold() public {
    uint256 healthFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD + 1;
    uint256 liquidationBonus = 120_00; // 20%
    uint256 liquidationBonusFactor = 40_00; // 40%
    uint256 healthFactorForMaxBonus = 0.9e18;

    testCalculate_fuzz_gte_liquidationThreshold(
      healthFactor,
      healthFactorForMaxBonus,
      liquidationBonus,
      liquidationBonusFactor
    );
  }

  /// fuzz - when >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD, return minLiquidationBonus
  function testCalculate_fuzz_gte_liquidationThreshold(
    uint256 healthFactor,
    uint256 healthFactorForMaxBonus,
    uint256 liquidationBonus,
    uint256 liquidationBonusFactor
  ) public {
    liquidationBonus = bound(liquidationBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS); // BPS
    liquidationBonusFactor = bound(liquidationBonusFactor, 1, MAX_LIQUIDATION_BONUS_FACTOR); // BPS
    healthFactorForMaxBonus = bound(
      healthFactorForMaxBonus,
      1,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );
    healthFactor = bound(healthFactor, HEALTH_FACTOR_LIQUIDATION_THRESHOLD + 1, UINT256_MAX);

    _config = DataTypes.LiquidationConfig({
      closeFactor: WadRayMath.WAD,
      healthFactorForMaxBonus: healthFactorForMaxBonus,
      liquidationBonusFactor: liquidationBonusFactor
    });

    uint256 result = LiquidationLogic.calculateVariableLiquidationBonus(
      _config,
      healthFactor,
      liquidationBonus,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );

    assertEq(
      result,
      _calcMinLiqBonus(liquidationBonus, liquidationBonusFactor),
      'should be minLiquidationBonus'
    );
  }

  /// when healthFactorForMaxBonus <= healthFactor <= healthFactorLiquidationThreshold
  function testCalculate_intermediateValue() public {
    uint256 liquidationBonus = 120_00; // 20% bonus
    uint256 liquidationBonusFactor = 40_00; // 40%
    uint256 healthFactorForMaxBonus = 0.9e18;
    uint256 healthFactor = (HEALTH_FACTOR_LIQUIDATION_THRESHOLD + healthFactorForMaxBonus) / 2; // hf is halfway through

    testCalculate_fuzz_intermediateValue(
      healthFactor,
      healthFactorForMaxBonus,
      liquidationBonus,
      liquidationBonusFactor
    );
  }

  /// fuzz - when healthFactorForMaxBonus <= healthFactor <= healthFactorLiquidationThreshold
  function testCalculate_fuzz_intermediateValue(
    uint256 healthFactor,
    uint256 healthFactorForMaxBonus,
    uint256 liquidationBonus,
    uint256 liquidationBonusFactor
  ) public {
    liquidationBonus = bound(liquidationBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS); // BPS
    liquidationBonusFactor = bound(liquidationBonusFactor, 1, MAX_LIQUIDATION_BONUS_FACTOR); // BPS

    healthFactorForMaxBonus = bound(
      healthFactorForMaxBonus,
      1,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );
    healthFactor = bound(
      healthFactor,
      healthFactorForMaxBonus,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );

    _config = DataTypes.LiquidationConfig({
      closeFactor: 0,
      healthFactorForMaxBonus: healthFactorForMaxBonus,
      liquidationBonusFactor: liquidationBonusFactor
    });

    uint256 result = LiquidationLogic.calculateVariableLiquidationBonus(
      _config,
      healthFactor,
      liquidationBonus,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );

    assertEq(
      result,
      _calcExpectedLiqBonus(
        healthFactor,
        _config.healthFactorForMaxBonus,
        liquidationBonusFactor,
        liquidationBonus,
        HEALTH_FACTOR_LIQUIDATION_THRESHOLD
      ),
      'should be linear interpolation'
    );
    assertGe(
      result,
      _calcMinLiqBonus(liquidationBonus, liquidationBonusFactor),
      'should be >= min liquidationBonus'
    );
    assertLe(result, liquidationBonus, 'should be =< max liquidationBonus');
  }

  /// fuzz - when liquidationBonusFactor is 0, the liquidation bonus should be the default value
  function testCalculate_fuzz_zero_liquidationBonusFactor(
    uint256 healthFactor,
    uint256 closeFactor,
    uint256 healthFactorForMaxBonus,
    uint256 liquidationBonus
  ) public {
    healthFactorForMaxBonus = bound(
      healthFactorForMaxBonus,
      1,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1
    );
    healthFactor = bound(
      healthFactor,
      healthFactorForMaxBonus + 1,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );
    closeFactor = bound(closeFactor, HEALTH_FACTOR_LIQUIDATION_THRESHOLD, MAX_CLOSE_FACTOR); // WAD
    liquidationBonus = bound(liquidationBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS); // BPS
    uint256 liquidationBonusFactor = 0;

    uint256 result = _getVariableLiquidationBonus(
      healthFactor,
      closeFactor,
      healthFactorForMaxBonus,
      liquidationBonus,
      liquidationBonusFactor
    );

    assertEq(result, liquidationBonus, 'should be default liquidationBonus');
  }

  /// fuzz - when healthFactorForMaxBonus is 0, the liquidation bonus should be the default value
  function testCalculate_fuzz_zero_healthFactorForMaxBonus(
    uint256 healthFactor,
    uint256 closeFactor,
    uint256 liquidationBonusFactor,
    uint256 liquidationBonus
  ) public {
    uint256 healthFactorForMaxBonus = 0;
    healthFactor = bound(
      healthFactor,
      healthFactorForMaxBonus + 1,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );
    liquidationBonusFactor = bound(liquidationBonusFactor, 1, 100_00); // BPS
    closeFactor = bound(closeFactor, HEALTH_FACTOR_LIQUIDATION_THRESHOLD, MAX_CLOSE_FACTOR); // WAD
    liquidationBonus = bound(liquidationBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS); // BPS

    uint256 result = _getVariableLiquidationBonus(
      healthFactor,
      closeFactor,
      healthFactorForMaxBonus,
      liquidationBonus,
      liquidationBonusFactor
    );

    assertEq(result, liquidationBonus, 'should be default liquidationBonus');
  }

  /// fuzz - when health factor is lte healthFactorForMaxBonus, the liquidation bonus should be the default value
  function testCalculate_fuzz_hf_lte_healthFactorForMaxBonus(
    uint256 healthFactor,
    uint256 closeFactor,
    uint256 healthFactorForMaxBonus,
    uint256 liquidationBonusFactor,
    uint256 liquidationBonus
  ) public {
    healthFactorForMaxBonus = bound(
      healthFactorForMaxBonus,
      1,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );
    healthFactor = bound(healthFactor, 0, healthFactorForMaxBonus);
    liquidationBonusFactor = bound(liquidationBonusFactor, 1, 100_00); // BPS
    closeFactor = bound(closeFactor, HEALTH_FACTOR_LIQUIDATION_THRESHOLD, MAX_CLOSE_FACTOR); // WAD
    liquidationBonus = bound(liquidationBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS); // BPS

    uint256 result = _getVariableLiquidationBonus(
      healthFactor,
      closeFactor,
      healthFactorForMaxBonus,
      liquidationBonus,
      liquidationBonusFactor
    );

    assertEq(result, liquidationBonus, 'should be default liquidationBonus');
  }

  /// helper to get the liquidation bonus result from LiquidationLogic lib
  /// @return the calculated liquidation bonus
  function _getVariableLiquidationBonus(
    uint256 healthFactor,
    uint256 closeFactor,
    uint256 healthFactorForMaxBonus,
    uint256 liquidationBonus,
    uint256 liquidationBonusFactor
  ) internal returns (uint256) {
    _config = DataTypes.LiquidationConfig({
      closeFactor: closeFactor,
      healthFactorForMaxBonus: healthFactorForMaxBonus,
      liquidationBonusFactor: liquidationBonusFactor
    });

    return
      LiquidationLogic.calculateVariableLiquidationBonus(
        _config,
        healthFactor,
        liquidationBonus,
        HEALTH_FACTOR_LIQUIDATION_THRESHOLD
      );
  }

  /// helper to calc the liquidation bonus based on the health factor, health factor bonus threshold,
  /// liquidation bonus factor, liquidation bonus, and health factor liquidation threshold
  function _calcExpectedLiqBonus(
    uint256 healthFactor,
    uint256 healthFactorForMaxBonus,
    uint256 liquidationBonusFactor,
    uint256 liquidationBonus,
    uint256 healthFactorLiquidationThreshold
  ) internal pure returns (uint256) {
    if (healthFactor <= healthFactorForMaxBonus) {
      return liquidationBonus;
    }
    uint256 minLiquidationBonus = _calcMinLiqBonus(liquidationBonus, liquidationBonusFactor);
    if (healthFactor >= healthFactorLiquidationThreshold) {
      return minLiquidationBonus;
    }
    return
      minLiquidationBonus +
      ((liquidationBonus - minLiquidationBonus) *
        (healthFactorLiquidationThreshold - healthFactor)) /
      (healthFactorLiquidationThreshold - healthFactorForMaxBonus);
  }

  /// calc the minimum liquidation bonus based on the liquidation bonus and the liquidation bonus factor
  function _calcMinLiqBonus(
    uint256 liquidationBonus,
    uint256 liquidationBonusFactor
  ) internal pure returns (uint256) {
    return
      (liquidationBonus - PercentageMath.PERCENTAGE_FACTOR).percentMulDown(liquidationBonusFactor) +
      PercentageMath.PERCENTAGE_FACTOR;
  }
}
