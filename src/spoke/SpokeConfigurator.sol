// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {AccessManagedUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/AccessManagedUpgradeable.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

/// @title SpokeConfigurator
/// @author Aave Labs
/// @notice Handles administrative functions on the Spoke.
/// @dev Must be granted permission by the Spoke.
abstract contract SpokeConfigurator is AccessManagedUpgradeable, ISpokeConfigurator {
  using SafeCast for uint256;

  /// @dev Identifies a reserve by both its addresses and its resolved identifier.
  struct ReserveKey {
    ISpoke spoke;
    address hub;
    address underlying;
    uint256 reserveId;
  }

  /// @dev Map of Spoke addresses and reserve identifiers to the dynamic config key re-added on restore.
  mapping(address spoke => mapping(uint256 reserveId => uint32 dynamicConfigKey))
    internal _savedDynamicConfigKey;

  /// @dev To be overridden by the inheriting SpokeConfigurator instance contract.
  function initialize(address authority) external virtual;

  /// @inheritdoc ISpokeConfigurator
  function updateReservePriceSource(
    address spoke,
    address hub,
    address underlying,
    address priceSource
  ) external restricted {
    ReserveKey memory key = _resolveReserveKey(spoke, hub, underlying);
    address oldPriceSource = IAaveOracle(key.spoke.ORACLE()).getReserveSource(key.reserveId);
    key.spoke.updateReservePriceSource(key.reserveId, priceSource);
    emit ReservePriceSourceUpdated(
      spoke,
      hub,
      underlying,
      key.reserveId,
      oldPriceSource,
      priceSource
    );
  }

  /// @inheritdoc ISpokeConfigurator
  function updateLiquidationTargetHealthFactor(
    address spoke,
    uint256 targetHealthFactor
  ) external restricted {
    ISpoke targetSpoke = ISpoke(spoke);
    ISpoke.LiquidationConfig memory liquidationConfig = targetSpoke.getLiquidationConfig();
    uint256 oldTargetHealthFactor = liquidationConfig.targetHealthFactor;
    liquidationConfig.targetHealthFactor = targetHealthFactor.toUint128();
    targetSpoke.updateLiquidationConfig(liquidationConfig);
    emit LiquidationTargetHealthFactorUpdated(spoke, oldTargetHealthFactor, targetHealthFactor);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateHealthFactorForMaxBonus(
    address spoke,
    uint256 healthFactorForMaxBonus
  ) external restricted {
    ISpoke targetSpoke = ISpoke(spoke);
    ISpoke.LiquidationConfig memory liquidationConfig = targetSpoke.getLiquidationConfig();
    uint256 oldHealthFactorForMaxBonus = liquidationConfig.healthFactorForMaxBonus;
    liquidationConfig.healthFactorForMaxBonus = healthFactorForMaxBonus.toUint64();
    targetSpoke.updateLiquidationConfig(liquidationConfig);
    emit HealthFactorForMaxBonusUpdated(spoke, oldHealthFactorForMaxBonus, healthFactorForMaxBonus);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateLiquidationBonusFactor(
    address spoke,
    uint256 liquidationBonusFactor
  ) external restricted {
    ISpoke targetSpoke = ISpoke(spoke);
    ISpoke.LiquidationConfig memory liquidationConfig = targetSpoke.getLiquidationConfig();
    uint256 oldLiquidationBonusFactor = liquidationConfig.liquidationBonusFactor;
    liquidationConfig.liquidationBonusFactor = liquidationBonusFactor.toUint16();
    targetSpoke.updateLiquidationConfig(liquidationConfig);
    emit LiquidationBonusFactorUpdated(spoke, oldLiquidationBonusFactor, liquidationBonusFactor);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateLiquidationConfig(
    address spoke,
    ISpoke.LiquidationConfig calldata liquidationConfig
  ) external restricted {
    ISpoke targetSpoke = ISpoke(spoke);
    ISpoke.LiquidationConfig memory oldConfig = targetSpoke.getLiquidationConfig();
    targetSpoke.updateLiquidationConfig(liquidationConfig);
    emit LiquidationTargetHealthFactorUpdated(
      spoke,
      oldConfig.targetHealthFactor,
      liquidationConfig.targetHealthFactor
    );
    emit HealthFactorForMaxBonusUpdated(
      spoke,
      oldConfig.healthFactorForMaxBonus,
      liquidationConfig.healthFactorForMaxBonus
    );
    emit LiquidationBonusFactorUpdated(
      spoke,
      oldConfig.liquidationBonusFactor,
      liquidationConfig.liquidationBonusFactor
    );
  }

  /// @inheritdoc ISpokeConfigurator
  function addReserve(
    address spoke,
    address hub,
    address underlying,
    address priceSource,
    ISpoke.ReserveConfig calldata config,
    ISpoke.DynamicReserveConfig calldata dynamicConfig
  ) external restricted returns (uint256) {
    uint256 reserveId = ISpoke(spoke).addReserve(
      hub,
      IHubBase(hub).getAssetId(underlying),
      priceSource,
      config,
      dynamicConfig
    );
    ReserveKey memory key = ReserveKey({
      spoke: ISpoke(spoke),
      hub: hub,
      underlying: underlying,
      reserveId: reserveId
    });
    ISpoke.ReserveConfig memory emptyConfig;
    ISpoke.DynamicReserveConfig memory emptyDynamicConfig;
    emit ReservePriceSourceUpdated(spoke, hub, underlying, reserveId, address(0), priceSource);
    _emitReserveConfigUpdated(key, emptyConfig, config);
    _emitDynamicReserveConfigUpdated(key, 0, 0, emptyDynamicConfig, dynamicConfig);
    return reserveId;
  }

  /// @inheritdoc ISpokeConfigurator
  function updatePaused(
    address spoke,
    address hub,
    address underlying,
    bool paused
  ) external restricted {
    _updatePaused(_resolveReserveKey(spoke, hub, underlying), paused);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateBorrowable(
    address spoke,
    address hub,
    address underlying,
    bool borrowable
  ) external restricted {
    ReserveKey memory key = _resolveReserveKey(spoke, hub, underlying);
    ISpoke.ReserveConfig memory reserveConfig = key.spoke.getReserveConfig(key.reserveId);
    bool oldBorrowable = reserveConfig.borrowable;
    reserveConfig.borrowable = borrowable;
    key.spoke.updateReserveConfig(key.reserveId, reserveConfig);
    emit ReserveBorrowableUpdated(spoke, hub, underlying, key.reserveId, oldBorrowable, borrowable);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateReceiveSharesEnabled(
    address spoke,
    address hub,
    address underlying,
    bool receiveSharesEnabled
  ) external restricted {
    ReserveKey memory key = _resolveReserveKey(spoke, hub, underlying);
    ISpoke.ReserveConfig memory reserveConfig = key.spoke.getReserveConfig(key.reserveId);
    bool oldReceiveSharesEnabled = reserveConfig.receiveSharesEnabled;
    reserveConfig.receiveSharesEnabled = receiveSharesEnabled;
    key.spoke.updateReserveConfig(key.reserveId, reserveConfig);
    emit ReserveReceiveSharesEnabledUpdated(
      spoke,
      hub,
      underlying,
      key.reserveId,
      oldReceiveSharesEnabled,
      receiveSharesEnabled
    );
  }

  /// @inheritdoc ISpokeConfigurator
  function updateCollateralRisk(
    address spoke,
    address hub,
    address underlying,
    uint256 collateralRisk
  ) external restricted {
    ReserveKey memory key = _resolveReserveKey(spoke, hub, underlying);
    ISpoke.ReserveConfig memory reserveConfig = key.spoke.getReserveConfig(key.reserveId);
    uint256 oldCollateralRisk = reserveConfig.collateralRisk;
    reserveConfig.collateralRisk = collateralRisk.toUint24();
    key.spoke.updateReserveConfig(key.reserveId, reserveConfig);
    emit ReserveCollateralRiskUpdated(
      spoke,
      hub,
      underlying,
      key.reserveId,
      oldCollateralRisk,
      collateralRisk
    );
  }

  /// @inheritdoc ISpokeConfigurator
  function addCollateralFactor(
    address spoke,
    address hub,
    address underlying,
    uint16 collateralFactor
  ) external restricted returns (uint32) {
    ReserveKey memory key = _resolveReserveKey(spoke, hub, underlying);
    (uint32 oldKey, ISpoke.DynamicReserveConfig memory oldConfig) = _getLatestDynamicConfig(key);
    ISpoke.DynamicReserveConfig memory newConfig = _copy(oldConfig);
    newConfig.collateralFactor = collateralFactor;
    return _addDynamicReserveConfig(key, oldKey, oldConfig, newConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateCollateralFactor(
    address spoke,
    address hub,
    address underlying,
    uint32 dynamicConfigKey,
    uint16 collateralFactor
  ) external restricted {
    ReserveKey memory key = _resolveReserveKey(spoke, hub, underlying);
    ISpoke.DynamicReserveConfig memory dynamicConfig = key.spoke.getDynamicReserveConfig(
      key.reserveId,
      dynamicConfigKey
    );
    uint256 oldCollateralFactor = dynamicConfig.collateralFactor;
    dynamicConfig.collateralFactor = collateralFactor;
    key.spoke.updateDynamicReserveConfig(key.reserveId, dynamicConfigKey, dynamicConfig);
    emit CollateralFactorUpdated(
      spoke,
      hub,
      underlying,
      key.reserveId,
      dynamicConfigKey,
      dynamicConfigKey,
      oldCollateralFactor,
      collateralFactor
    );
  }

  /// @inheritdoc ISpokeConfigurator
  function addMaxLiquidationBonus(
    address spoke,
    address hub,
    address underlying,
    uint256 maxLiquidationBonus
  ) external restricted returns (uint32) {
    ReserveKey memory key = _resolveReserveKey(spoke, hub, underlying);
    (uint32 oldKey, ISpoke.DynamicReserveConfig memory oldConfig) = _getLatestDynamicConfig(key);
    ISpoke.DynamicReserveConfig memory newConfig = _copy(oldConfig);
    newConfig.maxLiquidationBonus = maxLiquidationBonus.toUint32();
    return _addDynamicReserveConfig(key, oldKey, oldConfig, newConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateMaxLiquidationBonus(
    address spoke,
    address hub,
    address underlying,
    uint32 dynamicConfigKey,
    uint256 maxLiquidationBonus
  ) external restricted {
    ReserveKey memory key = _resolveReserveKey(spoke, hub, underlying);
    ISpoke.DynamicReserveConfig memory dynamicConfig = key.spoke.getDynamicReserveConfig(
      key.reserveId,
      dynamicConfigKey
    );
    uint256 oldMaxLiquidationBonus = dynamicConfig.maxLiquidationBonus;
    dynamicConfig.maxLiquidationBonus = maxLiquidationBonus.toUint32();
    key.spoke.updateDynamicReserveConfig(key.reserveId, dynamicConfigKey, dynamicConfig);
    emit MaxLiquidationBonusUpdated(
      spoke,
      hub,
      underlying,
      key.reserveId,
      dynamicConfigKey,
      dynamicConfigKey,
      oldMaxLiquidationBonus,
      maxLiquidationBonus
    );
  }

  /// @inheritdoc ISpokeConfigurator
  function addLiquidationFee(
    address spoke,
    address hub,
    address underlying,
    uint256 liquidationFee
  ) external restricted returns (uint32) {
    ReserveKey memory key = _resolveReserveKey(spoke, hub, underlying);
    (uint32 oldKey, ISpoke.DynamicReserveConfig memory oldConfig) = _getLatestDynamicConfig(key);
    ISpoke.DynamicReserveConfig memory newConfig = _copy(oldConfig);
    newConfig.liquidationFee = liquidationFee.toUint16();
    return _addDynamicReserveConfig(key, oldKey, oldConfig, newConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateLiquidationFee(
    address spoke,
    address hub,
    address underlying,
    uint32 dynamicConfigKey,
    uint256 liquidationFee
  ) external restricted {
    ReserveKey memory key = _resolveReserveKey(spoke, hub, underlying);
    ISpoke.DynamicReserveConfig memory dynamicConfig = key.spoke.getDynamicReserveConfig(
      key.reserveId,
      dynamicConfigKey
    );
    uint256 oldLiquidationFee = dynamicConfig.liquidationFee;
    dynamicConfig.liquidationFee = liquidationFee.toUint16();
    key.spoke.updateDynamicReserveConfig(key.reserveId, dynamicConfigKey, dynamicConfig);
    emit LiquidationFeeUpdated(
      spoke,
      hub,
      underlying,
      key.reserveId,
      dynamicConfigKey,
      dynamicConfigKey,
      oldLiquidationFee,
      liquidationFee
    );
  }

  /// @inheritdoc ISpokeConfigurator
  function addDynamicReserveConfig(
    address spoke,
    address hub,
    address underlying,
    ISpoke.DynamicReserveConfig calldata dynamicConfig
  ) external restricted returns (uint32) {
    ReserveKey memory key = _resolveReserveKey(spoke, hub, underlying);
    (uint32 oldKey, ISpoke.DynamicReserveConfig memory oldConfig) = _getLatestDynamicConfig(key);
    return _addDynamicReserveConfig(key, oldKey, oldConfig, dynamicConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updateDynamicReserveConfig(
    address spoke,
    address hub,
    address underlying,
    uint32 dynamicConfigKey,
    ISpoke.DynamicReserveConfig calldata dynamicConfig
  ) external restricted {
    ReserveKey memory key = _resolveReserveKey(spoke, hub, underlying);
    ISpoke.DynamicReserveConfig memory oldConfig = key.spoke.getDynamicReserveConfig(
      key.reserveId,
      dynamicConfigKey
    );
    key.spoke.updateDynamicReserveConfig(key.reserveId, dynamicConfigKey, dynamicConfig);
    _emitDynamicReserveConfigUpdated(
      key,
      dynamicConfigKey,
      dynamicConfigKey,
      oldConfig,
      dynamicConfig
    );
  }

  /// @inheritdoc ISpokeConfigurator
  function pauseAllReserves(address spoke) external restricted {
    ISpoke targetSpoke = ISpoke(spoke);
    uint256 reserveCount = targetSpoke.getReserveCount();
    for (uint256 reserveId = 0; reserveId < reserveCount; ++reserveId) {
      _updatePaused(_getReserveKey(targetSpoke, reserveId), true);
    }
  }

  /// @inheritdoc ISpokeConfigurator
  function pauseReserve(address spoke, address hub, address underlying) external restricted {
    _updatePaused(_resolveReserveKey(spoke, hub, underlying), true);
  }

  /// @inheritdoc ISpokeConfigurator
  function freezeReserve(address spoke, address hub, address underlying) external restricted {
    require(_freezeReserve(_resolveReserveKey(spoke, hub, underlying)), ReserveAlreadyFrozen());
  }

  /// @inheritdoc ISpokeConfigurator
  function unfreezeReserve(address spoke, address hub, address underlying) external restricted {
    require(_unfreezeReserve(_resolveReserveKey(spoke, hub, underlying)), ReserveNotFrozen());
  }

  /// @inheritdoc ISpokeConfigurator
  function freezeSpoke(address spoke) external restricted {
    ISpoke targetSpoke = ISpoke(spoke);
    uint256 reserveCount = targetSpoke.getReserveCount();
    for (uint256 reserveId = 0; reserveId < reserveCount; ++reserveId) {
      _freezeReserve(_getReserveKey(targetSpoke, reserveId));
    }
  }

  /// @inheritdoc ISpokeConfigurator
  function unfreezeSpoke(address spoke) external restricted {
    ISpoke targetSpoke = ISpoke(spoke);
    uint256 reserveCount = targetSpoke.getReserveCount();
    for (uint256 reserveId = 0; reserveId < reserveCount; ++reserveId) {
      _unfreezeReserve(_getReserveKey(targetSpoke, reserveId));
    }
  }

  /// @inheritdoc ISpokeConfigurator
  function zeroCollateralFactor(
    address spoke,
    address hub,
    address underlying
  ) external restricted {
    require(
      _zeroCollateralFactor(_resolveReserveKey(spoke, hub, underlying)),
      CollateralFactorAlreadyZero()
    );
  }

  /// @inheritdoc ISpokeConfigurator
  function restoreCollateralFactor(
    address spoke,
    address hub,
    address underlying
  ) external restricted returns (uint32) {
    ReserveKey memory key = _resolveReserveKey(spoke, hub, underlying);
    require(!key.spoke.getReserveConfig(key.reserveId).frozen, CannotRestoreFrozenReserve());
    (uint32 oldKey, ISpoke.DynamicReserveConfig memory oldConfig) = _getLatestDynamicConfig(key);
    require(oldConfig.collateralFactor == 0, CollateralFactorNotZero());
    ISpoke.DynamicReserveConfig memory savedConfig = key.spoke.getDynamicReserveConfig(
      key.reserveId,
      _savedDynamicConfigKey[spoke][key.reserveId]
    );
    require(savedConfig.collateralFactor != 0, InvalidSavedCollateralFactor());
    // Re-adds the full saved config rather than only its collateral factor, so max liquidation bonus and
    // liquidation fee changes made on later keys are dropped. Open for review; may change to restore the
    // collateral factor alone.
    return _addDynamicReserveConfig(key, oldKey, oldConfig, savedConfig);
  }

  /// @inheritdoc ISpokeConfigurator
  function updatePositionManager(
    address spoke,
    address positionManager,
    bool active
  ) external restricted {
    ISpoke targetSpoke = ISpoke(spoke);
    bool oldActive = targetSpoke.isPositionManagerActive(positionManager);
    targetSpoke.updatePositionManager(positionManager, active);
    emit PositionManagerUpdated(spoke, positionManager, oldActive, active);
  }

  /// @inheritdoc ISpokeConfigurator
  function getSavedDynamicConfigKey(
    address spoke,
    address hub,
    address underlying
  ) external view returns (uint32) {
    return _savedDynamicConfigKey[spoke][_resolveReserveKey(spoke, hub, underlying).reserveId];
  }

  /// @dev Sets the frozen flag and zeroes the collateral factor. Returns false if neither changed.
  function _freezeReserve(ReserveKey memory key) internal returns (bool) {
    ISpoke.ReserveConfig memory reserveConfig = key.spoke.getReserveConfig(key.reserveId);
    bool frozenUpdated = !reserveConfig.frozen;
    if (frozenUpdated) {
      reserveConfig.frozen = true;
      key.spoke.updateReserveConfig(key.reserveId, reserveConfig);
      emit ReserveFrozenUpdated(
        address(key.spoke),
        key.hub,
        key.underlying,
        key.reserveId,
        false,
        true
      );
    }
    bool collateralFactorZeroed = _zeroCollateralFactor(key);
    return frozenUpdated || collateralFactorZeroed;
  }

  /// @dev Clears the frozen flag. Returns false if the reserve is not frozen.
  function _unfreezeReserve(ReserveKey memory key) internal returns (bool) {
    ISpoke.ReserveConfig memory reserveConfig = key.spoke.getReserveConfig(key.reserveId);
    if (!reserveConfig.frozen) {
      return false;
    }
    reserveConfig.frozen = false;
    key.spoke.updateReserveConfig(key.reserveId, reserveConfig);
    emit ReserveFrozenUpdated(
      address(key.spoke),
      key.hub,
      key.underlying,
      key.reserveId,
      true,
      false
    );
    return true;
  }

  /// @dev Adds a copy of the latest dynamic config with a zero collateral factor. Returns false if the
  /// latest collateral factor is already zero.
  function _zeroCollateralFactor(ReserveKey memory key) internal returns (bool) {
    (uint32 oldKey, ISpoke.DynamicReserveConfig memory oldConfig) = _getLatestDynamicConfig(key);
    if (oldConfig.collateralFactor == 0) {
      return false;
    }
    ISpoke.DynamicReserveConfig memory newConfig = _copy(oldConfig);
    newConfig.collateralFactor = 0;
    _addDynamicReserveConfig(key, oldKey, oldConfig, newConfig);
    return true;
  }

  /// @dev Adds a dynamic config and saves `oldKey` as the restore target when the collateral factor goes
  /// from non-zero to zero.
  function _addDynamicReserveConfig(
    ReserveKey memory key,
    uint32 oldKey,
    ISpoke.DynamicReserveConfig memory oldConfig,
    ISpoke.DynamicReserveConfig memory newConfig
  ) internal returns (uint32) {
    uint32 newKey = key.spoke.addDynamicReserveConfig(key.reserveId, newConfig);
    _emitDynamicReserveConfigUpdated(key, oldKey, newKey, oldConfig, newConfig);
    if (oldConfig.collateralFactor != 0 && newConfig.collateralFactor == 0) {
      uint32 oldSavedKey = _savedDynamicConfigKey[address(key.spoke)][key.reserveId];
      _savedDynamicConfigKey[address(key.spoke)][key.reserveId] = oldKey;
      emit SavedDynamicConfigKeyUpdated(
        address(key.spoke),
        key.hub,
        key.underlying,
        key.reserveId,
        oldSavedKey,
        oldKey
      );
    }
    return newKey;
  }

  function _updatePaused(ReserveKey memory key, bool paused) internal {
    ISpoke.ReserveConfig memory reserveConfig = key.spoke.getReserveConfig(key.reserveId);
    bool oldPaused = reserveConfig.paused;
    reserveConfig.paused = paused;
    key.spoke.updateReserveConfig(key.reserveId, reserveConfig);
    emit ReservePausedUpdated(
      address(key.spoke),
      key.hub,
      key.underlying,
      key.reserveId,
      oldPaused,
      paused
    );
  }

  function _emitReserveConfigUpdated(
    ReserveKey memory key,
    ISpoke.ReserveConfig memory oldConfig,
    ISpoke.ReserveConfig memory newConfig
  ) internal {
    address spoke = address(key.spoke);
    emit ReservePausedUpdated(
      spoke,
      key.hub,
      key.underlying,
      key.reserveId,
      oldConfig.paused,
      newConfig.paused
    );
    emit ReserveFrozenUpdated(
      spoke,
      key.hub,
      key.underlying,
      key.reserveId,
      oldConfig.frozen,
      newConfig.frozen
    );
    emit ReserveBorrowableUpdated(
      spoke,
      key.hub,
      key.underlying,
      key.reserveId,
      oldConfig.borrowable,
      newConfig.borrowable
    );
    emit ReserveReceiveSharesEnabledUpdated(
      spoke,
      key.hub,
      key.underlying,
      key.reserveId,
      oldConfig.receiveSharesEnabled,
      newConfig.receiveSharesEnabled
    );
    emit ReserveCollateralRiskUpdated(
      spoke,
      key.hub,
      key.underlying,
      key.reserveId,
      oldConfig.collateralRisk,
      newConfig.collateralRisk
    );
  }

  function _emitDynamicReserveConfigUpdated(
    ReserveKey memory key,
    uint32 oldKey,
    uint32 newKey,
    ISpoke.DynamicReserveConfig memory oldConfig,
    ISpoke.DynamicReserveConfig memory newConfig
  ) internal {
    address spoke = address(key.spoke);
    emit CollateralFactorUpdated(
      spoke,
      key.hub,
      key.underlying,
      key.reserveId,
      oldKey,
      newKey,
      oldConfig.collateralFactor,
      newConfig.collateralFactor
    );
    emit MaxLiquidationBonusUpdated(
      spoke,
      key.hub,
      key.underlying,
      key.reserveId,
      oldKey,
      newKey,
      oldConfig.maxLiquidationBonus,
      newConfig.maxLiquidationBonus
    );
    emit LiquidationFeeUpdated(
      spoke,
      key.hub,
      key.underlying,
      key.reserveId,
      oldKey,
      newKey,
      oldConfig.liquidationFee,
      newConfig.liquidationFee
    );
  }

  function _getLatestDynamicConfig(
    ReserveKey memory key
  ) internal view returns (uint32, ISpoke.DynamicReserveConfig memory) {
    uint32 dynamicConfigKey = key.spoke.getReserve(key.reserveId).dynamicConfigKey;
    return (dynamicConfigKey, key.spoke.getDynamicReserveConfig(key.reserveId, dynamicConfigKey));
  }

  function _resolveReserveKey(
    address spoke,
    address hub,
    address underlying
  ) internal view returns (ReserveKey memory) {
    return
      ReserveKey({
        spoke: ISpoke(spoke),
        hub: hub,
        underlying: underlying,
        reserveId: ISpoke(spoke).getReserveId(hub, IHubBase(hub).getAssetId(underlying))
      });
  }

  function _getReserveKey(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (ReserveKey memory) {
    ISpoke.Reserve memory reserve = spoke.getReserve(reserveId);
    return
      ReserveKey({
        spoke: spoke,
        hub: address(reserve.hub),
        underlying: reserve.underlying,
        reserveId: reserveId
      });
  }

  function _copy(
    ISpoke.DynamicReserveConfig memory config
  ) internal pure returns (ISpoke.DynamicReserveConfig memory) {
    return
      ISpoke.DynamicReserveConfig({
        collateralFactor: config.collateralFactor,
        maxLiquidationBonus: config.maxLiquidationBonus,
        liquidationFee: config.liquidationFee
      });
  }
}
