# pragma version 0.5.0b1

from hub.libraries import SharesMath
from libraries import Errors
from libraries.math import PercentageMath
from libraries.math import WadRayMath
from spoke.libraries import ReserveFlagsMap
from spoke.libraries import PositionStatusMap
from spoke.libraries import SpokeUtils
from spoke.libraries import UserPositionUtils

initializes: SharesMath
initializes: PositionStatusMap
initializes: ReserveFlagsMap
initializes: SpokeUtils
initializes: UserPositionUtils


error AccessManagedUnauthorized:
    arg0: address

error AssetNotListed:
    pass

error DynamicConfigKeyUninitialized:
    pass

error HealthFactorBelowThreshold:
    pass

error InvalidAccountNonce:
    arg0: address
    arg1: uint256

error InvalidAddress:
    pass

error InvalidAssetDecimals:
    pass

error InvalidAssetId:
    pass

error InvalidCollateralFactor:
    pass

error InvalidCollateralFactorAndMaxLiquidationBonus:
    pass

error InvalidCollateralRisk:
    pass

error InvalidInitialization:
    pass

error InvalidLiquidationConfig:
    pass

error InvalidLiquidationFee:
    pass

error InvalidMaxUserReservesLimit:
    pass

error InvalidOracleDecimals:
    pass

error InvalidSignature:
    pass

error MaximumDynamicConfigKeyReached:
    pass

error MaximumUserReservesExceeded:
    pass

error ReentrancyGuardReentrantCall:
    pass

error ReserveExists:
    pass

error ReserveFrozen:
    pass

error ReserveNotBorrowable:
    pass

error ReserveNotListed:
    pass

error ReservePaused:
    pass

error SafeCastOverflowedUintDowncast:
    arg0: uint8
    arg1: uint256

error Unauthorized:
    pass

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

struct PackedUserPosition:
    debtShares: uint256
    premiumOffsetRay: int200
    supplyData: uint256

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

struct UserAccountData:
    riskPremium: uint256
    avgCollateralFactor: uint256
    healthFactor: uint256
    totalCollateralValue: uint256
    totalDebtValueRay: uint256
    activeCollateralCount: uint256
    borrowCount: uint256

struct PositionManagerUpdate:
    positionManager: address
    approve: bool

struct SetUserPositionManagers:
    onBehalfOf: address
    updates: DynArray[PositionManagerUpdate, 1024]
    nonce: uint256
    deadline: uint256

struct CollateralInfo:
    risk: uint256
    collateralValue: uint256

struct ValidateLiquidationCallParams:
    user: address
    liquidator: address
    collateralReserveFlags: uint8
    debtReserveFlags: uint8
    suppliedShares: uint256
    drawnShares: uint256
    debtToCover: uint256
    collateralFactor: uint256
    isUsingAsCollateral: bool
    healthFactor: uint256
    receiveShares: bool

struct CalculateLiquidationAmountsParams:
    collateralReserveHub: address
    collateralReserveAssetId: uint256
    suppliedShares: uint256
    collateralAssetDecimals: uint256
    collateralAssetPrice: uint256
    drawnShares: uint256
    premiumDebtRay: uint256
    drawnIndex: uint256
    totalDebtValueRay: uint256
    debtAssetDecimals: uint256
    debtAssetPrice: uint256
    debtToCover: uint256
    collateralFactor: uint256
    healthFactorForMaxBonus: uint256
    liquidationBonusFactor: uint256
    maxLiquidationBonus: uint256
    targetHealthFactor: uint256
    healthFactor: uint256
    liquidationFee: uint256

struct LiquidationAmounts:
    collateralSharesToLiquidate: uint256
    collateralSharesToLiquidator: uint256
    drawnSharesToLiquidate: uint256
    premiumDebtRayToLiquidate: uint256

interface IAuthority:
    def canCall(caller: address, target: address, selector: bytes4) -> (bool, uint32): view

interface IAaveOracle:
    def decimals() -> uint8: view
    def setReserveSource(reserveId: uint256, source: address): nonpayable
    def getReservePrice(reserveId: uint256) -> uint256: view

interface IHub:
    def getAssetUnderlyingAndDecimals(assetId: uint256) -> (address, uint8): view
    def add(assetId: uint256, amount: uint256) -> uint256: nonpayable
    def remove(assetId: uint256, amount: uint256, to: address) -> uint256: nonpayable
    def draw(assetId: uint256, amount: uint256, to: address) -> uint256: nonpayable
    def restore(assetId: uint256, drawnAmount: uint256, premiumDelta: UserPositionUtils.PremiumDelta) -> uint256: nonpayable
    def refreshPremium(assetId: uint256, premiumDelta: UserPositionUtils.PremiumDelta): nonpayable
    def reportDeficit(assetId: uint256, drawnAmount: uint256, premiumDelta: UserPositionUtils.PremiumDelta) -> (uint256, uint256): nonpayable
    def transferShares(assetId: uint256, shares: uint256, toSpoke: address): nonpayable
    def payFeeShares(assetId: uint256, shares: uint256): nonpayable
    def previewRemoveByShares(assetId: uint256, shares: uint256) -> uint256: view
    def previewRemoveByAssets(assetId: uint256, amount: uint256) -> uint256: view
    def previewAddByAssets(assetId: uint256, amount: uint256) -> uint256: view
    def previewDrawByAssets(assetId: uint256, amount: uint256) -> uint256: view
    def getAssetDrawnIndex(assetId: uint256) -> uint256: view
    def getSpokeAddedAssets(assetId: uint256, spoke: address) -> uint256: view
    def getSpokeAddedShares(assetId: uint256, spoke: address) -> uint256: view
    def getSpokeOwed(assetId: uint256, spoke: address) -> (uint256, uint256): view
    def getSpokeTotalOwed(assetId: uint256, spoke: address) -> uint256: view

interface IERC1271:
    def isValidSignature(hash: bytes32, signature: Bytes[INF]) -> bytes4: view

interface ILiquidationLogic:
    def validateLiquidationCall(params: ValidateLiquidationCallParams) -> bool: view
    def calculateLiquidationAmounts(params: CalculateLiquidationAmountsParams) -> LiquidationAmounts: view


event Initialized:
    version: uint64
event AuthorityUpdated:
    authority: address
event SetSpokeImmutables:
    oracle: indexed(address)
    maxUserReservesLimit: uint16
event UpdateLiquidationConfig:
    config: LiquidationConfig
event AddReserve:
    reserveId: indexed(uint256)
    assetId: indexed(uint256)
    hub: indexed(address)
event UpdateReserveConfig:
    reserveId: indexed(uint256)
    config: ReserveConfig
event UpdateReservePriceSource:
    reserveId: indexed(uint256)
    priceSource: indexed(address)
event AddDynamicReserveConfig:
    reserveId: indexed(uint256)
    dynamicConfigKey: indexed(uint32)
    config: DynamicReserveConfig
event UpdateDynamicReserveConfig:
    reserveId: indexed(uint256)
    dynamicConfigKey: indexed(uint32)
    config: DynamicReserveConfig
event UpdatePositionManager:
    positionManager: indexed(address)
    active: bool
event Supply:
    reserveId: indexed(uint256)
    caller: indexed(address)
    user: indexed(address)
    suppliedShares: uint256
    suppliedAmount: uint256
event Withdraw:
    reserveId: indexed(uint256)
    caller: indexed(address)
    user: indexed(address)
    withdrawnShares: uint256
    withdrawnAmount: uint256
event Borrow:
    reserveId: indexed(uint256)
    caller: indexed(address)
    user: indexed(address)
    drawnShares: uint256
    drawnAmount: uint256
event Repay:
    reserveId: indexed(uint256)
    caller: indexed(address)
    user: indexed(address)
    drawnShares: uint256
    totalAmountRepaid: uint256
    premiumDelta: UserPositionUtils.PremiumDelta
event SetUsingAsCollateral:
    reserveId: indexed(uint256)
    caller: indexed(address)
    user: indexed(address)
    usingAsCollateral: bool
event UpdateUserRiskPremium:
    user: indexed(address)
    riskPremium: uint256
event RefreshAllUserDynamicConfig:
    user: indexed(address)
event RefreshSingleUserDynamicConfig:
    user: indexed(address)
    reserveId: uint256
event SetUserPositionManager:
    user: indexed(address)
    positionManager: indexed(address)
    approve: bool
event RefreshPremiumDebt:
    reserveId: indexed(uint256)
    user: indexed(address)
    premiumDelta: UserPositionUtils.PremiumDelta
event LiquidationCall:
    collateralReserveId: indexed(uint256)
    debtReserveId: indexed(uint256)
    user: indexed(address)
    liquidator: address
    receiveShares: bool
    debtAmountRestored: uint256
    drawnSharesLiquidated: uint256
    premiumDelta: UserPositionUtils.PremiumDelta
    collateralAmountRemoved: uint256
    collateralSharesLiquidated: uint256
    collateralSharesToLiquidator: uint256
event ReportDeficit:
    reserveId: indexed(uint256)
    user: indexed(address)
    drawnShares: uint256
    premiumDelta: UserPositionUtils.PremiumDelta


