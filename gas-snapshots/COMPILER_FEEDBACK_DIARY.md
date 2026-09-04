# Vyper 0.5 compiler feedback diary

This diary records language, compiler, correctness, and performance findings from the Aave v4 Vyper POC for Vyper
core developers. Measurements use Cancun, Venom via `--experimental-codegen`,
and the repository's matched 137-operation gas suite. The historical baseline build uses
Vyper 0.5.0b2 at PR #5232's merge commit and `-O 3`; earlier milestones used
0.5.0a3 and official 0.5.0b1.

## September 5, 2026: parity corrections and compiler feedback

This entry supersedes earlier claims of full equivalence. The historical green
suite establishes coverage of the tested behaviors, not the entire Solidity API.
The implementation remains a prototype with the explicit residuals below.

### Supported language features that the port should have used

Native Vyper modules support test wrappers: `initializes: HubInstance` or
`SpokeInstance`, `exports: ...__interface__`, and additional wrapper-only methods.
The wrappers now live under `vyper/src/harness/`. Their constructors initialize the
imported production module. Only fixture construction temporarily uses a wrapper;
the production ABI excludes its helpers. The position-manager test getter also
moved out of the shared production base and into its wrapper.

This was a port design error, not missing inheritance support. A build-time
allowlist in `vyper/production-abi.json` checks production function signatures
against the pinned Solidity ABI. Raw-dispatch metadata is included explicitly;
known missing methods are listed rather than silently treated as implemented.
The guard is a surface check, not a behavioral proof.

Shared native modules now provide SignatureChecker, AccessManaged, and SafeERC20.
Contract-wallet intent verification, authority delay consumption, legacy boolean
responses, replacement-authority validation, reset-required token approvals,
optional token returns, and canonical ECDSA checks do not require new language
features. ERC-2612 permit intentionally remains ECDSA-only, matching Solidity.

### Why the old tests passed

The original ERC-1271 coverage exercised signed Spoke position-manager approvals.
The other intent consumers were tested with EOA signatures. Those tests could all
pass while SignatureGateway, TakerPositionManager, ConfigPositionManager, and
TokenizationSpoke omitted contract wallets. New positive tests use an approved
contract-wallet digest and a 513-byte signature at each of those boundaries.
There is no evidence here that the implementer falsified results.

Existing scheduled-operation coverage primarily exercised `AccessManager.execute`
with a simple managed target. Direct execution on a real Hub or Spoke follows the
separate AccessManaged consumption path. New tests schedule an ordinary operation,
advance time, call the production target directly, and verify the schedule is
consumed and its marker reset. Green helper-library tests also did not establish
that production Spoke exported ExtSload.

The tri-state approval shadow mapping existed solely to accommodate Foundry's
arbitrary-storage fixture. It is removed. The explicit-disabled no-op test now
uses canonical state: arbitrary-storage mode can refill a zeroed Vyper mapping
slot, which is not normal EVM storage behavior. No production state is added to
satisfy that cheatcode.

### Bytecode: do the test helpers prevent O2?

Yes, helpers consume runtime space; no, removing them alone does not make this
Spoke deployable under O2. The isolated experiment freezes source revision
`44751e4e`, imports and compiler flags, uses Hub's actual layout override, and
removes only the testing functions. Spoke's three immutable words add 96 bytes to
the compiler's runtime hex and must be counted toward EIP-170.

| Frozen production contract | Optimizer | With helpers, deployed bytes | Without helpers, deployed bytes | Saved |
|---|---|---:|---:|---:|
| Hub | O2 | 17,445 | 17,379 | 66 |
| Hub | O3 | 15,548 | 15,482 | 66 |
| Spoke | O2 | 25,388 | 24,710 | 678 |
| Spoke | O3 | 22,435 | 21,821 | 614 |

