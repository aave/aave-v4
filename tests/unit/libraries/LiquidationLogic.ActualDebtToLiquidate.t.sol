// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {Base} from 'tests/Base.t.sol';

contract LiquidationLogicActualDebtToLiquidateTest is Base {
  using PercentageMath for uint256;
  using WadRayMath for uint256;

  DataTypes.LiquidationConfig internal _config;

  /// if debtToCover > maxLiquidatableDebt, actualDebtToLiquidate == maxLiquidatableDebt
  function testCalculateActualDebtToLiquidate_debtToCover_gt_maxLiquidatableDebt() public {
    uint256 debtToCover = 1000e18;

    DataTypes.LiquidationCallLocalVars memory params;
    params.totalDebt = 2000e18;

    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      debtToCover,
      params
    );

    assertEq(actualDebtToLiquidate, params.totalDebt); // Expected value based on the test case setup
  }
}
