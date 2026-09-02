# pragma version 0.5.0b1
from spoke.interfaces import ISpoke
from spoke.interfaces import ISpokeConfigurator
from dependencies.openzeppelin import IAuthority


implements: ISpokeConfigurator


MAX_RESERVES: constant(uint256) = 256
authority_address: address


@deploy
def __init__(authority_: address):
    if authority_ == empty(address):
        raise ISpokeConfigurator.InvalidAddress()
    self.authority_address = authority_
    log ISpokeConfigurator.AuthorityUpdated(authority=authority_)


@internal
@view
def _check_access(selector: Bytes[4]):
    allowed: bool = False
    delay: uint32 = 0
    allowed, delay = staticcall IAuthority(self.authority_address).canCall(msg.sender, self, convert(selector, bytes4))
    if not allowed:
        raise ISpokeConfigurator.AccessManagedUnauthorized(msg.sender)


@internal
@pure
def _u128(cast_value: uint256) -> uint128:
    if cast_value > convert(max_value(uint128), uint256):
        raise ISpokeConfigurator.SafeCastOverflowedUintDowncast(128, cast_value)
    return convert(cast_value, uint128)


@internal
@pure
def _u64(cast_value: uint256) -> uint64:
    if cast_value > convert(max_value(uint64), uint256):
        raise ISpokeConfigurator.SafeCastOverflowedUintDowncast(64, cast_value)
    return convert(cast_value, uint64)


@internal
@pure
def _u32(cast_value: uint256) -> uint32:
    if cast_value > convert(max_value(uint32), uint256):
        raise ISpokeConfigurator.SafeCastOverflowedUintDowncast(32, cast_value)
    return convert(cast_value, uint32)


@internal
@pure
def _u24(cast_value: uint256) -> uint24:
    if cast_value > convert(max_value(uint24), uint256):
        raise ISpokeConfigurator.SafeCastOverflowedUintDowncast(24, cast_value)
    return convert(cast_value, uint24)


@internal
@pure
def _u16(cast_value: uint256) -> uint16:
    if cast_value > convert(max_value(uint16), uint256):
        raise ISpokeConfigurator.SafeCastOverflowedUintDowncast(16, cast_value)
    return convert(cast_value, uint16)


@external
@view
def authority() -> address:
    return self.authority_address


@external
def setAuthority(newAuthority: address):
    if msg.sender != self.authority_address:
        raise ISpokeConfigurator.AccessManagedUnauthorized(msg.sender)
    self.authority_address = newAuthority
    log ISpokeConfigurator.AuthorityUpdated(authority=newAuthority)


@external
@pure
def isConsumingScheduledOp() -> bytes4:
    return empty(bytes4)


@external
def updateReservePriceSource(spoke: address, reserveId: uint256, priceSource: address):
    self._check_access(method_id("updateReservePriceSource(address,uint256,address)"))
    extcall ISpoke(spoke).updateReservePriceSource(reserveId, priceSource)


@external
def updateLiquidationTargetHealthFactor(spoke: address, targetHealthFactor: uint256):
    self._check_access(method_id("updateLiquidationTargetHealthFactor(address,uint256)"))
    config: ISpoke.LiquidationConfig = staticcall ISpoke(spoke).getLiquidationConfig()
    config.targetHealthFactor = self._u128(targetHealthFactor)
    extcall ISpoke(spoke).updateLiquidationConfig(config)


@external
def updateHealthFactorForMaxBonus(spoke: address, healthFactorForMaxBonus: uint256):
    self._check_access(method_id("updateHealthFactorForMaxBonus(address,uint256)"))
    config: ISpoke.LiquidationConfig = staticcall ISpoke(spoke).getLiquidationConfig()
    config.healthFactorForMaxBonus = self._u64(healthFactorForMaxBonus)
    extcall ISpoke(spoke).updateLiquidationConfig(config)


@external
def updateLiquidationBonusFactor(spoke: address, liquidationBonusFactor: uint256):
    self._check_access(method_id("updateLiquidationBonusFactor(address,uint256)"))
    config: ISpoke.LiquidationConfig = staticcall ISpoke(spoke).getLiquidationConfig()
    config.liquidationBonusFactor = self._u16(liquidationBonusFactor)
    extcall ISpoke(spoke).updateLiquidationConfig(config)


