# pragma version 0.5.0a3

# Stateless Vyper implementation of the Aave V4 configuration engine.  It is
# intentionally suitable for both direct calls and governance payload
# delegatecalls: all state changes are performed on the supplied protocol
# contracts and this contract has no storage.

MAX_UPDATES: constant(uint256) = 32
MAX_ASSETS: constant(uint256) = 32
MAX_SELECTORS: constant(uint256) = 64
MAX_STRING: constant(uint256) = 128
MAX_IR_DATA: constant(uint256) = 1024

KEEP_CURRENT: constant(uint256) = max_value(uint256) - 652
KEEP_CURRENT_ADDRESS: constant(address) = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF
KEEP_CURRENT_UINT64: constant(uint64) = max_value(uint64) - 46
KEEP_CURRENT_UINT32: constant(uint32) = max_value(uint32) - 23
KEEP_CURRENT_UINT16: constant(uint16) = max_value(uint16) - 61


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

struct LiquidationConfig:
    targetHealthFactor: uint128
    healthFactorForMaxBonus: uint64
    liquidationBonusFactor: uint16

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

struct AssetConfig:
    feeReceiver: address
    liquidityFee: uint16
    irStrategy: address
    reinvestmentController: address


interface IHub:
    def getAssetId(underlying: address) -> uint256: view
    def getAssetConfig(assetId: uint256) -> AssetConfig: view

interface IInterestRateStrategy:
    def getInterestRateData(assetId: uint256) -> InterestRateData: view

interface IHubConfigurator:
    def addAsset(hub: address, underlying: address, feeReceiver: address, liquidityFee: uint256, irStrategy: address, irData: Bytes[MAX_IR_DATA]) -> uint256: nonpayable
    def updateFeeConfig(hub: address, assetId: uint256, liquidityFee: uint256, feeReceiver: address): nonpayable
    def updateLiquidityFee(hub: address, assetId: uint256, liquidityFee: uint256): nonpayable
    def updateFeeReceiver(hub: address, assetId: uint256, feeReceiver: address): nonpayable
    def updateInterestRateStrategy(hub: address, assetId: uint256, irStrategy: address, irData: Bytes[MAX_IR_DATA]): nonpayable
    def updateInterestRateData(hub: address, assetId: uint256, irData: Bytes[MAX_IR_DATA]): nonpayable
    def updateReinvestmentController(hub: address, assetId: uint256, reinvestmentController: address): nonpayable
    def addSpoke(hub: address, spoke: address, assetId: uint256, config: HubSpokeConfig): nonpayable
    def addSpokeToAssets(hub: address, spoke: address, assetIds: DynArray[uint256, MAX_ASSETS], configs: DynArray[HubSpokeConfig, MAX_ASSETS]): nonpayable
    def updateSpokeCaps(hub: address, assetId: uint256, spoke: address, addCap: uint256, drawCap: uint256): nonpayable
    def updateSpokeAddCap(hub: address, assetId: uint256, spoke: address, addCap: uint256): nonpayable
    def updateSpokeDrawCap(hub: address, assetId: uint256, spoke: address, drawCap: uint256): nonpayable
    def updateSpokeRiskPremiumThreshold(hub: address, assetId: uint256, spoke: address, riskPremiumThreshold: uint256): nonpayable
    def updateSpokeActive(hub: address, assetId: uint256, spoke: address, active: bool): nonpayable
    def updateSpokeHalted(hub: address, assetId: uint256, spoke: address, halted: bool): nonpayable
    def haltAsset(hub: address, assetId: uint256): nonpayable
    def deactivateAsset(hub: address, assetId: uint256): nonpayable
    def resetAssetCaps(hub: address, assetId: uint256): nonpayable
    def deactivateSpoke(hub: address, spoke: address): nonpayable
    def resetSpokeCaps(hub: address, spoke: address): nonpayable

interface ISpoke:
    def getReserveId(hub: address, assetId: uint256) -> uint256: view
    def getDynamicReserveConfig(reserveId: uint256, dynamicConfigKey: uint32) -> DynamicReserveConfig: view

