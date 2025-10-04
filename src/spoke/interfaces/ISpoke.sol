// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {INoncesKeyed} from 'src/interfaces/INoncesKeyed.sol';
import {IMulticall} from 'src/interfaces/IMulticall.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {ISpokeBase} from 'src/spoke/interfaces/ISpokeBase.sol';

/// @title ISpoke
/// @author Aave Labs
/// @notice Full interface for Spoke.
interface ISpoke is ISpokeBase, IMulticall, INoncesKeyed, IAccessManaged {
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
    uint128 targetHealthFactor; // WAD, ideal health factor to restore user position during liquidation
    uint64 healthFactorForMaxBonus; // WAD, health factor under which liquidation bonus is max
    uint16 liquidationBonusFactor; // BPS, liquidation bonus factor * maxLiquidationBonus is the minimum liquidation bonus
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

  /// @notice Emitted when a reserve is added.
  /// @param reserveId The identifier of the reserve.
  /// @param assetId The identifier of the asset.
  /// @param hub The address of the hub where the asset is listed.
  event AddReserve(uint256 indexed reserveId, uint256 indexed assetId, address indexed hub);

  /// @notice Emitted when a reserve configuration is updated.
  /// @param reserveId The identifier of the reserve.
  /// @param config The reserve configuration.
  event UpdateReserveConfig(uint256 indexed reserveId, ReserveConfig config);

  /// @notice Emitted when a dynamic reserve config is added.
  /// @dev The config key is the next available key for the reserve, which is now the latest config
  /// key of the reserve. It can be an existing key that was previously used and is now being
  /// overridden.
  /// @param reserveId The identifier of the reserve.
  /// @param configKey The key of the added dynamic config.
  /// @param config The dynamic reserve config.
  event AddDynamicReserveConfig(
    uint256 indexed reserveId,
    uint16 indexed configKey,
    DynamicReserveConfig config
  );

  /// @notice Emitted when a dynamic reserve config is updated.
  /// @param reserveId The identifier of the reserve.
  /// @param configKey The key of the updated dynamic config.
  /// @param config The dynamic reserve config.
  event UpdateDynamicReserveConfig(
    uint256 indexed reserveId,
    uint16 indexed configKey,
    DynamicReserveConfig config
  );

  /// @notice Emitted when a user's dynamic config is refreshed for all reserves to their latest config key.
  /// @param user The address of the user.
  event RefreshAllUserDynamicConfig(address indexed user);

  /// @notice Emitted when a user's dynamic config is refreshed for a single reserve to its latest config key.
  /// @param user The address of the user.
  /// @param reserveId The identifier of the reserve.
  event RefreshSingleUserDynamicConfig(address indexed user, uint256 reserveId);

  /// @notice Emitted on setUsingAsCollateral action.
  /// @param reserveId The reserve identifier of the underlying asset.
  /// @param caller The transaction initiator.
  /// @param user The owner of the position being modified.
  /// @param usingAsCollateral Boolean whether the reserve is enabled or disabled as collateral.
  event SetUsingAsCollateral(
    uint256 indexed reserveId,
    address indexed caller,
    address indexed user,
    bool usingAsCollateral
  );

  /// @notice Emitted on updateUserRiskPremium action.
  /// @param user The owner of the position being modified.
  /// @param riskPremium The new risk premium (BPS) value of user.
  event UpdateUserRiskPremium(address indexed user, uint256 riskPremium);

  /// @notice Emitted on setUserPositionManager or renouncePositionManagerRole action.
  /// @param user The address of the user on whose behalf position manager can act.
  /// @param positionManager The address of the position manager.
  /// @param approve True if position manager approval was granted, false if it was revoked.
  event SetUserPositionManager(address indexed user, address indexed positionManager, bool approve);

  /// @notice Emitted on updatePositionManager action.
  /// @param positionManager The address of the position manager.
  /// @param active True if position manager has become active, false otherwise.
  event UpdatePositionManager(address indexed positionManager, bool active);

  /// @notice Emitted on refreshPremiumDebt action.
  /// @param reserveId The identifier of the reserve.
  /// @param user The address of the user.
  /// @param premiumDelta The change in premium values.
  event RefreshPremiumDebt(
    uint256 indexed reserveId,
    address indexed user,
    IHubBase.PremiumDelta premiumDelta
  );

