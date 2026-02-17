// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {Roles} from 'src/libraries/types/Roles.sol';
import {SnapshotHelpers} from 'tests/helpers/SnapshotHelpers.sol';

/// @title ConfigHelpers
/// @notice Configuration mutator helpers for the Aave V4 test suite.
abstract contract ConfigHelpers is SnapshotHelpers {
  using SafeCast for *;

  function updateAssetFeeReceiver(
    IHub hub,
    uint256 assetId,
    address newFeeReceiver
  ) internal pausePrank {
    IHub.AssetConfig memory config = hub.getAssetConfig(assetId);
    config.feeReceiver = newFeeReceiver;

    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(assetId, config, new bytes(0));

    assertEq(hub.getAssetConfig(assetId), config);
  }

  function updateAssetReinvestmentController(
    IHub hub,
    uint256 assetId,
    address newReinvestmentController
  ) internal pausePrank {
    IHub.AssetConfig memory config = hub.getAssetConfig(assetId);
    config.reinvestmentController = newReinvestmentController;

    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(assetId, config, new bytes(0));

    assertEq(hub.getAssetConfig(assetId), config);
  }

  function _updateReserveFrozenFlag(
    ISpoke spoke,
    uint256 reserveId,
    bool newFrozenFlag
  ) internal pausePrank {
    ISpoke.ReserveConfig memory config = spoke.getReserveConfig(reserveId);
    config.frozen = newFrozenFlag;

    vm.prank(SPOKE_ADMIN);
    spoke.updateReserveConfig(reserveId, config);

    assertEq(spoke.getReserveConfig(reserveId), config);
  }

  function _updateReservePausedFlag(
    ISpoke spoke,
    uint256 reserveId,
    bool paused
  ) internal pausePrank {
    ISpoke.ReserveConfig memory config = spoke.getReserveConfig(reserveId);
    config.paused = paused;

    vm.prank(SPOKE_ADMIN);
    spoke.updateReserveConfig(reserveId, config);

    assertEq(spoke.getReserveConfig(reserveId), config);
  }

  function _updateReserveReceiveSharesEnabledFlag(
    ISpoke spoke,
    uint256 reserveId,
    bool receiveSharesEnabled
  ) internal pausePrank {
    ISpoke.ReserveConfig memory config = spoke.getReserveConfig(reserveId);
    config.receiveSharesEnabled = receiveSharesEnabled;

    vm.prank(SPOKE_ADMIN);
    spoke.updateReserveConfig(reserveId, config);

    assertEq(spoke.getReserveConfig(reserveId), config);
  }

  function _updateLiquidationConfig(
    ISpoke spoke,
    ISpoke.LiquidationConfig memory config
  ) internal pausePrank {
    vm.prank(SPOKE_ADMIN);
    spoke.updateLiquidationConfig(config);

    assertEq(spoke.getLiquidationConfig(), config);
  }

  function _updateMaxLiquidationBonus(
    ISpoke spoke,
    uint256 reserveId,
    uint32 newMaxLiquidationBonus
  ) internal pausePrank returns (uint32) {
    ISpoke.DynamicReserveConfig memory config = _getLatestDynamicReserveConfig(spoke, reserveId);
    config.maxLiquidationBonus = newMaxLiquidationBonus;

    vm.prank(SPOKE_ADMIN);
    uint32 dynamicConfigKey = spoke.addDynamicReserveConfig(reserveId, config);

    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), config);
    return dynamicConfigKey;
  }

  function _updateLiquidationFee(
    ISpoke spoke,
    uint256 reserveId,
    uint16 newLiquidationFee
  ) internal pausePrank returns (uint32) {
    ISpoke.DynamicReserveConfig memory config = _getLatestDynamicReserveConfig(spoke, reserveId);
    config.liquidationFee = newLiquidationFee;

    vm.prank(SPOKE_ADMIN);
    uint32 dynamicConfigKey = spoke.addDynamicReserveConfig(reserveId, config);

    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), config);
    return dynamicConfigKey;
  }

  function _updateCollateralFactorAndLiquidationBonus(
    ISpoke spoke,
    uint256 reserveId,
    uint256 newCollateralFactor,
    uint256 newLiquidationBonus
  ) internal pausePrank returns (uint32) {
    ISpoke.DynamicReserveConfig memory config = _getLatestDynamicReserveConfig(spoke, reserveId);
    config.collateralFactor = newCollateralFactor.toUint16();
    config.maxLiquidationBonus = newLiquidationBonus.toUint32();

    vm.prank(SPOKE_ADMIN);
    uint32 dynamicConfigKey = spoke.addDynamicReserveConfig(reserveId, config);

    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), config);
    return dynamicConfigKey;
  }

  function _updateCollateralFactor(
    ISpoke spoke,
    uint256 reserveId,
    uint256 newCollateralFactor
  ) internal pausePrank returns (uint32) {
    ISpoke.DynamicReserveConfig memory config = _getLatestDynamicReserveConfig(spoke, reserveId);
    config.collateralFactor = newCollateralFactor.toUint16();
    vm.prank(SPOKE_ADMIN);
    uint32 dynamicConfigKey = spoke.addDynamicReserveConfig(reserveId, config);

    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), config);
    return dynamicConfigKey;
  }

  function _updateCollateralFactorAtKey(
    ISpoke spoke,
    uint256 reserveId,
    uint256 newCollateralFactor,
    uint32 dynamicConfigKey
  ) internal pausePrank {
    ISpoke.DynamicReserveConfig memory config = spoke.getDynamicReserveConfig(
      reserveId,
      dynamicConfigKey
    );
    config.collateralFactor = newCollateralFactor.toUint16();
    vm.prank(SPOKE_ADMIN);
    spoke.updateDynamicReserveConfig(reserveId, dynamicConfigKey, config);

    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), config);
  }

  function _addDynamicReserveConfig(
    ISpoke spoke,
    uint256 reserveId,
    ISpoke.DynamicReserveConfig memory config
  ) internal pausePrank returns (uint32) {
    vm.prank(SPOKE_ADMIN);
    return spoke.addDynamicReserveConfig(reserveId, config);
  }

  function _updateReserveBorrowableFlag(
    ISpoke spoke,
    uint256 reserveId,
    bool newBorrowable
  ) internal pausePrank {
    ISpoke.ReserveConfig memory config = spoke.getReserveConfig(reserveId);
    config.borrowable = newBorrowable;
    vm.prank(SPOKE_ADMIN);
    spoke.updateReserveConfig(reserveId, config);

    assertEq(spoke.getReserveConfig(reserveId), config);
  }

  function _updateCollateralRisk(
    ISpoke spoke,
    uint256 reserveId,
    uint24 newCollateralRisk
  ) internal pausePrank {
    ISpoke.ReserveConfig memory config = spoke.getReserveConfig(reserveId);
    config.collateralRisk = newCollateralRisk;
    vm.prank(SPOKE_ADMIN);
    spoke.updateReserveConfig(reserveId, config);

    assertEq(spoke.getReserveConfig(reserveId), config);
  }

  function updateLiquidityFee(IHub hub, uint256 assetId, uint256 liquidityFee) internal pausePrank {
    IHub.AssetConfig memory config = hub.getAssetConfig(assetId);
    config.liquidityFee = liquidityFee.toUint16();
    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(assetId, config, new bytes(0));

    assertEq(hub.getAssetConfig(assetId), config);
  }

  function _updateTargetHealthFactor(
    ISpoke spoke,
    uint128 newTargetHealthFactor
  ) internal pausePrank {
    ISpoke.LiquidationConfig memory liqConfig = spoke.getLiquidationConfig();
    liqConfig.targetHealthFactor = newTargetHealthFactor;
    vm.prank(SPOKE_ADMIN);
    spoke.updateLiquidationConfig(liqConfig);

    assertEq(spoke.getLiquidationConfig(), liqConfig);
  }

  function _updateLiquidationBonusFactor(
    ISpoke spoke,
    uint16 newLiquidationBonusFactor
  ) internal pausePrank {
    ISpoke.LiquidationConfig memory liqConfig = spoke.getLiquidationConfig();
    liqConfig.liquidationBonusFactor = newLiquidationBonusFactor;
    vm.prank(SPOKE_ADMIN);
    spoke.updateLiquidationConfig(liqConfig);

    assertEq(spoke.getLiquidationConfig(), liqConfig);
  }

  function _updateSpokeHalted(
    IHub hub,
    uint256 assetId,
    address spoke,
    bool halted
  ) internal pausePrank {
    IHub.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spoke);
    spokeConfig.halted = halted;
    vm.prank(HUB_ADMIN);
    hub.updateSpokeConfig(assetId, spoke, spokeConfig);

    assertEq(hub.getSpokeConfig(assetId, spoke), spokeConfig);
  }

  function _updateSpokeActive(
    IHub hub,
    uint256 assetId,
    address spoke,
    bool newActive
  ) internal pausePrank {
    IHub.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spoke);
    spokeConfig.active = newActive;
    vm.prank(HUB_ADMIN);
    hub.updateSpokeConfig(assetId, spoke, spokeConfig);

    assertEq(hub.getSpokeConfig(assetId, spoke), spokeConfig);
  }

  function _updateAddCap(
    IHub hub,
    uint256 assetId,
    address spoke,
    uint40 newAddCap
  ) internal pausePrank {
    IHub.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spoke);
    spokeConfig.addCap = newAddCap;
    vm.prank(HUB_ADMIN);
    hub.updateSpokeConfig(assetId, spoke, spokeConfig);

    assertEq(hub.getSpokeConfig(assetId, spoke), spokeConfig);
  }

  function updateDrawCap(
    IHub hub,
    uint256 assetId,
    address spoke,
    uint40 newDrawCap
  ) internal pausePrank {
    IHub.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spoke);
    spokeConfig.drawCap = newDrawCap;
    vm.prank(HUB_ADMIN);
    hub.updateSpokeConfig(assetId, spoke, spokeConfig);

    assertEq(hub.getSpokeConfig(assetId, spoke), spokeConfig);
  }

  function _updateSpokeRiskPremiumThreshold(
    IHub hub,
    uint256 assetId,
    address spoke,
    uint24 newRiskPremiumThreshold
  ) internal pausePrank {
    IHub.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spoke);
    spokeConfig.riskPremiumThreshold = newRiskPremiumThreshold;
    vm.prank(HUB_ADMIN);
    hub.updateSpokeConfig(assetId, spoke, spokeConfig);

    assertEq(hub.getSpokeConfig(assetId, spoke), spokeConfig);
  }

  function grantDeficitEliminatorRole(IHub hub, address target) internal pausePrank {
    IAccessManager manager = IAccessManager(hub.authority());
    vm.prank(ADMIN);
    manager.grantRole(Roles.DEFICIT_ELIMINATOR_ROLE, target, 0);
  }

  function revokeDeficitEliminatorRole(IHub hub, address target) internal pausePrank {
    IAccessManager manager = IAccessManager(hub.authority());
    vm.prank(ADMIN);
    manager.revokeRole(Roles.DEFICIT_ELIMINATOR_ROLE, target);
  }
}
