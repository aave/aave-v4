# pragma version 0.5.0b1

from hub.libraries import Premium
from hub.libraries import SharesMath
from libraries import Errors
from libraries.math import MathUtils
from libraries.math import PercentageMath
from libraries.math import WadRayMath
from hub.interfaces import IHub
from hub.interfaces import IInterestRateStrategy
from dependencies.openzeppelin import IAuthority
from dependencies.openzeppelin import IERC20

implements: IHub

struct PackedAsset:
    liquidityData: uint256
    addedData: uint256
    premiumOffsetRay: int200
    debtData: uint256
    indexData: uint256
    underlying: address
    irStrategy: address
    reinvestmentController: address
    feeReceiver: address
    deficitRay: uint200

struct PackedSpokeData:
    debtShares: uint256
    premiumOffsetRay: int200
    configData: uint256
    deficitRay: uint200

HUB_REVISION: public(constant(uint64)) = 1
MAX_ALLOWED_UNDERLYING_DECIMALS: public(constant(uint8)) = 18
MIN_ALLOWED_UNDERLYING_DECIMALS: public(constant(uint8)) = 6
MAX_ALLOWED_SPOKE_CAP: public(constant(uint40)) = max_value(uint40)
MAX_RISK_PREMIUM_THRESHOLD: public(constant(uint24)) = max_value(uint24)
RAY: constant(uint256) = 10**27
PERCENTAGE_FACTOR: constant(uint256) = 10**4
SPOKE_COUNT_KEY: constant(uint256) = max_value(uint256)
MASK_8: constant(uint256) = 2**8 - 1
MASK_16: constant(uint256) = 2**16 - 1
MASK_24: constant(uint256) = 2**24 - 1
MASK_40: constant(uint256) = 2**40 - 1
MASK_96: constant(uint256) = 2**96 - 1
MASK_120: constant(uint256) = 2**120 - 1

asset_count: uint256
assets: HashMap[uint256, PackedAsset]
spokes: HashMap[uint256, HashMap[address, PackedSpokeData]]
spoke_addresses: HashMap[uint256, HashMap[uint256, bytes32]]
spoke_listed: HashMap[uint256, HashMap[address, bool]]
underlying_to_asset_id: HashMap[address, uint256]
authority_address: address
initialized_state: uint256


@internal
@pure
def _pack_asset(asset: IHub.Asset) -> PackedAsset:
    return PackedAsset(
        liquidityData=(
            convert(asset.liquidity, uint256)
            | convert(asset.realizedFees, uint256) << 120
            | convert(asset.decimals, uint256) << 240
        ),
        addedData=convert(asset.addedShares, uint256) | convert(asset.swept, uint256) << 120,
        premiumOffsetRay=asset.premiumOffsetRay,
        debtData=(
            convert(asset.drawnShares, uint256)
            | convert(asset.premiumShares, uint256) << 120
            | convert(asset.liquidityFee, uint256) << 240
        ),
        indexData=(
            convert(asset.drawnIndex, uint256)
            | convert(asset.drawnRate, uint256) << 120
            | convert(asset.lastUpdateTimestamp, uint256) << 216
        ),
        underlying=asset.underlying,
        irStrategy=asset.irStrategy,
        reinvestmentController=asset.reinvestmentController,
        feeReceiver=asset.feeReceiver,
        deficitRay=asset.deficitRay,
    )


@internal
@pure
def _unpack_asset(packed: PackedAsset) -> IHub.Asset:
    return IHub.Asset(
        liquidity=convert(packed.liquidityData & MASK_120, uint120),
        realizedFees=convert((packed.liquidityData >> 120) & MASK_120, uint120),
        decimals=convert((packed.liquidityData >> 240) & MASK_8, uint8),
        addedShares=convert(packed.addedData & MASK_120, uint120),
        swept=convert((packed.addedData >> 120) & MASK_120, uint120),
        premiumOffsetRay=packed.premiumOffsetRay,
        drawnShares=convert(packed.debtData & MASK_120, uint120),
        premiumShares=convert((packed.debtData >> 120) & MASK_120, uint120),
        liquidityFee=convert((packed.debtData >> 240) & MASK_16, uint16),
        drawnIndex=convert(packed.indexData & MASK_120, uint120),
        drawnRate=convert((packed.indexData >> 120) & MASK_96, uint96),
        lastUpdateTimestamp=convert((packed.indexData >> 216) & MASK_40, uint40),
        underlying=packed.underlying,
        irStrategy=packed.irStrategy,
        reinvestmentController=packed.reinvestmentController,
        feeReceiver=packed.feeReceiver,
        deficitRay=packed.deficitRay,
    )


@internal
@view
def _load_asset(asset_id: uint256) -> IHub.Asset:
    return self._unpack_asset(self.assets[asset_id])


@internal
def _store_asset(asset_id: uint256, asset: IHub.Asset):
    self.assets[asset_id] = self._pack_asset(asset)


@internal
@pure
def _pack_spoke(data: IHub.SpokeData) -> PackedSpokeData:
    return PackedSpokeData(
        debtShares=convert(data.drawnShares, uint256) | convert(data.premiumShares, uint256) << 120,
        premiumOffsetRay=data.premiumOffsetRay,
        configData=(
            convert(data.addedShares, uint256)
            | convert(data.addCap, uint256) << 120
            | convert(data.drawCap, uint256) << 160
            | convert(data.riskPremiumThreshold, uint256) << 200
            | convert(data.active, uint256) << 224
            | convert(data.halted, uint256) << 225
        ),
        deficitRay=data.deficitRay,
    )


@internal
@pure
def _unpack_spoke(packed: PackedSpokeData) -> IHub.SpokeData:
    return IHub.SpokeData(
        drawnShares=convert(packed.debtShares & MASK_120, uint120),
        premiumShares=convert((packed.debtShares >> 120) & MASK_120, uint120),
        premiumOffsetRay=packed.premiumOffsetRay,
        addedShares=convert(packed.configData & MASK_120, uint120),
        addCap=convert((packed.configData >> 120) & MASK_40, uint40),
        drawCap=convert((packed.configData >> 160) & MASK_40, uint40),
        riskPremiumThreshold=convert((packed.configData >> 200) & MASK_24, uint24),
        active=(packed.configData >> 224) & 1 != 0,
        halted=(packed.configData >> 225) & 1 != 0,
        deficitRay=packed.deficitRay,
    )


