# Aave V4 Deployment Infrastructure

Infrastructure for deploying and configuring the Aave V4 hub-and-spoke protocol.

## Quickstart

Deploys all contracts and grants roles basic roles. No assets are listed, no spokes are registered, no reserves are configured.

### 1. Configure `.env`

Copy `.env.example` and set:

| Variable  | Description                                          |
| --------- | ---------------------------------------------------- |
| `ACCOUNT` | Foundry keystore account name for the deployer       |
| `DRY`     | Leave blank to broadcast; set to a value to simulate |

The deploy script constructs a `FullDeployInputs` struct (see `src/deployments/utils/InputUtils.sol`) with admin addresses, hub/spoke labels, CREATE2 salt, and gateway flags. Override `_getDeployInputs()` in your chain-specific script (extends `AaveV4DeployBatchBase.s.sol`) to provide these values. Any zero-address admin fields default to the deployer.

### 2. Pre-deploy LiquidationLogic (required for spokes)

```bash
make deploy-precompile
```

This deploys `LiquidationLogic` via CREATE2 and writes `FOUNDRY_LIBRARIES` to `.env` so Foundry can link `SpokeInstance` bytecode on the next compilation. See [LiquidationLogic Pre-deployment](#liquidationlogic-pre-deployment) for details.

### 3. Deploy Remaining Contracts

```bash
make deploy-contracts
```

This runs `AaveV4DeployOrchestration.deployAaveV4()`, which deploys batches in order: AccessManager → role labeling → Configurators → Configurator role setup → TreasurySpoke → Hubs → Spokes → Gateways → PositionManagers → role grants → DEFAULT_ADMIN transfer.

### TokenizationSpoke

`TokenizationSpoke` is **not** deployed by the orchestration, because it requires an asset to already be listed on a Hub and Spoke. Each `TokenizationSpoke` instance should be deployed separately after asset listing, one per asset.

### LiquidationLogic Pre-deployment

`LiquidationLogic` is an external Solidity library used by `Spoke.sol` (via `SpokeInstance`). Because it has `external` functions, the compiler emits it as a separate contract that `SpokeInstance` calls via `DELEGATECALL` at runtime. When Solidity compiles `SpokeInstance`, it leaves placeholder references (`__$<hash>$__`) in the bytecode where the library address should go. You cannot deploy `SpokeInstance` until those placeholders are replaced with a real on-chain address.

This requires a **two-step deploy** because Foundry needs to re-compile with the library address baked into the bytecode:

**Step 1 — `LibraryPreCompile.s.sol`** (separate transaction):

1. `SpokeDeployUtils.deployLiquidationLogic()` deploys it via CREATE2 with `salt=0`
2. Writes `FOUNDRY_LIBRARIES=src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic:0x<address>` to `.env` via FFI
3. On re-run: if the library is already deployed (has code), skips. If `FOUNDRY_LIBRARIES` exists but the library isn't deployed (wrong chain/fork), deletes the stale entry and asks you to run again

**Step 2 — Main deploy script** (next invocation):

1. Foundry reads `.env` at startup, sees `FOUNDRY_LIBRARIES`, and at compile time replaces all `__$<hash>$__` placeholders in `SpokeInstance`'s bytecode with the library address
2. `AaveV4SpokeInstanceBatch` deploys `SpokeInstance` with fully linked bytecode

## Architecture

```
scripts/deploy/
  AaveV4DeployBatchBase.s.sol     Base: deploy-only run()

src/deployments/
  batches/                    Batch constructors -- deploy related contracts together
    AaveV4AuthorityBatch        AccessManagerEnumerable
    AaveV4ConfiguratorBatch     HubConfigurator, SpokeConfigurator
    AaveV4TreasurySpokeBatch    TreasurySpoke (single instance, proxy + impl)
    AaveV4HubInstanceBatch      HubInstance (proxy + impl), InterestRateStrategy
    AaveV4SpokeInstanceBatch    SpokeInstance (proxy + impl), AaveOracle
    AaveV4GatewayBatch          NativeTokenGateway, SignatureGateway
    AaveV4PositionManagerBatch  GiverPositionManager, TakerPositionManager, ConfigPositionManager

  orchestration/              High-level orchestrators
    AaveV4DeployOrchestration   Main entry: deployAaveV4() -- calls batches in order
    AaveV4DeployBase            Static deploy helpers for each batch

  procedures/                 Granular operations
    deploy/                   Individual contract deploy procedures
    roles/                    Role setup procedures per component

  libraries/
    BatchReports              Report structs for each batch
    OrchestrationReports      Full deployment report aggregation
    ConfigData                Parameter structs for config operations

  utils/
    InputUtils                FullDeployInputs struct
    Roles                     Role ID constants (0, 100-103, 200, 300-302, 400)
    Create2Utils              Deterministic deployment helpers
    Logger / MetadataLogger   Deployment logging and JSON output
```

### Roles (Roles.sol)

Roles are namespaced by contract domain: Hub (100-199), HubConfigurator (200-299), Spoke (300-399), SpokeConfigurator (400-499). See `Roles.sol` NatSpec for the full role strategy and evolution guidelines.

All roles are labeled on the `AccessManagerEnumerable` during deployment via `AaveV4AccessManagerRolesProcedure.labelAllRoles()`. Each role is labeled with its `Roles.sol` constant name (e.g., role 101 is labeled `"HUB_CONFIGURATOR_ROLE"`). Labels are queryable on-chain via `getLabelOfRole()` and `getRoleOfLabel()`.

#### `AccessManager` Role

| ID  | Name               | Granted To         | Notes                                                             |
| --- | ------------------ | ------------------ | ----------------------------------------------------------------- |
| 0   | DEFAULT_ADMIN_ROLE | accessManagerAdmin | OpenZeppelin built-in. Transferred from deployer at end of deploy |

#### `Hub` Roles

| ID  | Name                        | Granted To                         | Functions                                                                     |
| --- | --------------------------- | ---------------------------------- | ----------------------------------------------------------------------------- |
| 100 | HUB_DOMAIN_ADMIN_ROLE       | hubAdmin                           | (reserved for future use)                                                     |
| 101 | HUB_CONFIGURATOR_ROLE       | hubAdmin, HubConfigurator contract | addAsset, updateAssetConfig, addSpoke, updateSpokeConfig, setInterestRateData |
| 102 | HUB_FEE_MINTER_ROLE         | hubAdmin                           | mintFeeShares                                                                 |
| 103 | HUB_DEFICIT_ELIMINATOR_ROLE | hubAdmin                           | eliminateDeficit                                                              |

#### `HubConfigurator` Roles

| ID  | Name                               | Granted To           | Functions                                        |
| --- | ---------------------------------- | -------------------- | ------------------------------------------------ |
| 200 | HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE | hubConfiguratorAdmin | All 22 HubConfigurator selectors (see Roles.sol) |

Domain admin role holds all selectors initially. Granular roles (201+) are carved out as needed.

#### `Spoke` Roles (on Spoke contract)

| ID  | Name                             | Granted To                             | Functions                                                                                                                                                      |
| --- | -------------------------------- | -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 300 | SPOKE_DOMAIN_ADMIN_ROLE          | spokeAdmin                             | (reserved for future use)                                                                                                                                      |
| 301 | SPOKE_USER_POSITION_UPDATER_ROLE | spokeAdmin                             | updateUserDynamicConfig, updateUserRiskPremium                                                                                                                 |
| 302 | SPOKE_CONFIGURATOR_ROLE          | spokeAdmin, SpokeConfigurator contract | updateLiquidationConfig, addReserve, updateReserveConfig, updateDynamicReserveConfig, addDynamicReserveConfig, updatePositionManager, updateReservePriceSource |

#### `SpokeConfigurator` Roles (on SpokeConfigurator contract)

| ID  | Name                                 | Granted To             | Functions                                          |
| --- | ------------------------------------ | ---------------------- | -------------------------------------------------- |
| 400 | SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE | spokeConfiguratorAdmin | All 24 SpokeConfigurator selectors (see Roles.sol) |

Domain admin role holds all selectors initially. Granular roles (401+) are carved out as needed.

## Data Flow

```
AaveV4DeployBatchBase.s.sol                         (Foundry script entry point)
  run()
    _getDeployInputs()                              override per chain in extended script
    vm.startBroadcast()
    _loadWarningsAndSanitizeInputs()                validate labels, default zero addrs to deployer
    |
    +-- AaveV4DeployOrchestration.deployAaveV4()    (library — all calls execute as deployer)
    |     |
    |     +-- _deriveSalt(deployer, salt)            [deployer(160b) | hash(SALT,salt)(96b)]
    |     |
    |     +-- _deployAuthorityBatch()
    |     |     AaveV4DeployBase.deployAuthorityBatch()
    |     |       new AaveV4AuthorityBatch(admin, salt)
    |     |         AaveV4AccessManagerEnumerableDeployProcedure._deployAccessManagerEnumerable()
    |     |           Create2Utils.create2Deploy() --> AccessManagerEnumerable
    |     |
    |     +-- _labelRoles()
    |     |     AaveV4AccessManagerRolesProcedure.labelAllRoles()
    |     |       AccessManager.labelRole()  (labels all roles with the associated Roles.sol constant names)
    |     |
    |     +-- _deployConfiguratorBatch()
    |     |     AaveV4DeployBase.deployConfiguratorBatch()
    |     |       new AaveV4ConfiguratorBatch(hubAuth, spokeAuth, salt)
    |     |         AaveV4HubConfiguratorDeployProcedure._deployHubConfigurator()
    |     |           Create2Utils.create2Deploy() --> HubConfigurator
    |     |         AaveV4SpokeConfiguratorDeployProcedure._deploySpokeConfigurator()
    |     |           Create2Utils.create2Deploy() --> SpokeConfigurator
    |     |
    |     +-- _setupConfiguratorRoles()
    |     |     AaveV4HubConfiguratorRolesProcedure.setupHubConfiguratorAllRoles()
    |     |       AccessManager.setTargetFunctionRole()  (selector -> role mappings for HubConfigurator)
    |     |     AaveV4SpokeConfiguratorRolesProcedure.setupSpokeConfiguratorAllRoles()
    |     |       AccessManager.setTargetFunctionRole()  (selector -> role mappings for SpokeConfigurator)
    |     |
    |     +-- _deployTreasurySpokeBatch()
    |     |     AaveV4DeployBase.deployTreasurySpokeBatch()
    |     |       new AaveV4TreasurySpokeBatch(owner, salt)
    |     |         Create2Utils.create2Deploy() --> TreasurySpoke
    |     |
    |     +-- _deployHubs(hubLabels)                for each hub label:
    |     |     _deployHub()
    |     |       _deployHubInstanceBatch()
    |     |         AaveV4DeployBase.deployHubInstanceBatch()
    |     |           new AaveV4HubInstanceBatch(proxyAdmin, authority, hubBytecode, salt)
    |     |             Create2Utils.proxify()    --> HubInstance (proxy + impl)
    |     |             Create2Utils.create2Deploy() --> InterestRateStrategy
    |     |       _setupHubRoles()
    |     |         AaveV4HubRolesProcedure.setupHubAllRoles()
    |     |           AccessManager.setTargetFunctionRole()  (selector -> role mappings for Hub)
    |     |
    |     +-- _deploySpokes(spokeLabels)            for each spoke label:
    |     |     _deploySpoke()
    |     |       _deploySpokeInstanceBatch()
    |     |         AaveV4DeployBase.deploySpokeInstanceBatch()
    |     |           new AaveV4SpokeInstanceBatch(proxyAdmin, authority, bytecode, ...)
    |     |             new AaveOracle()             (non-deterministic, needs setSpoke post-deploy)
    |     |             Create2Utils.proxify()    --> SpokeInstance (proxy + impl)
    |     |       _setupSpokeRoles()
    |     |         AaveV4SpokeRolesProcedure.setupSpokeAllRoles()
    |     |           AccessManager.setTargetFunctionRole()  (selector -> role mappings for Spoke)
    |     |
    |     +-- _deployGatewayBatch()                 (if deployNativeTokenGateway || deploySignatureGateway)
    |     |     AaveV4DeployBase.deployGatewaysBatch()
    |     |       new AaveV4GatewayBatch(owner, nativeWrapper, flags, salt)
    |     |         Create2Utils.create2Deploy() --> NativeTokenGateway, SignatureGateway
    |     |
    |     +-- _deployPositionManagerBatch()         (if deployPositionManagers)
    |     |     AaveV4DeployBase.deployPositionManagerBatch()
    |     |       new AaveV4PositionManagerBatch(owner, salt)
    |     |         Create2Utils.create2Deploy() --> GiverPositionManager
    |     |         Create2Utils.create2Deploy() --> TakerPositionManager
    |     |         Create2Utils.create2Deploy() --> ConfigPositionManager
    |     |
    |     +-- grantRoles (if grantRoles == true)
    |     |     _grantHubRoles()
    |     |       AaveV4HubRolesProcedure.grantHubAllRoles()         hubAdmin gets roles 101-103
    |     |       AaveV4HubRolesProcedure.grantHubRole()             HubConfigurator gets role 101
    |     |       AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorAllRoles()
    |     |                                                          hubConfiguratorAdmin gets role 200
    |     |     _grantSpokeRoles()
    |     |       AaveV4SpokeRolesProcedure.grantSpokeAllRoles()     spokeAdmin gets roles 301-302
    |     |       AaveV4SpokeRolesProcedure.grantSpokeRole()         SpokeConfigurator gets role 302
    |     |       AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorAllRoles()
    |     |                                                          spokeConfiguratorAdmin gets role 400
    |     |     AaveV4AccessManagerRolesProcedure.replaceDefaultAdminRole()
    |     |       grant role 0 to accessManagerAdmin, revoke from deployer
    |     |
    |     v
    |   FullDeploymentReport                        (all deployed addresses + salt)
    |
    vm.stopBroadcast()
    MetadataLogger.writeJsonReportMarket()          write JSON report
    logger.save()                                   save logs to output/reports/deployments/
```
