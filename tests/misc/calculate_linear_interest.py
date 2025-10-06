from z3 import *

s = Optimize()

UINT256_MAX = IntVal(2**256 - 1)
RAY = IntVal(10**27)
SECONDS_PER_YEAR = IntVal(365 * 24 * 60 * 60)

rate = IntVal(2**96 - 1)
lastUpdateTimestamp = IntVal(2**32 - 1)
currentTimestamp = Int("currentTimestamp")
elapsed = currentTimestamp - lastUpdateTimestamp

s.add(rate * elapsed <= UINT256_MAX)
s.add(RAY + ((rate * elapsed) / SECONDS_PER_YEAR) <= UINT256_MAX)

s.maximize(currentTimestamp)

assert s.check() == sat
m = s.model()
print("currentTimestamp max =", m[currentTimestamp])
