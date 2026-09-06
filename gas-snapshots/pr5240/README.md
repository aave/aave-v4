# Vyper PR #5240 experiment — September 6, 2026

PR: https://github.com/vyperlang/vyper/pull/5240 (open at measurement time).
Tested head: `b8a11e8d1921ec65e416ece24e7eb0831f3249a1`.
Pinned control: `8af5e83c10af4f065cc660fe20293dac11fdff83`.
Port source revision: `1f712904`.
Both compilers identify as 0.5.0b2. All contract builds use Venom, O3,
Cancun, no bytecode metadata, and `PYTHONHASHSEED=0`. Foundry 1.8.1 uses the
repository Vyper profile and fixed fuzz seed `0x640`.

## Finding

The feature is useful: replacing the bounded outer multicall arrays in
AccessManager and PositionManagerBase with native `DynArray[Bytes[N], INF]`
removes the 64-call and 4-call limits and cuts the measured AccessManager
administrative call costs by more than 99%. Inner input/output byte limits
are unchanged. The source adaptation is essential; compiling unchanged sources
with the PR does not remove the fixed reservation.

This addresses the practical consequence of issue
https://github.com/vyperlang/vyper/issues/5244 by changing the unused sibling's
outer array type. It does not fix cross-function allocation coupling for code
that retains a bounded outer array.

## Direct AccessManager call measurements

These are `gasleft()` differences around identical calls, excluding deployment,
using the same test setup and call order in all three runs. They include the
Solidity caller overhead. The managed call includes target work and schedule
consumption; it is not an isolated measurement of `consumeScheduledOp`.

| Operation | Pinned compiler | PR, unchanged sources | PR, native arrays | Saving vs PR control |
|---|---:|---:|---:|---:|
| setTargetFunctionRole | 36,394,915 | 36,394,915 | 276,990 | 99.24% |
| schedule | 36,252,857 | 36,252,857 | 127,757 | 99.65% |
| Managed call including schedule consumption | 36,264,480 | 36,264,480 | 140,917 | 99.61% |

## Issue #5244 minimal reproducer

Only `length(bytes)` is called, with four bytes; the other function is unused.
Both runs below use the PR compiler. The modified source only changes the
unused echo function's outer array bound from 64 to INF.

| Inner bytes bound | Optimizer | Bounded outer array | Unbounded outer array |
|---|---|---:|---:|
| 32 | O2 | 2,126 | 948 |
| 32 | O3 | 2,132 | 953 |
| 32,768 | O2 | 34,050,123 | 948 |
| 32,768 | O3 | 34,050,129 | 953 |

All eight calls return the correct length. Logs are retained under
`vyper/compiler-feedback/pr5240/memory-*.txt`.

## Standard gas suite

| Build | Sum of 137 scenarios |
|---|---:|
| Pinned compiler, current port | 22,277,072 |
| PR compiler, unchanged sources | 22,277,084 |
| PR compiler, native multicall arrays | 22,277,108 |

The change is effectively zero in this suite (+24 gas vs the PR control).
It does not include AccessManager administrative operations. None of its
individual operations changes by more than 100 gas. Small deltas should not be
interpreted as an optimization effect, given the known compiler allocation
nondeterminism and signed-calldata byte-cost sensitivity of these fixtures.
These totals are a scenario comparison index, not one transaction's gas.

## Limits and validation

The PR still rejects `DynArray[Bytes[INF], INF]` and `raw_call(max_outsize=INF)`.
The open requests in issues #5247 and #5246 therefore remain relevant. Spoke's
existing runtime input decoding was not replaced with a bounded-input native
multicall: that would reduce its current accepted input domain.

Native AccessManager runtime grows from 15,488 to 15,794 bytes. GiverPositionManager
grows from 3,516 to 3,824 compiler runtime bytes; immutable data, where present,
must be added for deployed-size accounting. Spoke's compiler runtime is unchanged.

Each measured gas run passes 87 tests: the existing 86 gas tests plus the direct
AccessManager measurement. Three isolated positive domain tests pass: 65-call
AccessManager, 5-call position-manager plus empty batch, and exact dynamic return
encoding for strings of 1, 33, and 128 bytes. The domain log is retained next to
the harness. The full Vyper run passes **2,079 tests across 204 suites, zero
failures, and one pre-existing skip**, with 1,000 runs per fuzz test. This count
includes the direct gas test and two expanded-count tests; the dynamic-string
test was also validated in the isolated three-test domain run.

After the experiment, the original pinned Vyper artifacts and snapshot fixtures
were restored. The experiment's harnesses live in the feedback directory and
are not part of the pinned compiler's default test suite.

This is a retained experiment, not an update to the pinned production compiler.
The exact proposed source/compiler change is
`vyper/compiler-feedback/pr5240/native-arrays.patch`; compiler provenance,
source hashes, settings, and bytecode hashes are in the adjacent `builds.json`.

## Reproduce

On a disposable copy of revision `1f712904`, copy `PR5240.gas.t.sol` from
`vyper/compiler-feedback/pr5240/` into `tests/compiler/`. Build and run:

```sh
make vyper-build
FOUNDRY_PROFILE=vyper TEST_VYPER=true forge test --match-path 'tests/{gas,compiler}/**' -vv
```

Copy `snapshots/` before the next run. For the compiler-only stage change
`vyper/requirements.txt` to the exact PR head above, install it, build, and rerun.
For the native-array stage apply only the source hunks of `native-arrays.patch`
(or apply the whole patch directly to the original revision), then rebuild and
rerun. Add `PR5240Domain.t.sol` from the feedback directory for the positive
65-call AccessManager and 5-call position-manager tests and empty-result check.
The domain tests require the native-array stage. Existing byte-length bounds
and oversized-return rejection remain in effect.
