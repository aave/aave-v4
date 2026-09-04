# pragma version 0.5.0b2

from hub.libraries import SharesMath
from libraries import Errors
from libraries.math import PercentageMath
from libraries.math import WadRayMath
from spoke.libraries import ReserveFlagsMap
from spoke.libraries import SpokeUtils
from hub.interfaces import IHub
from spoke.interfaces import ISpoke
from spoke.interfaces import ILiquidationLogic

struct CalculateDebtToTargetHealthFactorParams:
    totalDebtValueRay: uint256
    debtAssetUnit: uint256
    debtAssetPrice: uint256
    collateralFactor: uint256
    liquidationBonus: uint256
    healthFactor: uint256
    targetHealthFactor: uint256

struct CalculateDebtToLiquidateParams:
    drawnShares: uint256
    premiumDebtRay: uint256
    drawnIndex: uint256
    totalDebtValueRay: uint256
    debtAssetDecimals: uint256
    debtAssetUnit: uint256
    debtAssetPrice: uint256
    debtToCover: uint256
    collateralFactor: uint256
    liquidationBonus: uint256
    healthFactor: uint256
    targetHealthFactor: uint256

struct CalculateCollateralToLiquidateParams:
    collateralReserveHub: address
    collateralReserveAssetId: uint256
    collateralAssetUnit: uint256
    collateralAssetPrice: uint256
    drawnSharesToLiquidate: uint256
    premiumDebtRayToLiquidate: uint256
    drawnIndex: uint256
    debtAssetUnit: uint256
    debtAssetPrice: uint256
    liquidationBonus: uint256

HEALTH_FACTOR_LIQUIDATION_THRESHOLD: constant(uint256) = 10**18
DUST_LIQUIDATION_THRESHOLD: constant(uint256) = 1000 * 10**26
PERCENTAGE_FACTOR: constant(uint256) = 10**4
RAY: constant(uint256) = 10**27
WAD: constant(uint256) = 10**18


@pure
def _panic_arithmetic():
    raise Errors.Panic(17)


@pure
def calculate_liquidation_bonus(
    health_factor_for_max_bonus: uint256,
    liquidation_bonus_factor: uint256,
    health_factor: uint256,
    max_liquidation_bonus: uint256,
) -> uint256:
    if health_factor <= health_factor_for_max_bonus:
        return max_liquidation_bonus
    minimum: uint256 = PERCENTAGE_FACTOR + PercentageMath.percent_mul_down(
        max_liquidation_bonus - PERCENTAGE_FACTOR,
        liquidation_bonus_factor,
    )
    return minimum + SharesMath._mul_div_down(
        max_liquidation_bonus - minimum,
        HEALTH_FACTOR_LIQUIDATION_THRESHOLD - health_factor,
        HEALTH_FACTOR_LIQUIDATION_THRESHOLD - health_factor_for_max_bonus,
    )


@pure
def validate_liquidation_call(params: ILiquidationLogic.ValidateLiquidationCallParams):
    if params.user == params.liquidator:
        raise ISpoke.SelfLiquidation()
    if params.debtToCover == 0:
        raise ISpoke.InvalidDebtToCover()
    if ReserveFlagsMap.paused(params.collateralReserveFlags) or ReserveFlagsMap.paused(params.debtReserveFlags):
        raise ISpoke.ReservePaused()
    if params.suppliedShares == 0:
        raise ISpoke.ReserveNotSupplied()
    if params.drawnShares == 0:
        raise ISpoke.ReserveNotBorrowed()
    if params.healthFactor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD:
        raise ISpoke.HealthFactorNotBelowThreshold()
    if params.collateralFactor == 0 or not params.isUsingAsCollateral:
        raise ISpoke.ReserveNotEnabledAsCollateral()
    if params.receiveShares and (ReserveFlagsMap.frozen(params.collateralReserveFlags) or not ReserveFlagsMap.receive_shares_enabled(params.collateralReserveFlags)):
        raise ISpoke.CannotReceiveShares()


