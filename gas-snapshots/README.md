# Solidity vs optimized Vyper gas snapshots

These are matched runs of the repository's `tests/gas/**` suite. Solidity uses
the repository compiler profiles. Vyper uses pinned Vyper 0.5.0a3, Cancun,
Venom (`--experimental-codegen`), and the experimental aggressive optimizer
level (`-O 3`). Each run passed 86/86 tests and records 137 operations across
11 snapshot files.

The scenario-sum index is a comparison device, not the cost of one transaction:

| Implementation | Scenario index | vs Solidity | vs initial Vyper |
|---|---:|---:|---:|
| Solidity | 18,046,597 | — | — |
| Initial Vyper 0.5.0a3 | 47,114,515 | +161.07% | — |
| Optimized Vyper POC | 24,053,993 | +33.29% | -48.95% |

The optimized POC removes 23,060,522 gas from the initial Vyper index. One
operation beats Solidity, 14 are equal, and 122 remain above Solidity. The
magnitude of the remaining regressions is much smaller than in the initial
port.

## Category totals

| Snapshot | Ops | Solidity | Optimized Vyper | Delta | Delta % |
|---|---:|---:|---:|---:|---:|
| ConfigPositionManager.Operations.json | 11 | 582,821 | 651,467 | +68,646 | +11.78% |
| GiverPositionManager.Operations.json | 2 | 319,569 | 393,831 | +74,262 | +23.24% |
| Hub.Operations.json | 16 | 1,583,520 | 2,127,323 | +543,803 | +34.34% |
| NativeTokenGateway.Operations.json | 6 | 987,939 | 1,245,171 | +257,232 | +26.04% |
| PositionManagerBase.Operations.json | 1 | 75,041 | 146,411 | +71,370 | +95.11% |
| SignatureGateway.Operations.json | 8 | 991,321 | 1,265,275 | +273,954 | +27.64% |
| Spoke.Getters.json | 5 | 405,161 | 654,761 | +249,600 | +61.61% |
| Spoke.Operations.ZeroRiskPremium.json | 32 | 4,942,161 | 6,798,599 | +1,856,438 | +37.56% |
| Spoke.Operations.json | 32 | 5,611,075 | 7,744,574 | +2,133,499 | +38.02% |
| TakerPositionManager.Operations.json | 9 | 885,399 | 1,024,309 | +138,910 | +15.69% |
| TokenizationSpoke.Operations.json | 15 | 1,662,590 | 2,002,272 | +339,682 | +20.43% |

## Representative operations

| Operation | Solidity | Initial Vyper | Optimized Vyper |
|---|---:|---:|---:|
| Hub add | 91,610 | 176,001 | 116,324 |
| Hub draw | 109,072 | 178,547 | 132,465 |
| Spoke borrow, first | 269,297 | 602,706 | 354,830 |
| Spoke liquidation, partial | 365,078 | 808,538 | 510,871 |
| Spoke repay, partial | 142,713 | 233,940 | 184,078 |
| Spoke supply, no borrow | 127,753 | 216,216 | 159,606 |
| Empty account-data getter | 13,014 | 217,592 | 22,939 |
| Permit + repay multicall | 166,334 | 1,528,877 | 204,718 |

`TokenizationSpoke.permit` remains the one Vyper win: 61,818 versus 62,766
gas (-1.51%).

## POC compatibility limits

The optimized Vyper build is intentionally a theoretical POC, not an ABI-domain
equivalent production replacement. Selectors remain compatible, but bounded
Vyper types restrict accepted values:

- Spoke multicall: at most 4 calls, 512 bytes per call, and 256 bytes returned
  per call.
- Position-manager multicall: the same 4 / 512 / 256 bounds.
- General Spoke and ERC-1271 signatures: at most 256 bytes.
- `SetUserPositionManagers.updates` remains capped at 1024 because the full
  Solidity fuzz suite exercises that domain.

These limits are a direct consequence of Vyper 0.5.0a3 lacking production-ready
unbounded dynamic-array support. They must not be treated as transparent
optimizations.

## Artifacts

- `solidity/`: matched Solidity snapshots.
- `vyper/`: initial Vyper 0.5.0a3 snapshots.
- `vyper-optimized/`: final optimized Vyper snapshots.
- `comparison.json`: initial Vyper versus Solidity.
- `optimized-comparison.json`: optimized Vyper versus Solidity.
- `PERFORMANCE_DIARY.md`: measurements and compiler-facing hotspot notes.

## Reproduce

```sh
forge test --mp 'tests/gas/**' -vv
.venv/bin/python scripts/build_vyper.py
TEST_VYPER=true forge test --mp 'tests/gas/**' -vv
python3 scripts/compare_vyper_gas.py \
  gas-snapshots/solidity gas-snapshots/vyper-optimized /tmp/vyper-gas-comparison
```

Foundry writes both implementations to `snapshots/*.json`; copy each completed
run before starting the next one.
