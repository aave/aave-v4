// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataTypes} from 'src/libraries/types/DataTypes.sol';

/**
 * @title ISpokeConfigurator
 * @author Aave Labs
 * @notice Interface for the SpokeConfigurator
 */
interface ISpokeConfigurator {
  /**
   * @notice Updates the oracle of a spoke.
   * @param spoke The address of the spoke.
   * @param oracle The new oracle.
   */
  function updateOracle(address spoke, address oracle) external;

  /**
   * @notice Updates the price source of a reserve.
   * @dev The price source must implement the AggregatorV3Interface.
   * @param spoke The address of the spoke.
   * @param reserveId The identifier of the reserve.
   * @param priceSource The new price source.
   */
  function updateReservePriceSource(address spoke, uint256 reserveId, address priceSource) external;

  /**
   * @notice Updates the liquidation close factor of a spoke.
   * @param spoke The address of the spoke.
   * @param closeFactor The new liquidation close factor.
   */
  function updateLiquidationCloseFactor(address spoke, uint256 closeFactor) external;

  /**
   * @notice Updates the health factor for max liquidation bonus of a spoke.
   * @param spoke The address of the spoke.
   * @param healthFactorForMaxBonus The new health factor for max liquidation bonus.
   */
  function updateHealthFactorForMaxBonus(address spoke, uint256 healthFactorForMaxBonus) external;

  /**
   * @notice Updates the liquidation bonus factor of a spoke.
   * @param spoke The address of the spoke.
   * @param liquidationBonusFactor The new liquidation bonus factor.
   */
  function updateLiquidationBonusFactor(address spoke, uint256 liquidationBonusFactor) external;

  /**
   * @notice Updates the liquidation config of a spoke.
   * @param spoke The address of the spoke.
   * @param liquidationConfig The new liquidation config.
   */
  function updateLiquidationConfig(
    address spoke,
    DataTypes.LiquidationConfig calldata liquidationConfig
  ) external;

  /**
   * @notice Adds a new reserve to a spoke.
   * @dev The price source must implement the AggregatorV3Interface.
   * @param spoke The address of the spoke.
   * @param hub The address of the hub where the asset is listed.
   * @param assetId The identifier of the asset.
   * @param priceSource The address of the price source.
   * @param config The configuration of the reserve.
   * @param dynamicConfig The dynamic configuration of the reserve.
   * @return reserveId The identifier of the reserve.
   */
  function addReserve(
    address spoke,
    address hub,
    uint256 assetId,
    address priceSource,
    DataTypes.ReserveConfig calldata config,
    DataTypes.DynamicReserveConfig calldata dynamicConfig
  ) external returns (uint256 reserveId);

  /**
   * @notice Updates the paused flag of a reserve.
   * @param spoke The address of the spoke.
   * @param reserveId The identifier of the reserve.
   * @param paused The new paused flag.
   */
  function updatePaused(address spoke, uint256 reserveId, bool paused) external;

  /**
   * @notice Updates the frozen flag of a reserve.
   * @param spoke The address of the spoke.
   * @param reserveId The identifier of the reserve.
   * @param frozen The new frozen flag.
   */
  function updateFrozen(address spoke, uint256 reserveId, bool frozen) external;

  /**
   * @notice Updates the borrowable flag of a reserve.
   * @param spoke The address of the spoke.
   * @param reserveId The identifier of the reserve.
   * @param borrowable The new borrowable flag.
   */
  function updateBorrowable(address spoke, uint256 reserveId, bool borrowable) external;

  /**
   * @notice Updates the collateral risk of a reserve.
   * @param spoke The address of the spoke.
   * @param reserveId The identifier of the reserve.
   * @param collateralRisk The new collateral risk.
   */
  function updateCollateralRisk(address spoke, uint256 reserveId, uint256 collateralRisk) external;

  /**
   * @notice Adds a dynamic config to a reserve, identical to the latest one but with the specified collateral factor.
   * @param spoke The address of the spoke.
   * @param reserveId The identifier of the reserve.
   * @param collateralFactor The new collateral factor.
   */
  function addCollateralFactor(address spoke, uint256 reserveId, uint16 collateralFactor) external;

