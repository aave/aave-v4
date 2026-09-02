#pragma version 0.5.0b1

from libraries import Errors

error SafeCastOverflowedUintToInt:
    arg0: uint256

RAY: constant(uint256) = 10**27
SECONDS_PER_YEAR: constant(uint256) = 365 * 24 * 60 * 60
UINT256_MAX: constant(uint256) = max_value(uint256)
INT256_MAX: constant(uint256) = 2**255 - 1
INT256_MIN_ABS: constant(uint256) = 2**255


@pure
def _panic_arithmetic():
    raise Errors.Panic(17)


@view
def calculate_linear_interest(rate: uint96, last_update_timestamp: uint40) -> uint256:
    previous_timestamp: uint256 = convert(last_update_timestamp, uint256)
    assert previous_timestamp <= block.timestamp
    elapsed: uint256 = block.timestamp - previous_timestamp
    return RAY + convert(rate, uint256) * elapsed // SECONDS_PER_YEAR


@pure
def min_value(a: uint256, b: uint256) -> uint256:
    if a < b:
        return a
    return b


@pure
def zero_floor_sub(a: uint256, b: uint256) -> uint256:
    if a > b:
        return a - b
    return 0


@pure
def add_signed(a: uint256, b: int256) -> uint256:
    if b >= 0:
        positive: uint256 = convert(b, uint256)
        if a > UINT256_MAX - positive:
            self._panic_arithmetic()
        return a + positive
    magnitude: uint256 = INT256_MIN_ABS if b == min_value(int256) else convert(-b, uint256)
    if a < magnitude:
        self._panic_arithmetic()
    return a - magnitude


@pure
def unchecked_add(a: uint256, b: uint256) -> uint256:
    return unsafe_add(a, b)


@pure
def signed_sub(a: uint256, b: uint256) -> int256:
    if a > INT256_MAX:
        raise SafeCastOverflowedUintToInt(a)
    if b > INT256_MAX:
        raise SafeCastOverflowedUintToInt(b)
    return convert(a, int256) - convert(b, int256)


@pure
def unchecked_sub(a: uint256, b: uint256) -> uint256:
    return unsafe_sub(a, b)


@pure
def unchecked_exp(a: uint256, b: uint256) -> uint256:
    return pow_mod256(a, b)


@pure
def div_up(a: uint256, b: uint256) -> uint256:
    assert b != 0
    return a // b + convert(a % b != 0, uint256)


@pure
def mul_div_down(a: uint256, b: uint256, c: uint256) -> uint256:
    assert c != 0
    if b != 0:
        assert a <= UINT256_MAX // b
    return unsafe_mul(a, b) // c


@pure
def mul_div_up(a: uint256, b: uint256, c: uint256) -> uint256:
    assert c != 0
    if b != 0:
        assert a <= UINT256_MAX // b
    product: uint256 = unsafe_mul(a, b)
    return product // c + convert(product % c != 0, uint256)
