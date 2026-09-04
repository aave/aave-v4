# pragma version 0.5.0b2
from config_engine.interfaces import IAaveV4ConfigEngine

# Reusable Vyper governance-payload base. Concrete payloads override each
# action getter and the execution hooks. Keeping the orchestration in this
# module ensures the same payload ordering and delegatecall semantics as the
# Solidity implementation.

MAX_UPDATES: constant(uint256) = 32
MAX_ASSETS: constant(uint256) = 32
MAX_SELECTORS: constant(uint256) = 64
MAX_STRING: constant(uint256) = 128
MAX_ENGINE_CALLDATA: constant(uint256) = 262144
MAX_REVERT_DATA: constant(uint256) = 4096


@view
@abstract
def _config_engine() -> address:
    ...


@view
@abstract
def _hub_asset_listings() -> DynArray[IAaveV4ConfigEngine.AssetListing, MAX_UPDATES]:
    ...


@view
@abstract
def _hub_asset_config_updates() -> DynArray[IAaveV4ConfigEngine.AssetConfigUpdate, INF]:
    ...


@view
@abstract
def _hub_spoke_to_assets_additions() -> DynArray[IAaveV4ConfigEngine.SpokeToAssetsAddition, MAX_UPDATES]:
    ...


@view
@abstract
def _hub_spoke_config_updates() -> DynArray[IAaveV4ConfigEngine.SpokeConfigUpdate, INF]:
    ...


@view
@abstract
def _hub_asset_halts() -> DynArray[IAaveV4ConfigEngine.AssetHalt, INF]:
    ...


@view
@abstract
def _hub_asset_deactivations() -> DynArray[IAaveV4ConfigEngine.AssetDeactivation, INF]:
    ...


@view
@abstract
def _hub_asset_caps_resets() -> DynArray[IAaveV4ConfigEngine.AssetCapsReset, INF]:
    ...


@view
@abstract
def _hub_spoke_deactivations() -> DynArray[IAaveV4ConfigEngine.SpokeDeactivation, INF]:
    ...


@view
@abstract
def _hub_spoke_caps_resets() -> DynArray[IAaveV4ConfigEngine.SpokeCapsReset, INF]:
    ...


@view
@abstract
def _spoke_reserve_listings() -> DynArray[IAaveV4ConfigEngine.ReserveListing, INF]:
    ...


@view
@abstract
def _spoke_reserve_config_updates() -> DynArray[IAaveV4ConfigEngine.ReserveConfigUpdate, INF]:
    ...


@view
@abstract
def _spoke_liquidation_config_updates() -> DynArray[IAaveV4ConfigEngine.LiquidationConfigUpdate, INF]:
    ...


@view
@abstract
def _spoke_dynamic_reserve_config_additions() -> DynArray[IAaveV4ConfigEngine.DynamicReserveConfigAddition, INF]:
    ...


@view
@abstract
def _spoke_dynamic_reserve_config_updates() -> DynArray[IAaveV4ConfigEngine.DynamicReserveConfigUpdate, INF]:
    ...


@view
@abstract
def _spoke_position_manager_updates() -> DynArray[IAaveV4ConfigEngine.PositionManagerUpdate, INF]:
    ...


@view
@abstract
def _access_manager_role_memberships() -> DynArray[IAaveV4ConfigEngine.RoleMembership, INF]:
    ...


@view
@abstract
def _access_manager_role_updates() -> DynArray[IAaveV4ConfigEngine.RoleUpdate, MAX_UPDATES]:
    ...


@view
@abstract
def _access_manager_target_function_role_updates() -> DynArray[IAaveV4ConfigEngine.TargetFunctionRoleUpdate, MAX_UPDATES]:
    ...


@view
@abstract
def _access_manager_target_admin_delay_updates() -> DynArray[IAaveV4ConfigEngine.TargetAdminDelayUpdate, INF]:
    ...


@view
@abstract
def _position_manager_spoke_registrations() -> DynArray[IAaveV4ConfigEngine.SpokeRegistration, INF]:
    ...


@view
@abstract
def _position_manager_role_renouncements() -> DynArray[IAaveV4ConfigEngine.PositionManagerRoleRenouncement, INF]:
    ...


