# Proves the maximum risk premium for a user computed by a spoke is bounded to MAX_ALLOWED_COLLATERAL_RISK
# divUp(sum(k_i * v_i), sum(k_i)) <= v_max when v_i <= v_max for all i.
from z3 import *

MAX_KEY = IntVal(1000_00) # MAX_ALLOWED_COLLATERAL_RISK

def divUp(a, b):
    return (a + b - 1) / b

s = Solver()

# N-agnostic: represent sum(k_i * v_i) as numerator, sum(k_i) as denominator
numerator = Int('numerator')
denominator = Int('denominator')

s.add(denominator >= 1)
s.add(numerator >= 0)
# v_i <= v_max
# implies; k_i * v_i <= k_i * v_max
# implies; sum(k_i * v_i) <= v_max * sum(k_i)
s.add(numerator <= MAX_KEY * denominator)

s.add(Not(divUp(numerator, denominator) <= MAX_KEY))
print(s.model() if s.check() == sat else 'no counterexample')
