# pragma version 0.5.0b1

from config_engine import AaveV4Payload
from config_engine.interfaces import IAaveV4ConfigEngine

initializes: AaveV4Payload
exports: AaveV4Payload.execute


error InvalidConfigEngine:
    pass

CONFIG_ENGINE: public(immutable(address))

event PreExecuteCalled:
    pass

event PostExecuteCalled:
    pass

preExecuteCalled: public(bool)
postExecuteCalled: public(bool)
preExecuteOrder: public(uint256)
postExecuteOrder: public(uint256)
call_counter: uint256

hub_asset_listings: DynArray[IAaveV4ConfigEngine.AssetListing, AaveV4Payload.MAX_UPDATES]
hub_asset_config_updates: DynArray[IAaveV4ConfigEngine.AssetConfigUpdate, AaveV4Payload.MAX_UPDATES]
hub_spoke_to_assets_additions: DynArray[IAaveV4ConfigEngine.SpokeToAssetsAddition, AaveV4Payload.MAX_UPDATES]
hub_spoke_config_updates: DynArray[IAaveV4ConfigEngine.SpokeConfigUpdate, AaveV4Payload.MAX_UPDATES]
hub_asset_halts: DynArray[IAaveV4ConfigEngine.AssetHalt, AaveV4Payload.MAX_UPDATES]
hub_asset_deactivations: DynArray[IAaveV4ConfigEngine.AssetDeactivation, AaveV4Payload.MAX_UPDATES]
hub_asset_caps_resets: DynArray[IAaveV4ConfigEngine.AssetCapsReset, AaveV4Payload.MAX_UPDATES]
hub_spoke_deactivations: DynArray[IAaveV4ConfigEngine.SpokeDeactivation, AaveV4Payload.MAX_UPDATES]
hub_spoke_caps_resets: DynArray[IAaveV4ConfigEngine.SpokeCapsReset, AaveV4Payload.MAX_UPDATES]
spoke_reserve_listings: DynArray[IAaveV4ConfigEngine.ReserveListing, AaveV4Payload.MAX_UPDATES]
spoke_reserve_config_updates: DynArray[IAaveV4ConfigEngine.ReserveConfigUpdate, AaveV4Payload.MAX_UPDATES]
spoke_liquidation_config_updates: DynArray[IAaveV4ConfigEngine.LiquidationConfigUpdate, AaveV4Payload.MAX_UPDATES]
spoke_dynamic_reserve_config_additions: DynArray[IAaveV4ConfigEngine.DynamicReserveConfigAddition, AaveV4Payload.MAX_UPDATES]
spoke_dynamic_reserve_config_updates: DynArray[IAaveV4ConfigEngine.DynamicReserveConfigUpdate, AaveV4Payload.MAX_UPDATES]
spoke_position_manager_updates: DynArray[IAaveV4ConfigEngine.PositionManagerUpdate, AaveV4Payload.MAX_UPDATES]
access_manager_role_memberships: DynArray[IAaveV4ConfigEngine.RoleMembership, AaveV4Payload.MAX_UPDATES]
access_manager_role_updates: DynArray[IAaveV4ConfigEngine.RoleUpdate, AaveV4Payload.MAX_UPDATES]
access_manager_target_function_role_updates: DynArray[IAaveV4ConfigEngine.TargetFunctionRoleUpdate, AaveV4Payload.MAX_UPDATES]
access_manager_target_admin_delay_updates: DynArray[IAaveV4ConfigEngine.TargetAdminDelayUpdate, AaveV4Payload.MAX_UPDATES]
position_manager_spoke_registrations: DynArray[IAaveV4ConfigEngine.SpokeRegistration, AaveV4Payload.MAX_UPDATES]
position_manager_role_renouncements: DynArray[IAaveV4ConfigEngine.PositionManagerRoleRenouncement, AaveV4Payload.MAX_UPDATES]


@deploy
def __init__(configEngine: address):
    if configEngine == empty(address):
        raise InvalidConfigEngine()
    CONFIG_ENGINE = configEngine


@view
@override(AaveV4Payload)
def _config_engine() -> address:
    return CONFIG_ENGINE


@override(AaveV4Payload)
def _pre_execute():
    self.call_counter += 1
    self.preExecuteCalled = True
    self.preExecuteOrder = self.call_counter
    log PreExecuteCalled()