@internal
@view
def _load_spoke(asset_id: uint256, spoke: address) -> IHub.SpokeData:
    return self._unpack_spoke(self.spokes[asset_id][spoke])


@internal
def _store_spoke(asset_id: uint256, spoke: address, data: IHub.SpokeData):
    self.spokes[asset_id][spoke] = self._pack_spoke(data)


@deploy
def __init__():
    self.initialized_state = convert(max_value(uint64), uint256)
    log IHub.Initialized(version=max_value(uint64))


@internal
@view
def _check_access(selector: Bytes[4]):
    allowed: bool = False
    delay: uint32 = 0
    allowed, delay = staticcall IAuthority(self.authority_address).canCall(msg.sender, self, convert(selector, bytes4))
    if not allowed:
        raise IHub.AccessManagedUnauthorized(msg.sender)


@internal
@pure
def _u120(cast_value: uint256) -> uint120:
    if cast_value > convert(max_value(uint120), uint256):
        raise IHub.SafeCastOverflowedUintDowncast(120, cast_value)
    return convert(cast_value, uint120)


@internal
@pure
def _u96(cast_value: uint256) -> uint96:
    if cast_value > convert(max_value(uint96), uint256):
        raise IHub.SafeCastOverflowedUintDowncast(96, cast_value)
    return convert(cast_value, uint96)


@internal
@pure
def _u40(cast_value: uint256) -> uint40:
    if cast_value > convert(max_value(uint40), uint256):
        raise IHub.SafeCastOverflowedUintDowncast(40, cast_value)
    return convert(cast_value, uint40)


@internal
@pure
def _u200(cast_value: uint256) -> uint200:
    if cast_value > convert(max_value(uint200), uint256):
        raise IHub.SafeCastOverflowedUintDowncast(200, cast_value)
    return convert(cast_value, uint200)


@internal
@pure
def _i200(cast_value: int256) -> int200:
    if cast_value > convert(max_value(int200), int256) or cast_value < convert(min_value(int200), int256):
        raise IHub.SafeCastOverflowedIntDowncast(200, cast_value)
    return convert(cast_value, int200)


@internal
@pure
def _panic_arithmetic():
    raise Errors.Panic(convert(17, uint256))


@internal
def _safe_transfer(token: address, receiver: address, amount: uint256):
    result: Bytes[32] = raw_call(
        token,
        concat(method_id("transfer(address,uint256)"), convert(receiver, bytes32), convert(amount, bytes32)),
        max_outsize=32,
    )
    assert len(result) == 0 or abi_decode(result, bool)


@internal
@view
def _drawn_index(asset: IHub.Asset) -> uint256:
    previous: uint256 = convert(asset.drawnIndex, uint256)
    if convert(asset.lastUpdateTimestamp, uint256) == block.timestamp or (asset.drawnShares == 0 and asset.premiumShares == 0):
        return previous
    linear: uint256 = MathUtils.calculate_linear_interest(asset.drawnRate, asset.lastUpdateTimestamp)
    return WadRayMath.ray_mul_up(previous, linear)


@internal
@pure
def _premium_ray(premium_shares: uint256, premium_offset_ray: int256, drawn_index: uint256) -> uint256:
    return Premium.calculate_premium_ray(premium_shares, premium_offset_ray, drawn_index)


@internal
@view
def _unrealized_fees(asset: IHub.Asset, drawn_index: uint256) -> uint256:
    previous: uint256 = convert(asset.drawnIndex, uint256)
    if previous == drawn_index or asset.liquidityFee == 0:
        return 0
    after_ray: uint256 = convert(asset.drawnShares, uint256) * drawn_index + self._premium_ray(convert(asset.premiumShares, uint256), convert(asset.premiumOffsetRay, int256), drawn_index) + convert(asset.deficitRay, uint256)
    before_ray: uint256 = convert(asset.drawnShares, uint256) * previous + self._premium_ray(convert(asset.premiumShares, uint256), convert(asset.premiumOffsetRay, int256), previous) + convert(asset.deficitRay, uint256)
    growth: uint256 = WadRayMath.from_ray_up(after_ray) - WadRayMath.from_ray_up(before_ray)
    return PercentageMath.percent_mul_down(growth, convert(asset.liquidityFee, uint256))


@internal
@view
def _total_added_assets(asset: IHub.Asset) -> uint256:
    index: uint256 = self._drawn_index(asset)
    owed_ray: uint256 = convert(asset.drawnShares, uint256) * index + self._premium_ray(convert(asset.premiumShares, uint256), convert(asset.premiumOffsetRay, int256), index) + convert(asset.deficitRay, uint256)
    return convert(asset.liquidity, uint256) + convert(asset.swept, uint256) + WadRayMath.from_ray_up(owed_ray) - convert(asset.realizedFees, uint256) - self._unrealized_fees(asset, index)


@internal
@view
def _to_added_shares_down(asset: IHub.Asset, amount: uint256) -> uint256:
    return SharesMath.to_shares_down(amount, self._total_added_assets(asset), convert(asset.addedShares, uint256))


@internal
@view
def _to_added_shares_up(asset: IHub.Asset, amount: uint256) -> uint256:
    return SharesMath.to_shares_up(amount, self._total_added_assets(asset), convert(asset.addedShares, uint256))


@internal
@view
def _to_added_assets_down(asset: IHub.Asset, shares: uint256) -> uint256:
    return SharesMath.to_assets_down(shares, self._total_added_assets(asset), convert(asset.addedShares, uint256))


@internal
@view
def _to_added_assets_up(asset: IHub.Asset, shares: uint256) -> uint256:
    return SharesMath.to_assets_up(shares, self._total_added_assets(asset), convert(asset.addedShares, uint256))


@internal
@view
def _drawn_rate(asset_id: uint256, asset: IHub.Asset, index: uint256) -> uint256:
    drawn: uint256 = WadRayMath.ray_mul_up(convert(asset.drawnShares, uint256), index)
    deficit: uint256 = WadRayMath.from_ray_up(convert(asset.deficitRay, uint256))
    return staticcall IInterestRateStrategy(asset.irStrategy).calculateInterestRate(asset_id, convert(asset.liquidity, uint256), drawn, deficit, convert(asset.swept, uint256))