The helper-free O2 control remains **134 bytes over 24,576**, before adding the
behavioral corrections. These are whole-artifact differences, including optimizer
and dispatch effects, not an additive price for each individual helper. Reproduce
with `scripts/measure_vyper_helper_size.py`; retained results are in
`vyper/compiler-feedback/helper-removal-sizes.json`. Current corrected-artifact
sizes are recorded separately in `build-verification.json`; do not substitute the
frozen removal-only measurement for the corrected contract.

### Actual compiler/language gaps

Minimal compile-only cases and exact diagnostics live in
`vyper/compiler-feedback/cases/` and `capabilities.json`. Run
`scripts/check_vyper_capabilities.py` against the pinned compiler.

| Gap in 0.5.0b2 at 8af5e83c | Consequence | Requested capability |
|---|---|---|
| Nested unbounded dynamic types rejected | Native `bytes[]` and structs containing dynamic arrays cannot express the Solidity input domain | Recursive runtime ABI decoding/encoding, including abstract and exported module interfaces |
| `raw_call(max_outsize=INF)` rejected | Successful delegated returns still require a finite capture buffer | Runtime allocation from returndata size, preserving complete successful data |
| Unbounded storage arrays/strings rejected | Token metadata and role labels retain finite bounds; enumerable collections use mappings plus length | Runtime-sized persistent sequence support with predictable storage layout |
| No arbitrary-slot SLOAD builtin or inline assembly | Production Spoke still lacks `extSload` and `extSloads` | A narrowly specified storage-read primitive, including delegatecall/proxy semantics |
| Mapping layout differs from Solidity | Namespace offsets alone cannot provide proxy-state compatibility | Explicit storage layout control, including mapping key/base hashing, if migration is a supported use case |

A higher finite buffer is not a full-parity fix. No new Solidity backend or custom
nested ABI decoder was introduced to disguise these gaps. Existing raw dispatch
remains explicitly identified. Multicall now rejects oversized successful results
instead of silently truncating them, and uses native failure propagation to retain
complete revert data. This makes the restriction explicit; it does not remove it.

### Remaining API-domain matrix

| Surface | Current restriction/status |
|---|---|
| Production Spoke ExtSload | Both methods still unimplemented; standalone compatibility shell does not establish production support |
| Spoke multicall | Runtime-sized count/input; each successful result limited to 256 bytes |
| Position-manager multicall | 4 calls, 512 input bytes per call, 256 successful return bytes per call |
| AccessManager multicall | 64 calls, 32,768 input and successful return bytes per call |
| Signed Spoke manager-update struct | 1,024 updates; the unbounded hash accumulator does not expand the input decoder |
| Role labels and token name/symbol | 128 bytes |
| Four nested config-engine update families | 32 outer updates; nested arrays/strings retain their declared bounds |
| Proxy migration | Fresh Vyper deployments only; Solidity-state upgrades are not compatible or validated |

The artificial total-256-reserve cap and two-bucket traversal were removed
together. Account-data processing uses runtime-sized collateral storage in memory,
with a packed scalar key/value and the reference KeyValueList value limit. A new
functional test lists 300 additional reserves and uses collateral beyond the old
bitmap boundary. This is separate from the protocol's per-user reserve limit.

### Optimizations and reproducibility

Hub accrual/rate updates now write only affected packed words. Spoke config-key
refresh writes only the supply/config word. Collateral records occupy one word;
zero-debt account queries skip sorting after required collateral validation.
Insertion sort remains quadratic and needs workload-specific scaling measurements
before replacing it. Batch output construction appends static words and ABI-encodes
once, replacing repeated concatenation of growing prefixes.