@override(AaveV4Payload)
def _post_execute():
    self.call_counter += 1
    self.postExecuteCalled = True
    self.postExecuteOrder = self.call_counter
    log PostExecuteCalled()


@external
def setHubAssetListings(items: DynArray[IAaveV4ConfigEngine.AssetListing, AaveV4Payload.MAX_UPDATES]):
    self.hub_asset_listings = items

@external
def setHubAssetConfigUpdates(items: DynArray[IAaveV4ConfigEngine.AssetConfigUpdate, AaveV4Payload.MAX_UPDATES]):
    self.hub_asset_config_updates = items

@external
def setHubSpokeToAssetsAdditions(items: DynArray[IAaveV4ConfigEngine.SpokeToAssetsAddition, AaveV4Payload.MAX_UPDATES]):
    self.hub_spoke_to_assets_additions = items

@external
def setHubSpokeConfigUpdates(items: DynArray[IAaveV4ConfigEngine.SpokeConfigUpdate, AaveV4Payload.MAX_UPDATES]):
    self.hub_spoke_config_updates = items

@external
def setHubAssetHalts(items: DynArray[IAaveV4ConfigEngine.AssetHalt, AaveV4Payload.MAX_UPDATES]):
    self.hub_asset_halts = items

@external
def setHubAssetDeactivations(items: DynArray[IAaveV4ConfigEngine.AssetDeactivation, AaveV4Payload.MAX_UPDATES]):
    self.hub_asset_deactivations = items

@external
def setHubAssetCapsResets(items: DynArray[IAaveV4ConfigEngine.AssetCapsReset, AaveV4Payload.MAX_UPDATES]):
    self.hub_asset_caps_resets = items

@external
def setHubSpokeDeactivations(items: DynArray[IAaveV4ConfigEngine.SpokeDeactivation, AaveV4Payload.MAX_UPDATES]):
    self.hub_spoke_deactivations = items

@external
def setHubSpokeCapsResets(items: DynArray[IAaveV4ConfigEngine.SpokeCapsReset, AaveV4Payload.MAX_UPDATES]):
    self.hub_spoke_caps_resets = items

@external
def setSpokeReserveListings(items: DynArray[IAaveV4ConfigEngine.ReserveListing, AaveV4Payload.MAX_UPDATES]):
    self.spoke_reserve_listings = items

@external
def setSpokeReserveConfigUpdates(items: DynArray[IAaveV4ConfigEngine.ReserveConfigUpdate, AaveV4Payload.MAX_UPDATES]):
    self.spoke_reserve_config_updates = items

@external
def setSpokeLiquidationConfigUpdates(items: DynArray[IAaveV4ConfigEngine.LiquidationConfigUpdate, AaveV4Payload.MAX_UPDATES]):
    self.spoke_liquidation_config_updates = items

@external
def setSpokeDynamicReserveConfigAdditions(items: DynArray[IAaveV4ConfigEngine.DynamicReserveConfigAddition, AaveV4Payload.MAX_UPDATES]):
    self.spoke_dynamic_reserve_config_additions = items

@external
def setSpokeDynamicReserveConfigUpdates(items: DynArray[IAaveV4ConfigEngine.DynamicReserveConfigUpdate, AaveV4Payload.MAX_UPDATES]):
    self.spoke_dynamic_reserve_config_updates = items

@external
def setSpokePositionManagerUpdates(items: DynArray[IAaveV4ConfigEngine.PositionManagerUpdate, AaveV4Payload.MAX_UPDATES]):
    self.spoke_position_manager_updates = items

@external
def setAccessManagerRoleMemberships(items: DynArray[IAaveV4ConfigEngine.RoleMembership, AaveV4Payload.MAX_UPDATES]):
    self.access_manager_role_memberships = items

@external
def setAccessManagerRoleUpdates(items: DynArray[IAaveV4ConfigEngine.RoleUpdate, AaveV4Payload.MAX_UPDATES]):
    self.access_manager_role_updates = items

@external
def setAccessManagerTargetFunctionRoleUpdates(items: DynArray[IAaveV4ConfigEngine.TargetFunctionRoleUpdate, AaveV4Payload.MAX_UPDATES]):
    self.access_manager_target_function_role_updates = items

