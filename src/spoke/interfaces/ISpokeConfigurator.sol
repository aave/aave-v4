// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title ISpokeConfigurator
/// @author Aave Labs
/// @notice Interface for the SpokeConfigurator.
/// @dev Reserves are addressed by `(spoke, hub, underlying)`; the reserve identifier is resolved on the Spoke.
interface ISpokeConfigurator {
  /// @notice Emitted when the price source of a reserve is updated.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param reserveId The identifier of the reserve.
  /// @param oldPriceSource The previous price source.
  /// @param newPriceSource The new price source.
  event ReservePriceSourceUpdated(
    address indexed spoke,
    address indexed hub,
    address indexed underlying,
    uint256 reserveId,
    address oldPriceSource,
    address newPriceSource
  );

  /// @notice Emitted when the paused flag of a reserve is updated.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param reserveId The identifier of the reserve.
  /// @param oldPaused The previous paused flag.
  /// @param newPaused The new paused flag.
  event ReservePausedUpdated(
    address indexed spoke,
    address indexed hub,
    address indexed underlying,
    uint256 reserveId,
    bool oldPaused,
    bool newPaused
  );

  /// @notice Emitted when the frozen flag of a reserve is updated.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param reserveId The identifier of the reserve.
  /// @param oldFrozen The previous frozen flag.
  /// @param newFrozen The new frozen flag.
  event ReserveFrozenUpdated(
    address indexed spoke,
    address indexed hub,
    address indexed underlying,
    uint256 reserveId,
    bool oldFrozen,
    bool newFrozen
  );

  /// @notice Emitted when the borrowable flag of a reserve is updated.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param reserveId The identifier of the reserve.
  /// @param oldBorrowable The previous borrowable flag.
  /// @param newBorrowable The new borrowable flag.
  event ReserveBorrowableUpdated(
    address indexed spoke,
    address indexed hub,
    address indexed underlying,
    uint256 reserveId,
    bool oldBorrowable,
    bool newBorrowable
  );

  /// @notice Emitted when the receiveSharesEnabled flag of a reserve is updated.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param reserveId The identifier of the reserve.
  /// @param oldReceiveSharesEnabled The previous receiveSharesEnabled flag.
  /// @param newReceiveSharesEnabled The new receiveSharesEnabled flag.
  event ReserveReceiveSharesEnabledUpdated(
    address indexed spoke,
    address indexed hub,
    address indexed underlying,
    uint256 reserveId,
    bool oldReceiveSharesEnabled,
    bool newReceiveSharesEnabled
  );

  /// @notice Emitted when the collateral risk of a reserve is updated.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param reserveId The identifier of the reserve.
  /// @param oldCollateralRisk The previous collateral risk.
  /// @param newCollateralRisk The new collateral risk.
  event ReserveCollateralRiskUpdated(
    address indexed spoke,
    address indexed hub,
    address indexed underlying,
    uint256 reserveId,
    uint256 oldCollateralRisk,
    uint256 newCollateralRisk
  );

  /// @notice Emitted when the liquidation target health factor of a Spoke is updated.
  /// @param spoke The address of the Spoke.
  /// @param oldTargetHealthFactor The previous target health factor.
  /// @param newTargetHealthFactor The new target health factor.
  event LiquidationTargetHealthFactorUpdated(
    address indexed spoke,
    uint256 oldTargetHealthFactor,
    uint256 newTargetHealthFactor
  );

  /// @notice Emitted when the health factor for max liquidation bonus of a Spoke is updated.
  /// @param spoke The address of the Spoke.
  /// @param oldHealthFactorForMaxBonus The previous health factor for max bonus.
  /// @param newHealthFactorForMaxBonus The new health factor for max bonus.
  event HealthFactorForMaxBonusUpdated(
    address indexed spoke,
    uint256 oldHealthFactorForMaxBonus,
    uint256 newHealthFactorForMaxBonus
  );

  /// @notice Emitted when the liquidation bonus factor of a Spoke is updated.
  /// @param spoke The address of the Spoke.
  /// @param oldLiquidationBonusFactor The previous liquidation bonus factor.
  /// @param newLiquidationBonusFactor The new liquidation bonus factor.
  event LiquidationBonusFactorUpdated(
    address indexed spoke,
    uint256 oldLiquidationBonusFactor,
    uint256 newLiquidationBonusFactor
  );

  /// @notice Emitted when the collateral factor of a reserve's dynamic config is added or updated.
  /// @dev On an addition `oldKey` is the previous latest key; on an update `oldKey` equals `newKey`.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param reserveId The identifier of the reserve.
  /// @param oldKey The dynamic config key holding the previous value.
  /// @param newKey The dynamic config key holding the new value.
  /// @param oldCollateralFactor The previous collateral factor.
  /// @param newCollateralFactor The new collateral factor.
  event CollateralFactorUpdated(
    address indexed spoke,
    address indexed hub,
    address indexed underlying,
    uint256 reserveId,
    uint32 oldKey,
    uint32 newKey,
    uint256 oldCollateralFactor,
    uint256 newCollateralFactor
  );

