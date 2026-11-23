# Highlights the fact that totalAddedAssets does not decrease when a deficit is reported (hence the share price does not decrease).
from commons import *


def totalAddedAssets(drawnShares, premiumDebtRay, deficitRay, drawnIndex):
    # return rayMulUp(drawnShares, drawnIndex) + fromRayUp(premiumDebtRay) + fromRayUp(deficitRay)          # this is wrong
    # return rayMulDown(drawnShares, drawnIndex) + fromRayDown(premiumDebtRay) + fromRayDown(deficitRay)    # this is wrong
    return fromRayUp(drawnShares * drawnIndex + premiumDebtRay + deficitRay)


s = Solver()

drawnShares = Int('drawnShares')
s.add(1 <= drawnShares, drawnShares <= MAX_SUPPLY_AMOUNT)
drawnIndex = Int('drawnIndex')
s.add(RAY <= drawnIndex, drawnIndex < 100 * RAY)
premiumDebtRay = Int('premiumDebtRay')
s.add(0 <= premiumDebtRay, premiumDebtRay <= MAX_SUPPLY_AMOUNT)
deficitRay = Int('deficitRay')
s.add(0 <= deficitRay, deficitRay <= MAX_SUPPLY_AMOUNT)

deficitDrawnShares = Int('deficitDrawnShares')
s.add(0 <= deficitDrawnShares, deficitDrawnShares <= drawnShares)
deficitPremiumDebtRay = Int('deficitPremiumDebtRay')
s.add(0 <= deficitPremiumDebtRay, deficitPremiumDebtRay <= premiumDebtRay)

totalAddedAssetsBefore = totalAddedAssets(
    drawnShares, premiumDebtRay, deficitRay, drawnIndex
)
totalAddedAssetsAfter = totalAddedAssets(
    drawnShares - deficitDrawnShares,
    premiumDebtRay - deficitPremiumDebtRay,
    deficitRay + deficitDrawnShares * drawnIndex + deficitPremiumDebtRay,
    drawnIndex,
)

proveValid(
    s,
    'Total added assets does not decrease after deficit is reported',
    totalAddedAssetsAfter >= totalAddedAssetsBefore,
)
