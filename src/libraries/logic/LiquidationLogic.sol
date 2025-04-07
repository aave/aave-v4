// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';

library LiquidationLogic {
  using PercentageMath for uint256;

  function calculateVariableLiquidationBonus(
    DataTypes.VariableLiquidationBonusConfig storage config,
    uint256 healthFactor,
    uint256 healthFactorLiquidationThreshold,
    uint256 liquidationBonus
  ) internal view returns (uint256) {
    // if HF <= healthFactorBonusThreshold, liquidation bonus is max
    if (healthFactor <= config.healthFactorBonusThreshold) {
      return liquidationBonus;
    }
    uint256 minLiquidationBonus = liquidationBonus.percentMul(config.liquidationBonusFactor);

    // if HF >= healthFactorLiquidationThreshold, liquidation bonus is min
    if (healthFactor >= healthFactorLiquidationThreshold) {
      return minLiquidationBonus;
    }

    // otherwise, linearly interpolate between min and max
    return
      minLiquidationBonus +
      ((liquidationBonus - minLiquidationBonus) *
        (healthFactorLiquidationThreshold - healthFactor)) /
      (healthFactorLiquidationThreshold - config.healthFactorBonusThreshold);
  }
}
