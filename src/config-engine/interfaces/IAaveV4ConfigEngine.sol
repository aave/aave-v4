// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';

/// @title IAaveV4ConfigEngine
/// @author Aave Labs
/// @notice Interface for the Aave V4 Config Engine, defining all structs and engine method signatures.
/// The engine is stateless and invoked via delegatecall from payload contracts.
/// All numeric fields in config structs use uint256 so that type(uint256).max can serve as
/// the universal KEEP_CURRENT sentinel. Boolean fields use uint256 (0=false, 1=true, KEEP_CURRENT=skip).
interface IAaveV4ConfigEngine {
  /// @notice Parameters for tokenization of an asset on a Hub when listing the asset.
  /// @dev addCap The add cap for the TokenizationSpoke (0 means no tokenization).
  /// @dev name The name for the TokenizationSpoke.
  /// @dev symbol The symbol for the TokenizationSpoke.
  struct TokenizationSpokeConfig {
    uint256 addCap;
    string name;
    string symbol;
  }

  /// @notice Parameters for listing a new asset on a Hub.
  /// @dev hubConfigurator The HubConfigurator to use for this action.
  /// @dev hub The address of the Hub.
  /// @dev underlying The address of the underlying asset.
  /// @dev feeReceiver The address of the fee receiver Spoke.
  /// @dev liquidityFee The liquidity fee of the asset, in BPS.
  /// @dev irStrategy The address of the interest rate strategy contract.
  /// @dev irData The interest rate data to apply to the given asset.
  /// @dev tokenization The tokenization configuration for the asset.
  struct AssetListing {
    IHubConfigurator hubConfigurator;
    address hub;
    address underlying;
    address feeReceiver;
    uint256 liquidityFee;
    address irStrategy;
    IAssetInterestRateStrategy.InterestRateData irData;
    TokenizationSpokeConfig tokenization;
  }

  /// @notice Parameters for updating asset config (fee, interest rate, reinvestment) on a Hub.
  /// @dev hubConfigurator The HubConfigurator to use for this action.
  /// @dev hub The address of the Hub.
  /// @dev underlying The address of the underlying asset.
  /// @dev liquidityFee The new liquidity fee (KEEP_CURRENT to skip).
  /// @dev feeReceiver The new fee receiver (KEEP_CURRENT_ADDRESS to skip).
  /// @dev irStrategy The new interest rate strategy (KEEP_CURRENT_ADDRESS to skip strategy update).
  /// @dev irData The interest rate data. If irStrategy != KEEP_CURRENT_ADDRESS, calls updateInterestRateStrategy.
  /// Otherwise individual fields use KEEP_CURRENT_UINT16/KEEP_CURRENT_UINT32 sentinels;
  /// non-sentinel fields trigger a read-modify-write via updateInterestRateData.
  /// @dev reinvestmentController The new reinvestment controller (KEEP_CURRENT_ADDRESS to skip).
  struct AssetConfigUpdate {
    IHubConfigurator hubConfigurator;
    address hub;
    address underlying;
    uint256 liquidityFee;
    address feeReceiver;
    address irStrategy;
    IAssetInterestRateStrategy.InterestRateData irData;
    address reinvestmentController;
  }

  /// @notice Pairs an underlying asset address with its Spoke configuration.
  /// @dev underlying The address of the underlying asset.
  /// @dev config The Spoke configuration for the asset.
  struct SpokeAssetConfig {
    address underlying;
    IHub.SpokeConfig config;
  }

  /// @notice Parameters for registering a Spoke for multiple assets on a Hub.
  /// @dev hubConfigurator The HubConfigurator to use for this action.
  /// @dev hub The address of the Hub.
  /// @dev spoke The address of the Spoke.
  /// @dev assets The list of underlying assets with their Spoke configurations.
  struct SpokeToAssetsAddition {
    IHubConfigurator hubConfigurator;
    address hub;
    address spoke;
    SpokeAssetConfig[] assets;
  }

  /// @notice Parameters for updating Spoke config (caps, risk premium threshold, status) on a Hub.
  /// @dev hubConfigurator The HubConfigurator to use for this action.
  /// @dev hub The address of the Hub.
  /// @dev underlying The address of the underlying asset.
  /// @dev spoke The address of the Spoke.
  /// @dev addCap The new add cap (KEEP_CURRENT to skip).
  /// @dev drawCap The new draw cap (KEEP_CURRENT to skip).
  /// @dev riskPremiumThreshold The new risk premium threshold (KEEP_CURRENT to skip).
  /// @dev active New active flag (0=false, 1=true, KEEP_CURRENT=skip).
  /// @dev halted New halted flag (0=false, 1=true, KEEP_CURRENT=skip).
  struct SpokeConfigUpdate {
    IHubConfigurator hubConfigurator;
    address hub;
    address underlying;
    address spoke;
    uint256 addCap;
    uint256 drawCap;
    uint256 riskPremiumThreshold;
    uint256 active;
    uint256 halted;
  }