@internal
def _accrue(asset_id: uint256):
    asset: IHub.Asset = self._load_asset(asset_id)
    if convert(asset.lastUpdateTimestamp, uint256) == block.timestamp:
        return
    index: uint256 = self._drawn_index(asset)
    asset.realizedFees = self._u120(convert(asset.realizedFees, uint256) + self._unrealized_fees(asset, index))
    asset.drawnIndex = self._u120(index)
    asset.lastUpdateTimestamp = self._u40(block.timestamp)
    self._store_asset(asset_id, asset)


@internal
def _update_rate(asset_id: uint256):
    asset: IHub.Asset = self._load_asset(asset_id)
    rate: uint256 = self._drawn_rate(asset_id, asset, convert(asset.drawnIndex, uint256))
    asset.drawnRate = self._u96(rate)
    self._store_asset(asset_id, asset)
    log IHub.UpdateAsset(assetId=asset_id, drawnIndex=convert(asset.drawnIndex, uint256), drawnRate=rate, accruedFees=convert(asset.realizedFees, uint256))


@internal
@view
def _spoke_drawn(asset: IHub.Asset, spoke: IHub.SpokeData) -> uint256:
    return WadRayMath.ray_mul_up(convert(spoke.drawnShares, uint256), self._drawn_index(asset))


@internal
@view
def _spoke_premium_ray(asset: IHub.Asset, spoke: IHub.SpokeData) -> uint256:
    return self._premium_ray(convert(spoke.premiumShares, uint256), convert(spoke.premiumOffsetRay, int256), self._drawn_index(asset))


@internal
def _add_spoke(asset_id: uint256, spoke: address):
    if self.spoke_listed[asset_id][spoke]:
        raise IHub.SpokeAlreadyListed()
    self.spoke_listed[asset_id][spoke] = True
    count: uint256 = convert(self.spoke_addresses[asset_id][SPOKE_COUNT_KEY], uint256)
    self.spoke_addresses[asset_id][count] = convert(spoke, bytes32)
    self.spoke_addresses[asset_id][SPOKE_COUNT_KEY] = convert(count + 1, bytes32)
    log IHub.AddSpoke(assetId=asset_id, spoke=spoke)


@internal
def _update_spoke_config(asset_id: uint256, spoke: address, config: IHub.SpokeConfig):
    data: IHub.SpokeData = self._load_spoke(asset_id, spoke)
    data.addCap = config.addCap
    data.drawCap = config.drawCap
    data.riskPremiumThreshold = config.riskPremiumThreshold
    data.active = config.active
    data.halted = config.halted
    self._store_spoke(asset_id, spoke, data)
    log IHub.UpdateSpokeConfig(assetId=asset_id, spoke=spoke, config=config)


@external
def initialize(authority: address):
    initialized: uint64 = convert(self.initialized_state & (2**64 - 1), uint64)
    if initialized >= HUB_REVISION:
        raise IHub.InvalidInitialization()
    if authority == empty(address):
        raise IHub.InvalidAddress()
    self.initialized_state = convert(HUB_REVISION, uint256)
    self.authority_address = authority
    log IHub.AuthorityUpdated(authority=authority)
    log IHub.Initialized(version=HUB_REVISION)


@external
@view
def authority() -> address:
    return self.authority_address


@external
def setAuthority(newAuthority: address):
    if msg.sender != self.authority_address:
        raise IHub.AccessManagedUnauthorized(msg.sender)
    self.authority_address = newAuthority
    log IHub.AuthorityUpdated(authority=newAuthority)


@external
@pure
def isConsumingScheduledOp() -> bytes4:
    return empty(bytes4)


@external
def addAsset(underlying: address, decimals: uint8, feeReceiver: address, irStrategy: address, irData: Bytes[INF]) -> uint256:
    self._check_access(method_id("addAsset(address,uint8,address,address,bytes)"))
    if underlying == empty(address) or feeReceiver == empty(address) or irStrategy == empty(address):
        raise IHub.InvalidAddress()
    if decimals < MIN_ALLOWED_UNDERLYING_DECIMALS or decimals > MAX_ALLOWED_UNDERLYING_DECIMALS:
        raise IHub.InvalidAssetDecimals()
    if self._load_asset(self.underlying_to_asset_id[underlying]).underlying == underlying:
        raise IHub.UnderlyingAlreadyListed()
    asset_id: uint256 = self.asset_count
    self.asset_count += 1
    self.underlying_to_asset_id[underlying] = asset_id
    extcall IInterestRateStrategy(irStrategy).setInterestRateData(asset_id, irData)
    rate: uint256 = staticcall IInterestRateStrategy(irStrategy).calculateInterestRate(asset_id, 0, 0, 0, 0)
    asset: IHub.Asset = IHub.Asset(
        liquidity=0, realizedFees=0, decimals=decimals, addedShares=0, swept=0,
        premiumOffsetRay=0, drawnShares=0, premiumShares=0, liquidityFee=0,
        drawnIndex=convert(RAY, uint120), drawnRate=self._u96(rate), lastUpdateTimestamp=self._u40(block.timestamp),
        underlying=underlying, irStrategy=irStrategy, reinvestmentController=empty(address), feeReceiver=feeReceiver, deficitRay=0,
    )
    self._store_asset(asset_id, asset)
    self._add_spoke(asset_id, feeReceiver)
    fee_config: IHub.SpokeConfig = IHub.SpokeConfig(addCap=MAX_ALLOWED_SPOKE_CAP, drawCap=0, riskPremiumThreshold=0, active=True, halted=False)
    self._update_spoke_config(asset_id, feeReceiver, fee_config)
    log IHub.AddAsset(assetId=asset_id, underlying=underlying, decimals=decimals)
    asset_config: IHub.AssetConfig = IHub.AssetConfig(feeReceiver=feeReceiver, liquidityFee=0, irStrategy=irStrategy, reinvestmentController=empty(address))
    log IHub.UpdateAssetConfig(assetId=asset_id, config=asset_config)
    log IHub.UpdateAsset(assetId=asset_id, drawnIndex=RAY, drawnRate=rate, accruedFees=0)
    return asset_id


@external
def addSpoke(assetId: uint256, spoke: address, config: IHub.SpokeConfig):
    self._check_access(method_id("addSpoke(uint256,address,(uint40,uint40,uint24,bool,bool))"))
    if assetId >= self.asset_count:
        raise IHub.AssetNotListed()
    if spoke == empty(address):
        raise IHub.InvalidAddress()
    self._add_spoke(assetId, spoke)
    self._update_spoke_config(assetId, spoke, config)


