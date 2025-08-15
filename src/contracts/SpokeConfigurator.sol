// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
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
  using SafeCast for uint256;

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
    liquidationConfig.closeFactor = closeFactor.toUint128();
    targetSpoke.updateLiquidationConfig(liquidationConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateHealthFactorForMaxBonus(
    address spoke,
    uint256 healthFactorForMaxBonus
  ) external onlyOwner {
    ISpoke targetSpoke = ISpoke(spoke);
    DataTypes.LiquidationConfig memory liquidationConfig = targetSpoke.getLiquidationConfig();
    liquidationConfig.healthFactorForMaxBonus = healthFactorForMaxBonus.toUint64();
    targetSpoke.updateLiquidationConfig(liquidationConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateLiquidationBonusFactor(
    address spoke,
    uint256 liquidationBonusFactor
  ) external onlyOwner {
    ISpoke targetSpoke = ISpoke(spoke);
    DataTypes.LiquidationConfig memory liquidationConfig = targetSpoke.getLiquidationConfig();
    liquidationConfig.liquidationBonusFactor = liquidationBonusFactor.toUint16();
    targetSpoke.updateLiquidationConfig(liquidationConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateLiquidationConfig(
    address spoke,
    DataTypes.LiquidationConfig calldata liquidationConfig
  ) external onlyOwner {
    ISpoke(spoke).updateLiquidationConfig(liquidationConfig);
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
  function updateCollateralRisk(
    address spoke,
    uint256 reserveId,
    uint256 collateralRisk
  ) external onlyOwner {
    ISpoke targetSpoke = ISpoke(spoke);
    DataTypes.ReserveConfig memory reserveConfig = targetSpoke.getReserveConfig(reserveId);
    reserveConfig.collateralRisk = collateralRisk.toUint24();
    targetSpoke.updateReserveConfig(reserveId, reserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function addCollateralFactor(
    address spoke,
    uint256 reserveId,
    uint16 collateralFactor
  ) external onlyOwner {
    ISpoke targetSpoke = ISpoke(spoke);
    DataTypes.DynamicReserveConfig memory dynamicReserveConfig = targetSpoke
      .getDynamicReserveConfig(reserveId);
    dynamicReserveConfig.collateralFactor = collateralFactor;
    targetSpoke.addDynamicReserveConfig(reserveId, dynamicReserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateCollateralFactor(
    address spoke,
    uint256 reserveId,
    uint16 configKey,
    uint16 collateralFactor
  ) external onlyOwner {
    ISpoke targetSpoke = ISpoke(spoke);
    DataTypes.DynamicReserveConfig memory dynamicReserveConfig = targetSpoke
      .getDynamicReserveConfig(reserveId, configKey);
    dynamicReserveConfig.collateralFactor = collateralFactor;
    targetSpoke.updateDynamicReserveConfig(reserveId, configKey, dynamicReserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function addLiquidationBonus(
    address spoke,
    uint256 reserveId,
    uint256 liquidationBonus
  ) external onlyOwner {
    ISpoke targetSpoke = ISpoke(spoke);
    DataTypes.DynamicReserveConfig memory dynamicReserveConfig = targetSpoke
      .getDynamicReserveConfig(reserveId);
    dynamicReserveConfig.liquidationBonus = liquidationBonus.toUint32();
    targetSpoke.addDynamicReserveConfig(reserveId, dynamicReserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateLiquidationBonus(
    address spoke,
    uint256 reserveId,
    uint16 configKey,
    uint256 liquidationBonus
  ) external onlyOwner {
    ISpoke targetSpoke = ISpoke(spoke);
    DataTypes.DynamicReserveConfig memory dynamicReserveConfig = targetSpoke
      .getDynamicReserveConfig(reserveId, configKey);
    dynamicReserveConfig.liquidationBonus = liquidationBonus.toUint32();
    targetSpoke.updateDynamicReserveConfig(reserveId, configKey, dynamicReserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function addLiquidationFee(
    address spoke,
    uint256 reserveId,
    uint256 liquidationFee
  ) external onlyOwner {
    ISpoke targetSpoke = ISpoke(spoke);
    DataTypes.DynamicReserveConfig memory dynamicReserveConfig = targetSpoke
      .getDynamicReserveConfig(reserveId);
    dynamicReserveConfig.liquidationFee = liquidationFee.toUint16();
    targetSpoke.addDynamicReserveConfig(reserveId, dynamicReserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateLiquidationFee(
    address spoke,
    uint256 reserveId,
    uint16 configKey,
    uint256 liquidationFee
  ) external onlyOwner {
    ISpoke targetSpoke = ISpoke(spoke);
    DataTypes.DynamicReserveConfig memory dynamicReserveConfig = targetSpoke
      .getDynamicReserveConfig(reserveId, configKey);
    dynamicReserveConfig.liquidationFee = liquidationFee.toUint16();
    targetSpoke.updateDynamicReserveConfig(reserveId, configKey, dynamicReserveConfig);
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
  function addDynamicReserveConfig(
    address spoke,
    uint256 reserveId,
    DataTypes.DynamicReserveConfig calldata dynamicConfig
  ) external onlyOwner returns (uint16 configKey) {
    return ISpoke(spoke).addDynamicReserveConfig(reserveId, dynamicConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateDynamicReserveConfig(
    address spoke,
    uint256 reserveId,
    uint16 configKey,
    DataTypes.DynamicReserveConfig calldata dynamicConfig
  ) external onlyOwner {
    ISpoke(spoke).updateDynamicReserveConfig(reserveId, configKey, dynamicConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function pauseAllReserves(address spoke) external onlyOwner {
    ISpoke targetSpoke = ISpoke(spoke);
    uint256 reserveCount = targetSpoke.getReserveCount();
    for (uint256 reserveId = 0; reserveId < reserveCount; ++reserveId) {
      DataTypes.ReserveConfig memory reserveConfig = targetSpoke.getReserveConfig(reserveId);
      reserveConfig.paused = true;
      targetSpoke.updateReserveConfig(reserveId, reserveConfig);
    }
  }

  /// @inheritdoc ISpokeConfigurator
  function freezeAllReserves(address spoke) external onlyOwner {
    ISpoke targetSpoke = ISpoke(spoke);
    uint256 reserveCount = targetSpoke.getReserveCount();
    for (uint256 reserveId = 0; reserveId < reserveCount; ++reserveId) {
      DataTypes.ReserveConfig memory reserveConfig = targetSpoke.getReserveConfig(reserveId);
      reserveConfig.frozen = true;
      targetSpoke.updateReserveConfig(reserveId, reserveConfig);
    }
  }

  /// @inheritdoc ISpokeConfigurator
  function updatePositionManager(
    address spoke,
    address positionManager,
    bool active
  ) external onlyOwner {
    ISpoke(spoke).updatePositionManager(positionManager, active);
  }
}