@pure
def calculate_debt_to_target_health_factor(params: CalculateDebtToTargetHealthFactorParams) -> uint256:
    if params.targetHealthFactor < params.healthFactor:
        self._panic_arithmetic()
    liquidation_penalty: uint256 = PercentageMath.percent_mul_up(
        WadRayMath.bps_to_wad(params.liquidationBonus),
        params.collateralFactor,
    )
    return SharesMath._mul_div_up(
        params.totalDebtValueRay,
        params.debtAssetUnit * (params.targetHealthFactor - params.healthFactor),
        (params.targetHealthFactor - liquidation_penalty) * params.debtAssetPrice * WAD,
    )


@pure
def calculate_debt_to_liquidate(params: CalculateDebtToLiquidateParams) -> (uint256, uint256):
    target_params: CalculateDebtToTargetHealthFactorParams = CalculateDebtToTargetHealthFactorParams(
        totalDebtValueRay=params.totalDebtValueRay,
        debtAssetUnit=params.debtAssetUnit,
        debtAssetPrice=params.debtAssetPrice,
        collateralFactor=params.collateralFactor,
        liquidationBonus=params.liquidationBonus,
        healthFactor=params.healthFactor,
        targetHealthFactor=params.targetHealthFactor,
    )
    debt_ray_to_target: uint256 = self.calculate_debt_to_target_health_factor(target_params)
    premium_to_liquidate: uint256 = min(WadRayMath.round_ray_up(debt_ray_to_target), params.premiumDebtRay)
    if params.debtToCover < WadRayMath.from_ray_up(premium_to_liquidate):
        premium_to_liquidate = params.debtToCover * RAY

    drawn_to_liquidate: uint256 = 0
    if premium_to_liquidate == params.premiumDebtRay and premium_to_liquidate < debt_ray_to_target:
        drawn_to_target: uint256 = (debt_ray_to_target - premium_to_liquidate) // params.drawnIndex + convert((debt_ray_to_target - premium_to_liquidate) % params.drawnIndex != 0, uint256)
        available: uint256 = params.debtToCover - WadRayMath.from_ray_up(premium_to_liquidate)
        drawn_to_cover: uint256 = SharesMath._mul_div_down(available, RAY, params.drawnIndex)
        drawn_to_liquidate = min(min(drawn_to_target, drawn_to_cover), params.drawnShares)

    debt_ray_remaining: uint256 = (params.drawnShares - drawn_to_liquidate) * params.drawnIndex + params.premiumDebtRay - premium_to_liquidate
    leaves_debt_dust: bool = drawn_to_liquidate < params.drawnShares and SpokeUtils.to_value(
        debt_ray_remaining,
        params.debtAssetDecimals,
        params.debtAssetPrice,
    ) < DUST_LIQUIDATION_THRESHOLD * RAY
    if leaves_debt_dust:
        return params.drawnShares, params.premiumDebtRay
    return drawn_to_liquidate, premium_to_liquidate


@view
def calculate_collateral_to_liquidate(params: CalculateCollateralToLiquidateParams) -> uint256:
    debt_ray: uint256 = params.drawnSharesToLiquidate * params.drawnIndex + params.premiumDebtRayToLiquidate
    collateral_amount: uint256 = SharesMath._mul_div_down(
        debt_ray,
        params.debtAssetPrice * params.collateralAssetUnit * params.liquidationBonus,
        params.debtAssetUnit * params.collateralAssetPrice * PERCENTAGE_FACTOR * RAY,
    )
    return staticcall IHub(params.collateralReserveHub).previewAddByAssets(params.collateralReserveAssetId, collateral_amount)


