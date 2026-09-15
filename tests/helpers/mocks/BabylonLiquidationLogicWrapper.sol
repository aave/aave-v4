// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BabylonLiquidationLogic} from 'src/spoke/libraries/BabylonLiquidationLogic.sol';

contract BabylonLiquidationLogicWrapper {
  bool public IS_TEST = true;

  function calculateLiquidationAmounts(
    BabylonLiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) external view returns (BabylonLiquidationLogic.LiquidationAmounts memory) {
    return BabylonLiquidationLogic._calculateLiquidationAmounts(params);
  }
}