Builds fix `PYTHONHASHSEED=0` and record project source hashes, compiler settings,
and the pinned compiler requirement. Repeated-build results and bytecode hashes
are retained in `vyper/compiler-feedback/build-verification.json`. Two successive O3 Spoke builds with seed 0 still have different hashes, despite
identical 23,299-byte runtime size. Thus setting the seed does **not** fix the
nondeterminism. A subsequent diagnostic isolated unstable tie ordering in Venom's
memory-allocation pass: unordered sets of identity-hashed instruction allocations
feed a sort without a stable tie-breaker. Adding an IR-variable-name tie-breaker
in a temporary process produced identical bytecode in four consecutive builds;
the two unmodified controls differed. The baseline IR differences change numeric
memory addresses. Details, hashes, the IR diff, and an unapplied diagnostic shim
are in `vyper/compiler-feedback/determinism/`. Semantic equivalence and a complete
compiler fix still require validation. Run `scripts/check_vyper_build.py` to
repeat the standard comparison without replacing tested artifacts.

The corrected Spoke is 23,395 deployed bytes under O3 and 26,907 under O2,
including its 96 immutable bytes. O3 has 1,181 bytes of EIP-170 headroom; O2
exceeds the limit by 2,331. Corrected Hub is 16,100 bytes under O3 and 18,269
under O2. Correctness additions and output construction change code size; the
isolated helper savings must not be treated as the net result of all changes.

### Confirmed compiler performance issue: unrelated bounded function inflates a small call

A minimal two-function control reproduces the extreme AccessManager call cost.
One function echoes `DynArray[Bytes[BOUND], 64]`; the other simply returns the
length of `Bytes[INF]`. Only the second function is called, with **four bytes**.
Changing the unused sibling's bound from 32 to 32,768 changes that small call's
cost dramatically:

| Sibling element bound | O2 small-call gas | O3 small-call gas |
|---|---:|---:|
| 32 bytes | 2,126 | 2,132 |
| 32,768 bytes | 34,050,123 | 34,050,129 |

Values measure gas around the Solidity caller's external call and include the same
call overhead in both controls; deployment is excluded. All four calls return the
correct length. This confirms cross-function bound coupling in generated code,
consistent with excessive static-memory reservation affecting runtime allocation.
The exact allocator cause still needs compiler investigation. Shrinking the public
ABI bound would hide the cost by restricting the API further, so no such workaround
was applied.

Reproduce with `scripts/check_vyper_memory_allocation.py`. The two short Vyper
sources and full results are under `vyper/compiler-feedback/memory-allocation/`.
Flags: pinned 8af5e83c, Venom, Cancun, metadata disabled, Python hash seed 0.
In the actual AccessManager compatibility trace, `setTargetFunctionRole`,
`schedule`, and `consumeScheduledOp` each cost roughly 36 million gas. AccessManager
operations are absent from the historical 137-operation benchmark. The test suite's
large gas limit allows them to pass, so a green suite does not establish practical
deployment performance.

### Additional implementation gap: AccessManager administrative delays

Source comparison found that the enumerable AccessManager also applies updates to
execution/grant/target-admin delays immediately and simplifies authorization of
calls targeting itself. This is separate from the repaired AccessManaged module.
It is not a language limitation, and the current implementation must not be
presented as fully matching OpenZeppelin AccessManager.

The proposed broader authorization rewrite was not applied: automatic approval
review rejected its scope because it could introduce persistent access-control
regressions. The concrete, **unapplied and unvalidated** proposal is retained as
`vyper/compiler-feedback/access-manager-proposed.patch`. It changes only the
delay value representation and the associated AccessManager authorization/update
paths; it has not been compiled into any tested artifact. The follow-up must preserve Time.Delay's current/pending/effect
semantics, method-specific admin roles and target delays, and scheduled execution
both directly and through `execute`. Positive time-transition checks must cover
existing-member delay reduction, minimum-setback grant/target delay updates,
role-admin callers, and matured scheduled administrative calls against both
implementations. Existing tests mostly setting zero grant delays do not cover this.

### Validation and current matched gas results

Foundry 1.8.1, fuzz seed `0x640`, 1,000 runs per fuzz test:

- Full rebuilt Vyper suite: **2,076 passed, 0 failed, 1 skipped**.
- All 12 new compatibility cases against Solidity: **12 passed**. This uses the
  same already compiled harness/profile to select the reference implementations.
