# pragma version 0.5.0a3

from spoke.libraries import ReserveFlagsMap

initializes: ReserveFlagsMap


@external
@pure
def create(initPaused: bool, initFrozen: bool, initBorrowable: bool, initReceiveSharesEnabled: bool) -> uint8:
    return ReserveFlagsMap.create(initPaused, initFrozen, initBorrowable, initReceiveSharesEnabled)


@external
@pure
def setPaused(flags: uint8, status: bool) -> uint8:
    return ReserveFlagsMap.set_paused(flags, status)


@external
@pure
def setFrozen(flags: uint8, status: bool) -> uint8:
    return ReserveFlagsMap.set_frozen(flags, status)


@external
@pure
def setBorrowable(flags: uint8, status: bool) -> uint8:
    return ReserveFlagsMap.set_borrowable(flags, status)


@external
@pure
def setReceiveSharesEnabled(flags: uint8, status: bool) -> uint8:
    return ReserveFlagsMap.set_receive_shares_enabled(flags, status)


@external
@pure
def paused(flags: uint8) -> bool:
    return ReserveFlagsMap.paused(flags)


@external
@pure
def frozen(flags: uint8) -> bool:
    return ReserveFlagsMap.frozen(flags)


@external
@pure
def borrowable(flags: uint8) -> bool:
    return ReserveFlagsMap.borrowable(flags)


@external
@pure
def receiveSharesEnabled(flags: uint8) -> bool:
    return ReserveFlagsMap.receive_shares_enabled(flags)


@external
@pure
def PAUSED_MASK() -> uint8:
    return ReserveFlagsMap.PAUSED_MASK


@external
@pure
def FROZEN_MASK() -> uint8:
    return ReserveFlagsMap.FROZEN_MASK


@external
@pure
def BORROWABLE_MASK() -> uint8:
    return ReserveFlagsMap.BORROWABLE_MASK


@external
@pure
def RECEIVE_SHARES_ENABLED_MASK() -> uint8:
    return ReserveFlagsMap.RECEIVE_SHARES_ENABLED_MASK