  /// @notice Emitted when the price source of a reserve is updated.
  /// @param reserveId The identifier of the reserve.
  /// @param priceSource The address of the new price source.
  event UpdateReservePriceSource(uint256 indexed reserveId, address indexed priceSource);

  /// @notice Emitted when a liquidation config is updated.
  /// @param config The new liquidation config.
  event UpdateLiquidationConfig(LiquidationConfig config);

  /// @notice Thrown when an asset is not listed on the hub when adding a reserve.
  error AssetNotListed();

  /// @notice Thrown when adding a new reserve if that reserve already exists for a given hub/assetId pair.
  error ReserveExists();

  /// @notice Thrown when adding a new reserve if an asset id is invalid.
  error InvalidAssetId();

  /// @notice Thrown when updating a reserve if it is not listed.
  error ReserveNotListed();

  /// @notice Thrown when a reserve is not borrowable during a `borrow` action.
  error ReserveNotBorrowable();

  /// @notice Thrown when a reserve is paused during an attempted action.
  error ReservePaused();

  /// @notice Thrown when a reserve is frozen.
  /// @dev Can only occur during an attempted `supply`, `borrow`, or `setUsingAsCollateral` action.
  error ReserveFrozen();

  /// @notice Thrown when an action causes a user's health factor to fall below the liquidation threshold.
  error HealthFactorBelowThreshold();

  /// @notice Thrown when collateral cannot be liquidated.
  error CollateralCannotBeLiquidated();

  /// @notice Thrown when a specified reserve is not borrowed by the user during liquidation.
  error SpecifiedCurrencyNotBorrowedByUser();

  /// @notice Thrown when an unauthorized caller attempts an action.
  error Unauthorized();

  /// @notice Thrown if a config key is uninitialized when updating a dynamic reserve config.
  error ConfigKeyUninitialized();

  /// @notice Thrown if an inactive position manager is set as a user's position manager.
  error InactivePositionManager();

  /// @notice Thrown when a signature is invalid.
  error InvalidSignature();

  /// @notice Thrown for an invalid zero address.
  error InvalidAddress();

  /// @notice Thrown when the oracle decimals are not 8 in the constructor.
  error InvalidOracleDecimals();

  /// @notice Thrown when a collateral risk exceeds the maximum allowed.
  error InvalidCollateralRisk();

  /// @notice Thrown if a liquidation config is invalid when it is updated.
  error InvalidLiquidationConfig();

  /// @notice Thrown when a liquidation fee is invalid.
  error InvalidLiquidationFee();

  /// @notice Thrown when a collateral factor and max liquidation bonus are invalid.
  error InvalidCollateralFactorAndMaxLiquidationBonus();

  /// @notice Thrown when a self-liquidation is attempted.
  error SelfLiquidation();

  /// @notice Thrown during liquidation when a user's health factor is not below the liquidation threshold.
  error HealthFactorNotBelowThreshold();

  /// @notice Thrown when dust debt remains after a liquidation.
  error MustNotLeaveDust();

  /// @notice Thrown when a debt to cover input is zero.
  error InvalidDebtToCover();

  /// @notice Thrown when trying to set zero collateralFactor on historic dynamic configuration keys.
  error InvalidCollateralFactor();

  /// @notice Updates the liquidation config.
  /// @param config The liquidation config.
  function updateLiquidationConfig(LiquidationConfig calldata config) external;

  /// @notice Updates the price source of a reserve.
  /// @param reserveId The identifier of the reserve.
  /// @param priceSource The address of the price source.
  function updateReservePriceSource(uint256 reserveId, address priceSource) external;

  /// @notice Adds a new reserve to the spoke.
  /// @dev Allowed even if the spoke has not yet been added to the hub.
  /// @dev Allowed even if the `active` flag is `false`.
  /// @dev Allowed even if the spoke has been added but the `addCap` is zero.
  /// @param hub The address of the Hub where the asset is listed.
  /// @param assetId The identifier of the asset in the Hub.
  /// @param priceSource The address of the price source for the asset.
  /// @param config The initial reserve configuration.
  /// @param dynamicConfig The initial dynamic reserve configuration.
  /// @return The identifier of the newly added reserve.
  function addReserve(
    address hub,
    uint256 assetId,
    address priceSource,
    ReserveConfig calldata config,
    DynamicReserveConfig calldata dynamicConfig
  ) external returns (uint256);

