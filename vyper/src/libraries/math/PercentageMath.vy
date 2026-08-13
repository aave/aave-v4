#pragma version 0.5.0a3

PERCENTAGE_FACTOR: constant(uint256) = 10**4
UINT256_MAX: constant(uint256) = max_value(uint256)


@pure
def percent_mul_down(amount: uint256, percentage: uint256) -> uint256:
    if percentage != 0:
        assert amount <= UINT256_MAX // percentage
    return unsafe_mul(amount, percentage) // PERCENTAGE_FACTOR


@pure
def percent_mul_up(amount: uint256, percentage: uint256) -> uint256:
    if percentage != 0:
        assert amount <= UINT256_MAX // percentage
    product: uint256 = unsafe_mul(amount, percentage)
    return product // PERCENTAGE_FACTOR + convert(product % PERCENTAGE_FACTOR != 0, uint256)


@pure
def percent_div_down(amount: uint256, percentage: uint256) -> uint256:
    assert percentage != 0
    assert amount <= UINT256_MAX // PERCENTAGE_FACTOR
    return unsafe_mul(amount, PERCENTAGE_FACTOR) // percentage


@pure
def percent_div_up(amount: uint256, percentage: uint256) -> uint256:
    assert percentage != 0
    assert amount <= UINT256_MAX // PERCENTAGE_FACTOR
    numerator: uint256 = unsafe_mul(amount, PERCENTAGE_FACTOR)
    return numerator // percentage + convert(numerator % percentage != 0, uint256)


@pure
def from_bps_down(amount: uint256) -> uint256:
    return amount // PERCENTAGE_FACTOR
