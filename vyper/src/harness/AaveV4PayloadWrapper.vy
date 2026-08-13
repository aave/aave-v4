# pragma version 0.5.0a3

from config_engine import AaveV4Payload

initializes: AaveV4Payload
exports: AaveV4Payload.execute


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

hub_asset_listings: DynArray[AaveV4Payload.AssetListing, AaveV4Payload.MAX_UPDATES]
hub_asset_config_updates: DynArray[AaveV4Payload.AssetConfigUpdate, AaveV4Payload.MAX_UPDATES]
hub_spoke_to_assets_additions: DynArray[AaveV4Payload.SpokeToAssetsAddition, AaveV4Payload.MAX_UPDATES]
hub_spoke_config_updates: DynArray[AaveV4Payload.SpokeConfigUpdate, AaveV4Payload.MAX_UPDATES]
hub_asset_halts: DynArray[AaveV4Payload.AssetHalt, AaveV4Payload.MAX_UPDATES]
hub_asset_deactivations: DynArray[AaveV4Payload.AssetDeactivation, AaveV4Payload.MAX_UPDATES]
hub_asset_caps_resets: DynArray[AaveV4Payload.AssetCapsReset, AaveV4Payload.MAX_UPDATES]
hub_spoke_deactivations: DynArray[AaveV4Payload.SpokeDeactivation, AaveV4Payload.MAX_UPDATES]
hub_spoke_caps_resets: DynArray[AaveV4Payload.SpokeCapsReset, AaveV4Payload.MAX_UPDATES]
spoke_reserve_listings: DynArray[AaveV4Payload.ReserveListing, AaveV4Payload.MAX_UPDATES]
spoke_reserve_config_updates: DynArray[AaveV4Payload.ReserveConfigUpdate, AaveV4Payload.MAX_UPDATES]
spoke_liquidation_config_updates: DynArray[AaveV4Payload.LiquidationConfigUpdate, AaveV4Payload.MAX_UPDATES]
spoke_dynamic_reserve_config_additions: DynArray[AaveV4Payload.DynamicReserveConfigAddition, AaveV4Payload.MAX_UPDATES]
spoke_dynamic_reserve_config_updates: DynArray[AaveV4Payload.DynamicReserveConfigUpdate, AaveV4Payload.MAX_UPDATES]
spoke_position_manager_updates: DynArray[AaveV4Payload.PositionManagerUpdate, AaveV4Payload.MAX_UPDATES]
access_manager_role_memberships: DynArray[AaveV4Payload.RoleMembership, AaveV4Payload.MAX_UPDATES]
access_manager_role_updates: DynArray[AaveV4Payload.RoleUpdate, AaveV4Payload.MAX_UPDATES]
access_manager_target_function_role_updates: DynArray[AaveV4Payload.TargetFunctionRoleUpdate, AaveV4Payload.MAX_UPDATES]
access_manager_target_admin_delay_updates: DynArray[AaveV4Payload.TargetAdminDelayUpdate, AaveV4Payload.MAX_UPDATES]
position_manager_spoke_registrations: DynArray[AaveV4Payload.SpokeRegistration, AaveV4Payload.MAX_UPDATES]
position_manager_role_renouncements: DynArray[AaveV4Payload.PositionManagerRoleRenouncement, AaveV4Payload.MAX_UPDATES]


@deploy
def __init__(configEngine: address):
    if configEngine == empty(address):
        raw_revert(method_id("InvalidConfigEngine()"))
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
def setHubAssetListings(items: DynArray[AaveV4Payload.AssetListing, AaveV4Payload.MAX_UPDATES]):
    self.hub_asset_listings = items

@external
def setHubAssetConfigUpdates(items: DynArray[AaveV4Payload.AssetConfigUpdate, AaveV4Payload.MAX_UPDATES]):
    self.hub_asset_config_updates = items

@external
def setHubSpokeToAssetsAdditions(items: DynArray[AaveV4Payload.SpokeToAssetsAddition, AaveV4Payload.MAX_UPDATES]):
    self.hub_spoke_to_assets_additions = items

@external
def setHubSpokeConfigUpdates(items: DynArray[AaveV4Payload.SpokeConfigUpdate, AaveV4Payload.MAX_UPDATES]):
    self.hub_spoke_config_updates = items

@external
def setHubAssetHalts(items: DynArray[AaveV4Payload.AssetHalt, AaveV4Payload.MAX_UPDATES]):
    self.hub_asset_halts = items

