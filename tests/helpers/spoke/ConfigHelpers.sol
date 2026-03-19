// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {Assertions} from 'tests/helpers/spoke/Assertions.sol';

/// @title ConfigHelpers
/// @notice Spoke-level configuration mutator helpers for the Aave V4 test suite.
abstract contract ConfigHelpers is Assertions {
  using SafeCast for *;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                      RESERVE CONFIG                                       //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _updateReserveFrozenFlag(
    ISpoke spoke,
    uint256 reserveId,
    bool newFrozenFlag,
    address spokeAdmin
  ) internal pausePrank {
    ISpoke.ReserveConfig memory config = spoke.getReserveConfig(reserveId);
    config.frozen = newFrozenFlag;

    vm.prank(spokeAdmin);
    spoke.updateReserveConfig(reserveId, config);

    assertEq(spoke.getReserveConfig(reserveId), config);
  }

  function _updateReservePausedFlag(
    ISpoke spoke,
    uint256 reserveId,
    bool paused,
    address spokeAdmin
  ) internal pausePrank {
    ISpoke.ReserveConfig memory config = spoke.getReserveConfig(reserveId);
    config.paused = paused;

    vm.prank(spokeAdmin);
    spoke.updateReserveConfig(reserveId, config);

    assertEq(spoke.getReserveConfig(reserveId), config);
  }

  function _updateReserveBorrowableFlag(
    ISpoke spoke,
    uint256 reserveId,
    bool newBorrowable,
    address spokeAdmin
  ) internal pausePrank {
    ISpoke.ReserveConfig memory config = spoke.getReserveConfig(reserveId);
    config.borrowable = newBorrowable;
    vm.prank(spokeAdmin);
    spoke.updateReserveConfig(reserveId, config);

    assertEq(spoke.getReserveConfig(reserveId), config);
  }

  function _updateCollateralRisk(
    ISpoke spoke,
    uint256 reserveId,
    uint24 newCollateralRisk,
    address spokeAdmin
  ) internal pausePrank {
    ISpoke.ReserveConfig memory config = spoke.getReserveConfig(reserveId);
    config.collateralRisk = newCollateralRisk;
    vm.prank(spokeAdmin);
    spoke.updateReserveConfig(reserveId, config);

    assertEq(spoke.getReserveConfig(reserveId), config);
  }

  function _updateLiquidationConfig(
    ISpoke spoke,
    ISpoke.LiquidationConfig memory config,
    address spokeAdmin
  ) internal pausePrank {
    vm.prank(spokeAdmin);
    spoke.updateLiquidationConfig(config);

    assertEq(spoke.getLiquidationConfig(), config);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                  DYNAMIC RESERVE CONFIG                                   //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _updateMaxLiquidationBonus(
    ISpoke spoke,
    uint256 reserveId,
    uint32 newMaxLiquidationBonus,
    address spokeAdmin
  ) internal pausePrank returns (uint32) {
    ISpoke.DynamicReserveConfig memory config = _getLatestDynamicReserveConfig(spoke, reserveId);
    config.maxLiquidationBonus = newMaxLiquidationBonus;

    vm.prank(spokeAdmin);
    uint32 dynamicConfigKey = spoke.addDynamicReserveConfig(reserveId, config);

    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), config);
    return dynamicConfigKey;
  }

  function _updateLiquidationFee(
    ISpoke spoke,
    uint256 reserveId,
    uint16 newLiquidationFee,
    address spokeAdmin
  ) internal pausePrank returns (uint32) {
    ISpoke.DynamicReserveConfig memory config = _getLatestDynamicReserveConfig(spoke, reserveId);
    config.liquidationFee = newLiquidationFee;

    vm.prank(spokeAdmin);
    uint32 dynamicConfigKey = spoke.addDynamicReserveConfig(reserveId, config);

    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), config);
    return dynamicConfigKey;
  }

  function _updateCollateralFactorAndLiquidationBonus(
    ISpoke spoke,
    uint256 reserveId,
    uint256 newCollateralFactor,
    uint256 newLiquidationBonus,
    address spokeAdmin
  ) internal pausePrank returns (uint32) {
    ISpoke.DynamicReserveConfig memory config = _getLatestDynamicReserveConfig(spoke, reserveId);
    config.collateralFactor = newCollateralFactor.toUint16();
    config.maxLiquidationBonus = newLiquidationBonus.toUint32();

    vm.prank(spokeAdmin);
    uint32 dynamicConfigKey = spoke.addDynamicReserveConfig(reserveId, config);

    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), config);
    return dynamicConfigKey;
  }

  function _updateCollateralFactor(
    ISpoke spoke,
    uint256 reserveId,
    uint256 newCollateralFactor,
    address spokeAdmin
  ) internal pausePrank returns (uint32) {
    ISpoke.DynamicReserveConfig memory config = _getLatestDynamicReserveConfig(spoke, reserveId);
    config.collateralFactor = newCollateralFactor.toUint16();
    vm.prank(spokeAdmin);
    uint32 dynamicConfigKey = spoke.addDynamicReserveConfig(reserveId, config);

    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), config);
    return dynamicConfigKey;
  }

  function _addDynamicReserveConfig(
    ISpoke spoke,
    uint256 reserveId,
    ISpoke.DynamicReserveConfig memory config,
    address spokeAdmin
  ) internal pausePrank returns (uint32) {
    vm.prank(spokeAdmin);
    return spoke.addDynamicReserveConfig(reserveId, config);
  }

  function _updateTargetHealthFactor(
    ISpoke spoke,
    uint128 newTargetHealthFactor,
    address spokeAdmin
  ) internal pausePrank {
    ISpoke.LiquidationConfig memory liqConfig = spoke.getLiquidationConfig();
    liqConfig.targetHealthFactor = newTargetHealthFactor;
    vm.prank(spokeAdmin);
    spoke.updateLiquidationConfig(liqConfig);

    assertEq(spoke.getLiquidationConfig(), liqConfig);
  }

  function _updateLiquidationBonusFactor(
    ISpoke spoke,
    uint16 newLiquidationBonusFactor,
    address spokeAdmin
  ) internal pausePrank {
    ISpoke.LiquidationConfig memory liqConfig = spoke.getLiquidationConfig();
    liqConfig.liquidationBonusFactor = newLiquidationBonusFactor;
    vm.prank(spokeAdmin);
    spoke.updateLiquidationConfig(liqConfig);

    assertEq(spoke.getLiquidationConfig(), liqConfig);
  }
}
