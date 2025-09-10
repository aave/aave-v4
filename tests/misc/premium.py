from z3 import *

RAY = IntVal(10**27)
rayMulUp = lambda a, b: (a * b + RAY - 1) / RAY
rayMulDown = lambda a, b: (a * b) / RAY
premiumDebt = (
    lambda shares, offset, realized: rayMulUp(shares, index) - offset + realized
)

# global asset state
index = Int("index")
premiumShares = Int("premiumShares")
premiumOffset = Int("premiumOffset")
realizedPremium = Int("realizedPremium")

s = Solver()

s.add(RAY <= index, index <= 100 * RAY)
s.add(0 <= premiumShares, premiumShares <= 10**30)
s.add(0 <= premiumOffset, premiumOffset <= 10**30)
s.add(0 <= realizedPremium, realizedPremium <= 10**30)
s.add(rayMulDown(premiumShares, index) >= premiumOffset)

# choose user's old position
ps_old = Int("ps_old")
po_old = Int("po_old")
s.add(0 <= ps_old, ps_old <= premiumShares)
s.add(0 <= po_old, po_old <= premiumOffset)
accrued = rayMulUp(ps_old, index) - po_old
s.add(0 <= accrued, accrued <= rayMulUp(premiumShares, index) - premiumOffset)

# user's new position
ps_new = Int("ps_new")
s.add(0 <= ps_new, ps_new <= 10**30)
po_new = rayMulDown(ps_new, index)

# replace user's old position with the new one
premiumSharesDelta = ps_new - ps_old
premiumOffsetDelta = po_new - po_old
realizedPremiumDelta = accrued

before = premiumDebt(premiumShares, premiumOffset, realizedPremium)
after = premiumDebt(
    premiumShares + premiumSharesDelta,
    premiumOffset + premiumOffsetDelta,
    realizedPremium + realizedPremiumDelta,
)

s.add(Not(And(after >= before, after - before <= 2)))

print(s.model() if s.check() == sat else "no counterexample")