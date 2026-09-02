# Solidity vs Vyper gas snapshots

These matched runs use the repository's `tests/gas/**` suite: 86 tests and 137
recorded operations across 11 snapshot files. Solidity uses the repository
compiler profiles. The final Vyper run uses official Vyper 0.5.0b1, Cancun,
Venom (`--experimental-codegen`), and `-O 3`.

The scenario-sum index is a comparison device, not one transaction:

| Implementation | Scenario index | vs Solidity | vs prior stage |
|---|---:|---:|---:|
| Solidity | 18,046,597 | — | — |
| Initial Vyper 0.5.0a3 | 47,114,515 | +161.07% | — |
| Optimized Vyper 0.5.0a3 | 24,053,993 | +33.29% | -48.95% vs initial |
| Vyper 0.5.0b1, bounded control | 22,008,357 | +21.95% | -8.50% vs optimized a3 |
| Vyper 0.5.0b1, parity-oriented runtime arrays | 22,754,778 | +26.09% | +3.39% vs bounded b1 |

The official b1 compiler reduces the optimized a3 index by 8.50% before the
runtime-array migration. Preserving unbounded behavior where b1 permits it adds
746,421 gas to the bounded b1 control in these small scenarios, but the final
parity-oriented build is still 1,299,215 gas (-5.40%) below optimized a3.

## Final category totals

| Snapshot | Ops | Solidity | Vyper b1 | Delta | Delta % |
|---|---:|---:|---:|---:|---:|
| ConfigPositionManager.Operations.json | 11 | 582,821 | 626,022 | +43,201 | +7.41% |
| GiverPositionManager.Operations.json | 2 | 319,569 | 375,300 | +55,731 | +17.44% |
| Hub.Operations.json | 16 | 1,583,520 | 2,007,873 | +424,353 | +26.80% |
| NativeTokenGateway.Operations.json | 6 | 987,939 | 1,184,176 | +196,237 | +19.86% |
| PositionManagerBase.Operations.json | 1 | 75,041 | 121,012 | +45,971 | +61.26% |
| SignatureGateway.Operations.json | 8 | 991,321 | 1,176,013 | +184,692 | +18.63% |
| Spoke.Getters.json | 5 | 405,161 | 578,239 | +173,078 | +42.72% |
| Spoke.Operations.ZeroRiskPremium.json | 32 | 4,942,161 | 6,496,483 | +1,554,322 | +31.45% |
| Spoke.Operations.json | 32 | 5,611,075 | 7,308,448 | +1,697,373 | +30.25% |
| TakerPositionManager.Operations.json | 9 | 885,399 | 980,975 | +95,576 | +10.79% |
| TokenizationSpoke.Operations.json | 15 | 1,662,590 | 1,900,237 | +237,647 | +14.29% |

Two operations beat Solidity, 14 are equal, and 121 remain above Solidity.
The complete per-operation table is in
`comparison-b1-unbounded/comparison.json`.

## Runtime-array parity and compiler limits

The final build uses `DynArray[T, INF]` for supported top-level ABI-static
arrays, `Bytes[INF]` for signatures and interest-rate data, mapping-plus-length
storage for persistent enumerable collections, and raw runtime ABI decoding for
Spoke `multicall(bytes[])`. Abstract payload methods use unbounded return types
where their element structures are ABI-static.

Official 0.5.0b1 still rejects nested unbounded dynamic shapes such as
`DynArray[Bytes[INF], INF]`, dynamic structs containing unbounded arrays or
strings, and unbounded storage arrays. It also requires `raw_call` to have a
literal finite `max_outsize`. Consequently:

- Spoke multicall has unbounded call count and per-call input size, but each
  delegated result is capped at 256 bytes.
- Position-manager and AccessManager multicalls remain source-level bounded
  because their existing fallbacks/module composition cannot express an
  unbounded nested return with b1.
- Four config-engine update families whose structs contain strings or nested
  arrays retain finite source bounds.
- Harness-only storage arrays remain bounded; production enumerable Hub and
  AccessManager collections use mapping-plus-length storage.

These are compiler residuals, not gas-driven design choices.

## Artifacts

- `solidity/`: matched Solidity snapshots.
- `vyper/`: initial Vyper 0.5.0a3 snapshots.
- `vyper-optimized/`: optimized Vyper 0.5.0a3 snapshots.
- `vyper-b1-bounded/`: official b1 bounded control.
- `vyper-b1-unbounded/`: final parity-oriented b1 snapshots.
- `comparison-b1-unbounded/`: generated final comparison and tables.
- `PERFORMANCE_DIARY.md`: compiler-facing findings and staged measurements.

## Reproduce

```sh
forge test --match-path 'tests/gas/**' -vv
.venv/bin/python scripts/build_vyper.py
TEST_VYPER=true forge test --match-path 'tests/gas/**' -vv
.venv/bin/python scripts/compare_vyper_gas.py \
  gas-snapshots/solidity \
  gas-snapshots/vyper-b1-unbounded \
  gas-snapshots/comparison-b1-unbounded
```

Foundry writes both implementations to `snapshots/*.json`; copy each completed
run before starting the next one.
