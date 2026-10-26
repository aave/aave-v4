# Babylon market

Two Hubs, `babylon-btc` for vaultBTC and `babylon-stables` for the borrowed stables, and one BabylonSpoke, deployed with `grantRoles = false`. The deployer keeps every role and ownership until the handover. Each deployment has its own config, `config/<config>.json`, picked with `config=<config>` on every step. The scripts revert when the config's `chainId` is not the RPC's chain.

| Config         | Chain    | Purpose                                                       |
| -------------- | -------- | ------------------------------------------------------------- |
| `sepolia`      | Sepolia  | Testnet market                                                |
| `mainnet-test` | Ethereum | Test market on mainnet, with its own deploy and library salts |

A production mainnet market gets its own config, so it never shares an address with `mainnet-test`.

| Field                        | Meaning                                                                                               |
| ---------------------------- | ----------------------------------------------------------------------------------------------------- |
| `chainId`                    | Chain the config is for                                                                               |
| `salt`                       | Deploy salt                                                                                           |
| `librarySalt`                | CREATE2 salt of LiquidationLogic and BabylonLiquidationLogic                                          |
| `hubLabels`                  | Hub labels, `babylon-btc` and `babylon-stables`                                                       |
| `babylonSpokeLabel`          | BabylonSpoke label, `babylon`                                                                         |
| `liquidationManager`         | The only address allowed to liquidate on the BabylonSpoke. Immutable.                                 |
| `managedCollateralReserveId` | The only reserve usable as collateral. Immutable, so the collateral must be the first reserve added.  |
| `admin`                      | Receives every role and ownership at handover                                                         |
| `report`                     | Deployment report written by step 2, read by steps 3 and 4                                            |
| `reserves`                   | BabylonSpoke reserves in reserve id order, each listed on its `hub` and connected to the BabylonSpoke |
| `liquidationConfig`          | BabylonSpoke liquidation config                                                                       |

On Sepolia, `salt` is `keccak256("aave-v4-babylon-v2")`, `librarySalt` is the canonical `0x2bdf` and `liquidationManager` is the AaveAdapter at its precomputed address `0x6A785E8fdF251E2aA758a6E1841e1470074f46BF`.

On `mainnet-test`, `salt` is `keccak256("aave-v4-babylon-mainnet-test-v1")` and `librarySalt` is `keccak256("aave-v4-babylon-mainnet-test-libraries-v1")`, so its libraries are separate from the canonical LiquidationLogic. `liquidationManager` is the AaveAdapter Babylon precomputed at `0xF93892D520630d3eB0ed9A2157746E0a63a9E6f2`. The parameters follow the [ARFC](https://governance.aave.com/t/arfc-onboard-native-btc-as-collateral-to-aave-v4-via-babylon-trustless-bitcoin-vaults/25845/10): `babylon-btc` stands in for the Babylon Hub and `babylon-stables` for the Core Hub. vaultBTC's address comes from Babylon after step 2, so step 3 reverts until it is filled in. Values the ARFC leaves open are set for the test: vaultBTC has a zero rate and no liquidity fee, `babylon-stables` copies the live Core Hub curves and fees, and its add caps equal its draw caps so liquidity can be supplied through the BabylonSpoke.

## Steps

1. `make babylon-precompile chain=<chain> config=<config> account=<keystore>`, run twice. With no active `FOUNDRY_LIBRARIES` entry in `.env`, it deploys `LiquidationLogic` at `librarySalt` and records it as the entry. The second run compiles `BabylonLiquidationLogic` linked against it, deploys it at `librarySalt` and records both, so `--verify` verifies both libraries. A run on an entry of another config reverts, and a dry run leaves `.env` unchanged.
2. `make babylon-deploy chain=<chain> config=<config> account=<keystore>` deploys the market and writes the report to `output/reports/deployments/`. It reverts unless the BabylonSpoke links the libraries at `librarySalt`. Copy the report to `reports/<config>.json`, the path set in `report`. Configs live in `config/` and deployment reports in `reports/`.
3. `make babylon-configure chain=<chain> config=<config> account=<keystore>` configures the market from the deployer. It grants the deployer the HubConfigurator and SpokeConfigurator domain admin roles, and grants the configurators their Hub and Spoke roles. Then it lists each reserve on its Hub with the TreasurySpoke as fee receiver, connects the BabylonSpoke, adds the reserve and sets the liquidation config. It reverts if the BabylonSpoke already has reserves.
4. `make babylon-handover chain=<chain> config=<config> account=<keystore>` grants `admin` the HubConfigurator and SpokeConfigurator domain admin roles, transfers every ProxyAdmin, nominates `admin` as TreasurySpoke owner and removes every role the deployer holds. It reverts unless the roles end as below and every ProxyAdmin is owned by `admin`.
5. `admin` calls `acceptOwnership()` on the TreasurySpoke.
6. `make babylon-verify chain=<chain> config=<config>` checks the whole market against the config without sending anything: contract wiring, roles, every ProxyAdmin owner, TreasurySpoke ownership and every reserve.

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