  /// @notice Parameters for halting an asset on a Hub.
  /// @dev hubConfigurator The HubConfigurator to use for this action.
  /// @dev hub The address of the Hub.
  /// @dev underlying The address of the underlying asset.
  struct AssetHalt {
    IHubConfigurator hubConfigurator;
    address hub;
    address underlying;
  }

  /// @notice Parameters for deactivating an asset on a Hub.
  /// @dev hubConfigurator The HubConfigurator to use for this action.
  /// @dev hub The address of the Hub.
  /// @dev underlying The address of the underlying asset.
  struct AssetDeactivation {
    IHubConfigurator hubConfigurator;
    address hub;
    address underlying;
  }

  /// @notice Parameters for resetting asset caps on a Hub to 0.
  /// @dev hubConfigurator The HubConfigurator to use for this action.
  /// @dev hub The address of the Hub.
  /// @dev underlying The address of the underlying asset.
  struct AssetCapsReset {
    IHubConfigurator hubConfigurator;
    address hub;
    address underlying;
  }

  /// @notice Parameters for deactivating a Spoke on a Hub.
  /// @dev hubConfigurator The HubConfigurator to use for this action.
  /// @dev hub The address of the Hub.
  /// @dev spoke The address of the Spoke.
  struct SpokeDeactivation {
    IHubConfigurator hubConfigurator;
    address hub;
    address spoke;
  }

  /// @notice Parameters for resetting Spoke caps on a Hub.
  /// @dev hubConfigurator The HubConfigurator to use for this action.
  /// @dev hub The address of the Hub.
  /// @dev spoke The address of the Spoke.
  struct SpokeCapsReset {
    IHubConfigurator hubConfigurator;
    address hub;
    address spoke;
  }

  /// @notice Parameters for listing a new reserve on a Spoke.
  /// @dev spokeConfigurator The SpokeConfigurator to use for this action.
  /// @dev spoke The address of the Spoke.
  /// @dev hub The address of the Hub.
  /// @dev underlying The address of the underlying asset.
  /// @dev priceSource The address of the price source.
  /// @dev config The configuration of the reserve.
  /// @dev dynamicConfig The dynamic configuration of the reserve.
  struct ReserveListing {
    ISpokeConfigurator spokeConfigurator;
    address spoke;
    address hub;
    address underlying;
    address priceSource;
    ISpoke.ReserveConfig config;
    ISpoke.DynamicReserveConfig dynamicConfig;
  }

  /// @notice Parameters for updating reserve config on a Spoke.
  /// @dev spokeConfigurator The SpokeConfigurator to use for this action.
  /// @dev spoke The address of the Spoke.
  /// @dev hub The address of the Hub.
  /// @dev underlying The address of the underlying asset.
  /// @dev priceSource The new price source address (KEEP_CURRENT_ADDRESS to skip).
  /// @dev collateralRisk New collateral risk (KEEP_CURRENT to skip).
  /// @dev paused New paused flag (0=false, 1=true, KEEP_CURRENT=skip).
  /// @dev frozen New frozen flag (0=false, 1=true, KEEP_CURRENT=skip).
  /// @dev borrowable New borrowable flag (0=false, 1=true, KEEP_CURRENT=skip).
  /// @dev receiveSharesEnabled New receiveSharesEnabled flag (0=false, 1=true, KEEP_CURRENT=skip).
  struct ReserveConfigUpdate {
    ISpokeConfigurator spokeConfigurator;
    address spoke;
    address hub;
    address underlying;
    address priceSource;
    uint256 collateralRisk;
    uint256 paused;
    uint256 frozen;
    uint256 borrowable;
    uint256 receiveSharesEnabled;
  }

  /// @notice Parameters for updating liquidation config on a Spoke.
  /// @dev spokeConfigurator The SpokeConfigurator to use for this action.
  /// @dev spoke The address of the Spoke.
  /// @dev targetHealthFactor The new target health factor (KEEP_CURRENT to skip).
  /// @dev healthFactorForMaxBonus The new health factor for max bonus (KEEP_CURRENT to skip).
  /// @dev liquidationBonusFactor The new liquidation bonus factor (KEEP_CURRENT to skip).
  struct LiquidationConfigUpdate {
    ISpokeConfigurator spokeConfigurator;
    address spoke;
    uint256 targetHealthFactor;
    uint256 healthFactorForMaxBonus;
    uint256 liquidationBonusFactor;
  }

