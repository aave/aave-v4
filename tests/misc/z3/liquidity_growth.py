# Highlights the fact that liquidity growth cannot be calculated accurately using the index delta.
from commons import *

base = Int('base')
premium = Int('premium')
index1 = Int('index1')
index2 = Int('index2')

s = Solver()

s.add(RAY <= index1, index1 < index2, index2 <= 100 * RAY)
s.add(0 <= base, base <= MAX_SUPPLY_AMOUNT)
s.add(0 <= premium, premium <= MAX_SUPPLY_AMOUNT)

trueLiquidityGrowth = (
    rayMulUp(base, index2)
    - rayMulUp(base, index1)
    + rayMulUp(premium, index2)
    - rayMulUp(premium, index1)
)
x = rayMulDown(base, index2 - index1) + rayMulDown(
    premium, index2 - index1
)  # incorrect -- it underestimates the liquidity growth
# x = rayMulDown(base + premium, index2 - index1) # incorrect -- it overestimates the liquidity growth

proveValid(
    s,
    'Liquidity growth via index delta equals true liquidity growth (expected: invalid)',
    trueLiquidityGrowth == x,
)
