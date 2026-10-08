# Proves maxDeposit rounding: deposit(maxDeposit()) must satisfy Hub._validateAdd.
# _validateAdd checks: allowed >= toAddedAssetsUp(spokeShares) + depositAmount
from commons import *

totalAddedAssets = Int('totalAddedAssets')
totalAddedShares = Int('totalAddedShares')
spokeShares = Int('spokeShares')
allowed = Int('allowed')

s = Solver()
s.add(0 <= totalAddedAssets, totalAddedAssets <= MAX_SUPPLY_AMOUNT)
s.add(0 <= totalAddedShares, totalAddedShares <= MAX_SUPPLY_AMOUNT)
s.add(0 <= spokeShares, spokeShares <= totalAddedShares)
s.add(0 < allowed, allowed <= MAX_SUPPLY_AMOUNT)

balance = toAddedAssetsUp(spokeShares, totalAddedAssets, totalAddedShares)
depositAmount = zeroFloorSub(allowed, balance)
hubCheck = (
    toAddedAssetsUp(spokeShares, totalAddedAssets, totalAddedShares) + depositAmount
)
s.add(depositAmount > 0)

proveValid(s, 'deposit(maxDeposit()) satisfies _validateAdd', allowed >= hubCheck)