SPOKE_REVISION: public(constant(uint64)) = 1
SET_USER_POSITION_MANAGERS_TYPEHASH: public(constant(bytes32)) = 0xba01f7bf3d3674c63670ec4a78b0d56aac1ad6e8c84468920b9e61bfe0b9851a
POSITION_MANAGER_UPDATE_TYPEHASH: constant(bytes32) = 0x187dbd227227274b90655fb4011fc21dd749e8966fc040bd91e0b92609202565
DOMAIN_TYPEHASH: constant(bytes32) = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
NAME_HASH: constant(bytes32) = keccak256("Spoke")
VERSION_HASH: constant(bytes32) = keccak256("1")
ERC1271_MAGIC: constant(bytes4) = 0x1626ba7e
HEALTH_FACTOR_LIQUIDATION_THRESHOLD: constant(uint256) = 10**18
MAX_ALLOWED_COLLATERAL_RISK: constant(uint256) = 1000_00
MAX_ALLOWED_ASSET_ID: constant(uint256) = 2**16 - 1
MAX_RESERVES: constant(uint256) = 256
RAY: constant(uint256) = 10**27
WAD: constant(uint256) = 10**18
MASK_8: constant(uint256) = 2**8 - 1
MASK_16: constant(uint256) = 2**16 - 1
MASK_24: constant(uint256) = 2**24 - 1
MASK_32: constant(uint256) = 2**32 - 1
MASK_120: constant(uint256) = 2**120 - 1
MASK_160: constant(uint256) = 2**160 - 1

ORACLE: public(immutable(address))
MAX_USER_RESERVES_LIMIT: public(immutable(uint16))
LIQUIDATION_LOGIC: immutable(address)

reserve_count: uint256
liquidation_config: LiquidationConfig
reserves: HashMap[uint256, PackedReserve]
hub_asset_to_reserve: HashMap[address, HashMap[uint256, uint256]]
dynamic_configs: HashMap[uint256, HashMap[uint32, uint256]]
position_status: HashMap[address, HashMap[uint256, uint256]]
risk_premium: HashMap[address, uint24]
user_positions: HashMap[address, HashMap[uint256, PackedUserPosition]]
position_manager_active: HashMap[address, uint256]
position_manager_approval: HashMap[address, HashMap[address, uint256]]
nonces_by_owner: HashMap[address, HashMap[uint192, uint256]]
authority_address: address
initialized_state: uint256
# Nonzero tri-state marker: 1 is explicitly disabled, 2 is explicitly enabled.
# The canonical approval mapping remains Solidity-compatible 0/1.
position_manager_approval_state: HashMap[address, HashMap[address, uint256]]
reentrancy_lock: transient(bool)


@deploy
def __init__(liquidationLogic_: address, oracle_: address, maxUserReservesLimit_: uint16):
    if staticcall IAaveOracle(oracle_).decimals() != 8:
        raise InvalidOracleDecimals()
    if maxUserReservesLimit_ == 0:
        raise InvalidMaxUserReservesLimit()
    ORACLE = oracle_
    MAX_USER_RESERVES_LIMIT = maxUserReservesLimit_
    LIQUIDATION_LOGIC = liquidationLogic_
    self.initialized_state = convert(max_value(uint64), uint256)
    log Initialized(version=max_value(uint64))


@internal
@pure
def _panic_arithmetic():
    raise Errors.Panic(convert(17, uint256))


@internal
def _enter_nonreentrant():
    if self.reentrancy_lock:
        raise ReentrancyGuardReentrantCall()
    self.reentrancy_lock = True


@internal
def _exit_nonreentrant():
    self.reentrancy_lock = False


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
def _u24(cast_value: uint256) -> uint24:
    if cast_value > convert(max_value(uint24), uint256):
        raise SafeCastOverflowedUintDowncast(24, cast_value)
    return convert(cast_value, uint24)


@internal
@pure
def _pack_reserve(reserve: Reserve) -> PackedReserve:
    config_data: uint256 = convert(reserve.hub, uint256)
    config_data |= convert(reserve.assetId, uint256) << 160
    config_data |= convert(reserve.decimals, uint256) << 176
    config_data |= convert(reserve.collateralRisk, uint256) << 184
    config_data |= convert(reserve.flags, uint256) << 208
    config_data |= convert(reserve.dynamicConfigKey, uint256) << 216
    return PackedReserve(underlying=reserve.underlying, configData=config_data)


@internal
@pure
def _unpack_reserve(packed: PackedReserve) -> Reserve:
    data: uint256 = packed.configData
    return Reserve(
        underlying=packed.underlying,
        hub=convert(data & MASK_160, address),
        assetId=convert((data >> 160) & MASK_16, uint16),
        decimals=convert((data >> 176) & MASK_8, uint8),
        collateralRisk=convert((data >> 184) & MASK_24, uint24),
        flags=convert((data >> 208) & MASK_8, uint8),
        dynamicConfigKey=convert((data >> 216) & MASK_32, uint32),
    )


@internal
@view
def _load_reserve(reserve_id: uint256) -> Reserve:
    return self._unpack_reserve(self.reserves[reserve_id])


@internal
def _store_reserve(reserve_id: uint256, reserve: Reserve):
    self.reserves[reserve_id] = self._pack_reserve(reserve)


@internal
@pure
def _pack_dynamic_config(config: DynamicReserveConfig) -> uint256:
    return (
        convert(config.collateralFactor, uint256)
        | convert(config.maxLiquidationBonus, uint256) << 16
        | convert(config.liquidationFee, uint256) << 48
    )


@internal
@pure
def _unpack_dynamic_config(data: uint256) -> DynamicReserveConfig:
    return DynamicReserveConfig(
        collateralFactor=convert(data & MASK_16, uint16),
        maxLiquidationBonus=convert((data >> 16) & MASK_32, uint32),
        liquidationFee=convert((data >> 48) & MASK_16, uint16),
    )


@internal
@view
def _load_dynamic_config(reserve_id: uint256, key: uint32) -> DynamicReserveConfig:
    return self._unpack_dynamic_config(self.dynamic_configs[reserve_id][key])


@internal
def _store_dynamic_config(reserve_id: uint256, key: uint32, config: DynamicReserveConfig):
    self.dynamic_configs[reserve_id][key] = self._pack_dynamic_config(config)


@internal
@pure
def _pack_user_position(position: UserPositionUtils.UserPosition) -> PackedUserPosition:
    return PackedUserPosition(
        debtShares=(
            convert(position.drawnShares, uint256)
            | convert(position.premiumShares, uint256) << 120
        ),
        premiumOffsetRay=position.premiumOffsetRay,
        supplyData=(
            convert(position.suppliedShares, uint256)
            | convert(position.dynamicConfigKey, uint256) << 120
        ),
    )


@internal
@pure
def _unpack_user_position(packed: PackedUserPosition) -> UserPositionUtils.UserPosition:
    return UserPositionUtils.UserPosition(
        drawnShares=convert(packed.debtShares & MASK_120, uint120),
        premiumShares=convert((packed.debtShares >> 120) & MASK_120, uint120),
        premiumOffsetRay=packed.premiumOffsetRay,
        suppliedShares=convert(packed.supplyData & MASK_120, uint120),
        dynamicConfigKey=convert((packed.supplyData >> 120) & MASK_32, uint32),
    )


@internal
@view
def _load_user_position(user: address, reserve_id: uint256) -> UserPositionUtils.UserPosition:
    return self._unpack_user_position(self.user_positions[user][reserve_id])


@internal
def _store_user_position(user: address, reserve_id: uint256, position: UserPositionUtils.UserPosition):
    self.user_positions[user][reserve_id] = self._pack_user_position(position)


@internal
@view
def _check_access(selector: Bytes[4]):
    allowed: bool = False
    delay: uint32 = 0
    allowed, delay = staticcall IAuthority(self.authority_address).canCall(msg.sender, self, convert(selector, bytes4))
    if not allowed:
        raise AccessManagedUnauthorized(msg.sender)


@internal
@view
def _is_position_manager(user: address, manager: address) -> bool:
    approval_state: uint256 = self.position_manager_approval_state[manager][user]
    approved: bool = self.position_manager_approval[manager][user] != 0
    if approval_state == 1:
        approved = False
    elif approval_state == 2:
        approved = True
    return user == manager or (self.position_manager_active[manager] != 0 and approved)


@internal
@view
def _only_position_manager(user: address):
    if not self._is_position_manager(user, msg.sender):
        raise Unauthorized()


@internal
@view
def _require_reserve(reserve_id: uint256) -> Reserve:
    if reserve_id >= self.reserve_count:
        raise ReserveNotListed()
    return self._load_reserve(reserve_id)


@internal
def _safe_transfer_from(token: address, owner: address, receiver: address, amount: uint256):
    result: Bytes[32] = raw_call(
        token,
        concat(method_id("transferFrom(address,address,uint256)"), convert(owner, bytes32), convert(receiver, bytes32), convert(amount, bytes32)),
        max_outsize=32,
    )
    assert len(result) == 0 or abi_decode(result, bool)


