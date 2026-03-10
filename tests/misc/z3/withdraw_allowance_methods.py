# Verifies the outcome of each calculation method for the asset liquidity cost of a
# withdraw action, to find which ones give a good representation of the reduction in
# the user's supplied assets — suitable for decreasing the taker withdraw allowance.
#
# Method A: toAddedAssetsUp(withdrawnShares)               — ceil conversion of burned shares
# Method B: toAddedAssetsUp(before) - toAddedAssetsUp(after) — delta of ceil asset views
#           using updated totals after the withdraw (accounts for share price change)
# Method C: toAddedAssetsUp(toAddedSharesDown(amount))     — round-trip of the input amount
#
# The withdraw burns toAddedSharesUp(amount) shares and returns toAddedAssetsDown of those.
# Method B is the source of truth (actual change in user's asset position).
# Methods A and C are compared against B for divergence bounds.
from commons import *

s = Solver()
s.set("timeout", 300000)  # 5min per check

totalAddedAssets = Int("totalAddedAssets")
totalAddedShares = Int("totalAddedShares")
userShares = Int("userShares")
withdrawAmount = Int("withdrawAmount")

s.add(0 <= totalAddedAssets, totalAddedAssets <= 10**30)
s.add(0 <= totalAddedShares, totalAddedShares <= 10**30)
s.add(0 <= userShares, userShares <= totalAddedShares)
s.add(1 <= withdrawAmount, withdrawAmount <= 10**30)
s.add(withdrawAmount <= totalAddedAssets)

withdrawnShares = toAddedSharesUp(withdrawAmount, totalAddedAssets, totalAddedShares)
s.add(withdrawnShares <= userShares)

userSuppliedBefore = toAddedAssetsUp(userShares, totalAddedAssets, totalAddedShares)

roundTripShares = toAddedSharesDown(withdrawAmount, totalAddedAssets, totalAddedShares)
methodC = toAddedAssetsUp(roundTripShares, totalAddedAssets, totalAddedShares)

# After withdraw, totals change:
afterTotalAddedAssets = totalAddedAssets - withdrawAmount
afterTotalAddedShares = totalAddedShares - withdrawnShares

methodA = toAddedAssetsUp(withdrawnShares, afterTotalAddedAssets, afterTotalAddedShares)

userSuppliedAfter = toAddedAssetsUp(userShares - withdrawnShares, afterTotalAddedAssets, afterTotalAddedShares)
methodB = userSuppliedBefore - userSuppliedAfter

# Safety (all methods >= actual withdrawn amount)
proveValid(s, "A >= withdrawAmount", methodA >= withdrawAmount)
proveValid(s, "B >= withdrawAmount", methodB >= withdrawAmount)
proveValid(s, "C >= withdrawAmount", methodC >= withdrawAmount)

# Divergence from B (source of truth)
proveValid(s, "A - B <= 2", methodA - methodB <= 2)
proveValid(s, "B - C <= 2", methodB - methodC <= 2)
