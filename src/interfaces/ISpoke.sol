// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {IMulticall} from 'src/interfaces/IMulticall.sol';
import {IAaveOracle} from 'src/interfaces/IAaveOracle.sol';
import {ISpokeBase} from 'src/interfaces/ISpokeBase.sol';

/**
 * @title ISpoke
 * @author Aave Labs
 * @notice Full interface for Spoke
 */
interface ISpoke is ISpokeBase, IMulticall, IAccessManaged {
  event AddReserve(uint256 indexed reserveId, uint256 indexed assetId, address indexed hub);
  event ReserveConfigUpdate(uint256 indexed reserveId, DataTypes.ReserveConfig config);

  /**
   * @notice Emitted when a dynamic reserve config is added.
   * @dev The config key is the next available key for the reserve, which is now the latest config
   * key of the reserve. It can be an existing key that was previously used and is now being
   * overridden.
   * @param reserveId The identifier of the reserve.
   * @param configKey The key of the added dynamic config.
   * @param config The dynamic reserve config.
   */
  event AddDynamicReserveConfig(
    uint256 indexed reserveId,
    uint16 indexed configKey,
    DataTypes.DynamicReserveConfig config
  );

  /**
   * @notice Emitted when a dynamic reserve config is updated.
   * @param reserveId The identifier of the reserve.
   * @param configKey The key of the updated dynamic config.
   * @param config The dynamic reserve config.
   */
  event UpdateDynamicReserveConfig(
    uint256 indexed reserveId,
    uint16 indexed configKey,
    DataTypes.DynamicReserveConfig config
  );

  /**
   * @notice Emitted when a user's dynamic config is refreshed for all reserves to their latest config key.
   * @param user The address of the user.
   */
  event RefreshAllUserDynamicConfig(address indexed user);

  /**
   * @notice Emitted when a user's dynamic config is refreshed for a single reserve to its latest config key.
   * @param user The address of the user.
   * @param reserveId The identifier of the reserve.
   */
  event RefreshSingleUserDynamicConfig(address indexed user, uint256 reserveId);

  /**
   * @notice Emitted on setUsingAsCollateral action.
   * @param reserveId The reserve identifier of the underlying asset as registered on the spoke.
   * @param caller The transaction initiator.
   * @param user The owner of the position being modified.
   * @param usingAsCollateral Boolean whether the reserve is enabled or disabled as collateral.
   */
  event UsingAsCollateral(
    uint256 indexed reserveId,
    address indexed caller,
    address indexed user,
    bool usingAsCollateral
  );

  /**
   * @notice Emitted on updateUserRiskPremium action.
   * @param user The owner of the position being modified.
   * @param riskPremium The new risk premium (BPS) value of user.
   */
  event UserRiskPremiumUpdate(address indexed user, uint256 riskPremium);

  /**
   * @notice Emitted on setUserPositionManager or renouncePositionManagerRole action.
   * @param user The address of the user on whose behalf position manager can act.
   * @param positionManager The address of the position manager.
   * @param approve True if position manager approval was granted, false if it was revoked.
   */
  event SetUserPositionManager(address indexed user, address indexed positionManager, bool approve);

  /**
   * @notice Emitted on updatePositionManager action.
   * @param positionManager The address of the position manager.
   * @param active True if position manager has become active, false otherwise.
   */
  event PositionManagerUpdate(address indexed positionManager, bool active);

  event RefreshPremiumDebt(
    uint256 indexed reserveId,
    address indexed user,
    DataTypes.PremiumDelta premiumDelta
  );
  event OracleUpdate(address indexed oracle);
  event ReservePriceSourceUpdate(uint256 indexed reserveId, address indexed priceSource);
  event LiquidationConfigUpdate(DataTypes.LiquidationConfig config);

  error ReserveNotListed();
  error AssetNotListed();
  error InvalidCollateralRisk();
  error InsufficientSupply(uint256 supply);
  error ReserveNotBorrowable(uint256 reserveId);
  error ReservePaused();
  error ReserveFrozen();
  error InvalidCollateralFactor();
  error InvalidLiquidationBonus();
  error IncompatibleCollateralFactorAndLiquidationBonus();
  error HealthFactorBelowThreshold();
  error InvalidCloseFactor();
  error InvalidHealthFactorForMaxBonus();
  error InvalidLiquidationBonusFactor();
  error HealthFactorNotBelowThreshold();
  error CollateralCannotBeLiquidated();
  error SpecifiedCurrencyNotBorrowedByUser();
  error InvalidDebtToCover();
  error InvalidLiquidationFee();
  error InvalidOracle();
  error UsersAndDebtLengthMismatch();
  error Unauthorized();
  error ConfigKeyUninitialized();
  error InactivePositionManager();

  function updateLiquidationConfig(DataTypes.LiquidationConfig calldata config) external;

  function updateOracle(address newOracle) external;

  function updateReservePriceSource(uint256 reserveId, address priceSource) external;

  function addReserve(
    address hub,
    uint256 assetId,
    address priceSource,
    DataTypes.ReserveConfig calldata config,
    DataTypes.DynamicReserveConfig calldata dynConfig
  ) external returns (uint256);

  function updateReserveConfig(uint256 reserveId, DataTypes.ReserveConfig calldata params) external;