@view
def calculate_liquidation_amounts(params: ILiquidationLogic.CalculateLiquidationAmountsParams) -> ILiquidationLogic.LiquidationAmounts:
    collateral_unit: uint256 = 10 ** params.collateralAssetDecimals
    debt_unit: uint256 = 10 ** params.debtAssetDecimals
    bonus: uint256 = self.calculate_liquidation_bonus(
        params.healthFactorForMaxBonus,
        params.liquidationBonusFactor,
        params.healthFactor,
        params.maxLiquidationBonus,
    )
    debt_params: CalculateDebtToLiquidateParams = CalculateDebtToLiquidateParams(
        drawnShares=params.drawnShares,
        premiumDebtRay=params.premiumDebtRay,
        drawnIndex=params.drawnIndex,
        totalDebtValueRay=params.totalDebtValueRay,
        debtAssetDecimals=params.debtAssetDecimals,
        debtAssetUnit=debt_unit,
        debtAssetPrice=params.debtAssetPrice,
        debtToCover=params.debtToCover,
        collateralFactor=params.collateralFactor,
        liquidationBonus=bonus,
        healthFactor=params.healthFactor,
        targetHealthFactor=params.targetHealthFactor,
    )
    drawn_to_liquidate: uint256 = 0
    premium_to_liquidate: uint256 = 0
    drawn_to_liquidate, premium_to_liquidate = self.calculate_debt_to_liquidate(debt_params)
    collateral_params: CalculateCollateralToLiquidateParams = CalculateCollateralToLiquidateParams(
        collateralReserveHub=params.collateralReserveHub,
        collateralReserveAssetId=params.collateralReserveAssetId,
        collateralAssetUnit=collateral_unit,
        collateralAssetPrice=params.collateralAssetPrice,
        drawnSharesToLiquidate=drawn_to_liquidate,
        premiumDebtRayToLiquidate=premium_to_liquidate,
        drawnIndex=params.drawnIndex,
        debtAssetUnit=debt_unit,
        debtAssetPrice=params.debtAssetPrice,
        liquidationBonus=bonus,
    )
    collateral_to_liquidate: uint256 = self.calculate_collateral_to_liquidate(collateral_params)
    leaves_collateral_dust: bool = False
    if collateral_to_liquidate < params.suppliedShares:
        remaining: uint256 = staticcall IHub(params.collateralReserveHub).previewRemoveByShares(
            params.collateralReserveAssetId,
            params.suppliedShares - collateral_to_liquidate,
        )
        leaves_collateral_dust = SpokeUtils.to_value(remaining, params.collateralAssetDecimals, params.collateralAssetPrice) < DUST_LIQUIDATION_THRESHOLD

    if collateral_to_liquidate > params.suppliedShares or (leaves_collateral_dust and drawn_to_liquidate < params.drawnShares):
        collateral_to_liquidate = params.suppliedShares
        collateral_assets_up: uint256 = staticcall IHub(params.collateralReserveHub).previewAddByShares(
            params.collateralReserveAssetId,
            collateral_to_liquidate,
        )
        debt_ray: uint256 = SharesMath._mul_div_up(
            collateral_assets_up,
            params.collateralAssetPrice * debt_unit * PERCENTAGE_FACTOR * RAY,
            params.debtAssetPrice * collateral_unit * bonus,
        )
        if debt_ray <= params.premiumDebtRay:
            premium_to_liquidate = min(WadRayMath.round_ray_up(debt_ray), params.premiumDebtRay)
            drawn_to_liquidate = 0
        else:
            premium_to_liquidate = params.premiumDebtRay
            drawn_to_liquidate = (debt_ray - premium_to_liquidate) // params.drawnIndex + convert((debt_ray - premium_to_liquidate) % params.drawnIndex != 0, uint256)
            if drawn_to_liquidate > params.drawnShares:
                drawn_to_liquidate = params.drawnShares
                collateral_params.drawnSharesToLiquidate = drawn_to_liquidate
                collateral_params.premiumDebtRayToLiquidate = premium_to_liquidate
                collateral_to_liquidate = min(self.calculate_collateral_to_liquidate(collateral_params), params.suppliedShares)

    amount_to_restore: uint256 = WadRayMath.ray_mul_up(drawn_to_liquidate, params.drawnIndex) + WadRayMath.from_ray_up(premium_to_liquidate)
    if params.debtToCover < amount_to_restore:
        raise ISpoke.MustNotLeaveDust()
    fee_shares: uint256 = SharesMath._mul_div_up(
        collateral_to_liquidate,
        params.liquidationFee * (bonus - PERCENTAGE_FACTOR),
        bonus * PERCENTAGE_FACTOR,
    )
    return ILiquidationLogic.LiquidationAmounts(
        collateralSharesToLiquidate=collateral_to_liquidate,
        collateralSharesToLiquidator=collateral_to_liquidate - fee_shares,
        drawnSharesToLiquidate=drawn_to_liquidate,
        premiumDebtRayToLiquidate=premium_to_liquidate,
    )


@pure
def evaluate_deficit(is_collateral_empty: bool, is_debt_empty: bool, active_collateral_count: uint256, borrow_count: uint256) -> bool:
    if not is_collateral_empty or active_collateral_count > 1:
        return False
    return not is_debt_empty or borrow_count > 1
