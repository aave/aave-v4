Tested this against the Aave V4 port and a focused forwarding harness at
`58a453d402388cc1744db37082ec1e4f850550e5` (base `6f1aefb5909d0faaae580ad5c78e07426482aedb`).

Positive results:

- Whole successful returndata works through call/staticcall/delegatecall and
  internal forwarding, including lengths above our existing 256-byte and
  32768-byte per-call bounds. Largest tested response: 65537 bytes.
- Empty/unaligned responses, exact outer ABI encoding/padding, two live result
  buffers, complete revert bubbling and `(False, full_revert_data)` capture pass.
- A bounded `max_outsize=32` remains bounded when the consuming type is
  `Bytes[INF]`, including failure capture.
- All 9 harness tests pass under O2, O3 and O3 with inlining disabled, with
  128 success-size and 128 failure-size fuzz cases per configuration.
- All 41 existing Aave artifacts have identical creation/runtime bytecode,
  ABI and selectors versus the base when using identical compatible sources.
  This was not a rerun of the full Aave parity suite.

The standalone forwarder also avoids the fixed-buffer cost in our small
microbenchmark: a warm 32-byte result costs 3217 gas with `INF`, versus 17337
with a 32768-byte bound; at 32768 returned bytes, 74988 versus 85021. These
include call/return-copy overhead, not transaction intrinsic gas.

Two boundaries worth retaining in the documentation:

1. This addresses #5246 but not full multicall parity: `DynArray[Bytes[INF], INF]`
   is still rejected, so #5247 remains necessary for aggregating arbitrary
   successful results without a per-element cap.
2. Existing #5244 still dominates mixed contracts. Adding an *uncalled* sibling
   taking/returning `DynArray[Bytes[32768], 64]` raises the same 32-byte forwarding
   call from 3217 to 34054443 gas under O3, with identical output. This is not
   a claimed regression from this PR, and the measurement includes both input
   decoding and result handling. Runtime-sized capture does not, by itself,
   mean total memory cost depends only on the actual response length.

Overall: useful and working in these tests; this removes a real forwarding
capability blocker for us. Nested unbounded types and allocation isolation are
the remaining pieces, rather than reasons to hold this capability back.