@abstract
def _pre_execute():
    ...


@abstract
def _post_execute():
    ...


@internal
def _delegate_call_engine(call_data: Bytes[INF]):
    success: bool = False
    result: Bytes[MAX_REVERT_DATA] = b""
    success, result = raw_call(
        self._config_engine(),
        call_data,
        max_outsize=MAX_REVERT_DATA,
        is_delegate_call=True,
        revert_on_failure=False,
    )
    if not success:
        # Preserve arbitrary downstream revert data; it cannot be represented by a static error.
        raw_revert(result)


@external
def execute():
    self._pre_execute()

    memberships: DynArray[IAaveV4ConfigEngine.RoleMembership, INF] = self._access_manager_role_memberships()
    if len(memberships) > 0:
        self._delegate_call_engine(
            concat(method_id("executeRoleMemberships((address,uint64,address,bool,uint32)[])"), abi_encode(memberships))
        )

    role_updates: DynArray[IAaveV4ConfigEngine.RoleUpdate, MAX_UPDATES] = self._access_manager_role_updates()
    if len(role_updates) > 0:
        self._delegate_call_engine(
            concat(method_id("executeRoleUpdates((address,uint64,uint64,uint64,uint32,string,bool)[])"), abi_encode(role_updates))
        )

    target_role_updates: DynArray[IAaveV4ConfigEngine.TargetFunctionRoleUpdate, MAX_UPDATES] = self._access_manager_target_function_role_updates()
    if len(target_role_updates) > 0:
        self._delegate_call_engine(
            concat(method_id("executeTargetFunctionRoleUpdates((address,address,bytes4[],uint64)[])"), abi_encode(target_role_updates))
        )

    target_delay_updates: DynArray[IAaveV4ConfigEngine.TargetAdminDelayUpdate, INF] = self._access_manager_target_admin_delay_updates()
    if len(target_delay_updates) > 0:
        self._delegate_call_engine(
            concat(method_id("executeTargetAdminDelayUpdates((address,address,uint32)[])"), abi_encode(target_delay_updates))
        )

    listings: DynArray[IAaveV4ConfigEngine.AssetListing, MAX_UPDATES] = self._hub_asset_listings()
    if len(listings) > 0:
        self._delegate_call_engine(
            concat(method_id("executeHubAssetListings((address,address,address,address,uint256,address,(uint16,uint32,uint32,uint32),(uint256,address,string,string))[])"), abi_encode(listings))
        )

    asset_updates: DynArray[IAaveV4ConfigEngine.AssetConfigUpdate, INF] = self._hub_asset_config_updates()
    if len(asset_updates) > 0:
        self._delegate_call_engine(
            concat(method_id("executeHubAssetConfigUpdates((address,address,address,uint256,address,address,(uint16,uint32,uint32,uint32),address)[])"), abi_encode(asset_updates))
        )

    spoke_additions: DynArray[IAaveV4ConfigEngine.SpokeToAssetsAddition, MAX_UPDATES] = self._hub_spoke_to_assets_additions()
    if len(spoke_additions) > 0:
        self._delegate_call_engine(
            concat(method_id("executeHubSpokeToAssetsAdditions((address,address,address,(address,(uint40,uint40,uint24,bool,bool))[])[])"), abi_encode(spoke_additions))
        )

    spoke_updates: DynArray[IAaveV4ConfigEngine.SpokeConfigUpdate, INF] = self._hub_spoke_config_updates()
    if len(spoke_updates) > 0:
        self._delegate_call_engine(
            concat(method_id("executeHubSpokeConfigUpdates((address,address,address,address,uint256,uint256,uint256,uint256,uint256)[])"), abi_encode(spoke_updates))
        )

    halts: DynArray[IAaveV4ConfigEngine.AssetHalt, INF] = self._hub_asset_halts()
    if len(halts) > 0:
        self._delegate_call_engine(
            concat(method_id("executeHubAssetHalts((address,address,address)[])"), abi_encode(halts))
        )

    asset_deactivations: DynArray[IAaveV4ConfigEngine.AssetDeactivation, INF] = self._hub_asset_deactivations()
    if len(asset_deactivations) > 0:
        self._delegate_call_engine(
            concat(method_id("executeHubAssetDeactivations((address,address,address)[])"), abi_encode(asset_deactivations))
        )

    asset_resets: DynArray[IAaveV4ConfigEngine.AssetCapsReset, INF] = self._hub_asset_caps_resets()
    if len(asset_resets) > 0:
        self._delegate_call_engine(
            concat(method_id("executeHubAssetCapsResets((address,address,address)[])"), abi_encode(asset_resets))
        )

    spoke_deactivations: DynArray[IAaveV4ConfigEngine.SpokeDeactivation, INF] = self._hub_spoke_deactivations()
    if len(spoke_deactivations) > 0:
        self._delegate_call_engine(
            concat(method_id("executeHubSpokeDeactivations((address,address,address)[])"), abi_encode(spoke_deactivations))
        )

    spoke_resets: DynArray[IAaveV4ConfigEngine.SpokeCapsReset, INF] = self._hub_spoke_caps_resets()
    if len(spoke_resets) > 0:
        self._delegate_call_engine(
            concat(method_id("executeHubSpokeCapsResets((address,address,address)[])"), abi_encode(spoke_resets))
        )

    reserve_listings: DynArray[IAaveV4ConfigEngine.ReserveListing, INF] = self._spoke_reserve_listings()
    if len(reserve_listings) > 0:
        self._delegate_call_engine(
            concat(method_id("executeSpokeReserveListings((address,address,address,address,address,(uint24,bool,bool,bool,bool),(uint16,uint32,uint16))[])"), abi_encode(reserve_listings))
        )

    reserve_updates: DynArray[IAaveV4ConfigEngine.ReserveConfigUpdate, INF] = self._spoke_reserve_config_updates()
    if len(reserve_updates) > 0:
        self._delegate_call_engine(
            concat(method_id("executeSpokeReserveConfigUpdates((address,address,address,address,address,uint256,uint256,uint256,uint256,uint256)[])"), abi_encode(reserve_updates))
        )

    liquidation_updates: DynArray[IAaveV4ConfigEngine.LiquidationConfigUpdate, INF] = self._spoke_liquidation_config_updates()
    if len(liquidation_updates) > 0:
        self._delegate_call_engine(
            concat(method_id("executeSpokeLiquidationConfigUpdates((address,address,uint256,uint256,uint256)[])"), abi_encode(liquidation_updates))
        )

    dynamic_additions: DynArray[IAaveV4ConfigEngine.DynamicReserveConfigAddition, INF] = self._spoke_dynamic_reserve_config_additions()
    if len(dynamic_additions) > 0:
        self._delegate_call_engine(
            concat(method_id("executeSpokeDynamicReserveConfigAdditions((address,address,address,address,(uint16,uint32,uint16))[])"), abi_encode(dynamic_additions))
        )

    dynamic_updates: DynArray[IAaveV4ConfigEngine.DynamicReserveConfigUpdate, INF] = self._spoke_dynamic_reserve_config_updates()
    if len(dynamic_updates) > 0:
        self._delegate_call_engine(
            concat(method_id("executeSpokeDynamicReserveConfigUpdates((address,address,address,address,uint256,uint256,uint256,uint256)[])"), abi_encode(dynamic_updates))
        )

    manager_updates: DynArray[IAaveV4ConfigEngine.PositionManagerUpdate, INF] = self._spoke_position_manager_updates()
    if len(manager_updates) > 0:
        self._delegate_call_engine(
            concat(method_id("executeSpokePositionManagerUpdates((address,address,address,bool)[])"), abi_encode(manager_updates))
        )

    renouncements: DynArray[IAaveV4ConfigEngine.PositionManagerRoleRenouncement, INF] = self._position_manager_role_renouncements()
    if len(renouncements) > 0:
        self._delegate_call_engine(
            concat(method_id("executePositionManagerRoleRenouncements((address,address,address)[])"), abi_encode(renouncements))
        )

    registrations: DynArray[IAaveV4ConfigEngine.SpokeRegistration, INF] = self._position_manager_spoke_registrations()
    if len(registrations) > 0:
        self._delegate_call_engine(
            concat(method_id("executePositionManagerSpokeRegistrations((address,address,bool)[])"), abi_encode(registrations))
        )

    self._post_execute()
