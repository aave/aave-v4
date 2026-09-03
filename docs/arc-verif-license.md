# Arc verification licences: outstanding issues

Every contract of the Arc deployment is source-verified on `explorer.arc.io`, but **21 of 24 carry the wrong licence**. This lists them and what is and is not fixable.

## The problem

Aave V4 sources declare `LicenseRef-BUSL`, which maps to Blockscout's `bsl_1_1`. The OpenZeppelin `TransparentUpgradeableProxy` used for the hub, both spokes and the treasury spoke declares `MIT`, which maps to `mit`. Neither is what the explorer records.

The cause is Blockscout's cross-chain matcher. Most of these contracts were never submitted: `eth_bytecode_db` recognised byte-identical verified code from the Ethereum and Avalanche V4 deployments and imported the record, and an imported record carries `license_type: none` regardless of what the source says.

**A verified record cannot be corrected by resubmitting.** Confirmed on `AaveV4ConfigEngine`: a corrective POST with `license_type=bsl_1_1` returned `{"message":"Smart-contract verification started"}` and the record stayed at `none`. Blockscout keeps the existing record and drops the new source, and it reports the worker failure only over its websocket channel, so the acknowledgement is misleading.

So the 21 below need explorer-side intervention from Circle, not another submission from us.

## Should be `bsl_1_1` (17)

| Contract                    | Address                                      | On explorer | Should be |
| --------------------------- | -------------------------------------------- | ----------- | --------- |
| `AaveOracle`                | `0x2abd2B5C30D649273B3b762b0E1758BaC8F87cFE` | `none`      | `bsl_1_1` |
| `AaveOracle`                | `0x6ffE98F3422041236c19923EDB949F18A69e8A09` | `none`      | `bsl_1_1` |
| `AaveV4ConfigEngine`        | `0x0A3af96f72b1B52c9BB9778FcD839154c2599371` | `none`      | `bsl_1_1` |
| `AccessManagerEnumerable`   | `0x24761DB265998ba1D38E8a29031cF72C2CeF3A7D` | `none`      | `bsl_1_1` |
| `AssetInterestRateStrategy` | `0xaa5b3bF9f16b634Eb1e0C1210bF8bB92b526e76D` | `none`      | `bsl_1_1` |
| `ConfigPositionManager`     | `0xa5Aa65Ae1c830d2ae10853CeEa42AE653adB3312` | `none`      | `bsl_1_1` |
| `GiverPositionManager`      | `0x01Da80Eef3004ebbF90b7637B1De7fF30fBc7cf1` | `none`      | `bsl_1_1` |
| `HubConfigurator`           | `0x419cF771E08d927b23F2F1691968C5135Ad8B659` | `none`      | `bsl_1_1` |
| `HubInstance`               | `0x3DcECcbD9b051638Bfa42200e7aAEC9Cc9621258` | `none`      | `bsl_1_1` |
| `LiquidationLogic`          | `0x818E84198224535FAeaEc1b583d3Ff6b812A5AF3` | `none`      | `bsl_1_1` |
| `PositionManagerEngine`     | `0x9fF7CCe79F0599D6Dd2620bc28763F7cE287D88e` | `none`      | `bsl_1_1` |
| `SignatureGateway`          | `0x0d36A4a21119BBBDe559d59002254171D976289f` | `none`      | `bsl_1_1` |
| `SpokeConfigurator`         | `0x102610d2A7Fd87A85ad8fdCfC78879be8Fd40576` | `none`      | `bsl_1_1` |
| `SpokeEngine`               | `0x8a121c22D558c91fc6819fEf1c738bb457Ad79F2` | `none`      | `bsl_1_1` |
| `SpokeInstance`             | `0xd4452Bd02C804245a41C75a5d0f6289C3ac787B6` | `none`      | `bsl_1_1` |
| `SpokeInstance`             | `0xf76b49F5911Ca3838a469563c0ffB07c8f91ba79` | `none`      | `bsl_1_1` |
| `TakerPositionManager`      | `0xe9fae1C386c6f45B1fb3C3Ef01aDE424DAd4bCcF` | `none`      | `bsl_1_1` |

