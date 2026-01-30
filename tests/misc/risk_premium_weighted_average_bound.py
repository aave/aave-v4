# Proves the maximum risk premium for a user computed by a spoke is bounded to MAX_ALLOWED_COLLATERAL_RISK
# divUp(sum(percentMulUp(w_i, rp_i)), sum(w_i)) <= rp_max when rp_i <= rp_max for all i.
from z3 import *

MAX_RP = IntVal(1000_00) # MAX_ALLOWED_COLLATERAL_RISK
PERCENTAGE_FACTOR = IntVal(100_00)

def divUp(numerator, denominator):
    return (numerator + denominator - 1) / denominator

def percentMulUp(value, percentage):
    return (value * percentage + PERCENTAGE_FACTOR - 1) / PERCENTAGE_FACTOR

s = Solver()

# N-agnostic: represent sum(percentMulUp(w_i, rp_i)) as numerator, sum(w_i) as denominator
weightedSum = Int('weightedSum')
sumOfWeights = Int('sumOfWeights')

s.add(sumOfWeights >= 1)
s.add(weightedSum >= 0)
# rp_i <= rp_max
# implies; percentMulUp(w_i * rp_i) <= percentMulUp(w_i * rp_max)
# implies; sum(percentMulUp(w_i * rp_i)) <= sum(percentMulUp(w_i * rp_max)) <= percentMulUp(sum(w_i) * rp_max) <= sum(w_i) * rp_max
s.add(weightedSum <= percentMulUp(sumOfWeights, MAX_RP))

s.add(Not(divUp(weightedSum, sumOfWeights) <= MAX_RP))
print(s.model() if s.check() == sat else 'no counterexample')
