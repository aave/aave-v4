# pragma version 0.5.0b1


error AccessManagedUnauthorized:
    arg0: address

error InvalidAddress:
    pass

error MismatchedConfigs:
    pass

error SafeCastOverflowedUintDowncast:
    arg0: uint8
    arg1: uint256

struct AssetConfig:
    feeReceiver: address
    liquidityFee: uint16
    irStrategy: address
    reinvestmentController: address

struct SpokeConfig:
    addCap: uint40
    drawCap: uint40
    riskPremiumThreshold: uint24
    active: bool
    halted: bool

interface IAuthority:
    def canCall(caller: address, target: address, selector: bytes4) -> (bool, uint32): view

interface IERC20Metadata:
    def decimals() -> uint8: view

interface IHub:
    def addAsset(underlying: address, decimals: uint8, feeReceiver: address, irStrategy: address, irData: Bytes[INF]) -> uint256: nonpayable
    def updateAssetConfig(assetId: uint256, config: AssetConfig, irData: Bytes[INF]): nonpayable
    def getAssetConfig(assetId: uint256) -> AssetConfig: view
    def getSpokeCount(assetId: uint256) -> uint256: view
    def getSpokeAddress(assetId: uint256, index: uint256) -> address: view
    def getSpokeConfig(assetId: uint256, spoke: address) -> SpokeConfig: view
    def updateSpokeConfig(assetId: uint256, spoke: address, config: SpokeConfig): nonpayable
    def addSpoke(assetId: uint256, spoke: address, config: SpokeConfig): nonpayable
    def getAssetCount() -> uint256: view
    def isSpokeListed(assetId: uint256, spoke: address) -> bool: view
    def setInterestRateData(assetId: uint256, irData: Bytes[INF]): nonpayable


event AuthorityUpdated:
    authority: address


MAX_ITEMS: constant(uint256) = 256
authority_address: address


@deploy
def __init__(authority_: address):
    if authority_ == empty(address):
        raise InvalidAddress()
    self.authority_address = authority_
    log AuthorityUpdated(authority=authority_)


@internal
@view
def _check_access(selector: Bytes[4]):
    allowed: bool = False
    delay: uint32 = 0
    allowed, delay = staticcall IAuthority(self.authority_address).canCall(msg.sender, self, convert(selector, bytes4))
    if not allowed:
        raise AccessManagedUnauthorized(msg.sender)


@internal
@pure
def _u16(cast_value: uint256) -> uint16:
    if cast_value > convert(max_value(uint16), uint256):
        raise SafeCastOverflowedUintDowncast(16, cast_value)
    return convert(cast_value, uint16)


@internal
@pure
def _u40(cast_value: uint256) -> uint40:
    if cast_value > convert(max_value(uint40), uint256):
        raise SafeCastOverflowedUintDowncast(40, cast_value)
    return convert(cast_value, uint40)


@internal
@pure
def _u24(cast_value: uint256) -> uint24:
    if cast_value > convert(max_value(uint24), uint256):
        raise SafeCastOverflowedUintDowncast(24, cast_value)
    return convert(cast_value, uint24)


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


@internal
def _update_liquidity_fee(hub: address, asset_id: uint256, liquidity_fee: uint256):
    config: AssetConfig = staticcall IHub(hub).getAssetConfig(asset_id)
    config.liquidityFee = self._u16(liquidity_fee)
    extcall IHub(hub).updateAssetConfig(asset_id, config, b"")


@external
def addAsset(hub: address, underlying: address, feeReceiver: address, liquidityFee: uint256, irStrategy: address, irData: Bytes[INF]) -> uint256:
    self._check_access(method_id("addAsset(address,address,address,uint256,address,bytes)"))
    decimals: uint8 = staticcall IERC20Metadata(underlying).decimals()
    asset_id: uint256 = extcall IHub(hub).addAsset(underlying, decimals, feeReceiver, irStrategy, irData)
    self._update_liquidity_fee(hub, asset_id, liquidityFee)
    return asset_id


