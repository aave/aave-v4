# Highlights the fact that debtToLiquidate cannot exceed debtReserveBalance in liquidation logic.
from z3 import *

WAD = IntVal(10**18)
PERCENTAGE_FACTOR = IntVal(10**4)

DUST_LIQUIDATION_THRESHOLD = IntVal(1000 * 10**26)

def mulDivDown(a, num, den):
    return (a * num) / den

def mulDivUp(a, num, den):
    return (a * num + den - 1) / den

s = Solver()

debtAssetPrice = Int('debtAssetPrice')
s.add(1 <= debtAssetPrice, debtAssetPrice <= 10**30)
debtAssetDecimals = Int('debtAssetDecimals')
s.add(1 <= debtAssetDecimals, debtAssetDecimals <= 18)
debtAssetUnit = ToInt(10**debtAssetDecimals)

collateralAssetPrice = Int('collateralAssetPrice')
s.add(1 <= collateralAssetPrice, collateralAssetPrice <= 10**30)
collateralAssetDecimals = Int('collateralAssetDecimals')
s.add(1 <= collateralAssetDecimals, collateralAssetDecimals <= 18)
collateralAssetUnit = ToInt(10**collateralAssetDecimals)

liquidationBonus = Int('liquidationBonus')
s.add(PERCENTAGE_FACTOR <= liquidationBonus, liquidationBonus < PERCENTAGE_FACTOR * PERCENTAGE_FACTOR)

debtReserveBalance = Int('debtReserveBalance')
s.add(0 <= debtReserveBalance, debtReserveBalance <= 10**30)
debtToLiquidate = Int('debtToLiquidate')
s.add(0 <= debtToLiquidate, debtToLiquidate <= debtReserveBalance)

collateralReserveBalance = Int('collateralReserveBalance')
s.add(0 <= collateralReserveBalance, collateralReserveBalance <= 10**30)
collateralToLiquidate = Int('collateralToLiquidate')
s.add(collateralToLiquidate == mulDivDown(debtToLiquidate, debtAssetPrice * collateralAssetUnit * liquidationBonus, debtAssetUnit * collateralAssetPrice * PERCENTAGE_FACTOR))

s.add(
  Or(
    collateralToLiquidate > collateralReserveBalance,
    And(
      mulDivDown(collateralReserveBalance - collateralToLiquidate, collateralAssetPrice * WAD, collateralAssetUnit) < DUST_LIQUIDATION_THRESHOLD,
      DUST_LIQUIDATION_THRESHOLD <= mulDivDown(debtReserveBalance - debtToLiquidate, debtAssetPrice * WAD, debtAssetUnit)
    )
  )
)

s.add(
  Not(
    mulDivUp(
      collateralReserveBalance,
      collateralAssetPrice * debtAssetUnit * PERCENTAGE_FACTOR,
      debtAssetPrice * collateralAssetUnit * liquidationBonus
    ) <= debtReserveBalance
  )
)

print(s.model() if s.check() == sat else 'no counterexample')