  /// @notice Emitted when the max liquidation bonus of a reserve's dynamic config is added or updated.
  /// @dev On an addition `oldKey` is the previous latest key; on an update `oldKey` equals `newKey`.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param reserveId The identifier of the reserve.
  /// @param oldKey The dynamic config key holding the previous value.
  /// @param newKey The dynamic config key holding the new value.
  /// @param oldMaxLiquidationBonus The previous max liquidation bonus.
  /// @param newMaxLiquidationBonus The new max liquidation bonus.
  event MaxLiquidationBonusUpdated(
    address indexed spoke,
    address indexed hub,
    address indexed underlying,
    uint256 reserveId,
    uint32 oldKey,
    uint32 newKey,
    uint256 oldMaxLiquidationBonus,
    uint256 newMaxLiquidationBonus
  );

  /// @notice Emitted when the liquidation fee of a reserve's dynamic config is added or updated.
  /// @dev On an addition `oldKey` is the previous latest key; on an update `oldKey` equals `newKey`.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param reserveId The identifier of the reserve.
  /// @param oldKey The dynamic config key holding the previous value.
  /// @param newKey The dynamic config key holding the new value.
  /// @param oldLiquidationFee The previous liquidation fee.
  /// @param newLiquidationFee The new liquidation fee.
  event LiquidationFeeUpdated(
    address indexed spoke,
    address indexed hub,
    address indexed underlying,
    uint256 reserveId,
    uint32 oldKey,
    uint32 newKey,
    uint256 oldLiquidationFee,
    uint256 newLiquidationFee
  );

  /// @notice Emitted when the saved dynamic config key of a reserve is updated.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param reserveId The identifier of the reserve.
  /// @param oldSavedKey The previous saved dynamic config key.
  /// @param newSavedKey The new saved dynamic config key.
  event SavedDynamicConfigKeyUpdated(
    address indexed spoke,
    address indexed hub,
    address indexed underlying,
    uint256 reserveId,
    uint32 oldSavedKey,
    uint32 newSavedKey
  );

  /// @notice Emitted when the active flag of a Spoke's position manager is updated.
  /// @param spoke The address of the Spoke.
  /// @param positionManager The address of the position manager.
  /// @param oldActive The previous active flag.
  /// @param newActive The new active flag.
  event PositionManagerUpdated(
    address indexed spoke,
    address indexed positionManager,
    bool oldActive,
    bool newActive
  );

  /// @notice Thrown when an address parameter is the zero address.
  error InvalidAddress();

  /// @notice Thrown when freezing a reserve that is already frozen with a zero collateral factor.
  error ReserveAlreadyFrozen();

  /// @notice Thrown when unfreezing a reserve that is not frozen.
  error ReserveNotFrozen();

  /// @notice Thrown when restoring the collateral factor of a frozen reserve.
  error CannotRestoreFrozenReserve();

  /// @notice Thrown when zeroing the collateral factor of a reserve whose latest collateral factor is already zero.
  error CollateralFactorAlreadyZero();

  /// @notice Thrown when restoring the collateral factor of a reserve whose latest collateral factor is not zero.
  error CollateralFactorNotZero();

  /// @notice Thrown when the dynamic config at the saved key has a zero collateral factor.
  error InvalidSavedCollateralFactor();

  /// @notice Updates the price source of a reserve.
  /// @dev The price source must implement IPriceFeed.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param priceSource The new price source.
  function updateReservePriceSource(
    address spoke,
    address hub,
    address underlying,
    address priceSource
  ) external;

  /// @notice Updates the liquidation target health factor of a spoke.
  /// @param spoke The address of the Spoke.
  /// @param targetHealthFactor The new liquidation target health factor.
  function updateLiquidationTargetHealthFactor(address spoke, uint256 targetHealthFactor) external;

  /// @notice Updates the health factor for max liquidation bonus of a spoke.
  /// @param spoke The address of the Spoke.
  /// @param healthFactorForMaxBonus The new health factor for max liquidation bonus.
  function updateHealthFactorForMaxBonus(address spoke, uint256 healthFactorForMaxBonus) external;

  /// @notice Updates the liquidation bonus factor of a spoke.
  /// @param spoke The address of the Spoke.
  /// @param liquidationBonusFactor The new liquidation bonus factor.
  function updateLiquidationBonusFactor(address spoke, uint256 liquidationBonusFactor) external;

