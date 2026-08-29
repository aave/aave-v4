# Proves the maximum risk premium for a user computed by a spoke is bounded to MAX_ALLOWED_COLLATERAL_RISK
# divUp(sum(percentMulUp(w_i, rp_i)), sum(w_i)) <= rp_max when rp_i <= rp_max for all i.
from commons import *

s = Solver()

# N-agnostic: represent sum(percentMulUp(w_i, rp_i)) as numerator, sum(w_i) as denominator
weightedSum = Int('weightedSum')
sumOfWeights = Int('sumOfWeights')

s.add(sumOfWeights >= 1)
s.add(weightedSum >= 0)
# rp_i <= rp_max
# implies; percentMulUp(w_i * rp_i) <= percentMulUp(w_i * rp_max)
# implies; sum(percentMulUp(w_i * rp_i)) <= sum(percentMulUp(w_i * rp_max)) <= percentMulUp(sum(w_i) * rp_max) <= sum(w_i) * rp_max
s.add(weightedSum <= percentMulUp(sumOfWeights, MAX_COLLATERAL_RISK))

proveValid(
    s,
    'Weighted average risk premium is bounded by MAX_COLLATERAL_RISK',
    divUp(weightedSum, sumOfWeights) <= MAX_COLLATERAL_RISK,
)
