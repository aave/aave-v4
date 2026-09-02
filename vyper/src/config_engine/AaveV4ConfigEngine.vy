# pragma version 0.5.0b1
from hub.interfaces import IHub
from hub.interfaces import IAssetInterestRateStrategy
from hub.interfaces import IHubConfigurator
from spoke.interfaces import ISpoke
from spoke.interfaces import ISpokeConfigurator
from position_manager.interfaces import IPositionManager
from dependencies.openzeppelin import IAccessManager
from config_engine.interfaces import ITokenizationSpokeDeployer
from config_engine.interfaces import IAaveV4ConfigEngine

implements: IAaveV4ConfigEngine

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


TOKENIZATION_SPOKE_DEPLOYER: immutable(address)


@deploy
def __init__(tokenizationSpokeDeployer: address):
    TOKENIZATION_SPOKE_DEPLOYER = tokenizationSpokeDeployer


@internal
@pure
def _to_bool(flag: uint256) -> bool:
    if flag > 1:
        raise IAaveV4ConfigEngine.InvalidBoolValue(flag)
    return flag == 1


@internal
@pure
def _u128(cast_value: uint256) -> uint128:
    if cast_value > convert(max_value(uint128), uint256):
        raise IAaveV4ConfigEngine.SafeCastOverflowedUintDowncast(128, cast_value)
    return convert(cast_value, uint128)


@internal
@pure
def _u64(cast_value: uint256) -> uint64:
    if cast_value > convert(max_value(uint64), uint256):
        raise IAaveV4ConfigEngine.SafeCastOverflowedUintDowncast(64, cast_value)
    return convert(cast_value, uint64)


@internal
@pure
def _u32(cast_value: uint256) -> uint32:
    if cast_value > convert(max_value(uint32), uint256):
        raise IAaveV4ConfigEngine.SafeCastOverflowedUintDowncast(32, cast_value)
    return convert(cast_value, uint32)


@internal
@pure
def _u16(cast_value: uint256) -> uint16:
    if cast_value > convert(max_value(uint16), uint256):
        raise IAaveV4ConfigEngine.SafeCastOverflowedUintDowncast(16, cast_value)
    return convert(cast_value, uint16)


@internal
@pure
def _u40(cast_value: uint256) -> uint40:
    if cast_value > convert(max_value(uint40), uint256):
        raise IAaveV4ConfigEngine.SafeCastOverflowedUintDowncast(40, cast_value)
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
def executeHubAssetListings(listings: DynArray[IAaveV4ConfigEngine.AssetListing, MAX_UPDATES]):
    for listing: IAaveV4ConfigEngine.AssetListing in listings:
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
            raise IAaveV4ConfigEngine.InvalidTokenizationSpokeConfig()
        proxy: address = extcall ITokenizationSpokeDeployer(TOKENIZATION_SPOKE_DEPLOYER).deploy(
            listing.hub,
            listing.underlying,
            listing.tokenization.name,
            listing.tokenization.symbol,
            listing.tokenization.proxyAdminOwner,
        )
        asset_id: uint256 = self._asset_id(listing.hub, listing.underlying)
        config: IHub.SpokeConfig = IHub.SpokeConfig(
            addCap=self._u40(listing.tokenization.addCap),
            drawCap=0,
            riskPremiumThreshold=0,
            active=True,
            halted=False,
        )
        extcall IHubConfigurator(listing.hubConfigurator).addSpoke(listing.hub, proxy, asset_id, config)


