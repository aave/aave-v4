# pragma version 0.5.0b2

from position_manager import PositionManagerBase

initializes: PositionManagerBase
exports: PositionManagerBase.__interface__


@deploy
def __init__(initialOwner: address):
    PositionManagerBase._initialize_owner(initialOwner)


@pure
@override(PositionManagerBase)
def _multicall_enabled() -> bool:
    return True


@external
@payable
def __default__():
    pass


@external
@view
def getReserveUnderlying(spoke: address, reserveId: uint256) -> address:
    reserve: PositionManagerBase.ISpoke.Reserve = staticcall PositionManagerBase.ISpoke(spoke).getReserve(reserveId)
    return reserve.underlying