interface ISpokeConfigurator:
    def addReserve(spoke: address, hub: address, assetId: uint256, priceSource: address, config: ReserveConfig, dynamicConfig: DynamicReserveConfig) -> uint256: nonpayable
    def updateReservePriceSource(spoke: address, reserveId: uint256, priceSource: address): nonpayable
    def updateCollateralRisk(spoke: address, reserveId: uint256, collateralRisk: uint256): nonpayable
    def updatePaused(spoke: address, reserveId: uint256, paused: bool): nonpayable
    def updateFrozen(spoke: address, reserveId: uint256, frozen: bool): nonpayable
    def updateBorrowable(spoke: address, reserveId: uint256, borrowable: bool): nonpayable
    def updateReceiveSharesEnabled(spoke: address, reserveId: uint256, receiveSharesEnabled: bool): nonpayable
    def updateLiquidationConfig(spoke: address, config: LiquidationConfig): nonpayable
    def updateLiquidationTargetHealthFactor(spoke: address, targetHealthFactor: uint256): nonpayable
    def updateHealthFactorForMaxBonus(spoke: address, healthFactorForMaxBonus: uint256): nonpayable
    def updateLiquidationBonusFactor(spoke: address, liquidationBonusFactor: uint256): nonpayable
    def addDynamicReserveConfig(spoke: address, reserveId: uint256, dynamicConfig: DynamicReserveConfig) -> uint32: nonpayable
    def updateDynamicReserveConfig(spoke: address, reserveId: uint256, dynamicConfigKey: uint32, dynamicConfig: DynamicReserveConfig): nonpayable
    def updatePositionManager(spoke: address, positionManager: address, active: bool): nonpayable

interface IPositionManager:
    def registerSpoke(spoke: address, registered: bool): nonpayable
    def renouncePositionManagerRole(spoke: address, user: address): nonpayable

interface IAccessManager:
    def grantRole(roleId: uint64, account: address, executionDelay: uint32): nonpayable
    def revokeRole(roleId: uint64, account: address): nonpayable
    def setRoleAdmin(roleId: uint64, admin: uint64): nonpayable
    def setRoleGuardian(roleId: uint64, guardian: uint64): nonpayable
    def setGrantDelay(roleId: uint64, newDelay: uint32): nonpayable
    def labelRole(roleId: uint64, label: String[MAX_STRING]): nonpayable
    def setTargetFunctionRole(target: address, selectors: DynArray[bytes4, MAX_SELECTORS], roleId: uint64): nonpayable
    def setTargetAdminDelay(target: address, newDelay: uint32): nonpayable

interface ITokenizationSpokeDeployer:
    def deploy(hub: address, underlying: address, name: String[MAX_STRING], symbol: String[MAX_STRING], proxyAdminOwner: address) -> address: nonpayable


TOKENIZATION_SPOKE_DEPLOYER: immutable(address)


@deploy
def __init__(tokenizationSpokeDeployer: address):
    TOKENIZATION_SPOKE_DEPLOYER = tokenizationSpokeDeployer


@internal
@pure
def _to_bool(flag: uint256) -> bool:
    if flag > 1:
        raw_revert(concat(method_id("InvalidBoolValue(uint256)"), convert(flag, bytes32)))
    return flag == 1


@internal
@pure
def _u128(cast_value: uint256) -> uint128:
    if cast_value > convert(max_value(uint128), uint256):
        raw_revert(concat(method_id("SafeCastOverflowedUintDowncast(uint8,uint256)"), convert(128, bytes32), convert(cast_value, bytes32)))
    return convert(cast_value, uint128)


@internal
@pure
def _u64(cast_value: uint256) -> uint64:
    if cast_value > convert(max_value(uint64), uint256):
        raw_revert(concat(method_id("SafeCastOverflowedUintDowncast(uint8,uint256)"), convert(64, bytes32), convert(cast_value, bytes32)))
    return convert(cast_value, uint64)


@internal
@pure
def _u32(cast_value: uint256) -> uint32:
    if cast_value > convert(max_value(uint32), uint256):
        raw_revert(concat(method_id("SafeCastOverflowedUintDowncast(uint8,uint256)"), convert(32, bytes32), convert(cast_value, bytes32)))
    return convert(cast_value, uint32)


