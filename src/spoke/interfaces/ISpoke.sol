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
  /// @notice Reserve level data.
  /// @dev underlying The address of the underlying asset.
  /// @dev hub The address of the associated Hub.
  /// @dev assetId The identifier of the asset in the Hub.
  /// @dev decimals The number of decimals of the underlying asset.
  /// @dev dynamicConfigKey The key of the last reserve dynamic config.
  /// @dev paused True if all actions are prevented for the reserve.
  /// @dev frozen True if new activity is prevented for the reserve.
  /// @dev borrowable True if the reserve is borrowable.
  /// @dev collateralRisk The risk associated with a collateral asset, expressed in BPS.
  struct Reserve {
    address underlying;
    //
    IHubBase hub;
    uint16 assetId;
    uint8 decimals;
    uint24 dynamicConfigKey;
    bool paused;
    bool frozen;
    bool borrowable;
    uint24 collateralRisk;
  }

  /// @notice Reserve configuration. Subset of the `Reserve` struct.
  struct ReserveConfig {
    bool paused;
    bool frozen;
    bool borrowable;
    uint24 collateralRisk;
  }

  /// @notice Dynamic reserve configuration data.
  /// @dev collateralFactor The proportion of a reserve's value eligible to be used as collateral, expressed in BPS.
  /// @dev maxLiquidationBonus The maximum extra amount of collateral given to the liquidator as bonus, expressed in BPS. 100_00 represents 0.00% bonus.
  /// @dev liquidationFee The protocol fee charged on liquidations, taken from the collateral bonus given to the liquidator, expressed in BPS.
  struct DynamicReserveConfig {
    uint16 collateralFactor;
    uint32 maxLiquidationBonus;
    uint16 liquidationFee;
  }

  /// @notice Liquidation configuration data.
  /// @dev targetHealthFactor The ideal health factor to restore a user position during liquidation, expressed in WAD.
  /// @dev healthFactorForMaxBonus The health factor under which liquidation bonus is maximum, expressed in WAD.
  /// @dev liquidationBonusFactor The value multiplied by `maxLiquidationBonus` to compute the minimum liquidation bonus, expressed in BPS.
  struct LiquidationConfig {
    uint128 targetHealthFactor;
    uint64 healthFactorForMaxBonus;
    uint16 liquidationBonusFactor;
  }

  /// @notice User position data per reserve.
  /// @dev drawnShares The drawn shares of the user position.
  /// @dev realizedPremiumRay The interest-free premium debt already accrued for the user position, expressed in asset units and scaled by RAY.
  /// @dev premiumShares The premium shares of the user position.
  /// @dev premiumOffsetRay The premium offset of the user position, used to calculate the premium, expressed in asset units and scaled by RAY.
  /// @dev suppliedShares The supplied shares of the user position.
  /// @dev dynamicConfigKey The key of the user position dynamic config.
  struct UserPosition {
    uint120 drawnShares;
    uint120 premiumShares;
    //
    uint200 realizedPremiumRay;
    //
    uint200 premiumOffsetRay;
    //
    uint120 suppliedShares;
    uint24 dynamicConfigKey;
  }

  /// @notice Position manager configuration data.
  /// @dev approval The mapping of position manager user approvals.
  /// @dev active True if the position manager is active.
  struct PositionManagerConfig {
    mapping(address user => bool) approval;
    bool active;
  }

  /// @notice User position status data.
  /// @dev map The map of bitmap buckets for the position status.
  /// @dev hasPositiveRiskPremium True if the user position has a risk premium strictly greater than 0.
  struct PositionStatus {
    mapping(uint256 bucket => uint256) map;
    bool hasPositiveRiskPremium;
  }

  /// @notice User account data describing a user position and its health.
  /// @dev riskPremium The risk premium of the user position, expressed in BPS.
  /// @dev avgCollateralFactor The weighted average collateral factor of the user position, expressed in WAD.
  /// @dev healthFactor The health factor of the user position, expressed in WAD. 1e18 represents a health factor of 1.00.
  /// @dev totalCollateralValue The total collateral value of the user position, expressed in units of base currency. 1e26 represents 1 USD.
  /// @dev totalDebtValue The total debt value of the user position, expressed in units of base currency. 1e26 represents 1 USD.
  /// @dev activeCollateralCount The number of active collaterals, which includes reserves with `collateralFactor` > 0, `enabledAsCollateral` and `suppliedAmount` > 0.
  /// @dev borrowedCount The number of borrowed reserves of the user position.
  struct UserAccountData {
    uint256 riskPremium;
    uint256 avgCollateralFactor;
    uint256 healthFactor;
    uint256 totalCollateralValue;
    uint256 totalDebtValue;
    uint256 activeCollateralCount;
    uint256 borrowedCount;
  }

  /// @notice Emitted when the oracle address of the spoke is updated.
  /// @param oracle The new address of the oracle.
  event UpdateOracle(address oracle);

  /// @notice Emitted when a liquidation config is updated.
  /// @param config The new liquidation config.
  event UpdateLiquidationConfig(LiquidationConfig config);

  /// @notice Emitted when a reserve is added.
  /// @param reserveId The identifier of the reserve.
  /// @param assetId The identifier of the asset.
  /// @param hub The address of the Hub where the asset is listed.
  event AddReserve(uint256 indexed reserveId, uint256 indexed assetId, address indexed hub);

  /// @notice Emitted when a reserve configuration is updated.
  /// @param reserveId The identifier of the reserve.
  /// @param config The reserve configuration.
  event UpdateReserveConfig(uint256 indexed reserveId, ReserveConfig config);

  /// @notice Emitted when the price source of a reserve is updated.
  /// @param reserveId The identifier of the reserve.
  /// @param priceSource The address of the new price source.
  event UpdateReservePriceSource(uint256 indexed reserveId, address indexed priceSource);

  /// @notice Emitted when a dynamic reserve config is added.
  /// @dev The config key is the next available key for the reserve, which is now the latest config
  /// key of the reserve.
  /// @param reserveId The identifier of the reserve.
  /// @param dynamicConfigKey The key of the added dynamic config.
  /// @param config The dynamic reserve config.
  event AddDynamicReserveConfig(
    uint256 indexed reserveId,
    uint24 indexed dynamicConfigKey,
    DynamicReserveConfig config
  );

  /// @notice Emitted when a dynamic reserve config is updated.
  /// @param reserveId The identifier of the reserve.
  /// @param dynamicConfigKey The key of the updated dynamic config.
  /// @param config The dynamic reserve config.
  event UpdateDynamicReserveConfig(
    uint256 indexed reserveId,
    uint24 indexed dynamicConfigKey,
    DynamicReserveConfig config
  );

  /// @notice Emitted on updatePositionManager action.
  /// @param positionManager The address of the position manager.
  /// @param active True if position manager has become active.
  event UpdatePositionManager(address indexed positionManager, bool active);

  /// @notice Emitted on setUsingAsCollateral action.
  /// @param reserveId The reserve identifier of the underlying asset.
  /// @param caller The transaction initiator.
  /// @param user The owner of the position being modified.
  /// @param usingAsCollateral Whether the reserve is enabled or disabled as collateral.
  event SetUsingAsCollateral(
    uint256 indexed reserveId,
    address indexed caller,
    address indexed user,
    bool usingAsCollateral
  );

  /// @notice Emitted when a user's dynamic config is refreshed for all reserves to their latest config key.
  /// @param user The address of the user.
  event RefreshAllUserDynamicConfig(address indexed user);

  /// @notice Emitted when a user's dynamic config is refreshed for a single reserve to its latest config key.
  /// @param user The address of the user.
  /// @param reserveId The identifier of the reserve.
  event RefreshSingleUserDynamicConfig(address indexed user, uint256 reserveId);

  /// @notice Emitted on updateUserRiskPremium action.
  /// @param user The owner of the position being modified.
  /// @param riskPremium The new risk premium (BPS) value of user.
  event UpdateUserRiskPremium(address indexed user, uint256 riskPremium);

  /// @notice Emitted on setUserPositionManager or renouncePositionManagerRole action.
  /// @param user The address of the user on whose behalf position manager can act.
  /// @param positionManager The address of the position manager.
  /// @param approve True if position manager approval was granted, false if it was revoked.
  event SetUserPositionManager(address indexed user, address indexed positionManager, bool approve);

  /// @notice Emitted on refreshPremiumDebt action.
  /// @param reserveId The identifier of the reserve.
  /// @param user The address of the user.
  /// @param premiumDelta The change in premium values.
  event RefreshPremiumDebt(
    uint256 indexed reserveId,
    address indexed user,
    IHubBase.PremiumDelta premiumDelta
  );

  /// @notice Emitted on liquidations that report deficit to the Hub.
  /// @param reserveId The identifier of the reserve.
  /// @param user The address of the user.
  /// @param drawnShares The amount of drawn shares reported as deficit.
  /// @param premiumDelta The premium delta data struct reported as deficit.
  event ReportDeficit(
    uint256 indexed reserveId,
    address indexed user,
    uint256 drawnShares,
    IHubBase.PremiumDelta premiumDelta
  );

  /// @notice Thrown when an asset is not listed on the Hub when adding a reserve.
  error AssetNotListed();

  /// @notice Thrown when adding a new reserve if that reserve already exists for a given Hub/assetId pair.
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

  /// @notice Thrown when a specified reserve is not supplied by the user during liquidation.
  error ReserveNotSupplied();

  /// @notice Thrown when a specified reserve is not borrowed by the user during liquidation.
  error ReserveNotBorrowed();

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

  /// @notice Thrown when trying to set zero collateralFactor on historic dynamic configuration keys.
  error InvalidCollateralFactor();

  /// @notice Thrown when a self-liquidation is attempted.
  error SelfLiquidation();

  /// @notice Thrown during liquidation when a user's health factor is not below the liquidation threshold.
  error HealthFactorNotBelowThreshold();

  /// @notice Thrown when collateral or debt dust remains after a liquidation, and neither reserve is fully liquidated.
  error MustNotLeaveDust();

  /// @notice Thrown when a debt to cover input is zero.
  error InvalidDebtToCover();

  /// @notice Thrown when the liquidator tries to receive shares for a collateral reserve that is frozen.
  error CannotReceiveShares();

  /// @notice Thrown when the maximum number of dynamic config keys is reached.
  error MaximumDynamicConfigKeyReached();

  /// @notice Updates the liquidation config.
  /// @param config The liquidation config.
  function updateLiquidationConfig(LiquidationConfig calldata config) external;

  /// @notice Adds a new reserve to the spoke.
  /// @dev Allowed even if the spoke has not yet been added to the Hub.
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

  /// @notice Updates the price source of a reserve.
  /// @param reserveId The identifier of the reserve.
  /// @param priceSource The address of the price source.
  function updateReservePriceSource(uint256 reserveId, address priceSource) external;

  /// @notice Updates the dynamic reserve config for a given reserve.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @dev Appends dynamic config to the next available key; reverts if `MAX_ALLOWED_DYNAMIC_CONFIG_KEY` is reached.
  /// @param reserveId The identifier of the reserve.
  /// @param dynamicConfig The new dynamic reserve config.
  /// @return dynamicConfigKey The key of the added dynamic config.
  function addDynamicReserveConfig(
    uint256 reserveId,
    DynamicReserveConfig calldata dynamicConfig
  ) external returns (uint24 dynamicConfigKey);

  /// @notice Updates the dynamic reserve config for a given reserve at the specified key.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @dev Reverts with `ConfigKeyUninitialized` if the config key has not been initialized yet.
  /// @dev Reverts with `InvalidCollateralFactor` if the collateral factor is 0.
  /// @param reserveId The identifier of the reserve.
  /// @param dynamicConfigKey The key of the config to update.
  /// @param dynamicConfig The new dynamic reserve config.
  function updateDynamicReserveConfig(
    uint256 reserveId,
    uint24 dynamicConfigKey,
    DynamicReserveConfig calldata dynamicConfig
  ) external;

  /// @notice Allows an approved caller (admin) to toggle the active status of position manager.
  /// @param positionManager The address of the position manager.
  /// @param active True if positionManager is to be set as active.
  function updatePositionManager(address positionManager, bool active) external;

  /// @notice Allows suppliers to enable/disable a specific supplied reserve as collateral.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @dev Caller must be `onBehalfOf` or an authorized position manager for `onBehalfOf`.
  /// @param reserveId The reserve identifier of the underlying asset.
  /// @param usingAsCollateral True if the user wants to use the supply as collateral.
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

  /// @notice Allows consuming a permit signature for the given reserve's underlying asset.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @dev Spender is the corresponding Hub of the given reserve.
  /// @param reserveId The identifier of the reserve.
  /// @param onBehalfOf The address of the user on whose behalf the permit is being used.
  /// @param value The amount of the underlying asset to permit.
  /// @param deadline The deadline for the permit.
  function permitReserve(
    uint256 reserveId,
    address onBehalfOf,
    uint256 value,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external;

  /// @notice Returns the liquidation config struct.
  function getLiquidationConfig() external view returns (LiquidationConfig memory);

  /// @notice Returns the number of listed reserves on the spoke.
  /// @dev Count includes reserves that are not currently active.
  function getReserveCount() external view returns (uint256);

  /// @notice Returns the reserve struct data in storage.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @param reserveId The identifier of the reserve.
  function getReserve(uint256 reserveId) external view returns (Reserve memory);

  /// @notice Returns the reserve configuration struct data in storage.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @param reserveId The identifier of the reserve.
  function getReserveConfig(uint256 reserveId) external view returns (ReserveConfig memory);

  /// @notice Returns the dynamic reserve configuration struct at the specified key.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @dev Does not revert if `dynamicConfigKey` is unset.
  /// @param reserveId The identifier of the reserve.
  /// @param dynamicConfigKey The key of the dynamic config.
  function getDynamicReserveConfig(
    uint256 reserveId,
    uint24 dynamicConfigKey
  ) external view returns (DynamicReserveConfig memory);

  /// @notice Returns two flags indicating whether the reserve is used as collateral and whether it is borrowed by the user.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @dev Even if enabled as collateral, it will only count towards user position if the collateral factor is greater than 0.
  /// @param reserveId The identifier of the reserve.
  /// @param user The address of the user.
  /// @return True if the reserve is enabled as collateral by the user.
  /// @return True if the reserve is borrowed by the user.
  function getUserReserveStatus(uint256 reserveId, address user) external view returns (bool, bool);

  /// @notice Returns the user position struct in storage.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @param reserveId The identifier of the reserve.
  /// @param user The address of the user.
  function getUserPosition(
    uint256 reserveId,
    address user
  ) external view returns (UserPosition memory);

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

  /// @notice Returns whether positionManager is currently activated by governance.
  /// @param positionManager The address of the position manager.
  /// @return True if positionManager is currently active.
  function isPositionManagerActive(address positionManager) external view returns (bool);

  /// @notice Returns whether positionManager is active and approved by user.
  /// @param user The address of the user.
  /// @param positionManager The address of the position manager.
  /// @return True if positionManager is active and approved by user.
  function isPositionManager(address user, address positionManager) external view returns (bool);

  /// @notice Returns the EIP-712 domain separator.
  function DOMAIN_SEPARATOR() external view returns (bytes32);

  /// @notice Returns the address of the external `LiquidationLogic` library.
  /// @return The address of the library.
  function getLiquidationLogic() external pure returns (address);

  /// @notice Returns the type hash for the SetUserPositionManager intent.
  /// @return The bytes-encoded EIP-712 struct hash representing the intent.
  function SET_USER_POSITION_MANAGER_TYPEHASH() external view returns (bytes32);

  /// @notice Returns the address of the AaveOracle contract.
  function ORACLE() external view returns (address);
}
