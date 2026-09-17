# PR #5271: runtime-sized raw-call returndata

September 17, 2026. [PR #5271](https://github.com/vyperlang/vyper/pull/5271)
head `58a453d402388cc1744db37082ec1e4f850550e5`; reviewed base
`6f1aefb5909d0faaae580ad5c78e07426482aedb`.
Compiler reports `0.5.0b2+commit.58a453d4`. Forge 1.8.1
(`982849d3140c01fd3b72905759581a132df7aa98`), Solidity 0.8.28, Python 3.13.14,
Cancun, hash seed 0, disabled Vyper bytecode metadata.

This section records the original pre-merge experiment. The subsequent compiler
adoption pins the merged version, not this historical PR head; see
[merge-validation.md](merge-validation.md).

## Results

The new capability works in the tested cases. All **9 tests pass** under each
of Venom O3, O2, and O3 with inlining disabled. Each configuration includes
128 fuzz runs for successful responses and 128 for failures (768 fuzz cases
across configurations). Exact source/harness files are in
`vyper/compiler-feedback/pr5271/`; logs are retained here.

Coverage includes:

- Whole successful responses through ordinary, static and delegate calls,
  internal forwarding and `(bool, Bytes[INF])` capture.
- Lengths 0, 1, 31, 32, 33, 255, 256, 257, 32767, 32768, 32769 and 65537.
- Exact bytes, including full outer ABI encoding and zero padding for ordinary
  forwarding and successful bool/bytes capture.
- Complete failure payloads, including empty and 65537-byte reverts, both
  bubbling and returned with a false success flag.
- Correct delegate-call address and sender context.
- A 32769-byte result surviving a second 33-byte call in a separate live buffer.
- A bounded 32-byte raw call remains capped when assigned/returned through
  an unbounded type, including failure-data capture.
- The base compiler rejects `max_outsize=INF`; the head accepts it under Venom.
  Legacy codegen still rejects the unbounded forwarder.

This is focused feature validation, not an exhaustive audit of the PR. No fork
or live-chain state is needed. No production implementation was adapted, and
the full Aave parity suite was **not rerun** for this feature experiment.

## Existing Aave compilation

All **41 Aave targets compile** on the PR head. Using the same compatibility-only
keyword-error sources on both compilers, every target has **identical creation
bytecode, runtime bytecode, ABI, selectors and source hashes** versus the base.
`compatibility.json` retains provenance, comparisons and runtime hashes.

The sources are the isolated `compatible` stage from PR #5234, not its
zero-capacity candidate and not the PR #5240 native-multicall adaptation. The
keyword-error migration is necessary on both recent compilers. The repository's
production source and actual `8af5e83c` pin remained unchanged during that experiment. Equality here is
against PR base `6f1aefb`, not against the older production compiler.

Because these unchanged artifacts are byte-identical, there is no existing-code
gas or deployment-bytecode change to attribute to this PR. We did not claim
a newly executed full-suite result or remeasure the standard 137-operation index.

## Small-forwarder gas

Compare two otherwise equivalent single-function forwarders: one captures and
returns `Bytes[32768]`, the other uses `max_outsize=INF` and `Bytes[INF]`.
For responses up to 32768 bytes they return identical bytes. Larger responses
are deliberately not equivalent: the bounded version truncates.

Each measurement uses a fresh helper-call frame, an unmeasured warm-up, then
`gasleft()` around the measured call. The callee returns the supplied byte
payload using assembly. Measurements include forwarding, target execution and
caller ABI-copy overhead, but exclude fixture deployment, payload construction,
transaction intrinsic gas and the warm-up. They are warm-call microbenchmarks,
not projected savings across Aave.

| Returned bytes | Bounded 32768, O3 | Unbounded, O3 |
| --- | ---: | ---: |
| 0 | 17,302 | 3,187 |
| 32 | 17,337 | 3,217 |
| 256 | 17,599 | 3,462 |
| 4,096 | 22,623 | 8,341 |
| 32,768 | 85,021 | 74,988 |

At 32769 bytes, the unbounded result remains complete (75,092 measured gas),
whereas the bounded result is only 32768 bytes. Do not interpret that pair as
a like-for-like performance comparison.

## Important remaining limitations

**Nested results remain unsupported.** The retained `Nested.vy` probe still
fails with `DynArray element types cannot contain unbounded sequence types`.
PR #5271 solves the standalone successful-returndata capture capability from
[#5246](https://github.com/vyperlang/vyper/issues/5246), but it does not complete
[#5247](https://github.com/vyperlang/vyper/issues/5247). Our multicalls cannot
simply switch to fully unbounded `bytes[]` results yet; collecting a captured
`Bytes[INF]` into bounded elements would retain the per-element restriction.

**Contract-wide memory coupling remains.** Add an uncalled function with
`DynArray[Bytes[32768], 64]` inputs/outputs to the unbounded forwarder. Calling
only `forward` with a 32-byte result still returns the correct bytes, but costs
**34,054,443 gas instead of 3,217** under O3; O2 is 34,054,425 versus 3,199.
This demonstrates that existing [#5244](https://github.com/vyperlang/vyper/issues/5244)
also matters to the new forwarder shape. It is not evidence that this PR
introduced the coupling. The measurement covers the whole forwarding call;
it does not isolate the cost of input decoding from returndata materialization.

Unrestricted capture also does not make arbitrary response sizes affordable:
ordinary EVM gas/memory limits still apply. The maximum tested response here
is 65537 bytes, not an asserted universal safety bound.

## Reproduction

Install the exact head SHA in a Python 3.13 environment. From repository root,
create a temporary case directory and copy the retained `foundry.toml` into it,
then copy `PR5271.t.sol` into its `test/` directory. Compile with:

```sh
python vyper/compiler-feedback/pr5271/compile.py PATH_TO_VYPER CASE_DIRECTORY/out 3
forge test --root CASE_DIRECTORY --remappings forge-std/=ABSOLUTE_REPO/lib/forge-std/src/ -vv
```

Use `2` for O2, or `3 --no-inline` to exercise the internal-return path without
inlining, replacing the temporary fixture artifacts before each run. The
compiler helper forces hash seed 0 and the recorded EVM/metadata settings.
Compile `Nested.vy` separately to reproduce its expected rejection.

At the time of this experiment, nothing had been committed, pushed or published.
Normal repository artifacts and snapshot fixtures were never swapped or edited.
