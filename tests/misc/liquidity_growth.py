from z3 import *

base = Int('base')
premium = Int('premium')
index1 = Int('index1')
index2 = Int('index2')

RAY = IntVal(10**27)

s = Solver()

s.add(RAY <= index1, index1 < index2, index2 <= 100 * RAY)
s.add(0 <= base, base <= 10**30)
s.add(0 <= premium, premium <= 10**30)

rayMulUp = lambda a, b: (a * b + RAY - 1) / RAY
rayMulDown = lambda a, b: (a * b) / RAY

expected = rayMulUp(base, index2) - rayMulUp(base, index1) + rayMulUp(premium, index2) - rayMulUp(premium, index1)
actual = rayMulDown(base, index2 - index1) + rayMulDown(premium, index2 - index1)
# actual = rayMulDown(base + premium, index2 - index1) # incorrect

s.add(Not(expected >= actual))

if s.check() == sat:
    print("counterexample:", s.model())
else:
    print("no counterexample found")
