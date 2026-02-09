# Proves maxDeposit rounding: deposit(maxDeposit()) must satisfy Hub._validateAdd.
# _validateAdd checks: allowed >= toAddedAssetsUp(spokeShares) + depositAmount
from z3 import *

VIRTUAL_SHARES = IntVal(10**6)
VIRTUAL_ASSETS = IntVal(10**6)


def mulDivDown(a, num, den):
    return (a * num) / den


def mulDivUp(a, num, den):
    return (a * num + den - 1) / den


def zeroFloorSub(a, b):
    return If(a > b, a - b, IntVal(0))


def toAddedAssetsDown(shares, totalAddedAssets, totalAddedShares):
    """previewRedeem / previewRemoveByShares — rounds down"""
    return mulDivDown(
        shares, totalAddedAssets + VIRTUAL_ASSETS, totalAddedShares + VIRTUAL_SHARES
    )


def toAddedAssetsUp(shares, totalAddedAssets, totalAddedShares):
    """previewMint / previewAddByShares — rounds up"""
    return mulDivUp(
        shares, totalAddedAssets + VIRTUAL_ASSETS, totalAddedShares + VIRTUAL_SHARES
    )


def check(propertyDescription):
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

balance = toAddedAssetsUp(spokeShares, totalAddedAssets, totalAddedShares)
depositAmount = zeroFloorSub(allowed, balance)
hubCheck = (
    toAddedAssetsUp(spokeShares, totalAddedAssets, totalAddedShares) + depositAmount
)

s.push()
s.add(depositAmount > 0)
s.add(Not(allowed >= hubCheck))
check("deposit(maxDeposit()) satisfies _validateAdd")
s.pop()
