# pragma version 0.5.0b1

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


struct InterestRateData:
    optimalUsageRatio: uint16
    baseDrawnRate: uint32
    rateGrowthBeforeOptimal: uint32
    rateGrowthAfterOptimal: uint32

struct TokenizationSpokeConfig:
    addCap: uint256
    proxyAdminOwner: address
    name: String[MAX_STRING]
    symbol: String[MAX_STRING]

struct AssetListing:
    hubConfigurator: address
    hub: address
    underlying: address
    feeReceiver: address
    liquidityFee: uint256
    irStrategy: address
    irData: InterestRateData
    tokenization: TokenizationSpokeConfig

struct AssetConfigUpdate:
    hubConfigurator: address
    hub: address
    underlying: address
    liquidityFee: uint256
    feeReceiver: address
    irStrategy: address
    irData: InterestRateData
    reinvestmentController: address

struct HubSpokeConfig:
    addCap: uint40
    drawCap: uint40
    riskPremiumThreshold: uint24
    active: bool
    halted: bool

struct SpokeAssetConfig:
    underlying: address
    config: HubSpokeConfig

struct SpokeToAssetsAddition:
    hubConfigurator: address
    hub: address
    spoke: address
    assets: DynArray[SpokeAssetConfig, MAX_ASSETS]

struct SpokeConfigUpdate:
    hubConfigurator: address
    hub: address
    underlying: address
    spoke: address
    addCap: uint256
    drawCap: uint256
    riskPremiumThreshold: uint256
    active: uint256
    halted: uint256

struct AssetHalt:
    hubConfigurator: address
    hub: address
    underlying: address

struct AssetDeactivation:
    hubConfigurator: address
    hub: address
    underlying: address

struct AssetCapsReset:
    hubConfigurator: address
    hub: address
    underlying: address

struct SpokeDeactivation:
    hubConfigurator: address
    hub: address
    spoke: address

struct SpokeCapsReset:
    hubConfigurator: address
    hub: address
    spoke: address

struct ReserveConfig:
    collateralRisk: uint24
    paused: bool
    frozen: bool
    borrowable: bool
    receiveSharesEnabled: bool

struct DynamicReserveConfig:
    collateralFactor: uint16
    maxLiquidationBonus: uint32
    liquidationFee: uint16

struct ReserveListing:
    spokeConfigurator: address
    spoke: address
    hub: address
    underlying: address
    priceSource: address
    config: ReserveConfig
    dynamicConfig: DynamicReserveConfig

struct ReserveConfigUpdate:
    spokeConfigurator: address
    spoke: address
    hub: address
    underlying: address
    priceSource: address
    collateralRisk: uint256
    paused: uint256
    frozen: uint256
    borrowable: uint256
    receiveSharesEnabled: uint256

struct LiquidationConfigUpdate:
    spokeConfigurator: address
    spoke: address
    targetHealthFactor: uint256
    healthFactorForMaxBonus: uint256
    liquidationBonusFactor: uint256

struct DynamicReserveConfigAddition:
    spokeConfigurator: address
    spoke: address
    hub: address
    underlying: address
    dynamicConfig: DynamicReserveConfig

struct DynamicReserveConfigUpdate:
    spokeConfigurator: address
    spoke: address
    hub: address
    underlying: address
    dynamicConfigKey: uint256
    collateralFactor: uint256
    maxLiquidationBonus: uint256
    liquidationFee: uint256

struct PositionManagerUpdate:
    spokeConfigurator: address
    spoke: address
    positionManager: address
    active: bool

struct SpokeRegistration:
    positionManager: address
    spoke: address
    registered: bool

struct PositionManagerRoleRenouncement:
    positionManager: address
    spoke: address
    user: address

struct RoleMembership:
    authority: address
    roleId: uint64
    account: address
    granted: bool
    executionDelay: uint32

struct RoleUpdate:
    authority: address
    roleId: uint64
    admin: uint64
    guardian: uint64
    grantDelay: uint32
    label: String[MAX_STRING]
    labelUpdate: bool

struct TargetFunctionRoleUpdate:
    authority: address
    target: address
    selectors: DynArray[bytes4, MAX_SELECTORS]
    roleId: uint64

struct TargetAdminDelayUpdate:
    authority: address
    target: address
    newDelay: uint32


@view
@abstract
def _config_engine() -> address:
    ...


@view
@abstract
def _hub_asset_listings() -> DynArray[AssetListing, MAX_UPDATES]:
    ...


@view
@abstract
def _hub_asset_config_updates() -> DynArray[AssetConfigUpdate, INF]:
    ...


@view
@abstract
def _hub_spoke_to_assets_additions() -> DynArray[SpokeToAssetsAddition, MAX_UPDATES]:
    ...