- After changing the remaining config-payload failure path to native full revert
  propagation: **206 config-engine/payload tests passed**. The other contracts were
  unchanged from the full-suite run apart from whitespace.
- Fresh Solidity gas suite with its repository compiler profiles: **86 passed**.
  The full Vyper run includes the same **86 gas tests**.
- Minimal memory-allocation controls: **4 passed**, with the measured performance
  difference above. The production ABI guard rejects the original Hub and Spoke
  artifacts containing test methods; all 15 guarded current contracts pass.

The fresh matched index is **17,999,249 Solidity gas versus 22,277,132 Vyper gas**
across 137 independent scenarios: **+23.77% versus Solidity**, compared with the
old Vyper index of 22,321,268. The net reduction versus the old port is only
**0.20%**. These changes restore behavior as well as optimize code; they are not a
blanket performance improvement. In particular, the Spoke getter subtotal grows
from 577,739 to 639,053, while Hub's subtotal falls from 2,008,278 to 1,976,051.
Per-change attribution requires isolated controls; the current aggregate cannot
assign those differences to a single compiler feature or source change.

The complete category and per-operation data are in
`gas-snapshots/comparison-parity-fixes/`. Snapshot inputs are retained separately
under `solidity-parity-fixes/` and `vyper-parity-fixes/`, with tested-artifact hashes
and follow-up validation in `vyper-parity-fixes-build.json`. The shared active
`snapshots/` fixtures were restored after collecting these runs.

A passing suite still does not establish unrestricted ABI parity, existing-proxy
migration support, viable AccessManager gas costs, deterministic compilation, or
completion of the unapplied AccessManager administrative-delay proposal. Those
remain explicit unresolved items rather than exceptions hidden in test helpers.

## Historical measurements (before these corrections)

## Runtime-array results through 0.5.0b2

| Milestone | Scenario index | vs Solidity | vs previous |
|---|---:|---:|---:|
| Optimized 0.5.0a3 | 24,053,993 | +33.29% | — |
| 0.5.0b1 bounded control | 22,008,357 | +21.95% | -8.50% |
| 0.5.0b1 parity-oriented runtime arrays | 22,743,051 | +26.36% | +3.34% |
| 0.5.0b2 PR #5232 compiler-only | 22,750,281 | +26.40% | +0.03% |
| 0.5.0b2 restored hash append | 22,321,268 | +24.01% | -1.89% |

The official b1 release provides top-level `Bytes[INF]`, `String[INF]`, and
`DynArray[T, INF]` for ABI-static `T` under Venom. The POC now uses these for
signatures, interest-rate data, oracle batch getters, configurator batches, and
abstract payload methods. Production persistent enumerable arrays were replaced
with mapping-plus-length storage. Spoke multicall uses raw runtime decoding to
accept an unbounded `bytes[]` call count and unbounded per-call input size.

The b1 runtime path was not a gas optimization in the small benchmark domain:
it added 734,694 gas (+3.34%) versus the bounded control. It was retained
because unbounded behavior is a feature-parity requirement. PR #5232 makes
long local appends efficient enough to recover 429,013 gas (-1.89%) after one
previously bounded accumulator is restored to `DynArray[bytes32, INF]`.

The remaining compiler gaps are nested unbounded dynamic types, unbounded
storage arrays, and unbounded `raw_call` returndata. Vyper 0.5.0b2 rejects
`DynArray[Bytes[INF], INF]` and dynamic structs containing unbounded arrays or
strings, and `raw_call` still requires a literal finite `max_outsize`. The POC
isolates those residual bounds instead of describing them as optimizations.

## Cumulative 0.5.0a3 progress

