#pragma version 0.5.0b1
from spoke.interfaces import ISpoke
from spoke.interfaces import IPriceFeed
from spoke.interfaces import IAaveOracle

implements: IAaveOracle


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
        raise IAaveOracle.InvalidSource(reserve_id)
    price: int256 = staticcall IPriceFeed(source).latestAnswer()
    if price <= 0:
        raise IAaveOracle.InvalidPrice(reserve_id)
    return convert(price, uint256)


@external
def setSpoke(spoke_: address):
    if msg.sender != DEPLOYER:
        raise IAaveOracle.OnlyDeployer()
    if spoke_ == empty(address):
        raise IAaveOracle.InvalidAddress()
    if self.spoke != empty(address):
        raise IAaveOracle.SpokeAlreadySet()
    if staticcall ISpoke(spoke_).ORACLE() != self:
        raise IAaveOracle.OracleMismatch()
    self.spoke = spoke_
    log IAaveOracle.SetSpoke(spoke=spoke_)


@external
def setReserveSource(reserveId: uint256, source: address):
    if msg.sender != self.spoke:
        raise IAaveOracle.OnlySpoke()
    if staticcall IPriceFeed(source).decimals() != DECIMALS:
        raise IAaveOracle.InvalidSourceDecimals(reserveId)
    self.sources[reserveId] = source
    self._get_source_price(reserveId)
    log IAaveOracle.UpdateReserveSource(reserveId=reserveId, source=source)


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