## Should be `mit` (4)

| Contract                      | Address                                      | On explorer | Should be |
| ----------------------------- | -------------------------------------------- | ----------- | --------- |
| `TransparentUpgradeableProxy` | `0x17288dfc86205301064577b98B02b81017e6F79C` | `none`      | `mit`     |
| `TransparentUpgradeableProxy` | `0x4164EBCAF74670aa74C8D4F59de6157c0780F1bB` | `none`      | `mit`     |
| `TransparentUpgradeableProxy` | `0xB843bdC3a87A05E77E07Df9FE48928b3A34b134d` | `none`      | `mit`     |
| `TransparentUpgradeableProxy` | `0xcbd466CB8709D9f6dd8312668B4dbef394cE0e15` | `none`      | `mit`     |

## Correct (3)

These three were unverified when the deployment was checked, so submitting them with an explicit `license_type=bsl_1_1` worked — there was no imported record to lose to.

| Contract                    | Address                                      | On explorer | Should be |
| --------------------------- | -------------------------------------------- | ----------- | --------- |
| `AccessManagerEngine`       | `0x060b87b8481eEa9AeE246289AA774CE977445031` | `bsl_1_1`   | `bsl_1_1` |
| `HubEngine`                 | `0xc350fA6A315E783aB15D8F8bf6ECc49796587465` | `bsl_1_1`   | `bsl_1_1` |
| `TokenizationSpokeDeployer` | `0x38a979fa226e075f31C056CaE7C922Af782B1b66` | `bsl_1_1`   | `bsl_1_1` |

## What to ask Circle for

1. **Correct the licence on the 21 records above**, or allow re-verification to replace an existing record rather than dropping it.
2. **A Cloudflare Access service token.** Verification currently depends on a `CF_Authorization` browser cookie valid for 24 hours, which makes any bulk correction a race against expiry. Requested 25 August, still outstanding.

## How to avoid this next time

Submit **before** the matcher runs. The window is short and it is the whole game: a first status sweep of the deployment showed five contracts unverified that a sweep minutes later showed verified and licence-less. Anything not submitted in that window inherits `none` permanently.

There is no way to submit through forge. `--verifier-url` carries no headers and the explorer needs the Access cookie, so the shape is forge for the payload and curl for the POST:

```bash
forge verify-contract <addr> <src/Path.sol:Name> --show-standard-json-input > input.json
curl -X POST --cookie "CF_Authorization=$ARC_EXPLORER_TOKEN" \
  -F compiler_version=v0.8.28+commit.7893614a \
  -F license_type=bsl_1_1 \
  -F autodetect_constructor_args=false -F constructor_args= \
  -F 'files[0]=@input.json;type=application/json' \
  https://explorer.arc.io/api/v2/smart-contracts/<addr>/verification/via/standard-input
```

Three gotchas that cost time here:

- **`forge verify-contract` cannot run at all in this repo** until the `[etherscan]` table is fixed. Several aliases (`bnb`, `fantom`, and others behind them) are unknown to forge 1.7.1 and specify `chainId` rather than `chain`, so the table fails to resolve and every invocation errors out before doing anything — including `--show-standard-json-input`, which needs no network. The payloads here were generated with that table commented out.
- **Contracts that link libraries need `FOUNDRY_LIBRARIES` exported when the payload is generated**, or `settings.libraries` comes out empty and the submitted source compiles to different bytecode. `HubEngine` needs `TokenizationSpokeDeployer`; `AaveV4ConfigEngine` needs all four engine libraries; `SpokeInstance` needs `LiquidationLogic`.
- **`/Users/koga/Work/misc-scripts/verify-arc.sh` re-sources `.env` internally**, so an exported `FOUNDRY_LIBRARIES` is overwritten by whatever `.env` holds. For library-linked contracts, generate the payload and POST manually instead. Its bytecode pre-check also masks only immutable spans, so it warns spuriously on libraries, which embed their own address after a leading `PUSH20`, and on the config engine, whose link slots it does not mask.