@external
def setHubAssetDeactivations(items: DynArray[AaveV4Payload.AssetDeactivation, AaveV4Payload.MAX_UPDATES]):
    self.hub_asset_deactivations = items

@external
def setHubAssetCapsResets(items: DynArray[AaveV4Payload.AssetCapsReset, AaveV4Payload.MAX_UPDATES]):
    self.hub_asset_caps_resets = items

@external
def setHubSpokeDeactivations(items: DynArray[AaveV4Payload.SpokeDeactivation, AaveV4Payload.MAX_UPDATES]):
    self.hub_spoke_deactivations = items

@external
def setHubSpokeCapsResets(items: DynArray[AaveV4Payload.SpokeCapsReset, AaveV4Payload.MAX_UPDATES]):
    self.hub_spoke_caps_resets = items

@external
def setSpokeReserveListings(items: DynArray[AaveV4Payload.ReserveListing, AaveV4Payload.MAX_UPDATES]):
    self.spoke_reserve_listings = items

@external
def setSpokeReserveConfigUpdates(items: DynArray[AaveV4Payload.ReserveConfigUpdate, AaveV4Payload.MAX_UPDATES]):
    self.spoke_reserve_config_updates = items

@external
def setSpokeLiquidationConfigUpdates(items: DynArray[AaveV4Payload.LiquidationConfigUpdate, AaveV4Payload.MAX_UPDATES]):
    self.spoke_liquidation_config_updates = items

@external
def setSpokeDynamicReserveConfigAdditions(items: DynArray[AaveV4Payload.DynamicReserveConfigAddition, AaveV4Payload.MAX_UPDATES]):
    self.spoke_dynamic_reserve_config_additions = items

@external
def setSpokeDynamicReserveConfigUpdates(items: DynArray[AaveV4Payload.DynamicReserveConfigUpdate, AaveV4Payload.MAX_UPDATES]):
    self.spoke_dynamic_reserve_config_updates = items

@external
def setSpokePositionManagerUpdates(items: DynArray[AaveV4Payload.PositionManagerUpdate, AaveV4Payload.MAX_UPDATES]):
    self.spoke_position_manager_updates = items

@external
def setAccessManagerRoleMemberships(items: DynArray[AaveV4Payload.RoleMembership, AaveV4Payload.MAX_UPDATES]):
    self.access_manager_role_memberships = items

@external
def setAccessManagerRoleUpdates(items: DynArray[AaveV4Payload.RoleUpdate, AaveV4Payload.MAX_UPDATES]):
    self.access_manager_role_updates = items

@external
def setAccessManagerTargetFunctionRoleUpdates(items: DynArray[AaveV4Payload.TargetFunctionRoleUpdate, AaveV4Payload.MAX_UPDATES]):
    self.access_manager_target_function_role_updates = items

@external
def setAccessManagerTargetAdminDelayUpdates(items: DynArray[AaveV4Payload.TargetAdminDelayUpdate, AaveV4Payload.MAX_UPDATES]):
    self.access_manager_target_admin_delay_updates = items

@external
def setPositionManagerSpokeRegistrations(items: DynArray[AaveV4Payload.SpokeRegistration, AaveV4Payload.MAX_UPDATES]):
    self.position_manager_spoke_registrations = items

@external
def setPositionManagerRoleRenouncements(items: DynArray[AaveV4Payload.PositionManagerRoleRenouncement, AaveV4Payload.MAX_UPDATES]):
    self.position_manager_role_renouncements = items


@external
@view
def hubAssetListings() -> DynArray[AaveV4Payload.AssetListing, AaveV4Payload.MAX_UPDATES]:
    return self.hub_asset_listings

@external
@view
def hubAssetConfigUpdates() -> DynArray[AaveV4Payload.AssetConfigUpdate, AaveV4Payload.MAX_UPDATES]:
    return self.hub_asset_config_updates

@external
@view
def hubSpokeToAssetsAdditions() -> DynArray[AaveV4Payload.SpokeToAssetsAddition, AaveV4Payload.MAX_UPDATES]:
    return self.hub_spoke_to_assets_additions

@external
@view
def hubSpokeConfigUpdates() -> DynArray[AaveV4Payload.SpokeConfigUpdate, AaveV4Payload.MAX_UPDATES]:
    return self.hub_spoke_config_updates

