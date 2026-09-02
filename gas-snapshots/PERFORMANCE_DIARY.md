# Vyper 0.5 performance diary

This diary records performance findings from the Aave v4 Vyper POC for Vyper
core developers. Measurements use Cancun, Venom via `--experimental-codegen`,
and the repository's matched 137-operation gas suite. The final build uses
official Vyper 0.5.0b1 and `-O 3`; earlier milestones used 0.5.0a3.

## Official 0.5.0b1 and runtime-array results

| Milestone | Scenario index | vs Solidity | vs previous |
|---|---:|---:|---:|
| Optimized 0.5.0a3 | 24,053,993 | +33.29% | — |
| 0.5.0b1 bounded control | 22,008,357 | +21.95% | -8.50% |
| 0.5.0b1 parity-oriented runtime arrays | 22,754,778 | +26.09% | +3.39% |

The official b1 release provides top-level `Bytes[INF]`, `String[INF]`, and
`DynArray[T, INF]` for ABI-static `T` under Venom. The POC now uses these for
signatures, interest-rate data, oracle batch getters, configurator batches, and
abstract payload methods. Production persistent enumerable arrays were replaced
with mapping-plus-length storage. Spoke multicall uses raw runtime decoding to
accept an unbounded `bytes[]` call count and unbounded per-call input size.

The runtime path is not a gas optimization in the small benchmark domain: it
adds 746,421 gas (+3.39%) versus the bounded b1 control. It is retained because
unbounded behavior is a feature-parity requirement. Even with that cost, the
final b1 build is 1,299,215 gas (-5.40%) below optimized a3.

The remaining compiler gaps are nested unbounded dynamic types, unbounded
storage arrays, and unbounded `raw_call` returndata. Vyper 0.5.0b1 rejects
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
- Full b1 suite: 2,064 passing and zero failing; one pre-existing `pending rft`
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