@internal
@view
def _domain_separator() -> bytes32:
    return keccak256(abi_encode(DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, chain.id, self))


@internal
@pure
def _pack_nonce(key: uint192, nonce: uint64) -> uint256:
    return unsafe_mul(convert(key, uint256), 2**64) | convert(nonce, uint256)


@internal
def _use_checked_nonce(owner: address, key_nonce: uint256):
    key: uint192 = convert(key_nonce // 2**64, uint192)
    nonce: uint64 = convert(self.nonces_by_owner[owner][key] & (2**64 - 1), uint64)
    current: uint256 = self._pack_nonce(key, nonce)
    if key_nonce != current:
        raise InvalidAccountNonce(owner, current)
    self.nonces_by_owner[owner][key] = convert(unsafe_add(nonce, 1), uint256)


@internal
@view
def _valid_signature(signer: address, digest: bytes32, signature: Bytes[INF]) -> bool:
    if len(signature) == 65:
        r: bytes32 = convert(slice(signature, 0, 32), bytes32)
        s: bytes32 = convert(slice(signature, 32, 32), bytes32)
        v: uint256 = convert(slice(signature, 64, 1), uint256)
        if ecrecover(digest, v, r, s) == signer and signer != empty(address):
            return True
    success: bool = False
    response: Bytes[32] = b""
    success, response = raw_call(
        signer,
        concat(method_id("isValidSignature(bytes32,bytes)"), abi_encode(digest, signature)),
        max_outsize=32,
        is_static_call=True,
        revert_on_failure=False,
    )
    return success and len(response) >= 4 and convert(slice(response, 0, 4), bytes4) == ERC1271_MAGIC


@external
def initialize(authority: address):
    initialized: uint64 = convert(self.initialized_state & (2**64 - 1), uint64)
    if initialized >= SPOKE_REVISION:
        raise InvalidInitialization()
    log SetSpokeImmutables(oracle=ORACLE, maxUserReservesLimit=MAX_USER_RESERVES_LIMIT)
    if authority == empty(address):
        raise InvalidAddress()
    self.initialized_state = convert(SPOKE_REVISION, uint256)
    self.authority_address = authority
    log AuthorityUpdated(authority=authority)
    if self.liquidation_config.targetHealthFactor == 0:
        self.liquidation_config.targetHealthFactor = convert(HEALTH_FACTOR_LIQUIDATION_THRESHOLD, uint128)
        log UpdateLiquidationConfig(config=self.liquidation_config)
    log Initialized(version=SPOKE_REVISION)


@external
@view
def authority() -> address:
    return self.authority_address


@external
def setAuthority(newAuthority: address):
    if msg.sender != self.authority_address:
        raise AccessManagedUnauthorized(msg.sender)
    self.authority_address = newAuthority
    log AuthorityUpdated(authority=newAuthority)


@external
@pure
def isConsumingScheduledOp() -> bytes4:
    return empty(bytes4)


@external
@view
def DOMAIN_SEPARATOR() -> bytes32:
    return self._domain_separator()


@external
@view
def eip712Domain() -> (bytes1, String[16], String[8], uint256, address, bytes32, DynArray[uint256, INF]):
    extensions: DynArray[uint256, INF] = []
    return 0x0f, "Spoke", "1", chain.id, self, empty(bytes32), extensions


@external
def useNonce(key: uint192) -> uint256:
    nonce: uint64 = convert(self.nonces_by_owner[msg.sender][key] & (2**64 - 1), uint64)
    self.nonces_by_owner[msg.sender][key] = convert(unsafe_add(nonce, 1), uint256)
    return self._pack_nonce(key, nonce)


@external
@view
def nonces(owner: address, key: uint192) -> uint256:
    nonce: uint64 = convert(self.nonces_by_owner[owner][key] & (2**64 - 1), uint64)
    return self._pack_nonce(key, nonce)


@external
def updateLiquidationConfig(config: LiquidationConfig):
    self._check_access(method_id("updateLiquidationConfig((uint128,uint64,uint16))"))
    if (convert(config.targetHealthFactor, uint256) < HEALTH_FACTOR_LIQUIDATION_THRESHOLD
        or convert(config.liquidationBonusFactor, uint256) > 10**4
        or convert(config.healthFactorForMaxBonus, uint256) >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD):
        raise InvalidLiquidationConfig()
    self.liquidation_config = config
    log UpdateLiquidationConfig(config=config)


@internal
@pure
def _validate_dynamic(config: DynamicReserveConfig):
    cf: uint256 = convert(config.collateralFactor, uint256)
    bonus: uint256 = convert(config.maxLiquidationBonus, uint256)
    if cf >= 10**4 or bonus < 10**4 or PercentageMath.percent_mul_up(bonus, cf) >= 10**4:
        raise InvalidCollateralFactorAndMaxLiquidationBonus()
    if convert(config.liquidationFee, uint256) > 10**4:
        raise InvalidLiquidationFee()


@external
def addReserve(hub: address, assetId: uint256, priceSource: address, config: ReserveConfig, dynamicConfig: DynamicReserveConfig) -> uint256:
    self._check_access(method_id("addReserve(address,uint256,address,(uint24,bool,bool,bool,bool),(uint16,uint32,uint16))"))
    if hub == empty(address):
        raise InvalidAddress()
    if assetId > MAX_ALLOWED_ASSET_ID:
        raise InvalidAssetId()
    candidate: uint256 = self.hub_asset_to_reserve[hub][assetId]
    existing: Reserve = self._load_reserve(candidate)
    if existing.hub == hub and convert(existing.assetId, uint256) == assetId:
        raise ReserveExists()
    if convert(config.collateralRisk, uint256) > MAX_ALLOWED_COLLATERAL_RISK:
        raise InvalidCollateralRisk()
    self._validate_dynamic(dynamicConfig)
    if priceSource == empty(address):
        raise InvalidAddress()
    reserve_id: uint256 = self.reserve_count
    self.reserve_count += 1
    if self.reserve_count > MAX_RESERVES:
        self._panic_arithmetic()
    self.hub_asset_to_reserve[hub][assetId] = reserve_id
    underlying: address = empty(address)
    decimals: uint8 = 0
    underlying, decimals = staticcall IHub(hub).getAssetUnderlyingAndDecimals(assetId)
    if underlying == empty(address):
        raise AssetNotListed()
    if decimals > 18:
        raise InvalidAssetDecimals()
    extcall IAaveOracle(ORACLE).setReserveSource(reserve_id, priceSource)
    flags: uint8 = ReserveFlagsMap.create(config.paused, config.frozen, config.borrowable, config.receiveSharesEnabled)
    self._store_reserve(reserve_id, Reserve(
        underlying=underlying,
        hub=hub,
        assetId=convert(assetId, uint16),
        decimals=decimals,
        collateralRisk=config.collateralRisk,
        flags=flags,
        dynamicConfigKey=0,
    ))
    self._store_dynamic_config(reserve_id, 0, dynamicConfig)
    log UpdateReservePriceSource(reserveId=reserve_id, priceSource=priceSource)
    log AddReserve(reserveId=reserve_id, assetId=assetId, hub=hub)
    log UpdateReserveConfig(reserveId=reserve_id, config=config)
    log AddDynamicReserveConfig(reserveId=reserve_id, dynamicConfigKey=0, config=dynamicConfig)
    return reserve_id


@external
def updateReserveConfig(reserveId: uint256, config: ReserveConfig):
    self._check_access(method_id("updateReserveConfig(uint256,(uint24,bool,bool,bool,bool))"))
    reserve: Reserve = self._require_reserve(reserveId)
    if convert(config.collateralRisk, uint256) > MAX_ALLOWED_COLLATERAL_RISK:
        raise InvalidCollateralRisk()
    reserve.collateralRisk = config.collateralRisk
    reserve.flags = ReserveFlagsMap.create(config.paused, config.frozen, config.borrowable, config.receiveSharesEnabled)
    self._store_reserve(reserveId, reserve)
    log UpdateReserveConfig(reserveId=reserveId, config=config)


@external
def updateReservePriceSource(reserveId: uint256, priceSource: address):
    self._check_access(method_id("updateReservePriceSource(uint256,address)"))
    self._require_reserve(reserveId)
    if priceSource == empty(address):
        raise InvalidAddress()
    extcall IAaveOracle(ORACLE).setReserveSource(reserveId, priceSource)
    log UpdateReservePriceSource(reserveId=reserveId, priceSource=priceSource)


@external
def addDynamicReserveConfig(reserveId: uint256, dynamicConfig: DynamicReserveConfig) -> uint32:
    self._check_access(method_id("addDynamicReserveConfig(uint256,(uint16,uint32,uint16))"))
    reserve: Reserve = self._require_reserve(reserveId)
    if reserve.dynamicConfigKey == max_value(uint32):
        raise MaximumDynamicConfigKeyReached()
    self._validate_dynamic(dynamicConfig)
    key: uint32 = reserve.dynamicConfigKey + 1
    reserve.dynamicConfigKey = key
    self._store_reserve(reserveId, reserve)
    self._store_dynamic_config(reserveId, key, dynamicConfig)
    log AddDynamicReserveConfig(reserveId=reserveId, dynamicConfigKey=key, config=dynamicConfig)
    return key


@external
def updateDynamicReserveConfig(reserveId: uint256, dynamicConfigKey: uint32, dynamicConfig: DynamicReserveConfig):
    self._check_access(method_id("updateDynamicReserveConfig(uint256,uint32,(uint16,uint32,uint16))"))
    self._require_reserve(reserveId)
    current: DynamicReserveConfig = self._load_dynamic_config(reserveId, dynamicConfigKey)
    if current.maxLiquidationBonus == 0:
        raise DynamicConfigKeyUninitialized()
    if dynamicConfig.collateralFactor == 0:
        raise InvalidCollateralFactor()
    self._validate_dynamic(dynamicConfig)
    self._store_dynamic_config(reserveId, dynamicConfigKey, dynamicConfig)
    log UpdateDynamicReserveConfig(reserveId=reserveId, dynamicConfigKey=dynamicConfigKey, config=dynamicConfig)


@external
def updatePositionManager(positionManager: address, active: bool):
    self._check_access(method_id("updatePositionManager(address,bool)"))
    self.position_manager_active[positionManager] = convert(active, uint256)
    log UpdatePositionManager(positionManager=positionManager, active=active)


@internal
@view
def _reserve_status(user: address, reserve_id: uint256) -> (bool, bool):
    word: uint256 = self.position_status[user][reserve_id >> 7]
    status: uint256 = word >> ((reserve_id % 128) << 1)
    return status & 1 != 0, status & 2 != 0


@internal
def _set_borrowing(user: address, reserve_id: uint256, enabled: bool):
    bucket: uint256 = reserve_id >> 7
    bit: uint256 = 1 << ((reserve_id % 128) << 1)
    if enabled:
        self.position_status[user][bucket] |= bit
    else:
        self.position_status[user][bucket] &= max_value(uint256) ^ bit


@internal
def _set_using_as_collateral(user: address, reserve_id: uint256, enabled: bool):
    bucket: uint256 = reserve_id >> 7
    bit: uint256 = 2 << ((reserve_id % 128) << 1)
    if enabled:
        self.position_status[user][bucket] |= bit
    else:
        self.position_status[user][bucket] &= max_value(uint256) ^ bit


@internal
@view
def _next_position(user: address, from_reserve_id: uint256) -> (uint256, bool, bool):
    bucket: uint256 = PositionStatusMap.bucket_id(from_reserve_id)
    word: uint256 = self.position_status[user][bucket]
    set_bit_id: uint256 = PositionStatusMap.fls(
        PositionStatusMap.isolate_until(word, from_reserve_id)
    )
    for _i: uint256 in range(2):
        if set_bit_id != 256 or bucket == 0:
            break
        bucket -= 1
        word = self.position_status[user][bucket]
        set_bit_id = PositionStatusMap.fls(word)
    if set_bit_id == 256:
        return PositionStatusMap.NOT_FOUND, False, False
    status: uint256 = word >> ((set_bit_id >> 1) << 1)
    return PositionStatusMap.from_bit_id(set_bit_id, bucket), status & 1 != 0, status & 2 != 0


@internal
@view
def _next_borrowing(user: address, from_reserve_id: uint256) -> uint256:
    bucket: uint256 = PositionStatusMap.bucket_id(from_reserve_id)
    set_bit_id: uint256 = PositionStatusMap.fls(
        PositionStatusMap.isolate_borrowing_until(
            self.position_status[user][bucket],
            from_reserve_id,
        )
    )
    for _i: uint256 in range(2):
        if set_bit_id != 256 or bucket == 0:
            break
        bucket -= 1
        set_bit_id = PositionStatusMap.fls(
            PositionStatusMap.isolate_borrowing(self.position_status[user][bucket])
        )
    if set_bit_id == 256:
        return PositionStatusMap.NOT_FOUND
    return PositionStatusMap.from_bit_id(set_bit_id, bucket)


@internal
@view
def _next_collateral(user: address, from_reserve_id: uint256) -> uint256:
    bucket: uint256 = PositionStatusMap.bucket_id(from_reserve_id)
    set_bit_id: uint256 = PositionStatusMap.fls(
        PositionStatusMap.isolate_collateral_until(
            self.position_status[user][bucket],
            from_reserve_id,
        )
    )
    for _i: uint256 in range(2):
        if set_bit_id != 256 or bucket == 0:
            break
        bucket -= 1
        set_bit_id = PositionStatusMap.fls(
            PositionStatusMap.isolate_collateral(self.position_status[user][bucket])
        )
    if set_bit_id == 256:
        return PositionStatusMap.NOT_FOUND
    return PositionStatusMap.from_bit_id(set_bit_id, bucket)


@internal
@view
def _collateral_count(user: address) -> uint256:
    reserve_count_: uint256 = self.reserve_count
    bucket: uint256 = PositionStatusMap.bucket_id(reserve_count_)
    count: uint256 = PositionStatusMap.pop_count(
        PositionStatusMap.isolate_collateral_until(
            self.position_status[user][bucket],
            reserve_count_,
        )
    )
    for _i: uint256 in range(2):
        if bucket == 0:
            break
        bucket -= 1
        count += PositionStatusMap.pop_count(
            PositionStatusMap.isolate_collateral(self.position_status[user][bucket])
        )
    return count


@internal
@view
def _borrow_count(user: address) -> uint256:
    reserve_count_: uint256 = self.reserve_count
    bucket: uint256 = PositionStatusMap.bucket_id(reserve_count_)
    count: uint256 = PositionStatusMap.pop_count(
        PositionStatusMap.isolate_borrowing_until(
            self.position_status[user][bucket],
            reserve_count_,
        )
    )
    for _i: uint256 in range(2):
        if bucket == 0:
            break
        bucket -= 1
        count += PositionStatusMap.pop_count(
            PositionStatusMap.isolate_borrowing(self.position_status[user][bucket])
        )
    return count


@internal
def _refresh_configs(user: address):
    reserve_id: uint256 = self.reserve_count
    for _i: uint256 in range(MAX_RESERVES):
        reserve_id = self._next_collateral(user, reserve_id)
        if reserve_id == PositionStatusMap.NOT_FOUND:
            break
        position: UserPositionUtils.UserPosition = self._load_user_position(user, reserve_id)
        position.dynamicConfigKey = self._load_reserve(reserve_id).dynamicConfigKey
        self._store_user_position(user, reserve_id, position)


@internal
@view
def _account_data(user: address) -> UserAccountData:
    account: UserAccountData = UserAccountData(
        riskPremium=0,
        avgCollateralFactor=0,
        healthFactor=max_value(uint256),
        totalCollateralValue=0,
        totalDebtValueRay=0,
        activeCollateralCount=0,
        borrowCount=0,
    )
    collateral_info: DynArray[CollateralInfo, MAX_RESERVES] = []
    reserve_id: uint256 = self.reserve_count
    for _i: uint256 in range(MAX_RESERVES):
        borrowing: bool = False
        collateral: bool = False
        reserve_id, borrowing, collateral = self._next_position(user, reserve_id)
        if reserve_id == PositionStatusMap.NOT_FOUND:
            break
        reserve: Reserve = self._load_reserve(reserve_id)
        position: UserPositionUtils.UserPosition = self._load_user_position(user, reserve_id)
        price: uint256 = staticcall IAaveOracle(ORACLE).getReservePrice(reserve_id)
        if collateral:
            dynamic: DynamicReserveConfig = self._load_dynamic_config(reserve_id, position.dynamicConfigKey)
            if dynamic.collateralFactor > 0 and position.suppliedShares > 0:
                assets: uint256 = staticcall IHub(reserve.hub).previewRemoveByShares(convert(reserve.assetId, uint256), convert(position.suppliedShares, uint256))
                collateral_value: uint256 = SpokeUtils.to_value(assets, convert(reserve.decimals, uint256), price)
                account.totalCollateralValue += collateral_value
                account.avgCollateralFactor += convert(dynamic.collateralFactor, uint256) * collateral_value
                account.activeCollateralCount += 1
                collateral_info.append(CollateralInfo(risk=convert(reserve.collateralRisk, uint256), collateralValue=collateral_value))
        if borrowing:
            index: uint256 = staticcall IHub(reserve.hub).getAssetDrawnIndex(convert(reserve.assetId, uint256))
            premium_ray: uint256 = UserPositionUtils.calculate_premium_ray(position, index)
            debt_ray: uint256 = convert(position.drawnShares, uint256) * index + premium_ray
            account.totalDebtValueRay += SpokeUtils.to_value(debt_ray, convert(reserve.decimals, uint256), price)
            account.borrowCount += 1
    if account.totalDebtValueRay > 0:
        account.healthFactor = SharesMath._mul_div_down(
            WadRayMath.bps_to_wad(account.avgCollateralFactor),
            RAY,
            account.totalDebtValueRay,
        )
    if account.totalCollateralValue > 0:
        account.avgCollateralFactor = WadRayMath.bps_to_wad(account.avgCollateralFactor) // account.totalCollateralValue
    # Stable insertion sort: risk ascending, and collateral value descending for equal risks.
    for i: uint256 in range(MAX_RESERVES):
        if i >= len(collateral_info):
            break
        j: uint256 = i
        for _k: uint256 in range(MAX_RESERVES):
            if j == 0:
                break
            left: CollateralInfo = collateral_info[j - 1]
            right: CollateralInfo = collateral_info[j]
            if left.risk < right.risk or (left.risk == right.risk and left.collateralValue >= right.collateralValue):
                break
            collateral_info[j - 1] = right
            collateral_info[j] = left
            j -= 1
    total_debt_value: uint256 = WadRayMath.from_ray_up(account.totalDebtValueRay)
    debt_left: uint256 = total_debt_value
    weighted_risk: uint256 = 0
    for i: uint256 in range(MAX_RESERVES):
        if i >= len(collateral_info) or debt_left == 0:
            break
        covered: uint256 = min(collateral_info[i].collateralValue, debt_left)
        weighted_risk += covered * collateral_info[i].risk
        debt_left -= covered
    if debt_left < total_debt_value:
        denominator: uint256 = total_debt_value - debt_left
        account.riskPremium = weighted_risk // denominator + convert(weighted_risk % denominator != 0, uint256)
    return account


@internal
def _notify_risk_premium(user: address, new_risk_premium: uint256):
    old: uint256 = convert(self.risk_premium[user], uint256)
    if new_risk_premium == 0 and old == 0:
        return
    self.risk_premium[user] = self._u24(new_risk_premium)
    reserve_id: uint256 = self.reserve_count
    for _i: uint256 in range(MAX_RESERVES):
        reserve_id = self._next_borrowing(user, reserve_id)
        if reserve_id == PositionStatusMap.NOT_FOUND:
            break
        reserve: Reserve = self._load_reserve(reserve_id)
        position: UserPositionUtils.UserPosition = self._load_user_position(user, reserve_id)
        index: uint256 = staticcall IHub(reserve.hub).getAssetDrawnIndex(convert(reserve.assetId, uint256))
        delta: UserPositionUtils.PremiumDelta = UserPositionUtils.calculate_premium_delta(position, 0, index, new_risk_premium, 0)
        extcall IHub(reserve.hub).refreshPremium(convert(reserve.assetId, uint256), delta)
        new_shares: int256 = convert(position.premiumShares, int256) + delta.sharesDelta
        new_offset: int256 = convert(position.premiumOffsetRay, int256) + delta.offsetRayDelta
        position.premiumShares = convert(new_shares, uint120)
        position.premiumOffsetRay = convert(new_offset, int200)
        self._store_user_position(user, reserve_id, position)
        log RefreshPremiumDebt(reserveId=reserve_id, user=user, premiumDelta=delta)
    log UpdateUserRiskPremium(user=user, riskPremium=new_risk_premium)


@internal
def _refresh_validate(user: address) -> UserAccountData:
    self._refresh_configs(user)
    account: UserAccountData = self._account_data(user)
    log RefreshAllUserDynamicConfig(user=user)
    if account.healthFactor < HEALTH_FACTOR_LIQUIDATION_THRESHOLD:
        raise HealthFactorBelowThreshold()
    return account


@external
def supply(reserveId: uint256, amount: uint256, onBehalfOf: address) -> (uint256, uint256):
    self._enter_nonreentrant()
    self._only_position_manager(onBehalfOf)
    reserve: Reserve = self._require_reserve(reserveId)
    if ReserveFlagsMap.paused(reserve.flags):
        raise ReservePaused()
    if ReserveFlagsMap.frozen(reserve.flags):
        raise ReserveFrozen()
    self._safe_transfer_from(reserve.underlying, msg.sender, reserve.hub, amount)
    supplied_shares: uint256 = extcall IHub(reserve.hub).add(convert(reserve.assetId, uint256), amount)
    position: UserPositionUtils.UserPosition = self._load_user_position(onBehalfOf, reserveId)
    position.suppliedShares = self._u120(convert(position.suppliedShares, uint256) + supplied_shares)
    self._store_user_position(onBehalfOf, reserveId, position)
    log Supply(reserveId=reserveId, caller=msg.sender, user=onBehalfOf, suppliedShares=supplied_shares, suppliedAmount=amount)
    self._exit_nonreentrant()
    return supplied_shares, amount


@external
def withdraw(reserveId: uint256, amount: uint256, onBehalfOf: address) -> (uint256, uint256):
    self._enter_nonreentrant()
    self._only_position_manager(onBehalfOf)
    reserve: Reserve = self._require_reserve(reserveId)
    if ReserveFlagsMap.paused(reserve.flags):
        raise ReservePaused()
    position: UserPositionUtils.UserPosition = self._load_user_position(onBehalfOf, reserveId)
    maximum: uint256 = staticcall IHub(reserve.hub).previewRemoveByShares(convert(reserve.assetId, uint256), convert(position.suppliedShares, uint256))
    withdrawn_amount: uint256 = min(amount, maximum)
    withdrawn_shares: uint256 = extcall IHub(reserve.hub).remove(convert(reserve.assetId, uint256), withdrawn_amount, msg.sender)
    shares_120: uint120 = self._u120(withdrawn_shares)
    if shares_120 > position.suppliedShares:
        self._panic_arithmetic()
    position.suppliedShares -= shares_120
    self._store_user_position(onBehalfOf, reserveId, position)
    _borrowing: bool = False
    collateral: bool = False
    _borrowing, collateral = self._reserve_status(onBehalfOf, reserveId)
    if collateral:
        account: UserAccountData = self._refresh_validate(onBehalfOf)
        self._notify_risk_premium(onBehalfOf, account.riskPremium)
    log Withdraw(reserveId=reserveId, caller=msg.sender, user=onBehalfOf, withdrawnShares=withdrawn_shares, withdrawnAmount=withdrawn_amount)
    self._exit_nonreentrant()
    return withdrawn_shares, withdrawn_amount


@external
def borrow(reserveId: uint256, amount: uint256, onBehalfOf: address) -> (uint256, uint256):
    self._enter_nonreentrant()
    self._only_position_manager(onBehalfOf)
    reserve: Reserve = self._require_reserve(reserveId)
    if ReserveFlagsMap.paused(reserve.flags):
        raise ReservePaused()
    if ReserveFlagsMap.frozen(reserve.flags):
        raise ReserveFrozen()
    if not ReserveFlagsMap.borrowable(reserve.flags):
        raise ReserveNotBorrowable()
    drawn_shares: uint256 = extcall IHub(reserve.hub).draw(convert(reserve.assetId, uint256), amount, msg.sender)
    position: UserPositionUtils.UserPosition = self._load_user_position(onBehalfOf, reserveId)
    position.drawnShares = self._u120(convert(position.drawnShares, uint256) + drawn_shares)
    self._store_user_position(onBehalfOf, reserveId, position)
    borrowing: bool = False
    _collateral: bool = False
    borrowing, _collateral = self._reserve_status(onBehalfOf, reserveId)
    if not borrowing:
        if MAX_USER_RESERVES_LIMIT != max_value(uint16) and self._borrow_count(onBehalfOf) >= convert(MAX_USER_RESERVES_LIMIT, uint256):
            raise MaximumUserReservesExceeded()
        self._set_borrowing(onBehalfOf, reserveId, True)
    account: UserAccountData = self._refresh_validate(onBehalfOf)
    self._notify_risk_premium(onBehalfOf, account.riskPremium)
    log Borrow(reserveId=reserveId, caller=msg.sender, user=onBehalfOf, drawnShares=drawn_shares, drawnAmount=amount)
    self._exit_nonreentrant()
    return drawn_shares, amount


@external
def borrowWithoutHfCheck(reserveId: uint256, amount: uint256, onBehalfOf: address) -> (uint256, uint256):
    self._enter_nonreentrant()
    self._only_position_manager(onBehalfOf)
    reserve: Reserve = self._require_reserve(reserveId)
    if ReserveFlagsMap.paused(reserve.flags):
        raise ReservePaused()
    if ReserveFlagsMap.frozen(reserve.flags):
        raise ReserveFrozen()
    if not ReserveFlagsMap.borrowable(reserve.flags):
        raise ReserveNotBorrowable()
    drawn_shares: uint256 = extcall IHub(reserve.hub).draw(convert(reserve.assetId, uint256), amount, msg.sender)
    position: UserPositionUtils.UserPosition = self._load_user_position(onBehalfOf, reserveId)
    position.drawnShares = self._u120(convert(position.drawnShares, uint256) + drawn_shares)
    self._store_user_position(onBehalfOf, reserveId, position)
    borrowing: bool = False
    _collateral: bool = False
    borrowing, _collateral = self._reserve_status(onBehalfOf, reserveId)
    if not borrowing:
        if MAX_USER_RESERVES_LIMIT != max_value(uint16) and self._borrow_count(onBehalfOf) >= convert(MAX_USER_RESERVES_LIMIT, uint256):
            raise MaximumUserReservesExceeded()
        self._set_borrowing(onBehalfOf, reserveId, True)
    self._refresh_configs(onBehalfOf)
    account: UserAccountData = self._account_data(onBehalfOf)
    log RefreshAllUserDynamicConfig(user=onBehalfOf)
    self._notify_risk_premium(onBehalfOf, account.riskPremium)
    log Borrow(reserveId=reserveId, caller=msg.sender, user=onBehalfOf, drawnShares=drawn_shares, drawnAmount=amount)
    self._exit_nonreentrant()
    return drawn_shares, amount


@external
def repay(reserveId: uint256, amount: uint256, onBehalfOf: address) -> (uint256, uint256):
    self._enter_nonreentrant()
    self._only_position_manager(onBehalfOf)
    reserve: Reserve = self._require_reserve(reserveId)
    if ReserveFlagsMap.paused(reserve.flags):
        raise ReservePaused()
    position: UserPositionUtils.UserPosition = self._load_user_position(onBehalfOf, reserveId)
    index: uint256 = staticcall IHub(reserve.hub).getAssetDrawnIndex(convert(reserve.assetId, uint256))
    drawn_restored: uint256 = 0
    premium_restored_ray: uint256 = 0
    drawn_restored, premium_restored_ray = UserPositionUtils.calculate_restore_amount(position, index, amount)
    restored_shares: uint256 = WadRayMath.ray_div_down(drawn_restored, index)
    delta: UserPositionUtils.PremiumDelta = UserPositionUtils.calculate_premium_delta(
        position,
        restored_shares,
        index,
        convert(self.risk_premium[onBehalfOf], uint256),
        premium_restored_ray,
    )
    total_restored: uint256 = drawn_restored + WadRayMath.from_ray_up(premium_restored_ray)
    self._safe_transfer_from(reserve.underlying, msg.sender, reserve.hub, total_restored)
    extcall IHub(reserve.hub).restore(convert(reserve.assetId, uint256), drawn_restored, delta)
    new_premium_shares: int256 = convert(position.premiumShares, int256) + delta.sharesDelta
    new_offset: int256 = convert(position.premiumOffsetRay, int256) + delta.offsetRayDelta
    position.premiumShares = convert(new_premium_shares, uint120)
    position.premiumOffsetRay = convert(new_offset, int200)
    shares_120: uint120 = self._u120(restored_shares)
    if shares_120 > position.drawnShares:
        self._panic_arithmetic()
    position.drawnShares -= shares_120
    if position.drawnShares == 0:
        self._set_borrowing(onBehalfOf, reserveId, False)
    self._store_user_position(onBehalfOf, reserveId, position)
    log Repay(reserveId=reserveId, caller=msg.sender, user=onBehalfOf, drawnShares=restored_shares, totalAmountRepaid=total_restored, premiumDelta=delta)
    self._exit_nonreentrant()
    return restored_shares, total_restored


@external
def setUsingAsCollateral(reserveId: uint256, usingAsCollateral: bool, onBehalfOf: address):
    self._enter_nonreentrant()
    self._only_position_manager(onBehalfOf)
    reserve: Reserve = self._require_reserve(reserveId)
    _borrowing: bool = False
    collateral: bool = False
    _borrowing, collateral = self._reserve_status(onBehalfOf, reserveId)
    if collateral == usingAsCollateral:
        self._exit_nonreentrant()
        return
    if ReserveFlagsMap.paused(reserve.flags):
        raise ReservePaused()
    if usingAsCollateral:
        if ReserveFlagsMap.frozen(reserve.flags):
            raise ReserveFrozen()
        if MAX_USER_RESERVES_LIMIT != max_value(uint16) and self._collateral_count(onBehalfOf) >= convert(MAX_USER_RESERVES_LIMIT, uint256):
            raise MaximumUserReservesExceeded()
    self._set_using_as_collateral(onBehalfOf, reserveId, usingAsCollateral)
    if usingAsCollateral:
        position: UserPositionUtils.UserPosition = self._load_user_position(onBehalfOf, reserveId)
        position.dynamicConfigKey = reserve.dynamicConfigKey
        self._store_user_position(onBehalfOf, reserveId, position)
        log RefreshSingleUserDynamicConfig(user=onBehalfOf, reserveId=reserveId)
    else:
        account: UserAccountData = self._refresh_validate(onBehalfOf)
        self._notify_risk_premium(onBehalfOf, account.riskPremium)
    log SetUsingAsCollateral(reserveId=reserveId, caller=msg.sender, user=onBehalfOf, usingAsCollateral=usingAsCollateral)
    self._exit_nonreentrant()


@external
def updateUserRiskPremium(onBehalfOf: address):
    self._enter_nonreentrant()
    if not self._is_position_manager(onBehalfOf, msg.sender):
        self._check_access(method_id("updateUserRiskPremium(address)"))
    account: UserAccountData = self._account_data(onBehalfOf)
    self._notify_risk_premium(onBehalfOf, account.riskPremium)
    self._exit_nonreentrant()


@external
def updateUserDynamicConfig(onBehalfOf: address):
    self._enter_nonreentrant()
    if not self._is_position_manager(onBehalfOf, msg.sender):
        self._check_access(method_id("updateUserDynamicConfig(address)"))
    account: UserAccountData = self._refresh_validate(onBehalfOf)
    self._notify_risk_premium(onBehalfOf, account.riskPremium)
    self._exit_nonreentrant()


@external
def setUserPositionManager(positionManager: address, approve: bool):
    approval: uint256 = convert(approve, uint256)
    self.position_manager_approval[positionManager][msg.sender] = approval
    self.position_manager_approval_state[positionManager][msg.sender] = 1 + approval
    log SetUserPositionManager(user=msg.sender, positionManager=positionManager, approve=approve)


@external
def setUserPositionManagersWithSig(params: SetUserPositionManagers, signature: Bytes[INF]):
    if block.timestamp > params.deadline:
        raise InvalidSignature()
    update_hashes: DynArray[bytes32, 1024] = []
    for i: uint256 in range(1024):
        if i >= len(params.updates):
            break
        update_hash: bytes32 = keccak256(abi_encode(POSITION_MANAGER_UPDATE_TYPEHASH, params.updates[i].positionManager, params.updates[i].approve))
        update_hashes.append(update_hash)
    encoded_hashes: Bytes[32800] = abi_encode(update_hashes, ensure_tuple=False)
    updates_digest: bytes32 = keccak256(slice(encoded_hashes, 32, len(encoded_hashes) - 32))
    intent_hash: bytes32 = keccak256(abi_encode(
        SET_USER_POSITION_MANAGERS_TYPEHASH,
        params.onBehalfOf,
        updates_digest,
        params.nonce,
        params.deadline,
    ))
    digest: bytes32 = keccak256(concat(b"\x19\x01", self._domain_separator(), intent_hash))
    if not self._valid_signature(params.onBehalfOf, digest, signature):
        raise InvalidSignature()
    self._use_checked_nonce(params.onBehalfOf, params.nonce)
    for i: uint256 in range(1024):
        if i >= len(params.updates):
            break
        update: PositionManagerUpdate = params.updates[i]
        approval: uint256 = convert(update.approve, uint256)
        self.position_manager_approval[update.positionManager][params.onBehalfOf] = approval
        self.position_manager_approval_state[update.positionManager][params.onBehalfOf] = 1 + approval
        log SetUserPositionManager(user=params.onBehalfOf, positionManager=update.positionManager, approve=update.approve)


@external
def renouncePositionManagerRole(onBehalfOf: address):
    approval_state: uint256 = self.position_manager_approval_state[msg.sender][onBehalfOf]
    if approval_state == 1 or (approval_state == 0 and self.position_manager_approval[msg.sender][onBehalfOf] == 0):
        return
    self.position_manager_approval[msg.sender][onBehalfOf] = 0
    self.position_manager_approval_state[msg.sender][onBehalfOf] = 1
    log SetUserPositionManager(user=onBehalfOf, positionManager=msg.sender, approve=False)


@external
def permitReserve(reserveId: uint256, onBehalfOf: address, permitValue: uint256, deadline: uint256, permitV: uint8, permitR: bytes32, permitS: bytes32):
    reserve: Reserve = self._require_reserve(reserveId)
    _permit_success: bool = False
    _permit_response: Bytes[1] = b""
    _permit_success, _permit_response = raw_call(
        reserve.underlying,
        concat(
            method_id("permit(address,address,uint256,uint256,uint8,bytes32,bytes32)"),
            convert(onBehalfOf, bytes32),
            convert(self, bytes32),
            convert(permitValue, bytes32),
            convert(deadline, bytes32),
            convert(permitV, bytes32),
            permitR,
            permitS,
        ),
        max_outsize=1,
        revert_on_failure=False,
    )


@external
@view
def getLiquidationConfig() -> LiquidationConfig:
    return self.liquidation_config


@external
@view
def getReserveCount() -> uint256:
    return self.reserve_count


@external
@view
def getReserveSuppliedAssets(reserveId: uint256) -> uint256:
    reserve: Reserve = self._require_reserve(reserveId)
    return staticcall IHub(reserve.hub).getSpokeAddedAssets(convert(reserve.assetId, uint256), self)


@external
@view
def getReserveSuppliedShares(reserveId: uint256) -> uint256:
    reserve: Reserve = self._require_reserve(reserveId)
    return staticcall IHub(reserve.hub).getSpokeAddedShares(convert(reserve.assetId, uint256), self)


@external
@view
def getReserveDebt(reserveId: uint256) -> (uint256, uint256):
    reserve: Reserve = self._require_reserve(reserveId)
    return staticcall IHub(reserve.hub).getSpokeOwed(convert(reserve.assetId, uint256), self)


@external
@view
def getReserveTotalDebt(reserveId: uint256) -> uint256:
    reserve: Reserve = self._require_reserve(reserveId)
    return staticcall IHub(reserve.hub).getSpokeTotalOwed(convert(reserve.assetId, uint256), self)


@external
@view
def getReserveId(hub: address, assetId: uint256) -> uint256:
    reserve_id: uint256 = self.hub_asset_to_reserve[hub][assetId]
    reserve: Reserve = self._load_reserve(reserve_id)
    if reserve.hub != hub or convert(reserve.assetId, uint256) != assetId:
        raise ReserveNotListed()
    return reserve_id


@external
@view
def getReserve(reserveId: uint256) -> Reserve:
    self._require_reserve(reserveId)
    return self._load_reserve(reserveId)


@external
@view
def getReserveConfig(reserveId: uint256) -> ReserveConfig:
    reserve: Reserve = self._require_reserve(reserveId)
    return ReserveConfig(
        collateralRisk=reserve.collateralRisk,
        paused=ReserveFlagsMap.paused(reserve.flags),
        frozen=ReserveFlagsMap.frozen(reserve.flags),
        borrowable=ReserveFlagsMap.borrowable(reserve.flags),
        receiveSharesEnabled=ReserveFlagsMap.receive_shares_enabled(reserve.flags),
    )


@external
@view
def getDynamicReserveConfig(reserveId: uint256, dynamicConfigKey: uint32) -> DynamicReserveConfig:
    self._require_reserve(reserveId)
    return self._load_dynamic_config(reserveId, dynamicConfigKey)


@external
@view
def getUserReserveStatus(reserveId: uint256, user: address) -> (bool, bool):
    self._require_reserve(reserveId)
    borrowing: bool = False
    collateral: bool = False
    borrowing, collateral = self._reserve_status(user, reserveId)
    return collateral, borrowing


@external
@view
def getUserSuppliedAssets(reserveId: uint256, user: address) -> uint256:
    reserve: Reserve = self._require_reserve(reserveId)
    position: UserPositionUtils.UserPosition = self._load_user_position(user, reserveId)
    return staticcall IHub(reserve.hub).previewRemoveByShares(convert(reserve.assetId, uint256), convert(position.suppliedShares, uint256))


@external
@view
def getUserSuppliedShares(reserveId: uint256, user: address) -> uint256:
    self._require_reserve(reserveId)
    return convert(self._load_user_position(user, reserveId).suppliedShares, uint256)


@internal
@view
def _user_debt(reserve_id: uint256, user: address) -> (uint256, uint256):
    reserve: Reserve = self._require_reserve(reserve_id)
    index: uint256 = staticcall IHub(reserve.hub).getAssetDrawnIndex(convert(reserve.assetId, uint256))
    return UserPositionUtils.get_debt(self._load_user_position(user, reserve_id), index)


@external
@view
def getUserDebt(reserveId: uint256, user: address) -> (uint256, uint256):
    drawn: uint256 = 0
    premium_ray: uint256 = 0
    drawn, premium_ray = self._user_debt(reserveId, user)
    return drawn, WadRayMath.from_ray_up(premium_ray)


@external
@view
def getUserTotalDebt(reserveId: uint256, user: address) -> uint256:
    drawn: uint256 = 0
    premium_ray: uint256 = 0
    drawn, premium_ray = self._user_debt(reserveId, user)
    return drawn + WadRayMath.from_ray_up(premium_ray)


@external
@view
def getUserPremiumDebtRay(reserveId: uint256, user: address) -> uint256:
    _drawn: uint256 = 0
    premium_ray: uint256 = 0
    _drawn, premium_ray = self._user_debt(reserveId, user)
    return premium_ray


@external
@view
def getUserPosition(reserveId: uint256, user: address) -> UserPositionUtils.UserPosition:
    self._require_reserve(reserveId)
    return self._load_user_position(user, reserveId)


@external
@view
def getUserLastRiskPremium(user: address) -> uint256:
    return convert(self.risk_premium[user], uint256)


@external
@view
def getUserAccountData(user: address) -> UserAccountData:
    return self._account_data(user)


@external
@view
def getLiquidationBonus(reserveId: uint256, user: address, healthFactor: uint256) -> uint256:
    self._require_reserve(reserveId)
    position: UserPositionUtils.UserPosition = self._load_user_position(user, reserveId)
    maximum: uint256 = convert(self._load_dynamic_config(reserveId, position.dynamicConfigKey).maxLiquidationBonus, uint256)
    if healthFactor <= convert(self.liquidation_config.healthFactorForMaxBonus, uint256):
        return maximum
    spread: uint256 = maximum - 10**4
    minimum: uint256 = 10**4 + PercentageMath.percent_mul_down(spread, convert(self.liquidation_config.liquidationBonusFactor, uint256))
    return minimum + SharesMath._mul_div_down(
        maximum - minimum,
        HEALTH_FACTOR_LIQUIDATION_THRESHOLD - healthFactor,
        HEALTH_FACTOR_LIQUIDATION_THRESHOLD - convert(self.liquidation_config.healthFactorForMaxBonus, uint256),
    )


@external
@view
def isPositionManagerActive(positionManager: address) -> bool:
    return self.position_manager_active[positionManager] != 0


@external
@view
def isPositionManager(user: address, positionManager: address) -> bool:
    return self._is_position_manager(user, positionManager)


@external
@view
def getLiquidationLogic() -> address:
    return LIQUIDATION_LOGIC


@external
def calculateUserAccountData(user: address, refreshConfig: bool) -> UserAccountData:
    if refreshConfig:
        self._refresh_configs(user)
    return self._account_data(user)


@external
def setReserveDynamicConfigKey(reserveId: uint256, configKey: uint32):
    reserve: Reserve = self._load_reserve(reserveId)
    reserve.dynamicConfigKey = configKey
    self._store_reserve(reserveId, reserve)


@internal
def _report_deficit(user: address):
    self.risk_premium[user] = 0
    reserve_id: uint256 = self.reserve_count
    for _i: uint256 in range(MAX_RESERVES):
        reserve_id = self._next_borrowing(user, reserve_id)
        if reserve_id == PositionStatusMap.NOT_FOUND:
            break
        reserve: Reserve = self._load_reserve(reserve_id)
        position: UserPositionUtils.UserPosition = self._load_user_position(user, reserve_id)
        drawn_shares: uint256 = convert(position.drawnShares, uint256)
        index: uint256 = staticcall IHub(reserve.hub).getAssetDrawnIndex(convert(reserve.assetId, uint256))
        premium_ray: uint256 = UserPositionUtils.calculate_premium_ray(position, index)
        delta: UserPositionUtils.PremiumDelta = UserPositionUtils.calculate_premium_delta(
            position,
            drawn_shares,
            index,
            0,
            premium_ray,
        )
        extcall IHub(reserve.hub).reportDeficit(
            convert(reserve.assetId, uint256),
            WadRayMath.ray_mul_up(drawn_shares, index),
            delta,
        )
        position.premiumShares = convert(convert(position.premiumShares, int256) + delta.sharesDelta, uint120)
        position.premiumOffsetRay = convert(convert(position.premiumOffsetRay, int256) + delta.offsetRayDelta, int200)
        position.drawnShares = 0
        self._store_user_position(user, reserve_id, position)
        self._set_borrowing(user, reserve_id, False)
        log ReportDeficit(reserveId=reserve_id, user=user, drawnShares=drawn_shares, premiumDelta=delta)
    log UpdateUserRiskPremium(user=user, riskPremium=0)


@external
def liquidationCall(collateralReserveId: uint256, debtReserveId: uint256, user: address, debtToCover: uint256, receiveShares: bool):
    self._enter_nonreentrant()
    account: UserAccountData = self._account_data(user)
    collateral_reserve: Reserve = self._require_reserve(collateralReserveId)
    debt_reserve: Reserve = self._require_reserve(debtReserveId)
    collateral_position: UserPositionUtils.UserPosition = self._load_user_position(user, collateralReserveId)
    debt_position: UserPositionUtils.UserPosition = self._load_user_position(user, debtReserveId)
    dynamic: DynamicReserveConfig = self._load_dynamic_config(collateralReserveId, collateral_position.dynamicConfigKey)
    drawn_index: uint256 = staticcall IHub(debt_reserve.hub).getAssetDrawnIndex(convert(debt_reserve.assetId, uint256))
    premium_ray: uint256 = UserPositionUtils.calculate_premium_ray(debt_position, drawn_index)
    _collateral_borrowing: bool = False
    is_using_as_collateral: bool = False
    _collateral_borrowing, is_using_as_collateral = self._reserve_status(user, collateralReserveId)

    validate_params: ValidateLiquidationCallParams = ValidateLiquidationCallParams(
        user=user,
        liquidator=msg.sender,
        collateralReserveFlags=collateral_reserve.flags,
        debtReserveFlags=debt_reserve.flags,
        suppliedShares=convert(collateral_position.suppliedShares, uint256),
        drawnShares=convert(debt_position.drawnShares, uint256),
        debtToCover=debtToCover,
        collateralFactor=convert(dynamic.collateralFactor, uint256),
        isUsingAsCollateral=is_using_as_collateral,
        healthFactor=account.healthFactor,
        receiveShares=receiveShares,
    )
    _validated: bool = staticcall ILiquidationLogic(LIQUIDATION_LOGIC).validateLiquidationCall(validate_params)

    amount_params: CalculateLiquidationAmountsParams = CalculateLiquidationAmountsParams(
        collateralReserveHub=collateral_reserve.hub,
        collateralReserveAssetId=convert(collateral_reserve.assetId, uint256),
        suppliedShares=convert(collateral_position.suppliedShares, uint256),
        collateralAssetDecimals=convert(collateral_reserve.decimals, uint256),
        collateralAssetPrice=staticcall IAaveOracle(ORACLE).getReservePrice(collateralReserveId),
        drawnShares=convert(debt_position.drawnShares, uint256),
        premiumDebtRay=premium_ray,
        drawnIndex=drawn_index,
        totalDebtValueRay=account.totalDebtValueRay,
        debtAssetDecimals=convert(debt_reserve.decimals, uint256),
        debtAssetPrice=staticcall IAaveOracle(ORACLE).getReservePrice(debtReserveId),
        debtToCover=debtToCover,
        collateralFactor=convert(dynamic.collateralFactor, uint256),
        healthFactorForMaxBonus=convert(self.liquidation_config.healthFactorForMaxBonus, uint256),
        liquidationBonusFactor=convert(self.liquidation_config.liquidationBonusFactor, uint256),
        maxLiquidationBonus=convert(dynamic.maxLiquidationBonus, uint256),
        targetHealthFactor=convert(self.liquidation_config.targetHealthFactor, uint256),
        healthFactor=account.healthFactor,
        liquidationFee=convert(dynamic.liquidationFee, uint256),
    )
    amounts: LiquidationAmounts = staticcall ILiquidationLogic(LIQUIDATION_LOGIC).calculateLiquidationAmounts(amount_params)

    shares_to_liquidate: uint120 = self._u120(amounts.collateralSharesToLiquidate)
    if shares_to_liquidate > collateral_position.suppliedShares:
        self._panic_arithmetic()
    collateral_position.suppliedShares -= shares_to_liquidate
    self._store_user_position(user, collateralReserveId, collateral_position)
    collateral_amount_removed: uint256 = staticcall IHub(collateral_reserve.hub).previewRemoveByShares(
        convert(collateral_reserve.assetId, uint256),
        amounts.collateralSharesToLiquidate,
    )
    if amounts.collateralSharesToLiquidator > 0:
        if receiveShares:
            liquidator_position: UserPositionUtils.UserPosition = self._load_user_position(msg.sender, collateralReserveId)
            liquidator_position.suppliedShares = self._u120(convert(liquidator_position.suppliedShares, uint256) + amounts.collateralSharesToLiquidator)
            self._store_user_position(msg.sender, collateralReserveId, liquidator_position)
        else:
            collateral_to_liquidator: uint256 = collateral_amount_removed
            if amounts.collateralSharesToLiquidator < amounts.collateralSharesToLiquidate:
                collateral_to_liquidator = staticcall IHub(collateral_reserve.hub).previewRemoveByShares(
                    convert(collateral_reserve.assetId, uint256),
                    amounts.collateralSharesToLiquidator,
                )
            extcall IHub(collateral_reserve.hub).remove(convert(collateral_reserve.assetId, uint256), collateral_to_liquidator, msg.sender)
    fee_shares: uint256 = amounts.collateralSharesToLiquidate - amounts.collateralSharesToLiquidator
    if fee_shares > 0:
        extcall IHub(collateral_reserve.hub).payFeeShares(convert(collateral_reserve.assetId, uint256), fee_shares)

    # Solidity storage references alias when collateral and debt use the same
    # reserve.  Vyper structs are values, so reload the position after applying
    # the collateral mutation to avoid restoring the old suppliedShares below.
    if debtReserveId == collateralReserveId:
        debt_position = self._load_user_position(user, debtReserveId)

    premium_delta: UserPositionUtils.PremiumDelta = UserPositionUtils.calculate_premium_delta(
        debt_position,
        amounts.drawnSharesToLiquidate,
        drawn_index,
        convert(self.risk_premium[user], uint256),
        amounts.premiumDebtRayToLiquidate,
    )
    drawn_amount: uint256 = WadRayMath.ray_mul_up(amounts.drawnSharesToLiquidate, drawn_index)
    restored_amount: uint256 = drawn_amount + WadRayMath.from_ray_up(amounts.premiumDebtRayToLiquidate)
    self._safe_transfer_from(debt_reserve.underlying, msg.sender, debt_reserve.hub, restored_amount)
    extcall IHub(debt_reserve.hub).restore(convert(debt_reserve.assetId, uint256), drawn_amount, premium_delta)
    debt_position.premiumShares = convert(convert(debt_position.premiumShares, int256) + premium_delta.sharesDelta, uint120)
    debt_position.premiumOffsetRay = convert(convert(debt_position.premiumOffsetRay, int256) + premium_delta.offsetRayDelta, int200)
    drawn_120: uint120 = self._u120(amounts.drawnSharesToLiquidate)
    if drawn_120 > debt_position.drawnShares:
        self._panic_arithmetic()
    debt_position.drawnShares -= drawn_120
    debt_empty: bool = debt_position.drawnShares == 0
    if debt_empty:
        self._set_borrowing(user, debtReserveId, False)
    self._store_user_position(user, debtReserveId, debt_position)

    log LiquidationCall(
        collateralReserveId=collateralReserveId,
        debtReserveId=debtReserveId,
        user=user,
        liquidator=msg.sender,
        receiveShares=receiveShares,
        debtAmountRestored=restored_amount,
        drawnSharesLiquidated=amounts.drawnSharesToLiquidate,
        premiumDelta=premium_delta,
        collateralAmountRemoved=collateral_amount_removed,
        collateralSharesLiquidated=amounts.collateralSharesToLiquidate,
        collateralSharesToLiquidator=amounts.collateralSharesToLiquidator,
    )

    collateral_empty: bool = collateral_position.suppliedShares == 0
    deficit: bool = collateral_empty and account.activeCollateralCount <= 1 and (not debt_empty or account.borrowCount > 1)
    if deficit:
        self._report_deficit(user)
    else:
        updated: UserAccountData = self._account_data(user)
        self._notify_risk_premium(user, updated.riskPremium)
    self._exit_nonreentrant()


@external
@raw_return
def __default__() -> Bytes[INF]:
    # Nested unbounded dynamic arrays are not yet a source-level type in b1,
    # so decode the standard `bytes[]` ABI through its unbounded offset list.
    if len(msg.data) < 68 or slice(msg.data, 0, 4) != method_id("multicall(bytes[])"):
        raise

    array_start: uint256 = 4 + convert(slice(msg.data, 4, 32), uint256)
    if array_start > len(msg.data) - 32:
        raise
    count: uint256 = convert(slice(msg.data, array_start, 32), uint256)
    heads_size: uint256 = 32 + 32 * count
    if heads_size > len(msg.data) - array_start:
        raise

    element_offsets: DynArray[uint256, INF] = abi_decode(
        slice(msg.data, array_start, heads_size),
        DynArray[uint256, INF],
        unwrap_tuple=False,
    )
    element_heads_start: uint256 = array_start + 32
    heads: Bytes[INF] = b""
    tails: Bytes[INF] = b""
    output_offset: uint256 = 32 * count
    for element_offset: uint256 in element_offsets:
        element_start: uint256 = element_heads_start + element_offset
        if element_start > len(msg.data) - 32:
            raise
        element_length: uint256 = convert(slice(msg.data, element_start, 32), uint256)
        payload_start: uint256 = element_start + 32
        if element_length > len(msg.data) - payload_start:
            raise

        call_data: Bytes[INF] = slice(msg.data, payload_start, element_length)
        result: Bytes[256] = raw_call(
            self,
            call_data,
            max_outsize=256,
            is_delegate_call=True,
        )
        encoded_result: Bytes[INF] = abi_encode(result, ensure_tuple=False)
        heads = concat(heads, convert(output_offset, bytes32))
        tails = concat(tails, encoded_result)
        output_offset += len(encoded_result)

    return concat(convert(32, bytes32), convert(count, bytes32), heads, tails)
