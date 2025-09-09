// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';

contract SpokeGettersTest is SpokeBase {
  using LiquidationLogic for DataTypes.LiquidationConfig;
  using SafeCast for uint256;

  DataTypes.LiquidationConfig internal _config;

  function test_getLiquidationBonus_notConfigured() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 healthFactor = WadRayMath.WAD;
    test_getLiquidationBonus_fuzz_notConfigured(reserveId, healthFactor);
  }

  function test_getLiquidationBonus_fuzz_notConfigured(
    uint256 reserveId,
    uint256 healthFactor
  ) public {
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    healthFactor = bound(healthFactor, 0, HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
    uint256 liqBonus = spoke1.getLiquidationBonus(reserveId, bob, healthFactor);

    _config = spoke1.getLiquidationConfig();
    assertEq(
      _config,
      DataTypes.LiquidationConfig({
        targetHealthFactor: WadRayMath.WAD.toUint128(),
        healthFactorForMaxBonus: 0,
        liquidationBonusFactor: 0
      })
    );

    assertEq(
      liqBonus,
      LiquidationLogic.calculateLiquidationBonus({
        healthFactorForMaxBonus: 0,
        liquidationBonusFactor: 0,
        healthFactor: healthFactor,
        maxLiquidationBonus: spoke1.getDynamicReserveConfig(reserveId).maxLiquidationBonus
      }),
      'calc should match'
    );
  }

  function test_getLiquidationBonus_configured() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 healthFactor = WadRayMath.WAD;
    test_getLiquidationBonus_fuzz_configured(reserveId, healthFactor, 40_00, 0.9e18);
  }

  function test_getLiquidationBonus_fuzz_configured(
    uint256 reserveId,
    uint256 healthFactor,
    uint16 liquidationBonusFactor,
    uint64 healthFactorForMaxBonus
  ) public {
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    healthFactor = bound(healthFactor, 0, HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
    liquidationBonusFactor = bound(liquidationBonusFactor, 0, PercentageMath.PERCENTAGE_FACTOR)
      .toUint16();
    healthFactorForMaxBonus = bound(
      healthFactorForMaxBonus,
      0,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1
    ).toUint64();

    DataTypes.LiquidationConfig memory config = DataTypes.LiquidationConfig({
      targetHealthFactor: WadRayMath.WAD.toUint128(),
      healthFactorForMaxBonus: healthFactorForMaxBonus,
      liquidationBonusFactor: liquidationBonusFactor
    });
    vm.prank(SPOKE_ADMIN);
    spoke1.updateLiquidationConfig(config);
    _config = spoke1.getLiquidationConfig();

    uint256 liqBonus = spoke1.getLiquidationBonus(reserveId, bob, healthFactor);

    assertEq(
      liqBonus,
      LiquidationLogic.calculateLiquidationBonus({
        healthFactorForMaxBonus: healthFactorForMaxBonus,
        liquidationBonusFactor: liquidationBonusFactor,
        healthFactor: healthFactor,
        maxLiquidationBonus: spoke1.getDynamicReserveConfig(reserveId).maxLiquidationBonus
      }),
      'calc should match'
    );
  }
}