  /// @notice Updates the reserve config for a given reserve.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @param reserveId The identifier of the reserve.
  /// @param params The new reserve config.
  function updateReserveConfig(uint256 reserveId, ReserveConfig calldata params) external;

  /// @notice Updates the dynamic reserve config for a given reserve.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @dev Appends dynamic config to the next valid config key, and overrides existing config if the key is already used.
  /// @param reserveId The identifier of the reserve.
  /// @param dynamicConfig The new dynamic reserve config.
  /// @return configKey The key of the added dynamic config.
  function addDynamicReserveConfig(
    uint256 reserveId,
    DynamicReserveConfig calldata dynamicConfig
  ) external returns (uint16 configKey);

  /// @notice Updates the dynamic reserve config for a given reserve at the specified key.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @dev Reverts with `ConfigKeyUninitialized` if the config key has not been initialized yet.
  /// @dev Reverts with `InvalidCollateralFactor` if the collateral factor is 0.
  /// @param reserveId The identifier of the reserve.
  /// @param configKey The key of the config to update.
  /// @param dynamicConfig The new dynamic reserve config.
  function updateDynamicReserveConfig(
    uint256 reserveId,
    uint16 configKey,
    DynamicReserveConfig calldata dynamicConfig
  ) external;

  /// @notice Allows an approved caller (admin) to toggle the active status of position manager.
  /// @param positionManager The address of the position manager.
  /// @param active True if positionManager is to be set as active, false otherwise.
  function updatePositionManager(address positionManager, bool active) external;

  /// @notice Allows suppliers to enable/disable a specific supplied reserve as collateral.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @dev Caller must be `onBehalfOf` or an authorized position manager for `onBehalfOf`.
  /// @param reserveId The reserve identifier of the underlying asset.
  /// @param usingAsCollateral True if the user wants to use the supply as collateral, false otherwise.
  /// @param onBehalfOf The owner of the position being modified.
  function setUsingAsCollateral(
    uint256 reserveId,
    bool usingAsCollateral,
    address onBehalfOf
  ) external;

  /// @notice Allows updating the risk premium on onBehalfOf position.
  /// @dev Caller must be `onBehalfOf`, an authorized position manager for `onBehalfOf`, or admin.
  /// @param onBehalfOf The owner of the position being modified.
  function updateUserRiskPremium(address onBehalfOf) external;

  /// @notice Allows updating the dynamic configuration for all collateral reserves on onBehalfOf position.
  /// @dev Caller must be `onBehalfOf`, an authorized position manager for `onBehalfOf`, or admin.
  /// @param onBehalfOf The owner of the position being modified.
  function updateUserDynamicConfig(address onBehalfOf) external;

  /// @notice Enables a user to grant or revoke approval for a position manager
  /// @param positionManager The address of the position manager.
  /// @param approve True to approve the position manager, false to revoke approval.
  function setUserPositionManager(address positionManager, bool approve) external;