| Milestone | Scenario index | Change from initial Vyper |
|---|---:|---:|
| Initial Vyper 0.5.0a3 | 47,114,515 | — |
| Position bitmap and bit algorithms | 40,976,922 | -13.03% |
| Spoke packing plus first raw-return multicall | 33,812,256 | -28.23% |
| Smaller multicall bound (8 calls) | 28,792,910 | -38.89% |
| Final: Hub packing and tighter bounded buffers | 24,053,993 | -48.95% |

Solidity's matched index is 18,046,597. The final gap is +33.29%, down from
+161.07%.

Milestones are cumulative and should not be interpreted as isolated A/B tests.
Focused measurements below isolate the important effects where possible.

## 1. Narrow struct fields are not automatically packed

### Observation

Vyper assigns a full storage slot to every struct member, including `uint8`,
`uint16`, `uint24`, `uint32`, `uint40`, `uint96`, `uint120`, `uint200`, `bool`,
and `address`. The equivalent Solidity structs automatically share compatible
slots.

Examples from the initial port:

| Logical record | Initial Vyper slots | Manual packed slots |
|---|---:|---:|
| Spoke `Reserve` | 7 | 2 |
| Spoke `UserPosition` | 5 | 3 |
| Spoke `DynamicReserveConfig` | 3 | 1 |
| Hub `Asset` | 17 | 10 |
| Hub `SpokeData` | 10 | 4 |

The POC stores packed `uint256` words and exposes pure pack/unpack helpers so
the external structs remain unchanged.

### Measured impact

- The cumulative Spoke packing stage helped reduce the total index from
  40,976,922 to 33,812,256.
- Packing Hub `Asset` and `SpokeData` reduced the Hub category from 2,819,647
  to 2,127,323: -692,324 gas (-24.55%).
- Because Spoke calls Hub, Hub packing also reduced downstream Spoke,
  tokenization, and gateway operations.

### Core opportunity

Implement Solidity-like storage packing for struct members, or provide a
first-class packed-storage annotation/type. Manual shifts and masks are verbose,
easy to get wrong, and force every load/store through conversion helpers.

## 2. Sparse position traversal needs bitmaps and efficient bit primitives

### Observation

The initial Spoke kept independent collateral and borrowing mappings and scanned
all 256 reserves. It loaded reserve/position data and called the oracle even for
inactive reserves. Solidity uses a compact position-status bitmap and visits
only set bits.

The POC combines both status flags into a bitmap and iterates active entries.
It also replaces:

- a 256-iteration population count with a constant-step SWAR popcount; and
- a 256-iteration highest-set-bit scan with eight binary-search steps.

### Measured impact

- Aggregate index: 47,114,515 to 40,976,922 (-13.03%).
- Empty account getter: 217,592 to 22,924 gas (-89.46%) at the bitmap stage;
  the final build is 22,939 gas.

### Core opportunity

Expose or recognize common `popcount`, `clz`/`fls`, and set-bit iteration
patterns. Straightforward fixed loops are catastrophically expensive here,
while the constant-step bit algorithms are compact and predictable.

## 3. Bounded dynamic ABI values charge for the maximum, not the value (a3)

### Observation

Solidity APIs use unbounded `bytes` and `bytes[]`. Vyper 0.5.0a3 requires
compile-time maxima. Large safe-looking bounds (`Bytes[4096]`, 64 calls) caused
huge ABI materialization and return-buffer overhead even when tests passed one
or two short calls.

Returning `DynArray[Bytes[4096], 64]` normally was especially expensive.
Changing Spoke multicall to `@raw_return` and returning `abi_encode(results)`
avoided an extra return encoding layer. Tightening theoretical POC bounds then
reduced the reserved memory further.

### Measured impact

| Spoke multicall | Initial Vyper | Final POC | Solidity |
|---|---:|---:|---:|
| permit + repay | 1,528,877 | 204,718 | 166,334 |
| permit + supply | 1,520,889 | 182,977 | 151,663 |
| permit + supply + collateral | 1,554,342 | 198,963 | 166,114 |
| supply + collateral | 1,516,228 | 178,730 | 146,316 |