  /// @notice Updates the liquidation config of a spoke.
  /// @param spoke The address of the Spoke.
  /// @param liquidationConfig The new liquidation config.
  function updateLiquidationConfig(
    address spoke,
    ISpoke.LiquidationConfig calldata liquidationConfig
  ) external;

  /// @notice Adds a new reserve to a spoke.
  /// @dev The asset corresponding to the reserve must be already listed on the Hub.
  /// @dev The price source must implement IPriceFeed.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub where the asset corresponding to the reserve is listed.
  /// @param underlying The address of the underlying asset.
  /// @param priceSource The address of the price source.
  /// @param config The configuration of the reserve.
  /// @param dynamicConfig The dynamic configuration of the reserve.
  /// @return reserveId The identifier of the reserve.
  function addReserve(
    address spoke,
    address hub,
    address underlying,
    address priceSource,
    ISpoke.ReserveConfig calldata config,
    ISpoke.DynamicReserveConfig calldata dynamicConfig
  ) external returns (uint256);

  /// @notice Updates the paused flag of a reserve.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param paused The new paused flag.
  function updatePaused(address spoke, address hub, address underlying, bool paused) external;

  /// @notice Updates the borrowable flag of a reserve.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param borrowable The new borrowable flag.
  function updateBorrowable(
    address spoke,
    address hub,
    address underlying,
    bool borrowable
  ) external;

  /// @notice Updates whether receiving shares on liquidation is enabled.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param receiveSharesEnabled The new receiveSharesEnabled flag.
  function updateReceiveSharesEnabled(
    address spoke,
    address hub,
    address underlying,
    bool receiveSharesEnabled
  ) external;

  /// @notice Updates the collateral risk of a reserve.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param collateralRisk The new collateral risk.
  function updateCollateralRisk(
    address spoke,
    address hub,
    address underlying,
    uint256 collateralRisk
  ) external;

  /// @notice Adds a dynamic config to a reserve, identical to the latest one but with the specified collateral factor.
  /// @dev Taking the latest collateral factor from non-zero to zero saves the previous latest key as the restore target.
  /// @dev A non-zero collateral factor is allowed on a frozen reserve and lifts the zero collateral factor applied by the freeze.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param collateralFactor The new collateral factor.
  /// @return The dynamicConfigKey of the added dynamic configuration.
  function addCollateralFactor(
    address spoke,
    address hub,
    address underlying,
    uint16 collateralFactor
  ) external returns (uint32);

  /// @notice Updates an existing collateral factor of a reserve at the specified key.
  /// @dev Updating the saved key changes the dynamic config re-added by `restoreCollateralFactor`.
  /// @dev Raising the collateral factor of a key with a zero collateral factor applies to every
  /// position bound to that key, including while the reserve is frozen.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param dynamicConfigKey The key of the dynamic config to update.
  /// @param collateralFactor The new collateral factor.
  function updateCollateralFactor(
    address spoke,
    address hub,
    address underlying,
    uint32 dynamicConfigKey,
    uint16 collateralFactor
  ) external;

  /// @notice Adds a dynamic config to a reserve, identical to the latest one but with the specified max liquidation bonus.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param maxLiquidationBonus The new max liquidation bonus.
  /// @return The dynamicConfigKey of the added dynamic configuration.
  function addMaxLiquidationBonus(
    address spoke,
    address hub,
    address underlying,
    uint256 maxLiquidationBonus
  ) external returns (uint32);

  /// @notice Updates an existing liquidation bonus of a reserve at the specified key.
  /// @dev Updating the saved key changes the dynamic config re-added by `restoreCollateralFactor`.
  /// @dev Reverts on a key with a zero collateral factor, since the Spoke rejects zero collateral
  /// factors on update; use the `add*` variant during a freeze.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param dynamicConfigKey The key of the dynamic config to update.
  /// @param maxLiquidationBonus The new liquidation bonus.
  function updateMaxLiquidationBonus(
    address spoke,
    address hub,
    address underlying,
    uint32 dynamicConfigKey,
    uint256 maxLiquidationBonus
  ) external;

  /// @notice Adds a dynamic config to a reserve, identical to the latest one but with the specified liquidation fee.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param liquidationFee The new liquidation fee.
  /// @return The dynamicConfigKey of the added dynamic configuration.
  function addLiquidationFee(
    address spoke,
    address hub,
    address underlying,
    uint256 liquidationFee
  ) external returns (uint32);

  /// @notice Updates an existing liquidation fee of a reserve at the specified key.
  /// @dev Updating the saved key changes the dynamic config re-added by `restoreCollateralFactor`.
  /// @dev Reverts on a key with a zero collateral factor, since the Spoke rejects zero collateral
  /// factors on update; use the `add*` variant during a freeze.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param dynamicConfigKey The key of the dynamic config to update.
  /// @param liquidationFee The new liquidation fee.
  function updateLiquidationFee(
    address spoke,
    address hub,
    address underlying,
    uint32 dynamicConfigKey,
    uint256 liquidationFee
  ) external;