@internal
@pure
def _u16(cast_value: uint256) -> uint16:
    if cast_value > convert(max_value(uint16), uint256):
        raw_revert(concat(method_id("SafeCastOverflowedUintDowncast(uint8,uint256)"), convert(16, bytes32), convert(cast_value, bytes32)))
    return convert(cast_value, uint16)


@internal
@pure
def _u40(cast_value: uint256) -> uint40:
    if cast_value > convert(max_value(uint40), uint256):
        raw_revert(concat(method_id("SafeCastOverflowedUintDowncast(uint8,uint256)"), convert(40, bytes32), convert(cast_value, bytes32)))
    return convert(cast_value, uint40)


@internal
@view
def _asset_id(hub: address, underlying: address) -> uint256:
    return staticcall IHub(hub).getAssetId(underlying)


@internal
@view
def _reserve_id(spoke: address, hub: address, underlying: address) -> uint256:
    return staticcall ISpoke(spoke).getReserveId(hub, self._asset_id(hub, underlying))


@external
def executeHubAssetListings(listings: DynArray[AssetListing, MAX_UPDATES]):
    for listing: AssetListing in listings:
        extcall IHubConfigurator(listing.hubConfigurator).addAsset(
            listing.hub,
            listing.underlying,
            listing.feeReceiver,
            listing.liquidityFee,
            listing.irStrategy,
            abi_encode(listing.irData),
        )
        has_name: bool = len(listing.tokenization.name) > 0
        has_symbol: bool = len(listing.tokenization.symbol) > 0
        has_owner: bool = listing.tokenization.proxyAdminOwner != empty(address)
        if not has_name and not has_symbol and not has_owner and listing.tokenization.addCap == 0:
            continue
        if not has_name or not has_symbol or not has_owner:
            raw_revert(method_id("InvalidTokenizationSpokeConfig()"))
        proxy: address = extcall ITokenizationSpokeDeployer(TOKENIZATION_SPOKE_DEPLOYER).deploy(
            listing.hub,
            listing.underlying,
            listing.tokenization.name,
            listing.tokenization.symbol,
            listing.tokenization.proxyAdminOwner,
        )
        asset_id: uint256 = self._asset_id(listing.hub, listing.underlying)
        config: HubSpokeConfig = HubSpokeConfig(
            addCap=self._u40(listing.tokenization.addCap),
            drawCap=0,
            riskPremiumThreshold=0,
            active=True,
            halted=False,
        )
        extcall IHubConfigurator(listing.hubConfigurator).addSpoke(listing.hub, proxy, asset_id, config)


@external
def executeHubAssetConfigUpdates(updates: DynArray[AssetConfigUpdate, MAX_UPDATES]):
    for update: AssetConfigUpdate in updates:
        asset_id: uint256 = self._asset_id(update.hub, update.underlying)
        update_fee: bool = update.liquidityFee != KEEP_CURRENT
        update_receiver: bool = update.feeReceiver != KEEP_CURRENT_ADDRESS
        if update_fee and update_receiver:
            extcall IHubConfigurator(update.hubConfigurator).updateFeeConfig(update.hub, asset_id, update.liquidityFee, update.feeReceiver)
        elif update_fee:
            extcall IHubConfigurator(update.hubConfigurator).updateLiquidityFee(update.hub, asset_id, update.liquidityFee)
        elif update_receiver:
            extcall IHubConfigurator(update.hubConfigurator).updateFeeReceiver(update.hub, asset_id, update.feeReceiver)

        if update.irStrategy != KEEP_CURRENT_ADDRESS:
            if (
                update.irData.optimalUsageRatio == KEEP_CURRENT_UINT16
                or update.irData.baseDrawnRate == KEEP_CURRENT_UINT32
                or update.irData.rateGrowthBeforeOptimal == KEEP_CURRENT_UINT32
                or update.irData.rateGrowthAfterOptimal == KEEP_CURRENT_UINT32
            ):
                raw_revert(method_id("InvalidIrDataWithNewStrategy()"))
            extcall IHubConfigurator(update.hubConfigurator).updateInterestRateStrategy(
                update.hub, asset_id, update.irStrategy, abi_encode(update.irData)
            )
        else:
            update_optimal: bool = update.irData.optimalUsageRatio != KEEP_CURRENT_UINT16
            update_base: bool = update.irData.baseDrawnRate != KEEP_CURRENT_UINT32
            update_before: bool = update.irData.rateGrowthBeforeOptimal != KEEP_CURRENT_UINT32
            update_after: bool = update.irData.rateGrowthAfterOptimal != KEEP_CURRENT_UINT32
            if update_optimal or update_base or update_before or update_after:
                asset_config: AssetConfig = staticcall IHub(update.hub).getAssetConfig(asset_id)
                current: InterestRateData = staticcall IInterestRateStrategy(asset_config.irStrategy).getInterestRateData(asset_id)
                if update_optimal:
                    current.optimalUsageRatio = update.irData.optimalUsageRatio
                if update_base:
                    current.baseDrawnRate = update.irData.baseDrawnRate
                if update_before:
                    current.rateGrowthBeforeOptimal = update.irData.rateGrowthBeforeOptimal
                if update_after:
                    current.rateGrowthAfterOptimal = update.irData.rateGrowthAfterOptimal
                extcall IHubConfigurator(update.hubConfigurator).updateInterestRateData(update.hub, asset_id, abi_encode(current))

        if update.reinvestmentController != KEEP_CURRENT_ADDRESS:
            extcall IHubConfigurator(update.hubConfigurator).updateReinvestmentController(update.hub, asset_id, update.reinvestmentController)


