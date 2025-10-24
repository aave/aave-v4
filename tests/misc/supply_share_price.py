# Highlights the fact that the supply share price does not decrease between accruals/previews due to fees. 
# Note that minting fee shares is equivalent to an add operation, which is known to not decrease the share price.
from z3 import *

RAY = IntVal(10**27)
PERCENTAGE_FACTOR = IntVal(10**4)
VIRTUAL_SHARES = IntVal(10**6)
VIRTUAL_ASSETS = IntVal(10**6)

def rayMulDown(a, b):
    return (a * b) / RAY

def rayMulUp(a, b):
    return (a * b + RAY - 1) / RAY

def percentMulDown(a, b):
    return (a * b) / PERCENTAGE_FACTOR

def unrealizedFeeAmount(drawnShares, premiumShares, drawnIndex1, drawnIndex2, liquidityFee):
    return percentMulDown(rayMulUp(drawnShares, drawnIndex2) - rayMulUp(drawnShares, drawnIndex1) + rayMulUp(premiumShares, drawnIndex2) - rayMulUp(premiumShares, drawnIndex1), liquidityFee)

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

liquidityFee = Int('liquidityFee')
s.add(0 <= liquidityFee, liquidityFee <= PERCENTAGE_FACTOR)

drawnIndex1 = Int('drawnIndex1')
s.add(RAY <= drawnIndex1, drawnIndex1 < 100 * RAY)
drawnIndex2 = Int('drawnIndex2')
s.add(drawnIndex1 <= drawnIndex2, drawnIndex2 < 100 * RAY)
drawnIndex3 = Int('drawnIndex3')
s.add(drawnIndex2 <= drawnIndex3, drawnIndex3 < 100 * RAY)

drawnShares = Int('drawnShares')
s.add(1 <= drawnShares, drawnShares <= 10**30)
premiumShares = Int('premiumShares')
s.add(0 <= premiumShares, premiumShares <= 10**30)
premiumOffset = Int('premiumOffset')
s.add(0 <= premiumOffset, premiumOffset <= rayMulDown(premiumShares, drawnIndex1))
liquiditySweptDeficitRealizedPremium = Int('liquiditySweptDeficitRealizedPremium')
s.add(0 <= liquiditySweptDeficitRealizedPremium, liquiditySweptDeficitRealizedPremium <= 10**30)

# T1: accrue/preview
feeAmount1 = unrealizedFeeAmount(drawnShares, premiumShares, RAY, drawnIndex1, liquidityFee)
totalAddedAssets1 = liquiditySweptDeficitRealizedPremium + rayMulUp(drawnShares, drawnIndex1) + rayMulUp(premiumShares, drawnIndex1) - premiumOffset - feeAmount1

# T2: accrue/preview
feeAmount2 = feeAmount1 + unrealizedFeeAmount(drawnShares, premiumShares, drawnIndex1, drawnIndex2, liquidityFee)
totalAddedAssets2 = liquiditySweptDeficitRealizedPremium + rayMulUp(drawnShares, drawnIndex2) + rayMulUp(premiumShares, drawnIndex2) - premiumOffset - feeAmount2

# T3: accrue/preview
feeAmount3 = feeAmount2 + unrealizedFeeAmount(drawnShares, premiumShares, drawnIndex2, drawnIndex3, liquidityFee)
totalAddedAssets3 = liquiditySweptDeficitRealizedPremium + rayMulUp(drawnShares, drawnIndex3) + rayMulUp(premiumShares, drawnIndex3) - premiumOffset - feeAmount3

s.push()
# Shares remain constant
s.add(simplify(totalAddedAssets1 > totalAddedAssets2))
check("Share price does not decrease from T1 to T2")
s.pop()

s.push()
# Shares remain constant
s.add(simplify(totalAddedAssets2 > totalAddedAssets3))
check("Share price does not decrease from T2 to T3")
s.pop()
