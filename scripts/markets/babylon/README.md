# Babylon market

Two Hubs, `babylon-btc` for vaultBTC and `babylon-stables` for the borrowed stables, and one BabylonSpoke, deployed with `grantRoles = false`. The deployer keeps every role and ownership until the handover. Each deployment has its own config, `config/<config>.json`, picked with `config=<config>` on every step. The scripts revert when the config's `chainId` is not the RPC's chain.

| Config         | Chain    | Purpose                                                       |
| -------------- | -------- | ------------------------------------------------------------- |
| `sepolia`      | Sepolia  | Testnet market                                                |
| `mainnet-test` | Ethereum | Test market on mainnet, with its own deploy and library salts |
| `mainnet`      | Ethereum | Production market                                             |

| Field                        | Meaning                                                                                                                                                                          |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `chainId`                    | Chain the config is for                                                                                                                                                          |
| `salt`                       | Deploy salt                                                                                                                                                                      |
| `librarySalt`                | CREATE2 salt of LiquidationLogic and BabylonLiquidationLogic                                                                                                                     |
| `deployer`                   | Account every step broadcasts from. Every deployed address depends on it, and the scripts revert for another broadcaster                                                         |
| `hubLabels`                  | Hub labels, `babylon-btc` and `babylon-stables`                                                                                                                                  |
| `babylonSpokeLabel`          | BabylonSpoke label, `babylon`                                                                                                                                                    |
| `liquidationManager`         | The only address allowed to liquidate on the BabylonSpoke. Immutable.                                                                                                            |
| `liquidationManagerDeployer` | Babylon's CreateX deployer of the AaveAdapter. When set, step 3 reverts unless CreateX maps it and `liquidationManagerSalt` to `liquidationManager`. Required on Ethereum        |
| `liquidationManagerSalt`     | Babylon's global CreateX salt, derived as in Babylon's `AaveAdapterScript`                                                                                                       |
| `managedCollateralReserveId` | The only reserve usable as collateral. Immutable, so the collateral must be the first reserve added.                                                                             |
| `admin`                      | Receives every ownership at handover, and every role unless `authority` is set                                                                                                   |
| `authority`                  | Zero, or the AccessManager the Hubs and the BabylonSpoke move to at handover. The deployed AccessManager is then left with no admin                                              |
| `feeReceiver`                | Zero for the deployed TreasurySpoke, or the fee receiver of every listed asset                                                                                                   |
| `report`                     | Deployment report written by steps 2 and 3, read by the later steps                                                                                                              |
| `reserves`                   | BabylonSpoke reserves in reserve id order, each listed on its `hub` and connected to the BabylonSpoke                                                                            |
| `externalReserves`           | Optional. BabylonSpoke reserves on assets of Hubs outside the market, added after `reserves` without connecting the BabylonSpoke on that Hub                                     |
| `externalSpokes`             | Optional. Spokes deployed outside the market, connected to a listed asset on its `hub`. Configure connects them, verify checks their config, and the ProxyAdmin checks skip them |
| `liquidationConfig`          | BabylonSpoke liquidation config                                                                                                                                                  |

On Sepolia, `salt` is `keccak256("aave-v4-babylon-v2")`, `librarySalt` is the canonical `0x2bdf` and `liquidationManager` is the AaveAdapter at its precomputed address `0x6A785E8fdF251E2aA758a6E1841e1470074f46BF`.

