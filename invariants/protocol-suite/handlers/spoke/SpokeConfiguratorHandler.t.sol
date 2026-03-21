// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

// Interfaces
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {ISpokeConfiguratorHandler} from '../interfaces/ISpokeConfiguratorHandler.sol';

// Libraries
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';

// Test Contracts
import {Actor} from '../../../shared/utils/Actor.sol';
import {BaseHandler} from '../../base/BaseHandler.t.sol';

/// @title SpokeConfiguratorHandler
/// @notice Handler test contract for a set of actions
/// @dev Inputs are bounded to Spoke._validate* constraints on *admin* actions don't unnecessarily
///      discard fuzz inputs.
contract SpokeConfiguratorHandler is BaseHandler, ISpokeConfiguratorHandler {
  using PercentageMath for uint256;
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                      STATE VARIABLES                                      //
  ///////////////////////////////////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          ACTIONS                                          //
  ///////////////////////////////////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                         OWNER ACTIONS                                     //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                     RESERVE CONFIG                                        //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function updateCollateralRisk(uint256 collateralRisk, uint8 i, uint8 j) external setup {
    address spoke = _getRandomSpoke(i);
    uint256 reserveId = _getRandomReserveId(spoke, j);
    collateralRisk = _bound(collateralRisk, 0, MAX_ALLOWED_COLLATERAL_RISK);
    spokeConfigurator.updateCollateralRisk(spoke, reserveId, collateralRisk);
  }

  function updatePaused(bool halted, uint8 i, uint8 j) external setup {
    address spoke = _getRandomSpoke(i);
    uint256 reserveId = _getRandomReserveId(spoke, j);
    spokeConfigurator.updatePaused(spoke, reserveId, halted);
  }

  function updateFrozen(bool frozen, uint8 i, uint8 j) external setup {
    address spoke = _getRandomSpoke(i);
    uint256 reserveId = _getRandomReserveId(spoke, j);
    spokeConfigurator.updateFrozen(spoke, reserveId, frozen);
  }

  function updateBorrowable(bool borrowable, uint8 i, uint8 j) external setup {
    address spoke = _getRandomSpoke(i);
    uint256 reserveId = _getRandomReserveId(spoke, j);
    spokeConfigurator.updateBorrowable(spoke, reserveId, borrowable);
  }

  function updateReceiveSharesEnabled(bool receiveSharesEnabled, uint8 i, uint8 j) external setup {
    address spoke = _getRandomSpoke(i);
    uint256 reserveId = _getRandomReserveId(spoke, j);
    spokeConfigurator.updateReceiveSharesEnabled(spoke, reserveId, receiveSharesEnabled);
  }

  function pauseAllReserves(uint8 i) external setup {
    address spoke = _getRandomSpoke(i);
    spokeConfigurator.pauseAllReserves(spoke);
  }

  function freezeAllReserves(uint8 i) external setup {
    address spoke = _getRandomSpoke(i);
    spokeConfigurator.freezeAllReserves(spoke);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                   LIQUIDATION CONFIG                                      //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function updateLiquidationTargetHealthFactor(uint256 targetHealthFactor, uint8 i) external setup {
    address spoke = _getRandomSpoke(i);
    targetHealthFactor = _bound(
      targetHealthFactor,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      MAX_TARGET_HEALTH_FACTOR
    );
    spokeConfigurator.updateLiquidationTargetHealthFactor(spoke, targetHealthFactor);
  }

  function updateHealthFactorForMaxBonus(uint256 healthFactorForMaxBonus, uint8 i) external setup {
    address spoke = _getRandomSpoke(i);
    healthFactorForMaxBonus = _bound(
      healthFactorForMaxBonus,
      0,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1
    );
    spokeConfigurator.updateHealthFactorForMaxBonus(spoke, healthFactorForMaxBonus);
  }

  function updateLiquidationBonusFactor(uint256 liquidationBonusFactor, uint8 i) external setup {
    address spoke = _getRandomSpoke(i);
    liquidationBonusFactor = _bound(liquidationBonusFactor, 0, PERCENTAGE_FACTOR);
    spokeConfigurator.updateLiquidationBonusFactor(spoke, liquidationBonusFactor);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                    DYNAMIC CONFIG                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function addCollateralFactor(uint256 collateralFactor, uint8 i, uint8 j) external setup {
    address spoke = _getRandomSpoke(i);
    uint256 reserveId = _getRandomReserveId(spoke, j);

    uint256 maxCf = _collateralFactorUpperBound(spoke, reserveId);
    collateralFactor = _bound(collateralFactor, 1, maxCf);
    spokeConfigurator.addCollateralFactor(spoke, reserveId, uint16(collateralFactor));
  }

  function updateCollateralFactor(
    uint256 collateralFactor,
    uint8 i,
    uint8 j,
    uint8 k
  ) external setup {
    address spoke = _getRandomSpoke(i);
    uint256 reserveId = _getRandomReserveId(spoke, j);
    uint32 dynamicConfigKey = _getRandomDynamicConfigKey(spoke, reserveId, k);

    uint256 maxCf = _collateralFactorUpperBound(spoke, reserveId, dynamicConfigKey);
    collateralFactor = _bound(collateralFactor, 1, maxCf);
    spokeConfigurator.updateCollateralFactor(
      spoke,
      reserveId,
      dynamicConfigKey,
      uint16(collateralFactor)
    );
  }

  function addMaxLiquidationBonus(uint256 maxLiquidationBonus, uint8 i, uint8 j) external setup {
    address spoke = _getRandomSpoke(i);
    uint256 reserveId = _getRandomReserveId(spoke, j);

    uint256 maxMlb = _maxLiquidationBonusUpperBound(spoke, reserveId);
    maxLiquidationBonus = _bound(maxLiquidationBonus, PERCENTAGE_FACTOR, maxMlb);
    spokeConfigurator.addMaxLiquidationBonus(spoke, reserveId, maxLiquidationBonus);
  }

  function updateMaxLiquidationBonus(
    uint256 maxLiquidationBonus,
    uint8 i,
    uint8 j,
    uint8 k
  ) external setup {
    address spoke = _getRandomSpoke(i);
    uint256 reserveId = _getRandomReserveId(spoke, j);
    uint32 dynamicConfigKey = _getRandomDynamicConfigKey(spoke, reserveId, k);

    uint256 maxMlb = _maxLiquidationBonusUpperBound(spoke, reserveId, dynamicConfigKey);
    maxLiquidationBonus = _bound(maxLiquidationBonus, PERCENTAGE_FACTOR, maxMlb);
    spokeConfigurator.updateMaxLiquidationBonus(
      spoke,
      reserveId,
      dynamicConfigKey,
      maxLiquidationBonus
    );
  }

  function addLiquidationFee(uint256 liquidationFee, uint8 i, uint8 j) external setup {
    address spoke = _getRandomSpoke(i);
    uint256 reserveId = _getRandomReserveId(spoke, j);
    liquidationFee = _bound(liquidationFee, 0, PERCENTAGE_FACTOR);
    spokeConfigurator.addLiquidationFee(spoke, reserveId, liquidationFee);
  }

  function updateLiquidationFee(uint256 liquidationFee, uint8 i, uint8 j, uint8 k) external setup {
    address spoke = _getRandomSpoke(i);
    uint256 reserveId = _getRandomReserveId(spoke, j);
    uint32 dynamicConfigKey = _getRandomDynamicConfigKey(spoke, reserveId, k);
    liquidationFee = _bound(liquidationFee, 0, PERCENTAGE_FACTOR);
    spokeConfigurator.updateLiquidationFee(spoke, reserveId, dynamicConfigKey, liquidationFee);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                           HELPERS                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @dev Returns the latest dynamic config for a reserve.
  function _getLatestDynamicConfig(
    address spoke,
    uint256 reserveId
  ) internal view returns (ISpoke.DynamicReserveConfig memory) {
    uint32 latestKey = ISpoke(spoke).getReserve(reserveId).dynamicConfigKey;
    return ISpoke(spoke).getDynamicReserveConfig(reserveId, latestKey);
  }

  /// @dev Returns a random dynamic config key in [0, reserve.dynamicConfigKey].
  function _getRandomDynamicConfigKey(
    address spoke,
    uint256 reserveId,
    uint8 k
  ) internal view returns (uint32) {
    uint32 latestKey = ISpoke(spoke).getReserve(reserveId).dynamicConfigKey;
    return uint32(_bound(k, 0, latestKey));
  }

  /// @dev Upper bound for collateralFactor derived from the reserve's latest maxLiquidationBonus.
  function _collateralFactorUpperBound(
    address spoke,
    uint256 reserveId
  ) internal view returns (uint256) {
    uint256 maxLiquidationBonus = _getLatestDynamicConfig(spoke, reserveId).maxLiquidationBonus;
    return _collateralFactorUpperBound(maxLiquidationBonus);
  }

  /// @dev Upper bound for collateralFactor at a specific dynamic config key.
  function _collateralFactorUpperBound(
    address spoke,
    uint256 reserveId,
    uint32 dynamicConfigKey
  ) internal view returns (uint256) {
    uint256 maxLiquidationBonus = ISpoke(spoke)
      .getDynamicReserveConfig(reserveId, dynamicConfigKey)
      .maxLiquidationBonus;
    return _collateralFactorUpperBound(maxLiquidationBonus);
  }

  /// @dev Upper bound for maxLiquidationBonus derived from the reserve's latest collateralFactor.
  function _maxLiquidationBonusUpperBound(
    address spoke,
    uint256 reserveId
  ) internal view returns (uint256) {
    uint256 collateralFactor = _getLatestDynamicConfig(spoke, reserveId).collateralFactor;
    return _maxLiquidationBonusUpperBound(collateralFactor);
  }

  /// @dev Upper bound for maxLiquidationBonus at a specific dynamic config key.
  function _maxLiquidationBonusUpperBound(
    address spoke,
    uint256 reserveId,
    uint32 dynamicConfigKey
  ) internal view returns (uint256) {
    uint256 collateralFactor = ISpoke(spoke)
      .getDynamicReserveConfig(reserveId, dynamicConfigKey)
      .collateralFactor;
    return _maxLiquidationBonusUpperBound(collateralFactor);
  }

  /// @dev Upper bound for maxLiquidationBonus for a given collateralFactor.
  function _maxLiquidationBonusUpperBound(
    uint256 collateralFactor
  ) internal pure returns (uint256) {
    if (collateralFactor == 0) return PERCENTAGE_FACTOR;
    return (PercentageMath.PERCENTAGE_FACTOR - 1).percentDivDown(collateralFactor);
  }

  /// @dev Upper bound for collateralFactor for a given maxLiquidationBonus.
  function _collateralFactorUpperBound(
    uint256 maxLiquidationBonus
  ) internal pure returns (uint256) {
    return (PercentageMath.PERCENTAGE_FACTOR - 1).percentDivDown(maxLiquidationBonus);
  }
}
