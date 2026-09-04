# Aave V4 on Base — deploy runbook

Base mainnet, chain id 8453. One Hub (`core`) and one Spoke (`main`), deployed fully halted and handed over to the V4 Security Council.

Inputs live in `config/base.json` and `config/base-config.json`. Scripts are `scripts/deploy/AaveV4DeployBase.s.sol`, `scripts/config/AaveV4ConfigureBase.s.sol`, `scripts/config/AaveV4RelinquishBase.s.sol` and `scripts/config/DeployBaseConfigEngine.s.sol`. `tests/deployments/AaveV4BaseDeployConfig.t.sol` pins both input files and `tests/deployments/AaveV4BaseConfigureAndRelinquish.t.sol` runs the whole path against a local deployment.

**Two things are still missing before a real run:** the V4 Security Council executor address, and the launch set with its risk parameters. See [What is still open](#what-is-still-open).

## The end state

The market reproduces what the live **Ethereum** V4 market runs with. That map was read off the chain itself rather than inferred, and the tests assert it.

**Roles.** The Security Council Safe admins the AccessManager. Its executor is what actually executes the Council's configuration payloads, so it holds the two configurator domain admin roles — alongside the Council itself and the DAO's own governance executor, which can both reach the configurators directly.

| Role                                  | Holder                                                   |
| ------------------------------------- | -------------------------------------------------------- |
| `0` ACCESS_MANAGER_ADMIN              | Security Council **+** governance executor               |
| `101` HUB_CONFIGURATOR_ROLE           | the HubConfigurator                                      |
| `200` HUB_CONFIGURATOR_DOMAIN_ADMIN   | Council **+** Council executor **+** governance executor |
| `301` SPOKE_CONFIGURATOR_ROLE         | the SpokeConfigurator                                    |
| `400` SPOKE_CONFIGURATOR_DOMAIN_ADMIN | Council **+** Council executor **+** governance executor |
| `100`, `102`, `103`, `300`, `302`     | nobody                                                   |

The five empty roles reach the Hub and Spokes directly rather than through a configurator, and are unheld on both live markets: nothing at launch calls `mintFeeShares`, `eliminateDeficit` or the user position updaters, and role `0` can grant them when something does. `config/base.json` therefore carries `hubAdmin` and `spokeAdmin` as the zero address, and `AaveV4BaseHandover.verifyRoleHolders` asserts those roles are empty rather than only asserting the deployer is not in them.

The two configurator domain admin roles carry the same three holders, which is Ethereum's shape. Avalanche differs — it grants neither role to the Council and keeps the governance executor off role `400` — but that asymmetry has no counterpart in how the market is operated, and the Council holding role `0` could grant itself both at any time regardless. `test_relinquishGrantsTheEthereumRoleMap` pins the exact member count of each role, so an extra holder fails the test rather than passing unnoticed.

**Ownership.** Everything ends up with the Security Council, which is how both live markets read on-chain today.

| Contract                                                    | Owner after deploy | Owner after handover      |
| ----------------------------------------------------------- | ------------------ | ------------------------- |
| Hub / Spoke / TreasurySpoke / TokenizationSpoke ProxyAdmins | Council            | Council                   |
| TreasurySpoke                                               | Council            | Council                   |
| Giver / Taker / Config position managers                    | deployer           | Council (after accepting) |
| NativeTokenGateway, SignatureGateway                        | deployer           | Council (after accepting) |

The split exists because `PositionManagerBase.registerSpoke` is `onlyOwner` and configuration has to call it to wire each manager to each Spoke. `AaveV4DeployBase` therefore forces `gatewayOwner` and `positionManagerOwner` to the deployer at deploy time, and the handover transfers them onward. Everything else belongs to the Council from the deploy transaction onwards, which is what keeps the TreasurySpoke from needing an `Ownable2Step` acceptance of its own.

**The market is halted.** Configuration halts each asset on the Hub as it lists it, which sets `halted = true` on every Spoke registered for that asset — the main Spoke, the treasury spoke that `addAsset` registers as fee receiver, and the tokenization spoke. `Hub` rejects every liquidity operation against a halted spoke with `SpokeHalted`.

There is no `unhaltAsset`. Going live is one `updateSpokeHalted(hub, assetId, spoke, false)` per asset-spoke pair, from an address holding role `200`. The Spoke-side reserve flags are left unpaused, so the halt is the only thing holding the market closed and the only thing to undo.

## Addresses

| Field                                             | Address                                      | Source                             |
| ------------------------------------------------- | -------------------------------------------- | ---------------------------------- |
| Security Council (owner, roles `0`, `200`, `400`) | `0x187AAE17d4931310B3fc75743e7F16Bdc9eD77e9` | `MiscEthereum.V4_SECURITY_COUNCIL` |
| Council executor (roles `200`, `400`)             | **`0x1111…1111` placeholder**                | not deployed on Base yet           |
| Governance executor (roles `0`, `200`, `400`)     | `0x9390B1735def18560c509E2d0bc090E9d6BA257a` | `GovernanceV3Base.EXECUTOR_LVL_1`  |

The Security Council Safe is at the same address on Ethereum, Avalanche and Arc, so Base is expected to match — but **it has no code on Base today**, and neither does any V4 Security Council executor. The executor address is chain-specific (Avalanche and Arc differ), so it cannot be predicted the way the Safe can.

`AaveV4DeployBase` rejects the placeholder whenever `block.chainid` is 8453, which is what makes a real deploy impossible until `hubConfiguratorAdmin`, `spokeConfiguratorAdmin` and `governanceExecutor` are all filled in. Local and test runs are exempt, so the tests still exercise the full wiring. `test_deployInputs` and `test_handoverTargets` assert the placeholder is still there: replace the assertions and `config/base.json` together.

## Prerequisites

1. **`RPC_BASE`** set in `.env`.
2. **`ETHERSCAN_API_KEY_BASE`** set in `.env` for `--verify`. Base is already wired up in `foundry.toml`, both as an RPC endpoint and an Etherscan chain.
3. **The Council executor address**, replacing the placeholder as described above.

The Safe Singleton Factory at `0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7` is already deployed on Base, so no request to [safe-singleton-factory](https://github.com/safe-global/safe-singleton-factory) is needed. `Create2Utils` reverts with `MissingCreate2Factory` if it ever goes missing.

## Steps

```bash
# 1. LiquidationLogic, written to FOUNDRY_LIBRARIES in .env
make deploy-precompile chain=base account=<keystore-name>

# 2. AccessManager, configurators, treasury spoke, core hub, main spoke, gateways, position managers
make deploy-contracts chain=base account=<keystore-name> script=AaveV4DeployBase

# 3. roles, liquidation configs, position manager wiring, asset listings, then halt each asset
make configure-market chain=base account=<keystore-name> script=AaveV4ConfigureBase

# 4. hand the market over and prove the deployer holds nothing
make relinquish-market chain=base account=<keystore-name> script=AaveV4RelinquishBase

# the config engine governance payloads delegatecall into; order-independent of the above
make deploy-config-engine chain=base account=<keystore-name> script=DeployBaseConfigEngine
```

Add `dry=true` to any target to simulate. Step 2 writes its report to `output/reports/deployments/base-<timestamp>.json`; point `report` in `config/base-config.json` at it, and set `deployer` to the address you are broadcasting from, before step 3.

After step 4 the Council has one thing left to do: `acceptOwnership()` on each of the five managers and gateways, which step 4 lists by address on completion. Until it does, the deployer still owns them — which means `registerSpoke`, `renouncePositionManagerRole` and, since the rescue guardian is `owner()`, `rescueToken` and `rescueNative`. Close that window promptly.

See `src/deployments/README.md` for what the orchestration does and why the library pre-deploy is a separate step.

## Configuration is direct calls, not a payload

Every `HubConfigurator` and `SpokeConfigurator` function is `external restricted`, gated per target function on the AccessManager. An EOA holding the role calls them directly, which is what the configuration script does. `AaveV4ConfigEngine` is not used here: it is invoked by delegatecall, and a forge script broadcasting from an EOA cannot delegatecall. The engine is the path for governance payloads once the market is handed over — including the payload that unhalts it — which is why the domain admin roles end up with the Council executor.

`config/base.json` sets `grantRoles` to false, so the deploy wires every selector to its role but grants no role to anyone, and leaves the deployer holding the AccessManager admin role. That is the window step 3 runs in. One thing `grantRoles: false` does that the input documentation does not spell out: it skips granting the configurators the roles they call the Hub and Spokes with (`101` and `301`). Without those grants a configurator call reverts even when the caller holds the domain admin role, so `AaveV4BaseConfiguration` grants them — permanently, since they are part of the end state.

This works because the AccessManager carries no delays on a fresh deploy: nothing in the deploy path calls `setGrantDelay` or `setTargetAdminDelay`, and every grant uses an execution delay of zero. A non-zero delay would defer the deployer's self-grants and revert the calls that follow, so `AaveV4BaseConfiguration.requireNoDelays` asserts it rather than assuming it.

## The asset list

`config/base-config.json` carries one entry per asset:

```json
{
  "symbol": "WETH",
  "underlying": "0x…",
  "priceSource": "0x…",
  "tokenize": true
}
```

**It is empty today.** Configuration then grants the roles, applies the liquidation configs and wires the position managers, and lists nothing — which is a valid run, and the state the market would launch in with no assets. Filling the list in needs no Solidity change.

The scripts reject anything that is not a live contract:

- **`underlying`** — `HubConfigurator.addAsset` reads `decimals()` off it.
- **`priceSource`** — `AaveOracle.setReserveSource` requires the feed's `decimals()` to equal 8 and reads a price from it during `addReserve`.

That is all the on-chain checks can do. A capped adapter built against the wrong base feed reports 8 decimals like any other, so the price source has to be verified off-chain before it reaches this config.

`tokenize` deploys a `TokenizationSpoke` for the asset and registers it on the Hub supply-only, the way every Avalanche core asset has one. Its share token follows the live naming — `Wrapped Aave Core WETH` / `waCoreWETH` — and its ProxyAdmin owner is passed explicitly, so it lands on the Council rather than on whoever ran the script. `AaveV4BaseHandover.verifyProxyAdmins` walks the Hub's registered Spokes rather than only the ones the deploy produced, so a tokenization spoke whose ProxyAdmin went elsewhere — from this script or from a later listing payload — fails the handover verification with `UnexpectedOwner`.

Adding a second Spoke means a second `spokeLabels` entry; configuration registers every Spoke for every asset.

### Launch parameters

`AaveV4BaseParameters` holds the parameters every asset is listed with. They are not risk parameters in the usual sense: the market launches halted, every reserve non-collateral, non-borrowable and with zero caps, and the real listing parameters arrive in the first governance payload through the config engine.

Each value sits at the neutral end of what its own validation accepts rather than at a literal zero, because three of them reject zero:

| Parameter             | Value    | Why not zero                                                 |
| --------------------- | -------- | ------------------------------------------------------------ |
| `optimalUsageRatio`   | `1_00`   | `AssetInterestRateStrategy.MIN_OPTIMAL_RATIO`                |
| `maxLiquidationBonus` | `100_00` | must be at least `PERCENTAGE_FACTOR`, which is a 0.00% bonus |
| `targetHealthFactor`  | `1e18`   | must be at least `Spoke.HEALTH_FACTOR_LIQUIDATION_THRESHOLD` |

Everything else — caps, collateral factor, liquidation fee, liquidity fee, rate slopes, risk premium threshold, tokenization add cap — is zero.

## What is still open

- **The V4 Security Council executor on Base.** Blocks a real deploy; the placeholder guard enforces that.
- **The launch set and its risk parameters.** `config/base-config.json` is empty and `AaveV4BaseParameters` carries neutral values. Both can be filled in without touching the scripts.
