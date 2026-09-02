# Solidity vs Vyper gas snapshots

These are matched runs of the repository's `tests/gas/**` suite. The Solidity run
uses the repository compiler profiles; the Vyper run uses Vyper 0.5.0b1 with
Venom enforced through `--experimental-codegen`. Both target Cancun.

Each run passed 86/86 tests. The snapshots contain
137 measured operations across 11 files.

The sum across independent scenarios is a comparison index, not the cost of a
single transaction. On that index, Vyper used
22,754,778 gas versus Solidity's 18,046,597 gas:
+4,708,181 gas (+26.09%).
2 operations improved, 14 were unchanged, and
121 regressed.

## Category totals

| Snapshot | Ops | Solidity | Vyper | Delta | Delta % |
|---|---:|---:|---:|---:|---:|
| ConfigPositionManager.Operations.json | 11 | 582,821 | 626,022 | +43,201 | +7.41% |
| GiverPositionManager.Operations.json | 2 | 319,569 | 375,300 | +55,731 | +17.44% |
| Hub.Operations.json | 16 | 1,583,520 | 2,007,873 | +424,353 | +26.80% |
| NativeTokenGateway.Operations.json | 6 | 987,939 | 1,184,176 | +196,237 | +19.86% |
| PositionManagerBase.Operations.json | 1 | 75,041 | 121,012 | +45,971 | +61.26% |
| SignatureGateway.Operations.json | 8 | 991,321 | 1,176,013 | +184,692 | +18.63% |
| Spoke.Getters.json | 5 | 405,161 | 578,239 | +173,078 | +42.72% |
| Spoke.Operations.ZeroRiskPremium.json | 32 | 4,942,161 | 6,496,483 | +1,554,322 | +31.45% |
| Spoke.Operations.json | 32 | 5,611,075 | 7,308,448 | +1,697,373 | +30.25% |
| TakerPositionManager.Operations.json | 9 | 885,399 | 980,975 | +95,576 | +10.79% |
| TokenizationSpoke.Operations.json | 15 | 1,662,590 | 1,900,237 | +237,647 | +14.29% |

## Representative operations

| Snapshot | Operation | Solidity | Vyper | Delta | Delta % |
|---|---|---:|---:|---:|---:|
| Hub.Operations.json | add | 91,610 | 110,662 | +19,052 | +20.80% |
| Hub.Operations.json | draw | 109,072 | 126,809 | +17,737 | +16.26% |
| Spoke.Operations.json | borrow: first | 269,297 | 327,528 | +58,231 | +21.62% |
| Spoke.Operations.json | liquidationCall: partial | 365,078 | 446,156 | +81,078 | +22.21% |
| Spoke.Operations.json | repay: partial | 142,713 | 176,379 | +33,666 | +23.59% |
| Spoke.Operations.json | supply: 0 borrows, collateral disabled | 127,753 | 157,412 | +29,659 | +23.22% |
| Spoke.Operations.json | withdraw: 0 borrows, partial | 140,394 | 176,186 | +35,792 | +25.49% |
| TokenizationSpoke.Operations.json | deposit | 118,614 | 137,028 | +18,414 | +15.52% |
| TokenizationSpoke.Operations.json | permit | 62,766 | 61,752 | -1,014 | -1.62% |
| TokenizationSpoke.Operations.json | withdraw: self, partial | 114,024 | 131,748 | +17,724 | +15.54% |

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
| Spoke.Getters.json | getUserAccountData: supplies: 2, borrows: 2 | 133,792 | 210,074 | +76,282 | +57.02% |
| Spoke.Operations.ZeroRiskPremium.json | supply + enable collateral (multicall) | 146,316 | 227,526 | +81,210 | +55.50% |
| Spoke.Operations.json | supply + enable collateral (multicall) | 146,316 | 227,526 | +81,210 | +55.50% |
| Spoke.Operations.ZeroRiskPremium.json | permitReserve + supply (multicall) | 151,663 | 229,309 | +77,646 | +51.20% |

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
testing. The empty-account getter and Tokenization Spoke `permit` beat
Solidity; 14 operations are byte-for-byte equal in the snapshots.

## Reproduce

```sh
forge test --mp 'tests/gas/**' -vv
.venv/bin/python scripts/build_vyper.py
TEST_VYPER=true forge test --mp 'tests/gas/**' -vv
python3 scripts/compare_vyper_gas.py gas-snapshots/solidity \
  gas-snapshots/vyper-b1-unbounded gas-snapshots/comparison-b1-unbounded
```

Foundry writes both implementations to `snapshots/*.json`, so copy each run
into its matching `gas-snapshots/` directory before starting the next run.
The complete per-operation data is in `comparison.json`.
