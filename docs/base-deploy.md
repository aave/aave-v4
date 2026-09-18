# Aave V4 on Base — deploy runbook

Base mainnet, chain id 8453. The tokenized equities market: one Hub (`equities`), one lending Spoke (`mag7`) carrying the seven Coinbase tokenized stocks as collateral against USDC, and a USDC TokenizationSpoke for composable supply-only positions. Deployed fully halted and handed over to the V4 Security Council.

Inputs live in `config/base.json` and `config/base-config.json`. Scripts are `scripts/deploy/AaveV4DeployBase.s.sol`, `scripts/config/AaveV4ConfigureBase.s.sol`, `scripts/config/AaveV4RelinquishBase.s.sol` and `scripts/config/DeployBaseConfigEngine.s.sol`. `tests/deployments/AaveV4BaseDeployConfig.t.sol` pins both input files against the risk parameters and `tests/deployments/AaveV4BaseConfigureAndRelinquish.t.sol` runs the whole path against a local deployment, driven by the real launch set.

**One thing is still missing before a real run:** the V4 Security Council executor address. See [What is still open](#what-is-still-open).

## The end state

The market reproduces what the live **Avalanche** V4 market runs with, member counts included. That map was read off the chain itself rather than inferred, and the tests assert it.

**Roles.** The Security Council Safe admins the AccessManager. Its executor is what actually executes the Council's configuration payloads, so it is the executor — not the Council — that holds the two configurator domain admin roles.

| Role                                  | Holder                                     | Members |
| ------------------------------------- | ------------------------------------------ | ------- |
| `0` ACCESS_MANAGER_ADMIN              | Security Council **+** governance executor | 2       |
| `101` HUB_CONFIGURATOR_ROLE           | the HubConfigurator                        | 1       |
| `200` HUB_CONFIGURATOR_DOMAIN_ADMIN   | Council executor **+** governance executor | 2       |
| `301` SPOKE_CONFIGURATOR_ROLE         | the SpokeConfigurator                      | 1       |
| `400` SPOKE_CONFIGURATOR_DOMAIN_ADMIN | Council executor                           | 1       |
| `100`, `102`, `103`, `300`, `302`     | nobody                                     | 0       |

The five empty roles reach the Hub and Spokes directly rather than through a configurator, and are unheld on both live markets: nothing at launch calls `mintFeeShares`, `eliminateDeficit` or the user position updaters, and role `0` can grant them when something does. `config/base.json` therefore carries `hubAdmin` and `spokeAdmin` as the zero address, and `AaveV4BaseHandover.verifyRoleHolders` asserts those roles are empty rather than only asserting the deployer is not in them.

**The Council does not hold roles `200` and `400` itself.** Ethereum grants it both directly, Avalanche grants it neither, and this follows Avalanche. That is a choice of default posture rather than of capability — on either market the Council holds role `0` and can grant itself either role whenever it wants.

**Role `400` is the Council executor alone**, which is Avalanche's shape too and the asymmetry worth knowing about before writing a payload: the DAO's governance executor can reach the HubConfigurator but not the SpokeConfigurator. Reserve configs, caps, price sources and spoke-side halting all go through the Council executor.

Worth recording, because it is not obvious and will come up again: **this map cannot be produced by `grantRoles: true`.** Deploy-time granting runs `grantHubAllRoles`/`grantSpokeAllRoles`, which require a non-zero `hubAdmin`/`spokeAdmin` and put it in roles `101`, `102`, `103`, `301` and `302`, and `replaceDefaultAdminRole`, which drops the deployer from role `0`. Read Arc's live map and that is exactly what it looks like — Arc role `101` is the HubConfigurator plus the Council, `102` and `103` are the Council, role `0` is the Council alone. Ethereum and Avalanche do not look like that precisely because their roles were granted after deploy, which is what `AaveV4RelinquishBase` does here.

`verifyRoleHolders` and `test_relinquishGrantsTheAvalancheRoleMap` both pin the exact member count of every role, so an extra holder fails the handover rather than passing unnoticed.

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

| Field                                             | Address                                      | Source                              |
| ------------------------------------------------- | -------------------------------------------- | ----------------------------------- |
| Security Council (owner, roles `0`, `200`, `400`) | `0x187AAE17d4931310B3fc75743e7F16Bdc9eD77e9` | `MiscEthereum.V4_SECURITY_COUNCIL`  |
| Council executor (roles `200`, `400`)             | `0xA9D9923A1ADC1200771aaaA38CFeD6A5b8483d70` | deployed, **not yet in the config** |
| Governance executor (roles `0`, `200`, `400`)     | `0x9390B1735def18560c509E2d0bc090E9d6BA257a` | `GovernanceV3Base.EXECUTOR_LVL_1`   |

### The Security Council Safe on Base is one key — blocker

`config/base.json` points `accessManagerAdmin`, `proxyAdminOwner`, `treasurySpokeOwner`, `gatewayOwner` and `positionManagerOwner` at the shared Council address. **On Base that address is not the Council.**

|             | Base                  | Ethereum              | Avalanche            |
| ----------- | --------------------- | --------------------- | -------------------- |
| `VERSION`   | 1.4.1                 | 1.4.1                 | 1.4.1                |
| singleton   | `0x29fcb43b…` SafeL2  | `0x41675C09…` Safe    | `0x29fcb43b…` SafeL2 |
| `threshold` | **1**                 | 5                     | 5                    |
| owners      | **1** — `0x5063b3D2…` | the 8 council signers | the same 8           |
| `nonce`     | **0**                 | 33                    | 8                    |

`0x5063b3D23C3640d51c9E2aef41063B1d482C70ff` is an EOA, not one of the eight signers. The Base Safe has no modules and no guard.

This is not an address squat. The Safe was created at block 51468086 in tx `0x700670f5…`, through the Safe proxy factory with a non-empty initializer and the L1 singleton, with `setup` in the same transaction and a delegatecall that swapped the master copy to SafeL2 — Safe's own cross-chain replay flow. Replaying reproduces the address because it replays the original initializer and salt nonce, which is also why it reproduces the _original_ owner set: the 5-of-8 on Ethereum and Avalanche was applied after creation by Safe transactions, and post-creation owner changes do not replay.

Benign mechanism, unchanged consequence. Until whoever holds `0x5063b3D2…` reconfigures the Base Safe to the council 5-of-8, handing the market over puts one key behind role `0` — which can grant every other role — and behind the ProxyAdmins of the Hub, the mag7 Spoke, the TreasurySpoke and the USDC TokenizationSpoke, which can upgrade all four implementations.

**Nothing should be deployed to Base until that owner set is fixed, and it has to be confirmed on-chain rather than assumed.**

### The Council executor

**Not deployed on Base.** None of the three known executors has code there, and `MiscBase` carries no `V4_` entry at all.

| Chain     | `V4_SECURITY_COUNCIL_EXECUTOR`               |
| --------- | -------------------------------------------- |
| Ethereum  | `0x14339e2178A954d5FB839D5Ff31644fE0F25F517` |
| Avalanche | `0xb619fA61e795D47f517702e63ce50292370561F1` |
| Arc       | `0x8e79b0541122d3822eC93082cEB1ab03EDBc1Fd5` |
| Base      | — none                                       |

Each is an `Executor` from [`aave-dao/aave-governance-v3`](https://github.com/aave-dao/aave-governance-v3) (`src/contracts/payloads/Executor.sol`) — an `Ownable` with an `executeTransaction(target, value, signature, data, withDelegatecall)`, which is what lets a Council payload delegatecall the config engine. The constructor takes nothing and owns itself to the deployer, so ownership is transferred to the Security Council Safe afterwards; all three read `owner() == 0x187AAE17…`.

They are standalone deploys rather than part of that repo's tracked set: `deployments/ethereum.json` records `permissionedExecutor` as `0x2759de67aD133C747C9f41d56F1b8A343cE679a1`, a different contract, and the Ethereum V4 executor was deployed straight from a BGD EOA. Nothing derives the address, so it has to be read back off the deploy.

Base now has one: **`0xA9D9923A1ADC1200771aaaA38CFeD6A5b8483d70`**, block 51468404, deployed from `0x4C11ed256D43762811B093145e6F6b58F2be4782` through `aave-governance-v3`'s `scripts/Payloads/Deploy_V4SecurityCouncilExecutor.s.sol:Base` — a standalone script outside `GovBaseScript`, writing to no `deployments/*.json`, so the V4 executor is not confused with the `permissionedExecutor` slot, which is zero on Base and would imply a permissioned payloads setup that does not exist there. Its runtime bytecode is byte-for-byte identical to the Ethereum deployment, and `owner()` reads `0x187AAE17…`.

Ownership was transferred in the same broadcast. `Executor` is single-step `Ownable`, so that is final — and it means the executor now sits behind the Base Safe described above, with the consequences that section spells out.

It still needs a `MiscBase.V4_SECURITY_COUNCIL_EXECUTOR` entry in [`aave-dao/aave-address-book`](https://github.com/aave-dao/aave-address-book).

`AaveV4DeployBase` rejects the placeholder whenever `block.chainid` is 8453, which is what makes a real deploy impossible until `hubConfiguratorAdmin`, `spokeConfiguratorAdmin` and `governanceExecutor` are all filled in. Local and test runs are exempt, so the tests still exercise the full wiring. `test_deployInputs` and `test_handoverTargets` assert the placeholder is still there: replace the assertions and `config/base.json` together.

**The executor address is deliberately not in the config yet.** It exists now, and dropping it into `hubConfiguratorAdmin` and `spokeConfiguratorAdmin` is a one-line change — but that placeholder guard is currently the only mechanical thing stopping a Base deploy, and the Safe above is the reason one should not happen. Wire the executor in once the Safe is fixed, not before.

## Prerequisites

1. **`RPC_BASE`** set in `.env`.
2. **`ETHERSCAN_API_KEY_BASE`** set in `.env` for `--verify`. Base is already wired up in `foundry.toml`, both as an RPC endpoint and an Etherscan chain.
3. **The Council executor address**, replacing the placeholder as described above.

The Safe Singleton Factory at `0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7` is already deployed on Base, so no request to [safe-singleton-factory](https://github.com/safe-global/safe-singleton-factory) is needed. `Create2Utils` reverts with `MissingCreate2Factory` if it ever goes missing.

## Steps

Every step broadcasts from a `cast wallet` keystore account, passed as `account=`. Create one once with `cast wallet import <name> --interactive`, and check which address it is with `make base-account account=<name>`.

```bash
# 1. LiquidationLogic, written to FOUNDRY_LIBRARIES in .env
make base-precompile account=<keystore-name>

# 2. AccessManager, configurators, treasury spoke, equities hub, mag7 spoke, gateways, managers
make base-deploy account=<keystore-name>

# 3. roles, liquidation configs, manager wiring, the eight listings and the USDC tokenization
#    spoke, then halt each asset
make base-configure account=<keystore-name>

# 4. hand the market over and prove the deployer holds nothing
make base-relinquish account=<keystore-name>

# the config engine governance payloads delegatecall into; order-independent of the above
make base-config-engine account=<keystore-name>
```

Add `dry=true` to any target to simulate. Each one wraps the generic `make deploy-contracts chain=base script=…` target, so the long form still works.

Step 2 writes its report to `output/reports/deployments/base-<timestamp>.json`; point `report` in `config/base-config.json` at it, and set `deployer` to the address `make base-account` printed, before step 3.

After step 4 the Council has one thing left to do: `acceptOwnership()` on each of the five managers and gateways, which step 4 lists by address on completion. Until it does, the deployer still owns them — which means `registerSpoke`, `renouncePositionManagerRole` and, since the rescue guardian is `owner()`, `rescueToken` and `rescueNative`. Close that window promptly.

See `src/deployments/README.md` for what the orchestration does and why the library pre-deploy is a separate step.

### Step 1 lands on the same LiquidationLogic as every other market

`0x88dF535473C5adf1f57789734A05E555F7Deb8DB`, which is where Ethereum and Avalanche have it and what every Spoke on both links against.

That is a CREATE2 result through the Safe Singleton Factory, which is already on Base, so the address follows from the creation code and the salt alone. `SpokeDeployUtils.LIQUIDATION_LOGIC_SALT` is `0x2bdf`, read back off the Ethereum deployment transaction — its calldata to the factory is the salt followed by the creation code. This used to pass a zero salt, which lands on `0x818E84198224535FAeaEc1b583d3Ff6b812A5AF3` instead; that is what Arc runs, and it is the same bytecode at a different address.

The creation code has to stay byte-identical for the address to hold. LiquidationLogic is not in `compilation_restrictions`, so it builds under the default profile rather than the Spoke's via-ir one, and `optimizer_runs`, `evm_version`, `solc_version` or `bytecode_hash` moving there moves the address. `tests/deployments/utils/LiquidationLogicAddress.t.sol` pins both the creation code hash and the resulting address, so that fails the suite rather than quietly producing a new deployment. (The Makefile's `FOUNDRY_PROFILE=base` is not a risk here: no `[profile.base]` exists, so it resolves to the default profile unchanged.)

**Do not skip step 1.** `.env` carries the library address in `FOUNDRY_LIBRARIES`, and the link happens at compile time with no on-chain check, so going straight to step 2 produces Spokes linked to an address that holds no code on Base. When `FOUNDRY_LIBRARIES` is set but the library is missing on the target chain, `LibraryPreCompile` deletes the line and reverts with `RETRY AGAIN`; that is the guard working, and the second run deploys it and rewrites the line.

## Configuration is direct calls, not a payload

Every `HubConfigurator` and `SpokeConfigurator` function is `external restricted`, gated per target function on the AccessManager. An EOA holding the role calls them directly, which is what the configuration script does. `AaveV4ConfigEngine` is not used here: it is invoked by delegatecall, and a forge script broadcasting from an EOA cannot delegatecall. The engine is the path for governance payloads once the market is handed over — including the payload that unhalts it — which is why the domain admin roles end up with the Council executor.

`config/base.json` sets `grantRoles` to false, so the deploy wires every selector to its role but grants no role to anyone, and leaves the deployer holding the AccessManager admin role. That is the window step 3 runs in. One thing `grantRoles: false` does that the input documentation does not spell out: it skips granting the configurators the roles they call the Hub and Spokes with (`101` and `301`). Without those grants a configurator call reverts even when the caller holds the domain admin role, so `AaveV4BaseConfiguration` grants them — permanently, since they are part of the end state.

This works because the AccessManager carries no delays on a fresh deploy: nothing in the deploy path calls `setGrantDelay` or `setTargetAdminDelay`, and every grant uses an execution delay of zero. A non-zero delay would defer the deployer's self-grants and revert the calls that follow, so `AaveV4BaseConfiguration.requireNoDelays` asserts it rather than assuming it.

## The launch set

`config/base-config.json` carries one entry per asset, each holding the risk parameters it is listed with. Values are in BPS unless noted; caps are in whole assets, not scaled by decimals, which is what `Hub` compares against.

```json
{
  "symbol": "USDC",
  "underlying": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
  "priceSource": "0xf52D010c7d4ecBfda92c2509900593CE34535D86",
  "liquidityFee": 1000,
  "optimalUsageRatio": 9000,
  "baseDrawnRate": 0,
  "rateGrowthBeforeOptimal": 400,
  "rateGrowthAfterOptimal": 2000,
  "addCap": 32000000,
  "drawCap": 21000000,
  "riskPremiumThreshold": 0,
  "collateralFactor": 0,
  "maxLiquidationBonus": 10000,
  "liquidationFee": 0,
  "borrowable": true,
  "receiveSharesEnabled": true,
  "tokenize": true,
  "tokenizationAddCap": 1000000
}
```

`test_launchSetMatchesTheRiskParameters` pins every one of those values against the risk provider's tables, so a parameter cannot move in the config alone.

### Collateral

The seven Coinbase tokenized equities, collateral only. They share everything but their collateral factor and add cap.

| Asset    | Collateral factor | Add cap |
| -------- | ----------------- | ------- |
| `AAPLc`  | 78.00%            | 15,000  |
| `AMZNc`  | 73.00%            | 10,500  |
| `GOOGLc` | 76.00%            | 15,000  |
| `METAc`  | 65.00%            | 5,800   |
| `MSFTc`  | 79.00%            | 5,200   |
| `NVDAc`  | 70.00%            | 24,000  |
| `TSLAc`  | 65.00%            | 14,000  |

Each is non-borrowable with a zero draw cap, a 5.50% `maxLiquidationBonus`, a 10.00% `liquidationFee` on that bonus, `receiveSharesEnabled`, and no tokenization spoke.

Their `liquidityFee` is zero. That is not a placeholder: every collateral-only asset across the six live V4 hubs carries a zero liquidity fee — `wstETH`, `weETH`, `rsETH`, `LBTC`, `XAUt`, `AAVE` and `LINK` on Ethereum Core, the `PT-*` and `sUSDe` assets on Plus, `WETH`/`WBTC`/`cbBTC`/`wstETH` on Prime, `sAVAX` on Avalanche. Nothing is drawn against them, so nothing accrues for the fee to apply to.

`optimalUsageRatio` is `1_00` for the same reason, which is `AssetInterestRateStrategy.MIN_OPTIMAL_RATIO` — the strategy rejects zero — with both rate slopes flat at zero.

### Borrow

USDC is the only borrowable asset and is never collateral, so its `maxLiquidationBonus` sits at the `100_00` floor `Spoke._validateDynamicReserveConfig` accepts, which is a 0.00% bonus.

| Parameter                 | Value      |
| ------------------------- | ---------- |
| `liquidityFee`            | 10.00%     |
| `optimalUsageRatio`       | 90.00%     |
| `baseDrawnRate`           | 0.00%      |
| `rateGrowthBeforeOptimal` | 4.00%      |
| `rateGrowthAfterOptimal`  | 20.00%     |
| `addCap`                  | 32,000,000 |
| `drawCap`                 | 21,000,000 |

The borrow rate therefore peaks at 24.00%.

### Liquidation

`AaveV4BaseParameters` holds what no asset varies: the liquidation curve, which is per Spoke rather than per reserve, and `collateralRisk`, which is zero on every reserve because no collateral carries a risk premium here. That is also why every `riskPremiumThreshold` is zero — a threshold only bites once premium shares exist, and none ever do.

| Parameter                 | Value  |
| ------------------------- | ------ |
| `targetHealthFactor`      | 1.24   |
| `healthFactorForMaxBonus` | 0.90   |
| `liquidationBonusFactor`  | 90.00% |

So a position at a health factor of 1.00 pays 90% of its collateral's maximum bonus, reaching the full amount at 0.90, and a liquidation restores it to 1.24.

### Price feeds

Each equity reads a Chainlink total return feed, all eight decimals, all live on Base:

| Asset    | Feed                                         | Description    |
| -------- | -------------------------------------------- | -------------- |
| `AAPLc`  | `0x787f13dEa48Db0897CbCDD985de77809D837F988` | Coinbase AAPL  |
| `AMZNc`  | `0x06A8E4b3aBB3B7543d8396FB2B763d22820cB295` | Coinbase AMZN  |
| `GOOGLc` | `0x5bF49E0ffA937CE2FfF033c739aD7C634c4D34F2` | Coinbase GOOGL |
| `METAc`  | `0x6526aE6797A76123638b863AeE4dD27Ba4E4b27D` | Coinbase META  |
| `MSFTc`  | `0xeB10A6c9aa7E537aEd766C08c35Dae35B321b18c` | Coinbase MSFT  |
| `NVDAc`  | `0x04689a41629776563E6822F76f2e57D148d28513` | Coinbase NVDA  |
| `TSLAc`  | `0xFaf869185383a24F8cb00e27BdA6b63B9905DCb4` | Coinbase TSLA  |

These run 24/5, Sunday 20:00 ET to Friday 20:00 ET. While the market is closed the feed publishes nothing at all, heartbeats included, so the last value before the Friday close stands with a stale timestamp until the Sunday reopen. Liquidations cannot credibly execute through the weekend under that, which the parameters above are chosen around. Chainlink is expected to bring 24/7 feeds for the same tokens to Base, and reparametrising the market is a governance payload once they are in production.

USDC reads `0xf52D010c7d4ecBfda92c2509900593CE34535D86`, the `PriceCapAdapterStable` **Aave V3 Base already prices USDC through**, rather than a newly deployed one. It reports `Capped USDC/USD` at eight decimals with `getPriceCap()` of `1.04e8`, which is the $1.04 cap the risk parameters call for. Note that its underlying aggregator is `0x1550207eAeB590D1557a6E6C066D3d57B5A4Dc65`, whose current aggregator is a `DualAggregator` — the Chainlink SVR USDC/USD feed on Base — and not the standard `0x7e860098F58bBFC8648a4311b374B1D669a2bc6B`. Reusing V3's adapter therefore inherits SVR on the borrowed asset. There is no SVR on the equity feeds; they are the standard variants.

### What the scripts can and cannot check

The scripts reject anything that is not a live contract:

- **`underlying`** — `HubConfigurator.addAsset` reads `decimals()` off it.
- **`priceSource`** — `AaveOracle.setReserveSource` requires the feed's `decimals()` to equal 8 and reads a price from it during `addReserve`.

That is all the on-chain checks can do. A capped adapter built against the wrong base feed reports 8 decimals like any other, so the price source has to be verified off-chain before it reaches this config.

The seven equity tokens are worth a note of their own: on Base their account code is a single `0xef` byte, because they are handled natively by the client rather than by ordinary bytecode. `code.length > 0` passes, and calls to them work on Base itself, but the EVM cannot execute that byte — so a Foundry fork test touching them fails. `AaveV4BaseConfigureAndRelinquishTest` etches mock token and feed code at the configured addresses instead, which is what lets it push the real parameters through the configurators.

`tokenize` deploys a `TokenizationSpoke` for the asset and registers it on the Hub supply-only, the way every Avalanche core asset has one. Only USDC has one here: it is the supply-only spoke composable positions are built through, capped at $1,000,000. Its share token follows the live naming — `Wrapped Aave Equities USDC` / `waEquitiesUSDC` — and its ProxyAdmin owner is passed explicitly, so it lands on the Council rather than on whoever ran the script. `AaveV4BaseHandover.verifyProxyAdmins` walks the Hub's registered Spokes rather than only the ones the deploy produced, so a tokenization spoke whose ProxyAdmin went elsewhere — from this script or from a later listing payload — fails the handover verification with `UnexpectedOwner`.

Adding a second Spoke means a second `spokeLabels` entry; configuration registers every Spoke for every asset, with the same per-asset parameters.

## What is still open

- **The Security Council Safe on Base is a single key**, not the council 5-of-8. This is the blocker: it would take role `0` and every ProxyAdmin. See [The Security Council Safe on Base is one key](#the-security-council-safe-on-base-is-one-key--blocker). Escalated to the Council; confirm the owner swap on-chain before anything is deployed.
- **Wiring the Council executor into `config/base.json`.** The address exists; it stays out until the Safe is fixed, because the placeholder guard is what is holding the deploy. See [The Council executor](#the-council-executor).
