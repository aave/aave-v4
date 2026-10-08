# Babylon market

Two Hubs, `babylon-btc` for vaultBTC and `babylon-stables` for the borrowed stables, and one BabylonSpoke, deployed with `grantRoles = false`. The deployer keeps every role and ownership until the handover. Config per chain lives in `<chain>.json` next to this file. Only Sepolia is supported for now.

| Field                        | Meaning                                                                                              |
| ---------------------------- | ---------------------------------------------------------------------------------------------------- |
| `salt`                       | Deploy salt, `keccak256("aave-v4-babylon")`                                                          |
| `hubLabels`                  | Hub labels, `babylon-btc` and `babylon-stables`                                                      |
| `babylonSpokeLabel`          | BabylonSpoke label, `babylon`                                                                        |
| `liquidationManager`         | The only address allowed to liquidate on the BabylonSpoke. Immutable.                                |
| `managedCollateralReserveId` | The only reserve usable as collateral. Immutable, so the collateral must be the first reserve added. |
| `admin`                      | Receives every role and ownership at handover                                                        |
| `report`                     | Deployment report written by step 2, read by step 4                                                  |

`liquidationManager` and `admin` are zero placeholders in the checked-in config. Deployment reverts while `liquidationManager` is unset, and the handover reverts while `admin` is unset.

## Steps

1. `make babylon-precompile chain=sepolia account=<keystore>` deploys `LiquidationLogic` at `0x88dF535473C5adf1f57789734A05E555F7Deb8DB` if missing, then `BabylonLiquidationLogic` linked against it, and writes `FOUNDRY_LIBRARIES` to `.env`.
2. `make babylon-deploy chain=sepolia account=<keystore>` deploys the market and writes the report to `output/reports/deployments/`. Set `report` in the config to that file.
3. Configure the market from the deployer, which holds the AccessManager admin role.
4. `make babylon-handover chain=sepolia account=<keystore>` grants `admin` the roles `grantRoles = true` would have granted, transfers every ProxyAdmin, nominates `admin` as TreasurySpoke owner and removes every role the deployer holds. It reverts unless the deployer ends with nothing.
5. `admin` calls `acceptOwnership()` on the TreasurySpoke.

Add `dry=true` to steps 1, 2 and 4 to simulate.
