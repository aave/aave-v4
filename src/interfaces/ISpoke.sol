// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
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
  /**
   * @notice Emitted when a reserve is added.
   * @param reserveId The identifier of the reserve.
   * @param assetId The identifier of the asset.
   * @param hub The address of the hub where the asset is listed.
   */
  event AddReserve(uint256 indexed reserveId, uint256 indexed assetId, address indexed hub);

  /**
   * @notice Emitted when a reserve configuration is updated.
   * @param reserveId The identifier of the reserve.
   * @param config The reserve configuration object.
   */
  event ReserveConfigUpdate(uint256 indexed reserveId, DataTypes.ReserveConfig config);

  /**
   * @notice Emitted when a dynamic reserve config is added.
   * @dev The config key is the next available key for the reserve, which becomes the latest config
   * key of the reserve. It can be an existing key that becomes overridden.
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
   * @notice Emitted when a reserve is set as collateral.
   * @param reserveId The identifier of the reserve.
   * @param caller The initiator of the transaction .
   * @param user The owner of the position being set as collateral.
   * @param usingAsCollateral True if the reserve is enabled as collateral, false if disabled.
   */
  event UsingAsCollateral(
    uint256 indexed reserveId,
    address indexed caller,
    address indexed user,
    bool usingAsCollateral
  );

  /**
   * @notice Emitted when a user's risk premium is updated.
   * @param user The owner of the position being modified.
   * @param riskPremium The new risk premium (BPS) value of user.
   */
  event UserRiskPremiumUpdate(address indexed user, uint256 riskPremium);

  /**
   * @notice Emitted when a position manager is set or revoked for a user.
   * @param user The address of the user on whose behalf the position manager can act.
   * @param positionManager The address of the position manager.
   * @param approve True if position manager approval was granted, false if it was revoked.
   */
  event SetUserPositionManager(address indexed user, address indexed positionManager, bool approve);

  /**
   * @notice Emitted when a position manager is updated.
   * @param positionManager The address of the position manager.
   * @param active True if position manager is active, false otherwise.
   */
  event UpdatePositionManager(address indexed positionManager, bool active);

  /**
   * @notice Emitted when premium debt is refreshed.
   * @param reserveId The identifier of the reserve.
   * @param user The address of the user.
   * @param premiumDelta The premium delta object.
   */
  event RefreshPremiumDebt(
    uint256 indexed reserveId,
    address indexed user,
    DataTypes.PremiumDelta premiumDelta
  );

  /**
   * @notice Emitted when the spoke's oracle is updated.
   * @param oracle The address of the new oracle.
   */
  event OracleUpdate(address indexed oracle);

  /**
   * @notice Emitted when the price source of a reserve is updated.
   * @param reserveId The identifier of the reserve.
   * @param priceSource The address of the new price source.
   */
  event ReservePriceSourceUpdate(uint256 indexed reserveId, address indexed priceSource);

  /**
   * @notice Emitted when the spoke's liquidation config is updated.
   * @param config The liquidation config object.
   */
  event LiquidationConfigUpdate(DataTypes.LiquidationConfig config);

  /**
   * @notice Thrown when an asset is not listed.
   */
  error AssetNotListed();

  /**
   * @notice Thrown when a reserve already exists.
   */
  error ReserveExists();

  /**
   * @notice Thrown when a reserve is not listed.
   */
  error ReserveNotListed();

  /**
   * @notice Thrown when the amount supplied is insufficient to cover a withdrawal.
   * @param supply The maximum amount that can be withdrawn.
   */
  error InsufficientSupply(uint256 supply);

  /**
   * @notice Thrown when a reserve is not borrowable.
   */
  error ReserveNotBorrowable();

  /**
   * @notice Thrown when a reserve is paused.
   */
  error ReservePaused();

  /**
   * @notice Thrown when a reserve is frozen.
   */
  error ReserveFrozen();

  /**
   * @notice Thrown when the health factor is below the liquidation threshold.
   */
  error HealthFactorBelowThreshold();

  /**
   * @notice Thrown when the collateral cannot be liquidated.
   */
  error CollateralCannotBeLiquidated();

  /**
   * @notice Thrown during liquidationwhen the specified currency is not borrowed by the user.
   */
  error SpecifiedCurrencyNotBorrowedByUser();

  /**
   * @notice Thrown when the caller is not authorized.
   */
  error Unauthorized();

  /**
   * @notice Thrown when a config key is uninitialized.
   */
  error ConfigKeyUninitialized();

  /**
   * @notice Thrown when a position manager is inactive.
   */
  error InactivePositionManager();

  /**
   * @notice Thrown when a signature is invalid.
   */
  error InvalidSignature();

  /**
   * @notice Thrown when an address is invalid.
   */
  error InvalidAddress();

  /**
   * @notice Thrown when an oracle is invalid.
   */
  error InvalidOracle();

  /**
   * @notice Thrown when a collateral risk is invalid.
   */
  error InvalidCollateralRisk();

  /**
   * @notice Thrown when a liquidation config is invalid.
   */
  error InvalidLiquidationConfig();

  /**
   * @notice Thrown when a liquidation fee is invalid.
   */
  error InvalidLiquidationFee();

  /**
   * @notice Thrown when a collateral factor and max liquidation bonus are invalid.
   * @dev The collateral factor must be less than or equal to 100%, the max liquidation bonus must be greater than or equal to 100%.
   * @dev The max liquidation bonus multiplied by the collateral factor must be less than 100%.
   */
  error InvalidCollateralFactorAndMaxLiquidationBonus();

  /**
   * @notice Thrown when the caller is attempting to liquidate their own position.
   */
  error SelfLiquidation();

  /**
   * @notice Thrown when the health factor is not below the threshold.
   */
  error HealthFactorNotBelowThreshold();

  /**
   * @notice Thrown when a liquidation leaves an invalid dust debt position.
   */
  error MustNotLeaveDust();

  /**
   * @notice Thrown when the debt to cover is invalid.
   */
  error InvalidDebtToCover();

  /**
   * @notice Allows an approved caller (admin) to update the spoke's liquidation config.
   * @param config The liquidation config object.
   */
  function updateLiquidationConfig(DataTypes.LiquidationConfig calldata config) external;

  /**
   * @notice Allows an approved caller (admin) to update the spoke oracle.
   * @dev Does not validate all existing reserves are supported on `newOracle`.
   */
  function updateOracle(address newOracle) external;

  /**
   * @notice Allows an approved caller (admin) to update the price source of a reserve.
   * @param reserveId The identifier of the reserve.
   * @param priceSource The new price source.
   */
  function updateReservePriceSource(uint256 reserveId, address priceSource) external;

  /**
   * @notice Allows an approved caller (admin) to add a new reserve.
   * @param hub The address of the hub where the asset is listed.
   * @param assetId The identifier of the asset.
   * @param priceSource The reserve's price source.
   * @param config The reserve configuration object.
   * @param dynConfig The dynamic reserve configuration object.
   */
  function addReserve(
    address hub,
    uint256 assetId,
    address priceSource,
    DataTypes.ReserveConfig calldata config,
    DataTypes.DynamicReserveConfig calldata dynConfig
  ) external returns (uint256);

  /**
   * @notice Allows an approved caller (admin) to update the configuration of a reserve.
   * @param reserveId The identifier of the reserve.
   * @param params The reserve configuration object.
   */
  function updateReserveConfig(uint256 reserveId, DataTypes.ReserveConfig calldata params) external;

  /**
   * @notice Allows an approved caller (admin) to update the dynamic reserve config for a given reserve.
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
   * @notice Allows suppliers to enable/disable a specific reserve as collateral.
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
   * @notice Allows the risk premium of the onBehalfOf position to be updated.
   * @dev Caller must be `onBehalfOf`, an authorized position manager for `onBehalfOf`, or admin.
   * @param onBehalfOf The owner of the position being modified.
   */
  function updateUserRiskPremium(address onBehalfOf) external;

  /**
   * @notice Allows updating the dynamic configuration for all collateral reserves on onBehalfOf position.
   * @dev Caller must be `onBehalfOf`, an authorized position manager for `onBehalfOf`, or admin.
   * @param onBehalfOf The owner of the position being modified.
   */
  function updateUserDynamicConfig(address onBehalfOf) external;

  /**
   * @notice Enables a user to grant or revoke approval for a position manager
   * @param positionManager The address of the position manager.
   * @param approve True to approve the position manager, false to revoke approval.
   */
  function setUserPositionManager(address positionManager, bool approve) external;

  /**
   * @notice Enables a user to grant or revoke approval for a position manager using an EIP712-compliant signature.
   * @param positionManager The address of the position manager.
   * @param user The address of the user on whose behalf the position manager can act.
   * @param approve True to approve the position manager, false to revoke approval.
   * @param deadline The deadline for the signature.
   * @param signature The EIP712-compliant signature bytes.
   */
  function setUserPositionManagerWithSig(
    address positionManager,
    address user,
    bool approve,
    uint256 deadline,
    bytes memory signature
  ) external;

  /**
   * @notice Allows position manager (as caller) to renounce their approval granted by the user.
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

  /**
   * @notice Allows caller to revoke their nonce used in `setUserPositionManagerWithSig`.
   */
  function useNonce() external;

  /**
   * @notice Allows consuming a permit signature for the given reserve's underlying asset.
   * @dev Spender is the corresponding hub of the given reserve.
   * @param reserveId The identifier of the reserve.
   * @param onBehalfOf The address of the user on whose behalf the permit is being used.
   * @param value The amount of the underlying asset to permit.
   * @param deadline The deadline for the permit.
   */
  function permitReserve(
    uint256 reserveId,
    address onBehalfOf,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;

  /**
   * @notice Returns the health factor of a user, in WAD precision.
   * @param user The address of the user.
   * @return The health factor.
   */
  function getHealthFactor(address user) external view returns (uint256);

  /**
   * @notice Returns the reserve object.
   * @param reserveId The identifier of the reserve.
   * @return The Reserve object.
   */
  function getReserve(uint256 reserveId) external view returns (DataTypes.Reserve memory);

  /**
   * @notice Returns the reserve configuration.
   * @param reserveId The identifier of the reserve.
   * @return The ReserveConfig object.
   */
  function getReserveConfig(
    uint256 reserveId
  ) external view returns (DataTypes.ReserveConfig memory);

  /**
   * @notice Returns the dynamic reserve configuration.
   * @param reserveId The identifier of the reserve.
   * @return The DynamicReserveConfig object.
   */
  function getDynamicReserveConfig(
    uint256 reserveId
  ) external view returns (DataTypes.DynamicReserveConfig memory);

  /**
   * @notice Returns the dynamic reserve configuration for a given config key.
   * @param reserveId The identifier of the reserve.
   * @param configKey The key of the config to return.
   * @return The DynamicReserveConfig object.
   */
  function getDynamicReserveConfig(
    uint256 reserveId,
    uint16 configKey
  ) external view returns (DataTypes.DynamicReserveConfig memory);

  /**
   * @notice Returns the amount of assets supplied for a given reserve.
   * @param reserveId The identifier of the reserve.
   * @return The amount of assets supplied.
   */
  function getReserveSuppliedAssets(uint256 reserveId) external view returns (uint256);

  /**
   * @notice Returns the amount of shares supplied for a given reserve.
   * @param reserveId The identifier of the reserve.
   * @return The amount of shares supplied.
   */
  function getReserveSuppliedShares(uint256 reserveId) external view returns (uint256);

  /**
   * @notice Returns the amount of drawn and premium debt assets for a given reserve.
   * @param reserveId The identifier of the reserve.
   * @return The amount of drawn debt assets.
   * @return The amount of premium debt assets.
   */
  function getReserveDebt(uint256 reserveId) external view returns (uint256, uint256);

  /**
   * @notice Returns the total amount of debt assets for a given reserve.
   * @param reserveId The identifier of the reserve.
   * @return The amount of drawn and premium debt assets.
   */
  function getReserveTotalDebt(uint256 reserveId) external view returns (uint256);

  /**
   * @notice Returns the amount of drawn shares for a given reserve.
   * @param reserveId The identifier of the reserve.
   * @return The amount of drawn shares.
   */
  function getReserveDrawnShares(uint256 reserveId) external view returns (uint256);

  /**
   * @notice Returns the premium share data for a given reserve.
   * @param reserveId The identifier of the reserve.
   * @return The amount of premium shares of the reserve.
   * @return The premium offset of the reserve.
   * @return The realized premium of the reserve.
   */
  function getReservePremiumData(
    uint256 reserveId
  ) external view returns (uint256, uint256, uint256);

  /**
   * @notice Returns the user account data.
   * @param user The address of the user.
   * @return The user account data object.
   */
  function getUserAccountData(
    address user
  ) external view returns (DataTypes.UserAccountData memory);

  /**
   * @notice Returns the amount of drawn and premium debt assets for a given reserve and user.
   * @param reserveId The identifier of the reserve.
   * @param user The address of the user.
   * @return The amount of drawn debt assets.
   * @return The amount of premium debt assets.
   */
  function getUserDebt(uint256 reserveId, address user) external view returns (uint256, uint256);

  /**
   * @notice Returns the user position for a given reserve and user.
   * @param reserveId The identifier of the reserve.
   * @param user The address of the user.
   * @return The user position object.
   */

  function getUserPosition(
    uint256 reserveId,
    address user
  ) external view returns (DataTypes.UserPosition memory);

  /**
   * @notice Returns the user risk premium.
   * @param user The address of the user.
   * @return The user risk premium.
   */
  function getUserRiskPremium(address user) external view returns (uint256);

  /**
   * @notice Returns the amount of assets supplied by a user on a given reserve.
   * @param reserveId The identifier of the reserve.
   * @param user The address of the user.
   * @return The amount of assets supplied.
   */
  function getUserSuppliedAssets(uint256 reserveId, address user) external view returns (uint256);

  /**
   * @notice Returns the amount of shares supplied by a user on a given reserve.
   * @param reserveId The identifier of the reserve.
   * @param user The address of the user.
   * @return The amount of shares supplied.
   */
  function getUserSuppliedShares(uint256 reserveId, address user) external view returns (uint256);

  /**
   * @notice Returns the total amount of debt assets for a user on a given reserve.
   * @param reserveId The identifier of the reserve.
   * @param user The address of the user.
   * @return The amount of drawn and premium debt assets.
   */
  function getUserTotalDebt(uint256 reserveId, address user) external view returns (uint256);

  /**
   * @notice Returns whether a user is using a given reserve as collateral.
   * @param reserveId The identifier of the reserve.
   * @param user The address of the user.
   * @return True if the user is using the reserve as collateral, false otherwise.
   */
  function isUsingAsCollateral(uint256 reserveId, address user) external view returns (bool);

  /**
   * @notice Returns whether a user is borrowing a given reserve.
   * @param reserveId The identifier of the reserve.
   * @param user The address of the user.
   * @return True if the user is borrowing the reserve, false otherwise.
   */
  function isBorrowing(uint256 reserveId, address user) external view returns (bool);

  /**
   * @notice Returns the number of reserves.
   * @return The number of reserves.
   */
  function getReserveCount() external view returns (uint256);

  /**
   * @notice Returns the liquidation bonus for the health factor of a user's position on a given reserve based on their dynamic config key.
   * @param reserveId The identifier of the reserve.
   * @param user The address of the user.
   * @param healthFactor The health factor.
   * @return The liquidation bonus, in BPS.
   */
  function getLiquidationBonus(
    uint256 reserveId,
    address user,
    uint256 healthFactor
  ) external view returns (uint256);

  /**
   * @notice Returns the liquidation config.
   * @return The liquidation config object.
   */
  function getLiquidationConfig() external view returns (DataTypes.LiquidationConfig memory);

  /**
   * @notice Returns the oracle.
   * @return The oracle interface.
   */
  function oracle() external view returns (IAaveOracle);

  /**
   * @notice Returns the nonce for a given user.
   * @param user The address of the user.
   * @return The nonce.
   */
  function nonces(address user) external view returns (uint256);

  /**
   * @notice Returns the domain separator for the EIP712 signature.
   * @return The domain separator.
   */
  function DOMAIN_SEPARATOR() external view returns (bytes32);
}