@external
def executeHubSpokeToAssetsAdditions(additions: DynArray[SpokeToAssetsAddition, MAX_UPDATES]):
    for addition: SpokeToAssetsAddition in additions:
        asset_ids: DynArray[uint256, MAX_ASSETS] = []
        configs: DynArray[HubSpokeConfig, MAX_ASSETS] = []
        for item: SpokeAssetConfig in addition.assets:
            asset_ids.append(self._asset_id(addition.hub, item.underlying))
            configs.append(item.config)
        extcall IHubConfigurator(addition.hubConfigurator).addSpokeToAssets(addition.hub, addition.spoke, asset_ids, configs)


@external
def executeHubSpokeConfigUpdates(updates: DynArray[SpokeConfigUpdate, MAX_UPDATES]):
    for update: SpokeConfigUpdate in updates:
        asset_id: uint256 = self._asset_id(update.hub, update.underlying)
        update_add: bool = update.addCap != KEEP_CURRENT
        update_draw: bool = update.drawCap != KEEP_CURRENT
        if update_add and update_draw:
            extcall IHubConfigurator(update.hubConfigurator).updateSpokeCaps(update.hub, asset_id, update.spoke, update.addCap, update.drawCap)
        elif update_add:
            extcall IHubConfigurator(update.hubConfigurator).updateSpokeAddCap(update.hub, asset_id, update.spoke, update.addCap)
        elif update_draw:
            extcall IHubConfigurator(update.hubConfigurator).updateSpokeDrawCap(update.hub, asset_id, update.spoke, update.drawCap)
        if update.riskPremiumThreshold != KEEP_CURRENT:
            extcall IHubConfigurator(update.hubConfigurator).updateSpokeRiskPremiumThreshold(update.hub, asset_id, update.spoke, update.riskPremiumThreshold)
        if update.active != KEEP_CURRENT:
            extcall IHubConfigurator(update.hubConfigurator).updateSpokeActive(update.hub, asset_id, update.spoke, self._to_bool(update.active))
        if update.halted != KEEP_CURRENT:
            extcall IHubConfigurator(update.hubConfigurator).updateSpokeHalted(update.hub, asset_id, update.spoke, self._to_bool(update.halted))


@external
def executeHubAssetHalts(halts: DynArray[AssetHalt, MAX_UPDATES]):
    for item: AssetHalt in halts:
        extcall IHubConfigurator(item.hubConfigurator).haltAsset(item.hub, self._asset_id(item.hub, item.underlying))


@external
def executeHubAssetDeactivations(deactivations: DynArray[AssetDeactivation, MAX_UPDATES]):
    for item: AssetDeactivation in deactivations:
        extcall IHubConfigurator(item.hubConfigurator).deactivateAsset(item.hub, self._asset_id(item.hub, item.underlying))


@external
def executeHubAssetCapsResets(resets: DynArray[AssetCapsReset, MAX_UPDATES]):
    for item: AssetCapsReset in resets:
        extcall IHubConfigurator(item.hubConfigurator).resetAssetCaps(item.hub, self._asset_id(item.hub, item.underlying))


