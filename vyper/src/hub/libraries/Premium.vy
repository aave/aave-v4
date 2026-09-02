# pragma version 0.5.0b1

from libraries import Errors

error SafeCastOverflowedIntToUint:
    arg0: int256

error SafeCastOverflowedUintToInt:
    arg0: uint256

@pure
def _panic_arithmetic():
    raise Errors.Panic(convert(17, uint256))


@pure
def calculate_premium_ray(premium_shares: uint256, premium_offset_ray: int256, drawn_index: uint256) -> uint256:
    if premium_shares != 0 and drawn_index > max_value(uint256) // premium_shares:
        self._panic_arithmetic()
    gross_uint: uint256 = premium_shares * drawn_index
    if gross_uint > convert(max_value(int256), uint256):
        raise SafeCastOverflowedUintToInt(gross_uint)
    gross: int256 = convert(gross_uint, int256)
    if premium_offset_ray < 0 and gross > max_value(int256) + premium_offset_ray:
        self._panic_arithmetic()
    premium_ray: int256 = gross - premium_offset_ray
    if premium_ray < 0:
        raise SafeCastOverflowedIntToUint(premium_ray)
    return convert(premium_ray, uint256)
