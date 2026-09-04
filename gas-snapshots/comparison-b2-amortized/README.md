# Solidity vs Vyper gas snapshots

These are matched runs of the repository's `tests/gas/**` suite. The Solidity run
uses the repository compiler profiles; the Vyper run uses Vyper 0.5.0b2 at
merge commit `8af5e83c` (PR #5232), with Venom enforced through
`--experimental-codegen`. Both use verified Foundry 1.8.0 and target Cancun;
the Vyper profile isolates artifacts from Solidity's additional
compiler profiles without changing production bytecode settings.

Each run passed 86/86 tests. The snapshots contain
137 measured operations across 11 files.

The sum across independent scenarios is a comparison index, not the cost of a
single transaction. On that index, Vyper used
22,321,268 gas versus Solidity's 17,999,249 gas:
+4,322,019 gas (+24.01%).
2 operations improved, 14 were unchanged, and
121 regressed.

## Category totals

| Snapshot | Ops | Solidity | Vyper | Delta | Delta % |
|---|---:|---:|---:|---:|---:|
| ConfigPositionManager.Operations.json | 11 | 582,821 | 625,760 | +42,939 | +7.37% |
| GiverPositionManager.Operations.json | 2 | 319,569 | 374,950 | +55,381 | +17.33% |
| Hub.Operations.json | 16 | 1,583,520 | 2,008,278 | +424,758 | +26.82% |
| NativeTokenGateway.Operations.json | 6 | 987,939 | 1,183,039 | +195,100 | +19.75% |
| PositionManagerBase.Operations.json | 1 | 75,041 | 91,532 | +16,491 | +21.98% |
| SignatureGateway.Operations.json | 8 | 991,297 | 1,145,757 | +154,460 | +15.58% |
| Spoke.Getters.json | 5 | 405,161 | 577,739 | +172,578 | +42.59% |
| Spoke.Operations.ZeroRiskPremium.json | 32 | 4,918,553 | 6,310,313 | +1,391,760 | +28.30% |
| Spoke.Operations.json | 32 | 5,587,371 | 7,122,902 | +1,535,531 | +27.48% |
| TakerPositionManager.Operations.json | 9 | 885,387 | 980,281 | +94,894 | +10.72% |
| TokenizationSpoke.Operations.json | 15 | 1,662,590 | 1,900,717 | +238,127 | +14.32% |

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
| Spoke.Getters.json | getUserAccountData: supplies: 2, borrows: 2 | 133,792 | 209,874 | +76,082 | +56.87% |
| Spoke.Operations.ZeroRiskPremium.json | usingAsCollateral: 2 borrows, disable | 138,182 | 206,443 | +68,261 | +49.40% |
| Spoke.Operations.ZeroRiskPremium.json | setUserPositionManagersWithSig: enable | 68,684 | 102,275 | +33,591 | +48.91% |
| Spoke.Operations.json | setUserPositionManagersWithSig: enable | 68,684 | 102,275 | +33,591 | +48.91% |
| Spoke.Getters.json | getUserAccountData: supplies: 2, borrows: 1 | 112,389 | 165,087 | +52,698 | +46.89% |
| Hub.Operations.json | restore: full - with transfer | 188,919 | 273,328 | +84,409 | +44.68% |
| Spoke.Operations.ZeroRiskPremium.json | withdraw: 2 borrows, partial | 186,292 | 266,525 | +80,233 | +43.07% |
| Spoke.Operations.ZeroRiskPremium.json | usingAsCollateral: 1 borrow, disable | 114,490 | 161,366 | +46,876 | +40.94% |
| Hub.Operations.json | transferShares | 74,540 | 103,853 | +29,313 | +39.33% |
| Spoke.Operations.ZeroRiskPremium.json | updateUserRiskPremium: 1 borrow | 104,446 | 145,164 | +40,718 | +38.98% |

## Interpretation

The two Spoke operation files contribute most of the absolute delta. The
Vyper implementation uses the same compact position bitmap strategy as the
Solidity implementation, but manual packed-storage conversion, internal
struct materialization, and cross-contract ABI work remain more expensive.

Spoke multicall now accepts an unbounded `bytes[]` ABI domain through raw
runtime decoding because Vyper 0.5.0b2 cannot type nested unbounded dynamic
arrays directly. That parity path is slower than the bounded decoder in the
small measured cases. Vyper also still requires a finite `raw_call` output
bound, so each delegated result remains capped at 256 bytes.

The signed position-manager setup rows also include an extra persistent
write used to preserve explicit boolean state under Foundry arbitrary-storage
testing.
2 operations beat Solidity and 14 are
byte-for-byte equal in the snapshots.

## Reproduce

```sh
forge test --mp 'tests/gas/**' -vv
.venv/bin/python scripts/build_vyper.py
FOUNDRY_PROFILE=vyper TEST_VYPER=true forge test --mp 'tests/gas/**' -vv
python3 scripts/compare_vyper_gas.py gas-snapshots/solidity \
  gas-snapshots/vyper-b2-amortized-restored gas-snapshots/comparison-b2-amortized
```

Foundry writes both implementations to `snapshots/*.json`, so copy each run
into its matching `gas-snapshots/` directory before starting the next run.
The complete per-operation data is in `comparison.json`.