@external
def executeHubSpokeDeactivations(deactivations: DynArray[SpokeDeactivation, MAX_UPDATES]):
    for item: SpokeDeactivation in deactivations:
        extcall IHubConfigurator(item.hubConfigurator).deactivateSpoke(item.hub, item.spoke)


@external
def executeHubSpokeCapsResets(resets: DynArray[SpokeCapsReset, MAX_UPDATES]):
    for item: SpokeCapsReset in resets:
        extcall IHubConfigurator(item.hubConfigurator).resetSpokeCaps(item.hub, item.spoke)


@external
def executeSpokeReserveListings(listings: DynArray[ReserveListing, MAX_UPDATES]):
    for listing: ReserveListing in listings:
        extcall ISpokeConfigurator(listing.spokeConfigurator).addReserve(
            listing.spoke,
            listing.hub,
            self._asset_id(listing.hub, listing.underlying),
            listing.priceSource,
            listing.config,
            listing.dynamicConfig,
        )


@external
def executeSpokeReserveConfigUpdates(updates: DynArray[ReserveConfigUpdate, MAX_UPDATES]):
    for update: ReserveConfigUpdate in updates:
        reserve_id: uint256 = self._reserve_id(update.spoke, update.hub, update.underlying)
        if update.priceSource != KEEP_CURRENT_ADDRESS:
            extcall ISpokeConfigurator(update.spokeConfigurator).updateReservePriceSource(update.spoke, reserve_id, update.priceSource)
        if update.collateralRisk != KEEP_CURRENT:
            extcall ISpokeConfigurator(update.spokeConfigurator).updateCollateralRisk(update.spoke, reserve_id, update.collateralRisk)
        if update.paused != KEEP_CURRENT:
            extcall ISpokeConfigurator(update.spokeConfigurator).updatePaused(update.spoke, reserve_id, self._to_bool(update.paused))
        if update.frozen != KEEP_CURRENT:
            extcall ISpokeConfigurator(update.spokeConfigurator).updateFrozen(update.spoke, reserve_id, self._to_bool(update.frozen))
        if update.borrowable != KEEP_CURRENT:
            extcall ISpokeConfigurator(update.spokeConfigurator).updateBorrowable(update.spoke, reserve_id, self._to_bool(update.borrowable))
        if update.receiveSharesEnabled != KEEP_CURRENT:
            extcall ISpokeConfigurator(update.spokeConfigurator).updateReceiveSharesEnabled(update.spoke, reserve_id, self._to_bool(update.receiveSharesEnabled))


@external
def executeSpokeLiquidationConfigUpdates(updates: DynArray[LiquidationConfigUpdate, MAX_UPDATES]):
    for update: LiquidationConfigUpdate in updates:
        update_target: bool = update.targetHealthFactor != KEEP_CURRENT
        update_max_bonus: bool = update.healthFactorForMaxBonus != KEEP_CURRENT
        update_bonus_factor: bool = update.liquidationBonusFactor != KEEP_CURRENT
        if update_target and update_max_bonus and update_bonus_factor:
            config: LiquidationConfig = LiquidationConfig(
                targetHealthFactor=self._u128(update.targetHealthFactor),
                healthFactorForMaxBonus=self._u64(update.healthFactorForMaxBonus),
                liquidationBonusFactor=self._u16(update.liquidationBonusFactor),
            )
            extcall ISpokeConfigurator(update.spokeConfigurator).updateLiquidationConfig(update.spoke, config)
        else:
            if update_target:
                extcall ISpokeConfigurator(update.spokeConfigurator).updateLiquidationTargetHealthFactor(update.spoke, update.targetHealthFactor)
            if update_max_bonus:
                extcall ISpokeConfigurator(update.spokeConfigurator).updateHealthFactorForMaxBonus(update.spoke, update.healthFactorForMaxBonus)
            if update_bonus_factor:
                extcall ISpokeConfigurator(update.spokeConfigurator).updateLiquidationBonusFactor(update.spoke, update.liquidationBonusFactor)


