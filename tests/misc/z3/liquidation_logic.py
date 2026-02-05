# Highlights the fact that debtToLiquidate cannot exceed debtReserveBalance in liquidation logic.
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
s.add(1 <= suppliedShares, suppliedShares <= addedShares)
drawnShares = Int("drawnShares")
s.add(1 <= drawnShares, drawnShares <= MAX_SUPPLY_AMOUNT)
premiumDebtRay = Int("premiumDebtRay")
s.add(0 <= premiumDebtRay, premiumDebtRay <= MAX_SUPPLY_AMOUNT)

# Liquidation parameters
liquidationBonus = Int("liquidationBonus")
s.add(
    MIN_LIQUIDATION_BONUS <= liquidationBonus,
    liquidationBonus <= MAX_LIQUIDATION_BONUS,
)
premiumDebtRayToLiquidate = Int("premiumDebtRayToLiquidate")
s.add(0 <= premiumDebtRayToLiquidate, premiumDebtRayToLiquidate <= premiumDebtRay)
rawDrawnSharesToLiquidate = Int("rawDrawnSharesToLiquidate")
s.add(0 <= rawDrawnSharesToLiquidate, rawDrawnSharesToLiquidate <= drawnShares)
s.add(Or(rawDrawnSharesToLiquidate == 0, premiumDebtRayToLiquidate == premiumDebtRay))

# Enforce debt dust condition
debtRayRemaining = (
    (drawnShares - rawDrawnSharesToLiquidate) * drawnIndex
    + premiumDebtRay
    - premiumDebtRayToLiquidate
)
leavesDebtDust = And(
    rawDrawnSharesToLiquidate < drawnShares,
    toValue(
        debtRayRemaining,
        debtAssetDecimals,
        debtAssetPrice,
    )
    < DUST_LIQUIDATION_THRESHOLD * RAY,
)
drawnSharesToLiquidate = Int("drawnSharesToLiquidate")
s.add(
    Or(
        And(Not(leavesDebtDust), drawnSharesToLiquidate == rawDrawnSharesToLiquidate),
        And(
            leavesDebtDust,
            drawnSharesToLiquidate == drawnShares,
            premiumDebtRayToLiquidate == premiumDebtRay,
        ),
    )
)

# Calculate collateral shares to liquidate
collateralSharesToLiquidate = previewAddByAssets(
    mulDivDown(
        drawnSharesToLiquidate * drawnIndex + premiumDebtRayToLiquidate,
        debtAssetPrice * collateralAssetUnit * liquidationBonus,
        debtAssetUnit * collateralAssetPrice * PERCENTAGE_FACTOR * RAY,
    ),
    totalAddedAssets,
    addedShares,
)

# Enforce recalculation of debt to liquidate
leavesCollateralDust = And(
    collateralSharesToLiquidate < suppliedShares,
    toValue(
        previewRemoveByShares(
            suppliedShares - collateralSharesToLiquidate,
            totalAddedAssets,
            addedShares,
        ),
        collateralAssetDecimals,
        collateralAssetPrice,
    )
    < DUST_LIQUIDATION_THRESHOLD,
)
s.add(
    Or(
        collateralSharesToLiquidate > suppliedShares,
        And(
            leavesCollateralDust,
            drawnSharesToLiquidate < drawnShares,
        ),
    ),
)

# Recalculate debt to liquidate
debtRayToLiquidate = mulDivUp(
    previewAddByShares(suppliedShares, totalAddedAssets, addedShares),
    collateralAssetPrice * debtAssetUnit * PERCENTAGE_FACTOR * RAY,
    debtAssetPrice * collateralAssetUnit * liquidationBonus,
)

# Enforce premium debt is fully liquidated
s.add(premiumDebtRay < debtRayToLiquidate)
recalculatedDrawnSharesToLiquidate = divUp(
    debtRayToLiquidate - premiumDebtRay, drawnIndex
)

proveSatisfiable(
    s,
    "Recalculated drawnSharesToLiquidate can exceed user's drawn shares",
    recalculatedDrawnSharesToLiquidate > drawnShares,
)

# Enforce recalculation of collateralSharesToLiquidate
s.add(recalculatedDrawnSharesToLiquidate > drawnShares)
recalculatedCollateralSharesToLiquidate = previewAddByAssets(
    mulDivDown(
        drawnShares * drawnIndex + premiumDebtRay,
        debtAssetPrice * collateralAssetUnit * liquidationBonus,
        debtAssetUnit * collateralAssetPrice * PERCENTAGE_FACTOR * RAY,
    ),
    totalAddedAssets,
    addedShares,
)

proveSatisfiable(
    s,
    "Recalculated collateralSharesToLiquidate can exceed user's supplied shares",
    recalculatedCollateralSharesToLiquidate > suppliedShares,
)
