# Adoption of merged PR #5271

September 17, 2026. The production compiler pin moves from
`8af5e83c10af4f065cc660fe20293dac11fdff83` to
`1180f3e171cf0569e6d5ec01e916d9b289e12724`, the merge commit of
[Vyper PR #5271](https://github.com/vyperlang/vyper/pull/5271).
This is distinct from the historical experimental head in [README.md](README.md).

## Scope

- Pin the compiler supporting `raw_call(..., max_outsize=INF)` under Venom.
- Convert 114 custom-error calls in 24 source files to declared keyword
  arguments, required by the newer compiler. Argument expressions and their
  ordering are preserved.
- Retain standalone forwarding fixtures, gas measurements and an unpublished
  feedback draft. These are isolated probes, not deployed Aave entrypoints.
- Keep existing production raw-call bounds unchanged. The merged compiler
  still rejects `DynArray[Bytes[INF], INF]`; removing nested multicall limits
  requires further compiler support.
- Do not adopt the separate zero-capacity-array or native-multicall experiments.

## Merge-commit validation

Settings: Vyper 0.5.0b2, Venom O3, Cancun, disabled bytecode metadata,
`PYTHONHASHSEED=0`; Forge 1.8.1, Solidity 0.8.28.

- All 41 repository build targets compile successfully with the exact pin.
- Full Vyper parity suite: 2,076 passed, 0 failed, 1 existing skip across
  202 suites (881.92 seconds). The skipped test is
  `test_accrueInterest_fuzz_RPBorrowAndSkipTime`, marked `pending rft`.
- Focused raw-call suite: 9 passed, 0 failed in each of O3, O2 and O3 with
  inlining disabled. Each run includes 128 success-size and 128 failure-size
  fuzz cases. See `merge-raw-call-*.log`.
- All 41 ABIs and selector sets match the earlier experimental-head artifacts.
  All 41 runtime bytecodes also match that head. This is not a claim of
  bytecode equality against the old production pin.
- All 17 production storage layouts match the earlier compatibility-only
  compiler baseline. All production deployed sizes, including immutables,
  remain below EIP-170: aggregate 128,772 bytes; `SpokeInstance` 23,224 bytes.
  See [merge-compatibility.json](merge-compatibility.json).
- The nested-unbounded probe is still rejected with
  `DynArray element types cannot contain unbounded sequence types`.
- Focused O3 warm-call gas is unchanged from the original experiment:
  a 32-byte response costs 3,217 with INF versus 17,337 with a 32,768-byte
  bound. These are forwarding microbenchmarks, not Aave-wide savings.

## Reproduction

Use `make vyper-install` and `make vyper-build`, then run
`FOUNDRY_PROFILE=vyper TEST_VYPER=true forge test` from the repository root.
The focused harness procedure is in [README.md](README.md); install the merged
pin instead of the historical PR head when reproducing this validation.
Run the three compiler configurations in separate artifact directories or
replace the isolated artifacts between runs.

The existing snapshot fixtures are restored after validation. Generated
`out-vyper` artifacts remain built with the adopted compiler and source.
No compiler feedback is posted upstream as part of this change.