@external
def updateSpokeConfig(assetId: uint256, spoke: address, config: IHub.SpokeConfig):
    self._check_access(method_id("updateSpokeConfig(uint256,address,(uint40,uint40,uint24,bool,bool))"))
    if assetId >= self.asset_count:
        raise IHub.AssetNotListed()
    if not self.spoke_listed[assetId][spoke]:
        raise IHub.SpokeNotListed()
    self._update_spoke_config(assetId, spoke, config)


@internal
def _mint_fee_shares(asset_id: uint256) -> uint256:
    asset: IHub.Asset = self._load_asset(asset_id)
    fees: uint256 = convert(asset.realizedFees, uint256)
    shares: uint256 = self._to_added_shares_down(asset, fees)
    if shares == 0:
        return 0
    receiver: IHub.SpokeData = self._load_spoke(asset_id, asset.feeReceiver)
    if not receiver.active:
        raise IHub.SpokeNotActive()
    asset.addedShares = self._u120(convert(asset.addedShares, uint256) + shares)
    receiver.addedShares = self._u120(convert(receiver.addedShares, uint256) + shares)
    asset.realizedFees = 0
    self._store_asset(asset_id, asset)
    self._store_spoke(asset_id, asset.feeReceiver, receiver)
    log IHub.MintFeeShares(assetId=asset_id, feeReceiver=asset.feeReceiver, shares=shares, assets=fees)
    return shares


@external
def updateAssetConfig(assetId: uint256, config: IHub.AssetConfig, irData: Bytes[INF]):
    self._check_access(method_id("updateAssetConfig(uint256,(address,uint16,address,address),bytes)"))
    if assetId >= self.asset_count:
        raise IHub.AssetNotListed()
    self._accrue(assetId)
    asset: IHub.Asset = self._load_asset(assetId)
    if convert(config.liquidityFee, uint256) > PERCENTAGE_FACTOR:
        raise IHub.InvalidLiquidityFee()
    if config.feeReceiver == empty(address) or config.irStrategy == empty(address):
        raise IHub.InvalidAddress()
    if config.reinvestmentController == empty(address) and asset.swept != 0:
        raise IHub.InvalidReinvestmentController()
    asset.liquidityFee = config.liquidityFee
    asset.reinvestmentController = config.reinvestmentController
    old_receiver: address = asset.feeReceiver
    self._store_asset(assetId, asset)
    if old_receiver != config.feeReceiver:
        self._mint_fee_shares(assetId)
        old_config: IHub.SpokeConfig = IHub.SpokeConfig(
            addCap=0,
            drawCap=0,
            riskPremiumThreshold=0,
            active=self._load_spoke(assetId, old_receiver).active,
            halted=self._load_spoke(assetId, old_receiver).halted,
        )
        self._update_spoke_config(assetId, old_receiver, old_config)
        asset = self._load_asset(assetId)
        asset.feeReceiver = config.feeReceiver
        self._store_asset(assetId, asset)
        self._add_spoke(assetId, config.feeReceiver)
        fee_config: IHub.SpokeConfig = IHub.SpokeConfig(addCap=MAX_ALLOWED_SPOKE_CAP, drawCap=0, riskPremiumThreshold=0, active=True, halted=False)
        self._update_spoke_config(assetId, config.feeReceiver, fee_config)
    asset = self._load_asset(assetId)
    if config.irStrategy != asset.irStrategy:
        asset.irStrategy = config.irStrategy
        self._store_asset(assetId, asset)
        extcall IInterestRateStrategy(config.irStrategy).setInterestRateData(assetId, irData)
    elif len(irData) != 0:
        raise IHub.InvalidInterestRateStrategy()
    self._update_rate(assetId)
    log IHub.UpdateAssetConfig(assetId=assetId, config=config)


@external
def setInterestRateData(assetId: uint256, irData: Bytes[INF]):
    self._check_access(method_id("setInterestRateData(uint256,bytes)"))
    if assetId >= self.asset_count:
        raise IHub.AssetNotListed()
    self._accrue(assetId)
    extcall IInterestRateStrategy(self._load_asset(assetId).irStrategy).setInterestRateData(assetId, irData)
    self._update_rate(assetId)


@external
def mintFeeShares(assetId: uint256) -> uint256:
    self._check_access(method_id("mintFeeShares(uint256)"))
    if assetId >= self.asset_count:
        raise IHub.AssetNotListed()
    self._accrue(assetId)
    result: uint256 = self._mint_fee_shares(assetId)
    self._update_rate(assetId)
    return result


@internal
@view
def _asset_units(decimals: uint8) -> uint256:
    return MathUtils.unchecked_exp(10, convert(decimals, uint256))


@external
def add(assetId: uint256, amount: uint256) -> uint256:
    self._accrue(assetId)
    asset: IHub.Asset = self._load_asset(assetId)
    spoke: IHub.SpokeData = self._load_spoke(assetId, msg.sender)
    if amount == 0:
        raise IHub.InvalidAmount()
    if not spoke.active:
        raise IHub.SpokeNotActive()
    if spoke.halted:
        raise IHub.SpokeHalted()
    if spoke.addCap != MAX_ALLOWED_SPOKE_CAP:
        cap: uint256 = convert(spoke.addCap, uint256) * self._asset_units(asset.decimals)
        required: uint256 = self._to_added_assets_up(asset, convert(spoke.addedShares, uint256)) + amount
        if cap < required:
            raise IHub.AddCapExceeded(convert(spoke.addCap, uint256))
    liquidity: uint256 = convert(asset.liquidity, uint256) + amount
    balance: uint256 = staticcall IERC20(asset.underlying).balanceOf(self)
    if balance < liquidity:
        raise IHub.InsufficientTransferred(liquidity - balance)
    shares: uint256 = self._to_added_shares_down(asset, amount)
    if shares == 0:
        raise IHub.InvalidShares()
    asset.addedShares = self._u120(convert(asset.addedShares, uint256) + shares)
    spoke.addedShares = self._u120(convert(spoke.addedShares, uint256) + shares)
    asset.liquidity = self._u120(liquidity)
    self._store_asset(assetId, asset)
    self._store_spoke(assetId, msg.sender, spoke)
    self._update_rate(assetId)
    log IHub.Add(assetId=assetId, spoke=msg.sender, shares=shares, amount=amount)
    return shares


