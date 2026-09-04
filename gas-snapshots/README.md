# Solidity vs Vyper gas snapshots

The current corrected build measures **22,277,132 gas versus 17,999,249 for
Solidity (+23.77%)** across 137 matched scenarios. This is 0.20% below the prior
Vyper index; some getter scenarios regress. See the
[current comparison](comparison-parity-fixes/README.md) and
[compiler feedback diary](COMPILER_FEEDBACK_DIARY.md) for validation, compiler
examples, bytecode sizes, and remaining correctness/API restrictions.

The tables below preserve historical measurements before those corrections.

These matched runs use the repository's `tests/gas/**` suite: 86 tests and 137
recorded operations across 11 snapshot files. The latest pair uses verified
Foundry 1.8.0 after merging upstream main `4d86c2d3`. Solidity uses the
repository compiler profiles. Vyper uses Vyper 0.5.0b2 at merge commit
`8af5e83c` from PR #5232, Cancun, Venom (`--experimental-codegen`), and `-O 3`.

The scenario-sum index is a comparison device, not one transaction:

| Implementation | Scenario index | vs Solidity | vs prior stage |
|---|---:|---:|---:|
| Solidity, latest main | 17,999,249 | — | — |
| Initial Vyper 0.5.0a3 | 47,114,515 | +161.07% | — |
| Optimized Vyper 0.5.0a3 | 24,053,993 | +33.29% | -48.95% vs initial |
| Vyper 0.5.0b1, bounded control | 22,008,357 | +21.95% | -8.50% vs optimized a3 |
| Vyper 0.5.0b1, latest-main runtime arrays | 22,743,051 | +26.36% | +3.34% vs bounded b1 |
| Vyper 0.5.0b2, compiler-only update | 22,750,281 | +26.40% | +0.03% vs b1 runtime arrays |
| Vyper 0.5.0b2, restored unbounded hash append | 22,321,268 | +24.01% | -1.89% vs compiler-only b2 |

The first three Vyper rows are historical measurements against the earlier
18,046,597 Solidity baseline. The final row is the directly matched comparison:
the parity-oriented Vyper build is 4,322,019 gas (+24.01%) above Solidity on
the scenario-sum index. PR #5232 alone is neutral in this suite because its
arrays usually receive four or fewer appends. Restoring an unbounded local
hash accumulator exposes the optimization on batches up to 1,024 elements.

## Historical category totals

| Snapshot | Ops | Solidity | Vyper b2 | Delta | Delta % |
|---|---:|---:|---:|---:|---:|
| ConfigPositionManager.Operations.json | 11 | 582,821 | 625,760 | +42,939 | +7.37% |
| GiverPositionManager.Operations.json | 2 | 319,569 | 374,950 | +55,381 | +17.33% |
| Hub.Operations.json | 16 | 1,583,520 | 2,008,278 | +424,758 | +26.82% |
| NativeTokenGateway.Operations.json | 6 | 987,939 | 1,183,039 | +195,100 | +19.75% |
| PositionManagerBase.Operations.json | 1 | 75,041 | 91,532 | +16,491 | +21.98% |
| SignatureGateway.Operations.json | 8 | 991,297 | 1,145,757 | +154,460 | +15.58% |
| Spoke.Getters.json | 5 | 405,161 | 577,739 | +172,578 | +42.59% |
| Spoke.Operations.ZeroRiskPremium.json | 32 | 4,918,553 | 6,310,313 | +1,391,760 | +28.30% |
| Spoke.Operations.json | 32 | 5,587,371 | 7,122,902 | +1,535,531 | +27.48% |
| TakerPositionManager.Operations.json | 9 | 885,387 | 980,281 | +94,894 | +10.72% |
| TokenizationSpoke.Operations.json | 15 | 1,662,590 | 1,900,717 | +238,127 | +14.32% |

Two operations beat Solidity, 14 are equal, and 121 remain above Solidity.
The complete per-operation table is in
`comparison-b2-amortized/comparison.json`.

## Runtime-array parity and compiler limits

The historical build uses `DynArray[T, INF]` for supported top-level ABI-static
arrays, `Bytes[INF]` for signatures and interest-rate data, mapping-plus-length
storage for persistent enumerable collections, and raw runtime ABI decoding for
Spoke `multicall(bytes[])`. Abstract payload methods use unbounded return types
where their element structures are ABI-static.

Vyper 0.5.0b2 still rejects nested unbounded dynamic shapes such as
`DynArray[Bytes[INF], INF]`, dynamic structs containing unbounded arrays or
strings, and unbounded storage arrays. It also requires `raw_call` to have a
literal finite `max_outsize`. Consequently:

- Spoke multicall has unbounded call count and per-call input size, but each
  delegated result is capped at 256 bytes.
- Position-manager and AccessManager multicalls remain source-level bounded
  because their existing fallbacks/module composition cannot express an
  unbounded nested return with b2.
- Four config-engine update families whose structs contain strings or nested
  arrays retain finite source bounds.
- Harness-only storage arrays remain bounded; production enumerable Hub and
  AccessManager collections use mapping-plus-length storage.

These restrictions reflect compiler limits, but their exact finite values are port
choices. They do not establish behavioral equivalence. The diary also lists
implementation omissions that need no compiler changes.

## Artifacts

- `solidity/`: matched Solidity snapshots.
- `vyper/`: initial Vyper 0.5.0a3 snapshots.
- `vyper-optimized/`: optimized Vyper 0.5.0a3 snapshots.
- `vyper-b1-bounded/`: official b1 bounded control.
- `vyper-b1-unbounded/`: final parity-oriented b1 snapshots.
- `vyper-b2-pre-amortized/`: exact pre-PR compiler control.
- `vyper-b2-amortized/`: PR #5232 compiler-only result.
- `vyper-b2-amortized-restored/`: final result with the hash append restored.
- `comparison-b2-amortized/`: generated final comparison and tables.
- `COMPILER_FEEDBACK_DIARY.md`: compiler-facing findings and staged measurements.

## Reproduce the current comparison

```sh
.venv/bin/python scripts/build_vyper.py
FOUNDRY_PROFILE=vyper TEST_VYPER=true FOUNDRY_SNAPSHOTS=gas-snapshots/vyper-parity-fixes forge test --match-path 'tests/gas/**' -vv
TEST_VYPER=false FOUNDRY_SNAPSHOTS=gas-snapshots/solidity-parity-fixes forge test --match-path 'tests/gas/**' -vv
.venv/bin/python scripts/compare_vyper_gas.py gas-snapshots/solidity-parity-fixes gas-snapshots/vyper-parity-fixes gas-snapshots/comparison-parity-fixes --foundry-version 1.8.1
```

Rebuilding may produce a different Spoke bytecode hash even with the same seed.
Associate new measurements with their artifacts rather than reusing old hashes.

## Reproduce the historical comparison

```sh
forge test --match-path 'tests/gas/**' -vv
.venv/bin/python scripts/build_vyper.py
FOUNDRY_PROFILE=vyper TEST_VYPER=true forge test --match-path 'tests/gas/**' -vv
.venv/bin/python scripts/compare_vyper_gas.py \
  gas-snapshots/solidity \
  gas-snapshots/vyper-b2-amortized-restored \
  gas-snapshots/comparison-b2-amortized
```

Foundry writes both implementations to `snapshots/*.json`; copy each completed
run before starting the next one.
