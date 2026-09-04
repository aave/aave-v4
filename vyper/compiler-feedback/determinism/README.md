# Memory-allocation tie ordering: diagnostic, not a production compiler patch

Pinned Vyper 8af5e83c, O3, Venom, Cancun, metadata disabled, PYTHONHASHSEED=0.
The installed package's 203 recorded Python source files match their installation
RECORD hashes. No installed compiler or production artifacts were modified.

Two fresh baseline processes emit different 23,299-byte Spoke runtime binaries.
The IR differences retained here change numeric memory-location constants.

The ordering chain is:

1. `memory_location.Allocation` wraps an `IRInstruction`. The instruction uses
   Python's default object-identity hash; setting PYTHONHASHSEED does not stabilize
   object identities across processes.
2. `MemLivenessAnalysis` consumes ordinary sets of allocations/pointers, including
   `self.escaped` and `_find_base_ptrs`, and inserts entries into ordered collections.
   Ordered collections preserve the already variable incoming order.
3. `ConcretizeMemLocPass.run_pass` sorts by `(not escaped, liveness-set length)`.
   Equal-priority allocations retain that incoming order and receive different
   concrete memory locations.

The temporary diagnostic adds the stable IR output-variable name as a third sort
key. All four fresh diagnostic processes produce the identical hash recorded in
`results.json`, with a runtime size of 23,304 bytes. This isolates a reproducibility
failure at memory-allocation tie ordering in this case. It does not establish a
complete compiler-wide fix or prove semantic equivalence of the resulting code.
A production fix should choose an explicitly stable total order and run the
compiler's semantic, memory-layout, and performance regression suites.

Reproduce each mode in separate processes, without replacing build artifacts:

```sh
PYTHONHASHSEED=0 PYTHONDONTWRITEBYTECODE=1 .venv/bin/python vyper/compiler-feedback/determinism/compile.py baseline -p vyper/src --evm-version cancun --experimental-codegen --disable-bytecode-metadata -O 3 -f bytecode_runtime,ir_runtime vyper/src/spoke/SpokeInstance.vy > /tmp/vyper-baseline.txt
PYTHONHASHSEED=0 PYTHONDONTWRITEBYTECODE=1 .venv/bin/python vyper/compiler-feedback/determinism/compile.py stable-ties -p vyper/src --evm-version cancun --experimental-codegen --disable-bytecode-metadata -O 3 -f bytecode_runtime,ir_runtime vyper/src/spoke/SpokeInstance.vy > /tmp/vyper-stable-ties.txt
```

The shim changes one method in the diagnostic Python process only. It deliberately
does not modify the installed compiler, the standard build, or tested artifacts.