@external
def setAccessManagerTargetAdminDelayUpdates(items: DynArray[IAaveV4ConfigEngine.TargetAdminDelayUpdate, AaveV4Payload.MAX_UPDATES]):
    self.access_manager_target_admin_delay_updates = items

@external
def setPositionManagerSpokeRegistrations(items: DynArray[IAaveV4ConfigEngine.SpokeRegistration, AaveV4Payload.MAX_UPDATES]):
    self.position_manager_spoke_registrations = items

@external
def setPositionManagerRoleRenouncements(items: DynArray[IAaveV4ConfigEngine.PositionManagerRoleRenouncement, AaveV4Payload.MAX_UPDATES]):
    self.position_manager_role_renouncements = items


@external
@view
def hubAssetListings() -> DynArray[IAaveV4ConfigEngine.AssetListing, AaveV4Payload.MAX_UPDATES]:
    return self.hub_asset_listings

@external
@view
def hubAssetConfigUpdates() -> DynArray[IAaveV4ConfigEngine.AssetConfigUpdate, INF]:
    return self._hub_asset_config_updates()

@external
@view
def hubSpokeToAssetsAdditions() -> DynArray[IAaveV4ConfigEngine.SpokeToAssetsAddition, AaveV4Payload.MAX_UPDATES]:
    return self.hub_spoke_to_assets_additions

@external
@view
def hubSpokeConfigUpdates() -> DynArray[IAaveV4ConfigEngine.SpokeConfigUpdate, INF]:
    return self._hub_spoke_config_updates()

@external
@view
def hubAssetHalts() -> DynArray[IAaveV4ConfigEngine.AssetHalt, INF]:
    return self._hub_asset_halts()

@external
@view
def hubAssetDeactivations() -> DynArray[IAaveV4ConfigEngine.AssetDeactivation, INF]:
    return self._hub_asset_deactivations()

@external
@view
def hubAssetCapsResets() -> DynArray[IAaveV4ConfigEngine.AssetCapsReset, INF]:
    return self._hub_asset_caps_resets()

@external
@view
def hubSpokeDeactivations() -> DynArray[IAaveV4ConfigEngine.SpokeDeactivation, INF]:
    return self._hub_spoke_deactivations()

@external
@view
def hubSpokeCapsResets() -> DynArray[IAaveV4ConfigEngine.SpokeCapsReset, INF]:
    return self._hub_spoke_caps_resets()

@external
@view
def spokeReserveListings() -> DynArray[IAaveV4ConfigEngine.ReserveListing, INF]:
    return self._spoke_reserve_listings()

@external
@view
def spokeReserveConfigUpdates() -> DynArray[IAaveV4ConfigEngine.ReserveConfigUpdate, INF]:
    return self._spoke_reserve_config_updates()

@external
@view
def spokeLiquidationConfigUpdates() -> DynArray[IAaveV4ConfigEngine.LiquidationConfigUpdate, INF]:
    return self._spoke_liquidation_config_updates()

@external
@view
def spokeDynamicReserveConfigAdditions() -> DynArray[IAaveV4ConfigEngine.DynamicReserveConfigAddition, INF]:
    return self._spoke_dynamic_reserve_config_additions()

@external
@view
def spokeDynamicReserveConfigUpdates() -> DynArray[IAaveV4ConfigEngine.DynamicReserveConfigUpdate, INF]:
    return self._spoke_dynamic_reserve_config_updates()

@external
@view
def spokePositionManagerUpdates() -> DynArray[IAaveV4ConfigEngine.PositionManagerUpdate, INF]:
    return self._spoke_position_manager_updates()

@external
@view
def accessManagerRoleMemberships() -> DynArray[IAaveV4ConfigEngine.RoleMembership, INF]:
    return self._access_manager_role_memberships()

@external
@view
def accessManagerRoleUpdates() -> DynArray[IAaveV4ConfigEngine.RoleUpdate, AaveV4Payload.MAX_UPDATES]:
    return self.access_manager_role_updates

@external
@view
def accessManagerTargetFunctionRoleUpdates() -> DynArray[IAaveV4ConfigEngine.TargetFunctionRoleUpdate, AaveV4Payload.MAX_UPDATES]:
    return self.access_manager_target_function_role_updates