  /// @notice Parameters for adding a dynamic reserve config on a Spoke.
  /// @dev spokeConfigurator The SpokeConfigurator to use for this action.
  /// @dev spoke The address of the Spoke.
  /// @dev hub The address of the Hub.
  /// @dev underlying The address of the underlying asset.
  /// @dev dynamicConfig The new dynamic config.
  struct DynamicReserveConfigAddition {
    ISpokeConfigurator spokeConfigurator;
    address spoke;
    address hub;
    address underlying;
    ISpoke.DynamicReserveConfig dynamicConfig;
  }

  /// @notice Parameters for updating a dynamic reserve config on a Spoke.
  /// @dev spokeConfigurator The SpokeConfigurator to use for this action.
  /// @dev spoke The address of the Spoke.
  /// @dev hub The address of the Hub.
  /// @dev underlying The address of the underlying asset.
  /// @dev dynamicConfigKey The key of the dynamic config to update.
  /// @dev collateralFactor New collateral factor (KEEP_CURRENT to skip).
  /// @dev maxLiquidationBonus New max liquidation bonus (KEEP_CURRENT to skip).
  /// @dev liquidationFee New liquidation fee (KEEP_CURRENT to skip).
  struct DynamicReserveConfigUpdate {
    ISpokeConfigurator spokeConfigurator;
    address spoke;
    address hub;
    address underlying;
    uint256 dynamicConfigKey;
    uint256 collateralFactor;
    uint256 maxLiquidationBonus;
    uint256 liquidationFee;
  }

  /// @notice Parameters for updating a position manager on a Spoke.
  /// @dev spokeConfigurator The SpokeConfigurator to use for this action.
  /// @dev spoke The address of the Spoke.
  /// @dev positionManager The address of the position manager.
  /// @dev active The new active flag.
  struct PositionManagerUpdate {
    ISpokeConfigurator spokeConfigurator;
    address spoke;
    address positionManager;
    bool active;
  }

  /// @notice Parameters for registering/deregistering a Spoke on a position manager.
  /// @dev positionManager The position manager address.
  /// @dev spoke The address of the Spoke.
  /// @dev registered Whether to register (true) or deregister (false) the Spoke.
  struct SpokeRegistration {
    address positionManager;
    address spoke;
    bool registered;
  }

  /// @notice Parameters for renouncing the position manager role for a user on a Spoke.
  /// @dev positionManager The position manager address.
  /// @dev spoke The address of the Spoke.
  /// @dev user The address of the user to renounce the role for.
  struct PositionManagerRoleRenouncement {
    address positionManager;
    address spoke;
    address user;
  }

  /// @notice Parameters for granting or revoking a role via AccessManager.
  /// @dev When granted=true → grantRole(roleId, account, executionDelay).
  /// @dev When granted=false → revokeRole(roleId, account). executionDelay is ignored.
  /// @dev authority The AccessManager address.
  /// @dev roleId The role identifier.
  /// @dev account The account to grant/revoke the role to/from.
  /// @dev granted Whether to grant (true) or revoke (false) the role.
  /// @dev executionDelay The execution delay for the account (only used when granted=true).
  struct RoleMembership {
    address authority;
    uint64 roleId;
    address account;
    bool granted;
    uint32 executionDelay;
  }

  /// @notice Parameters for updating role configuration via AccessManager.
  /// @dev Uses type-specific sentinels to skip fields: KEEP_CURRENT_UINT64 for admin/guardian,
  /// KEEP_CURRENT_UINT32 for grantDelay, empty string for label.
  /// @dev authority The AccessManager address.
  /// @dev roleId The role identifier.
  /// @dev admin The new admin role identifier (KEEP_CURRENT_UINT64 to skip).
  /// @dev guardian The new guardian role identifier (KEEP_CURRENT_UINT64 to skip).
  /// @dev grantDelay The new grant delay (KEEP_CURRENT_UINT32 to skip).
  /// @dev label The label string (empty string to skip).
  struct RoleUpdate {
    address authority;
    uint64 roleId;
    uint64 admin;
    uint64 guardian;
    uint32 grantDelay;
    string label;
  }

  /// @notice Parameters for setting target function roles via AccessManager.
  /// @dev authority The AccessManager address.
  /// @dev target The target contract address.
  /// @dev selectors The function selectors.
  /// @dev roleId The role identifier.
  struct TargetFunctionRoleUpdate {
    address authority;
    address target;
    bytes4[] selectors;
    uint64 roleId;
  }