@external
def remove(assetId: uint256, amount: uint256, to: address) -> uint256:
    self._accrue(assetId)
    asset: IHub.Asset = self._load_asset(assetId)
    spoke: IHub.SpokeData = self._load_spoke(assetId, msg.sender)
    if to == self:
        raise IHub.InvalidAddress()
    if amount == 0:
        raise IHub.InvalidAmount()
    if not spoke.active:
        raise IHub.SpokeNotActive()
    if spoke.halted:
        raise IHub.SpokeHalted()
    if amount > convert(asset.liquidity, uint256):
        raise IHub.InsufficientLiquidity(convert(asset.liquidity, uint256))
    shares: uint256 = self._to_added_shares_up(asset, amount)
    shares_120: uint120 = self._u120(shares)
    if shares_120 > asset.addedShares or shares_120 > spoke.addedShares:
        self._panic_arithmetic()
    asset.addedShares -= shares_120
    spoke.addedShares -= shares_120
    asset.liquidity = self._u120(convert(asset.liquidity, uint256) - amount)
    self._store_asset(assetId, asset)
    self._store_spoke(assetId, msg.sender, spoke)
    self._update_rate(assetId)
    self._safe_transfer(asset.underlying, to, amount)
    log IHub.Remove(assetId=assetId, spoke=msg.sender, shares=shares, amount=amount)
    return shares


@external
def draw(assetId: uint256, amount: uint256, to: address) -> uint256:
    self._accrue(assetId)
    asset: IHub.Asset = self._load_asset(assetId)
    spoke: IHub.SpokeData = self._load_spoke(assetId, msg.sender)
    if to == self:
        raise IHub.InvalidAddress()
    if amount == 0:
        raise IHub.InvalidAmount()
    if not spoke.active:
        raise IHub.SpokeNotActive()
    if spoke.halted:
        raise IHub.SpokeHalted()
    if spoke.drawCap != MAX_ALLOWED_SPOKE_CAP:
        owed: uint256 = self._spoke_drawn(asset, spoke) + WadRayMath.from_ray_up(self._spoke_premium_ray(asset, spoke)) + WadRayMath.from_ray_up(convert(spoke.deficitRay, uint256))
        cap: uint256 = convert(spoke.drawCap, uint256) * self._asset_units(asset.decimals)
        if cap < owed + amount:
            raise IHub.DrawCapExceeded(convert(spoke.drawCap, uint256))
    if amount > convert(asset.liquidity, uint256):
        raise IHub.InsufficientLiquidity(convert(asset.liquidity, uint256))
    shares: uint256 = WadRayMath.ray_div_up(amount, convert(asset.drawnIndex, uint256))
    asset.drawnShares = self._u120(convert(asset.drawnShares, uint256) + shares)
    spoke.drawnShares = self._u120(convert(spoke.drawnShares, uint256) + shares)
    asset.liquidity = self._u120(convert(asset.liquidity, uint256) - amount)
    self._store_asset(assetId, asset)
    self._store_spoke(assetId, msg.sender, spoke)
    self._update_rate(assetId)
    self._safe_transfer(asset.underlying, to, amount)
    log IHub.Draw(assetId=assetId, spoke=msg.sender, drawnShares=shares, drawnAmount=amount)
    return shares


@internal
@pure
def _apply_one(index: uint256, shares: uint256, offset: int256, delta: IHub.PremiumDelta) -> (uint120, int200):
    before: uint256 = Premium.calculate_premium_ray(shares, offset, index)
    new_shares: uint256 = MathUtils.add_signed(shares, delta.sharesDelta)
    new_offset: int256 = offset + delta.offsetRayDelta
    after: uint256 = Premium.calculate_premium_ray(new_shares, new_offset, index)
    if after + delta.restoredPremiumRay != before:
        raise IHub.InvalidPremiumChange()
    if new_shares > convert(max_value(uint120), uint256):
        raise IHub.SafeCastOverflowedUintDowncast(120, new_shares)
    if new_offset > convert(max_value(int200), int256) or new_offset < convert(min_value(int200), int256):
        raise IHub.SafeCastOverflowedIntDowncast(200, new_offset)
    return convert(new_shares, uint120), convert(new_offset, int200)


@internal
def _apply_premium(asset_id: uint256, spoke_address: address, delta: IHub.PremiumDelta):
    asset: IHub.Asset = self._load_asset(asset_id)
    spoke: IHub.SpokeData = self._load_spoke(asset_id, spoke_address)
    asset.premiumShares, asset.premiumOffsetRay = self._apply_one(convert(asset.drawnIndex, uint256), convert(asset.premiumShares, uint256), convert(asset.premiumOffsetRay, int256), delta)
    spoke.premiumShares, spoke.premiumOffsetRay = self._apply_one(convert(asset.drawnIndex, uint256), convert(spoke.premiumShares, uint256), convert(spoke.premiumOffsetRay, int256), delta)
    if spoke.riskPremiumThreshold != MAX_RISK_PREMIUM_THRESHOLD:
        maximum: uint256 = PercentageMath.percent_mul_up(convert(spoke.drawnShares, uint256), convert(spoke.riskPremiumThreshold, uint256))
        if convert(spoke.premiumShares, uint256) > maximum:
            raise IHub.InvalidPremiumChange()
    self._store_asset(asset_id, asset)
    self._store_spoke(asset_id, spoke_address, spoke)


