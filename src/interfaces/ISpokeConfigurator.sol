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
   * @notice Updates the active flag of a reserve.
   * @param spoke The address of the spoke.
   * @param reserveId The identifier of the reserve.
   * @param active The new active flag.
   */
  function updateActive(address spoke, uint256 reserveId, bool active) external;

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
   * @notice Updates the collateral flag of a reserve.
   * @param spoke The address of the spoke.
   * @param reserveId The identifier of the reserve.
   * @param collateral The new collateral flag.
   */
  function updateCollateral(address spoke, uint256 reserveId, bool collateral) external;

  /**
   * @notice Updates the liquidity premium of a reserve.
   * @param spoke The address of the spoke.
   * @param reserveId The identifier of the reserve.
   * @param liquidityPremium The new liquidity premium.
   */
  function updateLiquidityPremium(
    address spoke,
    uint256 reserveId,
    uint256 liquidityPremium
  ) external;

  /**
   * @notice Updates the collateral factor of a reserve.
   * @param spoke The address of the spoke.
   * @param reserveId The identifier of the reserve.
   * @param collateralFactor The new collateral factor.
   */
  function updateCollateralFactor(
    address spoke,
    uint256 reserveId,
    uint16 collateralFactor
  ) external;

  /**
   * @notice Updates the liquidation bonus of a reserve.
   * @param spoke The address of the spoke.
   * @param reserveId The identifier of the reserve.
   * @param liquidationBonus The new liquidation bonus.
   */
  function updateLiquidationBonus(
    address spoke,
    uint256 reserveId,
    uint256 liquidationBonus
  ) external;

  /**
   * @notice Updates the liquidation fee of a reserve.
   * @param spoke The address of the spoke.
   * @param reserveId The identifier of the reserve.
   * @param liquidationFee The new liquidation fee.
   */
  function updateLiquidationFee(address spoke, uint256 reserveId, uint256 liquidationFee) external;

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
   * @notice Updates the dynamic config of a reserve.
   * @param spoke The address of the spoke.
   * @param reserveId The identifier of the reserve.
   * @param dynamicConfig The new dynamic config.
   */
  function updateDynamicReserveConfig(
    address spoke,
    uint256 reserveId,
    DataTypes.DynamicReserveConfig calldata dynamicConfig
  ) external;
}
