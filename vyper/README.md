# Aave V4 Vyper implementation

This tree contains the Vyper implementation of Aave V4, compiled with the
latest published Vyper 0.5 prerelease. At the time this implementation was
created, PyPI publishes `0.5.0a3` as the newest 0.5 build and does not publish
a 0.5 release candidate yet. The version is pinned in `requirements.txt` and
every source file also has an exact version pragma.

## Build and test

```sh
make vyper-install
make vyper-build
make vyper-test
```

`scripts/build_vyper.py` produces Foundry-compatible artifacts in `out/`.
Vyper 0.5.0a3 still defaults to the legacy code generator, so the build always
passes `--experimental-codegen` and rejects any artifact whose compiler
settings do not confirm `experimental_codegen: true`. This makes Venom a
mandatory, verified property of every Vyper artifact rather than relying on a
compiler default. Builds otherwise use the gas optimizer (`-O 2`), Cancun, and
disabled bytecode metadata.

The Solidity tests select Vyper artifacts when `TEST_VYPER=true`. The full
suite is used rather than a hand-picked subset so deployment, upgradeability,
access control, Hub, Spoke, liquidation, tokenization, position-manager,
gateway, config-engine, utility, and differential-library behavior are all
exercised together.

`ExtSload` is the single opcode-compatibility boundary: Vyper 0.5.0a3 has no
arbitrary-slot storage-load builtin or inline assembly, so its Vyper ABI shell
delegatecalls a stateless backend for the raw `SLOAD` primitive. The dedicated
ExtSload Solidity suite runs against that Vyper shell and verifies that reads
come from the shell's own arbitrary storage, including batched and
dirty-calldata cases.

## Vyper 0.5 features

The port uses Vyper 0.5 abstract methods for reusable behavioral bases,
including interest-rate calculation, rescue authorization, and position
manager multicall policy. It also uses transient storage for reentrancy and
execution context, modules for reusable library logic, immutable values, and
the Venom code generator.
