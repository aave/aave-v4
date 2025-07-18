// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'src/interfaces/ISpokeConfigurator.sol';

/**
 * @title SpokeConfigurator
 * @author Aave Labs
 * @notice SpokeConfigurator contract for the Aave protocol
 * @dev Must be granted permission by the Spoke
 */
contract SpokeConfigurator is Ownable, ISpokeConfigurator {
  /**
   * @dev Constructor
   * @param owner_ The address of the owner
   */
  constructor(address owner_) Ownable(owner_) {}

  /// @inheritdoc ISpokeConfigurator
  function updateOracle(address spoke, address oracle) external onlyOwner {
    ISpoke(spoke).updateOracle(oracle);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateReservePriceSource(
    address spoke,
    uint256 reserveId,
    address priceSource
  ) external onlyOwner {
    ISpoke(spoke).updateReservePriceSource(reserveId, priceSource);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateLiquidationCloseFactor(address spoke, uint256 closeFactor) external onlyOwner {
    ISpoke targetSpoke = ISpoke(spoke);
    DataTypes.LiquidationConfig memory liquidationConfig = targetSpoke.getLiquidationConfig();
    liquidationConfig.closeFactor = closeFactor;
    targetSpoke.updateLiquidationConfig(liquidationConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateHealthFactorForMaxBonus(
    address spoke,
    uint256 healthFactorForMaxBonus
  ) external onlyOwner {
    ISpoke targetSpoke = ISpoke(spoke);
    DataTypes.LiquidationConfig memory liquidationConfig = targetSpoke.getLiquidationConfig();
    liquidationConfig.healthFactorForMaxBonus = healthFactorForMaxBonus;
    targetSpoke.updateLiquidationConfig(liquidationConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateLiquidationBonusFactor(
    address spoke,
    uint256 liquidationBonusFactor
  ) external onlyOwner {
    ISpoke targetSpoke = ISpoke(spoke);
    DataTypes.LiquidationConfig memory liquidationConfig = targetSpoke.getLiquidationConfig();
    liquidationConfig.liquidationBonusFactor = liquidationBonusFactor;
    targetSpoke.updateLiquidationConfig(liquidationConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function addReserve(
    address spoke,
    address hub,
    uint256 assetId,
    address priceSource,
    DataTypes.ReserveConfig calldata config,
    DataTypes.DynamicReserveConfig calldata dynamicConfig
  ) external onlyOwner returns (uint256 reserveId) {
    return ISpoke(spoke).addReserve(hub, assetId, priceSource, config, dynamicConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateActive(address spoke, uint256 reserveId, bool active) external onlyOwner {
    ISpoke targetSpoke = ISpoke(spoke);
    DataTypes.ReserveConfig memory reserveConfig = targetSpoke.getReserveConfig(reserveId);
    reserveConfig.active = active;
    targetSpoke.updateReserveConfig(reserveId, reserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updatePaused(address spoke, uint256 reserveId, bool paused) external onlyOwner {
    ISpoke targetSpoke = ISpoke(spoke);
    DataTypes.ReserveConfig memory reserveConfig = targetSpoke.getReserveConfig(reserveId);
    reserveConfig.paused = paused;
    targetSpoke.updateReserveConfig(reserveId, reserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateFrozen(address spoke, uint256 reserveId, bool frozen) external onlyOwner {
    ISpoke targetSpoke = ISpoke(spoke);
    DataTypes.ReserveConfig memory reserveConfig = targetSpoke.getReserveConfig(reserveId);
    reserveConfig.frozen = frozen;
    targetSpoke.updateReserveConfig(reserveId, reserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateBorrowable(address spoke, uint256 reserveId, bool borrowable) external onlyOwner {
    ISpoke targetSpoke = ISpoke(spoke);
    DataTypes.ReserveConfig memory reserveConfig = targetSpoke.getReserveConfig(reserveId);
    reserveConfig.borrowable = borrowable;
    targetSpoke.updateReserveConfig(reserveId, reserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateCollateral(address spoke, uint256 reserveId, bool collateral) external onlyOwner {
    ISpoke targetSpoke = ISpoke(spoke);
    DataTypes.ReserveConfig memory reserveConfig = targetSpoke.getReserveConfig(reserveId);
    reserveConfig.collateral = collateral;
    targetSpoke.updateReserveConfig(reserveId, reserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateLiquidityPremium(
    address spoke,
    uint256 reserveId,
    uint256 liquidityPremium
  ) external onlyOwner {
    ISpoke targetSpoke = ISpoke(spoke);
    DataTypes.ReserveConfig memory reserveConfig = targetSpoke.getReserveConfig(reserveId);
    reserveConfig.liquidityPremium = liquidityPremium;
    targetSpoke.updateReserveConfig(reserveId, reserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateCollateralFactor(
    address spoke,
    uint256 reserveId,
    uint16 collateralFactor
  ) external onlyOwner {
    ISpoke targetSpoke = ISpoke(spoke);
    DataTypes.DynamicReserveConfig memory dynamicReserveConfig = targetSpoke
      .getDynamicReserveConfig(reserveId);
    dynamicReserveConfig.collateralFactor = collateralFactor;
    targetSpoke.updateDynamicReserveConfig(reserveId, dynamicReserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateLiquidationBonus(
    address spoke,
    uint256 reserveId,
    uint256 liquidationBonus
  ) external onlyOwner {
    ISpoke targetSpoke = ISpoke(spoke);
    DataTypes.DynamicReserveConfig memory dynamicReserveConfig = targetSpoke
      .getDynamicReserveConfig(reserveId);
    dynamicReserveConfig.liquidationBonus = liquidationBonus;
    targetSpoke.updateDynamicReserveConfig(reserveId, dynamicReserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateLiquidationFee(
    address spoke,
    uint256 reserveId,
    uint256 liquidationFee
  ) external onlyOwner {
    ISpoke targetSpoke = ISpoke(spoke);
    DataTypes.DynamicReserveConfig memory dynamicReserveConfig = targetSpoke
      .getDynamicReserveConfig(reserveId);
    dynamicReserveConfig.liquidationFee = liquidationFee;
    targetSpoke.updateDynamicReserveConfig(reserveId, dynamicReserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateReserveConfig(
    address spoke,
    uint256 reserveId,
    DataTypes.ReserveConfig calldata config
  ) external onlyOwner {
    ISpoke(spoke).updateReserveConfig(reserveId, config);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateDynamicReserveConfig(
    address spoke,
    uint256 reserveId,
    DataTypes.DynamicReserveConfig calldata dynamicConfig
  ) external onlyOwner {
    ISpoke(spoke).updateDynamicReserveConfig(reserveId, dynamicConfig);
  }
}