@external
def executeHubAssetConfigUpdates(updates: DynArray[IAaveV4ConfigEngine.AssetConfigUpdate, INF]):
    for update: IAaveV4ConfigEngine.AssetConfigUpdate in updates:
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
                raise IAaveV4ConfigEngine.InvalidIrDataWithNewStrategy()
            extcall IHubConfigurator(update.hubConfigurator).updateInterestRateStrategy(
                update.hub, asset_id, update.irStrategy, abi_encode(update.irData)
            )
        else:
            update_optimal: bool = update.irData.optimalUsageRatio != KEEP_CURRENT_UINT16
            update_base: bool = update.irData.baseDrawnRate != KEEP_CURRENT_UINT32
            update_before: bool = update.irData.rateGrowthBeforeOptimal != KEEP_CURRENT_UINT32
            update_after: bool = update.irData.rateGrowthAfterOptimal != KEEP_CURRENT_UINT32
            if update_optimal or update_base or update_before or update_after:
                asset_config: IHub.AssetConfig = staticcall IHub(update.hub).getAssetConfig(asset_id)
                current: IAssetInterestRateStrategy.InterestRateData = staticcall IAssetInterestRateStrategy(asset_config.irStrategy).getInterestRateData(asset_id)
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
def executeHubSpokeToAssetsAdditions(additions: DynArray[IAaveV4ConfigEngine.SpokeToAssetsAddition, MAX_UPDATES]):
    for addition: IAaveV4ConfigEngine.SpokeToAssetsAddition in additions:
        asset_ids: DynArray[uint256, MAX_ASSETS] = []
        configs: DynArray[IHub.SpokeConfig, MAX_ASSETS] = []
        for item: IAaveV4ConfigEngine.SpokeAssetConfig in addition.assets:
            asset_ids.append(self._asset_id(addition.hub, item.underlying))
            configs.append(item.config)
        extcall IHubConfigurator(addition.hubConfigurator).addSpokeToAssets(addition.hub, addition.spoke, asset_ids, configs)


@external
def executeHubSpokeConfigUpdates(updates: DynArray[IAaveV4ConfigEngine.SpokeConfigUpdate, INF]):
    for update: IAaveV4ConfigEngine.SpokeConfigUpdate in updates:
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
def executeHubAssetHalts(halts: DynArray[IAaveV4ConfigEngine.AssetHalt, INF]):
    for item: IAaveV4ConfigEngine.AssetHalt in halts:
        extcall IHubConfigurator(item.hubConfigurator).haltAsset(item.hub, self._asset_id(item.hub, item.underlying))


@external
def executeHubAssetDeactivations(deactivations: DynArray[IAaveV4ConfigEngine.AssetDeactivation, INF]):
    for item: IAaveV4ConfigEngine.AssetDeactivation in deactivations:
        extcall IHubConfigurator(item.hubConfigurator).deactivateAsset(item.hub, self._asset_id(item.hub, item.underlying))


@external
def executeHubAssetCapsResets(resets: DynArray[IAaveV4ConfigEngine.AssetCapsReset, INF]):
    for item: IAaveV4ConfigEngine.AssetCapsReset in resets:
        extcall IHubConfigurator(item.hubConfigurator).resetAssetCaps(item.hub, self._asset_id(item.hub, item.underlying))


@external
def executeHubSpokeDeactivations(deactivations: DynArray[IAaveV4ConfigEngine.SpokeDeactivation, INF]):
    for item: IAaveV4ConfigEngine.SpokeDeactivation in deactivations:
        extcall IHubConfigurator(item.hubConfigurator).deactivateSpoke(item.hub, item.spoke)


@external
def executeHubSpokeCapsResets(resets: DynArray[IAaveV4ConfigEngine.SpokeCapsReset, INF]):
    for item: IAaveV4ConfigEngine.SpokeCapsReset in resets:
        extcall IHubConfigurator(item.hubConfigurator).resetSpokeCaps(item.hub, item.spoke)


@external
def executeSpokeReserveListings(listings: DynArray[IAaveV4ConfigEngine.ReserveListing, INF]):
    for listing: IAaveV4ConfigEngine.ReserveListing in listings:
        extcall ISpokeConfigurator(listing.spokeConfigurator).addReserve(
            listing.spoke,
            listing.hub,
            self._asset_id(listing.hub, listing.underlying),
            listing.priceSource,
            listing.config,
            listing.dynamicConfig,
        )


