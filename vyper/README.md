# Aave V4 Vyper implementation

This tree contains the Vyper implementation of Aave V4, compiled with Vyper
0.5.0b2 at merge commit `8af5e83c` (PR #5232). The compiler commit is pinned in
`requirements.txt` and every source file also has an exact version pragma.

## Build and test

```sh
make vyper-install
make vyper-build
make vyper-test
```

`scripts/build_vyper.py` produces Foundry-compatible artifacts in
`out-vyper/`. The build always passes `--experimental-codegen` and rejects any
artifact whose compiler settings do not confirm `experimental_codegen: true`.
This makes Venom a mandatory, verified property of every Vyper artifact rather
than relying on a compiler default. Builds otherwise use `-O 3`, Cancun, and
disabled bytecode metadata.

The Solidity tests select Vyper artifacts when `TEST_VYPER=true`. The full
suite is used rather than a hand-picked subset so deployment, upgradeability,
access control, Hub, Spoke, liquidation, tokenization, position-manager,
gateway, config-engine, utility, and differential-library behavior are all
exercised together.

The `vyper` Foundry profile keeps these artifacts separate from Solidity's
additional Hub and Spoke compiler-profile artifacts. This avoids ambiguous
library resolution in Forge 1.8.x without changing Vyper compiler settings or
production bytecode.

`ExtSload` is the single opcode-compatibility boundary: Vyper 0.5.0b2 has no
arbitrary-slot storage-load builtin or inline assembly, so its Vyper ABI shell
delegatecalls a stateless backend for each raw `SLOAD` primitive. Its public
batch array is runtime-unbounded. The dedicated ExtSload Solidity suite runs
against that Vyper shell and verifies that reads come from the shell's own
arbitrary storage, including batched and dirty-calldata cases.

## Vyper 0.5 features

The port uses Vyper 0.5 abstract methods for reusable behavioral bases,
including interest-rate calculation, rescue authorization, and position
manager multicall policy. It also uses transient storage for reentrancy and
execution context, modules for reusable library logic, immutable values, and
the Venom code generator.

Vyper 0.5.0b2 runtime allocation is used for supported top-level
`DynArray[T, INF]`, `Bytes[INF]`, and abstract method return types. Spoke
`multicall(bytes[])` uses raw ABI dispatch because b2 cannot yet type nested
unbounded dynamic arrays. Remaining finite bounds are documented in
`gas-snapshots/README.md`; they are compiler limitations, not gas-driven API
restrictions.

The pinned compiler includes PR #5232's amortized local unbounded-array append.
Spoke's signed position-manager batch therefore accumulates its update hashes
in `DynArray[bytes32, INF]`; batches can preserve the Solidity API domain
without quadratic copying. Persistent enumerable collections remain
mapping-plus-length because the compiler change does not apply to storage, and
short finite internal batches remain bounded where direct measurements show
that the unbounded allocator's fixed cost is higher.
