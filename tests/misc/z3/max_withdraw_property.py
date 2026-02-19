# Proves that in maxWithdraw, we never have result > _maxRemovableAssets()
# where result = balance.min(maxRemovableAssets) and balance = previewRedeem(balanceOf(owner))
# Specifically: result <= _maxRemovableAssets()
#
# Also proves withdraw(maxWithdraw()) is OK:
# previewWithdraw(result) <= balanceShares — shares burned don't exceed owner's balance
from commons import *

def previewRedeem(shares, totalAddedAssets, totalAddedShares):
    """Converts shares to assets, rounding down (previewRemoveByShares)"""
    return previewRemoveByShares(shares, totalAddedAssets, totalAddedShares)

def previewWithdraw(assets, totalAddedAssets, totalAddedShares):
    """Converts assets to shares, rounding up (previewRemoveByAssets)"""
    return previewRemoveByAssets(assets, totalAddedAssets, totalAddedShares)

s = Solver()

totalAddedAssets = Int("totalAddedAssets")
totalAddedShares = Int("totalAddedShares")
maxRemovableAssets = Int("maxRemovableAssets")
balanceShares = Int("balanceShares")  # balanceOf(owner) in shares

balanceAssets = previewRedeem(balanceShares, totalAddedAssets, totalAddedShares)
result = min(balanceAssets, maxRemovableAssets)
sharesBurned = previewWithdraw(result, totalAddedAssets, totalAddedShares)

s.add(0 <= totalAddedAssets, totalAddedAssets <= 10**30)
s.add(0 <= totalAddedShares, totalAddedShares <= 10**30)
s.add(0 <= maxRemovableAssets, maxRemovableAssets <= 10**30)
s.add(0 <= balanceShares, balanceShares <= 10**30)
# maxRemovableAssets is just liquidity, which is part of totalAddedAssets
s.add(maxRemovableAssets <= totalAddedAssets)

# maxWithdraw result does not exceed liquidity
proveValid(s, "min(previewRedeem(balanceShares), maxRemovableAssets) <= _maxRemovableAssets()", result <= maxRemovableAssets)

# withdraw(maxWithdraw()) — shares burned don't exceed owner's balance
proveValid(s, "previewWithdraw(maxWithdraw()) <= balanceShares", sharesBurned <= balanceShares)
