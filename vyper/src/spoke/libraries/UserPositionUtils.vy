# pragma version 0.5.0b1

from hub.libraries import Premium
from libraries.math import PercentageMath
from libraries.math import WadRayMath

initializes: Premium
initializes: PercentageMath
initializes: WadRayMath


struct UserPosition:
    drawnShares: uint120
    premiumShares: uint120
    premiumOffsetRay: int200
    suppliedShares: uint120
    dynamicConfigKey: uint32

struct PremiumDelta:
    sharesDelta: int256
    offsetRayDelta: int256
    restoredPremiumRay: uint256


@pure
def calculate_premium_ray(position: UserPosition, drawn_index: uint256) -> uint256:
    return Premium.calculate_premium_ray(
        convert(position.premiumShares, uint256),
        convert(position.premiumOffsetRay, int256),
        drawn_index,
    )


@pure
def get_debt(position: UserPosition, drawn_index: uint256) -> (uint256, uint256):
    return (
        WadRayMath.ray_mul_up(convert(position.drawnShares, uint256), drawn_index),
        self.calculate_premium_ray(position, drawn_index),
    )


@pure
def calculate_restore_amount(position: UserPosition, drawn_index: uint256, amount: uint256) -> (uint256, uint256):
    drawn_debt: uint256 = 0
    premium_debt_ray: uint256 = 0
    drawn_debt, premium_debt_ray = self.get_debt(position, drawn_index)
    premium_debt: uint256 = WadRayMath.from_ray_up(premium_debt_ray)
    if amount >= drawn_debt + premium_debt:
        return drawn_debt, premium_debt_ray
    if amount < premium_debt:
        return 0, WadRayMath.to_ray(amount)
    return amount - premium_debt, premium_debt_ray


@pure
def calculate_premium_delta(
    position: UserPosition,
    drawn_shares_taken: uint256,
    drawn_index: uint256,
    risk_premium: uint256,
    restored_premium_ray: uint256,
) -> PremiumDelta:
    old_shares: uint256 = convert(position.premiumShares, uint256)
    old_offset: int256 = convert(position.premiumOffsetRay, int256)
    premium_debt_ray: uint256 = self.calculate_premium_ray(position, drawn_index)
    new_shares: uint256 = PercentageMath.percent_mul_up(
        convert(position.drawnShares, uint256) - drawn_shares_taken,
        risk_premium,
    )
    new_offset: int256 = (
        convert(new_shares * drawn_index, int256)
        - convert(premium_debt_ray - restored_premium_ray, int256)
    )
    return PremiumDelta(
        sharesDelta=convert(new_shares, int256) - convert(old_shares, int256),
        offsetRayDelta=new_offset - old_offset,
        restoredPremiumRay=restored_premium_ray,
    )
