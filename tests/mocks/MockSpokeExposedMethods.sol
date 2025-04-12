// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2 as console} from 'forge-std/console2.sol';

import {Spoke} from 'src/contracts/Spoke.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

/// @dev mock Spoke to expose internal methods for testing
contract MockSpokeExposedMethods is Spoke {
  function test_coverage_ignore() public virtual {
    // Intentionally left blank.
    // Excludes contract from coverage.
  }
  constructor(
    address _hub,
    address _oracle,
    address _treasury,
    uint256 closeFactor
  ) Spoke(_hub, _oracle, _treasury, closeFactor) {}

  // function calculateActualDebtToLiquidate(
  //   uint256 collateralReserveId,
  //   uint256 debtToCover,
  //   address user,
  //   uint256 debtReserveId,
  //   DataTypes.LiquidationCallLocalVars memory params
  // ) public view returns (uint256) {
  //   return _calculateActualDebtToLiquidate(debtToCover, user, debtReserveId, params);
  // }

  // function calculateAvailableCollateralToLiquidate(
  //   DataTypes.Reserve memory collateralReserve,
  //   DataTypes.Reserve memory debtReserve,
  //   DataTypes.LiquidationCallLocalVars memory params
  // ) public view returns (uint256, uint256, uint256) {
  //   return _calculateAvailableCollateralToLiquidate(collateralReserve, debtReserve, params);
  // }
}