@external
@view
def accessManagerTargetAdminDelayUpdates() -> DynArray[IAaveV4ConfigEngine.TargetAdminDelayUpdate, INF]:
    return self._access_manager_target_admin_delay_updates()

@external
@view
def positionManagerSpokeRegistrations() -> DynArray[IAaveV4ConfigEngine.SpokeRegistration, INF]:
    return self._position_manager_spoke_registrations()

@external
@view
def positionManagerRoleRenouncements() -> DynArray[IAaveV4ConfigEngine.PositionManagerRoleRenouncement, INF]:
    return self._position_manager_role_renouncements()


@view
@override(AaveV4Payload)
def _hub_asset_listings() -> DynArray[IAaveV4ConfigEngine.AssetListing, AaveV4Payload.MAX_UPDATES]:
    return self.hub_asset_listings

@view
@override(AaveV4Payload)
def _hub_asset_config_updates() -> DynArray[IAaveV4ConfigEngine.AssetConfigUpdate, INF]:
    result: DynArray[IAaveV4ConfigEngine.AssetConfigUpdate, INF] = []
    for item: IAaveV4ConfigEngine.AssetConfigUpdate in self.hub_asset_config_updates:
        result.append(item)
    return result

@view
@override(AaveV4Payload)
def _hub_spoke_to_assets_additions() -> DynArray[IAaveV4ConfigEngine.SpokeToAssetsAddition, AaveV4Payload.MAX_UPDATES]:
    return self.hub_spoke_to_assets_additions

@view
@override(AaveV4Payload)
def _hub_spoke_config_updates() -> DynArray[IAaveV4ConfigEngine.SpokeConfigUpdate, INF]:
    result: DynArray[IAaveV4ConfigEngine.SpokeConfigUpdate, INF] = []
    for item: IAaveV4ConfigEngine.SpokeConfigUpdate in self.hub_spoke_config_updates:
        result.append(item)
    return result

@view
@override(AaveV4Payload)
def _hub_asset_halts() -> DynArray[IAaveV4ConfigEngine.AssetHalt, INF]:
    result: DynArray[IAaveV4ConfigEngine.AssetHalt, INF] = []
    for item: IAaveV4ConfigEngine.AssetHalt in self.hub_asset_halts:
        result.append(item)
    return result

@view
@override(AaveV4Payload)
def _hub_asset_deactivations() -> DynArray[IAaveV4ConfigEngine.AssetDeactivation, INF]:
    result: DynArray[IAaveV4ConfigEngine.AssetDeactivation, INF] = []
    for item: IAaveV4ConfigEngine.AssetDeactivation in self.hub_asset_deactivations:
        result.append(item)
    return result

@view
@override(AaveV4Payload)
def _hub_asset_caps_resets() -> DynArray[IAaveV4ConfigEngine.AssetCapsReset, INF]:
    result: DynArray[IAaveV4ConfigEngine.AssetCapsReset, INF] = []
    for item: IAaveV4ConfigEngine.AssetCapsReset in self.hub_asset_caps_resets:
        result.append(item)
    return result

@view
@override(AaveV4Payload)
def _hub_spoke_deactivations() -> DynArray[IAaveV4ConfigEngine.SpokeDeactivation, INF]:
    result: DynArray[IAaveV4ConfigEngine.SpokeDeactivation, INF] = []
    for item: IAaveV4ConfigEngine.SpokeDeactivation in self.hub_spoke_deactivations:
        result.append(item)
    return result

@view
@override(AaveV4Payload)
def _hub_spoke_caps_resets() -> DynArray[IAaveV4ConfigEngine.SpokeCapsReset, INF]:
    result: DynArray[IAaveV4ConfigEngine.SpokeCapsReset, INF] = []
    for item: IAaveV4ConfigEngine.SpokeCapsReset in self.hub_spoke_caps_resets:
        result.append(item)
    return result

@view
@override(AaveV4Payload)
def _spoke_reserve_listings() -> DynArray[IAaveV4ConfigEngine.ReserveListing, INF]:
    result: DynArray[IAaveV4ConfigEngine.ReserveListing, INF] = []
    for item: IAaveV4ConfigEngine.ReserveListing in self.spoke_reserve_listings:
        result.append(item)
    return result

