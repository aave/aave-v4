# pragma version 0.5.0a3


@pure
def _panic_arithmetic():
    raw_revert(concat(method_id("Panic(uint256)"), convert(convert(17, uint256), bytes32)))


@pure
def calculate_premium_ray(premium_shares: uint256, premium_offset_ray: int256, drawn_index: uint256) -> uint256:
    if premium_shares != 0 and drawn_index > max_value(uint256) // premium_shares:
        self._panic_arithmetic()
    gross_uint: uint256 = premium_shares * drawn_index
    if gross_uint > convert(max_value(int256), uint256):
        raw_revert(concat(method_id("SafeCastOverflowedUintToInt(uint256)"), convert(gross_uint, bytes32)))
    gross: int256 = convert(gross_uint, int256)
    if premium_offset_ray < 0 and gross > max_value(int256) + premium_offset_ray:
        self._panic_arithmetic()
    premium_ray: int256 = gross - premium_offset_ray
    if premium_ray < 0:
        raw_revert(concat(method_id("SafeCastOverflowedIntToUint(int256)"), abi_encode(premium_ray)))
    return convert(premium_ray, uint256)
