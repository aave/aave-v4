# Proves that in maxRedeem, we never have balance.toAssets > _maxRemovableAssets()
# where balance is the result from maxRedeem (balance.min(maxRemovableShares))
# Specifically: previewRedeem(result) <= _maxRemovableAssets()
#
# Also proves redeem(maxRedeem()) is OK:
# toAddedSharesUp(previewRedeem(result)) <= balance — Hub.remove share deduction doesn't exceed spoke shares
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


def convertToShares(assets, totalAddedAssets, totalAddedShares):
    """Converts assets to shares, rounding down (previewAddByAssets)"""
    return mulDivDown(
        assets, totalAddedShares + VIRTUAL_SHARES, totalAddedAssets + VIRTUAL_ASSETS
    )


def toAddedSharesUp(assets, totalAddedAssets, totalAddedShares):
    """Hub.remove's share calculation — rounds up (previewRemoveByAssets)"""
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
hubRemoveShares = toAddedSharesUp(resultAssets, totalAddedAssets, totalAddedShares)

# Property 1: redeemed assets don't exceed liquidity
s.push()
s.add(Not(resultAssets <= maxRemovableAssets))
check("previewRedeem(balance.min(maxRemovableShares)) <= _maxRemovableAssets()")
s.pop()

# Property 2: redeem(maxRedeem()) — Hub.remove share deduction doesn't exceed spoke shares
s.push()
s.add(Not(hubRemoveShares <= balance))
check("toAddedSharesUp(previewRedeem(maxRedeem())) <= balance")
s.pop()
