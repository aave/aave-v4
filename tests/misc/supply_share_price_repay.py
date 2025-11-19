# Highlights the fact that the supply share price does not decrease after a repay operation.
from z3 import *

RAY = IntVal(10**27)
PERCENTAGE_FACTOR = IntVal(10**4)
VIRTUAL_SHARES = IntVal(10**6)
VIRTUAL_ASSETS = IntVal(10**6)

def divUp(a, b):
    return (a + b - 1) / b

def check(propertyDescription):
    print(f"\n-- {propertyDescription} --")
    result = s.check()
    if result == sat:
        print("Counterexample found:")
        print(s.model())
    elif result == unsat:
        print(f"Property holds.")
    elif result == unknown:
        print("Timed out or unknown.")

s = Solver()

premiumRayBefore = Int('premiumRayBefore')
s.add(0 <= premiumRayBefore, premiumRayBefore <= 10**30)
premiumRestoredRay = Int('premiumRestoredRay')
s.add(0 <= premiumRestoredRay, premiumRestoredRay <= premiumRayBefore)

premiumRayAfter = premiumRayBefore - premiumRestoredRay
liquidityIncrease = divUp(premiumRestoredRay, RAY)
actualPremiumDebtDecrease = divUp(premiumRayBefore, RAY) - divUp(premiumRayAfter, RAY)

s.push()
# Supply share price does not decrease
s.add(simplify(actualPremiumDebtDecrease > liquidityIncrease))
check("Share price does not decrease after repay")