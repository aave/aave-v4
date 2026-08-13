# pragma version 0.5.0a3

from position_manager import PositionManagerBase

initializes: PositionManagerBase
exports: PositionManagerBase.__interface__


@deploy
def __init__(initialOwner: address):
    PositionManagerBase._initialize_owner(initialOwner)


@pure
@override(PositionManagerBase)
def _multicall_enabled() -> bool:
    return False


@external
@payable
def __default__():
    pass
