# Solidity vs Vyper gas snapshots

These matched runs use the repository's `tests/gas/**` suite: 86 tests and 137
recorded operations across 11 snapshot files. The latest pair uses verified
Foundry 1.8.0 after merging upstream main `4d86c2d3`. Solidity uses the
repository compiler profiles. Vyper uses official Vyper 0.5.0b1, Cancun,
Venom (`--experimental-codegen`), and `-O 3`.

The scenario-sum index is a comparison device, not one transaction:

| Implementation | Scenario index | vs Solidity | vs prior stage |
|---|---:|---:|---:|
| Solidity, latest main | 17,999,249 | — | — |
| Initial Vyper 0.5.0a3 | 47,114,515 | +161.07% | — |
| Optimized Vyper 0.5.0a3 | 24,053,993 | +33.29% | -48.95% vs initial |
| Vyper 0.5.0b1, bounded control | 22,008,357 | +21.95% | -8.50% vs optimized a3 |
| Vyper 0.5.0b1, latest-main runtime arrays | 22,743,051 | +26.36% | +3.34% vs bounded b1 |

The first three Vyper rows are historical measurements against the earlier
18,046,597 Solidity baseline. The latest-main pair is the directly matched
comparison: the parity-oriented Vyper build is 4,743,802 gas (+26.36%) above
Solidity on the scenario-sum index.

## Final category totals

| Snapshot | Ops | Solidity | Vyper b1 | Delta | Delta % |
|---|---:|---:|---:|---:|---:|
| ConfigPositionManager.Operations.json | 11 | 582,821 | 625,760 | +42,939 | +7.37% |
| GiverPositionManager.Operations.json | 2 | 319,569 | 374,950 | +55,381 | +17.33% |
| Hub.Operations.json | 16 | 1,583,520 | 2,008,278 | +424,758 | +26.82% |
| NativeTokenGateway.Operations.json | 6 | 987,939 | 1,183,039 | +195,100 | +19.75% |
| PositionManagerBase.Operations.json | 1 | 75,041 | 121,012 | +45,971 | +61.26% |
| SignatureGateway.Operations.json | 8 | 991,297 | 1,175,204 | +183,907 | +18.55% |
| Spoke.Getters.json | 5 | 405,161 | 577,739 | +172,578 | +42.59% |
| Spoke.Operations.ZeroRiskPremium.json | 32 | 4,918,553 | 6,491,847 | +1,573,294 | +31.99% |
| Spoke.Operations.json | 32 | 5,587,371 | 7,304,436 | +1,717,065 | +30.73% |
| TakerPositionManager.Operations.json | 9 | 885,387 | 980,281 | +94,894 | +10.72% |
| TokenizationSpoke.Operations.json | 15 | 1,662,590 | 1,900,505 | +237,915 | +14.31% |

Three operations beat Solidity, 12 are equal, and 122 remain above Solidity.
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
FOUNDRY_PROFILE=vyper TEST_VYPER=true forge test --match-path 'tests/gas/**' -vv
.venv/bin/python scripts/compare_vyper_gas.py \
  gas-snapshots/solidity \
  gas-snapshots/vyper-b1-unbounded \
  gas-snapshots/comparison-b1-unbounded
```

Foundry writes both implementations to `snapshots/*.json`; copy each completed
run before starting the next one.
