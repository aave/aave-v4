# Solidity vs Vyper gas snapshots

These are matched runs of the repository's `tests/gas/**` suite. The Solidity run
uses the repository compiler profiles; the Vyper run uses Vyper 0.5.0a3 with
Venom enforced through `--experimental-codegen`. Both target Cancun.

Each run passed 86/86 tests. The snapshots contain
137 measured operations across 11 files.

The sum across independent scenarios is a comparison index, not the cost of a
single transaction. On that index, Vyper used
47,114,515 gas versus Solidity's 18,046,597 gas:
+29,067,918 gas (+161.07%).
One operation improved, 14 were unchanged, and
122 regressed.

## Category totals

| Snapshot | Ops | Solidity | Vyper | Delta | Delta % |
|---|---:|---:|---:|---:|---:|
| ConfigPositionManager.Operations.json | 11 | 582,821 | 1,068,598 | +485,777 | +83.35% |
| GiverPositionManager.Operations.json | 2 | 319,569 | 486,487 | +166,918 | +52.23% |
| Hub.Operations.json | 16 | 1,583,520 | 2,818,352 | +1,234,832 | +77.98% |
| NativeTokenGateway.Operations.json | 6 | 987,939 | 1,656,785 | +668,846 | +67.70% |
| PositionManagerBase.Operations.json | 1 | 75,041 | 149,604 | +74,563 | +99.36% |
| SignatureGateway.Operations.json | 8 | 991,321 | 2,010,734 | +1,019,413 | +102.83% |
| Spoke.Getters.json | 5 | 405,161 | 1,591,289 | +1,186,128 | +292.75% |
| Spoke.Operations.ZeroRiskPremium.json | 32 | 4,942,161 | 16,171,848 | +11,229,687 | +227.22% |
| Spoke.Operations.json | 32 | 5,611,075 | 17,412,945 | +11,801,870 | +210.33% |
| TakerPositionManager.Operations.json | 9 | 885,399 | 1,400,899 | +515,500 | +58.22% |
| TokenizationSpoke.Operations.json | 15 | 1,662,590 | 2,346,974 | +684,384 | +41.16% |

## Representative operations

| Snapshot | Operation | Solidity | Vyper | Delta | Delta % |
|---|---|---:|---:|---:|---:|
| Hub.Operations.json | add | 91,610 | 176,001 | +84,391 | +92.12% |
| Hub.Operations.json | draw | 109,072 | 178,547 | +69,475 | +63.70% |
| Spoke.Operations.json | borrow: first | 269,297 | 602,706 | +333,409 | +123.81% |
| Spoke.Operations.json | liquidationCall: partial | 365,078 | 808,538 | +443,460 | +121.47% |
| Spoke.Operations.json | repay: partial | 142,713 | 233,940 | +91,227 | +63.92% |
| Spoke.Operations.json | supply: 0 borrows, collateral disabled | 127,753 | 216,216 | +88,463 | +69.25% |
| Spoke.Operations.json | withdraw: 0 borrows, partial | 140,394 | 397,192 | +256,798 | +182.91% |
| TokenizationSpoke.Operations.json | deposit | 118,614 | 171,780 | +53,166 | +44.82% |
| TokenizationSpoke.Operations.json | permit | 62,766 | 61,812 | -954 | -1.52% |
| TokenizationSpoke.Operations.json | withdraw: self, partial | 114,024 | 166,497 | +52,473 | +46.02% |

## Best result

| Snapshot | Operation | Solidity | Vyper | Delta | Delta % |
|---|---|---:|---:|---:|---:|
| TokenizationSpoke.Operations.json | permit | 62,766 | 61,812 | -954 | -1.52% |

## Largest percentage regressions

| Snapshot | Operation | Solidity | Vyper | Delta | Delta % |
|---|---|---:|---:|---:|---:|
| Spoke.Getters.json | getUserAccountData: supplies: 0, borrows: 0 | 13,014 | 217,592 | +204,578 | +1571.98% |
| Spoke.Operations.ZeroRiskPremium.json | supply + enable collateral (multicall) | 146,316 | 1,516,228 | +1,369,912 | +936.27% |
| Spoke.Operations.json | supply + enable collateral (multicall) | 146,316 | 1,516,228 | +1,369,912 | +936.27% |
| Spoke.Operations.ZeroRiskPremium.json | permitReserve + supply (multicall) | 151,663 | 1,520,889 | +1,369,226 | +902.81% |
| Spoke.Operations.json | permitReserve + supply (multicall) | 151,663 | 1,520,889 | +1,369,226 | +902.81% |
| Spoke.Operations.ZeroRiskPremium.json | permitReserve + supply + enable collateral (multicall) | 166,114 | 1,554,342 | +1,388,228 | +835.71% |
| Spoke.Operations.json | permitReserve + supply + enable collateral (multicall) | 166,114 | 1,554,342 | +1,388,228 | +835.71% |
| Spoke.Operations.json | permitReserve + repay (multicall) | 166,334 | 1,528,877 | +1,362,543 | +819.16% |
| Spoke.Operations.ZeroRiskPremium.json | permitReserve + repay (multicall) | 169,938 | 1,540,404 | +1,370,466 | +806.45% |
| ConfigPositionManager.Operations.json | updateUserDynamicConfigOnBehalfOf | 52,342 | 259,908 | +207,566 | +396.56% |

## Interpretation

The largest hotspot is `Spoke` account-data evaluation. Solidity walks a
compact position-status bitmap and visits only active reserves. The current
Vyper implementation keeps separate collateral/borrowing maps, walks every
listed reserve, loads its reserve and user-position records, and fetches an
oracle price before checking whether that reserve is active. This explains
why even the empty-account getter rises from 13,014 to 217,592 gas and why
the same overhead propagates into borrow, withdraw, liquidation, and risk
premium operations.

The other clear hotspot is multicall. Solidity accepts unbounded calldata
bytes arrays, while Vyper requires bounded `DynArray[Bytes[4096], 64]` input
and output types. The measured multicalls are 806% to 936% more expensive.
The source shape and measurements strongly suggest ABI materialization and
large bounded byte buffers are the main contributor, although opcode traces
would be needed to apportion that overhead exactly.

Outside those hotspots, Vyper remains higher across most categories but by
smaller margins: Tokenization Spoke is +41.16%, Giver Position Manager
is +52.23%, and Hub is +77.98% on their scenario-sum indices. `permit` on
Tokenization Spoke is the sole improvement at -1.52%; 14 operations are
unchanged.

## Reproduce

```sh
forge test --mp 'tests/gas/**' -vv
.venv/bin/python scripts/build_vyper.py
TEST_VYPER=true forge test --mp 'tests/gas/**' -vv
python3 scripts/compare_vyper_gas.py gas-snapshots/solidity gas-snapshots/vyper gas-snapshots
```

Foundry writes both implementations to `snapshots/*.json`, so copy each run
into its matching `gas-snapshots/` directory before starting the next run.
The complete per-operation data is in `comparison.json`.
