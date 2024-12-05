// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Spoke} from 'src/contracts/Spoke.sol';

import 'forge-std/console2.sol';

contract MockSpokeExposedMethods is Spoke {
  constructor(address _hub, address _oracle) Spoke(_hub, _oracle) {}

  function calculateAvailableCollateralToLiquidate(
    Reserve memory collateralReserve,
    Reserve memory debtReserve,
    uint256 debtToCover,
    uint256 userCollateralBalance,
    uint256 liquidationBonus
  ) public view returns (uint256, uint256, uint256) {
    return
      _calculateAvailableCollateralToLiquidate(
        collateralReserve,
        debtReserve,
        debtToCover,
        userCollateralBalance,
        liquidationBonus
      );
  }
}
