# pragma version 0.5.0b2

PAUSED_MASK: public(constant(uint8)) = 1
FROZEN_MASK: public(constant(uint8)) = 2
BORROWABLE_MASK: public(constant(uint8)) = 4
RECEIVE_SHARES_ENABLED_MASK: public(constant(uint8)) = 8


@pure
def _set_status(flags: uint8, mask: uint8, status: bool) -> uint8:
    if status:
        return flags | mask
    return flags & (255 ^ mask)


@pure
def create(paused: bool, frozen: bool, borrowable: bool, receive_shares_enabled: bool) -> uint8:
    flags: uint8 = 0
    flags = self._set_status(flags, PAUSED_MASK, paused)
    flags = self._set_status(flags, FROZEN_MASK, frozen)
    flags = self._set_status(flags, BORROWABLE_MASK, borrowable)
    return self._set_status(flags, RECEIVE_SHARES_ENABLED_MASK, receive_shares_enabled)


@pure
def set_paused(flags: uint8, status: bool) -> uint8:
    return self._set_status(flags, PAUSED_MASK, status)


@pure
def set_frozen(flags: uint8, status: bool) -> uint8:
    return self._set_status(flags, FROZEN_MASK, status)


@pure
def set_borrowable(flags: uint8, status: bool) -> uint8:
    return self._set_status(flags, BORROWABLE_MASK, status)


@pure
def set_receive_shares_enabled(flags: uint8, status: bool) -> uint8:
    return self._set_status(flags, RECEIVE_SHARES_ENABLED_MASK, status)


@pure
def paused(flags: uint8) -> bool:
    return flags & PAUSED_MASK != 0


@pure
def frozen(flags: uint8) -> bool:
    return flags & FROZEN_MASK != 0


@pure
def borrowable(flags: uint8) -> bool:
    return flags & BORROWABLE_MASK != 0


@pure
def receive_shares_enabled(flags: uint8) -> bool:
    return flags & RECEIVE_SHARES_ENABLED_MASK != 0
