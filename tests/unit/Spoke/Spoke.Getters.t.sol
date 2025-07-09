// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';

contract SpokeGettersTest is SpokeBase {
  using LiquidationLogic for DataTypes.LiquidationConfig;

  DataTypes.LiquidationConfig internal _config;

  function test_getVariableLiquidationBonus_notConfigured() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 healthFactor = WadRayMath.WAD;
    test_getVariableLiquidationBonus_fuzz_notConfigured(reserveId, healthFactor);
  }

  function test_getVariableLiquidationBonus_fuzz_notConfigured(
    uint256 reserveId,
    uint256 healthFactor
  ) public {
    reserveId = bound(reserveId, 0, spoke1.reserveCount() - 1);
    healthFactor = bound(healthFactor, 0, HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
    uint256 liqBonus = spoke1.getVariableLiquidationBonus(reserveId, bob, healthFactor);

    _config = spoke1.getLiquidationConfig();

    assertEq(
      liqBonus,
      LiquidationLogic.calculateVariableLiquidationBonus(
        _config,
        healthFactor,
        spoke1.getDynamicReserveConfig(reserveId).liquidationBonus,
        HEALTH_FACTOR_LIQUIDATION_THRESHOLD
      ),
      'calc should match'
    );
  }

  function test_getVariableLiquidationBonus_configured() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 healthFactor = WadRayMath.WAD;
    test_getVariableLiquidationBonus_fuzz_configured(reserveId, healthFactor, 40_00, 0.9e18);
  }

  function test_getVariableLiquidationBonus_fuzz_configured(
    uint256 reserveId,
    uint256 healthFactor,
    uint256 liquidationBonusFactor,
    uint256 healthFactorForMaxBonus
  ) public {
    reserveId = bound(reserveId, 0, spoke1.reserveCount() - 1);
    healthFactor = bound(healthFactor, 0, HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
    liquidationBonusFactor = bound(liquidationBonusFactor, 0, PercentageMath.PERCENTAGE_FACTOR);
    healthFactorForMaxBonus = bound(
      healthFactorForMaxBonus,
      0,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1
    );

    DataTypes.LiquidationConfig memory config = DataTypes.LiquidationConfig({
      closeFactor: WadRayMath.WAD,
      healthFactorForMaxBonus: healthFactorForMaxBonus,
      liquidationBonusFactor: liquidationBonusFactor
    });
    vm.prank(SPOKE_ADMIN);
    spoke1.updateLiquidationConfig(config);
    _config = spoke1.getLiquidationConfig();

    uint256 liqBonus = spoke1.getVariableLiquidationBonus(reserveId, bob, healthFactor);

    assertEq(
      liqBonus,
      LiquidationLogic.calculateVariableLiquidationBonus(
        _config,
        healthFactor,
        spoke1.getDynamicReserveConfig(reserveId).liquidationBonus,
        HEALTH_FACTOR_LIQUIDATION_THRESHOLD
      ),
      'calc should match'
    );
  }
}
