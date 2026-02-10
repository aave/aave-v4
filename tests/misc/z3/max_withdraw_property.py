# Proves that in maxWithdraw, we never have result > _maxRemovableAssets()
# where result = balance.min(maxRemovableAssets) and balance = previewRedeem(balanceOf(owner))
# Specifically: result <= _maxRemovableAssets()
from commons import *

def previewRedeem(shares, totalAddedAssets, totalAddedShares):
    """Converts shares to assets, rounding down (previewRemoveByShares)"""
    return previewRemoveByShares(shares, totalAddedAssets, totalAddedShares)

s = Solver()

totalAddedAssets = Int("totalAddedAssets")
totalAddedShares = Int("totalAddedShares")
maxRemovableAssets = Int("maxRemovableAssets")
balanceShares = Int("balanceShares")  # balanceOf(owner) in shares

s.add(0 <= totalAddedAssets, totalAddedAssets <= 10**30)
s.add(0 <= totalAddedShares, totalAddedShares <= 10**30)
s.add(0 <= maxRemovableAssets, maxRemovableAssets <= 10**30)
s.add(0 <= balanceShares, balanceShares <= 10**30)
# maxRemovableAssets is just liquidity, which is part of totalAddedAssets
s.add(maxRemovableAssets <= totalAddedAssets)

balanceAssets = previewRedeem(balanceShares, totalAddedAssets, totalAddedShares)
result = min(balanceAssets, maxRemovableAssets)

proveValid(s, "min(previewRedeem(balanceShares), maxRemovableAssets) <= _maxRemovableAssets()", result <= maxRemovableAssets)
