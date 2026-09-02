# Solidity vs Vyper gas snapshots

These are matched runs of the repository's `tests/gas/**` suite. The Solidity run
uses the repository compiler profiles; the Vyper run uses Vyper 0.5.0b1 with
Venom enforced through `--experimental-codegen`. Both use verified Foundry 1.8.0
and target Cancun; the Vyper profile isolates artifacts from Solidity's additional
compiler profiles without changing production bytecode settings.

Each run passed 86/86 tests. The snapshots contain
137 measured operations across 11 files.

The sum across independent scenarios is a comparison index, not the cost of a
single transaction. On that index, Vyper used
22,743,051 gas versus Solidity's 17,999,249 gas:
+4,743,802 gas (+26.36%).
3 operations improved, 12 were unchanged, and
122 regressed.

## Category totals

| Snapshot | Ops | Solidity | Vyper | Delta | Delta % |
|---|---:|---:|---:|---:|---:|
| ConfigPositionManager.Operations.json | 11 | 582,821 | 625,760 | +42,939 | +7.37% |
| GiverPositionManager.Operations.json | 2 | 319,569 | 374,950 | +55,381 | +17.33% |
| Hub.Operations.json | 16 | 1,583,520 | 2,008,278 | +424,758 | +26.82% |
| NativeTokenGateway.Operations.json | 6 | 987,939 | 1,183,039 | +195,100 | +19.75% |
| PositionManagerBase.Operations.json | 1 | 75,041 | 121,012 | +45,971 | +61.26% |
| SignatureGateway.Operations.json | 8 | 991,297 | 1,175,204 | +183,907 | +18.55% |
| Spoke.Getters.json | 5 | 405,161 | 577,739 | +172,578 | +42.59% |
| Spoke.Operations.ZeroRiskPremium.json | 32 | 4,918,553 | 6,491,847 | +1,573,294 | +31.99% |
| Spoke.Operations.json | 32 | 5,587,371 | 7,304,436 | +1,717,065 | +30.73% |
| TakerPositionManager.Operations.json | 9 | 885,387 | 980,281 | +94,894 | +10.72% |
| TokenizationSpoke.Operations.json | 15 | 1,662,590 | 1,900,505 | +237,915 | +14.31% |

## Representative operations

| Snapshot | Operation | Solidity | Vyper | Delta | Delta % |
|---|---|---:|---:|---:|---:|
| Hub.Operations.json | add | 91,610 | 110,668 | +19,058 | +20.80% |
| Hub.Operations.json | draw | 109,072 | 126,824 | +17,752 | +16.28% |
| Spoke.Operations.json | borrow: first | 269,297 | 327,390 | +58,093 | +21.57% |
| Spoke.Operations.json | liquidationCall: partial | 360,696 | 445,798 | +85,102 | +23.59% |
| Spoke.Operations.json | repay: partial | 142,713 | 176,334 | +33,621 | +23.56% |
| Spoke.Operations.json | supply: 0 borrows, collateral disabled | 127,753 | 157,334 | +29,581 | +23.15% |
| Spoke.Operations.json | withdraw: 0 borrows, partial | 140,394 | 176,071 | +35,677 | +25.41% |
| TokenizationSpoke.Operations.json | deposit | 118,614 | 137,040 | +18,426 | +15.53% |
| TokenizationSpoke.Operations.json | permit | 62,766 | 61,752 | -1,014 | -1.62% |
| TokenizationSpoke.Operations.json | withdraw: self, partial | 114,024 | 131,770 | +17,746 | +15.56% |

## Best result

| Snapshot | Operation | Solidity | Vyper | Delta | Delta % |
|---|---|---:|---:|---:|---:|
| TokenizationSpoke.Operations.json | permit | 62,766 | 61,752 | -1,014 | -1.62% |

## Largest percentage regressions

| Snapshot | Operation | Solidity | Vyper | Delta | Delta % |
|---|---|---:|---:|---:|---:|
| Spoke.Operations.ZeroRiskPremium.json | setUserPositionManagersWithSig: disable | 46,772 | 92,743 | +45,971 | +98.29% |
| Spoke.Operations.json | setUserPositionManagersWithSig: disable | 46,772 | 92,743 | +45,971 | +98.29% |
| Spoke.Operations.ZeroRiskPremium.json | setUserPositionManagersWithSig: enable | 68,684 | 131,755 | +63,071 | +91.83% |
| Spoke.Operations.json | setUserPositionManagersWithSig: enable | 68,684 | 131,755 | +63,071 | +91.83% |
| PositionManagerBase.Operations.json | setSelfAsUserPositionManagerWithSig | 75,041 | 121,012 | +45,971 | +61.26% |
| SignatureGateway.Operations.json | setSelfAsUserPositionManagerWithSig | 75,138 | 121,109 | +45,971 | +61.18% |
| Spoke.Getters.json | getUserAccountData: supplies: 2, borrows: 2 | 133,792 | 209,874 | +76,082 | +56.87% |
| Spoke.Operations.ZeroRiskPremium.json | supply + enable collateral (multicall) | 146,316 | 227,347 | +81,031 | +55.38% |
| Spoke.Operations.json | supply + enable collateral (multicall) | 146,316 | 227,347 | +81,031 | +55.38% |
| Spoke.Operations.ZeroRiskPremium.json | permitReserve + supply (multicall) | 151,663 | 229,192 | +77,529 | +51.12% |

## Interpretation

The two Spoke operation files contribute most of the absolute delta. The
Vyper implementation uses the same compact position bitmap strategy as the
Solidity implementation, but manual packed-storage conversion, internal
struct materialization, and cross-contract ABI work remain more expensive.

Spoke multicall now accepts an unbounded `bytes[]` ABI domain through raw
runtime decoding because Vyper 0.5.0b1 cannot type nested unbounded dynamic
arrays directly. That parity path is slower than b1's bounded decoder in the
small measured cases. Vyper also still requires a finite `raw_call` output
bound, so each delegated result remains capped at 256 bytes.

The signed position-manager setup rows also include an extra persistent
write used to preserve explicit boolean state under Foundry arbitrary-storage
testing.
3 operations beat Solidity and 12 are
byte-for-byte equal in the snapshots.

## Reproduce

```sh
forge test --mp 'tests/gas/**' -vv
.venv/bin/python scripts/build_vyper.py
FOUNDRY_PROFILE=vyper TEST_VYPER=true forge test --mp 'tests/gas/**' -vv
python3 scripts/compare_vyper_gas.py gas-snapshots/solidity \
  gas-snapshots/vyper-b1-unbounded gas-snapshots/comparison-b1-unbounded
```

Foundry writes both implementations to `snapshots/*.json`, so copy each run
into its matching `gas-snapshots/` directory before starting the next run.
The complete per-operation data is in `comparison.json`.
