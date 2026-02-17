# Proves that mint(maxMint()) satisfies Hub._validateAdd.
# maxMint = convertToShares(maxDeposit) = toAddedSharesDown(maxDeposit)
# When mint is called: assets = previewMint(maxMint) = toAddedAssetsUp(maxMint)
# _validateAdd checks: allowed >= toAddedAssetsUp(spokeShares) + assets
from commons import *

def previewMint(shares, totalAddedAssets, totalAddedShares):
    """Converts shares to assets, rounding up (previewAddByShares)"""
    return previewAddByShares(shares, totalAddedAssets, totalAddedShares)

def convertToShares(assets, totalAddedAssets, totalAddedShares):
    """Converts assets to shares, rounding down (previewAddByAssets)"""
    return previewAddByAssets(assets, totalAddedAssets, totalAddedShares)

totalAddedAssets = Int("totalAddedAssets")
totalAddedShares = Int("totalAddedShares")
spokeShares = Int("spokeShares")
allowed = Int("allowed")

s = Solver()
s.add(0 <= totalAddedAssets, totalAddedAssets <= 10**30)
s.add(0 <= totalAddedShares, totalAddedShares <= 10**30)
s.add(0 <= spokeShares, spokeShares <= totalAddedShares)
s.add(0 < allowed, allowed <= 10**30)

# maxDeposit
balance = previewMint(spokeShares, totalAddedAssets, totalAddedShares)
maxDepositAmount = zeroFloorSub(allowed, balance)

# maxMint = convertToShares(maxDeposit) 
maxMintShares = convertToShares(maxDepositAmount, totalAddedAssets, totalAddedShares)

# _validateAdd: allowed >= toAddedAssetsUp(spokeShares) + mintAssets
mintAssets = toAddedAssetsUp(maxMintShares, totalAddedAssets, totalAddedShares)
s.add(mintAssets > 0)
hubCheck = toAddedAssetsUp(spokeShares, totalAddedAssets, totalAddedShares) + mintAssets

proveValid(s, "mint(maxMint()) satisfies _validateAdd", allowed >= hubCheck)
