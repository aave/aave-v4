// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.10;

import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';

contract LiquidationLogicWrapper {
  function calculateVariableLiquidationBonus(
    DataTypes.CalculateVariableLiquidationBonusParams memory params
  ) public pure returns (uint256) {
    return LiquidationLogic.calculateVariableLiquidationBonus(params);
  }

  function validateLiquidationCall(
    LiquidationLogic.ValidateLiquidationCallParams memory params
  ) public pure {
    LiquidationLogic._validateLiquidationCall(params);
  }

  function calculateDebtToRestoreCloseFactor(
    LiquidationLogic.CalculateDebtToRestoreCloseFactorParams memory params
  ) public pure returns (uint256) {
    return LiquidationLogic._calculateDebtToRestoreCloseFactor(params);
  }

  function calculateMaxDebtToLiquidate(
    LiquidationLogic.CalculateMaxDebtToLiquidateParams memory params
  ) public pure returns (uint256) {
    return LiquidationLogic._calculateMaxDebtToLiquidate(params);
  }

  function calculateLiquidationAmounts(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) public pure returns (uint256, uint256, uint256) {
    return LiquidationLogic._calculateLiquidationAmounts(params);
  }

  function assessDeficit(
    LiquidationLogic.AssessDeficitParams memory params
  ) public pure returns (bool) {
    return LiquidationLogic._assessDeficit(params);
  }
}
