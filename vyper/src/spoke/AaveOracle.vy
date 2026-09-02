#pragma version 0.5.0b1


error InvalidAddress:
    pass

error InvalidPrice:
    arg0: uint256

error InvalidSource:
    arg0: uint256

error InvalidSourceDecimals:
    arg0: uint256

error OnlyDeployer:
    pass

error OnlySpoke:
    pass

error OracleMismatch:
    pass

error SpokeAlreadySet:
    pass

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
@view
def _get_source_price(reserve_id: uint256) -> uint256:
    source: address = self.sources[reserve_id]
    if source == empty(address):
        raise InvalidSource(reserve_id)
    price: int256 = staticcall IPriceFeed(source).latestAnswer()
    if price <= 0:
        raise InvalidPrice(reserve_id)
    return convert(price, uint256)


@external
def setSpoke(spoke_: address):
    if msg.sender != DEPLOYER:
        raise OnlyDeployer()
    if spoke_ == empty(address):
        raise InvalidAddress()
    if self.spoke != empty(address):
        raise SpokeAlreadySet()
    if staticcall ISpoke(spoke_).ORACLE() != self:
        raise OracleMismatch()
    self.spoke = spoke_
    log SetSpoke(spoke=spoke_)


@external
def setReserveSource(reserveId: uint256, source: address):
    if msg.sender != self.spoke:
        raise OnlySpoke()
    if staticcall IPriceFeed(source).decimals() != DECIMALS:
        raise InvalidSourceDecimals(reserveId)
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
def getReservesPrices(reserveIds: DynArray[uint256, INF]) -> DynArray[uint256, INF]:
    prices: DynArray[uint256, INF] = []
    for reserve_id: uint256 in reserveIds:
        prices.append(self._get_source_price(reserve_id))
    return prices


@external
@view
def getReserveSource(reserveId: uint256) -> address:
    return self.sources[reserveId]