@view
@abstract
def _hub_spoke_config_updates() -> DynArray[SpokeConfigUpdate, INF]:
    ...


@view
@abstract
def _hub_asset_halts() -> DynArray[AssetHalt, INF]:
    ...


@view
@abstract
def _hub_asset_deactivations() -> DynArray[AssetDeactivation, INF]:
    ...


@view
@abstract
def _hub_asset_caps_resets() -> DynArray[AssetCapsReset, INF]:
    ...


@view
@abstract
def _hub_spoke_deactivations() -> DynArray[SpokeDeactivation, INF]:
    ...


@view
@abstract
def _hub_spoke_caps_resets() -> DynArray[SpokeCapsReset, INF]:
    ...


@view
@abstract
def _spoke_reserve_listings() -> DynArray[ReserveListing, INF]:
    ...


@view
@abstract
def _spoke_reserve_config_updates() -> DynArray[ReserveConfigUpdate, INF]:
    ...


@view
@abstract
def _spoke_liquidation_config_updates() -> DynArray[LiquidationConfigUpdate, INF]:
    ...


@view
@abstract
def _spoke_dynamic_reserve_config_additions() -> DynArray[DynamicReserveConfigAddition, INF]:
    ...


@view
@abstract
def _spoke_dynamic_reserve_config_updates() -> DynArray[DynamicReserveConfigUpdate, INF]:
    ...


@view
@abstract
def _spoke_position_manager_updates() -> DynArray[PositionManagerUpdate, INF]:
    ...


@view
@abstract
def _access_manager_role_memberships() -> DynArray[RoleMembership, INF]:
    ...


@view
@abstract
def _access_manager_role_updates() -> DynArray[RoleUpdate, MAX_UPDATES]:
    ...


@view
@abstract
def _access_manager_target_function_role_updates() -> DynArray[TargetFunctionRoleUpdate, MAX_UPDATES]:
    ...


@view
@abstract
def _access_manager_target_admin_delay_updates() -> DynArray[TargetAdminDelayUpdate, INF]:
    ...


@view
@abstract
def _position_manager_spoke_registrations() -> DynArray[SpokeRegistration, INF]:
    ...


@view
@abstract
def _position_manager_role_renouncements() -> DynArray[PositionManagerRoleRenouncement, INF]:
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
        raw_revert(result)


