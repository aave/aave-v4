// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {LiquidationLogic} from '../../src/spoke/libraries/LiquidationLogic.sol';

contract LiquidationLogicHarness {
  function calculateLiquidationAmounts(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) external view returns (LiquidationLogic.LiquidationAmounts memory) {
    return LiquidationLogic._calculateLiquidationAmounts(params);
  }

  function calculateLiquidationBonus(
    uint256 healthFactorForMaxBonus,
    uint256 liquidationBonusFactor,
    uint256 healthFactor,
    uint256 maxLiquidationBonus
  ) external pure returns (uint256) {
    return
      LiquidationLogic.calculateLiquidationBonus(
        healthFactorForMaxBonus,
        liquidationBonusFactor,
        healthFactor,
        maxLiquidationBonus
      );
  }

  function calculateDebtToLiquidate(
    LiquidationLogic.CalculateDebtToLiquidateParams memory params
  ) external pure returns (uint256, uint256) {
    return LiquidationLogic._calculateDebtToLiquidate(params);
  }
}
