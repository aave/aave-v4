# pragma version 0.5.0a3


struct Reserve:
    underlying: address
    hub: address
    assetId: uint16
    decimals: uint8
    collateralRisk: uint24
    flags: uint8
    dynamicConfigKey: uint32

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

interface IHub:
    def previewAddByAssets(assetId: uint256, amount: uint256) -> uint256: view
    def previewDrawByAssets(assetId: uint256, amount: uint256) -> uint256: view


RAY: constant(uint256) = 10**27

# This declaration prefix deliberately mirrors SpokeInstance's storage slots.
reserve_count: uint256
liquidation_config: LiquidationConfig
reserves: HashMap[uint256, Reserve]
hub_asset_to_reserve: HashMap[address, HashMap[uint256, uint256]]
dynamic_configs: HashMap[uint256, HashMap[uint32, DynamicReserveConfig]]
using_as_collateral: HashMap[address, HashMap[uint256, bool]]
is_borrowing: HashMap[address, HashMap[uint256, bool]]
risk_premium: HashMap[address, uint24]
user_positions: HashMap[address, HashMap[uint256, UserPosition]]


@internal
@pure
def _u120(cast_value: uint256) -> uint120:
    if cast_value > convert(max_value(uint120), uint256):
        raw_revert(concat(method_id("SafeCastOverflowedUintDowncast(uint8,uint256)"), convert(120, bytes32), convert(cast_value, bytes32)))
    return convert(cast_value, uint120)


@internal
@pure
def _u32(cast_value: uint256) -> uint32:
    if cast_value > convert(max_value(uint32), uint256):
        raw_revert(concat(method_id("SafeCastOverflowedUintDowncast(uint8,uint256)"), convert(32, bytes32), convert(cast_value, bytes32)))
    return convert(cast_value, uint32)


@external
def mockStorage(user: address, info: AccountDataInfo):
    for i: uint256 in range(256):
        if i >= len(info.collateralReserveIds):
            break
        reserve_id: uint256 = info.collateralReserveIds[i]
        reserve: Reserve = self.reserves[reserve_id]
        position: UserPosition = self.user_positions[user][reserve_id]
        position.suppliedShares = self._u120(staticcall IHub(reserve.hub).previewAddByAssets(convert(reserve.assetId, uint256), info.collateralAmounts[i]))
        position.dynamicConfigKey = self._u32(info.collateralDynamicConfigKeys[i])
        self.user_positions[user][reserve_id] = position
        self.using_as_collateral[user][reserve_id] = True
    for i: uint256 in range(256):
        if i >= len(info.suppliedAssetsReserveIds):
            break
        reserve_id: uint256 = info.suppliedAssetsReserveIds[i]
        reserve: Reserve = self.reserves[reserve_id]
        position: UserPosition = self.user_positions[user][reserve_id]
        position.suppliedShares = self._u120(staticcall IHub(reserve.hub).previewAddByAssets(convert(reserve.assetId, uint256), info.suppliedAssetsAmounts[i]))
        self.user_positions[user][reserve_id] = position
    for i: uint256 in range(256):
        if i >= len(info.debtReserveIds):
            break
        reserve_id: uint256 = info.debtReserveIds[i]
        reserve: Reserve = self.reserves[reserve_id]
        position: UserPosition = self.user_positions[user][reserve_id]
        position.drawnShares = self._u120(staticcall IHub(reserve.hub).previewDrawByAssets(convert(reserve.assetId, uint256), info.drawnDebtAmounts[i]))
        desired_premium_ray: uint256 = info.realizedPremiumAmountsRay[i] + info.accruedPremiumAmounts[i] * RAY
        position.premiumShares = 0
        position.premiumOffsetRay = -convert(desired_premium_ray, int200)
        self.user_positions[user][reserve_id] = position
        self.is_borrowing[user][reserve_id] = True