@external
def updateLiquidationConfig(spoke: address, liquidationConfig: ISpoke.LiquidationConfig):
    self._check_access(method_id("updateLiquidationConfig(address,(uint128,uint64,uint16))"))
    extcall ISpoke(spoke).updateLiquidationConfig(liquidationConfig)


@external
def addReserve(spoke: address, hub: address, assetId: uint256, priceSource: address, config: ISpoke.ReserveConfig, dynamicConfig: ISpoke.DynamicReserveConfig) -> uint256:
    self._check_access(method_id("addReserve(address,address,uint256,address,(uint24,bool,bool,bool,bool),(uint16,uint32,uint16))"))
    return extcall ISpoke(spoke).addReserve(hub, assetId, priceSource, config, dynamicConfig)


@internal
def _update_reserve_flag(spoke: address, reserve_id: uint256, field: uint256, enabled: bool):
    config: ISpoke.ReserveConfig = staticcall ISpoke(spoke).getReserveConfig(reserve_id)
    if field == 0:
        config.paused = enabled
    elif field == 1:
        config.frozen = enabled
    elif field == 2:
        config.borrowable = enabled
    else:
        config.receiveSharesEnabled = enabled
    extcall ISpoke(spoke).updateReserveConfig(reserve_id, config)


@external
def updatePaused(spoke: address, reserveId: uint256, paused: bool):
    self._check_access(method_id("updatePaused(address,uint256,bool)"))
    self._update_reserve_flag(spoke, reserveId, 0, paused)


@external
def updateFrozen(spoke: address, reserveId: uint256, frozen: bool):
    self._check_access(method_id("updateFrozen(address,uint256,bool)"))
    self._update_reserve_flag(spoke, reserveId, 1, frozen)


@external
def updateBorrowable(spoke: address, reserveId: uint256, borrowable: bool):
    self._check_access(method_id("updateBorrowable(address,uint256,bool)"))
    self._update_reserve_flag(spoke, reserveId, 2, borrowable)


@external
def updateReceiveSharesEnabled(spoke: address, reserveId: uint256, receiveSharesEnabled: bool):
    self._check_access(method_id("updateReceiveSharesEnabled(address,uint256,bool)"))
    self._update_reserve_flag(spoke, reserveId, 3, receiveSharesEnabled)


@external
def updateCollateralRisk(spoke: address, reserveId: uint256, collateralRisk: uint256):
    self._check_access(method_id("updateCollateralRisk(address,uint256,uint256)"))
    config: ISpoke.ReserveConfig = staticcall ISpoke(spoke).getReserveConfig(reserveId)
    config.collateralRisk = self._u24(collateralRisk)
    extcall ISpoke(spoke).updateReserveConfig(reserveId, config)


@internal
@view
def _last_key(spoke: address, reserve_id: uint256) -> uint32:
    reserve: ISpoke.Reserve = staticcall ISpoke(spoke).getReserve(reserve_id)
    return reserve.dynamicConfigKey


@internal
def _add_dynamic_field(spoke: address, reserve_id: uint256, field: uint256, field_value: uint256) -> uint32:
    config: ISpoke.DynamicReserveConfig = staticcall ISpoke(spoke).getDynamicReserveConfig(reserve_id, self._last_key(spoke, reserve_id))
    if field == 0:
        config.collateralFactor = self._u16(field_value)
    elif field == 1:
        config.maxLiquidationBonus = self._u32(field_value)
    else:
        config.liquidationFee = self._u16(field_value)
    return extcall ISpoke(spoke).addDynamicReserveConfig(reserve_id, config)


@internal
def _update_dynamic_field(spoke: address, reserve_id: uint256, key: uint32, field: uint256, field_value: uint256):
    config: ISpoke.DynamicReserveConfig = staticcall ISpoke(spoke).getDynamicReserveConfig(reserve_id, key)
    if field == 0:
        config.collateralFactor = self._u16(field_value)
    elif field == 1:
        config.maxLiquidationBonus = self._u32(field_value)
    else:
        config.liquidationFee = self._u16(field_value)
    extcall ISpoke(spoke).updateDynamicReserveConfig(reserve_id, key, config)


