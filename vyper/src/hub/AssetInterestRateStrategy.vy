#pragma version 0.5.0b2

from hub import BasicInterestRateStrategy
from libraries.math import WadRayMath
from hub.interfaces import IAssetInterestRateStrategy

implements: IAssetInterestRateStrategy

initializes: BasicInterestRateStrategy
exports: BasicInterestRateStrategy.calculateInterestRate


MAX_ALLOWED_DRAWN_RATE: public(constant(uint256)) = 1000_00
MIN_OPTIMAL_RATIO: public(constant(uint256)) = 1_00
MAX_OPTIMAL_RATIO: public(constant(uint256)) = 99_00
HUB: public(immutable(address))

interest_rate_data: HashMap[uint256, IAssetInterestRateStrategy.InterestRateData]


@deploy
def __init__(hub: address):
    if hub == empty(address):
        raise IAssetInterestRateStrategy.InvalidAddress()
    HUB = hub


@external
def setInterestRateData(assetId: uint256, data: Bytes[INF]):
    if msg.sender != HUB:
        raise IAssetInterestRateStrategy.OnlyHub()

    rate_data: IAssetInterestRateStrategy.InterestRateData = abi_decode(data, IAssetInterestRateStrategy.InterestRateData)
    optimal_usage_ratio: uint256 = convert(rate_data.optimalUsageRatio, uint256)
    if optimal_usage_ratio < MIN_OPTIMAL_RATIO or optimal_usage_ratio > MAX_OPTIMAL_RATIO:
        raise IAssetInterestRateStrategy.InvalidOptimalUsageRatio()

    max_rate: uint256 = (
        convert(rate_data.baseDrawnRate, uint256)
        + convert(rate_data.rateGrowthBeforeOptimal, uint256)
        + convert(rate_data.rateGrowthAfterOptimal, uint256)
    )
    if max_rate > MAX_ALLOWED_DRAWN_RATE:
        raise IAssetInterestRateStrategy.InvalidMaxDrawnRate()

    self.interest_rate_data[assetId] = rate_data
    log IAssetInterestRateStrategy.UpdateInterestRateData(
        hub=HUB,
        assetId=assetId,
        optimalUsageRatio=convert(rate_data.optimalUsageRatio, uint256),
        baseDrawnRate=convert(rate_data.baseDrawnRate, uint256),
        rateGrowthBeforeOptimal=convert(rate_data.rateGrowthBeforeOptimal, uint256),
        rateGrowthAfterOptimal=convert(rate_data.rateGrowthAfterOptimal, uint256),
    )


@external
@view
def getInterestRateData(assetId: uint256) -> IAssetInterestRateStrategy.InterestRateData:
    return self.interest_rate_data[assetId]


@external
@view
def getOptimalUsageRatio(assetId: uint256) -> uint256:
    return convert(self.interest_rate_data[assetId].optimalUsageRatio, uint256)


@external
@view
def getBaseDrawnRate(assetId: uint256) -> uint256:
    return convert(self.interest_rate_data[assetId].baseDrawnRate, uint256)


@external
@view
def getRateGrowthBeforeOptimal(assetId: uint256) -> uint256:
    return convert(self.interest_rate_data[assetId].rateGrowthBeforeOptimal, uint256)


@external
@view
def getRateGrowthAfterOptimal(assetId: uint256) -> uint256:
    return convert(self.interest_rate_data[assetId].rateGrowthAfterOptimal, uint256)


@external
@view
def getMaxDrawnRate(assetId: uint256) -> uint256:
    rate_data: IAssetInterestRateStrategy.InterestRateData = self.interest_rate_data[assetId]
    return (
        convert(rate_data.baseDrawnRate, uint256)
        + convert(rate_data.rateGrowthBeforeOptimal, uint256)
        + convert(rate_data.rateGrowthAfterOptimal, uint256)
    )


@view
@override(BasicInterestRateStrategy)
def _calculate_interest_rate(
    asset_id: uint256,
    liquidity: uint256,
    drawn: uint256,
    deficit: uint256,
    swept: uint256,
) -> uint256:
    rate_data: IAssetInterestRateStrategy.InterestRateData = self.interest_rate_data[asset_id]
    if rate_data.optimalUsageRatio == 0:
        raise IAssetInterestRateStrategy.InterestRateDataNotSet(asset_id)

    current_drawn_rate_ray: uint256 = WadRayMath.bps_to_ray(
        convert(rate_data.baseDrawnRate, uint256)
    )
    if drawn == 0:
        return current_drawn_rate_ray

    usage_ratio_ray: uint256 = WadRayMath.ray_div_up(drawn, liquidity + drawn + swept)
    optimal_usage_ratio_ray: uint256 = WadRayMath.bps_to_ray(
        convert(rate_data.optimalUsageRatio, uint256)
    )

    if usage_ratio_ray <= optimal_usage_ratio_ray:
        current_drawn_rate_ray += WadRayMath.ray_div_up(
            WadRayMath.ray_mul_up(
                WadRayMath.bps_to_ray(convert(rate_data.rateGrowthBeforeOptimal, uint256)),
                usage_ratio_ray,
            ),
            optimal_usage_ratio_ray,
        )
    else:
        current_drawn_rate_ray += (
            WadRayMath.bps_to_ray(convert(rate_data.rateGrowthBeforeOptimal, uint256))
            + WadRayMath.ray_div_up(
                WadRayMath.ray_mul_up(
                    WadRayMath.bps_to_ray(convert(rate_data.rateGrowthAfterOptimal, uint256)),
                    usage_ratio_ray - optimal_usage_ratio_ray,
                ),
                WadRayMath.RAY - optimal_usage_ratio_ray,
            )
        )

    return current_drawn_rate_ray
