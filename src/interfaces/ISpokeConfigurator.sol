// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ISpokeConfigurator
 * @author Aave Labs
 * @notice Interface for the SpokeConfigurator
 */
interface ISpokeConfigurator {
  /**
   * @notice Updates the liquidation close factor of a spoke
   * @param spoke The address of the spoke
   * @param closeFactor The new liquidation close factor
   */
  function updateLiquidationCloseFactor(address spoke, uint256 closeFactor) external;

  /**
   * @notice Updates the liquidation health factor for max bonus of a spoke
   * @param spoke The address of the spoke
   * @param healthFactorForMaxBonus The new liquidation health factor for max bonus
   */
  function updateLiquidationHealthFactorForMaxBonus(
    address spoke,
    uint256 healthFactorForMaxBonus
  ) external;

  /**
   * @notice Updates the liquidation bonus factor of a spoke
   * @param spoke The address of the spoke
   * @param liquidationBonusFactor The new liquidation bonus factor
   */
  function updateLiquidationBonusFactor(address spoke, uint256 liquidationBonusFactor) external;

  /**
   * @notice Updates the active flag of a reserve
   * @param spoke The address of the spoke
   * @param reserveId The identifier of the reserve
   * @param active The new active flag
   */
  function updateActive(address spoke, uint256 reserveId, bool active) external;

  /**
   * @notice Updates the paused flag of a reserve
   * @param spoke The address of the spoke
   * @param reserveId The identifier of the reserve
   * @param paused The new paused flag
   */
  function updatePaused(address spoke, uint256 reserveId, bool paused) external;

  /**
   * @notice Updates the frozen flag of a reserve
   * @param spoke The address of the spoke
   * @param reserveId The identifier of the reserve
   * @param frozen The new frozen flag
   */
  function updateFrozen(address spoke, uint256 reserveId, bool frozen) external;

  /**
   * @notice Updates the borrowable flag of a reserve
   * @param spoke The address of the spoke
   * @param reserveId The identifier of the reserve
   * @param borrowable The new borrowable flag
   */
  function updateBorrowable(address spoke, uint256 reserveId, bool borrowable) external;

  /**
   * @notice Updates the collateral flag of a reserve
   * @param spoke The address of the spoke
   * @param reserveId The identifier of the reserve
   * @param collateral The new collateral flag
   */
  function updateCollateral(address spoke, uint256 reserveId, bool collateral) external;

  /**
   * @notice Updates the liquidation bonus of a reserve
   * @param spoke The address of the spoke
   * @param reserveId The identifier of the reserve
   * @param liquidationBonus The new liquidation bonus
   */
  function updateLiquidationBonus(
    address spoke,
    uint256 reserveId,
    uint256 liquidationBonus
  ) external;

  /**
   * @notice Updates the liquidity premium of a reserve
   * @param spoke The address of the spoke
   * @param reserveId The identifier of the reserve
   * @param liquidityPremium The new liquidity premium
   */
  function updateLiquidityPremium(
    address spoke,
    uint256 reserveId,
    uint256 liquidityPremium
  ) external;

  /**
   * @notice Updates the liquidation fee of a reserve
   * @param spoke The address of the spoke
   * @param reserveId The identifier of the reserve
   * @param liquidationFee The new liquidation fee
   */
  function updateLiquidationFee(address spoke, uint256 reserveId, uint256 liquidationFee) external;

  /**
   * @notice Updates the collateral factor of a reserve
   * @param spoke The address of the spoke
   * @param reserveId The identifier of the reserve
   * @param collateralFactor The new collateral factor
   */
  function updateCollateralFactor(
    address spoke,
    uint256 reserveId,
    uint16 collateralFactor
  ) external;
}