@external
def execute():
    self._pre_execute()

    memberships: DynArray[RoleMembership, INF] = self._access_manager_role_memberships()
    if len(memberships) > 0:
        self._delegate_call_engine(
            concat(method_id("executeRoleMemberships((address,uint64,address,bool,uint32)[])"), abi_encode(memberships))
        )

    role_updates: DynArray[RoleUpdate, MAX_UPDATES] = self._access_manager_role_updates()
    if len(role_updates) > 0:
        self._delegate_call_engine(
            concat(method_id("executeRoleUpdates((address,uint64,uint64,uint64,uint32,string,bool)[])"), abi_encode(role_updates))
        )

    target_role_updates: DynArray[TargetFunctionRoleUpdate, MAX_UPDATES] = self._access_manager_target_function_role_updates()
    if len(target_role_updates) > 0:
        self._delegate_call_engine(
            concat(method_id("executeTargetFunctionRoleUpdates((address,address,bytes4[],uint64)[])"), abi_encode(target_role_updates))
        )

    target_delay_updates: DynArray[TargetAdminDelayUpdate, INF] = self._access_manager_target_admin_delay_updates()
    if len(target_delay_updates) > 0:
        self._delegate_call_engine(
            concat(method_id("executeTargetAdminDelayUpdates((address,address,uint32)[])"), abi_encode(target_delay_updates))
        )

    listings: DynArray[AssetListing, MAX_UPDATES] = self._hub_asset_listings()
    if len(listings) > 0:
        self._delegate_call_engine(
            concat(method_id("executeHubAssetListings((address,address,address,address,uint256,address,(uint16,uint32,uint32,uint32),(uint256,address,string,string))[])"), abi_encode(listings))
        )

    asset_updates: DynArray[AssetConfigUpdate, INF] = self._hub_asset_config_updates()
    if len(asset_updates) > 0:
        self._delegate_call_engine(
            concat(method_id("executeHubAssetConfigUpdates((address,address,address,uint256,address,address,(uint16,uint32,uint32,uint32),address)[])"), abi_encode(asset_updates))
        )

    spoke_additions: DynArray[SpokeToAssetsAddition, MAX_UPDATES] = self._hub_spoke_to_assets_additions()
    if len(spoke_additions) > 0:
        self._delegate_call_engine(
            concat(method_id("executeHubSpokeToAssetsAdditions((address,address,address,(address,(uint40,uint40,uint24,bool,bool))[])[])"), abi_encode(spoke_additions))
        )

    spoke_updates: DynArray[SpokeConfigUpdate, INF] = self._hub_spoke_config_updates()
    if len(spoke_updates) > 0:
        self._delegate_call_engine(
            concat(method_id("executeHubSpokeConfigUpdates((address,address,address,address,uint256,uint256,uint256,uint256,uint256)[])"), abi_encode(spoke_updates))
        )

    halts: DynArray[AssetHalt, INF] = self._hub_asset_halts()
    if len(halts) > 0:
        self._delegate_call_engine(
            concat(method_id("executeHubAssetHalts((address,address,address)[])"), abi_encode(halts))
        )

    asset_deactivations: DynArray[AssetDeactivation, INF] = self._hub_asset_deactivations()
    if len(asset_deactivations) > 0:
        self._delegate_call_engine(
            concat(method_id("executeHubAssetDeactivations((address,address,address)[])"), abi_encode(asset_deactivations))
        )

    asset_resets: DynArray[AssetCapsReset, INF] = self._hub_asset_caps_resets()
    if len(asset_resets) > 0:
        self._delegate_call_engine(
            concat(method_id("executeHubAssetCapsResets((address,address,address)[])"), abi_encode(asset_resets))
        )

    spoke_deactivations: DynArray[SpokeDeactivation, INF] = self._hub_spoke_deactivations()
    if len(spoke_deactivations) > 0:
        self._delegate_call_engine(
            concat(method_id("executeHubSpokeDeactivations((address,address,address)[])"), abi_encode(spoke_deactivations))
        )

    spoke_resets: DynArray[SpokeCapsReset, INF] = self._hub_spoke_caps_resets()
    if len(spoke_resets) > 0:
        self._delegate_call_engine(
            concat(method_id("executeHubSpokeCapsResets((address,address,address)[])"), abi_encode(spoke_resets))
        )

    reserve_listings: DynArray[ReserveListing, INF] = self._spoke_reserve_listings()
    if len(reserve_listings) > 0:
        self._delegate_call_engine(
            concat(method_id("executeSpokeReserveListings((address,address,address,address,address,(uint24,bool,bool,bool,bool),(uint16,uint32,uint16))[])"), abi_encode(reserve_listings))
        )

    reserve_updates: DynArray[ReserveConfigUpdate, INF] = self._spoke_reserve_config_updates()
    if len(reserve_updates) > 0:
        self._delegate_call_engine(
            concat(method_id("executeSpokeReserveConfigUpdates((address,address,address,address,address,uint256,uint256,uint256,uint256,uint256)[])"), abi_encode(reserve_updates))
        )

    liquidation_updates: DynArray[LiquidationConfigUpdate, INF] = self._spoke_liquidation_config_updates()
    if len(liquidation_updates) > 0:
        self._delegate_call_engine(
            concat(method_id("executeSpokeLiquidationConfigUpdates((address,address,uint256,uint256,uint256)[])"), abi_encode(liquidation_updates))
        )

    dynamic_additions: DynArray[DynamicReserveConfigAddition, INF] = self._spoke_dynamic_reserve_config_additions()
    if len(dynamic_additions) > 0:
        self._delegate_call_engine(
            concat(method_id("executeSpokeDynamicReserveConfigAdditions((address,address,address,address,(uint16,uint32,uint16))[])"), abi_encode(dynamic_additions))
        )

    dynamic_updates: DynArray[DynamicReserveConfigUpdate, INF] = self._spoke_dynamic_reserve_config_updates()
    if len(dynamic_updates) > 0:
        self._delegate_call_engine(
            concat(method_id("executeSpokeDynamicReserveConfigUpdates((address,address,address,address,uint256,uint256,uint256,uint256)[])"), abi_encode(dynamic_updates))
        )

    manager_updates: DynArray[PositionManagerUpdate, INF] = self._spoke_position_manager_updates()
    if len(manager_updates) > 0:
        self._delegate_call_engine(
            concat(method_id("executeSpokePositionManagerUpdates((address,address,address,bool)[])"), abi_encode(manager_updates))
        )

    renouncements: DynArray[PositionManagerRoleRenouncement, INF] = self._position_manager_role_renouncements()
    if len(renouncements) > 0:
        self._delegate_call_engine(
            concat(method_id("executePositionManagerRoleRenouncements((address,address,address)[])"), abi_encode(renouncements))
        )

    registrations: DynArray[SpokeRegistration, INF] = self._position_manager_spoke_registrations()
    if len(registrations) > 0:
        self._delegate_call_engine(
            concat(method_id("executePositionManagerSpokeRegistrations((address,address,bool)[])"), abi_encode(registrations))
        )

    self._post_execute()
