# Highlights the fact that debtToCover is enforced correctly when premiumDebtRayToLiquidate is calculated.
from commons import *

s = Solver()

debtToCover = Int("debtToCover")
s.add(0 <= debtToCover, debtToCover <= MAX_SUPPLY_AMOUNT)

rawPremiumDebtRayToLiquidate = Int("rawPremiumDebtRayToLiquidate")
s.add(
    0 <= rawPremiumDebtRayToLiquidate, rawPremiumDebtRayToLiquidate <= MAX_SUPPLY_AMOUNT
)

expectedPremiumDebtRayToLiquidate = If(
    toRay(debtToCover) < rawPremiumDebtRayToLiquidate,
    toRay(debtToCover),
    rawPremiumDebtRayToLiquidate,
)

actualPremiumDebtRayToLiquidate = If(
    debtToCover <= fromRayDown(rawPremiumDebtRayToLiquidate),
    toRay(debtToCover),
    rawPremiumDebtRayToLiquidate,
)

proveValid(
    s,
    "debtToCover is enforced correctly when premiumDebtRayToLiquidate is calculated",
    actualPremiumDebtRayToLiquidate == expectedPremiumDebtRayToLiquidate,
)

actualPremiumDebtRayToLiquidate2 = If(
    debtToCover < fromRayUp(rawPremiumDebtRayToLiquidate),
    toRay(debtToCover),
    rawPremiumDebtRayToLiquidate,
)

proveValid(
    s,
    "debtToCover is enforced correctly when premiumDebtRayToLiquidate is calculated",
    actualPremiumDebtRayToLiquidate2 == expectedPremiumDebtRayToLiquidate,
)
