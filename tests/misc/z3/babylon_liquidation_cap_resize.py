# Analyzes the cap-binding resize in BabylonLiquidationLogic._liquidateDebtReserve:
#
#   if (collateralSharesToLiquidate > maxRemovableShares) {
#     collateralSharesToLiquidate = maxRemovableShares;
#     debtRayToLiquidate = mulDivUp(previewAddByShares(maxRemovableShares), Y, X);
#     if (debtRayToLiquidate <= premiumDebtRay) {
#       premiumDebtRayToLiquidate = roundRayUp(debtRayToLiquidate).min(premiumDebtRay);
#       drawnSharesToLiquidate = 0;
#     } else {
#       premiumDebtRayToLiquidate = premiumDebtRay;
#       drawnSharesToLiquidate = divUp(debtRayToLiquidate - premiumDebtRay, index);
#     }
#   }
#
# Proves why the premium branch needs its clamp while the drawn branch does not:
# 1. The resized repayment never exceeds the initially sized repayment (core lemma).
# 2. The premium clamp `.min(premiumDebtRay)` does bind (it is needed).
# 3. The resized drawn shares never exceed the initially sized drawn shares, so they stay
#    within `debtToCover` and the user's drawn shares without a clamp.
from commons import *

s = Solver()

# Pricing of collateral asset
addedShares = Int("addedShares")
s.add(0 <= addedShares, addedShares <= MAX_SUPPLY_AMOUNT)
totalAddedAssets = Int("totalAddedAssets")
s.add(
    (addedShares + VIRTUAL_SHARES) <= (totalAddedAssets + VIRTUAL_ASSETS),
    (totalAddedAssets + VIRTUAL_ASSETS)
    <= MAX_SUPPLY_PRICE * (addedShares + VIRTUAL_SHARES),
)
collateralAssetPrice = Int("collateralAssetPrice")
s.add(1 <= collateralAssetPrice, collateralAssetPrice <= MAX_PRICE)
# Asset units kept as bounded symbols instead of 10**decimals, covering all decimal configs.
collateralAssetUnit = Int("collateralAssetUnit")
s.add(10**6 <= collateralAssetUnit, collateralAssetUnit <= 10**18)

# Pricing of debt asset
drawnIndex = Int("drawnIndex")
s.add(MIN_DRAWN_INDEX <= drawnIndex, drawnIndex <= MAX_DRAWN_INDEX)
debtAssetPrice = Int("debtAssetPrice")
s.add(1 <= debtAssetPrice, debtAssetPrice <= MAX_PRICE)
debtAssetUnit = Int("debtAssetUnit")
s.add(10**6 <= debtAssetUnit, debtAssetUnit <= 10**18)

# Liquidatable user position
drawnShares = Int("drawnShares")
s.add(1 <= drawnShares, drawnShares <= MAX_SUPPLY_AMOUNT)
premiumDebtRay = Int("premiumDebtRay")
s.add(0 <= premiumDebtRay, premiumDebtRay <= MAX_SUPPLY_AMOUNT * RAY)

# Liquidation parameters
liquidationBonus = Int("liquidationBonus")
s.add(
    MIN_LIQUIDATION_BONUS <= liquidationBonus,
    liquidationBonus <= MAX_LIQUIDATION_BONUS,
)
debtToCover = Int("debtToCover")
s.add(1 <= debtToCover, debtToCover <= MAX_SUPPLY_AMOUNT * 100)

# Initial sizing from debtToCover: premium debt is liquidated first
premiumLimited = debtToCover < fromRayUp(premiumDebtRay)
premiumDebtRayToLiquidate = If(premiumLimited, toRay(debtToCover), premiumDebtRay)
drawnSharesToLiquidate = If(
    premiumLimited,
    IntVal(0),
    min(
        mulDivDown(debtToCover - fromRayUp(premiumDebtRay), RAY, drawnIndex),
        drawnShares,
    ),
)
# The initially sized repayment, in units of debt asset scaled by RAY
initialDebtRay = drawnSharesToLiquidate * drawnIndex + premiumDebtRayToLiquidate

# Collateral shares priced from the initially sized repayment
collateralSharesToLiquidate = previewAddByAssets(
    mulDivDown(
        initialDebtRay,
        debtAssetPrice * collateralAssetUnit * liquidationBonus,
        debtAssetUnit * collateralAssetPrice * PERCENTAGE_FACTOR * RAY,
    ),
    totalAddedAssets,
    addedShares,
)

# The priced removal exceeds the cap
maxRemovableShares = Int("maxRemovableShares")
s.add(1 <= maxRemovableShares)
s.add(collateralSharesToLiquidate > maxRemovableShares)

# The repayment is resized to exactly consume the cap, with the inverse of the bonus pricing
resizedDebtRay = mulDivUp(
    previewAddByShares(maxRemovableShares, totalAddedAssets, addedShares),
    collateralAssetPrice * debtAssetUnit * PERCENTAGE_FACTOR * RAY,
    debtAssetPrice * collateralAssetUnit * liquidationBonus,
)

# Sanity: the cap-binding block is reachable, for both resize branches
proveSatisfiable(
    s,
    "cap exceeded and the resized repayment exceeds the premium (drawn branch reachable)",
    resizedDebtRay > premiumDebtRay,
)
proveSatisfiable(
    s,
    "cap exceeded and the resized repayment is within the premium (premium branch reachable)",
    And(resizedDebtRay <= premiumDebtRay, resizedDebtRay > 0),
)

# 1. Core lemma: the resized repayment never exceeds the initially sized repayment
proveValid(
    s,
    "resized repayment <= initially sized repayment",
    resizedDebtRay <= initialDebtRay,
)

# 2. Premium branch: the `.min(premiumDebtRayToLiquidate)` clamp is needed
def roundRayUp(a):
    return toRay(fromRayUp(a))

proveSatisfiable(
    s,
    "roundRayUp(resized repayment) > position premium (the premium min binds)",
    And(
        resizedDebtRay <= premiumDebtRay,
        roundRayUp(resizedDebtRay) > premiumDebtRay,
    ),
)

# 3. Drawn branch: the resized drawn shares stay within the initially sized ones, no clamp needed
proveValid(
    s,
    "resized drawn shares <= initially sized drawn shares (no clamp needed)",
    Implies(
        resizedDebtRay > premiumDebtRay,
        divUp(resizedDebtRay - premiumDebtRay, drawnIndex) <= drawnSharesToLiquidate,
    ),
)
