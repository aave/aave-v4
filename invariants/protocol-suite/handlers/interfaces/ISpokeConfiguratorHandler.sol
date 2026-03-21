// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

/// @title ISpokeConfiguratorHandler
/// @notice Interface for the SpokeConfiguratorHandler
interface ISpokeConfiguratorHandler {
  // Reserve config
  function updateCollateralRisk(uint256 collateralRisk, uint8 i, uint8 j) external;

  function updatePaused(bool halted, uint8 i, uint8 j) external;

  function updateFrozen(bool frozen, uint8 i, uint8 j) external;

  function updateBorrowable(bool borrowable, uint8 i, uint8 j) external;

  function updateReceiveSharesEnabled(bool receiveSharesEnabled, uint8 i, uint8 j) external;

  function pauseAllReserves(uint8 i) external;

  function freezeAllReserves(uint8 i) external;

  // Liquidation config
  function updateLiquidationTargetHealthFactor(uint256 targetHealthFactor, uint8 i) external;

  function updateHealthFactorForMaxBonus(uint256 healthFactorForMaxBonus, uint8 i) external;

  function updateLiquidationBonusFactor(uint256 liquidationBonusFactor, uint8 i) external;

  // Dynamic reserve config
  function addCollateralFactor(uint256 collateralFactor, uint8 i, uint8 j) external;

  function updateCollateralFactor(uint256 collateralFactor, uint8 i, uint8 j, uint8 k) external;

  function addMaxLiquidationBonus(uint256 maxLiquidationBonus, uint8 i, uint8 j) external;

  function updateMaxLiquidationBonus(
    uint256 maxLiquidationBonus,
    uint8 i,
    uint8 j,
    uint8 k
  ) external;

  function addLiquidationFee(uint256 liquidationFee, uint8 i, uint8 j) external;

  function updateLiquidationFee(uint256 liquidationFee, uint8 i, uint8 j, uint8 k) external;
}
