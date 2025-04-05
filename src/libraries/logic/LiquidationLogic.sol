// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {PercentageMath} from 'src/contracts/PercentageMath.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';

library LiquidationLogic {
  using PercentageMath for uint256;

  function calculateVariableLiquidationBonus(
    uint256 healthFactor,
    DataTypes.VariableLiquidationBonusConfig memory config,
    uint256 healthFactorLiquidationThreshold,
    uint256 maxLiquidationBonus
  ) internal pure returns (uint256) {
    if (healthFactor < config.healthFactorThreshold) {
      return maxLiquidationBonus;
    }
    uint256 minLiquidationBonus = maxLiquidationBonus.percentMul(config.liquidationBonusFactor);

    if (healthFactor >= healthFactorLiquidationThreshold) {
      return minLiquidationBonus;
    }

    return
      minLiquidationBonus +
      ((maxLiquidationBonus - minLiquidationBonus) *
        (healthFactorLiquidationThreshold - healthFactor)) /
      (healthFactorLiquidationThreshold - config.healthFactorThreshold);
  }
}