@external
def executeSpokeReserveConfigUpdates(updates: DynArray[IAaveV4ConfigEngine.ReserveConfigUpdate, INF]):
    for update: IAaveV4ConfigEngine.ReserveConfigUpdate in updates:
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
def executeSpokeLiquidationConfigUpdates(updates: DynArray[IAaveV4ConfigEngine.LiquidationConfigUpdate, INF]):
    for update: IAaveV4ConfigEngine.LiquidationConfigUpdate in updates:
        update_target: bool = update.targetHealthFactor != KEEP_CURRENT
        update_max_bonus: bool = update.healthFactorForMaxBonus != KEEP_CURRENT
        update_bonus_factor: bool = update.liquidationBonusFactor != KEEP_CURRENT
        if update_target and update_max_bonus and update_bonus_factor:
            config: ISpoke.LiquidationConfig = ISpoke.LiquidationConfig(
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
def executeSpokeDynamicReserveConfigAdditions(additions: DynArray[IAaveV4ConfigEngine.DynamicReserveConfigAddition, INF]):
    for addition: IAaveV4ConfigEngine.DynamicReserveConfigAddition in additions:
        extcall ISpokeConfigurator(addition.spokeConfigurator).addDynamicReserveConfig(
            addition.spoke,
            self._reserve_id(addition.spoke, addition.hub, addition.underlying),
            addition.dynamicConfig,
        )


@external
def executeSpokeDynamicReserveConfigUpdates(updates: DynArray[IAaveV4ConfigEngine.DynamicReserveConfigUpdate, INF]):
    for update: IAaveV4ConfigEngine.DynamicReserveConfigUpdate in updates:
        reserve_id: uint256 = self._reserve_id(update.spoke, update.hub, update.underlying)
        key: uint32 = self._u32(update.dynamicConfigKey)
        current: ISpoke.DynamicReserveConfig = staticcall ISpoke(update.spoke).getDynamicReserveConfig(reserve_id, key)
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
def executeSpokePositionManagerUpdates(updates: DynArray[IAaveV4ConfigEngine.PositionManagerUpdate, INF]):
    for update: IAaveV4ConfigEngine.PositionManagerUpdate in updates:
        extcall ISpokeConfigurator(update.spokeConfigurator).updatePositionManager(update.spoke, update.positionManager, update.active)


@external
def executePositionManagerSpokeRegistrations(registrations: DynArray[IAaveV4ConfigEngine.SpokeRegistration, INF]):
    for registration: IAaveV4ConfigEngine.SpokeRegistration in registrations:
        extcall IPositionManager(registration.positionManager).registerSpoke(registration.spoke, registration.registered)


@external
def executePositionManagerRoleRenouncements(renouncements: DynArray[IAaveV4ConfigEngine.PositionManagerRoleRenouncement, INF]):
    for renouncement: IAaveV4ConfigEngine.PositionManagerRoleRenouncement in renouncements:
        extcall IPositionManager(renouncement.positionManager).renouncePositionManagerRole(renouncement.spoke, renouncement.user)


@external
def executeRoleMemberships(memberships: DynArray[IAaveV4ConfigEngine.RoleMembership, INF]):
    for membership: IAaveV4ConfigEngine.RoleMembership in memberships:
        if membership.granted:
            extcall IAccessManager(membership.authority).grantRole(membership.roleId, membership.account, membership.executionDelay)
        else:
            extcall IAccessManager(membership.authority).revokeRole(membership.roleId, membership.account)


@external
def executeRoleUpdates(updates: DynArray[IAaveV4ConfigEngine.RoleUpdate, MAX_UPDATES]):
    for update: IAaveV4ConfigEngine.RoleUpdate in updates:
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
def executeTargetFunctionRoleUpdates(updates: DynArray[IAaveV4ConfigEngine.TargetFunctionRoleUpdate, MAX_UPDATES]):
    for update: IAaveV4ConfigEngine.TargetFunctionRoleUpdate in updates:
        extcall IAccessManager(update.authority).setTargetFunctionRole(update.target, update.selectors, update.roleId)


@external
def executeTargetAdminDelayUpdates(updates: DynArray[IAaveV4ConfigEngine.TargetAdminDelayUpdate, INF]):
    for update: IAaveV4ConfigEngine.TargetAdminDelayUpdate in updates:
        extcall IAccessManager(update.authority).setTargetAdminDelay(update.target, update.newDelay)