@external
def addAssetWithDecimals(hub: address, underlying: address, decimals: uint8, feeReceiver: address, liquidityFee: uint256, irStrategy: address, irData: Bytes[INF]) -> uint256:
    self._check_access(method_id("addAssetWithDecimals(address,address,uint8,address,uint256,address,bytes)"))
    asset_id: uint256 = extcall IHub(hub).addAsset(underlying, decimals, feeReceiver, irStrategy, irData)
    self._update_liquidity_fee(hub, asset_id, liquidityFee)
    return asset_id


@external
def updateLiquidityFee(hub: address, assetId: uint256, liquidityFee: uint256):
    self._check_access(method_id("updateLiquidityFee(address,uint256,uint256)"))
    self._update_liquidity_fee(hub, assetId, liquidityFee)


@external
def updateFeeReceiver(hub: address, assetId: uint256, feeReceiver: address):
    self._check_access(method_id("updateFeeReceiver(address,uint256,address)"))
    config: AssetConfig = staticcall IHub(hub).getAssetConfig(assetId)
    config.feeReceiver = feeReceiver
    extcall IHub(hub).updateAssetConfig(assetId, config, b"")


@external
def updateFeeConfig(hub: address, assetId: uint256, liquidityFee: uint256, feeReceiver: address):
    self._check_access(method_id("updateFeeConfig(address,uint256,uint256,address)"))
    config: AssetConfig = staticcall IHub(hub).getAssetConfig(assetId)
    config.liquidityFee = self._u16(liquidityFee)
    config.feeReceiver = feeReceiver
    extcall IHub(hub).updateAssetConfig(assetId, config, b"")


@external
def updateInterestRateStrategy(hub: address, assetId: uint256, irStrategy: address, irData: Bytes[INF]):
    self._check_access(method_id("updateInterestRateStrategy(address,uint256,address,bytes)"))
    config: AssetConfig = staticcall IHub(hub).getAssetConfig(assetId)
    config.irStrategy = irStrategy
    extcall IHub(hub).updateAssetConfig(assetId, config, irData)


@external
def updateReinvestmentController(hub: address, assetId: uint256, reinvestmentController: address):
    self._check_access(method_id("updateReinvestmentController(address,uint256,address)"))
    config: AssetConfig = staticcall IHub(hub).getAssetConfig(assetId)
    config.reinvestmentController = reinvestmentController
    extcall IHub(hub).updateAssetConfig(assetId, config, b"")


@internal
def _reset_asset(hub: address, asset_id: uint256, action: uint256):
    count: uint256 = staticcall IHub(hub).getSpokeCount(asset_id)
    for i: uint256 in range(MAX_ITEMS):
        if i >= count:
            break
        spoke: address = staticcall IHub(hub).getSpokeAddress(asset_id, i)
        config: SpokeConfig = staticcall IHub(hub).getSpokeConfig(asset_id, spoke)
        if action == 0:
            config.addCap = 0
            config.drawCap = 0
        elif action == 1:
            config.active = False
        else:
            config.halted = True
        extcall IHub(hub).updateSpokeConfig(asset_id, spoke, config)


@external
def resetAssetCaps(hub: address, assetId: uint256):
    self._check_access(method_id("resetAssetCaps(address,uint256)"))
    self._reset_asset(hub, assetId, 0)


@external
def deactivateAsset(hub: address, assetId: uint256):
    self._check_access(method_id("deactivateAsset(address,uint256)"))
    self._reset_asset(hub, assetId, 1)


@external
def haltAsset(hub: address, assetId: uint256):
    self._check_access(method_id("haltAsset(address,uint256)"))
    self._reset_asset(hub, assetId, 2)


@external
def addSpoke(hub: address, spoke: address, assetId: uint256, config: SpokeConfig):
    self._check_access(method_id("addSpoke(address,address,uint256,(uint40,uint40,uint24,bool,bool))"))
    extcall IHub(hub).addSpoke(assetId, spoke, config)


@external
def addSpokeToAssets(hub: address, spoke: address, assetIds: DynArray[uint256, INF], configs: DynArray[SpokeConfig, INF]):
    self._check_access(method_id("addSpokeToAssets(address,address,uint256[],(uint40,uint40,uint24,bool,bool)[])"))
    if len(assetIds) != len(configs):
        raise MismatchedConfigs()
    i: uint256 = 0
    for asset_id: uint256 in assetIds:
        extcall IHub(hub).addSpoke(asset_id, spoke, configs[i])
        i += 1