@view
@override(AaveV4Payload)
def _spoke_reserve_config_updates() -> DynArray[IAaveV4ConfigEngine.ReserveConfigUpdate, INF]:
    result: DynArray[IAaveV4ConfigEngine.ReserveConfigUpdate, INF] = []
    for item: IAaveV4ConfigEngine.ReserveConfigUpdate in self.spoke_reserve_config_updates:
        result.append(item)
    return result

@view
@override(AaveV4Payload)
def _spoke_liquidation_config_updates() -> DynArray[IAaveV4ConfigEngine.LiquidationConfigUpdate, INF]:
    result: DynArray[IAaveV4ConfigEngine.LiquidationConfigUpdate, INF] = []
    for item: IAaveV4ConfigEngine.LiquidationConfigUpdate in self.spoke_liquidation_config_updates:
        result.append(item)
    return result

@view
@override(AaveV4Payload)
def _spoke_dynamic_reserve_config_additions() -> DynArray[IAaveV4ConfigEngine.DynamicReserveConfigAddition, INF]:
    result: DynArray[IAaveV4ConfigEngine.DynamicReserveConfigAddition, INF] = []
    for item: IAaveV4ConfigEngine.DynamicReserveConfigAddition in self.spoke_dynamic_reserve_config_additions:
        result.append(item)
    return result

@view
@override(AaveV4Payload)
def _spoke_dynamic_reserve_config_updates() -> DynArray[IAaveV4ConfigEngine.DynamicReserveConfigUpdate, INF]:
    result: DynArray[IAaveV4ConfigEngine.DynamicReserveConfigUpdate, INF] = []
    for item: IAaveV4ConfigEngine.DynamicReserveConfigUpdate in self.spoke_dynamic_reserve_config_updates:
        result.append(item)
    return result

@view
@override(AaveV4Payload)
def _spoke_position_manager_updates() -> DynArray[IAaveV4ConfigEngine.PositionManagerUpdate, INF]:
    result: DynArray[IAaveV4ConfigEngine.PositionManagerUpdate, INF] = []
    for item: IAaveV4ConfigEngine.PositionManagerUpdate in self.spoke_position_manager_updates:
        result.append(item)
    return result

@view
@override(AaveV4Payload)
def _access_manager_role_memberships() -> DynArray[IAaveV4ConfigEngine.RoleMembership, INF]:
    result: DynArray[IAaveV4ConfigEngine.RoleMembership, INF] = []
    for item: IAaveV4ConfigEngine.RoleMembership in self.access_manager_role_memberships:
        result.append(item)
    return result

@view
@override(AaveV4Payload)
def _access_manager_role_updates() -> DynArray[IAaveV4ConfigEngine.RoleUpdate, AaveV4Payload.MAX_UPDATES]:
    return self.access_manager_role_updates

@view
@override(AaveV4Payload)
def _access_manager_target_function_role_updates() -> DynArray[IAaveV4ConfigEngine.TargetFunctionRoleUpdate, AaveV4Payload.MAX_UPDATES]:
    return self.access_manager_target_function_role_updates

@view
@override(AaveV4Payload)
def _access_manager_target_admin_delay_updates() -> DynArray[IAaveV4ConfigEngine.TargetAdminDelayUpdate, INF]:
    result: DynArray[IAaveV4ConfigEngine.TargetAdminDelayUpdate, INF] = []
    for item: IAaveV4ConfigEngine.TargetAdminDelayUpdate in self.access_manager_target_admin_delay_updates:
        result.append(item)
    return result

@view
@override(AaveV4Payload)
def _position_manager_spoke_registrations() -> DynArray[IAaveV4ConfigEngine.SpokeRegistration, INF]:
    result: DynArray[IAaveV4ConfigEngine.SpokeRegistration, INF] = []
    for item: IAaveV4ConfigEngine.SpokeRegistration in self.position_manager_spoke_registrations:
        result.append(item)
    return result

@view
@override(AaveV4Payload)
def _position_manager_role_renouncements() -> DynArray[IAaveV4ConfigEngine.PositionManagerRoleRenouncement, INF]:
    result: DynArray[IAaveV4ConfigEngine.PositionManagerRoleRenouncement, INF] = []
    for item: IAaveV4ConfigEngine.PositionManagerRoleRenouncement in self.position_manager_role_renouncements:
        result.append(item)
    return result
