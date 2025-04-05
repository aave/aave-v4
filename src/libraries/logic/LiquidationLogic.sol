// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';

library LiquidationLogic {
  using PercentageMath for uint256;

  function calculateVariableLiquidationBonus(
    uint256 healthFactor,
    DataTypes.VariableLiquidationBonusConfig memory config,
    uint256 healthFactorLiquidationThreshold,
    uint256 liquidationBonus
  ) internal pure returns (uint256) {
    if (healthFactor < config.healthFactorBonusThreshold) {
      return liquidationBonus;
    }
    uint256 minLiquidationBonus = liquidationBonus.percentMul(config.liquidationBonusFactor);

    if (healthFactor >= healthFactorLiquidationThreshold) {
      return minLiquidationBonus;
    }

    return
      minLiquidationBonus +
      ((liquidationBonus - minLiquidationBonus) *
        (healthFactorLiquidationThreshold - healthFactor)) /
      (healthFactorLiquidationThreshold - config.healthFactorBonusThreshold);
  }
}
