// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Spoke} from 'src/contracts/Spoke.sol';

import 'forge-std/console2.sol';
/// @dev mock Spoke to expose internal methods for testing

contract MockSpokeExposedMethods is Spoke {
  constructor(address _hub, address _oracle) Spoke(_hub, _oracle) {}

  function calculateUserAccountData(
    address user
  ) public view returns (uint256, uint256, uint256, uint256, uint256) {
    return _calculateUserAccountData(user);
  }

  function calculateActualDebtToLiquidate(
    uint256 debtToCover,
    address user,
    uint256 debtAssetId,
    uint256 totalCollateralInBaseCurrency,
    uint256 totalDebtInBaseCurrency,
    uint256 avgLiquidationThreshold,
    Reserve memory collateralReserve
  ) public view returns (uint256) {
    return
      _calculateActualDebtToLiquidate(
        debtToCover,
        user,
        debtAssetId,
        totalCollateralInBaseCurrency,
        totalDebtInBaseCurrency,
        avgLiquidationThreshold,
        collateralReserve
      );
  }

  /**
   * @return The maximum collateral amount that is possible to liquidate given all the liquidation constraints (liquidation bonus, liquidationProtocolFeePercentage)
   * @return The amount to repay with the liquidation
   * @return The fee taken from the liquidation bonus amount to be paid to the protocol
   */
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
