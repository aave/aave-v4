# Analyzes the conversion of the remaining removal cap (assets) into `maxRemovableShares` in
# BabylonLiquidationLogic._liquidateDebtReserves, performed before each repayment:
#
#   uint256 maxRemovableShares = params.collateralHub
#     .previewAddByAssets(params.collateralAssetId, remainingCollateralToRemove)
#     .min(collateralUserPosition.suppliedShares);
#
# When the cap is enforced, exactly `maxRemovableShares` shares are removed and the payout is
# `previewRemoveByShares(maxRemovableShares)` (LiquidationLogic._liquidateCollateral). The cap
# conversion must therefore round down: `previewAddByAssets` (toAddedSharesDown) keeps the payout
# within `maxCollateralToRemove`, while `previewRemoveByAssets` (toAddedSharesUp) answers "how
# many shares must be burned to receive at least these assets" and can overshoot the cap.
# 1. With `previewRemoveByAssets`, the removed assets can exceed `maxCollateralToRemove`.
# 2. With `previewAddByAssets`, the removed assets never exceed `maxCollateralToRemove`.
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

# The removal cap, in units of collateral asset
maxCollateralToRemove = Int("maxCollateralToRemove")
s.add(1 <= maxCollateralToRemove, maxCollateralToRemove <= MAX_SUPPLY_AMOUNT)

# The user's collateral position covers the cap in both variants, so the cap is enforced unclipped
suppliedShares = Int("suppliedShares")
s.add(0 <= suppliedShares, suppliedShares <= addedShares)

maxRemovableSharesUp = previewRemoveByAssets(
    maxCollateralToRemove, totalAddedAssets, addedShares
)
maxRemovableSharesDown = previewAddByAssets(
    maxCollateralToRemove, totalAddedAssets, addedShares
)
s.add(maxRemovableSharesUp <= suppliedShares)

# 1. The rounded-up cap can pay out more than `maxCollateralToRemove`
proveSatisfiable(
    s,
    "previewRemoveByAssets cap: removed assets > maxCollateralToRemove",
    previewRemoveByShares(maxRemovableSharesUp, totalAddedAssets, addedShares)
    > maxCollateralToRemove,
)

# 2. The rounded-down cap never pays out more than `maxCollateralToRemove`
proveValid(
    s,
    "previewAddByAssets cap: removed assets <= maxCollateralToRemove",
    previewRemoveByShares(maxRemovableSharesDown, totalAddedAssets, addedShares)
    <= maxCollateralToRemove,
)