On `mainnet-test`, `salt` is `keccak256("aave-v4-babylon-mainnet-test-v1")` and `librarySalt` is `keccak256("aave-v4-babylon-mainnet-test-libraries-v1")`, so its libraries are separate from the canonical LiquidationLogic. `liquidationManager` is the AaveAdapter Babylon precomputed at `0xF93892D520630d3eB0ed9A2157746E0a63a9E6f2`. The parameters follow the [ARFC](https://governance.aave.com/t/arfc-onboard-native-btc-as-collateral-to-aave-v4-via-babylon-trustless-bitcoin-vaults/25845/10): `babylon-btc` stands in for the Babylon Hub and `babylon-stables` for the Core Hub. Every token and price feed is a Babylon mock, so only the Hub and Spoke layout and the risk parameters follow the ARFC. `babylon-stables` also lists WBTC supply-only on the BabylonSpoke, so it can be funded for BTCVaultSwap, which is the external spoke drawing it. Values the ARFC leaves open are set for the test: vaultBTC has a zero rate and no liquidity fee, `babylon-stables` copies the live Core Hub curves and fees, and its add caps equal its draw caps so liquidity can be supplied through the BabylonSpoke.

On `mainnet`, the market has one Hub, `babylon`, with the [LlamaRisk parameters](https://governance.aave.com/t/arfc-onboard-native-btc-as-collateral-to-aave-v4-via-babylon-trustless-bitcoin-vaults/25845/10). Its Babylon Hub spoke configs are inactive until the AIP. The Core Hub reserves are `externalReserves`, which the AIP backs with credit lines. `authority` is the Ethereum V4 AccessManager, `feeReceiver` the Ethereum TreasurySpoke and `admin` the V4 Security Council. The vaultBTC underlying is set once Babylon deploys it, and the CreateX fields once Babylon shares them. `librarySalt` is the canonical `0x2bdf`, so LiquidationLogic resolves to the live Ethereum `0x88dF535473C5adf1f57789734A05E555F7Deb8DB` and step 1 only deploys BabylonLiquidationLogic.

## Steps

1. Comment out any active `FOUNDRY_LIBRARIES` entry in `.env`, then run `make babylon-precompile chain=<chain> config=<config> account=<keystore>`, run twice. With no active `FOUNDRY_LIBRARIES` entry in `.env`, it deploys `LiquidationLogic` at `librarySalt` and records it as the entry. The second run compiles `BabylonLiquidationLogic` linked against it, deploys it at `librarySalt` and records both, so `--verify` verifies both libraries. A run on an entry of another config reverts, and a dry run leaves `.env` unchanged.
2. `make babylon-deploy-hub chain=<chain> config=<config> account=<keystore>` deploys the AccessManager, the configurators, the TreasurySpoke and the Hubs, and writes the report to `output/reports/deployments/`. Copy the report to `reports/<config>.json`, the path set in `report`. Configs live in `config/` and deployment reports in `reports/`. It does not load the Spoke bytecodes, so it runs without linked libraries and step 1 can run any time before step 3.
3. `make babylon-deploy-spoke chain=<chain> config=<config> account=<keystore>` deploys the BabylonSpoke under the AccessManager of the report, at the address a single-step deployment gives it, and writes the report with the BabylonSpoke to `output/reports/deployments/`. Copy it over `reports/<config>.json`. It reverts unless the BabylonSpoke links the libraries at `librarySalt`, and on Ethereum unless `liquidationManager` is the CreateX address of `liquidationManagerDeployer` and `liquidationManagerSalt`.
4. `make babylon-configure chain=<chain> config=<config> account=<keystore>` configures the market from the deployer. It grants the deployer the HubConfigurator and SpokeConfigurator domain admin roles, and grants the configurators their Hub and Spoke roles. Then it lists each reserve on its Hub with the TreasurySpoke as fee receiver, connects the BabylonSpoke, adds the reserve and sets the liquidation config. It reverts if the BabylonSpoke already has reserves.
5. `make babylon-handover chain=<chain> config=<config> account=<keystore>` grants `admin` the HubConfigurator and SpokeConfigurator domain admin roles, transfers every ProxyAdmin, nominates `admin` as TreasurySpoke owner and removes every role the deployer holds. It reverts unless the roles end as below and every ProxyAdmin is owned by `admin`.
   With `authority` set, it instead moves the Hubs and the BabylonSpoke to `authority`, revokes the deployer's roles and renounces the deployed AccessManager's admin role, leaving only the configurators on their own roles. With `feeReceiver` set, the deployed TreasurySpoke is unused, and it and its ProxyAdmin stay with the deployer. On `mainnet`, run it only after Babylon deployed the AaveAdapter, since the deployer can no longer change the market afterwards.
6. Without `feeReceiver`, `admin` calls `acceptOwnership()` on the TreasurySpoke.
7. `make babylon-verify chain=<chain> config=<config>` checks the whole market against the config without sending anything: contract wiring, roles, every ProxyAdmin owner, TreasurySpoke ownership and every reserve.

Without `authority`, the roles end as on Ethereum, with every governance holder replaced by `admin`:

| Role                                    | Holder            |
| --------------------------------------- | ----------------- |
| 0 ACCESS_MANAGER_ADMIN                  | admin             |
| 101 HUB_CONFIGURATOR_ROLE               | HubConfigurator   |
| 200 HUB_CONFIGURATOR_DOMAIN_ADMIN       | admin             |
| 301 SPOKE_CONFIGURATOR_ROLE             | SpokeConfigurator |
| 400 SPOKE_CONFIGURATOR_DOMAIN_ADMIN     | admin             |
| 100, 102, 103, 300, 302 and other roles | nobody            |

Add `dry=true` to steps 1 to 5 to simulate. On Sepolia, forge underestimates gas for these transactions, so also pass `gas_multiplier=1000` to steps 1 to 5.
