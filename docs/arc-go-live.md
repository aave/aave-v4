# Aave V4 on Arc — going live

Chain id 5042. Deployed, configured and handed over from `0x623f1C807fE1088439e129ebF3B9c92a63a0F5cD`. Four assets are listed on the `core` hub across the `main` and `forex` spokes, and **the whole market is halted**.

Two Safe transactions remain, both from `0x187AAE17d4931310B3fc75743e7F16Bdc9eD77e9`, **in this order**: step 1, then step 2. Until step 1 lands the deployer EOA still holds `rescueToken` and `rescueNative` on contracts that will be handling user funds, so un-pausing first would open the market with that outstanding.

Both should also wait on the Safe reaching 5-of-8. It is already the root authority and owns every ProxyAdmin.

## Step 1 — accept ownership of the position managers

`docs/arc-safe-1-accept-ownership.json` — 4 transactions.

The three position managers and the signature gateway were deployed owned by the deployer, because configuration needs `onlyOwner` access to `registerSpoke` on them. The handover called `transferOwnership` to the Safe, and `PositionManagerBase` is `Ownable2Step`, so each one is waiting on `acceptOwnership()`.

Until this runs, the deployer still owns those four contracts, which means `registerSpoke`, `renouncePositionManagerRole` and — since the rescue guardian is `owner()` — `rescueToken` and `rescueNative`. Everything else is already the Safe's.

Worth understanding the shape of this rather than just doing it: **all fifteen relinquish transactions succeeded and ownership never moved.** `transferOwnership` on an `Ownable2Step` contract records a pending owner and returns successfully, so a check that the calls went through reports a clean handover while the deployer still owns everything. Only a check of `owner()` itself catches it. That is why `ArcVerification` asserts end state rather than transaction success, and it is the part worth carrying to the next chain.

| Contract              | Address                                      | Call                |
| --------------------- | -------------------------------------------- | ------------------- |
| GiverPositionManager  | `0x01Da80Eef3004ebbF90b7637B1De7fF30fBc7cf1` | `acceptOwnership()` |
| TakerPositionManager  | `0xe9fae1C386c6f45B1fb3C3Ef01aDE424DAd4bCcF` | `acceptOwnership()` |
| ConfigPositionManager | `0xa5Aa65Ae1c830d2ae10853CeEa42AE653adB3312` | `acceptOwnership()` |
| SignatureGateway      | `0x0d36A4a21119BBBDe559d59002254171D976289f` | `acceptOwnership()` |

## Step 2 — un-pause the market

`docs/arc-safe-2-unpause.json` — 14 transactions. **This is the go-live switch. Do not run it until step 1 has landed, the Safe is 5-of-8, and the blocking items below are settled.**

Every asset was halted at the end of configuration with `HubConfigurator.haltAsset`, which sets `halted = true` on every spoke registered for it. There is no `unhaltAsset`, so releasing means one `Hub.updateSpokeConfig` per asset-and-spoke pair with `halted` cleared and the caps passed back unchanged.

The Safe holds `HUB_CONFIGURATOR_ROLE` (101), so it calls the Hub **directly** — no Executor hop. Confirmed on chain: `AccessManager.canCall(Safe, Hub, 0xa2763d29)` returns true with zero delay, and the same call from the Executor or the deployer returns false.

Each transaction targets the hub, `0x17288dfc86205301064577b98B02b81017e6F79C`:

