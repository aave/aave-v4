# Production compilation time — September 6, 2026

On the same macOS arm64 machine, fresh serial compilation of the matched
production scope takes **7.07 seconds for Solidity** and **30.36 seconds for
Vyper** (median of three runs). Vyper takes **4.29×** as long in this experiment.
These are compiler invocation times, not Foundry build/test times.

| Repetition | Solidity wall seconds | Vyper wall seconds |
|---|---:|---:|
| 1 | 7.031 | 30.444 |
| 2 | 7.102 | 30.112 |
| 3 | 7.071 | 30.361 |
| Median | 7.071 | 30.361 |
| Median child CPU seconds | 7.046 | 30.316 |

## Matched scope

The scope is the 15 production contracts in `vyper/production-abi.json`: Hub,
Spoke, treasury/tokenization instances, oracle, access manager, interest-rate
strategy, configurators, config engine, gateways, and position managers.
Their required deployable helper libraries are also compiled:

- Vyper: 17 output targets, adding LiquidationLogicContract and
  TokenizationSpokeDeployer.
- Solidity: 21 output targets, adding LiquidationLogic, TokenizationSpokeDeployer,
  and the four external config-engine libraries whose behavior Vyper implements
  within its config engine.

Imported internal libraries, interfaces, and base classes are included in the
compiler input and processed as needed. Solidity has 131 source files in its
recursive import closure; Vyper receives 69 production source/interface files,
with output requested only for its 17 deployable targets. Every build was checked
to emit creation bytecode for every requested target.

Excluded on both sides: tests, mocks, test wrappers, harnesses, Forge test
compilation, governance payload instances, deployment orchestration/scripts,
and the standalone Vyper ExtSload compatibility shell. Abstract payload bases
are not independently deployed targets. Runtime-required deployment helpers
and proxy code referenced by TokenizationSpokeDeployer remain included. No
`forge-std` or test sources occur in the selected Solidity import closure.

This measures the current implementations of the matched production scope.
The port's documented behavioral/ABI gaps still apply; the numbers are not
proof that both implementations have identical functionality or an intrinsic
language-speed ranking. Compiling every file under Solidity `src/` would include
Foundry-based deployment tooling without Vyper counterparts, so that is excluded.

## Settings and timing boundary

- Source revision: `1f7129042fe57e24bfc4c934be5088514cb93503`.
- Native Solidity compiler: `0.8.28+commit.7893614a.Darwin.appleclang`.
- Pinned Vyper compiler: `0.5.0b2+commit.8af5e83c`, Python 3.13, Venom O3.
  This timing uses the pinned implementation, not the unapplied PR #5240 patch.
- Cancun, ABI + creation bytecode + runtime bytecode output, bytecode metadata
  disabled for both compilers. No AST, IR dump, source-map, or documentation output.
- Solidity uses the repository's production optimizer profiles: default non-IR
  with 44,444,444 runs, Hub via-IR with 22,300 runs, Spoke via-IR with 750 runs.
  Those are three sequential standard-JSON invocations with disjoint output
  targets; their times are summed. Each includes the import closure needed for
  analysis. Vyper uses one standard-JSON invocation for all output targets and
  the production storage-layout overrides.
- Optimizer settings preserve each implementation's production optimization
  policy; Solidity run counts and Vyper optimization levels are not equivalent
  numerical knobs.
- A fresh compiler process is launched for each invocation. No incremental
  artifact cache is consulted. OS filesystem caches are not flushed. All jobs
  run serially; language order reverses on the second repetition.
- Wall time starts immediately before process launch and ends after the compiler
  exits with its JSON output written to a temporary file. It includes startup,
  source analysis, optimization, code generation, and compiler output emission.
  Source discovery/input preparation, output validation, report generation,
  dependency installation, and project artifact conversion are outside timing
  for both languages. Child user + system CPU time is also recorded.

## Reproduce

With the pinned Vyper environment installed and native solc 0.8.28 available:

```sh
python3 scripts/benchmark_compilation.py --solc /path/to/solc-0.8.28 --runs 3
```

No Foundry tests are invoked and no normal build artifacts or snapshots are
overwritten. `results.json` contains every sample and stage, exact compiler
versions/settings, output target lists, and source hashes.
