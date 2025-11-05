# Highlights the fact that supplies shares are always equal to removed shares (after doing the conversion to assets and back to shares).
from z3 import *

WAD = IntVal(10**18)
VIRTUAL_SHARES = IntVal(10**6)
VIRTUAL_ASSETS = IntVal(10**6)

def mulDivDown(a, num, den):
    return (a * num) / den

def mulDivUp(a, num, den):
    return (a * num + den - 1) / den

def previewRemoveByShares(shares, totalAddedAssets, totalAddedShares):
    return mulDivDown(shares, totalAddedAssets + VIRTUAL_ASSETS, totalAddedShares + VIRTUAL_SHARES)

def previewRemoveByAssets(assets, totalAddedAssets, totalAddedShares):
    return mulDivUp(assets, totalAddedShares + VIRTUAL_SHARES, totalAddedAssets + VIRTUAL_ASSETS)

def check(propertyDescription):
    print(f"\n-- {propertyDescription} --")
    result = s.check()
    if result == sat:
        print("Counterexample found:")
        print(s.model())
    elif result == unsat:
        print(f"Property holds.")
    elif result == unknown:
        print("Timed out or unknown.")

s = Solver()

totalAddedAssets = Int('totalAddedAssets')
s.add(0 <= totalAddedAssets, totalAddedAssets <= 10**30)
totalAddedShares = Int('totalAddedShares')
s.add(totalAddedAssets >= totalAddedShares, totalAddedAssets + VIRTUAL_ASSETS < (totalAddedShares + VIRTUAL_SHARES) * 100)
suppliedShares = Int('suppliedShares')
s.add(0 <= suppliedShares, suppliedShares <= totalAddedShares)

withdrawableAssets = previewRemoveByShares(suppliedShares, totalAddedAssets, totalAddedShares)
removedShares = previewRemoveByAssets(withdrawableAssets, totalAddedAssets, totalAddedShares)

s.add(removedShares != suppliedShares)
check("Supplies shares are always equal to removed shares (after doing the conversion to assets and back to shares).")