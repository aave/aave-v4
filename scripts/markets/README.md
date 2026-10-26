# Aave V4 initial markets

Scripts, configs, payloads and generators used for the initial Aave V4 deployments on Ethereum (2026-03-23/24) and Avalanche (2026-07-07), both deployed by `0xB00A89E5C8756bA8629846eEF8a4a9C71Ad1930A`, and Arc (2026-09-02), deployed by `0x623f1C807fE1088439e129ebF3B9c92a63a0F5cD`. They were recovered from the private `feat/deploy` (Ethereum) and `feat/deploy-avax-devnet` (Avalanche) branches, plus the Etherscan/Snowscan verified sources for the files that were never committed, and adapted to compile against the current `src/`.

```
scripts/markets/
├── AaveV4MarketPayloadsBase.s.sol      executor / handover helpers
├── generator/                          config + payload generators (bun)
├── ethereum/
│   ├── config/                         Chaos Labs xlsx, config.json, deployment.json, tokenization-deploy.json
│   ├── AaveV4Contracts.sol             generated address library
│   ├── AaveV4DeployEthereumMarket.s.sol
│   ├── TokenizationSpokeDeploy.s.sol   generated
│   ├── AaveV4EthereumMarketPayloads.s.sol
│   └── payloads/
├── avalanche/                          same layout, LlamaRisk markdown instead of the xlsx
└── arc/                                configured by the deployer directly, no payloads (see below)
    ├── config/                         deploy.json (deploy inputs and handover targets), config.json (assets), deployment.json
    ├── libraries/                      ARFC parameters, configuration, handover and verification logic
    ├── tests/                          `make market-test`
    └── docs/                           go-live notes and the Security Council Safe batches
```

## Run order

All targets take `market=ethereum|avalanche chain=<rpc alias> account=<keystore>`, add `dry=1` to simulate.

| Step | Target                                                      | On-chain counterpart (deployer nonces, ETH / AVAX)             |
| ---- | ----------------------------------------------------------- | -------------------------------------------------------------- |
| 1    | `market-deploy-precompile`                                  | LiquidationLogic, salt `11231` (0 / 0)                         |
| 2    | `market-deploy-contracts`                                   | batches + roles (1-67 / 1-38)                                  |
| 3    | `market-setup`                                              | executor setup, permissions, listings (73-85 / 40-64)          |
| 4    | `market-deploy-tokenization`, `market-tokenization-payload` | Factory + TokenizationSpokes (86-117 / 65-72)                  |
| 5    | `market-listings` (`engine=<ConfigEngine>` on Ethereum)     | remaining payloads (118-135 / 73-77)                           |
| 6    | `market-handover`                                           | handover to Governance and Security Council (136-198 / 83-117) |

Config and payload regeneration: `market-config`, `market-address-lib`, `market-payloads`, `market-tokenization`, `market-diff`.

The following contracts are not part of this repository and are referenced by address, they must exist before the step that uses them:

- Aave Governance `Executor` owned by the deployer, used to delegatecall the payloads: `0x778b07a501a7a8d7625e51C3Ea84D090118f0161` on Ethereum (before step 3), `0x5066364AE356DC95837772d9fC17ed926Fd54576` and `0xb619fA61e795D47f517702e63ce50292370561F1` on Avalanche (before steps 3 and 6).
- Ethereum price cap adapters listed in `ethereum/config/config.json` (aave-capo), including the LBTC ones used by `DiffPayload` (before step 5).

## Differences with the original deployment

Replaying all steps on forks taken right before the first deploy transaction reproduces every deployed address in `config/deployment.json` and `config/tokenization-deploy.json`, and every event emitted by the market contracts (hubs, spokes, oracles, configurators, access manager, position managers, tokenization spokes, proxy admins) is identical to mainnet. What differs:

- `AaveV4HubInstanceBatch` and `AaveV4SpokeInstanceBatch` bytecode changed on main (revert string and parameter rename), these batch contracts are transient and the Hub and Spoke contracts they deploy are unchanged.
- `AaveV4ConfigEngine`, its libraries and `AaveV4Payload` changed on main, so the ConfigEngine and every payload compile to a different bytecode than the deployed ones. Payload contents are unchanged except for the `proxyAdminOwner: address(0)` field required by the current `TokenizationSpokeConfig`.
- `ethereum/payloads/ConfigPayload_3a/3b` are kept as deployed, they were generated before the EURC, LBTC and USDG feeds were switched to the CAPO and fixed price adapters by `DiffPayload`. `ethereum/config/config.json` is the post-update config, regenerating the payloads from it lists the reserves with the new feeds directly. `DiffPayload` was generated against the chain state at the time and cannot be regenerated.
- The Avalanche tokenization `addCap` values in `avalanche/config/config.json` were lowered by hand after generation, running `market-config` outputs the original LlamaRisk derived caps.
- `Deactivate`, `DeactivateHub`, `FinalPermissionsPayload` and the Avalanche payloads come from their verified sources, the handover script reproduces transactions that were sent manually, with the ProxyAdmin ownership transfers in a different order.
- A third Avalanche ConfigEngine and its libraries (nonces 78-82) were deployed but never used, they are not reproduced.

## Arc

Arc was not configured through payloads: the deployer kept the AccessManager admin role (`grantRoles: false`), configured the market with direct calls, halted every asset and handed everything over to the Security Council Safe `0x187AAE17d4931310B3fc75743e7F16Bdc9eD77e9`, with the Council Executor `0x8e79b0541122d3822eC93082cEB1ab03EDBc1Fd5` as configurator domain admin. Imported from aave/aave-v4#1354.

All targets take `chain=<rpc alias> account=<keystore>`, add `dry=1` to simulate.

| Step | Target                                                                           | Deployer nonces                                         |
| ---- | -------------------------------------------------------------------------------- | ------------------------------------------------------- |
| 1    | `market-deploy-precompile market=arc`                                            | none, LiquidationLogic was already deployed at salt `0` |
| 2    | `market-deploy-contracts market=arc`                                             | 22-47                                                   |
| 3    | `arc-deploy-config-engine`                                                       | 48-51                                                   |
| 4    | `arc-configure`                                                                  | 52-101                                                  |
| 5    | `arc-relinquish`                                                                 | 102-116                                                 |
| 6    | `arc-verify`, read only, after the Safe accepted the position managers ownership |                                                         |

The two Safe batches that followed (accept ownership, then un-halt) are in `arc/docs/`. `arc-verify` asserts the market is halted, so it fails against the live market since the un-halt.

Replaying steps 2 to 5 on a fork taken right before nonce 22 reproduces every address in `arc/config/deployment.json`, the ConfigEngine and the TokenizationSpokes, with the same calldata and events for every transaction except the `since` timestamp of `RoleGranted`. Nonces 0-21 and 117+ are outside of this repository (the Council Executor deployment, an earlier deployment attempt with other inputs, and later unrelated transactions).