  /// @notice Enables a user to grant or revoke approval for a position manager using an EIP712-typed intent.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param positionManager The address of the position manager.
  /// @param user The address of the user on whose behalf position manager can act.
  /// @param approve True to approve the position manager, false to revoke approval.
  /// @param nonce The key-prefixed nonce for the signature.
  /// @param deadline The deadline for the signature.
  /// @param signature The EIP712-compliant signature bytes.
  function setUserPositionManagerWithSig(
    address positionManager,
    address user,
    bool approve,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external;

  /// @notice Allows position manager (as caller) to renounce their approval given by the user.
  /// @param user The address of the user.
  function renouncePositionManagerRole(address user) external;

  /// @notice Returns the address of the external `LiquidationLogic` library.
  /// @return The address of the library.
  function getLiquidationLogic() external pure returns (address);

  /// @notice Returns whether positionManager is active and approved by user.
  /// @param user The address of the user.
  /// @param positionManager The address of the position manager.
  /// @return True if positionManager is active and approved by user, false otherwise.
  function isPositionManager(address user, address positionManager) external view returns (bool);

  /// @notice Returns whether positionManager is currently activated by governance.
  /// @param positionManager The address of the position manager.
  /// @return True if positionManager is currently active, false otherwise.
  function isPositionManagerActive(address positionManager) external view returns (bool);

  /// @notice Allows consuming a permit signature for the given reserve's underlying asset.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @dev Spender is the corresponding hub of the given reserve.
  /// @param reserveId The identifier of the reserve.
  /// @param onBehalfOf The address of the user on whose behalf the permit is being used.
  /// @param value The amount of the underlying asset to permit.
  /// @param deadline The deadline for the permit.
  function permitReserve(
    uint256 reserveId,
    address onBehalfOf,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;

  /// @notice Returns the reserve struct data in storage.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @param reserveId The identifier of the reserve.
  function getReserve(uint256 reserveId) external view returns (Reserve memory);

  /// @notice Returns the reserve configuration struct data in storage.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @param reserveId The identifier of the reserve.
  function getReserveConfig(uint256 reserveId) external view returns (ReserveConfig memory);

  /// @notice Returns the dynamic reserve configuration struct data in storage.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @param reserveId The identifier of the reserve.
  function getDynamicReserveConfig(
    uint256 reserveId
  ) external view returns (DynamicReserveConfig memory);

  /// @notice Returns the dynamic reserve configuration struct at the specified key.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @param reserveId The identifier of the reserve.
  /// @param configKey The key of the dynamic config.
  function getDynamicReserveConfig(
    uint256 reserveId,
    uint16 configKey
  ) external view returns (DynamicReserveConfig memory);

  /// @notice Returns the liquidation config struct.
  function getLiquidationConfig() external view returns (LiquidationConfig memory);

  /// @notice Returns the liquidation bonus for a given health factor, based on the user's current dynamic configuration.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @param reserveId The identifier of the reserve.
  /// @param user The address of the user.
  /// @param healthFactor The health factor of the user.
  function getLiquidationBonus(
    uint256 reserveId,
    address user,
    uint256 healthFactor
  ) external view returns (uint256);

  /// @notice Returns the most up-to-date user account data information.
  /// @dev Utilizes user's current dynamic configuration of user position.
  function getUserAccountData(address user) external view returns (UserAccountData memory);

  /// @notice Returns the user position struct in storage.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @param reserveId The identifier of the reserve.
  /// @param user The address of the user.
  function getUserPosition(
    uint256 reserveId,
    address user
  ) external view returns (UserPosition memory);

  /// @notice Returns true if the reserve is set as collateral for the user, false otherwise.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @dev Even if enabled as collateral, it will only count towards user position if the collateral factor is greater than 0.
  /// @param reserveId The identifier of the reserve.
  /// @param user The address of the user.
  function isUsingAsCollateral(uint256 reserveId, address user) external view returns (bool);

  /// @notice Returns true if the user is borrowing the reserve, false otherwise.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @param reserveId The identifier of the reserve.
  /// @param user The address of the user.
  function isBorrowing(uint256 reserveId, address user) external view returns (bool);

  /// @notice Returns the number of listed reserves on the spoke.
  /// @dev Count includes reserves that are not currently active.
  function getReserveCount() external view returns (uint256);

  /// @notice Returns the maximum allowed value for an asset identifier.
  /// @return The maximum asset identifier value (inclusive).
  function MAX_ALLOWED_ASSET_ID() external view returns (uint256);

  /// @notice Returns the minimum health factor below which a position is considered unhealthy and subject to liquidation.
  /// @return The minimum health factor considered healthy, expressed in WAD (18 decimals) (e.g. 1e18 is 1.00).
  function HEALTH_FACTOR_LIQUIDATION_THRESHOLD() external view returns (uint64);

  /// @notice Returns the minimum required remaining base currency amount after a partial liquidation.
  /// @return The minimum debt amount considered as dust, denominated in USD with 26 decimals.
  function DUST_DEBT_LIQUIDATION_THRESHOLD() external view returns (uint256);

  /// @notice Returns the maximum allowed collateral risk value for a reserve.
  /// @return The maximum collateral risk value, expressed in bps (e.g. 100_00 is 100.00%).
  function MAX_ALLOWED_COLLATERAL_RISK() external view returns (uint24);

  /// @notice Returns the number of decimals used by the oracle.
  /// @return The number of decimals.
  function ORACLE_DECIMALS() external view returns (uint8);

  /// @notice Returns the address of the AaveOracle contract.
  function ORACLE() external view returns (address);

  /// @notice Returns the EIP-712 domain separator.
  function DOMAIN_SEPARATOR() external view returns (bytes32);

  /// @notice Returns the type hash for the SetUserPositionManager intent.
  /// @return The bytes-encoded EIP-712 struct hash representing the intent.
  function SET_USER_POSITION_MANAGER_TYPEHASH() external view returns (bytes32);
}