@external
def addCollateralFactor(spoke: address, reserveId: uint256, collateralFactor: uint16) -> uint32:
    self._check_access(method_id("addCollateralFactor(address,uint256,uint16)"))
    return self._add_dynamic_field(spoke, reserveId, 0, convert(collateralFactor, uint256))


@external
def updateCollateralFactor(spoke: address, reserveId: uint256, dynamicConfigKey: uint32, collateralFactor: uint16):
    self._check_access(method_id("updateCollateralFactor(address,uint256,uint32,uint16)"))
    self._update_dynamic_field(spoke, reserveId, dynamicConfigKey, 0, convert(collateralFactor, uint256))


@external
def addMaxLiquidationBonus(spoke: address, reserveId: uint256, maxLiquidationBonus: uint256) -> uint32:
    self._check_access(method_id("addMaxLiquidationBonus(address,uint256,uint256)"))
    return self._add_dynamic_field(spoke, reserveId, 1, maxLiquidationBonus)


@external
def updateMaxLiquidationBonus(spoke: address, reserveId: uint256, dynamicConfigKey: uint32, maxLiquidationBonus: uint256):
    self._check_access(method_id("updateMaxLiquidationBonus(address,uint256,uint32,uint256)"))
    self._update_dynamic_field(spoke, reserveId, dynamicConfigKey, 1, maxLiquidationBonus)


@external
def addLiquidationFee(spoke: address, reserveId: uint256, liquidationFee: uint256) -> uint32:
    self._check_access(method_id("addLiquidationFee(address,uint256,uint256)"))
    return self._add_dynamic_field(spoke, reserveId, 2, liquidationFee)


@external
def updateLiquidationFee(spoke: address, reserveId: uint256, dynamicConfigKey: uint32, liquidationFee: uint256):
    self._check_access(method_id("updateLiquidationFee(address,uint256,uint32,uint256)"))
    self._update_dynamic_field(spoke, reserveId, dynamicConfigKey, 2, liquidationFee)


@external
def addDynamicReserveConfig(spoke: address, reserveId: uint256, dynamicConfig: ISpoke.DynamicReserveConfig) -> uint32:
    self._check_access(method_id("addDynamicReserveConfig(address,uint256,(uint16,uint32,uint16))"))
    return extcall ISpoke(spoke).addDynamicReserveConfig(reserveId, dynamicConfig)


@external
def updateDynamicReserveConfig(spoke: address, reserveId: uint256, dynamicConfigKey: uint32, dynamicConfig: ISpoke.DynamicReserveConfig):
    self._check_access(method_id("updateDynamicReserveConfig(address,uint256,uint32,(uint16,uint32,uint16))"))
    extcall ISpoke(spoke).updateDynamicReserveConfig(reserveId, dynamicConfigKey, dynamicConfig)


@internal
def _set_all(spoke: address, field: uint256):
    count: uint256 = staticcall ISpoke(spoke).getReserveCount()
    for reserve_id: uint256 in range(MAX_RESERVES):
        if reserve_id >= count:
            break
        self._update_reserve_flag(spoke, reserve_id, field, True)


@external
def pauseAllReserves(spoke: address):
    self._check_access(method_id("pauseAllReserves(address)"))
    self._set_all(spoke, 0)


@external
def freezeAllReserves(spoke: address):
    self._check_access(method_id("freezeAllReserves(address)"))
    self._set_all(spoke, 1)


@external
def pauseReserve(spoke: address, reserveId: uint256):
    self._check_access(method_id("pauseReserve(address,uint256)"))
    self._update_reserve_flag(spoke, reserveId, 0, True)


@external
def freezeReserve(spoke: address, reserveId: uint256):
    self._check_access(method_id("freezeReserve(address,uint256)"))
    self._update_reserve_flag(spoke, reserveId, 1, True)


@external
def updatePositionManager(spoke: address, positionManager: address, active: bool):
    self._check_access(method_id("updatePositionManager(address,address,bool)"))
    extcall ISpoke(spoke).updatePositionManager(positionManager, active)