@external
def restore(assetId: uint256, drawnAmount: uint256, premiumDelta: IHub.PremiumDelta) -> uint256:
    self._accrue(assetId)
    asset: IHub.Asset = self._load_asset(assetId)
    spoke: IHub.SpokeData = self._load_spoke(assetId, msg.sender)
    if drawnAmount == 0 and premiumDelta.restoredPremiumRay == 0:
        raise IHub.InvalidAmount()
    if not spoke.active:
        raise IHub.SpokeNotActive()
    if spoke.halted:
        raise IHub.SpokeHalted()
    drawn: uint256 = self._spoke_drawn(asset, spoke)
    premium_ray: uint256 = self._spoke_premium_ray(asset, spoke)
    if drawnAmount > drawn:
        raise IHub.SurplusDrawnRestored(drawn)
    if premiumDelta.restoredPremiumRay > premium_ray:
        raise IHub.SurplusPremiumRayRestored(premium_ray)
    shares: uint256 = WadRayMath.ray_div_down(drawnAmount, convert(asset.drawnIndex, uint256))
    asset.drawnShares = self._u120(convert(asset.drawnShares, uint256) - shares)
    spoke.drawnShares = self._u120(convert(spoke.drawnShares, uint256) - shares)
    self._store_asset(assetId, asset)
    self._store_spoke(assetId, msg.sender, spoke)
    self._apply_premium(assetId, msg.sender, premiumDelta)
    asset = self._load_asset(assetId)
    premium_amount: uint256 = WadRayMath.from_ray_up(premiumDelta.restoredPremiumRay)
    liquidity: uint256 = convert(asset.liquidity, uint256) + drawnAmount + premium_amount
    balance: uint256 = staticcall IERC20(asset.underlying).balanceOf(self)
    if balance < liquidity:
        raise IHub.InsufficientTransferred(liquidity - balance)
    asset.liquidity = self._u120(liquidity)
    self._store_asset(assetId, asset)
    self._update_rate(assetId)
    log IHub.Restore(assetId=assetId, spoke=msg.sender, drawnShares=shares, premiumDelta=premiumDelta, drawnAmount=drawnAmount, premiumAmount=premium_amount)
    return shares


@external
def reportDeficit(assetId: uint256, drawnAmount: uint256, premiumDelta: IHub.PremiumDelta) -> (uint256, uint256):
    self._accrue(assetId)
    asset: IHub.Asset = self._load_asset(assetId)
    spoke: IHub.SpokeData = self._load_spoke(assetId, msg.sender)
    if drawnAmount == 0 and premiumDelta.restoredPremiumRay == 0:
        raise IHub.InvalidAmount()
    if not spoke.active:
        raise IHub.SpokeNotActive()
    drawn: uint256 = self._spoke_drawn(asset, spoke)
    premium_ray: uint256 = self._spoke_premium_ray(asset, spoke)
    if drawnAmount > drawn:
        raise IHub.SurplusDrawnDeficitReported(drawn)
    if premiumDelta.restoredPremiumRay > premium_ray:
        raise IHub.SurplusPremiumRayDeficitReported(premium_ray)
    shares: uint256 = WadRayMath.ray_div_down(drawnAmount, convert(asset.drawnIndex, uint256))
    asset.drawnShares = self._u120(convert(asset.drawnShares, uint256) - shares)
    spoke.drawnShares = self._u120(convert(spoke.drawnShares, uint256) - shares)
    self._store_asset(assetId, asset)
    self._store_spoke(assetId, msg.sender, spoke)
    self._apply_premium(assetId, msg.sender, premiumDelta)
    asset = self._load_asset(assetId)
    spoke = self._load_spoke(assetId, msg.sender)
    deficit_ray: uint256 = shares * convert(asset.drawnIndex, uint256) + premiumDelta.restoredPremiumRay
    asset.deficitRay = self._u200(convert(asset.deficitRay, uint256) + deficit_ray)
    spoke.deficitRay = self._u200(convert(spoke.deficitRay, uint256) + deficit_ray)
    self._store_asset(assetId, asset)
    self._store_spoke(assetId, msg.sender, spoke)
    self._update_rate(assetId)
    log IHub.ReportDeficit(assetId=assetId, spoke=msg.sender, drawnShares=shares, premiumDelta=premiumDelta, deficitAmountRay=deficit_ray)
    return shares, WadRayMath.from_ray_up(deficit_ray)


@external
def refreshPremium(assetId: uint256, premiumDelta: IHub.PremiumDelta):
    self._accrue(assetId)
    if not self._load_spoke(assetId, msg.sender).active:
        raise IHub.SpokeNotActive()
    if premiumDelta.restoredPremiumRay != 0:
        raise IHub.InvalidPremiumChange()
    self._apply_premium(assetId, msg.sender, premiumDelta)
    self._update_rate(assetId)
    log IHub.RefreshPremium(assetId=assetId, spoke=msg.sender, premiumDelta=premiumDelta)


@external
def eliminateDeficit(assetId: uint256, amount: uint256, coveredSpoke: address) -> (uint256, uint256):
    self._check_access(method_id("eliminateDeficit(uint256,uint256,address)"))
    self._accrue(assetId)
    asset: IHub.Asset = self._load_asset(assetId)
    caller: IHub.SpokeData = self._load_spoke(assetId, msg.sender)
    covered: IHub.SpokeData = self._load_spoke(assetId, coveredSpoke)
    covered_deficit_ray: uint256 = convert(covered.deficitRay, uint256)
    deficit_ray: uint256 = covered_deficit_ray
    if amount < WadRayMath.from_ray_up(covered_deficit_ray):
        deficit_ray = WadRayMath.to_ray(amount)
    if not caller.active:
        raise IHub.SpokeNotActive()
    if deficit_ray == 0:
        raise IHub.InvalidAmount()
    deficit_amount: uint256 = WadRayMath.from_ray_up(deficit_ray)
    shares: uint256 = self._to_added_shares_up(asset, deficit_amount)
    shares_120: uint120 = self._u120(shares)
    if shares_120 > asset.addedShares or shares_120 > caller.addedShares:
        self._panic_arithmetic()
    asset.addedShares -= shares_120
    caller.addedShares -= shares_120
    asset.deficitRay = self._u200(convert(asset.deficitRay, uint256) - deficit_ray)
    covered.deficitRay = self._u200(convert(covered.deficitRay, uint256) - deficit_ray)
    self._store_asset(assetId, asset)
    self._store_spoke(assetId, msg.sender, caller)
    self._store_spoke(assetId, coveredSpoke, covered)
    self._update_rate(assetId)
    log IHub.EliminateDeficit(assetId=assetId, callerSpoke=msg.sender, coveredSpoke=coveredSpoke, shares=shares, deficitAmountRay=deficit_ray)
    return shares, deficit_amount