| Asset  | assetId | Spoke        | Address                                      | addCap            | drawCap    |
| ------ | ------- | ------------ | -------------------------------------------- | ----------------- | ---------- |
| USDC   | 0       | treasury     | `0xcbd466CB8709D9f6dd8312668B4dbef394cE0e15` | 1,099,511,627,775 | 0          |
| USDC   | 0       | main         | `0xB843bdC3a87A05E77E07Df9FE48928b3A34b134d` | 56,000,000        | 51,000,000 |
| USDC   | 0       | forex        | `0x4164EBCAF74670aa74C8D4F59de6157c0780F1bB` | 13,000,000        | 11,000,000 |
| USDC   | 0       | tokenization | `0x42EAB64310E1D1c66b4d8aF7C9C4ce253885eB83` | 10,000,000        | 0          |
| EURC   | 1       | treasury     | `0xcbd466CB8709D9f6dd8312668B4dbef394cE0e15` | 1,099,511,627,775 | 0          |
| EURC   | 1       | main         | `0xB843bdC3a87A05E77E07Df9FE48928b3A34b134d` | 20,000,000        | 18,000,000 |
| EURC   | 1       | forex        | `0x4164EBCAF74670aa74C8D4F59de6157c0780F1bB` | 10,000,000        | 9,000,000  |
| EURC   | 1       | tokenization | `0x5A10b1533C0f1f181DC8a428BF5Eb58B08fc8d2c` | 9,000,000         | 0          |
| cirBTC | 2       | treasury     | `0xcbd466CB8709D9f6dd8312668B4dbef394cE0e15` | 1,099,511,627,775 | 0          |
| cirBTC | 2       | main         | `0xB843bdC3a87A05E77E07Df9FE48928b3A34b134d` | 1,100             | 220        |
| cirBTC | 2       | tokenization | `0x83D364DbAf4e7018E0b87dB3FaB3d1d8535a6F13` | 160               | 0          |
| WETH   | 3       | treasury     | `0xcbd466CB8709D9f6dd8312668B4dbef394cE0e15` | 1,099,511,627,775 | 0          |
| WETH   | 3       | main         | `0xB843bdC3a87A05E77E07Df9FE48928b3A34b134d` | 24,000            | 4,800      |
| WETH   | 3       | tokenization | `0xe8B890fea6e1E3915A337eD3136487F2f4f7e59D` | 6,000             | 0          |

Caps are in whole token units; the Hub scales them by each token's decimals. The treasury spoke carries `MAX_ALLOWED_SPOKE_CAP` as its add cap, which is the fee-receiver default and means uncapped.

The bundle can be split if you would rather release in stages — each transaction is independent. Releasing an asset only on `main` and not on `forex`, for instance, is just a matter of dropping the rows you do not want yet.

After it lands, `forge script scripts/config/AaveV4VerifyArc.s.sol --rpc-url arc` will fail on the halt assertion, since it checks that everything **is** halted. That is expected once the market is open.

## Deployed addresses

### Core

| Contract                  | Address                                      |
| ------------------------- | -------------------------------------------- |
| AccessManagerEnumerable   | `0x24761DB265998ba1D38E8a29031cF72C2CeF3A7D` |
| HubConfigurator           | `0x419cF771E08d927b23F2F1691968C5135Ad8B659` |
| SpokeConfigurator         | `0x102610d2A7Fd87A85ad8fdCfC78879be8Fd40576` |
| AssetInterestRateStrategy | `0xaa5b3bF9f16b634Eb1e0C1210bF8bB92b526e76D` |
| AaveV4ConfigEngine        | `0x0A3af96f72b1B52c9BB9778FcD839154c2599371` |

### Proxies

Each row is a `TransparentUpgradeableProxy`. Every ProxyAdmin is owned by the Safe.

| Contract                   | Proxy                                        | Implementation                               | ProxyAdmin                                   |
| -------------------------- | -------------------------------------------- | -------------------------------------------- | -------------------------------------------- |
| Hub (core)                 | `0x17288dfc86205301064577b98B02b81017e6F79C` | `0x3DcECcbD9b051638Bfa42200e7aAEC9Cc9621258` | `0x64F13f38798818D7AaC1bbD4dEfa163b90EA2fdD` |
| Spoke (main)               | `0xB843bdC3a87A05E77E07Df9FE48928b3A34b134d` | `0xf76b49F5911Ca3838a469563c0ffB07c8f91ba79` | `0x6a1beE304Ce745Df8D3Ab5c18f16Ac0561BD2626` |
| Spoke (forex)              | `0x4164EBCAF74670aa74C8D4F59de6157c0780F1bB` | `0xd4452Bd02C804245a41C75a5d0f6289C3ac787B6` | `0xE8d75bb46C15c70dB2A464886f51b8a46A871108` |
| TreasurySpoke              | `0xcbd466CB8709D9f6dd8312668B4dbef394cE0e15` | `0x25AE500228A7307673BbD933F806ce7DC6555D66` | `0xfa12D100A649c8D4dCC0047f9618b2bB4939f6A0` |
| TokenizationSpoke (USDC)   | `0x42EAB64310E1D1c66b4d8aF7C9C4ce253885eB83` | `0x7a2f8AFBF1F0Acaf5610d1D6860aFb5Ac931Ee43` | `0xFf7727ab55df7356F218c887C35a65c51768E374` |
| TokenizationSpoke (EURC)   | `0x5A10b1533C0f1f181DC8a428BF5Eb58B08fc8d2c` | `0x9295E6e945e52DCD5AAE7943Fd9ACb62496A87ce` | `0x5b3d12e8c9168c6323D5158B8862F7dAA08605Eb` |
| TokenizationSpoke (cirBTC) | `0x83D364DbAf4e7018E0b87dB3FaB3d1d8535a6F13` | `0x4d2763ED7e162C1b7949176D73BEcEE940fDAF47` | `0x3414c0e09C804A63e5a2E003eA7226DEae975f7C` |
| TokenizationSpoke (WETH)   | `0xe8B890fea6e1E3915A337eD3136487F2f4f7e59D` | `0x0215DF4A493A984997B1FB89660A3a1332fb5A4c` | `0xB05C54B974cE826e48AE7e3C2A72B2a8900E3B34` |