The optimized a3 POC bounds were 4 calls, 512 bytes of calldata per call, and 256 bytes
of returndata per call. Signatures are capped at 256 bytes. These are semantic
domain restrictions, not production-transparent optimizations.

`SetUserPositionManagers.updates` must remain `DynArray[..., 1024]` to pass the
full Solidity fuzz domain. Calls involving it retain a nearly constant ~71k
penalty, making it a useful remaining reproducer for maximum-bound ABI cost.

### Core opportunity

Production-ready unbounded calldata views and dynamic arrays are the biggest
language-level opportunity. Short of that, codegen should allocate/copy based
on runtime length rather than eagerly reflecting maximum bounds. Zero-copy
calldata slices and direct ABI forwarding would help router and multicall code.

## 4. Pre-b1 unbounded-array experiments were not ready

An experimental dynamic-allocation/unbounded-array compiler branch was tested
against the POC. It regressed signature and EIP-712 behavior, so it was not used
for final measurements. On stock 0.5.0a3, attempting to manually decode a
runtime calldata slice typed as `Bytes[INF]` also triggered a compiler
`CodegenPanic` when converting it to a bounded `Bytes[4096]` value.

That a3 result therefore used stock 0.5.0a3 plus explicit bounded POC types.
Official 0.5.0b1 supersedes the experimental compiler for supported top-level
runtime arrays; the nested-dynamic and `raw_call` limitations above remain.

## 5. Aggressive Venom is a code-size optimization here, not a gas win

A controlled A/B run compiled the exact final sources at both Venom levels:

| Setting | Scenario index | Spoke runtime bytecode |
|---|---:|---:|
| `-O 2` | 24,050,614 | 24,667 bytes |
| `-O 3` | 24,053,993 | 21,602 bytes |

`-O 3` costs 3,379 gas on the aggregate index (+0.01%), which is noise-level
but not an execution-gas improvement. It removes 3,065 runtime bytes. `-O 2`
is 91 bytes over the EIP-170 limit; `-O 3` is deployable with 2,974 bytes of
headroom. The build therefore enforces Venom and `-O 3`.

## 6. Large-struct external calls are cheaper than duplicating logic

Inlining `LiquidationLogic` into Spoke was tested to remove an external call
carrying a large parameter struct. It saved only about 4.2k gas per liquidation
(~0.7%) but grew Spoke runtime to 27,400 bytes, 2,824 bytes above EIP-170. The
experiment was reverted. This suggests the external call is not a primary
remaining hotspot.

## 7. Storage-layout overrides compare type spelling, not compatibility

Changing a mapping value from `Asset` to `PackedAsset` while preserving the
same root slot caused `CompilerPanic: Computed storage layout does not match
override file`. The expected and actual layouts differed only in the mapping's
struct type name; both used one root slot at slot 1. Updating the JSON type
string made compilation succeed.

For upgradeable contracts, a structural compatibility check would be more
useful than exact pretty-printed type equality, or the error should be a normal
diagnostic rather than an internal compiler panic.

## Remaining measured gaps in optimized 0.5.0a3

After the implementation fixes, the largest categories versus Solidity are:

- Spoke getters: +61.61%.
- PositionManagerBase signed setup: +95.11%, dominated by the 1024-element
  bounded updates decoder.
- Spoke standard operations: +38.02%.
- Spoke zero-risk operations: +37.56%.
- Hub: +34.34%.
- SignatureGateway: +27.64%.
- TokenizationSpoke: +20.43%.

The remaining account-data gap grows with active positions: final Vyper is
+48.74% for one supply and +72.36% for two supplies plus two borrows. Likely
contributors are repeated manual unpacking, internal struct materialization,
and call/ABI overhead rather than sparse traversal, which is now fixed.

## Validation

- Gas suite: 86/86 passing, 137 recorded operations.
- Full b2 suite: 2,064 passing and zero failing; one pre-existing `pending rft`
  test remains skipped.

