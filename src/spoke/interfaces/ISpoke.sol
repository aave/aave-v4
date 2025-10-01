// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {IMulticall} from 'src/interfaces/IMulticall.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {ISpokeBase} from 'src/spoke/interfaces/ISpokeBase.sol';

/**
 * @title ISpoke
 * @author Aave Labs
 * @notice Full interface for Spoke
 */
interface ISpoke is ISpokeBase, IMulticall, IAccessManaged {
  struct Reserve {
    address underlying;
    //
    IHubBase hub;
    uint16 assetId;
    uint8 decimals;
    uint16 dynamicConfigKey; // key of the last reserve config
    bool paused;
    bool frozen;
    bool borrowable;
    uint24 collateralRisk;
  }

  struct ReserveConfig {
    bool paused;
    bool frozen;
    bool borrowable;
    uint24 collateralRisk; // BPS
  }

  struct DynamicReserveConfig {
    uint16 collateralFactor;
    uint32 maxLiquidationBonus; // BPS, 100_00 represent a 0% bonus
    uint16 liquidationFee; // BPS
  }

  struct LiquidationConfig {
    uint128 targetHealthFactor; // WAD, HF value to restore to during a liquidation
    uint64 healthFactorForMaxBonus; // WAD, health factor under which liquidation bonus is max
    uint16 liquidationBonusFactor; // BPS, as a percentage of effective lb
  }

  struct UserPosition {
    uint128 drawnShares;
    uint128 realizedPremium;
    //
    uint128 premiumShares;
    uint128 premiumOffset;
    //
    uint128 suppliedShares;
    uint16 configKey; // key of the last user config
  }

  struct PositionManagerConfig {
    bool active;
    mapping(address user => bool) approval;
  }

  struct PositionStatus {
    mapping(uint256 slot => uint256) map;
  }

  struct UserAccountData {
    uint256 userRiskPremium;
    uint256 avgCollateralFactor;
    uint256 healthFactor;
    uint256 totalCollateralInBaseCurrency;
    uint256 totalDebtInBaseCurrency;
    uint256 suppliedCollateralsCount; // number of reserves with collateral factor > 0, enabled as collateral and strictly positive supplied amount
    uint256 borrowedReservesCount; // number of reserves with strictly positive debt
  }