### Position managers and gateways

Owned by the deployer until step 1.

| Contract              | Address                                      |
| --------------------- | -------------------------------------------- |
| GiverPositionManager  | `0x01Da80Eef3004ebbF90b7637B1De7fF30fBc7cf1` |
| TakerPositionManager  | `0xe9fae1C386c6f45B1fb3C3Ef01aDE424DAd4bCcF` |
| ConfigPositionManager | `0xa5Aa65Ae1c830d2ae10853CeEa42AE653adB3312` |
| SignatureGateway      | `0x0d36A4a21119BBBDe559d59002254171D976289f` |

### Oracles

One `AaveOracle` per spoke, holding the per-reserve price sources.

| Contract           | Address                                      |
| ------------------ | -------------------------------------------- |
| AaveOracle (main)  | `0x6ffE98F3422041236c19923EDB949F18A69e8A09` |
| AaveOracle (forex) | `0x2abd2B5C30D649273B3b762b0E1758BaC8F87cFE` |

### Libraries

Deployed separately and linked into the contracts that call them.

| Library                   | Address                                      | Linked into        |
| ------------------------- | -------------------------------------------- | ------------------ |
| LiquidationLogic          | `0x818E84198224535FAeaEc1b583d3Ff6b812A5AF3` | SpokeInstance      |
| AccessManagerEngine       | `0x060b87b8481eEa9AeE246289AA774CE977445031` | AaveV4ConfigEngine |
| HubEngine                 | `0xc350fA6A315E783aB15D8F8bf6ECc49796587465` | AaveV4ConfigEngine |
| SpokeEngine               | `0x8a121c22D558c91fc6819fEf1c738bb457Ad79F2` | AaveV4ConfigEngine |
| PositionManagerEngine     | `0x9fF7CCe79F0599D6Dd2620bc28763F7cE287D88e` | AaveV4ConfigEngine |
| TokenizationSpokeDeployer | `0x38a979fa226e075f31C056CaE7C922Af782B1b66` | HubEngine          |

### Assets

| Asset  | assetId | Underlying                                   | Dec | Price source                                 |
| ------ | ------- | -------------------------------------------- | --- | -------------------------------------------- |
| USDC   | 0       | `0x3600000000000000000000000000000000000000` | 6   | `0x729cFd10FC10A908aE9F9b35245cB6Ee14D44D6B` |
| EURC   | 1       | `0xbEf5f6d51CB62b58e6A8f77868681825C6fe21c1` | 6   | `0x1aBa23B4733aa96919C4434c1b9AC25bE9550d58` |
| cirBTC | 2       | `0x171A4217b86A807A64eB94757Db6849fb4bDbAA0` | 8   | `0x7777547914e03BCbB04Ae034942765a0dbb26aE3` |
| WETH   | 3       | `0x128cC466B61f542da60c70e3aA11c10e19B84EDB` | 18  | `0x2c7Dc3567b3490f53A8d32625d766834dd023F60` |

USDC and EURC price through capped adapters (`PriceCapAdapterStable` and `EURPriceCapAdapterStable`); cirBTC and wETH through Chainlink SVR proxies for BTC/USD and ETH/USD.

### Tokenization spokes

Supply-only, one per asset, ERC-4626 share tokens.

