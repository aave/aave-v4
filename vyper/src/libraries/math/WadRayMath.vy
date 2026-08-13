#pragma version 0.5.0a3

WAD_DECIMALS: constant(uint256) = 18
WAD: constant(uint256) = 10**18
RAY: constant(uint256) = 10**27
PERCENTAGE_FACTOR: constant(uint256) = 10**4
UINT256_MAX: constant(uint256) = max_value(uint256)


@pure
def wad_mul_down(a: uint256, b: uint256) -> uint256:
    if b != 0:
        assert a <= UINT256_MAX // b
    return unsafe_mul(a, b) // WAD


@pure
def wad_mul_up(a: uint256, b: uint256) -> uint256:
    if b != 0:
        assert a <= UINT256_MAX // b
    product: uint256 = unsafe_mul(a, b)
    return product // WAD + convert(product % WAD != 0, uint256)


@pure
def wad_div_down(a: uint256, b: uint256) -> uint256:
    assert b != 0
    assert a <= UINT256_MAX // WAD
    return unsafe_mul(a, WAD) // b


@pure
def wad_div_up(a: uint256, b: uint256) -> uint256:
    assert b != 0
    assert a <= UINT256_MAX // WAD
    numerator: uint256 = unsafe_mul(a, WAD)
    return numerator // b + convert(numerator % b != 0, uint256)


@pure
def ray_mul_down(a: uint256, b: uint256) -> uint256:
    if b != 0:
        assert a <= UINT256_MAX // b
    return unsafe_mul(a, b) // RAY


@pure
def ray_mul_up(a: uint256, b: uint256) -> uint256:
    if b != 0:
        assert a <= UINT256_MAX // b
    product: uint256 = unsafe_mul(a, b)
    return product // RAY + convert(product % RAY != 0, uint256)


@pure
def ray_div_down(a: uint256, b: uint256) -> uint256:
    assert b != 0
    assert a <= UINT256_MAX // RAY
    return unsafe_mul(a, RAY) // b


@pure
def ray_div_up(a: uint256, b: uint256) -> uint256:
    assert b != 0
    assert a <= UINT256_MAX // RAY
    numerator: uint256 = unsafe_mul(a, RAY)
    return numerator // b + convert(numerator % b != 0, uint256)


@pure
def to_wad(a: uint256) -> uint256:
    assert a <= UINT256_MAX // WAD
    return unsafe_mul(a, WAD)


@pure
def to_ray(a: uint256) -> uint256:
    assert a <= UINT256_MAX // RAY
    return unsafe_mul(a, RAY)


@pure
def from_wad_down(a: uint256) -> uint256:
    return a // WAD


@pure
def from_ray_up(a: uint256) -> uint256:
    return a // RAY + convert(a % RAY != 0, uint256)


@pure
def bps_to_wad(a: uint256) -> uint256:
    factor: uint256 = WAD // PERCENTAGE_FACTOR
    assert a <= UINT256_MAX // factor
    return unsafe_mul(a, factor)


@pure
def bps_to_ray(a: uint256) -> uint256:
    factor: uint256 = RAY // PERCENTAGE_FACTOR
    assert a <= UINT256_MAX // factor
    return unsafe_mul(a, factor)


@pure
def round_ray_up(a: uint256) -> uint256:
    rounded: uint256 = a // RAY + convert(a % RAY != 0, uint256)
    assert rounded <= UINT256_MAX // RAY
    return unsafe_mul(rounded, RAY)