  event AddReserve(uint256 indexed reserveId, uint256 indexed assetId, address indexed hub);
  event UpdateReserveConfig(uint256 indexed reserveId, ReserveConfig config);

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
    DynamicReserveConfig config
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
    DynamicReserveConfig config
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
  event SetUsingAsCollateral(
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
  event UpdateUserRiskPremium(address indexed user, uint256 riskPremium);

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
  event UpdatePositionManager(address indexed positionManager, bool active);

  event RefreshPremiumDebt(
    uint256 indexed reserveId,
    address indexed user,
    IHubBase.PremiumDelta premiumDelta
  );
  event UpdateReservePriceSource(uint256 indexed reserveId, address indexed priceSource);
  event UpdateLiquidationConfig(LiquidationConfig config);

  error AssetNotListed();
  error ReserveExists();
  error InvalidAssetId();
  error ReserveNotListed();
  error ReserveNotBorrowable();
  error ReservePaused();
  error ReserveFrozen();
  error HealthFactorBelowThreshold();
  error CollateralCannotBeLiquidated();
  error SpecifiedCurrencyNotBorrowedByUser();
  error Unauthorized();
  error ConfigKeyUninitialized();
  error InactivePositionManager();
  error InvalidSignature();
  error InvalidAddress();
  error InvalidOracleDecimals();
  error InvalidCollateralRisk();
  error InvalidLiquidationConfig();
  error InvalidLiquidationFee();
  error InvalidCollateralFactorAndMaxLiquidationBonus();
  error SelfLiquidation();
  error HealthFactorNotBelowThreshold();
  error MustNotLeaveDust();
  error InvalidDebtToCover();

  /**
   * @dev Thrown when trying to set zero collateralFactor on historic dynamic configuration keys.
   */
  error InvalidCollateralFactor();

  function updateLiquidationConfig(LiquidationConfig calldata config) external;

  function updateReservePriceSource(uint256 reserveId, address priceSource) external;

  /**
   * @notice Adds a new reserve to the spoke.
   * @param hub The address of the Hub where the asset is listed.
   * @param assetId The identifier of the asset in the Hub.
   * @param priceSource The address of the price source for the asset.
   * @param config The initial reserve configuration.
   * @param dynamicConfig The initial dynamic reserve configuration.
   */
  function addReserve(
    address hub,
    uint256 assetId,
    address priceSource,
    ReserveConfig calldata config,
    DynamicReserveConfig calldata dynamicConfig
  ) external returns (uint256);

  function updateReserveConfig(uint256 reserveId, ReserveConfig calldata params) external;

  /**
   * @notice Updates the dynamic reserve config for a given reserve.
   * @dev Appends dynamic config to the next valid config key, and overrides existing config if the key is already used.
   * @param reserveId The identifier of the reserve.
   * @param dynamicConfig The dynamic reserve config to update.
   * @return configKey The key of the added dynamic config.
   */
  function addDynamicReserveConfig(
    uint256 reserveId,
    DynamicReserveConfig calldata dynamicConfig
  ) external returns (uint16 configKey);

  /**
   * @notice Updates the dynamic reserve config for a given reserve at the specified key.
   * @dev Reverts with `ConfigKeyUninitialized` if the config key has not been initialized yet.
   * @dev Reverts with `InvalidCollateralFactor` if the collateral factor is 0.
   * @param reserveId The identifier of the reserve.
   * @param configKey The key of the config to update.
   * @param dynamicConfig The dynamic reserve config to update.
   */
  function updateDynamicReserveConfig(
    uint256 reserveId,
    uint16 configKey,
    DynamicReserveConfig calldata dynamicConfig
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
   * @notice Allows updating the risk premium on onBehalfOf position.
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
   * @param user The address of the user on whose behalf position manager can act.
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
   * @notice Allows position manager (as caller) to renounce their approval given by the user.
   * @param user The address of the user.
   */
  function renouncePositionManagerRole(address user) external;

  /**
   * @notice Gets the address of the external getLiquidationLogic library.
   */
  function getLiquidationLogic() external pure returns (address);

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
   * @notice Returns the maximum allowed value for an asset identifier.
   * @return The maximum asset identifier value (inclusive).
   */
  function MAX_ALLOWED_ASSET_ID() external view returns (uint256);

  /**
   * @notice Returns the type hash for the SetUserPositionManager intent.
   * @return The bytes-encoded EIP-712 struct hash representing the intent.
   */
  function SET_USER_POSITION_MANAGER_TYPEHASH() external view returns (bytes32);

  /**
   * @notice Returns the minimum health factor below which a position is considered unhealthy and subject to liquidation.
   * @return The minimum health factor considered healthy, expressed in WAD (18 decimals) (e.g. 1e18 is 1.00).
   */
  function HEALTH_FACTOR_LIQUIDATION_THRESHOLD() external view returns (uint64);

  /**
   * @notice Returns the minimum required remaining base currency amount after a partial liquidation.
   * @return The minimum debt amount considered as dust, denominated in USD with 26 decimals.
   */
  function DUST_DEBT_LIQUIDATION_THRESHOLD() external view returns (uint256);

  /**
   * @notice Returns the maximum allowed collateral risk value for a reserve.
   * @return The maximum collateral risk value, expressed in bps (e.g. 100_00 is 100.00%).
   */
  function MAX_ALLOWED_COLLATERAL_RISK() external view returns (uint24);

  function ORACLE_DECIMALS() external view returns (uint8);

  function ORACLE() external view returns (address);

  function getReserve(uint256 reserveId) external view returns (Reserve memory);

  function getReserveConfig(uint256 reserveId) external view returns (ReserveConfig memory);

  function getDynamicReserveConfig(
    uint256 reserveId
  ) external view returns (DynamicReserveConfig memory);

  function getDynamicReserveConfig(
    uint256 reserveId,
    uint16 configKey
  ) external view returns (DynamicReserveConfig memory);

  function getUserAccountData(address user) external view returns (UserAccountData memory);

  function getUserPosition(
    uint256 reserveId,
    address user
  ) external view returns (UserPosition memory);

  function isUsingAsCollateral(uint256 reserveId, address user) external view returns (bool);

  function isBorrowing(uint256 reserveId, address user) external view returns (bool);

  function getReserveCount() external view returns (uint256);

  function getLiquidationBonus(
    uint256 reserveId,
    address user,
    uint256 healthFactor
  ) external view returns (uint256);

  function getLiquidationConfig() external view returns (LiquidationConfig memory);

  function nonces(address user) external view returns (uint256);

  function DOMAIN_SEPARATOR() external view returns (bytes32);
}
