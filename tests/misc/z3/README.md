# Z3 Symbolic Proofs

Symbolic property proofs for Aave v4 math using the [Z3 SMT solver](https://github.com/Z3Prover/z3).

## Dependencies

### Required

- **[uv](https://docs.astral.sh/uv/)** - Python package manager

  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ```

- **[Python](https://www.python.org/downloads/)** >= 3.13

  ```bash
  # Verify installation
  python3 --version
  ```

### Install Dependencies

```bash
uv sync
```

## Usage

Run a proof:

```bash
uv run tests/misc/z3/max_deposit_property.py
```

Format code:

```bash
uv run ruff format tests/misc/z3
```

## Commons API

All proof scripts import shared constants, math helpers, and proof utilities from `commons.py` via `from commons import *`.

### Proof Utilities

#### `proveValid(s, propertyDescription, property, assumptions=[], variables=[])`

Proves a property holds for **all** variable assignments satisfying the solver's constraints. Internally checks that `Not(property)` is unsatisfiable — if no counterexample exists, the property is universally valid.

**Parameters:**

- `s` — a `Solver()` instance with constraints already added
- `propertyDescription` — string label printed in output
- `property` — Z3 boolean expression to prove
- `assumptions` — optional list of extra Z3 assumptions passed to `s.check()`
- `variables` — optional list of `(expression, name)` tuples printed if a counterexample is found

```python
from commons import *

s = Solver()

x = Int('x')
s.add(x >= 0, x <= 10)

proveValid(s, 'x + 1 > x', x + 1 > x)
# ✅ Property is valid.

proveValid(s, 'x < 5', x < 5)
# ❌ Property is not valid:
# [x = 5]
```

#### `proveSatisfiable(s, propertyDescription, property, assumptions=[], variables=[])`

Checks that a property **can** hold — i.e. at least one satisfying assignment exists. Useful for finding edge cases or demonstrating that a scenario is reachable.

**Parameters:** same as `proveValid`.

```python
from commons import *

s = Solver()

x = Int('x')
s.add(x >= 0, x <= 10)

proveSatisfiable(s, 'x == 7 is reachable', x == 7)
# ✅ Property is satisfiable
# [x = 7]
```

#### `maximise(expression, propertyDescription, assumptions=[], variables=[])`

Finds the **maximum** value of an expression under the given constraints using Z3's `Optimize` solver. Unlike `proveValid`/`proveSatisfiable`, this creates its own solver internally — constraints are passed via `assumptions`.

**Parameters:**

- `expression` — Z3 expression to maximise
- `propertyDescription` — string label printed in output
- `assumptions` — list of Z3 constraints
- `variables` — optional list of `(expression, name)` tuples printed alongside the result

```python
from commons import *

t = Int('t')
rate = IntVal(100)

maximise(
    t,
    'Maximum t such that rate * t <= 1000',
    assumptions=[t >= 0, rate * t <= 1000],
    variables=[(t, 't')],
)
# ✅ Maximum found: 10
# t: 10
```

### Constants

| Constant                              | Value            | Description                               |
| ------------------------------------- | ---------------- | ----------------------------------------- |
| `WAD`                                 | 10^18            | Standard decimal precision                |
| `RAY`                                 | 10^27            | Ray precision (interest math)             |
| `PERCENTAGE_FACTOR`                   | 10^4             | Basis points (1 = 0.01%)                  |
| `VIRTUAL_SHARES`                      | 10^6             | Virtual shares (hub inflation protection) |
| `VIRTUAL_ASSETS`                      | 10^6             | Virtual assets (hub inflation protection) |
| `MAX_PRICE`                           | 10^16            | Maximum oracle price                      |
| `MAX_SUPPLY_AMOUNT`                   | 10^30            | Maximum supply amount bound               |
| `MAX_SUPPLY_PRICE`                    | 100              | Maximum supply share price                |
| `MAX_COLLATERAL_RISK`                 | 100,000          | Maximum per-collateral risk premium       |
| `MIN_DRAWN_INDEX` / `MAX_DRAWN_INDEX` | RAY / 100 \* RAY | Drawn index range                         |
| `MIN_DECIMALS` / `MAX_DECIMALS`       | 6 / 18           | Token decimal range                       |
| `UINT256_MAX`                         | 2^256 - 1        | Solidity uint256 max value                |
| `SECONDS_PER_YEAR`                    | 31,536,000       | Seconds in a year (365 days)              |

### Math Helpers

All math helpers operate on Z3 symbolic expressions and mirror the Solidity implementations.

| Function                                                  | Description                               |
| --------------------------------------------------------- | ----------------------------------------- |
| `mulDivDown(a, num, den)`                                 | `(a * num) / den` (rounds down)           |
| `mulDivUp(a, num, den)`                                   | `(a * num + den - 1) / den` (rounds up)   |
| `divUp(a, b)`                                             | `(a + b - 1) / b`                         |
| `rayMulUp(a, b)` / `rayMulDown(a, b)`                     | Multiply in ray precision                 |
| `fromRayDown(a)` / `fromRayUp(a)`                         | Convert from ray to wad                   |
| `toRay(a)`                                                | Convert to ray                            |
| `percentMulUp(value, pct)` / `percentMulDown(value, pct)` | Percentage multiplication in basis points |
| `zeroFloorSub(a, b)`                                      | `max(a - b, 0)`                           |
| `min(a, b)`                                               | Z3-safe minimum via `If`                  |

### Share/Asset Conversion Helpers

| Function                                          | Rounding  | Use case                          |
| ------------------------------------------------- | --------- | --------------------------------- |
| `toAddedSharesDown(assets, totalAssets, shares)`  | Down      | Deposit: assets to shares         |
| `toAddedAssetsDown(shares, totalAssets, shares)`  | Down      | Redeem: shares to assets          |
| `toAddedSharesUp(assets, totalAssets, shares)`    | Up        | Withdraw: assets to shares burned |
| `toAddedAssetsUp(shares, totalAssets, shares)`    | Up        | Mint: shares to assets required   |
| `previewAddByAssets` / `previewAddByShares`       | Down / Up | Preview deposit/mint              |
| `previewRemoveByAssets` / `previewRemoveByShares` | Up / Down | Preview withdraw/redeem           |
