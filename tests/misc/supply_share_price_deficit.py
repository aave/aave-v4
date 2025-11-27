# Highlights the fact that totalAddedAssets does not decrease when a deficit is reported (hence the share price does not decrease).
from z3 import *

RAY = IntVal(10**27)

def divUp(a, b):
    return (a + b - 1) / b

def fromRayUp(a):
    return divUp(a, RAY)

def fromRayDown(a):
    return a / RAY

def rayMulUp(a, b):
    return (a * b + RAY - 1) / RAY

def rayMulDown(a, b):
    return (a * b) / RAY

def totalAddedAssets(drawnShares, premiumDebtRay, deficitRay, drawnIndex):
  # return rayMulUp(drawnShares, drawnIndex) + fromRayUp(premiumDebtRay) + fromRayUp(deficitRay)          # this is wrong
  # return rayMulDown(drawnShares, drawnIndex) + fromRayDown(premiumDebtRay) + fromRayDown(deficitRay)    # this is wrong
  return fromRayUp(drawnShares * drawnIndex + premiumDebtRay + deficitRay)

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

drawnShares = Int('drawnShares')
s.add(1 <= drawnShares, drawnShares <= 10**30)
drawnIndex = Int('drawnIndex')
s.add(RAY <= drawnIndex, drawnIndex < 100 * RAY)
premiumDebtRay = Int('premiumDebtRay')
s.add(0 <= premiumDebtRay, premiumDebtRay <= 10**30)
deficitRay = Int('deficitRay')
s.add(0 <= deficitRay, deficitRay <= 10**30)

deficitDrawnShares = Int('deficitDrawnShares')
s.add(0 <= deficitDrawnShares, deficitDrawnShares <= drawnShares)
deficitPremiumDebtRay = Int('deficitPremiumDebtRay')
s.add(0 <= deficitPremiumDebtRay, deficitPremiumDebtRay <= premiumDebtRay)

totalAddedAssetsBefore = totalAddedAssets(drawnShares, premiumDebtRay, deficitRay, drawnIndex)
totalAddedAssetsAfter = totalAddedAssets(drawnShares - deficitDrawnShares, premiumDebtRay - deficitPremiumDebtRay, deficitRay + deficitDrawnShares * drawnIndex + deficitPremiumDebtRay, drawnIndex)

s.push()
s.add(totalAddedAssetsBefore > totalAddedAssetsAfter)
check("Total added assets does not decrease after deficit is reported")