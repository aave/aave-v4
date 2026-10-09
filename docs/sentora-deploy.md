# Aave V4 Sentora market — deploy runbook

Ethereum mainnet, chain id 1. One Hub (`sentora`) and three Spokes (`rlusdYield`, `ousdYield`, `bluechip`), deployed halted. The V4 Security Council Safe admins the AccessManager and owns the ProxyAdmins; the Sentora Executor, behind its own Timelock, owns everything else and holds the configurator admin roles. Parameters come from the [ARFC](https://governance.aave.com/t/arfc-sentora-externally-curated-hub-spoke-framework-on-aave-v4/25723). OUSD is Open USD (`0x9f6F…4436`), as in the [OUSD listing ARFC](https://governance.aave.com/t/25735). Built the same way as the Base market: deploy with roles deferred, configure as the deployer, then hand over and prove the deployer holds nothing.

Inputs live in `config/sentora.json` and `config/sentora-config.json`. Scripts are `scripts/deploy/AaveV4DeploySentora.s.sol`, `scripts/config/AaveV4ConfigureSentora.s.sol`, `scripts/config/AaveV4RelinquishSentora.s.sol` and `scripts/config/DeploySentoraConfigEngine.s.sol`. `tests/deployments/AaveV4SentoraDeployConfig.t.sol` pins both input files and `tests/deployments/AaveV4SentoraConfigureAndRelinquish.t.sol` runs the whole path against a local deployment.

`config/sentora-config.json` has two lists. `assets` goes on the Hub, with the rate curve and the price feed. `reserves` goes on the Spokes: each entry names a Spoke label and an asset symbol, and carries that pair's caps and risk parameters. An asset is registered only on the Spokes a reserve names.

## Still open

- **Role holders.** `sentoraExecutor` and `riskSteward` in `config/sentora.json` are placeholders (`0x1111…1111`, `0x2222…2222`), and so are the three owner fields that point at the Executor. `emergencyOperator` is Sentora's `0x37409c868BA42B91ff7E7b64D5BC020897444fAf`, which has no code on Ethereum yet. `readHandover` rejects any placeholder with `PlaceholderAddress` on chain id 1, which blocks both the deploy and the handover.
- **Price sources for OUSD, PRIME and PST.** All three have `priceSource` 0, so `requireLiveAssets` blocks step 3 until their adapters from aave-price-feeds are deployed. OUSD gets a `PriceCapAdapterStable` (cap 1.04) on Chainlink OUSD/USD (`0xaf03…7418`), a feed live only since 2026-09-30.
- **No SVR feeds.** Every price source avoids SVR. USDe uses the capped USDT/USD adapter the V4 Ethena Spokes use (`0xC26D…4Ff8`, on standard Chainlink USDT/USD) instead of the ARFC's raw USDe/USD, and kBTC uses standard Chainlink BTC/USD (`0xF403…88c`). PST's adapter must sit on the non-SVR Capped USDC/USD (`0xB655…F6dA`), not `0x3f73…095B`, which is built on Aave's SVR USDC feed.
- **Values the ARFC does not set.** The liquidation curve mirrors Base (1.24 target, 0.90 for max bonus, 90% bonus factor). Borrowable reserves use `riskPremiumThreshold` = max, since 0 would reject any borrow against collateral that carries a collateral risk. `receiveSharesEnabled` is true everywhere and nothing is tokenized.
- **Values to confirm with Sentora.** The ARFC's liquidation fee equals the max bonus on every row (e.g. 3.5% / 3.5%), and it's encoded as that share of the bonus (`350`). Collateral-only assets carry a 0% liquidity fee per the ARFC's flat curve, which conflicts with its own 20% minimum reserve factor. Neither has any effect while their draw caps are 0.
- **Revenue split.** The ARFC's 50/50 onchain split has no mechanism here: fees accrue to the TreasurySpoke, owned by the Sentora Executor, and nobody holds `HUB_FEE_MINTER_ROLE`.

## The end state

| Role                                  | Holder                                     | Members |
| ------------------------------------- | ------------------------------------------ | ------- |
| `0` ACCESS_MANAGER_ADMIN              | `accessManagerAdmin` (V4 Security Council) | 1       |
| `101` HUB_CONFIGURATOR_ROLE           | the HubConfigurator                        | 1       |
| `200` HUB_CONFIGURATOR_DOMAIN_ADMIN   | `sentoraExecutor`                          | 1       |
| `301` SPOKE_CONFIGURATOR_ROLE         | the SpokeConfigurator                      | 1       |
| `400` SPOKE_CONFIGURATOR_DOMAIN_ADMIN | `sentoraExecutor`                          | 1       |
| `1000` SENTORA_RISK_ROLE              | `sentoraExecutor`, `riskSteward`           | 2       |
| `1001` SENTORA_EMERGENCY_ROLE         | `emergencyOperator`, `accessManagerAdmin`  | 2       |
| `100`, `102`, `103`, `300`, `302`     | nobody                                     | 0       |

No holder carries an AccessManager execution delay: the Executor's delay lives in its Timelock. The handover moves the cap, collateral factor and max liquidation bonus selectors (including `add/updateDynamicReserveConfig`) to `SENTORA_RISK_ROLE`, and the one-way halt, pause, freeze and cap-reset selectors to `SENTORA_EMERGENCY_ROLE`. Every other configurator selector stays on `200` / `400`, see `AaveV4SentoraRoles`. `AaveV4SentoraHandover.verify` pins every member count, every execution delay, every selector's role and each role's selector count, so an extra holder or a rewired selector fails the handover.

The Hub and Spoke ProxyAdmins belong to the Security Council from the deploy transaction onwards. The deploy gives the TreasurySpoke's ProxyAdmin the TreasurySpoke's own owner, so the TreasurySpoke starts on the deployer and the handover moves that ProxyAdmin to the Security Council. The TreasurySpoke, position managers and gateways all start on the deployer and the handover starts an `Ownable2Step` transfer of each to the Executor, which calls `acceptOwnership()` on all six. Step 4 lists them when it finishes.

Configuration halts every asset it lists on the Hub. Going live takes one `updateSpokeHalted(hub, assetId, spoke, false)` per asset-spoke pair from the Executor, through its Timelock.

## Steps

Every step broadcasts from a `cast wallet` keystore account, passed as `account=`. `RPC_MAINNET` and `ETHERSCAN_API_KEY_MAINNET` must be set in `.env`.

```bash
# 1. link the Spoke against the LiquidationLogic already live on Ethereum
echo 'FOUNDRY_LIBRARIES=src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic:0x88dF535473C5adf1f57789734A05E555F7Deb8DB' >> .env

# 2. AccessManager, configurators, treasury spoke, hub, spoke, gateways, managers
make sentora-deploy account=<keystore-name>

# 3. roles, liquidation config, manager wiring, listings, then halt each asset
make sentora-configure account=<keystore-name>

# 4. hand the market over and prove the deployer holds nothing
make sentora-relinquish account=<keystore-name>

# the config engine configuration payloads delegatecall into; order-independent of the above.
# The live Ethereum V4 engine 0xa1673fbD457747A05e91D9ef904Cb12827916B1E is the same code, so this
# step can be skipped in favour of it.
make sentora-config-engine account=<keystore-name>
```

Add `dry=true` to any target to simulate. Step 2 writes its report to `output/reports/deployments/`; point `report` in `config/sentora-config.json` at it before step 3.

Step 1 replaces `make deploy-precompile`. LiquidationLogic is already on Ethereum at the address `SpokeDeployUtils.LIQUIDATION_LOGIC_SALT` resolves to, and `LibraryPreCompile` would revert with `ContractAlreadyDeployed` trying to deploy it again when `FOUNDRY_LIBRARIES` is not set yet. `tests/deployments/utils/LiquidationLogicAddress.t.sol` pins that the current build still produces the bytecode at that address.
