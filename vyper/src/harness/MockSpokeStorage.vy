# pragma version 0.5.0b1
from hub.interfaces import IHub


error SafeCastOverflowedUintDowncast:
    arg0: uint8
    arg1: uint256

struct Reserve:
    underlying: address
    hub: address
    assetId: uint16
    decimals: uint8
    collateralRisk: uint24
    flags: uint8
    dynamicConfigKey: uint32

struct PackedReserve:
    underlying: address
    configData: uint256

struct LiquidationConfig:
    targetHealthFactor: uint128
    healthFactorForMaxBonus: uint64
    liquidationBonusFactor: uint16

struct DynamicReserveConfig:
    collateralFactor: uint16
    maxLiquidationBonus: uint32
    liquidationFee: uint16

struct UserPosition:
    drawnShares: uint120
    premiumShares: uint120
    premiumOffsetRay: int200
    suppliedShares: uint120
    dynamicConfigKey: uint32

struct PackedUserPosition:
    debtShares: uint256
    premiumOffsetRay: int200
    supplyData: uint256

struct AccountDataInfo:
    collateralReserveIds: DynArray[uint256, 256]
    collateralAmounts: DynArray[uint256, 256]
    collateralDynamicConfigKeys: DynArray[uint256, 256]
    suppliedAssetsReserveIds: DynArray[uint256, 256]
    suppliedAssetsAmounts: DynArray[uint256, 256]
    debtReserveIds: DynArray[uint256, 256]
    drawnDebtAmounts: DynArray[uint256, 256]
    realizedPremiumAmountsRay: DynArray[uint256, 256]
    accruedPremiumAmounts: DynArray[uint256, 256]

RAY: constant(uint256) = 10**27
MASK_16: constant(uint256) = 2**16 - 1
MASK_120: constant(uint256) = 2**120 - 1
MASK_160: constant(uint256) = 2**160 - 1
MASK_32: constant(uint256) = 2**32 - 1

# This declaration prefix deliberately mirrors SpokeInstance's storage slots.
reserve_count: uint256
liquidation_config: LiquidationConfig
reserves: HashMap[uint256, PackedReserve]
hub_asset_to_reserve: HashMap[address, HashMap[uint256, uint256]]
dynamic_configs: HashMap[uint256, HashMap[uint32, uint256]]
position_status: HashMap[address, HashMap[uint256, uint256]]
risk_premium: HashMap[address, uint24]
user_positions: HashMap[address, HashMap[uint256, PackedUserPosition]]


@internal
@pure
def _u120(cast_value: uint256) -> uint120:
    if cast_value > convert(max_value(uint120), uint256):
        raise SafeCastOverflowedUintDowncast(120, cast_value)
    return convert(cast_value, uint120)


@internal
@pure
def _u32(cast_value: uint256) -> uint32:
    if cast_value > convert(max_value(uint32), uint256):
        raise SafeCastOverflowedUintDowncast(32, cast_value)
    return convert(cast_value, uint32)


@internal
@pure
def _unpack_reserve(packed: PackedReserve) -> Reserve:
    data: uint256 = packed.configData
    return Reserve(
        underlying=packed.underlying,
        hub=convert(data & MASK_160, address),
        assetId=convert((data >> 160) & MASK_16, uint16),
        decimals=convert((data >> 176) & 255, uint8),
        collateralRisk=convert((data >> 184) & (2**24 - 1), uint24),
        flags=convert((data >> 208) & 255, uint8),
        dynamicConfigKey=convert((data >> 216) & MASK_32, uint32),
    )


@internal
@pure
def _unpack_user_position(packed: PackedUserPosition) -> UserPosition:
    return UserPosition(
        drawnShares=convert(packed.debtShares & MASK_120, uint120),
        premiumShares=convert((packed.debtShares >> 120) & MASK_120, uint120),
        premiumOffsetRay=packed.premiumOffsetRay,
        suppliedShares=convert(packed.supplyData & MASK_120, uint120),
        dynamicConfigKey=convert((packed.supplyData >> 120) & MASK_32, uint32),
    )


@internal
@pure
def _pack_user_position(position: UserPosition) -> PackedUserPosition:
    return PackedUserPosition(
        debtShares=convert(position.drawnShares, uint256) | convert(position.premiumShares, uint256) << 120,
        premiumOffsetRay=position.premiumOffsetRay,
        supplyData=convert(position.suppliedShares, uint256) | convert(position.dynamicConfigKey, uint256) << 120,
    )


@external
def mockStorage(user: address, info: AccountDataInfo):
    for i: uint256 in range(256):
        if i >= len(info.collateralReserveIds):
            break
        reserve_id: uint256 = info.collateralReserveIds[i]
        reserve: Reserve = self._unpack_reserve(self.reserves[reserve_id])
        position: UserPosition = self._unpack_user_position(self.user_positions[user][reserve_id])
        position.suppliedShares = self._u120(staticcall IHub(reserve.hub).previewAddByAssets(convert(reserve.assetId, uint256), info.collateralAmounts[i]))
        position.dynamicConfigKey = self._u32(info.collateralDynamicConfigKeys[i])
        self.user_positions[user][reserve_id] = self._pack_user_position(position)
        bucket: uint256 = reserve_id >> 7
        self.position_status[user][bucket] |= 2 << ((reserve_id % 128) << 1)
    for i: uint256 in range(256):
        if i >= len(info.suppliedAssetsReserveIds):
            break
        reserve_id: uint256 = info.suppliedAssetsReserveIds[i]
        reserve: Reserve = self._unpack_reserve(self.reserves[reserve_id])
        position: UserPosition = self._unpack_user_position(self.user_positions[user][reserve_id])
        position.suppliedShares = self._u120(staticcall IHub(reserve.hub).previewAddByAssets(convert(reserve.assetId, uint256), info.suppliedAssetsAmounts[i]))
        self.user_positions[user][reserve_id] = self._pack_user_position(position)
    for i: uint256 in range(256):
        if i >= len(info.debtReserveIds):
            break
        reserve_id: uint256 = info.debtReserveIds[i]
        reserve: Reserve = self._unpack_reserve(self.reserves[reserve_id])
        position: UserPosition = self._unpack_user_position(self.user_positions[user][reserve_id])
        position.drawnShares = self._u120(staticcall IHub(reserve.hub).previewDrawByAssets(convert(reserve.assetId, uint256), info.drawnDebtAmounts[i]))
        desired_premium_ray: uint256 = info.realizedPremiumAmountsRay[i] + info.accruedPremiumAmounts[i] * RAY
        position.premiumShares = 0
        position.premiumOffsetRay = -convert(desired_premium_ray, int200)
        self.user_positions[user][reserve_id] = self._pack_user_position(position)
        bucket: uint256 = reserve_id >> 7
        self.position_status[user][bucket] |= 1 << ((reserve_id % 128) << 1)
