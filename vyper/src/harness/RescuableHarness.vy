#pragma version 0.5.0b1

from utils import Rescuable

initializes: Rescuable
exports: Rescuable.__interface__


admin: public(immutable(address))


@deploy
def __init__(admin_: address):
    admin = admin_


@view
@override(Rescuable)
def _rescue_guardian() -> address:
    return admin


@external
@payable
def __default__():
    pass
