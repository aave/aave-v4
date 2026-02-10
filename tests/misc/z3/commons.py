from z3 import *

WAD = IntVal(10**18)
RAY = IntVal(10**27)
PERCENTAGE_FACTOR = IntVal(10**4)

VIRTUAL_SHARES = IntVal(10**6)
VIRTUAL_ASSETS = IntVal(10**6)

MAX_PRICE = IntVal(10**16)
MAX_SUPPLY_AMOUNT = IntVal(10**30)

MIN_DECIMALS = IntVal(6)
MAX_DECIMALS = IntVal(18)

MIN_DRAWN_INDEX = RAY
MAX_DRAWN_INDEX = 100 * RAY
MAX_SUPPLY_PRICE = IntVal(100)

MIN_LIQUIDATION_BONUS = PERCENTAGE_FACTOR
MAX_LIQUIDATION_BONUS = PERCENTAGE_FACTOR * PERCENTAGE_FACTOR - 1
DUST_LIQUIDATION_THRESHOLD = IntVal(1000 * 10**26)


def mulDivDown(a, num, den):
    return (a * num) / den


def mulDivUp(a, num, den):
    return (a * num + den - 1) / den


def divUp(a, b):
    return (a + b - 1) / b


def rayMulUp(a, b):
    return (a * b + RAY - 1) / RAY


def rayMulDown(a, b):
    return (a * b) / RAY


def fromRayDown(a):
    return a / RAY


def fromRayUp(a):
    return (a + RAY - 1) / RAY


def toRay(a):
    return a * RAY

def min(a, b):
    return If(a <= b, a, b)

def toAddedSharesDown(assets, totalAddedAssets, addedShares):
    return mulDivDown(
        assets, addedShares + VIRTUAL_SHARES, totalAddedAssets + VIRTUAL_ASSETS
    )


def toAddedAssetsDown(shares, totalAddedAssets, addedShares):
    return mulDivDown(
        shares, totalAddedAssets + VIRTUAL_ASSETS, addedShares + VIRTUAL_SHARES
    )


def toAddedSharesUp(assets, totalAddedAssets, addedShares):
    return mulDivUp(
        assets, addedShares + VIRTUAL_SHARES, totalAddedAssets + VIRTUAL_ASSETS
    )


def toAddedAssetsUp(shares, totalAddedAssets, addedShares):
    return mulDivUp(
        shares, totalAddedAssets + VIRTUAL_ASSETS, addedShares + VIRTUAL_SHARES
    )


def previewAddByAssets(assets, totalAddedAssets, addedShares):
    return toAddedSharesDown(assets, totalAddedAssets, addedShares)


def previewAddByShares(shares, totalAddedAssets, addedShares):
    return toAddedAssetsUp(shares, totalAddedAssets, addedShares)


def previewRemoveByAssets(assets, totalAddedAssets, addedShares):
    return toAddedSharesUp(assets, totalAddedAssets, addedShares)


def previewRemoveByShares(shares, totalAddedAssets, addedShares):
    return toAddedAssetsDown(shares, totalAddedAssets, addedShares)


# Assumes the asset uses at most 18 decimals.
def toValue(amount, decimals, price):
    return amount * (10 ** (18 - decimals)) * price


def proveValid(s, propertyDescription, property, assumptions=[], variables=[]):
    propertyDescriptionOutput = f"-- VALID Property: {propertyDescription} --"
    print("=" * len(propertyDescriptionOutput))
    print(propertyDescriptionOutput)

    result = s.check(Not(property), *assumptions)
    if result == sat:
        print("❌ Property is not valid:")
        print(s.model())
        for variable, variableName in variables:
            print(f"{variableName}: {s.model().eval(variable)}")
    elif result == unsat:
        print(f"✅ Property is valid.")
    elif result == unknown:
        print("❓ Timed out or unknown.")

    print("=" * len(propertyDescriptionOutput))


def proveSatisfiable(s, propertyDescription, property, assumptions=[], variables=[]):
    propertyDescriptionOutput = f"-- SATISFIABLE Property: {propertyDescription} --"
    print("=" * len(propertyDescriptionOutput))
    print(propertyDescriptionOutput)

    result = s.check(property, *assumptions)
    if result == sat:
        print("✅ Property is satisfiable")
        m = s.model()
        print(m)
        for variable, variableName in variables:
            print(f"{variableName}: {m.eval(variable)}")
    elif result == unsat:
        print("❌ Property is unsatisfiable.")
    elif result == unknown:
        print("❓ Timed out or unknown.")

    print("=" * len(propertyDescriptionOutput))