  /// @notice Parameters for setting target admin delay via AccessManager.
  /// @dev authority The AccessManager address.
  /// @dev target The target contract address.
  /// @dev newDelay The new admin delay.
  struct TargetAdminDelayUpdate {
    address authority;
    address target;
    uint32 newDelay;
  }

  /// @notice Lists new assets on Hubs via the HubConfigurator.
  /// @param listings The asset listings to execute.
  function executeHubAssetListings(AssetListing[] calldata listings) external;

  /// @notice Updates asset config (fee, interest rate, reinvestment) on Hubs.
  /// @param updates The asset config updates to execute.
  function executeHubAssetConfigUpdates(AssetConfigUpdate[] calldata updates) external;

  /// @notice Registers Spokes for multiple assets on Hubs.
  /// @param additions The Spoke-to-assets additions to execute.
  function executeHubSpokeToAssetsAdditions(SpokeToAssetsAddition[] calldata additions) external;

  /// @notice Updates Spoke config (caps, risk premium threshold, status) on Hubs.
  /// @param updates The Spoke config updates to execute.
  function executeHubSpokeConfigUpdates(SpokeConfigUpdate[] calldata updates) external;

  /// @notice Halts assets on Hubs.
  /// @param halts The asset halts to execute.
  function executeHubAssetHalts(AssetHalt[] calldata halts) external;

  /// @notice Deactivates assets on Hubs.
  /// @param deactivations The asset deactivations to execute.
  function executeHubAssetDeactivations(AssetDeactivation[] calldata deactivations) external;

  /// @notice Resets asset caps on Hubs.
  /// @param resets The asset caps resets to execute.
  function executeHubAssetCapsResets(AssetCapsReset[] calldata resets) external;

  /// @notice Deactivates Spokes on Hubs.
  /// @param deactivations The Spoke deactivations to execute.
  function executeHubSpokeDeactivations(SpokeDeactivation[] calldata deactivations) external;

  /// @notice Resets Spoke caps on Hubs.
  /// @param resets The Spoke caps resets to execute.
  function executeHubSpokeCapsResets(SpokeCapsReset[] calldata resets) external;

  /// @notice Lists new reserves on Spokes.
  /// @param listings The reserve listings to execute.
  function executeSpokeReserveListings(ReserveListing[] calldata listings) external;

  /// @notice Updates reserve config on Spokes.
  /// @param updates The reserve config updates to execute.
  function executeSpokeReserveConfigUpdates(ReserveConfigUpdate[] calldata updates) external;

  /// @notice Updates liquidation config on Spokes.
  /// @param updates The liquidation config updates to execute.
  function executeSpokeLiquidationConfigUpdates(
    LiquidationConfigUpdate[] calldata updates
  ) external;

  /// @notice Adds dynamic reserve configs on Spokes.
  /// @param additions The dynamic reserve config additions to execute.
  function executeSpokeDynamicReserveConfigAdditions(
    DynamicReserveConfigAddition[] calldata additions
  ) external;

  /// @notice Updates dynamic reserve configs on Spokes.
  /// @param updates The dynamic reserve config updates to execute.
  function executeSpokeDynamicReserveConfigUpdates(
    DynamicReserveConfigUpdate[] calldata updates
  ) external;

  /// @notice Updates position managers on Spokes.
  /// @param updates The position manager updates to execute.
  function executeSpokePositionManagerUpdates(PositionManagerUpdate[] calldata updates) external;

  /// @notice Registers/deregisters Spokes on position managers.
  /// @param registrations The Spoke registrations to execute.
  function executePositionManagerSpokeRegistrations(
    SpokeRegistration[] calldata registrations
  ) external;

  /// @notice Renounces position manager roles for users on Spokes.
  /// @param renouncements The role renouncements to execute.
  function executePositionManagerRoleRenouncements(
    PositionManagerRoleRenouncement[] calldata renouncements
  ) external;

  /// @notice Grants or revokes roles via AccessManager.
  /// @param memberships The role memberships to execute.
  function executeRoleMemberships(RoleMembership[] calldata memberships) external;

  /// @notice Updates role configuration (admin, guardian, grant delay, label) via AccessManager.
  /// @param updates The role updates to execute.
  function executeRoleUpdates(RoleUpdate[] calldata updates) external;

  /// @notice Updates target function roles via AccessManager.
  /// @param updates The target function role updates to execute.
  function executeTargetFunctionRoleUpdates(TargetFunctionRoleUpdate[] calldata updates) external;

  /// @notice Updates target admin delays via AccessManager.
  /// @param updates The target admin delay updates to execute.
  function executeTargetAdminDelayUpdates(TargetAdminDelayUpdate[] calldata updates) external;
}
