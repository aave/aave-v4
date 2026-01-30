// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {AccessManaged} from 'src/dependencies/openzeppelin/AccessManaged.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

/// @title SpokeConfigurator
/// @author Aave Labs
/// @notice Handles administrative functions on the spoke.
/// @dev Must be granted permission by the spoke.
contract SpokeConfigurator is AccessManaged, ISpokeConfigurator {
  using SafeCast for uint256;

  mapping(address spoke => uint256) internal _maxReserves;

  /// @dev Constructor.
  /// @param authority_ The address of the authority contract which manages permissions.
  constructor(address authority_) AccessManaged(authority_) {}

  /// @inheritdoc ISpokeConfigurator
  function updateReservePriceSource(
    address spoke,
    uint256 reserveId,
    address priceSource
  ) external restricted {
    ISpoke(spoke).updateReservePriceSource(reserveId, priceSource);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateLiquidationTargetHealthFactor(
    address spoke,
    uint256 targetHealthFactor
  ) external restricted {
    ISpoke targetSpoke = ISpoke(spoke);
    ISpoke.LiquidationConfig memory liquidationConfig = targetSpoke.getLiquidationConfig();
    liquidationConfig.targetHealthFactor = targetHealthFactor.toUint128();
    targetSpoke.updateLiquidationConfig(liquidationConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateHealthFactorForMaxBonus(
    address spoke,
    uint256 healthFactorForMaxBonus
  ) external restricted {
    ISpoke targetSpoke = ISpoke(spoke);
    ISpoke.LiquidationConfig memory liquidationConfig = targetSpoke.getLiquidationConfig();
    liquidationConfig.healthFactorForMaxBonus = healthFactorForMaxBonus.toUint64();
    targetSpoke.updateLiquidationConfig(liquidationConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateLiquidationBonusFactor(
    address spoke,
    uint256 liquidationBonusFactor
  ) external restricted {
    ISpoke targetSpoke = ISpoke(spoke);
    ISpoke.LiquidationConfig memory liquidationConfig = targetSpoke.getLiquidationConfig();
    liquidationConfig.liquidationBonusFactor = liquidationBonusFactor.toUint16();
    targetSpoke.updateLiquidationConfig(liquidationConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateLiquidationConfig(
    address spoke,
    ISpoke.LiquidationConfig calldata liquidationConfig
  ) external restricted {
    ISpoke(spoke).updateLiquidationConfig(liquidationConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateMaxReserves(address spoke, uint256 maxReserves) external restricted {
    _maxReserves[spoke] = maxReserves;
    emit UpdateMaxReserves(spoke, maxReserves);
  }

  /// @inheritdoc ISpokeConfigurator
  function addReserve(
    address spoke,
    address hub,
    uint256 assetId,
    address priceSource,
    ISpoke.ReserveConfig calldata config,
    ISpoke.DynamicReserveConfig calldata dynamicConfig
  ) external restricted returns (uint256) {
    require(
      ISpoke(spoke).getReserveCount() < _maxReserves[spoke],
      MaximumReservesReached(spoke, _maxReserves[spoke])
    );
    return ISpoke(spoke).addReserve(hub, assetId, priceSource, config, dynamicConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updatePaused(address spoke, uint256 reserveId, bool paused) external restricted {
    ISpoke targetSpoke = ISpoke(spoke);
    ISpoke.ReserveConfig memory reserveConfig = targetSpoke.getReserveConfig(reserveId);
    reserveConfig.paused = paused;
    targetSpoke.updateReserveConfig(reserveId, reserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateFrozen(address spoke, uint256 reserveId, bool frozen) external restricted {
    ISpoke targetSpoke = ISpoke(spoke);
    ISpoke.ReserveConfig memory reserveConfig = targetSpoke.getReserveConfig(reserveId);
    reserveConfig.frozen = frozen;
    targetSpoke.updateReserveConfig(reserveId, reserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateBorrowable(address spoke, uint256 reserveId, bool borrowable) external restricted {
    ISpoke targetSpoke = ISpoke(spoke);
    ISpoke.ReserveConfig memory reserveConfig = targetSpoke.getReserveConfig(reserveId);
    reserveConfig.borrowable = borrowable;
    targetSpoke.updateReserveConfig(reserveId, reserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateReceiveSharesEnabled(
    address spoke,
    uint256 reserveId,
    bool receiveSharesEnabled
  ) external restricted {
    ISpoke targetSpoke = ISpoke(spoke);
    ISpoke.ReserveConfig memory reserveConfig = targetSpoke.getReserveConfig(reserveId);
    reserveConfig.receiveSharesEnabled = receiveSharesEnabled;
    targetSpoke.updateReserveConfig(reserveId, reserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateCollateralRisk(
    address spoke,
    uint256 reserveId,
    uint256 collateralRisk
  ) external restricted {
    ISpoke targetSpoke = ISpoke(spoke);
    ISpoke.ReserveConfig memory reserveConfig = targetSpoke.getReserveConfig(reserveId);
    reserveConfig.collateralRisk = collateralRisk.toUint24();
    targetSpoke.updateReserveConfig(reserveId, reserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function addCollateralFactor(
    address spoke,
    uint256 reserveId,
    uint16 collateralFactor
  ) external restricted returns (uint24) {
    ISpoke targetSpoke = ISpoke(spoke);
    ISpoke.DynamicReserveConfig memory dynamicReserveConfig = targetSpoke.getDynamicReserveConfig(
      reserveId,
      _getReserveLastDynamicConfigKey(spoke, reserveId)
    );
    dynamicReserveConfig.collateralFactor = collateralFactor;
    return targetSpoke.addDynamicReserveConfig(reserveId, dynamicReserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateCollateralFactor(
    address spoke,
    uint256 reserveId,
    uint24 dynamicConfigKey,
    uint16 collateralFactor
  ) external restricted {
    ISpoke targetSpoke = ISpoke(spoke);
    ISpoke.DynamicReserveConfig memory dynamicReserveConfig = targetSpoke.getDynamicReserveConfig(
      reserveId,
      dynamicConfigKey
    );
    dynamicReserveConfig.collateralFactor = collateralFactor;
    targetSpoke.updateDynamicReserveConfig(reserveId, dynamicConfigKey, dynamicReserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function addMaxLiquidationBonus(
    address spoke,
    uint256 reserveId,
    uint256 maxLiquidationBonus
  ) external restricted returns (uint24) {
    ISpoke targetSpoke = ISpoke(spoke);
    ISpoke.DynamicReserveConfig memory dynamicReserveConfig = targetSpoke.getDynamicReserveConfig(
      reserveId,
      _getReserveLastDynamicConfigKey(spoke, reserveId)
    );
    dynamicReserveConfig.maxLiquidationBonus = maxLiquidationBonus.toUint32();
    return targetSpoke.addDynamicReserveConfig(reserveId, dynamicReserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateMaxLiquidationBonus(
    address spoke,
    uint256 reserveId,
    uint24 dynamicConfigKey,
    uint256 maxLiquidationBonus
  ) external restricted {
    ISpoke targetSpoke = ISpoke(spoke);
    ISpoke.DynamicReserveConfig memory dynamicReserveConfig = targetSpoke.getDynamicReserveConfig(
      reserveId,
      dynamicConfigKey
    );
    dynamicReserveConfig.maxLiquidationBonus = maxLiquidationBonus.toUint32();
    targetSpoke.updateDynamicReserveConfig(reserveId, dynamicConfigKey, dynamicReserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function addLiquidationFee(
    address spoke,
    uint256 reserveId,
    uint256 liquidationFee
  ) external restricted returns (uint24) {
    ISpoke targetSpoke = ISpoke(spoke);
    ISpoke.DynamicReserveConfig memory dynamicReserveConfig = targetSpoke.getDynamicReserveConfig(
      reserveId,
      _getReserveLastDynamicConfigKey(spoke, reserveId)
    );
    dynamicReserveConfig.liquidationFee = liquidationFee.toUint16();
    return targetSpoke.addDynamicReserveConfig(reserveId, dynamicReserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateLiquidationFee(
    address spoke,
    uint256 reserveId,
    uint24 dynamicConfigKey,
    uint256 liquidationFee
  ) external restricted {
    ISpoke targetSpoke = ISpoke(spoke);
    ISpoke.DynamicReserveConfig memory dynamicReserveConfig = targetSpoke.getDynamicReserveConfig(
      reserveId,
      dynamicConfigKey
    );
    dynamicReserveConfig.liquidationFee = liquidationFee.toUint16();
    targetSpoke.updateDynamicReserveConfig(reserveId, dynamicConfigKey, dynamicReserveConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function addDynamicReserveConfig(
    address spoke,
    uint256 reserveId,
    ISpoke.DynamicReserveConfig calldata dynamicConfig
  ) external restricted returns (uint24) {
    return ISpoke(spoke).addDynamicReserveConfig(reserveId, dynamicConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateDynamicReserveConfig(
    address spoke,
    uint256 reserveId,
    uint24 dynamicConfigKey,
    ISpoke.DynamicReserveConfig calldata dynamicConfig
  ) external restricted {
    ISpoke(spoke).updateDynamicReserveConfig(reserveId, dynamicConfigKey, dynamicConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function pauseAllReserves(address spoke) external restricted {
    ISpoke targetSpoke = ISpoke(spoke);
    uint256 reserveCount = targetSpoke.getReserveCount();
    for (uint256 reserveId = 0; reserveId < reserveCount; ++reserveId) {
      ISpoke.ReserveConfig memory reserveConfig = targetSpoke.getReserveConfig(reserveId);
      reserveConfig.paused = true;
      targetSpoke.updateReserveConfig(reserveId, reserveConfig);
    }
  }

  /// @inheritdoc ISpokeConfigurator
  function freezeAllReserves(address spoke) external restricted {
    ISpoke targetSpoke = ISpoke(spoke);
    uint256 reserveCount = targetSpoke.getReserveCount();
    for (uint256 reserveId = 0; reserveId < reserveCount; ++reserveId) {
      ISpoke.ReserveConfig memory reserveConfig = targetSpoke.getReserveConfig(reserveId);
      reserveConfig.frozen = true;
      targetSpoke.updateReserveConfig(reserveId, reserveConfig);
    }
  }

  /// @inheritdoc ISpokeConfigurator
  function updatePositionManager(
    address spoke,
    address positionManager,
    bool active
  ) external restricted {
    ISpoke(spoke).updatePositionManager(positionManager, active);
  }

  /// @inheritdoc ISpokeConfigurator
  function getMaxReserves(address spoke) external view returns (uint256) {
    return _maxReserves[spoke];
  }

  /// @dev Returns the last dynamic config key of the reserve for the specified Spoke.
  function _getReserveLastDynamicConfigKey(
    address spoke,
    uint256 reserveId
  ) internal view returns (uint24) {
    return ISpoke(spoke).getReserve(reserveId).dynamicConfigKey;
  }
}
