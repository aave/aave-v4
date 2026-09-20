from commons import *

premiumDebt = lambda shares, offset, realized: (
    rayMulUp(shares, index) - offset + realized
)

# global asset state
index = Int('index')
premiumShares = Int('premiumShares')
premiumOffset = Int('premiumOffset')
realizedPremium = Int('realizedPremium')

s = Solver()

s.add(RAY <= index, index <= 100 * RAY)
s.add(0 <= premiumShares, premiumShares <= MAX_SUPPLY_AMOUNT)
s.add(0 <= premiumOffset, premiumOffset <= MAX_SUPPLY_AMOUNT)
s.add(0 <= realizedPremium, realizedPremium <= MAX_SUPPLY_AMOUNT)
s.add(rayMulDown(premiumShares, index) >= premiumOffset)

# choose user's old position
ps_old = Int('ps_old')
po_old = Int('po_old')
s.add(0 <= ps_old, ps_old <= premiumShares)
s.add(0 <= po_old, po_old <= premiumOffset)
accrued = rayMulUp(ps_old, index) - po_old
s.add(0 <= accrued, accrued <= rayMulUp(premiumShares, index) - premiumOffset)

# user's new position
ps_new = Int('ps_new')
s.add(0 <= ps_new, ps_new <= MAX_SUPPLY_AMOUNT)
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

proveValid(
    s,
    'Premium debt change bounded by [0, 2] after position replacement',
    And(after >= before, after - before <= 2),
)
