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

def divUp(a, b):
    return (a + b - 1) / b

def premiumDebtRay(realizedPremiumRay, premiumShares, drawnIndex, premiumOffsetRay):
    return realizedPremiumRay + premiumShares * drawnIndex - premiumOffsetRay

def premiumDebt(realizedPremiumRay, premiumShares, drawnIndex, premiumOffsetRay):
    return divUp(premiumDebtRay(realizedPremiumRay, premiumShares, drawnIndex, premiumOffsetRay), RAY)

def unrealizedFeeAmount(drawnShares, previousIndex, drawnIndex, realizedPremiumRay, premiumShares, premiumOffsetRay, liquidityFee):
    liquidityGrowthDrawn = rayMulUp(drawnShares, drawnIndex) - rayMulUp(drawnShares, previousIndex)
    liquidityGrowthPremium = premiumDebt(realizedPremiumRay, premiumShares, drawnIndex, premiumOffsetRay) - premiumDebt(realizedPremiumRay, premiumShares, previousIndex, premiumOffsetRay)
    # wrongLiquidityGrowthPremium = divUp(premiumDebtRay(realizedPremiumRay, premiumShares, drawnIndex, premiumOffsetRay) - premiumDebtRay(realizedPremiumRay, premiumShares, previousIndex, premiumOffsetRay), RAY)
    return percentMulDown(liquidityGrowthDrawn + liquidityGrowthPremium, liquidityFee)

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
premiumOffsetRay = premiumShares * RAY
realizedPremiumRay = Int('realizedPremiumRay')
s.add(0 <= realizedPremiumRay, realizedPremiumRay <= 10**30)
liquiditySweptDeficit= Int('liquiditySweptDeficit')
s.add(0 <= liquiditySweptDeficit, liquiditySweptDeficit <= 10**30)

# T1: accrue
feeAmount1 = unrealizedFeeAmount(drawnShares, RAY, drawnIndex1, realizedPremiumRay, premiumShares, premiumOffsetRay, liquidityFee)
totalAddedAssets1 = liquiditySweptDeficit + rayMulUp(drawnShares, drawnIndex1) + premiumDebt(realizedPremiumRay, premiumShares, drawnIndex1, premiumOffsetRay) - feeAmount1
newRealizedPremiumRay = realizedPremiumRay + premiumShares * drawnIndex1 - premiumOffsetRay
newPremiumOffsetRay = premiumShares * drawnIndex1

# T2: preview
feeAmount2 = feeAmount1 + unrealizedFeeAmount(drawnShares, drawnIndex1, drawnIndex2, newRealizedPremiumRay, premiumShares, newPremiumOffsetRay, liquidityFee)
totalAddedAssets2 = liquiditySweptDeficit + rayMulUp(drawnShares, drawnIndex2) + premiumDebt(newRealizedPremiumRay, premiumShares, drawnIndex2, newPremiumOffsetRay) - feeAmount2

# T3: preview
feeAmount3 = feeAmount1 + unrealizedFeeAmount(drawnShares, drawnIndex1, drawnIndex3, newRealizedPremiumRay, premiumShares, newPremiumOffsetRay, liquidityFee)
totalAddedAssets3 = liquiditySweptDeficit + rayMulUp(drawnShares, drawnIndex3) + premiumDebt(newRealizedPremiumRay, premiumShares, drawnIndex3, newPremiumOffsetRay) - feeAmount3

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