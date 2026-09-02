# pragma version 0.5.0b1

from spoke.libraries import LiquidationLogic
from spoke.interfaces import ILiquidationLogic

implements: ILiquidationLogic

@external
@pure
def calculateLiquidationBonus(healthFactorForMaxBonus: uint256, liquidationBonusFactor: uint256, healthFactor: uint256, maxLiquidationBonus: uint256) -> uint256:
    return LiquidationLogic.calculate_liquidation_bonus(healthFactorForMaxBonus, liquidationBonusFactor, healthFactor, maxLiquidationBonus)


@external
@view
def validateLiquidationCall(params: ILiquidationLogic.ValidateLiquidationCallParams) -> bool:
    LiquidationLogic.validate_liquidation_call(params)
    return True


@external
@pure
def calculateDebtToTargetHealthFactor(params: LiquidationLogic.CalculateDebtToTargetHealthFactorParams) -> uint256:
    return LiquidationLogic.calculate_debt_to_target_health_factor(params)


@external
@pure
def calculateDebtToLiquidate(params: LiquidationLogic.CalculateDebtToLiquidateParams) -> (uint256, uint256):
    return LiquidationLogic.calculate_debt_to_liquidate(params)


@external
@view
def calculateCollateralToLiquidate(params: LiquidationLogic.CalculateCollateralToLiquidateParams) -> uint256:
    return LiquidationLogic.calculate_collateral_to_liquidate(params)


@external
@view
def calculateLiquidationAmounts(params: ILiquidationLogic.CalculateLiquidationAmountsParams) -> ILiquidationLogic.LiquidationAmounts:
    return LiquidationLogic.calculate_liquidation_amounts(params)


@external
@pure
def evaluateDeficit(isCollateralPositionEmpty: bool, isDebtPositionEmpty: bool, activeCollateralCount: uint256, borrowCount: uint256) -> bool:
    return LiquidationLogic.evaluate_deficit(isCollateralPositionEmpty, isDebtPositionEmpty, activeCollateralCount, borrowCount)
