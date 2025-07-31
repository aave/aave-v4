// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {IMulticall} from 'src/interfaces/IMulticall.sol';
import {IAaveOracle} from 'src/interfaces/IAaveOracle.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

/**
 * @title ISpoke
 * @author Aave Labs
 * @notice Basic interface for Spoke
 */
interface ISpoke is IMulticall, IAccessManaged {
  event ReserveAdded(uint256 indexed reserveId, uint256 indexed assetId, address indexed hub);
  event ReserveConfigUpdated(uint256 indexed reserveId, DataTypes.ReserveConfig config);

  /**
   * @notice Emitted when a dynamic reserve config is added.
   * @dev The config key is the next available key for the reserve, which is now the latest config
   * key of the reserve. It can be an existing key that was previously used and is now being
   * overridden.
   * @param reserveId The identifier of the reserve.
   * @param configKey The key of the added dynamic config.
   * @param config The dynamic reserve config.
   */
  event DynamicReserveConfigAdded(
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
  event DynamicReserveConfigUpdated(
    uint256 indexed reserveId,
    uint16 indexed configKey,
    DataTypes.DynamicReserveConfig config
  );

  /**
   * @notice Emitted when a user's dynamic config is refreshed for all reserves to their latest config key.
   * @param user The address of the user.
   */
  event UserDynamicConfigRefreshedAll(address indexed user);

  /**
   * @notice Emitted when a user's dynamic config is refreshed for a single reserve to its latest config key.
   * @param user The address of the user.
   * @param reserveId The identifier of the reserve.
   */
  event UserDynamicConfigRefreshedSingle(address indexed user, uint256 reserveId);

  /**
   * @notice Emitted on the supply action.
   * @param reserveId The reserve identifier of the underlying asset as registered on the spoke.
   * @param caller The transaction initiator, and supplier of the underlying asset.
   * @param user The owner of the modified position.
   * @param suppliedShares The amount of supply shares minted.
   */
  event Supply(
    uint256 indexed reserveId,
    address indexed caller,
    address indexed user,
    uint256 suppliedShares
  );

  /**
   * @notice Emitted on the withdraw action.
   * @param reserveId The reserve identifier of the underlying asset as registered on the spoke.
   * @param caller The transaction initiator, and recipient of the underlying asset being withdrawn.
   * @param user The owner of the modified position.
   * @param suppliedShares The amount of supply shares burned.
   */
  event Withdraw(
    uint256 indexed reserveId,
    address indexed caller,
    address indexed user,
    uint256 suppliedShares
  );

  /**
   * @notice Emitted on the borrow action.
   * @param reserveId The reserve identifier of the underlying asset as registered on the spoke.
   * @param caller The transaction initiator, and recipient of the underlying asset being borrowed.
   * @param user The owner of the position on which debt is generated.
   * @param drawnShares The amount of debt shares minted.
   */
  event Borrow(
    uint256 indexed reserveId,
    address indexed caller,
    address indexed user,
    uint256 drawnShares
  );

  /**
   * @notice Emitted on the repay action.
   * @param reserveId The reserve identifier of the underlying asset as registered on the spoke.
   * @param caller The transaction initiator, and supplier of the underlying asset being repaid.
   * @param user The owner of the position whose debt is being repaid.
   * @param drawnShares The amount of debt shares burned.
   */
  event Repay(
    uint256 indexed reserveId,
    address indexed caller,
    address indexed user,
    uint256 drawnShares
  );

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
  event UserPositionManagerSet(address indexed user, address indexed positionManager, bool approve);

  /**
   * @notice Emitted on updatePositionManager action.
   * @param positionManager The address of the position manager.
   * @param active True if position manager has become active, false otherwise.
   */
  event PositionManagerUpdated(address indexed positionManager, bool active);

  event RefreshPremiumDebt(
    uint256 indexed reserveId,
    address indexed user,
    DataTypes.PremiumDelta premiumDelta
  );
  event OracleUpdated(address indexed oracle);
  event ReservePriceSourceUpdated(uint256 indexed reserveId, address indexed priceSource);
  event LiquidationConfigUpdated(DataTypes.LiquidationConfig config);

  /**
   * @dev Emitted when a borrower is liquidated.
   * @param collateralAsset The address of the underlying asset used as collateral, to receive as result of the liquidation.
   * @param debtAsset The address of the underlying borrowed asset to be repaid with the liquidation.
   * @param user The address of the borrower getting liquidated.
   * @param liquidatedDebt The debt amount of borrowed asset to be liquidated.
   * @param liquidatedCollateral The amount of collateral received by the liquidator.
   * @param liquidator The address of the liquidator.
   */
  event LiquidationCall(
    address indexed collateralAsset,
    address indexed debtAsset,
    address indexed user,
    uint256 liquidatedDebt,
    uint256 liquidatedCollateral,
    address liquidator
  );

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
  error InvalidReserveDecimals();
  error HealthFactorBelowThreshold();
  error InvalidCloseFactor();
  error InvalidHubAddress();
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
   * @notice Supply an amount of underlying asset of the specified reserve.
   * @dev The Liquidity Hub pulls the underlying asset from the caller, so prior token approval is required.
   * @dev Caller must be `onBehalfOf` or an authorized position manager for `onBehalfOf`.
   * @param reserveId The reserve identifier.
   * @param amount The amount of asset to supply.
   * @param onBehalfOf The owner of position to add supply shares to.
   */
  function supply(uint256 reserveId, uint256 amount, address onBehalfOf) external;

  /**
   * @notice Withdraws a specified amount of underlying asset from the given reserve.
   * @dev Providing an amount greater than the maximum withdrawable value signals a full withdrawal.
   * @dev Caller must be `onBehalfOf` or an authorized position manager for `onBehalfOf`.
   * @dev Caller receives the underlying asset withdrawn.
   * @param reserveId The identifier of the reserve.
   * @param amount The amount of asset to withdraw.
   * @param onBehalfOf The owner of position to remove supply shares from.
   */
  function withdraw(uint256 reserveId, uint256 amount, address onBehalfOf) external;

  /**
   * @notice Borrows a specified amount of underlying asset from the given reserve
   * @dev Caller must be `onBehalfOf` or an authorized position manager for `onBehalfOf`.
   * @dev Caller receives the underlying asset borrowed.
   * @param reserveId The identifier of the reserve.
   * @param amount The amount of asset to borrow.
   * @param onBehalfOf The owner of the position against which debt is generated.
   */
  function borrow(uint256 reserveId, uint256 amount, address onBehalfOf) external;

  /**
   * @notice Repays a specified amount of underlying asset to a given reserve.
   * @dev The Liquidity Hub pulls the underlying asset from the caller, so prior approval is required.
   * @dev Caller must be `onBehalfOf` or an authorized position manager for `onBehalfOf`.
   * @param reserveId The identifier of the reserve.
   * @param amount The amount of asset to repay.
   * @param onBehalfOf The owner of the position whose debt is repaid.
   */
  function repay(uint256 reserveId, uint256 amount, address onBehalfOf) external;

  /**
   * @notice Liquidates a user position.
   * @dev Invokes Liquidity Hub restore, and pulls underlying repaid debt asset from caller (Liquidator), hence it needs prior approval.
   * @param collateralReserveId The reserveId of the underlying asset used as collateral by the liquidated user.
   * @param debtReserveId The reserveId of the underlying asset borrowed by the liquidated user, to be repaid by Liquidator during liquidation.
   * @param user The address of the user to liquidate.
   * @param debtToCover The amount of debt to cover.
   */
  function liquidationCall(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover
  ) external;

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

  function getReserveRiskPremium(uint256 reserveId) external view returns (uint256);

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

  function reservesList(uint256) external view returns (uint256);

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
