#pragma version 0.5.0a3


interface ISpoke:
    def ORACLE() -> address: view


interface IPriceFeed:
    def decimals() -> uint8: view
    def latestAnswer() -> int256: view


event UpdateReserveSource:
    reserveId: indexed(uint256)
    source: indexed(address)


event SetSpoke:
    spoke: indexed(address)


DECIMALS: immutable(uint8)
DEPLOYER: immutable(address)

spoke: public(address)
sources: HashMap[uint256, address]


@deploy
def __init__(decimals_: uint8):
    DEPLOYER = msg.sender
    DECIMALS = decimals_


@internal
@pure
def _revert_with_id(error_selector: Bytes[4], reserve_id: uint256):
    raw_revert(concat(error_selector, convert(reserve_id, bytes32)))


@internal
@view
def _get_source_price(reserve_id: uint256) -> uint256:
    source: address = self.sources[reserve_id]
    if source == empty(address):
        self._revert_with_id(method_id("InvalidSource(uint256)"), reserve_id)
    price: int256 = staticcall IPriceFeed(source).latestAnswer()
    if price <= 0:
        self._revert_with_id(method_id("InvalidPrice(uint256)"), reserve_id)
    return convert(price, uint256)


@external
def setSpoke(spoke_: address):
    if msg.sender != DEPLOYER:
        raw_revert(method_id("OnlyDeployer()"))
    if spoke_ == empty(address):
        raw_revert(method_id("InvalidAddress()"))
    if self.spoke != empty(address):
        raw_revert(method_id("SpokeAlreadySet()"))
    if staticcall ISpoke(spoke_).ORACLE() != self:
        raw_revert(method_id("OracleMismatch()"))
    self.spoke = spoke_
    log SetSpoke(spoke=spoke_)


@external
def setReserveSource(reserveId: uint256, source: address):
    if msg.sender != self.spoke:
        raw_revert(method_id("OnlySpoke()"))
    if staticcall IPriceFeed(source).decimals() != DECIMALS:
        self._revert_with_id(method_id("InvalidSourceDecimals(uint256)"), reserveId)
    self.sources[reserveId] = source
    self._get_source_price(reserveId)
    log UpdateReserveSource(reserveId=reserveId, source=source)


@external
@view
def decimals() -> uint8:
    return DECIMALS


@external
@view
def getReservePrice(reserveId: uint256) -> uint256:
    return self._get_source_price(reserveId)


@external
@view
def getReservesPrices(reserveIds: DynArray[uint256, 1024]) -> DynArray[uint256, 1024]:
    prices: DynArray[uint256, 1024] = []
    for reserve_id: uint256 in reserveIds:
        prices.append(self._get_source_price(reserve_id))
    return prices


@external
@view
def getReserveSource(reserveId: uint256) -> address:
    return self.sources[reserveId]
