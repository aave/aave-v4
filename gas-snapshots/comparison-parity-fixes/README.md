# Solidity vs Vyper gas snapshots

These are matched runs of the repository's `tests/gas/**` suite. The Solidity run
uses the repository compiler profiles; the Vyper run uses Vyper 0.5.0b2 at
merge commit `8af5e83c` (PR #5232), with Venom enforced through
`--experimental-codegen`. Recorded Foundry version: 1.8.1; target Cancun.
the Vyper profile isolates artifacts from Solidity's additional
compiler profiles without changing production bytecode settings.

The snapshots contain
137 measured operations across 11 files.

The sum across independent scenarios is a comparison index, not the cost of a
single transaction. On that index, Vyper used
22,277,132 gas versus Solidity's 17,999,249 gas:
+4,277,883 gas (+23.77%).
1 operations improved, 13 were unchanged, and
123 regressed.

## Category totals

| Snapshot | Ops | Solidity | Vyper | Delta | Delta % |
|---|---:|---:|---:|---:|---:|
| ConfigPositionManager.Operations.json | 11 | 582,821 | 639,227 | +56,406 | +9.68% |
| GiverPositionManager.Operations.json | 2 | 319,569 | 367,201 | +47,632 | +14.91% |
| Hub.Operations.json | 16 | 1,583,520 | 1,976,051 | +392,531 | +24.79% |
| NativeTokenGateway.Operations.json | 6 | 987,939 | 1,161,931 | +173,992 | +17.61% |
| PositionManagerBase.Operations.json | 1 | 75,041 | 89,162 | +14,121 | +18.82% |
| SignatureGateway.Operations.json | 8 | 991,297 | 1,149,841 | +158,544 | +15.99% |
| Spoke.Getters.json | 5 | 405,161 | 639,053 | +233,892 | +57.73% |
| Spoke.Operations.ZeroRiskPremium.json | 32 | 4,918,553 | 6,305,709 | +1,387,156 | +28.20% |
| Spoke.Operations.json | 32 | 5,587,371 | 7,086,536 | +1,499,165 | +26.83% |
| TakerPositionManager.Operations.json | 9 | 885,387 | 973,097 | +87,710 | +9.91% |
| TokenizationSpoke.Operations.json | 15 | 1,662,590 | 1,889,324 | +226,734 | +13.64% |

## Representative operations

| Snapshot | Operation | Solidity | Vyper | Delta | Delta % |
|---|---|---:|---:|---:|---:|
| Hub.Operations.json | add | 91,610 | 109,118 | +17,508 | +19.11% |
| Hub.Operations.json | draw | 109,072 | 124,230 | +15,158 | +13.90% |
| Spoke.Operations.json | borrow: first | 269,297 | 329,340 | +60,043 | +22.30% |
| Spoke.Operations.json | liquidationCall: partial | 360,696 | 449,697 | +89,001 | +24.67% |
| Spoke.Operations.json | repay: partial | 142,713 | 170,278 | +27,565 | +19.31% |
| Spoke.Operations.json | supply: 0 borrows, collateral disabled | 127,753 | 151,217 | +23,464 | +18.37% |
| Spoke.Operations.json | withdraw: 0 borrows, partial | 140,394 | 180,177 | +39,783 | +28.34% |
| TokenizationSpoke.Operations.json | deposit | 118,614 | 135,464 | +16,850 | +14.21% |
| TokenizationSpoke.Operations.json | permit | 62,766 | 61,759 | -1,007 | -1.60% |
| TokenizationSpoke.Operations.json | withdraw: self, partial | 114,024 | 130,158 | +16,134 | +14.15% |

## Best result

| Snapshot | Operation | Solidity | Vyper | Delta | Delta % |
|---|---|---:|---:|---:|---:|
| TokenizationSpoke.Operations.json | permit | 62,766 | 61,759 | -1,007 | -1.60% |

## Largest percentage regressions

| Snapshot | Operation | Solidity | Vyper | Delta | Delta % |
|---|---|---:|---:|---:|---:|
| Spoke.Getters.json | getUserAccountData: supplies: 0, borrows: 0 | 13,014 | 24,730 | +11,716 | +90.03% |
| Spoke.Getters.json | getUserAccountData: supplies: 2, borrows: 2 | 133,792 | 222,676 | +88,884 | +66.43% |
| Spoke.Getters.json | getUserAccountData: supplies: 2, borrows: 1 | 112,389 | 177,861 | +65,472 | +58.25% |
| Spoke.Operations.ZeroRiskPremium.json | usingAsCollateral: 2 borrows, disable | 138,182 | 212,697 | +74,515 | +53.93% |
| Spoke.Getters.json | getUserAccountData: supplies: 1, borrows: 0 | 56,072 | 82,728 | +26,656 | +47.54% |
| Spoke.Operations.ZeroRiskPremium.json | updateUserRiskPremium: 1 borrow | 104,446 | 153,186 | +48,740 | +46.67% |
| Spoke.Operations.ZeroRiskPremium.json | usingAsCollateral: 1 borrow, disable | 114,490 | 167,592 | +53,102 | +46.38% |
| Spoke.Getters.json | getUserAccountData: supplies: 2, borrows: 0 | 89,894 | 131,058 | +41,164 | +45.79% |
| Spoke.Operations.ZeroRiskPremium.json | withdraw: 2 borrows, partial | 186,292 | 271,106 | +84,814 | +45.53% |
| Hub.Operations.json | restore: full - with transfer | 188,919 | 270,851 | +81,932 | +43.37% |

## Interpretation

These measurements do not isolate the cause of a performance difference or
establish full behavioral equivalence. See COMPILER_FEEDBACK_DIARY.md for
the implementation status, current API limits, compiler examples, and test evidence.

1 operations beat Solidity and 13 are
byte-for-byte equal in the snapshots.

## Reproduce

```sh
forge test --mp 'tests/gas/**' -vv
.venv/bin/python scripts/build_vyper.py
FOUNDRY_PROFILE=vyper TEST_VYPER=true forge test --mp 'tests/gas/**' -vv
python3 scripts/compare_vyper_gas.py <solidity-snapshots> <vyper-snapshots> <output> --foundry-version <version>
```

Foundry writes both implementations to `snapshots/*.json`, so copy each run
into its matching `gas-snapshots/` directory before starting the next run.
The complete per-operation data is in `comparison.json`.
