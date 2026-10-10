# Hub & Spoke Prototype

A lightweight TypeScript prototype of Aave V4's Hub-and-Spoke lending architecture, built for rapid experimentation and invariant testing of the core accounting logic.

## What it models

The prototype implements a simplified version of the Hub's central accounting:

- **Hub**: Tracks global drawn debt (shares + index), supply-side exchange rate (via SharesMath with virtual assets/shares), premium accounting, fee accrual, and deficit (bad debt) tracking.
- **Spokes**: Regional intermediaries that bridge users to the Hub. Each spoke maintains its own view of drawn shares, premium shares, and added shares, mirrored on the Hub side for consistency checks.
- **Users**: Individual positions with drawn shares, premium shares/offset, added shares, and a risk premium that determines their premium debt.
- **Premium system**: Uses `premiumShares` and `premiumOffsetRay` (signed, RAY-precision) to track per-user premium debt. Premium deltas are propagated through `validateApplyPremiumDelta` which enforces the core invariant: `premiumRayAfter + restoredPremiumRay == premiumRayBefore`.
- **Interest accrual**: Simulated via random index multipliers on time advancement (`skip()`), modeling compounding drawn rates.

## What it does NOT model

- Oracle pricing, collateral factors, or health factor calculations
- Liquidation engine
- Dynamic risk configuration keys
- Cross-hub routing or cap enforcement
- EVM storage layout or gas considerations

## Running

Tests use [bun:test](https://bun.sh/docs/cli/test) (Jest-compatible).

```bash
# Run all prototype tests
bun test tests/misc/prototype/

# Scenario tests only
bun test tests/misc/prototype/scenario.test.ts

# Invariant fuzz test only
bun test tests/misc/prototype/invariant.test.ts

# Filter by test name
bun test tests/misc/prototype/ -t "repay deduction"
```

## File structure

| File | Purpose |
|------|---------|
| `core.ts` | Hub, Spoke, User, System classes and invariant checks |
| `utils.ts` | Math primitives (RAY/WAD/BPS), SharesMath, premium calculation, random generators |
| `scenario.test.ts` | Deterministic test scenarios exercising supply/borrow/repay/withdraw flows |
| `invariant.test.ts` | Randomized fuzz test that runs actions and asserts accounting invariants after each step |

## Invariants checked

- **Values within bounds**: all unsigned fields non-negative, premium non-negative, liquidity non-negative
- **Hub-Spoke accounting match**: spoke fields on Hub mirror actual spoke fields exactly
- **Sum of drawn debt**: hub drawn debt ~= sum of spoke drawn debts ~= sum of user drawn debts (within precision tolerance)
- **Sum of premium debt**: hub premium shares/offset == sum of spoke == sum of user (exact match)
- **Sum of added shares**: hub added shares ~= sum of spoke ~= sum of user
- **Sum of deficit**: hub deficit == sum of spoke deficit
- **Supply exchange rate non-decreasing**: the supply-side exchange rate never decreases across any action
