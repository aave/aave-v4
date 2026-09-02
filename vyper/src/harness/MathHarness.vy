#pragma version 0.5.0b1

from libraries.math import WadRayMath
from libraries.math import PercentageMath
from libraries.math import MathUtils


@external
@pure
def SECONDS_PER_YEAR() -> uint256:
    return MathUtils.SECONDS_PER_YEAR


@external
@pure
def WAD_DECIMALS() -> uint256:
    return WadRayMath.WAD_DECIMALS


@external
@pure
def WAD() -> uint256:
    return WadRayMath.WAD


@external
@pure
def RAY() -> uint256:
    return WadRayMath.RAY


@external
@pure
def PERCENTAGE_FACTOR() -> uint256:
    return PercentageMath.PERCENTAGE_FACTOR


@external
@pure
def wadMulDown(a: uint256, b: uint256) -> uint256:
    return WadRayMath.wad_mul_down(a, b)


@external
@pure
def wadMulUp(a: uint256, b: uint256) -> uint256:
    return WadRayMath.wad_mul_up(a, b)


@external
@pure
def wadDivDown(a: uint256, b: uint256) -> uint256:
    return WadRayMath.wad_div_down(a, b)


@external
@pure
def wadDivUp(a: uint256, b: uint256) -> uint256:
    return WadRayMath.wad_div_up(a, b)


@external
@pure
def rayMulDown(a: uint256, b: uint256) -> uint256:
    return WadRayMath.ray_mul_down(a, b)


@external
@pure
def rayMulUp(a: uint256, b: uint256) -> uint256:
    return WadRayMath.ray_mul_up(a, b)


@external
@pure
def rayDivDown(a: uint256, b: uint256) -> uint256:
    return WadRayMath.ray_div_down(a, b)


@external
@pure
def rayDivUp(a: uint256, b: uint256) -> uint256:
    return WadRayMath.ray_div_up(a, b)


@external
@pure
def toWad(a: uint256) -> uint256:
    return WadRayMath.to_wad(a)


@external
@pure
def toRay(a: uint256) -> uint256:
    return WadRayMath.to_ray(a)


@external
@pure
def fromWadDown(a: uint256) -> uint256:
    return WadRayMath.from_wad_down(a)


@external
@pure
def fromRayUp(a: uint256) -> uint256:
    return WadRayMath.from_ray_up(a)


@external
@pure
def bpsToWad(a: uint256) -> uint256:
    return WadRayMath.bps_to_wad(a)


@external
@pure
def bpsToRay(a: uint256) -> uint256:
    return WadRayMath.bps_to_ray(a)


@external
@pure
def roundRayUp(a: uint256) -> uint256:
    return WadRayMath.round_ray_up(a)


@external
@pure
def percentMulDown(amount: uint256, percentage: uint256) -> uint256:
    return PercentageMath.percent_mul_down(amount, percentage)


@external
@pure
def percentMulUp(amount: uint256, percentage: uint256) -> uint256:
    return PercentageMath.percent_mul_up(amount, percentage)


@external
@pure
def percentDivDown(amount: uint256, percentage: uint256) -> uint256:
    return PercentageMath.percent_div_down(amount, percentage)


@external
@pure
def percentDivUp(amount: uint256, percentage: uint256) -> uint256:
    return PercentageMath.percent_div_up(amount, percentage)


@external
@pure
def fromBpsDown(amount: uint256) -> uint256:
    return PercentageMath.from_bps_down(amount)


@external
@view
def calculateLinearInterest(rate: uint96, lastUpdateTimestamp: uint40) -> uint256:
    return MathUtils.calculate_linear_interest(rate, lastUpdateTimestamp)


@external
@pure
def min(a: uint256, b: uint256) -> uint256:
    return MathUtils.min_value(a, b)


@external
@pure
def zeroFloorSub(a: uint256, b: uint256) -> uint256:
    return MathUtils.zero_floor_sub(a, b)


@external
@pure
def add(a: uint256, b: int256) -> uint256:
    return MathUtils.add_signed(a, b)


@external
@pure
def uncheckedAdd(a: uint256, b: uint256) -> uint256:
    return MathUtils.unchecked_add(a, b)


@external
@pure
def signedSub(a: uint256, b: uint256) -> int256:
    return MathUtils.signed_sub(a, b)


@external
@pure
def uncheckedSub(a: uint256, b: uint256) -> uint256:
    return MathUtils.unchecked_sub(a, b)


@external
@pure
def uncheckedExp(a: uint256, b: uint256) -> uint256:
    return MathUtils.unchecked_exp(a, b)


@external
@pure
def divUp(a: uint256, b: uint256) -> uint256:
    return MathUtils.div_up(a, b)


@external
@pure
def mulDivDown(a: uint256, b: uint256, c: uint256) -> uint256:
    return MathUtils.mul_div_down(a, b, c)


@external
@pure
def mulDivUp(a: uint256, b: uint256, c: uint256) -> uint256:
    return MathUtils.mul_div_up(a, b, c)
