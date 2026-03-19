# Verifies the outcome of each calculation method for the asset liquidity cost of a
# withdraw action, to find which ones give a good representation of the reduction in
# the user's supplied assets — suitable for decreasing the taker withdraw allowance.
#
# Method A: toAddedAssetsUp(withdrawnShares)               — ceil conversion of burned shares
# Method B: previewRemoveByShares(before) - previewRemoveByShares(after) — delta of floor asset views
#           using updated totals after the withdraw (accounts for share price change)
# Method C: toAddedAssetsUp(toAddedSharesDown(amount))     — round-trip of the input amount
#
# The withdraw burns toAddedSharesUp(amount) shares and returns toAddedAssetsDown of those.
# Method B is the source of truth (actual change in user's asset position).
# Methods A and C are compared against B for divergence bounds.
from commons import *

s = Solver()
s.set("timeout", 300000)  # 5min per check

totalAddedShares = Int("totalAddedShares")
s.add(0 <= totalAddedShares, totalAddedShares <= MAX_SUPPLY_AMOUNT)
totalAddedAssets = Int("totalAddedAssets")
s.add(
    (totalAddedShares + VIRTUAL_SHARES) <= (totalAddedAssets + VIRTUAL_ASSETS),
    (totalAddedAssets + VIRTUAL_ASSETS)
    <= MAX_SUPPLY_PRICE * (totalAddedShares + VIRTUAL_SHARES),
)
userSuppliedShares = Int("userSuppliedShares")
withdrawAmount = Int("withdrawAmount")
s.add(0 <= userSuppliedShares, userSuppliedShares <= totalAddedShares)
s.add(1 <= withdrawAmount, withdrawAmount <= MAX_SUPPLY_AMOUNT)
s.add(withdrawAmount <= totalAddedAssets)

withdrawnShares = toAddedSharesUp(withdrawAmount, totalAddedAssets, totalAddedShares)
s.add(withdrawnShares <= userSuppliedShares)

userSuppliedBefore = previewRemoveByShares(userSuppliedShares, totalAddedAssets, totalAddedShares)

methodC = previewRemoveByShares(previewRemoveByAssets(withdrawAmount, totalAddedAssets, totalAddedShares), totalAddedAssets, totalAddedShares)

# After withdraw, totals change:
afterTotalAddedAssets = totalAddedAssets - withdrawAmount
afterTotalAddedShares = totalAddedShares - withdrawnShares

methodA = previewAddByShares(withdrawnShares, afterTotalAddedAssets, afterTotalAddedShares)

userSuppliedAfter = previewRemoveByShares(userSuppliedShares - withdrawnShares, afterTotalAddedAssets, afterTotalAddedShares)
methodB = userSuppliedBefore - userSuppliedAfter

# Safety (all methods >= actual withdrawn amount)
proveValid(s, "A >= withdrawAmount", methodA >= withdrawAmount)
proveValid(s, "B >= withdrawAmount", methodB >= withdrawAmount)
proveValid(s, "C >= withdrawAmount", methodC >= withdrawAmount)

# Divergence from B (source of truth)
proveValid(s, "A - B <= 2", methodA - methodB <= 2)
proveValid(s, "B - C <= 1", methodB - methodC <= 1)