## 8. Latest-main and Forge 1.8 refresh

Upstream main `4d86c2d3` changed Forge/forge-std integration and gas snapshot
cheatcodes but no production Solidity contracts. The Vyper tree therefore
required no behavioral port for this update. A dedicated Foundry `vyper`
profile now writes artifacts to `out-vyper/` and omits Solidity-only additional
compiler profiles, avoiding Forge 1.8.x's ambiguous incremental resolution of
the two legitimate `LiquidationLogic` artifacts.

Matched gas runs used the checksummed official Forge 1.8.0 release and passed
86/86 tests in each mode. The latest-main scenario index is 17,999,249 for
Solidity and 22,743,051 for Vyper: +4,743,802 gas (+26.36%). Three operations
beat Solidity, 12 are equal, and 122 are above Solidity. The full Vyper profile
passes 2,064 tests with zero failures and the one pre-existing skip.

- Focused Hub suite: 313/313 passing.
- Focused position-manager suite: 277/277 passing.
- Final b1 Spoke runtime bytecode: 21,923 bytes, 2,653 bytes under EIP-170.
- Final b2 Spoke runtime bytecode: 22,339 bytes, 2,237 bytes under EIP-170.

## 9. PR #5232 amortizes local unbounded appends

Vyper PR #5232 changes a local `DynArray[T, INF]` from reallocating and copying
on every append to a pointer-and-capacity cell whose capacity doubles. This
changes repeated append from quadratic to amortized linear behavior. The exact
compiler control uses parent `5c3c019b`; the tested build uses merge commit
`8af5e83c`, both identifying as 0.5.0b2.

With unchanged Aave sources, the matched scenario index moves from 22,743,060
to 22,750,281: +7,221 gas (+0.03%). This is expected because most measured
arrays receive zero to four appends, where maintaining capacity adds a small
fixed cost. A direct `DynArray[uint256, INF]` append benchmark shows the actual
crossover and asymptotic gain:

| Appends | Before PR | After PR | Change |
|---:|---:|---:|---:|
| 4 | 23,079 | 23,483 | +1.75% |
| 16 | 27,949 | 27,227 | -2.58% |
| 32 | 36,350 | 31,822 | -12.46% |
| 64 | 65,360 | 40,797 | -37.58% |
| 100 | 139,742 | 51,235 | -63.34% |
| 256 | 2,486,355 | 94,435 | -96.20% |
| 500 | 32,076,611 | 164,363 | -99.49% |
| 1,000 | 496,552,687 | 313,942 | -99.94% |

The audit found one gas-motivated bound worth reversing. Spoke's signed batch
position-manager flow accumulated at most 1,024 update hashes in a bounded
local array. Restoring that accumulator and its encoded buffer to unbounded
types reduces the b2 scenario index from 22,750,281 to 22,321,268: -429,013
gas (-1.89%). The individual signature update paths save roughly 22% to 32%,
and multicalls containing one save roughly 12% to 14%. The final Vyper gap to
Solidity falls from +26.40% to +24.01%.

Other prior append changes should not be reversed:

- Hub and AccessManager enumerable collections moved from bounded storage
  arrays to mapping-plus-length storage. PR #5232 only optimizes local arrays,
  and unbounded storage arrays remain unsupported.
- Spoke multicall and AccessManager role-label results have ABI-dynamic element
  types. Vyper still rejects unbounded arrays of dynamic elements, so their raw
  ABI paths remain necessary.
- Account-data collateral collection is short in the tested domain, where the
  unbounded allocator's fixed cost regresses gas.
- Config-engine batches are capped at 32. A representative two-array benchmark
  at 32 elements costs 36,442 gas bounded versus 51,151 unbounded, so those
  locals remain bounded.

The result is deliberately selective: feature-parity arrays stay unbounded,
the long local hash accumulator is restored, and finite internal arrays remain
bounded where the compiler feature does not apply or measurement rejects it.
