// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {HubEngine} from 'src/config-engine/libraries/HubEngine.sol';
import {SpokeEngine} from 'src/config-engine/libraries/SpokeEngine.sol';
import {AccessManagerEngine} from 'src/config-engine/libraries/AccessManagerEngine.sol';
import {PositionManagerEngine} from 'src/config-engine/libraries/PositionManagerEngine.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';

/// @title AaveV4ConfigEngine
/// @author Aave Labs
/// @notice Implementation of IAaveV4ConfigEngine. Delegates to external library contracts for
/// each action category. Invoked via delegatecall from payload contracts.
contract AaveV4ConfigEngine is IAaveV4ConfigEngine {
  /// @dev The address of this engine deployment.
  address private immutable SELF;

  /// @notice Modifier that reverts unless the engine is reached via delegatecall.
  modifier onlyDelegateCall() {
    require(address(this) != SELF, OnlyDelegateCall());
    _;
  }

  /// @dev Constructor.
  constructor() {
    SELF = address(this);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubAssetListings(AssetListing[] calldata listings) external onlyDelegateCall {
    HubEngine.executeHubAssetListings(listings);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubAssetConfigUpdates(
    AssetConfigUpdate[] calldata updates
  ) external onlyDelegateCall {
    HubEngine.executeHubAssetConfigUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubSpokeToAssetsAdditions(
    SpokeToAssetsAddition[] calldata additions
  ) external onlyDelegateCall {
    HubEngine.executeHubSpokeToAssetsAdditions(additions);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubSpokeConfigUpdates(
    SpokeConfigUpdate[] calldata updates
  ) external onlyDelegateCall {
    HubEngine.executeHubSpokeConfigUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubAssetHalts(AssetHalt[] calldata halts) external onlyDelegateCall {
    HubEngine.executeHubAssetHalts(halts);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubAssetDeactivations(
    AssetDeactivation[] calldata deactivations
  ) external onlyDelegateCall {
    HubEngine.executeHubAssetDeactivations(deactivations);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubAssetCapsResets(AssetCapsReset[] calldata resets) external onlyDelegateCall {
    HubEngine.executeHubAssetCapsResets(resets);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubSpokeDeactivations(
    SpokeDeactivation[] calldata deactivations
  ) external onlyDelegateCall {
    HubEngine.executeHubSpokeDeactivations(deactivations);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubSpokeCapsResets(SpokeCapsReset[] calldata resets) external onlyDelegateCall {
    HubEngine.executeHubSpokeCapsResets(resets);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeReserveListings(
    ReserveListing[] calldata listings
  ) external onlyDelegateCall {
    SpokeEngine.executeSpokeReserveListings(listings);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeReserveConfigUpdates(
    ReserveConfigUpdate[] calldata updates
  ) external onlyDelegateCall {
    SpokeEngine.executeSpokeReserveConfigUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeLiquidationConfigUpdates(
    LiquidationConfigUpdate[] calldata updates
  ) external onlyDelegateCall {
    SpokeEngine.executeSpokeLiquidationConfigUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeDynamicReserveConfigAdditions(
    DynamicReserveConfigAddition[] calldata additions
  ) external onlyDelegateCall {
    SpokeEngine.executeSpokeDynamicReserveConfigAdditions(additions);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeDynamicReserveConfigUpdates(
    DynamicReserveConfigUpdate[] calldata updates
  ) external onlyDelegateCall {
    SpokeEngine.executeSpokeDynamicReserveConfigUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokePositionManagerUpdates(
    PositionManagerUpdate[] calldata updates
  ) external onlyDelegateCall {
    SpokeEngine.executeSpokePositionManagerUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executePositionManagerSpokeRegistrations(
    SpokeRegistration[] calldata registrations
  ) external onlyDelegateCall {
    PositionManagerEngine.executePositionManagerSpokeRegistrations(registrations);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executePositionManagerRoleRenouncements(
    PositionManagerRoleRenouncement[] calldata renouncements
  ) external onlyDelegateCall {
    PositionManagerEngine.executePositionManagerRoleRenouncements(renouncements);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeRoleMemberships(RoleMembership[] calldata memberships) external onlyDelegateCall {
    AccessManagerEngine.executeRoleMemberships(memberships);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeRoleUpdates(RoleUpdate[] calldata updates) external onlyDelegateCall {
    AccessManagerEngine.executeRoleUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeTargetFunctionRoleUpdates(
    TargetFunctionRoleUpdate[] calldata updates
  ) external onlyDelegateCall {
    AccessManagerEngine.executeTargetFunctionRoleUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeTargetAdminDelayUpdates(
    TargetAdminDelayUpdate[] calldata updates
  ) external onlyDelegateCall {
    AccessManagerEngine.executeTargetAdminDelayUpdates(updates);
  }
}