@external
@view
def hubAssetHalts() -> DynArray[AaveV4Payload.AssetHalt, AaveV4Payload.MAX_UPDATES]:
    return self.hub_asset_halts

@external
@view
def hubAssetDeactivations() -> DynArray[AaveV4Payload.AssetDeactivation, AaveV4Payload.MAX_UPDATES]:
    return self.hub_asset_deactivations

@external
@view
def hubAssetCapsResets() -> DynArray[AaveV4Payload.AssetCapsReset, AaveV4Payload.MAX_UPDATES]:
    return self.hub_asset_caps_resets

@external
@view
def hubSpokeDeactivations() -> DynArray[AaveV4Payload.SpokeDeactivation, AaveV4Payload.MAX_UPDATES]:
    return self.hub_spoke_deactivations

@external
@view
def hubSpokeCapsResets() -> DynArray[AaveV4Payload.SpokeCapsReset, AaveV4Payload.MAX_UPDATES]:
    return self.hub_spoke_caps_resets

@external
@view
def spokeReserveListings() -> DynArray[AaveV4Payload.ReserveListing, AaveV4Payload.MAX_UPDATES]:
    return self.spoke_reserve_listings

@external
@view
def spokeReserveConfigUpdates() -> DynArray[AaveV4Payload.ReserveConfigUpdate, AaveV4Payload.MAX_UPDATES]:
    return self.spoke_reserve_config_updates

@external
@view
def spokeLiquidationConfigUpdates() -> DynArray[AaveV4Payload.LiquidationConfigUpdate, AaveV4Payload.MAX_UPDATES]:
    return self.spoke_liquidation_config_updates

@external
@view
def spokeDynamicReserveConfigAdditions() -> DynArray[AaveV4Payload.DynamicReserveConfigAddition, AaveV4Payload.MAX_UPDATES]:
    return self.spoke_dynamic_reserve_config_additions

@external
@view
def spokeDynamicReserveConfigUpdates() -> DynArray[AaveV4Payload.DynamicReserveConfigUpdate, AaveV4Payload.MAX_UPDATES]:
    return self.spoke_dynamic_reserve_config_updates

@external
@view
def spokePositionManagerUpdates() -> DynArray[AaveV4Payload.PositionManagerUpdate, AaveV4Payload.MAX_UPDATES]:
    return self.spoke_position_manager_updates

@external
@view
def accessManagerRoleMemberships() -> DynArray[AaveV4Payload.RoleMembership, AaveV4Payload.MAX_UPDATES]:
    return self.access_manager_role_memberships

@external
@view
def accessManagerRoleUpdates() -> DynArray[AaveV4Payload.RoleUpdate, AaveV4Payload.MAX_UPDATES]:
    return self.access_manager_role_updates

@external
@view
def accessManagerTargetFunctionRoleUpdates() -> DynArray[AaveV4Payload.TargetFunctionRoleUpdate, AaveV4Payload.MAX_UPDATES]:
    return self.access_manager_target_function_role_updates

@external
@view
def accessManagerTargetAdminDelayUpdates() -> DynArray[AaveV4Payload.TargetAdminDelayUpdate, AaveV4Payload.MAX_UPDATES]:
    return self.access_manager_target_admin_delay_updates

@external
@view
def positionManagerSpokeRegistrations() -> DynArray[AaveV4Payload.SpokeRegistration, AaveV4Payload.MAX_UPDATES]:
    return self.position_manager_spoke_registrations

@external
@view
def positionManagerRoleRenouncements() -> DynArray[AaveV4Payload.PositionManagerRoleRenouncement, AaveV4Payload.MAX_UPDATES]:
    return self.position_manager_role_renouncements


@view
@override(AaveV4Payload)
def _hub_asset_listings() -> DynArray[AaveV4Payload.AssetListing, AaveV4Payload.MAX_UPDATES]:
    return self.hub_asset_listings

@view
@override(AaveV4Payload)
def _hub_asset_config_updates() -> DynArray[AaveV4Payload.AssetConfigUpdate, AaveV4Payload.MAX_UPDATES]:
    return self.hub_asset_config_updates

@view
@override(AaveV4Payload)
def _hub_spoke_to_assets_additions() -> DynArray[AaveV4Payload.SpokeToAssetsAddition, AaveV4Payload.MAX_UPDATES]:
    return self.hub_spoke_to_assets_additions