  /**
   * @notice Updates the dynamic reserve config for a given reserve.
   * @dev Appends dynamic config to the next valid config key, and overrides existing config if the key is already used.
   * @param reserveId The identifier of the reserve.
   * @param dynamicConfig The dynamic reserve config to update.
   * @return configKey The key of the added dynamic config.
   */
  function addDynamicReserveConfig(
    uint256 reserveId,
    DataTypes.DynamicReserveConfig calldata dynamicConfig
  ) external returns (uint16 configKey);

  /**
   * @notice Updates the dynamic reserve config for a given reserve at the specified key.
   * @dev Reverts with `ConfigKeyUninitialized` if the config key has not been initialized yet.
   * @param reserveId The identifier of the reserve.
   * @param configKey The key of the config to update.
   * @param dynamicConfig The dynamic reserve config to update.
   */
  function updateDynamicReserveConfig(
    uint256 reserveId,
    uint16 configKey,
    DataTypes.DynamicReserveConfig calldata dynamicConfig
  ) external;

  /**
   * @notice Allows an approved caller (admin) to toggle the active status of position manager.
   * @param positionManager The address of the position manager.
   * @param active True if positionManager is to be set as active, false otherwise.
   */
  function updatePositionManager(address positionManager, bool active) external;

  /**
   * @notice Allows suppliers to enable/disable a specific supplied reserve as collateral.
   * @dev Caller must be `onBehalfOf` or an authorized position manager for `onBehalfOf`.
   * @param reserveId The reserve identifier of the underlying asset as registered on the spoke.
   * @param usingAsCollateral True if the user wants to use the supply as collateral, false otherwise.
   * @param onBehalfOf The owner of the position being modified.
   */
  function setUsingAsCollateral(
    uint256 reserveId,
    bool usingAsCollateral,
    address onBehalfOf
  ) external;

  /**
   * @notice Allows updating the risk premium on user position.
   * @dev If the risk premium has increased, the caller must be `user`, an authorized position manager
   * of `user`, or admin.
   * @param user The address of the user.
   */
  function updateUserRiskPremium(address user) external;

  /**
   * @notice Allows updating the dynamic configuration for all collateral reserves of a user position.
   * @dev Caller must be `onBehalfOf`, an authorized position manager for `onBehalfOf`, or admin.
   * @param onBehalfOf The owner of the position being modified.
   */
  function updateUserDynamicConfig(address onBehalfOf) external;

  /**
   * @notice Allows caller to approve or revoke approval for positionManager.
   * @param positionManager The address of the position manager.
   * @param approve True if user wants to approve position manager, false otherwise.
   */
  function setUserPositionManager(address positionManager, bool approve) external;

  /**
   * @notice Allows position manager (as caller) to renounce their approval given by the user.
   * @param user The address of the user.
   */
  function renouncePositionManagerRole(address user) external;

  /**
   * @notice Returns true if positionManager is active and approved by user, false otherwise.
   */
  function isPositionManager(address user, address positionManager) external view returns (bool);

  /**
   * @notice Returns true if positionManager is currently active, false otherwise.
   */
  function isPositionManagerActive(address positionManager) external view returns (bool);

  function getHealthFactor(address user) external view returns (uint256);

  function getReserve(uint256 reserveId) external view returns (DataTypes.Reserve memory);

  function getReserveDebt(uint256 reserveId) external view returns (uint256, uint256);

  function getReserveConfig(
    uint256 reserveId
  ) external view returns (DataTypes.ReserveConfig memory);

  function getDynamicReserveConfig(
    uint256 reserveId
  ) external view returns (DataTypes.DynamicReserveConfig memory);

  function getDynamicReserveConfig(
    uint256 reserveId,
    uint16 configKey
  ) external view returns (DataTypes.DynamicReserveConfig memory);

  function getReserveSuppliedAmount(uint256 reserveId) external view returns (uint256);

  function getReserveSuppliedShares(uint256 reserveId) external view returns (uint256);

  function getReserveTotalDebt(uint256 reserveId) external view returns (uint256);

  function getUserAccountData(
    address user
  )
    external
    view
    returns (
      uint256 userRiskPremium,
      uint256 avgCollateralFactor,
      uint256 healthFactor,
      uint256 totalCollateralInBaseCurrency,
      uint256 totalDebtInBaseCurrency
    );

  function getUserDebt(uint256 reserveId, address user) external view returns (uint256, uint256);

  function getUserPosition(
    uint256 reserveId,
    address user
  ) external view returns (DataTypes.UserPosition memory);

  function getUserRiskPremium(address user) external view returns (uint256);

  function getUserSuppliedAmount(uint256 reserveId, address user) external view returns (uint256);

  function getUserSuppliedShares(uint256 reserveId, address user) external view returns (uint256);

  function getUserTotalDebt(uint256 reserveId, address user) external view returns (uint256);

  function isUsingAsCollateral(uint256 reserveId, address user) external view returns (bool);

  function isBorrowing(uint256 reserveId, address user) external view returns (bool);

  function getReserveCount() external view returns (uint256);

  function getVariableLiquidationBonus(
    uint256 reserveId,
    address user,
    uint256 healthFactor
  ) external view returns (uint256);

  function getLiquidationConfig() external view returns (DataTypes.LiquidationConfig memory);

  function HEALTH_FACTOR_LIQUIDATION_THRESHOLD() external view returns (uint256);

  function MAX_COLLATERAL_RISK() external view returns (uint256);

  function oracle() external view returns (IAaveOracle);
}