@external
def executeSpokeDynamicReserveConfigAdditions(additions: DynArray[DynamicReserveConfigAddition, MAX_UPDATES]):
    for addition: DynamicReserveConfigAddition in additions:
        extcall ISpokeConfigurator(addition.spokeConfigurator).addDynamicReserveConfig(
            addition.spoke,
            self._reserve_id(addition.spoke, addition.hub, addition.underlying),
            addition.dynamicConfig,
        )


@external
def executeSpokeDynamicReserveConfigUpdates(updates: DynArray[DynamicReserveConfigUpdate, MAX_UPDATES]):
    for update: DynamicReserveConfigUpdate in updates:
        reserve_id: uint256 = self._reserve_id(update.spoke, update.hub, update.underlying)
        key: uint32 = self._u32(update.dynamicConfigKey)
        current: DynamicReserveConfig = staticcall ISpoke(update.spoke).getDynamicReserveConfig(reserve_id, key)
        changed: bool = False
        if update.collateralFactor != KEEP_CURRENT:
            current.collateralFactor = self._u16(update.collateralFactor)
            changed = True
        if update.maxLiquidationBonus != KEEP_CURRENT:
            current.maxLiquidationBonus = self._u32(update.maxLiquidationBonus)
            changed = True
        if update.liquidationFee != KEEP_CURRENT:
            current.liquidationFee = self._u16(update.liquidationFee)
            changed = True
        if changed:
            extcall ISpokeConfigurator(update.spokeConfigurator).updateDynamicReserveConfig(update.spoke, reserve_id, key, current)


@external
def executeSpokePositionManagerUpdates(updates: DynArray[PositionManagerUpdate, MAX_UPDATES]):
    for update: PositionManagerUpdate in updates:
        extcall ISpokeConfigurator(update.spokeConfigurator).updatePositionManager(update.spoke, update.positionManager, update.active)


@external
def executePositionManagerSpokeRegistrations(registrations: DynArray[SpokeRegistration, MAX_UPDATES]):
    for registration: SpokeRegistration in registrations:
        extcall IPositionManager(registration.positionManager).registerSpoke(registration.spoke, registration.registered)


@external
def executePositionManagerRoleRenouncements(renouncements: DynArray[PositionManagerRoleRenouncement, MAX_UPDATES]):
    for renouncement: PositionManagerRoleRenouncement in renouncements:
        extcall IPositionManager(renouncement.positionManager).renouncePositionManagerRole(renouncement.spoke, renouncement.user)


@external
def executeRoleMemberships(memberships: DynArray[RoleMembership, MAX_UPDATES]):
    for membership: RoleMembership in memberships:
        if membership.granted:
            extcall IAccessManager(membership.authority).grantRole(membership.roleId, membership.account, membership.executionDelay)
        else:
            extcall IAccessManager(membership.authority).revokeRole(membership.roleId, membership.account)


@external
def executeRoleUpdates(updates: DynArray[RoleUpdate, MAX_UPDATES]):
    for update: RoleUpdate in updates:
        if update.admin != KEEP_CURRENT_UINT64:
            extcall IAccessManager(update.authority).setRoleAdmin(update.roleId, update.admin)
        if update.guardian != KEEP_CURRENT_UINT64:
            extcall IAccessManager(update.authority).setRoleGuardian(update.roleId, update.guardian)
        if update.grantDelay != KEEP_CURRENT_UINT32:
            extcall IAccessManager(update.authority).setGrantDelay(update.roleId, update.grantDelay)
        if len(update.label) > 0:
            if update.labelUpdate:
                extcall IAccessManager(update.authority).labelRole(update.roleId, "")
            extcall IAccessManager(update.authority).labelRole(update.roleId, update.label)


@external
def executeTargetFunctionRoleUpdates(updates: DynArray[TargetFunctionRoleUpdate, MAX_UPDATES]):
    for update: TargetFunctionRoleUpdate in updates:
        extcall IAccessManager(update.authority).setTargetFunctionRole(update.target, update.selectors, update.roleId)


@external
def executeTargetAdminDelayUpdates(updates: DynArray[TargetAdminDelayUpdate, MAX_UPDATES]):
    for update: TargetAdminDelayUpdate in updates:
        extcall IAccessManager(update.authority).setTargetAdminDelay(update.target, update.newDelay)
