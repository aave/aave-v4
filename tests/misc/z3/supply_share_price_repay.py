# Highlights the fact that the supply share price does not decrease after a repay operation.
from commons import *

s = Solver()

premiumRayBefore = Int('premiumRayBefore')
s.add(0 <= premiumRayBefore, premiumRayBefore <= MAX_SUPPLY_AMOUNT)
premiumRestoredRay = Int('premiumRestoredRay')
s.add(0 <= premiumRestoredRay, premiumRestoredRay <= premiumRayBefore)

premiumRayAfter = premiumRayBefore - premiumRestoredRay
liquidityIncrease = divUp(premiumRestoredRay, RAY)
actualPremiumDebtDecrease = divUp(premiumRayBefore, RAY) - divUp(premiumRayAfter, RAY)

proveValid(
    s,
    'Share price does not decrease after repay',
    liquidityIncrease >= actualPremiumDebtDecrease,
)