@internal
def _update_spoke_field(hub: address, asset_id: uint256, spoke: address, field: uint256, field_value: uint256):
    config: SpokeConfig = staticcall IHub(hub).getSpokeConfig(asset_id, spoke)
    if field == 0:
        config.active = field_value != 0
    elif field == 1:
        config.halted = field_value != 0
    elif field == 2:
        config.addCap = self._u40(field_value)
    elif field == 3:
        config.drawCap = self._u40(field_value)
    else:
        config.riskPremiumThreshold = self._u24(field_value)
    extcall IHub(hub).updateSpokeConfig(asset_id, spoke, config)


@external
def updateSpokeActive(hub: address, assetId: uint256, spoke: address, active: bool):
    self._check_access(method_id("updateSpokeActive(address,uint256,address,bool)"))
    self._update_spoke_field(hub, assetId, spoke, 0, convert(active, uint256))


@external
def updateSpokeHalted(hub: address, assetId: uint256, spoke: address, halted: bool):
    self._check_access(method_id("updateSpokeHalted(address,uint256,address,bool)"))
    self._update_spoke_field(hub, assetId, spoke, 1, convert(halted, uint256))


@external
def updateSpokeAddCap(hub: address, assetId: uint256, spoke: address, addCap: uint256):
    self._check_access(method_id("updateSpokeAddCap(address,uint256,address,uint256)"))
    self._update_spoke_field(hub, assetId, spoke, 2, addCap)


@external
def updateSpokeDrawCap(hub: address, assetId: uint256, spoke: address, drawCap: uint256):
    self._check_access(method_id("updateSpokeDrawCap(address,uint256,address,uint256)"))
    self._update_spoke_field(hub, assetId, spoke, 3, drawCap)


@external
def updateSpokeRiskPremiumThreshold(hub: address, assetId: uint256, spoke: address, riskPremiumThreshold: uint256):
    self._check_access(method_id("updateSpokeRiskPremiumThreshold(address,uint256,address,uint256)"))
    self._update_spoke_field(hub, assetId, spoke, 4, riskPremiumThreshold)


@external
def updateSpokeCaps(hub: address, assetId: uint256, spoke: address, addCap: uint256, drawCap: uint256):
    self._check_access(method_id("updateSpokeCaps(address,uint256,address,uint256,uint256)"))
    config: SpokeConfig = staticcall IHub(hub).getSpokeConfig(assetId, spoke)
    config.addCap = self._u40(addCap)
    config.drawCap = self._u40(drawCap)
    extcall IHub(hub).updateSpokeConfig(assetId, spoke, config)


@internal
def _update_spoke_assets(hub: address, spoke: address, action: uint256):
    count: uint256 = staticcall IHub(hub).getAssetCount()
    for asset_id: uint256 in range(MAX_ITEMS):
        if asset_id >= count:
            break
        if staticcall IHub(hub).isSpokeListed(asset_id, spoke):
            config: SpokeConfig = staticcall IHub(hub).getSpokeConfig(asset_id, spoke)
            if action == 0:
                config.active = False
            elif action == 1:
                config.halted = True
            else:
                config.addCap = 0
                config.drawCap = 0
            extcall IHub(hub).updateSpokeConfig(asset_id, spoke, config)


@external
def deactivateSpoke(hub: address, spoke: address):
    self._check_access(method_id("deactivateSpoke(address,address)"))
    self._update_spoke_assets(hub, spoke, 0)


@external
def haltSpoke(hub: address, spoke: address):
    self._check_access(method_id("haltSpoke(address,address)"))
    self._update_spoke_assets(hub, spoke, 1)


@external
def resetSpokeCaps(hub: address, spoke: address):
    self._check_access(method_id("resetSpokeCaps(address,address)"))
    self._update_spoke_assets(hub, spoke, 2)


@external
def updateInterestRateData(hub: address, assetId: uint256, irData: Bytes[INF]):
    self._check_access(method_id("updateInterestRateData(address,uint256,bytes)"))
    extcall IHub(hub).setInterestRateData(assetId, irData)
