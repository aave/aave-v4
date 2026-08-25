// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {HubEngine} from 'src/config-engine/libraries/HubEngine.sol';
import {SpokeEngine} from 'src/config-engine/libraries/SpokeEngine.sol';
import {AccessManagerEngine} from 'src/config-engine/libraries/AccessManagerEngine.sol';
import {PositionManagerEngine} from 'src/config-engine/libraries/PositionManagerEngine.sol';
import {AddressesProviderEngine} from 'src/config-engine/libraries/AddressesProviderEngine.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {IAddressesProvider} from 'src/addresses-provider/interfaces/IAddressesProvider.sol';

/// @title AaveV4ConfigEngine
/// @author Aave Labs
/// @notice Implementation of IAaveV4ConfigEngine. Delegates to external library contracts for
/// each action category. Invoked via delegatecall from payload contracts.
/// @dev Hub and Spoke actions revert when the targeted Hub or Spoke is not registered on the
/// AddressesProvider; entries are managed via `executeAddressesProviderEntryUpdates`.
contract AaveV4ConfigEngine is IAaveV4ConfigEngine {
  /// @inheritdoc IAaveV4ConfigEngine
  IAddressesProvider public immutable ADDRESSES_PROVIDER;

  /// @dev Thrown when the addresses provider address is zero.
  error InvalidAddressesProvider();

  /// @param addressesProvider_ The AddressesProvider authorizing and registering engine actions.
  constructor(IAddressesProvider addressesProvider_) {
    require(address(addressesProvider_) != address(0), InvalidAddressesProvider());
    ADDRESSES_PROVIDER = addressesProvider_;
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeAddressesProviderEntryUpdates(
    AddressesProviderEntryUpdate[] calldata updates
  ) external {
    AddressesProviderEngine.executeAddressesProviderEntryUpdates(updates, ADDRESSES_PROVIDER);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubAssetListings(AssetListing[] calldata listings) external {
    HubEngine.executeHubAssetListings(listings, ADDRESSES_PROVIDER);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubAssetConfigUpdates(AssetConfigUpdate[] calldata updates) external {
    HubEngine.executeHubAssetConfigUpdates(updates, ADDRESSES_PROVIDER);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubSpokeToAssetsAdditions(SpokeToAssetsAddition[] calldata additions) external {
    HubEngine.executeHubSpokeToAssetsAdditions(additions, ADDRESSES_PROVIDER);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubSpokeConfigUpdates(SpokeConfigUpdate[] calldata updates) external {
    HubEngine.executeHubSpokeConfigUpdates(updates, ADDRESSES_PROVIDER);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubAssetHalts(AssetHalt[] calldata halts) external {
    HubEngine.executeHubAssetHalts(halts, ADDRESSES_PROVIDER);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubAssetDeactivations(AssetDeactivation[] calldata deactivations) external {
    HubEngine.executeHubAssetDeactivations(deactivations, ADDRESSES_PROVIDER);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubAssetCapsResets(AssetCapsReset[] calldata resets) external {
    HubEngine.executeHubAssetCapsResets(resets, ADDRESSES_PROVIDER);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubSpokeDeactivations(SpokeDeactivation[] calldata deactivations) external {
    HubEngine.executeHubSpokeDeactivations(deactivations, ADDRESSES_PROVIDER);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubSpokeCapsResets(SpokeCapsReset[] calldata resets) external {
    HubEngine.executeHubSpokeCapsResets(resets, ADDRESSES_PROVIDER);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeReserveListings(ReserveListing[] calldata listings) external {
    SpokeEngine.executeSpokeReserveListings(listings, ADDRESSES_PROVIDER);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeReserveConfigUpdates(ReserveConfigUpdate[] calldata updates) external {
    SpokeEngine.executeSpokeReserveConfigUpdates(updates, ADDRESSES_PROVIDER);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeLiquidationConfigUpdates(
    LiquidationConfigUpdate[] calldata updates
  ) external {
    SpokeEngine.executeSpokeLiquidationConfigUpdates(updates, ADDRESSES_PROVIDER);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeDynamicReserveConfigAdditions(
    DynamicReserveConfigAddition[] calldata additions
  ) external {
    SpokeEngine.executeSpokeDynamicReserveConfigAdditions(additions, ADDRESSES_PROVIDER);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeDynamicReserveConfigUpdates(
    DynamicReserveConfigUpdate[] calldata updates
  ) external {
    SpokeEngine.executeSpokeDynamicReserveConfigUpdates(updates, ADDRESSES_PROVIDER);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokePositionManagerUpdates(PositionManagerUpdate[] calldata updates) external {
    SpokeEngine.executeSpokePositionManagerUpdates(updates, ADDRESSES_PROVIDER);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executePositionManagerSpokeRegistrations(
    SpokeRegistration[] calldata registrations
  ) external {
    PositionManagerEngine.executePositionManagerSpokeRegistrations(registrations);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executePositionManagerRoleRenouncements(
    PositionManagerRoleRenouncement[] calldata renouncements
  ) external {
    PositionManagerEngine.executePositionManagerRoleRenouncements(renouncements);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeRoleMemberships(RoleMembership[] calldata memberships) external {
    AccessManagerEngine.executeRoleMemberships(memberships);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeRoleUpdates(RoleUpdate[] calldata updates) external {
    AccessManagerEngine.executeRoleUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeTargetFunctionRoleUpdates(TargetFunctionRoleUpdate[] calldata updates) external {
    AccessManagerEngine.executeTargetFunctionRoleUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeTargetAdminDelayUpdates(TargetAdminDelayUpdate[] calldata updates) external {
    AccessManagerEngine.executeTargetAdminDelayUpdates(updates);
  }
}