  /**
   * @notice Updates an existing collateral factor of a reserve at the specified key.
   * @param spoke The address of the spoke.
   * @param reserveId The identifier of the reserve.
   * @param configKey The key of the dynamic config to update.
   * @param collateralFactor The new collateral factor.
   */
  function updateCollateralFactor(
    address spoke,
    uint256 reserveId,
    uint16 configKey,
    uint16 collateralFactor
  ) external;

  /**
   * @notice Adds a dynamic config to a reserve, identical to the latest one but with the specified liquidation bonus.
   * @param spoke The address of the spoke.
   * @param reserveId The identifier of the reserve.
   * @param liquidationBonus The new liquidation bonus.
   */
  function addLiquidationBonus(address spoke, uint256 reserveId, uint256 liquidationBonus) external;

  /**
   * @notice Updates an existing liquidation bonus of a reserve at the specified key.
   * @param spoke The address of the spoke.
   * @param reserveId The identifier of the reserve.
   * @param configKey The key of the dynamic config to update.
   * @param liquidationBonus The new liquidation bonus.
   */
  function updateLiquidationBonus(
    address spoke,
    uint256 reserveId,
    uint16 configKey,
    uint256 liquidationBonus
  ) external;

  /**
   * @notice Adds a dynamic config to a reserve, identical to the latest one but with the specified liquidation fee.
   * @param spoke The address of the spoke.
   * @param reserveId The identifier of the reserve.
   * @param liquidationFee The new liquidation fee.
   */
  function addLiquidationFee(address spoke, uint256 reserveId, uint256 liquidationFee) external;

  /**
   * @notice Updates an existing liquidation fee of a reserve at the specified key.
   * @param spoke The address of the spoke.
   * @param reserveId The identifier of the reserve.
   * @param configKey The key of the dynamic config to update.
   * @param liquidationFee The new liquidation fee.
   */
  function updateLiquidationFee(
    address spoke,
    uint256 reserveId,
    uint16 configKey,
    uint256 liquidationFee
  ) external;

  /**
   * @notice Updates the config of a reserve.
   * @param spoke The address of the spoke.
   * @param reserveId The identifier of the reserve.
   * @param config The new reserve config.
   */
  function updateReserveConfig(
    address spoke,
    uint256 reserveId,
    DataTypes.ReserveConfig calldata config
  ) external;

  /**
   * @notice Adds a dynamic config to a reserve.
   * @param spoke The address of the spoke.
   * @param reserveId The identifier of the reserve.
   * @param dynamicConfig The new dynamic config.
   * @return configKey The key of the added dynamic config.
   */
  function addDynamicReserveConfig(
    address spoke,
    uint256 reserveId,
    DataTypes.DynamicReserveConfig calldata dynamicConfig
  ) external returns (uint16 configKey);

  /**
   * @notice Updates the dynamic config of a reserve at the specified key.
   * @param spoke The address of the spoke.
   * @param reserveId The identifier of the reserve.
   * @param configKey The key of the dynamic config to update.
   * @param dynamicConfig The new dynamic config.
   */
  function updateDynamicReserveConfig(
    address spoke,
    uint256 reserveId,
    uint16 configKey,
    DataTypes.DynamicReserveConfig calldata dynamicConfig
  ) external;

  /**
   * @notice Pauses all reserves of a spoke.
   * @param spoke The address of the spoke.
   */
  function pauseAllReserves(address spoke) external;

  /**
   * @notice Freezes all reserves of a spoke.
   * @param spoke The address of the spoke.
   */
  function freezeAllReserves(address spoke) external;

  /**
   * @notice Updates the active flag of a spoke's position manager.
   * @param spoke The address of the spoke.
   * @param positionManager The address of the position manager.
   * @param active The new active flag.
   */
  function updatePositionManager(address spoke, address positionManager, bool active) external;
}