@external
def payFeeShares(assetId: uint256, shares: uint256):
    self._accrue(assetId)
    asset: IHub.Asset = self._load_asset(assetId)
    sender: IHub.SpokeData = self._load_spoke(assetId, msg.sender)
    receiver: IHub.SpokeData = self._load_spoke(assetId, asset.feeReceiver)
    if not sender.active:
        raise IHub.SpokeNotActive()
    if shares == 0:
        raise IHub.InvalidShares()
    shares_120: uint120 = self._u120(shares)
    if shares_120 > sender.addedShares:
        self._panic_arithmetic()
    if convert(receiver.addedShares, uint256) + shares > convert(max_value(uint120), uint256):
        self._panic_arithmetic()
    sender.addedShares -= shares_120
    receiver.addedShares += shares_120
    self._store_spoke(assetId, msg.sender, sender)
    self._store_spoke(assetId, asset.feeReceiver, receiver)
    self._update_rate(assetId)
    log IHub.TransferShares(assetId=assetId, sender=msg.sender, receiver=asset.feeReceiver, shares=shares)


@external
def transferShares(assetId: uint256, shares: uint256, toSpoke: address):
    self._accrue(assetId)
    asset: IHub.Asset = self._load_asset(assetId)
    sender: IHub.SpokeData = self._load_spoke(assetId, msg.sender)
    receiver: IHub.SpokeData = self._load_spoke(assetId, toSpoke)
    if not sender.active or not receiver.active:
        raise IHub.SpokeNotActive()
    if sender.halted or receiver.halted:
        raise IHub.SpokeHalted()
    if shares == 0:
        raise IHub.InvalidShares()
    if receiver.addCap != MAX_ALLOWED_SPOKE_CAP:
        cap: uint256 = convert(receiver.addCap, uint256) * self._asset_units(asset.decimals)
        required: uint256 = self._to_added_assets_up(asset, convert(receiver.addedShares, uint256) + shares)
        if cap < required:
            raise IHub.AddCapExceeded(convert(receiver.addCap, uint256))
    shares_120: uint120 = self._u120(shares)
    if shares_120 > sender.addedShares:
        self._panic_arithmetic()
    if convert(receiver.addedShares, uint256) + shares > convert(max_value(uint120), uint256):
        self._panic_arithmetic()
    sender.addedShares -= shares_120
    receiver.addedShares += shares_120
    self._store_spoke(assetId, msg.sender, sender)
    self._store_spoke(assetId, toSpoke, receiver)
    self._update_rate(assetId)
    log IHub.TransferShares(assetId=assetId, sender=msg.sender, receiver=toSpoke, shares=shares)


@external
def sweep(assetId: uint256, amount: uint256):
    if assetId >= self.asset_count:
        raise IHub.AssetNotListed()
    self._accrue(assetId)
    asset: IHub.Asset = self._load_asset(assetId)
    if msg.sender != asset.reinvestmentController:
        raise IHub.OnlyReinvestmentController()
    if amount == 0:
        raise IHub.InvalidAmount()
    if amount > convert(asset.liquidity, uint256):
        raise IHub.InsufficientLiquidity(convert(asset.liquidity, uint256))
    asset.liquidity = self._u120(convert(asset.liquidity, uint256) - amount)
    asset.swept = self._u120(convert(asset.swept, uint256) + amount)
    self._store_asset(assetId, asset)
    self._update_rate(assetId)
    self._safe_transfer(asset.underlying, msg.sender, amount)
    log IHub.Sweep(assetId=assetId, reinvestmentController=msg.sender, amount=amount)


@external
def reclaim(assetId: uint256, amount: uint256):
    if assetId >= self.asset_count:
        raise IHub.AssetNotListed()
    self._accrue(assetId)
    asset: IHub.Asset = self._load_asset(assetId)
    if msg.sender != asset.reinvestmentController:
        raise IHub.OnlyReinvestmentController()
    if amount == 0:
        raise IHub.InvalidAmount()
    liquidity: uint256 = convert(asset.liquidity, uint256) + amount
    balance: uint256 = staticcall IERC20(asset.underlying).balanceOf(self)
    if balance < liquidity:
        raise IHub.InsufficientTransferred(liquidity - balance)
    asset.liquidity = self._u120(liquidity)
    amount_120: uint120 = self._u120(amount)
    if amount_120 > asset.swept:
        self._panic_arithmetic()
    asset.swept -= amount_120
    self._store_asset(assetId, asset)
    self._update_rate(assetId)
    log IHub.Reclaim(assetId=assetId, reinvestmentController=msg.sender, amount=amount)


@external
@view
def isUnderlyingListed(underlying: address) -> bool:
    return self._load_asset(self.underlying_to_asset_id[underlying]).underlying == underlying


@external
@view
def getAssetCount() -> uint256:
    return self.asset_count


@external
@view
def previewAddByAssets(assetId: uint256, amount: uint256) -> uint256:
    return self._to_added_shares_down(self._load_asset(assetId), amount)


@external
@view
def previewAddByShares(assetId: uint256, shares: uint256) -> uint256:
    return self._to_added_assets_up(self._load_asset(assetId), shares)


@external
@view
def previewRemoveByAssets(assetId: uint256, amount: uint256) -> uint256:
    return self._to_added_shares_up(self._load_asset(assetId), amount)


@external
@view
def previewRemoveByShares(assetId: uint256, shares: uint256) -> uint256:
    return self._to_added_assets_down(self._load_asset(assetId), shares)


@external
@view
def previewDrawByAssets(assetId: uint256, amount: uint256) -> uint256:
    return WadRayMath.ray_div_up(amount, self._drawn_index(self._load_asset(assetId)))


@external
@view
def previewDrawByShares(assetId: uint256, shares: uint256) -> uint256:
    return WadRayMath.ray_mul_down(shares, self._drawn_index(self._load_asset(assetId)))


@external
@view
def previewRestoreByAssets(assetId: uint256, amount: uint256) -> uint256:
    return WadRayMath.ray_div_down(amount, self._drawn_index(self._load_asset(assetId)))


@external
@view
def previewRestoreByShares(assetId: uint256, shares: uint256) -> uint256:
    return WadRayMath.ray_mul_up(shares, self._drawn_index(self._load_asset(assetId)))


@external
@view
def getAssetId(underlying: address) -> uint256:
    asset_id: uint256 = self.underlying_to_asset_id[underlying]
    if self._load_asset(asset_id).underlying != underlying:
        raise IHub.AssetNotListed()
    return asset_id


@external
@view
def getAssetUnderlyingAndDecimals(assetId: uint256) -> (address, uint8):
    asset: IHub.Asset = self._load_asset(assetId)
    return asset.underlying, asset.decimals


@external
@view
def getAssetDrawnIndex(assetId: uint256) -> uint256:
    return self._drawn_index(self._load_asset(assetId))


