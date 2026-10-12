# Babylon market

Two Hubs, `babylon-btc` for vaultBTC and `babylon-stables` for the borrowed stables, and one BabylonSpoke, deployed with `grantRoles = false`. The deployer keeps every role and ownership until the handover. Config per chain lives in `<chain>.json` next to this file. Only Sepolia is supported for now.

| Field                        | Meaning                                                                                               |
| ---------------------------- | ----------------------------------------------------------------------------------------------------- |
| `salt`                       | Deploy salt, `keccak256("aave-v4-babylon-v2")`                                                        |
| `hubLabels`                  | Hub labels, `babylon-btc` and `babylon-stables`                                                       |
| `babylonSpokeLabel`          | BabylonSpoke label, `babylon`                                                                         |
| `liquidationManager`         | The only address allowed to liquidate on the BabylonSpoke. Immutable.                                 |
| `managedCollateralReserveId` | The only reserve usable as collateral. Immutable, so the collateral must be the first reserve added.  |
| `admin`                      | Receives every role and ownership at handover                                                         |
| `report`                     | Deployment report written by step 2, read by steps 3 and 4                                            |
| `reserves`                   | BabylonSpoke reserves in reserve id order, each listed on its `hub` and connected to the BabylonSpoke |
| `liquidationConfig`          | BabylonSpoke liquidation config                                                                       |

On Sepolia, `liquidationManager` is the AaveAdapter at its precomputed address `0x6A785E8fdF251E2aA758a6E1841e1470074f46BF`. `admin` is a zero placeholder, and the handover reverts while it is unset.

## Steps

1. `make babylon-precompile chain=sepolia account=<keystore>` deploys `LiquidationLogic` at `0x88dF535473C5adf1f57789734A05E555F7Deb8DB` if missing, then `BabylonLiquidationLogic` linked against it, and writes `FOUNDRY_LIBRARIES` to `.env`.
2. `make babylon-deploy chain=sepolia account=<keystore>` deploys the market and writes the report to `output/reports/deployments/`. Copy it to `reports/<chain>.json` and set `report` in the config to that path.
3. `make babylon-configure chain=sepolia account=<keystore>` configures the market from the deployer. It grants the deployer the HubConfigurator and SpokeConfigurator domain admin roles, and grants the configurators their Hub and Spoke roles. Then it lists each reserve on its Hub with the TreasurySpoke as fee receiver, connects the BabylonSpoke, adds the reserve and sets the liquidation config. It reverts if the BabylonSpoke already has reserves.
4. `make babylon-handover chain=sepolia account=<keystore>` grants `admin` the HubConfigurator and SpokeConfigurator domain admin roles, transfers every ProxyAdmin, nominates `admin` as TreasurySpoke owner and removes every role the deployer holds. It reverts unless the roles end as below and every ProxyAdmin is owned by `admin`.
5. `admin` calls `acceptOwnership()` on the TreasurySpoke.
6. `make babylon-verify chain=sepolia` checks the whole market against the config without sending anything: contract wiring, roles, every ProxyAdmin owner, TreasurySpoke ownership and every reserve.

The roles end as on Ethereum, with every governance holder replaced by `admin`:

| Role                                    | Holder            |
| --------------------------------------- | ----------------- |
| 0 ACCESS_MANAGER_ADMIN                  | admin             |
| 101 HUB_CONFIGURATOR_ROLE               | HubConfigurator   |
| 200 HUB_CONFIGURATOR_DOMAIN_ADMIN       | admin             |
| 301 SPOKE_CONFIGURATOR_ROLE             | SpokeConfigurator |
| 400 SPOKE_CONFIGURATOR_DOMAIN_ADMIN     | admin             |
| 100, 102, 103, 300, 302 and other roles | nobody            |

Add `dry=true` to steps 1 to 4 to simulate. On Sepolia, forge underestimates gas for these transactions, so also pass `gas_multiplier=1000` to steps 1 to 4.
