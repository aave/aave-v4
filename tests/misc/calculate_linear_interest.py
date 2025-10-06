from z3 import *

s = Optimize()

RAY = IntVal(10**27)
SECONDS_PER_YEAR = IntVal(365 * 24 * 60 * 60)

rate = IntVal(2**96 - 1)
lastUpdateTimestamp = IntVal(2**32 - 1)
currentTimestamp = Int("currentTimestamp")

s.add(
    RAY + (rate * (currentTimestamp - lastUpdateTimestamp)) / SECONDS_PER_YEAR
    <= 2**256 - 1
)

s.maximize(currentTimestamp)

assert s.check() == sat
m = s.model()
print("currentTimestamp max =", m[currentTimestamp])
