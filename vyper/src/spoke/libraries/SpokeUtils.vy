# pragma version 0.5.0b2

from libraries import Errors

WAD_DECIMALS: constant(uint256) = 18


@pure
def _panic_arithmetic():
    raise Errors.Panic(17)


@pure
def to_value(amount: uint256, decimals: uint256, price: uint256) -> uint256:
    if decimals > WAD_DECIMALS:
        self._panic_arithmetic()
    scale: uint256 = 10 ** (WAD_DECIMALS - decimals)
    if price != 0 and amount > max_value(uint256) // price:
        self._panic_arithmetic()
    amount_price: uint256 = amount * price
    if scale != 0 and amount_price > max_value(uint256) // scale:
        self._panic_arithmetic()
    return amount_price * scale
