# Verifies the outcome of each calculation method for the asset cost of a
# borrow action, to find which ones give a good representation of the increase
# in the user's debt — suitable for decreasing the taker borrow allowance.
#
# Debt uses RAY-index math (not virtual-shares math like supply).
#   borrowedShares = rayDivUp(amount, drawnIndex)
#   drawnIndex does NOT change during a single borrow.
#
# Method A: rayMulUp(borrowedShares, drawnIndex)
#           — direct round-trip of borrowed shares back to assets
# Method B: rayMulUp(userDrawnShares + borrowedShares, drawnIndex) - rayMulUp(userDrawnShares, drawnIndex)
#           — before/after delta of user drawn debt
#
# Both methods should always be >= borrowAmount (safety).
# We verify whether A == B always holds and bound any divergence.
from commons import *

s = Solver()
s.set("timeout", 300000)  # 5min per check

drawnIndex = Int("drawnIndex")
userDrawnShares = Int("userDrawnShares")
borrowAmount = Int("borrowAmount")

s.add(MIN_DRAWN_INDEX <= drawnIndex, drawnIndex <= MAX_DRAWN_INDEX)
s.add(0 <= userDrawnShares, userDrawnShares <= MAX_SUPPLY_AMOUNT)
s.add(1 <= borrowAmount, borrowAmount <= MAX_SUPPLY_AMOUNT)


borrowedShares = toDrawnSharesUp(borrowAmount, drawnIndex)

# Method A: direct round-trip
methodA = toDrawnAssetsUp(borrowedShares, drawnIndex)

# Method B: before/after delta
userDebtBefore = toDrawnAssetsUp(userDrawnShares, drawnIndex)
userDebtAfter = toDrawnAssetsUp(userDrawnShares + borrowedShares, drawnIndex)
methodB = userDebtAfter - userDebtBefore

# Safety (both methods >= actual borrow amount)
proveValid(s, "A >= borrowAmount", methodA >= borrowAmount)
proveValid(s, "B >= borrowAmount", methodB >= borrowAmount)

# Equality check
proveValid(s, "A == B", methodA == methodB)

# Divergence bounds (in case A != B)
proveValid(s, "A >= B", methodA >= methodB)
proveValid(s, "A - B <= 1", methodA - methodB <= 1)
