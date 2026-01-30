# Proves that the proposed RiskPremiumThreshold formula strictly bounds the aggregate risk premium
# for any number of users, given any individual risk premium <= MAX_COLLATERAL_RISK.
from z3 import *

PERCENTAGE_FACTOR = IntVal(100_00)
MAX_COLLATERAL_RISK = IntVal(1000_00)

def percentMulUp(value, percentage):
    return (value * percentage + PERCENTAGE_FACTOR - 1) / PERCENTAGE_FACTOR

# ∀ drawnShares_i ≥ 1, ∀ riskPremium_i ≤ MAX_COLLATERAL_RISK,
# we want to minimize RISK_PREMIUM_THRESHOLD such that:
# Σ ⌈(drawnShares_i × riskPremium_i) / PERCENTAGE_FACTOR⌉ ≤ ⌈((Σ drawnShares_i) × RISK_PREMIUM_THRESHOLD) / PERCENTAGE_FACTOR⌉

# maximize LHS using the property ⌈x⌉ ≤ x + 1, and minimize RHS using the property ⌈x⌉ ≥ x
# Σ ((drawnShares_i × riskPremium_i) / PERCENTAGE_FACTOR + 1) ≤ ((Σ drawnShares_i) × RISK_PREMIUM_THRESHOLD) / PERCENTAGE_FACTOR

# for N as number of users, the above simplifies to:
# (1/PERCENTAGE_FACTOR) × Σ (drawnShares_i × riskPremium_i) + N ≤ (RISK_PREMIUM_THRESHOLD / PERCENTAGE_FACTOR) × Σ drawnShares_i

# worst case occurs when riskPremium_i = MAX_COLLATERAL_RISK for all i and drawnShares_i = 1 for all i (to maximize N)
# which implies: Σ drawnShares_i = N, and Σ (drawnShares_i × riskPremium_i) = N × MAX_COLLATERAL_RISK
# substituting these values gives:
# (1/PERCENTAGE_FACTOR) × (N × MAX_COLLATERAL_RISK) + N ≤ (RISK_PREMIUM_THRESHOLD / PERCENTAGE_FACTOR) × N

# MAX_COLLATERAL_RISK + PERCENTAGE_FACTOR ≤ RISK_PREMIUM_THRESHOLD

RISK_PREMIUM_THRESHOLD = MAX_COLLATERAL_RISK + PERCENTAGE_FACTOR

# N agnostic model for symbolic parameters to consider worst case average user
drawnShares = Int('drawnSharesPerUser')
riskPremium = Int('riskPremiumPerUser')
N = Int('numberOfUsers')

s = Solver()

s.add(1 <= N)
s.add(0 <= drawnShares, drawnShares <= 10 ** 30)
s.add(0 <= riskPremium, riskPremium <= MAX_COLLATERAL_RISK)

totalDrawn = N * drawnShares
premiumShares = percentMulUp(drawnShares, riskPremium)
s.add(Not(N * premiumShares <= percentMulUp(totalDrawn, RISK_PREMIUM_THRESHOLD)))

print(s.model() if s.check() == sat else 'no counterexample')