| Asset  | Proxy                                        | Share name               | Symbol         | Add cap    |
| ------ | -------------------------------------------- | ------------------------ | -------------- | ---------- |
| USDC   | `0x42EAB64310E1D1c66b4d8aF7C9C4ce253885eB83` | Wrapped Aave Core USDC   | `waCoreUSDC`   | 10,000,000 |
| EURC   | `0x5A10b1533C0f1f181DC8a428BF5Eb58B08fc8d2c` | Wrapped Aave Core EURC   | `waCoreEURC`   | 9,000,000  |
| cirBTC | `0x83D364DbAf4e7018E0b87dB3FaB3d1d8535a6F13` | Wrapped Aave Core cirBTC | `waCorecirBTC` | 160        |
| WETH   | `0xe8B890fea6e1E3915A337eD3136487F2f4f7e59D` | Wrapped Aave Core WETH   | `waCoreWETH`   | 6,000      |

## Authority

| Role                            | Id  | Holder                                                        |
| ------------------------------- | --- | ------------------------------------------------------------- |
| ACCESS_MANAGER_ADMIN            | 0   | Safe                                                          |
| HUB_CONFIGURATOR                | 101 | HubConfigurator contract, Safe                                |
| HUB_FEE_MINTER                  | 102 | Safe                                                          |
| HUB_DEFICIT_ELIMINATOR          | 103 | Safe                                                          |
| HUB_CONFIGURATOR_DOMAIN_ADMIN   | 200 | Council Executor `0x8e79b0541122d3822eC93082cEB1ab03EDBc1Fd5` |
| SPOKE_CONFIGURATOR              | 301 | SpokeConfigurator contract, Safe                              |
| SPOKE_USER_POSITION_UPDATER     | 302 | Safe                                                          |
| SPOKE_CONFIGURATOR_DOMAIN_ADMIN | 400 | Council Executor                                              |

The deployer holds no role. Roles 100 and 300 are held by nobody, as on Ethereum and Avalanche.

### Divergence from the other markets

Arc grants the Safe raw hub and spoke roles that the other two V4 markets do not grant to anyone. Enumerated on all three chains:

| Role                      | Ethereum               | Avalanche              | Arc                          |
| ------------------------- | ---------------------- | ---------------------- | ---------------------------- |
| 101 hub configurator      | HubConfigurator only   | HubConfigurator only   | HubConfigurator **+ Safe**   |
| 102 fee minter            | **nobody**             | **nobody**             | **Safe**                     |
| 103 deficit eliminator    | **nobody**             | **nobody**             | **Safe**                     |
| 301 spoke configurator    | SpokeConfigurator only | SpokeConfigurator only | SpokeConfigurator **+ Safe** |
| 302 user position updater | **nobody**             | **nobody**             | **Safe**                     |

These are not one decision, they are two:

- **101 is load-bearing — leave it.** The un-pause in step 2 depends on the Safe calling the Hub directly, and the Executor cannot: `canCall(Executor, Hub, 0xa2763d29)` is false. Revoking 101 would break the release path.
- **102, 103 and 302 have no stated purpose on Arc and no holder on either other market.** Three roles that exist nowhere else are live here. Unless there is a reason for them, revoke — cheap now, awkward once the market is open. 301 is in the same category as 101 in principle, though nothing in the current release path needs it.

## Known issues

### Blocking un-pause

- **The Safe is reportedly 1 owner at threshold 1.** It is the root authority and owns every ProxyAdmin.
- **cirBTC prices off a raw BTC/USD feed at a 78% collateral factor.** `PriceCapAdapterBase` clamps only the upper bound and has no floor, so a cirBTC discount to BTC is unpriced. This stopped being hypothetical when the asset was listed: the exposure is real from the moment step 2 runs. Every other wrapped BTC in the Aave price-feed set takes an asset-specific second input; cirBTC on a flat BTC/USD price is the first exception. A capped adapter is a one-field config change.
- **The 1.04 price cap** on the USDC and EURC adapters traces to no line of the ARFC — it is an inherited cross-network default, and it is load-bearing for both stablecoins. Confirm or set it deliberately.

### Non-blocking

- **Licence metadata is wrong on 21 of 24 verified contracts** — see `docs/arc-verif-license.md`. Cosmetic, and not fixable by resubmission.
- **wETH also sits on a raw Chainlink feed** rather than a capped adapter. Less acute than cirBTC — ETH/USD is a direct price for the asset, not a proxy for it — but the same asymmetry against USDC and EURC.