  /// @notice Adds a dynamic config to a reserve.
  /// @dev Taking the latest collateral factor from non-zero to zero saves the previous latest key as the restore target.
  /// @dev A non-zero collateral factor is allowed on a frozen reserve and lifts the zero collateral factor applied by the freeze.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param dynamicConfig The new dynamic config.
  /// @return dynamicConfigKey The key of the added dynamic config.
  function addDynamicReserveConfig(
    address spoke,
    address hub,
    address underlying,
    ISpoke.DynamicReserveConfig calldata dynamicConfig
  ) external returns (uint32);

  /// @notice Updates the dynamic config of a reserve at the specified key.
  /// @dev Updating the saved key changes the dynamic config re-added by `restoreCollateralFactor`.
  /// @dev Raising the collateral factor of a key with a zero collateral factor applies to every
  /// position bound to that key, including while the reserve is frozen.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param dynamicConfigKey The key of the dynamic config to update.
  /// @param dynamicConfig The new dynamic config.
  function updateDynamicReserveConfig(
    address spoke,
    address hub,
    address underlying,
    uint32 dynamicConfigKey,
    ISpoke.DynamicReserveConfig calldata dynamicConfig
  ) external;

  /// @notice Pauses all reserves of a spoke.
  /// @param spoke The address of the Spoke.
  function pauseAllReserves(address spoke) external;

  /// @notice Pauses a reserve of a spoke.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  function pauseReserve(address spoke, address hub, address underlying) external;

  /// @notice Freezes a reserve and zeroes its collateral factor.
  /// @dev Sets the frozen flag if not set. If the latest collateral factor is non-zero, adds a copy of the
  /// latest dynamic config with a zero collateral factor and saves the previous latest key as the restore target.
  /// @dev Existing positions keep their dynamic config key until refreshed; on refresh (borrow, withdraw,
  /// disabling collateral or `updateUserDynamicConfig`) the zero collateral factor applies and the health
  /// factor is re-validated.
  /// @dev Reverts if the reserve is already frozen and its latest collateral factor is zero.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  function freezeReserve(address spoke, address hub, address underlying) external;

  /// @notice Unfreezes a reserve.
  /// @dev Only clears the frozen flag; the collateral factor is restored separately via `restoreCollateralFactor`.
  /// @dev Reverts if the reserve is not frozen.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  function unfreezeReserve(address spoke, address hub, address underlying) external;

  /// @notice Freezes all reserves of a spoke and zeroes their collateral factors.
  /// @dev Applies `freezeReserve` to each reserve, skipping reserves already frozen with a zero collateral factor.
  /// @param spoke The address of the Spoke.
  function freezeSpoke(address spoke) external;

  /// @notice Unfreezes all reserves of a spoke.
  /// @dev Applies `unfreezeReserve` to each reserve, skipping reserves that are not frozen.
  /// @param spoke The address of the Spoke.
  function unfreezeSpoke(address spoke) external;

  /// @notice Zeroes the collateral factor of a reserve without freezing it.
  /// @dev Adds a copy of the latest dynamic config with a zero collateral factor and saves the previous latest
  /// key as the restore target.
  /// @dev Reverts if the latest collateral factor is already zero.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  function zeroCollateralFactor(address spoke, address hub, address underlying) external;

  /// @notice Restores the collateral factor of a reserve by re-adding the full dynamic config at the saved key.
  /// @dev The re-added config is the one stored at the saved key, including its max liquidation bonus and
  /// liquidation fee; changes made to those fields on later keys are not carried over.
  /// @dev The saved key is only tracked through this configurator. If the collateral factor is zeroed directly
  /// on the Spoke, the saved key is stale and restore re-adds the older saved config; reserves zeroed before
  /// the saved key was tracked read key 0, which re-adds the listing config.
  /// @dev Reverts if the reserve is frozen, if the latest collateral factor is non-zero, or if the collateral
  /// factor at the saved key is zero.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @return The dynamicConfigKey of the added dynamic configuration.
  function restoreCollateralFactor(
    address spoke,
    address hub,
    address underlying
  ) external returns (uint32);

  /// @notice Updates the active flag of a spoke's position manager.
  /// @param spoke The address of the Spoke.
  /// @param positionManager The address of the position manager.
  /// @param active The new active flag.
  function updatePositionManager(address spoke, address positionManager, bool active) external;

  /// @notice Returns the saved dynamic config key of a reserve, re-added by `restoreCollateralFactor`.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @return The saved dynamic config key.
  function getSavedDynamicConfigKey(
    address spoke,
    address hub,
    address underlying
  ) external view returns (uint32);
}
