# pragma version 0.5.0b1

VIRTUAL_ASSETS: public(constant(uint256)) = 10**6
VIRTUAL_SHARES: public(constant(uint256)) = 10**6


@pure
def _mul_div_down(x: uint256, y: uint256, denominator: uint256) -> uint256:
    prod0: uint256 = unsafe_mul(x, y)
    mm: uint256 = uint256_mulmod(x, y, max_value(uint256))
    prod1: uint256 = unsafe_sub(unsafe_sub(mm, prod0), convert(mm < prod0, uint256))

    if prod1 == 0:
        return prod0 // denominator
    if denominator <= prod1:
        raw_revert(method_id("MathOverflowedMulDiv()"))

    remainder: uint256 = uint256_mulmod(x, y, denominator)
    prod1 = unsafe_sub(prod1, convert(remainder > prod0, uint256))
    prod0 = unsafe_sub(prod0, remainder)

    twos: uint256 = denominator & unsafe_add(~denominator, 1)
    denominator //= twos
    prod0 //= twos
    twos = unsafe_add(unsafe_div(unsafe_sub(0, twos), twos), 1)
    prod0 = prod0 | unsafe_mul(prod1, twos)

    inverse: uint256 = unsafe_mul(3, denominator) ^ 2
    inverse = unsafe_mul(inverse, unsafe_sub(2, unsafe_mul(denominator, inverse)))
    inverse = unsafe_mul(inverse, unsafe_sub(2, unsafe_mul(denominator, inverse)))
    inverse = unsafe_mul(inverse, unsafe_sub(2, unsafe_mul(denominator, inverse)))
    inverse = unsafe_mul(inverse, unsafe_sub(2, unsafe_mul(denominator, inverse)))
    inverse = unsafe_mul(inverse, unsafe_sub(2, unsafe_mul(denominator, inverse)))
    inverse = unsafe_mul(inverse, unsafe_sub(2, unsafe_mul(denominator, inverse)))
    return unsafe_mul(prod0, inverse)


@pure
def _mul_div_up(x: uint256, y: uint256, denominator: uint256) -> uint256:
    result: uint256 = self._mul_div_down(x, y, denominator)
    if uint256_mulmod(x, y, denominator) != 0:
        if result == max_value(uint256):
            raw_revert(method_id("MathOverflowedMulDiv()"))
        result += 1
    return result


@pure
def to_shares_down(assets: uint256, total_assets: uint256, total_shares: uint256) -> uint256:
    return self._mul_div_down(assets, total_shares + VIRTUAL_SHARES, total_assets + VIRTUAL_ASSETS)


@pure
def to_assets_down(shares: uint256, total_assets: uint256, total_shares: uint256) -> uint256:
    return self._mul_div_down(shares, total_assets + VIRTUAL_ASSETS, total_shares + VIRTUAL_SHARES)


@pure
def to_shares_up(assets: uint256, total_assets: uint256, total_shares: uint256) -> uint256:
    return self._mul_div_up(assets, total_shares + VIRTUAL_SHARES, total_assets + VIRTUAL_ASSETS)


@pure
def to_assets_up(shares: uint256, total_assets: uint256, total_shares: uint256) -> uint256:
    return self._mul_div_up(shares, total_assets + VIRTUAL_ASSETS, total_shares + VIRTUAL_SHARES)
