#pragma version 0.5.0b2

from utils import SafeERC20
from utils.interfaces import IRescuable


@view
@abstract
def _rescue_guardian() -> address:
    ...


@internal
@view
def _check_rescue_guardian():
    if self._rescue_guardian() != msg.sender:
        raise IRescuable.OnlyRescueGuardian()


@external
def rescueToken(token: address, to: address, amount: uint256):
    self._check_rescue_guardian()
    SafeERC20.safe_transfer(token, to, amount)


@external
def rescueNative(to: address, amount: uint256):
    self._check_rescue_guardian()
    raw_call(to, b"", value=amount)


@external
@view
def rescueGuardian() -> address:
    return self._rescue_guardian()
