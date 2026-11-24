# Analyzes the collateral removal cap in BabylonLiquidationLogic, following the code order.
#
# _executeLiquidation converts the cap (assets) into shares, rounding down:
#
#   uint256 maxRemovableShares = params.collateralHub
#     .previewAddByAssets(params.collateralAssetId, params.maxCollateralToRemove)
#     .min(collateralUserPosition.suppliedShares);
#
# _calculateLiquidationAmounts resizes the repayment when the priced removal exceeds the cap:
#
#   if (collateralSharesToLiquidate > maxRemovableShares) {
#     collateralSharesToLiquidate = maxRemovableShares;
#     debtRayToLiquidate = mulDivUp(previewAddByShares(maxRemovableShares), Y, X);
#     if (debtRayToLiquidate <= premiumDebtRay) {
#       premiumDebtRayToLiquidate = roundRayUp(debtRayToLiquidate).min(premiumDebtRay);
#       drawnSharesToLiquidate = 0;
#     } else {
#       premiumDebtRayToLiquidate = premiumDebtRay;
#       drawnSharesToLiquidate = divUp(debtRayToLiquidate - premiumDebtRay, drawnIndex);
#     }
#   }
#
# 1. The collateral paid out to the liquidator never exceeds `maxCollateralToRemove`.
# 2. The user's collateral, valued in assets, decreases by no more than `maxCollateralToRemove`.
# 3. In the premium branch, the resized premium is within the initially sized premium.
# 4. In the drawn branch, the resized drawn shares are within the initially sized drawn shares.
# The initially sized amounts are already within `debtToCover` and the user's debt, so 3 and 4
# show the resize needs no further clamp.
#
# The solver holds the domain bounds. Branch conditions are passed as assumptions of the property
# they belong to, so no property restricts the space of another.
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
collateralAssetDecimals = Int("collateralAssetDecimals")
s.add(MIN_DECIMALS <= collateralAssetDecimals, collateralAssetDecimals <= MAX_DECIMALS)
collateralAssetUnit = ToInt(10**collateralAssetDecimals)

# Pricing of debt asset
drawnIndex = Int("drawnIndex")
s.add(MIN_DRAWN_INDEX <= drawnIndex, drawnIndex <= MAX_DRAWN_INDEX)
debtAssetPrice = Int("debtAssetPrice")
s.add(1 <= debtAssetPrice, debtAssetPrice <= MAX_PRICE)
debtAssetDecimals = Int("debtAssetDecimals")
s.add(MIN_DECIMALS <= debtAssetDecimals, debtAssetDecimals <= MAX_DECIMALS)
debtAssetUnit = ToInt(10**debtAssetDecimals)

# Liquidatable user position
suppliedShares = Int("suppliedShares")
s.add(0 <= suppliedShares, suppliedShares <= addedShares)
userCollateral = previewRemoveByShares(suppliedShares, totalAddedAssets, addedShares)
drawnShares = Int("drawnShares")
s.add(0 <= drawnShares, drawnShares <= MAX_SUPPLY_AMOUNT)
premiumDebtRay = Int("premiumDebtRay")
s.add(0 <= premiumDebtRay, premiumDebtRay <= MAX_SUPPLY_AMOUNT * RAY)

# Liquidation parameters
liquidationBonus = Int("liquidationBonus")
s.add(MIN_LIQUIDATION_BONUS <= liquidationBonus, liquidationBonus <= MAX_LIQUIDATION_BONUS)
debtToCover = Int("debtToCover")
s.add(1 <= debtToCover, debtToCover <= MAX_SUPPLY_AMOUNT)
maxCollateralToRemove = Int("maxCollateralToRemove")
s.add(0 <= maxCollateralToRemove, maxCollateralToRemove <= MAX_SUPPLY_AMOUNT)

# The cap converted into shares, rounding down and clipped to the position
maxRemovableShares = min(
    previewAddByAssets(maxCollateralToRemove, totalAddedAssets, addedShares),
    suppliedShares,
)

# 1. The payout never exceeds the cap
proveValid(
    s,
    "removed assets <= maxCollateralToRemove",
    previewRemoveByShares(maxRemovableShares, totalAddedAssets, addedShares)
    <= maxCollateralToRemove,
)

# 2. The user's collateral never decreases by more than the cap
remainingCollateral = previewRemoveByShares(
    suppliedShares - maxRemovableShares, totalAddedAssets, addedShares
)
proveValid(
    s,
    "user collateral decrease <= maxCollateralToRemove",
    userCollateral - remainingCollateral <= maxCollateralToRemove,
)

# Initial sizing from debtToCover: premium debt first, then drawn debt
premiumLimited = debtToCover < fromRayUp(premiumDebtRay)
premiumDebtRayToLiquidate = If(premiumLimited, toRay(debtToCover), premiumDebtRay)
drawnSharesToLiquidate = If(
    premiumLimited,
    IntVal(0),
    min(mulDivDown(debtToCover - fromRayUp(premiumDebtRay), RAY, drawnIndex), drawnShares),
)

# Collateral shares priced from the initial sizing (LiquidationLogic._calculateCollateralToLiquidate)
debtRayToLiquidate = drawnSharesToLiquidate * drawnIndex + premiumDebtRayToLiquidate
collateralSharesToLiquidate = previewAddByAssets(
    mulDivDown(
        debtRayToLiquidate,
        debtAssetPrice * collateralAssetUnit * liquidationBonus,
        debtAssetUnit * collateralAssetPrice * PERCENTAGE_FACTOR * RAY,
    ),
    totalAddedAssets,
    addedShares,
)

# When the cap binds, the repayment is resized with the inverse of the bonus pricing
capBinds = collateralSharesToLiquidate > maxRemovableShares
resizedDebtRayToLiquidate = mulDivUp(
    previewAddByShares(maxRemovableShares, totalAddedAssets, addedShares),
    collateralAssetPrice * debtAssetUnit * PERCENTAGE_FACTOR * RAY,
    debtAssetPrice * collateralAssetUnit * liquidationBonus,
)
drawnBranch = resizedDebtRayToLiquidate > premiumDebtRay


# 3. Premium branch
resizedPremiumDebtRayToLiquidate = min(roundRayUp(resizedDebtRayToLiquidate), premiumDebtRay)
proveValid(
    s,
    "resized premium debt <= initially sized premium debt",
    resizedPremiumDebtRayToLiquidate <= premiumDebtRayToLiquidate,
    assumptions=[capBinds, Not(drawnBranch)],
)

# 4. Drawn branch
resizedDrawnSharesToLiquidate = divUp(resizedDebtRayToLiquidate - premiumDebtRay, drawnIndex)
proveValid(
    s,
    "resized drawn shares <= initially sized drawn shares",
    resizedDrawnSharesToLiquidate <= drawnSharesToLiquidate,
    assumptions=[capBinds, drawnBranch],
)