@external
@view
def getAddedAssets(assetId: uint256) -> uint256:
    return self._total_added_assets(self._load_asset(assetId))


@external
@view
def getAddedShares(assetId: uint256) -> uint256:
    return convert(self._load_asset(assetId).addedShares, uint256)


@external
@view
def getAssetOwed(assetId: uint256) -> (uint256, uint256):
    asset: IHub.Asset = self._load_asset(assetId)
    index: uint256 = self._drawn_index(asset)
    return WadRayMath.ray_mul_up(convert(asset.drawnShares, uint256), index), WadRayMath.from_ray_up(self._premium_ray(convert(asset.premiumShares, uint256), convert(asset.premiumOffsetRay, int256), index))


@external
@view
def getAssetTotalOwed(assetId: uint256) -> uint256:
    asset: IHub.Asset = self._load_asset(assetId)
    index: uint256 = self._drawn_index(asset)
    return WadRayMath.ray_mul_up(convert(asset.drawnShares, uint256), index) + WadRayMath.from_ray_up(self._premium_ray(convert(asset.premiumShares, uint256), convert(asset.premiumOffsetRay, int256), index))


@external
@view
def getAssetPremiumRay(assetId: uint256) -> uint256:
    asset: IHub.Asset = self._load_asset(assetId)
    return self._premium_ray(convert(asset.premiumShares, uint256), convert(asset.premiumOffsetRay, int256), self._drawn_index(asset))


@external
@view
def getAssetDrawnShares(assetId: uint256) -> uint256:
    return convert(self._load_asset(assetId).drawnShares, uint256)


@external
@view
def getAssetPremiumData(assetId: uint256) -> (uint256, int256):
    asset: IHub.Asset = self._load_asset(assetId)
    return convert(asset.premiumShares, uint256), convert(asset.premiumOffsetRay, int256)


@external
@view
def getAssetLiquidity(assetId: uint256) -> uint256:
    return convert(self._load_asset(assetId).liquidity, uint256)


@external
@view
def getAssetDeficitRay(assetId: uint256) -> uint256:
    return convert(self._load_asset(assetId).deficitRay, uint256)


@external
@view
def getAsset(assetId: uint256) -> IHub.Asset:
    return self._load_asset(assetId)


@external
@view
def getAssetConfig(assetId: uint256) -> IHub.AssetConfig:
    asset: IHub.Asset = self._load_asset(assetId)
    return IHub.AssetConfig(feeReceiver=asset.feeReceiver, liquidityFee=asset.liquidityFee, irStrategy=asset.irStrategy, reinvestmentController=asset.reinvestmentController)


@external
@view
def getAssetAccruedFees(assetId: uint256) -> uint256:
    asset: IHub.Asset = self._load_asset(assetId)
    return convert(asset.realizedFees, uint256) + self._unrealized_fees(asset, self._drawn_index(asset))


@external
@view
def getAssetSwept(assetId: uint256) -> uint256:
    return convert(self._load_asset(assetId).swept, uint256)


@external
@view
def getAssetDrawnRate(assetId: uint256) -> uint256:
    asset: IHub.Asset = self._load_asset(assetId)
    return self._drawn_rate(assetId, asset, self._drawn_index(asset))


@external
@view
def getSpokeCount(assetId: uint256) -> uint256:
    return convert(self.spoke_addresses[assetId][SPOKE_COUNT_KEY], uint256)


@external
@view
def getSpokeAddedAssets(assetId: uint256, spoke: address) -> uint256:
    return self._to_added_assets_down(self._load_asset(assetId), convert(self._load_spoke(assetId, spoke).addedShares, uint256))


@external
@view
def getSpokeAddedShares(assetId: uint256, spoke: address) -> uint256:
    return convert(self._load_spoke(assetId, spoke).addedShares, uint256)


@external
@view
def getSpokeOwed(assetId: uint256, spoke: address) -> (uint256, uint256):
    asset: IHub.Asset = self._load_asset(assetId)
    data: IHub.SpokeData = self._load_spoke(assetId, spoke)
    return self._spoke_drawn(asset, data), WadRayMath.from_ray_up(self._spoke_premium_ray(asset, data))


@external
@view
def getSpokeTotalOwed(assetId: uint256, spoke: address) -> uint256:
    asset: IHub.Asset = self._load_asset(assetId)
    data: IHub.SpokeData = self._load_spoke(assetId, spoke)
    return self._spoke_drawn(asset, data) + WadRayMath.from_ray_up(self._spoke_premium_ray(asset, data))


@external
@view
def getSpokePremiumRay(assetId: uint256, spoke: address) -> uint256:
    return self._spoke_premium_ray(self._load_asset(assetId), self._load_spoke(assetId, spoke))


@external
@view
def getSpokeDrawnShares(assetId: uint256, spoke: address) -> uint256:
    return convert(self._load_spoke(assetId, spoke).drawnShares, uint256)


@external
@view
def getSpokePremiumData(assetId: uint256, spoke: address) -> (uint256, int256):
    data: IHub.SpokeData = self._load_spoke(assetId, spoke)
    return convert(data.premiumShares, uint256), convert(data.premiumOffsetRay, int256)


@external
@view
def getSpokeDeficitRay(assetId: uint256, spoke: address) -> uint256:
    return convert(self._load_spoke(assetId, spoke).deficitRay, uint256)


@external
@view
def isSpokeListed(assetId: uint256, spoke: address) -> bool:
    return self.spoke_listed[assetId][spoke]


@external
@view
def getSpokeAddress(assetId: uint256, index: uint256) -> address:
    return convert(self.spoke_addresses[assetId][index], address)


@external
@view
def getSpoke(assetId: uint256, spoke: address) -> IHub.SpokeData:
    return self._load_spoke(assetId, spoke)


@external
@view
def getSpokeConfig(assetId: uint256, spoke: address) -> IHub.SpokeConfig:
    data: IHub.SpokeData = self._load_spoke(assetId, spoke)
    return IHub.SpokeConfig(addCap=data.addCap, drawCap=data.drawCap, riskPremiumThreshold=data.riskPremiumThreshold, active=data.active, halted=data.halted)


@external
def setAssetAddedShares(assetId: uint256, addedShares: uint256):
    asset: IHub.Asset = self._load_asset(assetId)
    asset.addedShares = self._u120(addedShares)
    self._store_asset(assetId, asset)
