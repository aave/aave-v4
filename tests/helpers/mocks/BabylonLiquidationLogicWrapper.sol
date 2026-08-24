// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LiquidationLogic} from 'src/spoke/libraries/LiquidationLogic.sol';
import {BabylonLiquidationLogic} from 'src/spoke/libraries/BabylonLiquidationLogic.sol';

contract BabylonLiquidationLogicWrapper {
  function calculateLiquidationAmounts(
    BabylonLiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) public view returns (LiquidationLogic.LiquidationAmounts memory) {
    return BabylonLiquidationLogic._calculateLiquidationAmounts(params);
  }

  function calculateDebtToLiquidate(
    BabylonLiquidationLogic.CalculateDebtToLiquidateParams memory params
  ) public pure returns (uint256, uint256) {
    return BabylonLiquidationLogic._calculateDebtToLiquidate(params);
  }
}
