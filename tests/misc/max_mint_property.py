# Proves that mint(maxMint()) satisfies Hub._validateAdd.
# maxMint = convertToShares(maxDeposit) = toAddedSharesDown(maxDeposit)
# When mint is called: assets = previewMint(maxMint) = toAddedAssetsUp(maxMint)
# _validateAdd checks: allowed >= toAddedAssetsUp(spokeShares) + assets
from z3 import *

VIRTUAL_SHARES = IntVal(10**6)
VIRTUAL_ASSETS = IntVal(10**6)


def mulDivDown(a, num, den):
    return (a * num) / den


def mulDivUp(a, num, den):
    return (a * num + den - 1) / den


def zeroFloorSub(a, b):
    return If(a > b, a - b, IntVal(0))

def toAddedAssetsUp(shares, totalAddedAssets, totalAddedShares):
    """Converts shares to assets, rounding up (previewAddByShares)"""
    return mulDivUp(
        shares, totalAddedAssets + VIRTUAL_ASSETS, totalAddedShares + VIRTUAL_SHARES
    )

def previewMint(shares, totalAddedAssets, totalAddedShares):
    """Converts shares to assets, rounding up (previewAddByShares)"""
    return toAddedAssetsUp(shares, totalAddedAssets, totalAddedShares)

def convertToShares(assets, totalAddedAssets, totalAddedShares):
    """Converts assets to shares, rounding down (previewAddByAssets)"""
    return mulDivDown(
        assets, totalAddedShares + VIRTUAL_SHARES, totalAddedAssets + VIRTUAL_ASSETS
    )


def check(s, propertyDescription):
    print(f"\n-- {propertyDescription} --")
    result = s.check()
    if result == sat:
        print("Counterexample found:", s.model())
    elif result == unsat:
        print("Property holds.")
    elif result == unknown:
        print("Timed out or unknown.")


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

s.add(Not(allowed >= hubCheck))
check(s, "mint(maxMint()) satisfies _validateAdd")
