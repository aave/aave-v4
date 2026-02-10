# Proves that in maxRedeem, we never have balance.toAssets > _maxRemovableAssets()
# where balance is the result from maxRedeem (balance.min(maxRemovableShares))
# Specifically: previewRedeem(result) <= _maxRemovableAssets()
from commons import *

def previewRedeem(shares, totalAddedAssets, totalAddedShares):
    """Converts shares to assets, rounding down (previewRemoveByShares)"""
    return previewRemoveByShares(shares, totalAddedAssets, totalAddedShares)

def convertToShares(assets, totalAddedAssets, totalAddedShares):
    """Converts assets to shares, rounding down (previewAddByAssets)"""
    return previewAddByAssets(assets, totalAddedAssets, totalAddedShares)

s = Solver()

totalAddedAssets = Int("totalAddedAssets")
totalAddedShares = Int("totalAddedShares")
maxRemovableAssets = Int("maxRemovableAssets")  
balance = Int("balance")  # balanceOf(owner) in shares

s.add(0 <= totalAddedAssets, totalAddedAssets <= 10**30)
s.add(0 <= totalAddedShares, totalAddedShares <= 10**30)
s.add(0 <= maxRemovableAssets, maxRemovableAssets <= 10**30)
s.add(0 <= balance, balance <= 10**30)
# maxRemovableAssets is just liquidity, which is part of totalAddedAssets
s.add(maxRemovableAssets <= totalAddedAssets)

maxRemovableShares = convertToShares(
    maxRemovableAssets, totalAddedAssets, totalAddedShares
)

result = min(balance, maxRemovableShares)
resultAssets = previewRedeem(result, totalAddedAssets, totalAddedShares)

proveValid(s, "previewRedeem(balance.min(maxRemovableShares)) <= _maxRemovableAssets()", resultAssets <= maxRemovableAssets)
