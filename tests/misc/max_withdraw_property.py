# Proves that in maxWithdraw, we never have result > _maxRemovableAssets()
# where result = balance.min(maxRemovableAssets) and balance = previewRedeem(balanceOf(owner))
# Specifically: result <= _maxRemovableAssets()
#
# Also proves withdraw(maxWithdraw()) is OK:
# previewWithdraw(result) <= balanceShares — shares burned don't exceed owner's balance
from z3 import *

VIRTUAL_SHARES = IntVal(10**6)
VIRTUAL_ASSETS = IntVal(10**6)

def mulDivDown(a, num, den):
    return (a * num) / den

def mulDivUp(a, num, den):
    return (a * num + den - 1) / den

def min(a, b):
    return If(a <= b, a, b)

def previewRedeem(shares, totalAddedAssets, totalAddedShares):
    """Converts shares to assets, rounding down (previewRemoveByShares)"""
    return mulDivDown(
        shares, totalAddedAssets + VIRTUAL_ASSETS, totalAddedShares + VIRTUAL_SHARES
    )

def previewWithdraw(assets, totalAddedAssets, totalAddedShares):
    """Converts assets to shares, rounding up (previewRemoveByAssets)"""
    return mulDivUp(
        assets, totalAddedShares + VIRTUAL_SHARES, totalAddedAssets + VIRTUAL_ASSETS
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

# Property 1: maxWithdraw result does not exceed liquidity
s.push()
s.add(Not(result <= maxRemovableAssets))
check("min(previewRedeem(balanceShares), maxRemovableAssets) <= _maxRemovableAssets()")
s.pop()

# Property 2: withdraw(maxWithdraw()) — shares burned don't exceed owner's balance
s.push()
s.add(Not(sharesBurned <= balanceShares))
check("previewWithdraw(maxWithdraw()) <= balanceShares")
s.pop()