@view
@override(AaveV4Payload)
def _hub_spoke_config_updates() -> DynArray[AaveV4Payload.SpokeConfigUpdate, AaveV4Payload.MAX_UPDATES]:
    return self.hub_spoke_config_updates

@view
@override(AaveV4Payload)
def _hub_asset_halts() -> DynArray[AaveV4Payload.AssetHalt, AaveV4Payload.MAX_UPDATES]:
    return self.hub_asset_halts

@view
@override(AaveV4Payload)
def _hub_asset_deactivations() -> DynArray[AaveV4Payload.AssetDeactivation, AaveV4Payload.MAX_UPDATES]:
    return self.hub_asset_deactivations

@view
@override(AaveV4Payload)
def _hub_asset_caps_resets() -> DynArray[AaveV4Payload.AssetCapsReset, AaveV4Payload.MAX_UPDATES]:
    return self.hub_asset_caps_resets

@view
@override(AaveV4Payload)
def _hub_spoke_deactivations() -> DynArray[AaveV4Payload.SpokeDeactivation, AaveV4Payload.MAX_UPDATES]:
    return self.hub_spoke_deactivations

@view
@override(AaveV4Payload)
def _hub_spoke_caps_resets() -> DynArray[AaveV4Payload.SpokeCapsReset, AaveV4Payload.MAX_UPDATES]:
    return self.hub_spoke_caps_resets

@view
@override(AaveV4Payload)
def _spoke_reserve_listings() -> DynArray[AaveV4Payload.ReserveListing, AaveV4Payload.MAX_UPDATES]:
    return self.spoke_reserve_listings

@view
@override(AaveV4Payload)
def _spoke_reserve_config_updates() -> DynArray[AaveV4Payload.ReserveConfigUpdate, AaveV4Payload.MAX_UPDATES]:
    return self.spoke_reserve_config_updates

@view
@override(AaveV4Payload)
def _spoke_liquidation_config_updates() -> DynArray[AaveV4Payload.LiquidationConfigUpdate, AaveV4Payload.MAX_UPDATES]:
    return self.spoke_liquidation_config_updates

@view
@override(AaveV4Payload)
def _spoke_dynamic_reserve_config_additions() -> DynArray[AaveV4Payload.DynamicReserveConfigAddition, AaveV4Payload.MAX_UPDATES]:
    return self.spoke_dynamic_reserve_config_additions

@view
@override(AaveV4Payload)
def _spoke_dynamic_reserve_config_updates() -> DynArray[AaveV4Payload.DynamicReserveConfigUpdate, AaveV4Payload.MAX_UPDATES]:
    return self.spoke_dynamic_reserve_config_updates

@view
@override(AaveV4Payload)
def _spoke_position_manager_updates() -> DynArray[AaveV4Payload.PositionManagerUpdate, AaveV4Payload.MAX_UPDATES]:
    return self.spoke_position_manager_updates

@view
@override(AaveV4Payload)
def _access_manager_role_memberships() -> DynArray[AaveV4Payload.RoleMembership, AaveV4Payload.MAX_UPDATES]:
    return self.access_manager_role_memberships

@view
@override(AaveV4Payload)
def _access_manager_role_updates() -> DynArray[AaveV4Payload.RoleUpdate, AaveV4Payload.MAX_UPDATES]:
    return self.access_manager_role_updates

@view
@override(AaveV4Payload)
def _access_manager_target_function_role_updates() -> DynArray[AaveV4Payload.TargetFunctionRoleUpdate, AaveV4Payload.MAX_UPDATES]:
    return self.access_manager_target_function_role_updates

@view
@override(AaveV4Payload)
def _access_manager_target_admin_delay_updates() -> DynArray[AaveV4Payload.TargetAdminDelayUpdate, AaveV4Payload.MAX_UPDATES]:
    return self.access_manager_target_admin_delay_updates

@view
@override(AaveV4Payload)
def _position_manager_spoke_registrations() -> DynArray[AaveV4Payload.SpokeRegistration, AaveV4Payload.MAX_UPDATES]:
    return self.position_manager_spoke_registrations

@view
@override(AaveV4Payload)
def _position_manager_role_renouncements() -> DynArray[AaveV4Payload.PositionManagerRoleRenouncement, AaveV4Payload.MAX_UPDATES]:
    return self.position_manager_role_renouncements
