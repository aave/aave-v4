# Dynamic Risk Configuration

## Summary

Dynamic Risk Configuration is a spoke-level versioning mechanism (where each version is a snapshot of collateralization parameters) that isolates those parameters into per-Reserve configuration entries, each identified by a sequentially incrementing `dynamicConfigKey`. When governance updates collateralization parameters for a Reserve, the Spoke typically appends a new configuration entry rather than replacing the existing one (though governance can also update an existing key in place via `updateDynamicReserveConfig`). User positions retain a snapshot of the `dynamicConfigKey` active at the time of their last risk-bearing action. Parameter updates therefore do not immediately affect open positions; existing positions continue to evaluate under their snapshotted configuration until the user performs a risk-increasing action, at which point the Spoke rebinds the snapshot to the latest key. If the rebinding leaves the position under-collateralized, the action reverts.

The Governor retains the ability to force-migrate individual positions to the latest configuration via `updateUserDynamicConfig`. This mechanism is intended for emergency scenarios where extreme market conditions could negatively impact the protocol, allowing governance to proactively manage risk when waiting for natural user interactions is not viable.

## Relationship to the Hub/Spoke Architecture

Dynamic Risk Configuration is a spoke-level concern. The three parameters it encapsulates (Collateral Factor (CF), Liquidation Bonus (LB), and Liquidation Fee (LF)) govern how a user's collateral contributes to their health factor and how liquidation economics are computed. The Hub is unaware of these parameters; it maintains interest rate accounting, liquidity caps, and deficit state only. Spokes apply dynamic configurations independently: the same underlying asset registered on two different Spokes carries independent configuration histories and independent `dynamicConfigKey` counters.

The implementation spans three contracts in `src/spoke/`:

- `Spoke.sol`: exposes `addDynamicReserveConfig`, `updateDynamicReserveConfig`, and `updateUserDynamicConfig`, and implements all internal snapshot refresh logic.
- `SpokeStorage.sol`: declares the `_dynamicConfig` mapping and stores `_reserves` / `_userPositions` (whose `dynamicConfigKey` fields are defined in `ISpoke`).
- `SpokeConfigurator.sol`: provides access-controlled convenience functions for common parameter updates that delegate to the above entry points on the target Spoke.

## Configuration Data Model

The `DynamicReserveConfig` struct contains three fields:

| **Field**             | **Type** | **Description**                                                                                                             |
| --------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------- |
| `collateralFactor`    | `uint16` | Proportion of a Reserve's supplied value that counts toward a user's health factor, expressed in BPS.                       |
| `maxLiquidationBonus` | `uint32` | Maximum extra collateral the liquidator receives per unit of debt repaid, expressed in BPS. `100_00` represents a 0% bonus. |
| `liquidationFee`      | `uint16` | Protocol fee charged on liquidations, deducted from the collateral bonus before paying the liquidator, expressed in BPS.    |

The configuration history for each Reserve is stored in a nested mapping keyed first by `reserveId` and then by `dynamicConfigKey`:

```
mapping(uint256 reserveId => mapping(uint32 dynamicConfigKey => ISpoke.DynamicReserveConfig))
  internal _dynamicConfig;
```

Each `Reserve` struct holds a `dynamicConfigKey` field (type `uint32`) pointing to the most recently created configuration for that Reserve. Each `UserPosition` struct (one per user per reserve) holds a `dynamicConfigKey` field (type `uint32`) pointing to the configuration in use for that reserve when it is used as collateral. Health factor calculations for a user always use the configuration at the user position's snapshot key, not the Reserve's current key.

The maximum permitted `dynamicConfigKey` is `type(uint32).max` (approximately 4.29 billion entries per Reserve).

## Configuration Lifecycle

Configuration entries are created by appending a new key or updated by modifying an existing one. The two operations share most structural validation, but differ in one respect: `updateDynamicReserveConfig` disallows `collateralFactor = 0`, whereas `addDynamicReserveConfig` permits it (allowing a Reserve to be added as non-collateral from the start).

**Adding new configurations**

`addDynamicReserveConfig` creates a new configuration entry for a Reserve. The call increments the Reserve's `dynamicConfigKey` by one, stores the provided `DynamicReserveConfig` at that new key, advances the Reserve's `dynamicConfigKey` field to reference the new entry, and emits `AddDynamicReserveConfig`. New position snapshots created after this call bind to the new key.

Before storing, the Spoke validates three combined constraints under `InvalidCollateralFactorAndMaxLiquidationBonus`:

- `collateralFactor` must be strictly less than `100_00` BPS.
- `maxLiquidationBonus` must be greater than or equal to `100_00` BPS.
- `percentMulUp(maxLiquidationBonus, collateralFactor)` must be strictly less than `100_00` BPS.

The third constraint enforces that the liquidation penalty term derived from `maxLiquidationBonus` and `collateralFactor` remains strictly below 100%, which keeps downstream liquidation math well-defined. Additionally, `liquidationFee` must be at most `100_00` BPS; violations revert with `InvalidLiquidationFee`.

A new configuration with `collateralFactor = 0` is valid under these constraints. It is used to represent a Reserve being offboarded as collateral: users who enable the Reserve as collateral after the new configuration is created receive a zero collateral factor and therefore no collateral credit. Positions that already hold a snapshot at a prior key with a non-zero collateral factor are unaffected.

**Updating existing configurations**

`updateDynamicReserveConfig` modifies an existing configuration entry in place at a specified `dynamicConfigKey`. It applies the same structural validation as `addDynamicReserveConfig`, with two additional checks: the target key must reference a previously initialized entry, and the `collateralFactor` in the updated configuration must be strictly greater than zero.

The guard against setting `collateralFactor = 0` on a historical key is enforced in validation with `InvalidCollateralFactor`. If a historical key were altered to carry a zero collateral factor, all positions currently snapshotted at that key would lose collateral credit for that Reserve in health factor calculations. Additionally, liquidations read the borrower’s snapshotted dynamic configuration for the collateral reserve and require `collateralFactor > 0`; therefore that reserve could not be seized as liquidation collateral while bound to a zero-CF key. If it is the only collateral supporting outstanding debt, liquidation could be blocked until the key is updated back to `>0` or the position is migrated to a key with `collateralFactor > 0`.

Updating an uninitialized key reverts with `DynamicConfigKeyUninitialized`, detected by checking that the stored `maxLiquidationBonus` is nonzero (all valid stored configurations carry a `maxLiquidationBonus` of at least `100_00`).

> **Warning:** `updateDynamicReserveConfig` affects all open user positions currently snapshotted at the target key. Reducing `collateralFactor` on a historical key reduces effective collateral value for those positions and may bring them closer to the liquidation threshold. The Governor should model the impact on bound positions before executing such an update.

The `SpokeConfigurator` exposes convenience wrappers that read the current latest configuration, replace the specified field, and call the underlying add or update function:

- `addCollateralFactor` / `updateCollateralFactor`
- `addMaxLiquidationBonus` / `updateMaxLiquidationBonus`
- `addLiquidationFee` / `updateLiquidationFee`
- `addDynamicReserveConfig` / `updateDynamicReserveConfig` — full configuration passthrough

## User Position Snapshots

Each `UserPosition` stores a `dynamicConfigKey` field recording the configuration key currently bound to that user/reserve position for collateral evaluation. During health factor computation, the Spoke resolves the collateral factor for each Reserve from `_dynamicConfig[reserveId][userPosition.dynamicConfigKey].collateralFactor`. A collateral factor of zero causes the Reserve to contribute no value to the health factor regardless of the supplied amount.

Liquidations also use the user's snapshot key when determining the `maxLiquidationBonus` applicable to the collateral being seized. The liquidation bonus is therefore governed by the configuration active at the time of the user's last risk-bearing action, not the Reserve's current active configuration.

When a Reserve is first enabled as collateral via `setUsingAsCollateral`, the Spoke sets `userPosition.dynamicConfigKey = reserve.dynamicConfigKey` for that Reserve, binding the position to the then-current active configuration. Subsequent `addDynamicReserveConfig` calls advance the Reserve's key but leave the user position's snapshot unchanged until a refresh-triggering action occurs.

## Snapshot Refresh Rules

Whether a user action refreshes position snapshots depends on whether the action increases or decreases the risk the position poses to the protocol.

**Actions that refresh all collateral Reserve snapshots**

The following actions call `_refreshAndValidateUserAccountData`, which updates `userPosition.dynamicConfigKey` to `reserve.dynamicConfigKey` for every Reserve where the user has `usingAsCollateral` enabled, then recalculates and validates the health factor:

- `borrow`
- `withdraw` (only when the withdrawn Reserve has `usingAsCollateral` enabled)
- `setUsingAsCollateral` when disabling a Reserve as collateral
- `updateUserDynamicConfig`

On success, a `RefreshAllUserDynamicConfig` event is emitted. If the rebinding leaves the position under-collateralized, the call reverts with `HealthFactorBelowThreshold`, unwinding all state changes from the transaction.

**Actions that refresh a single Reserve's snapshot**

`setUsingAsCollateral` when enabling a Reserve as collateral calls `_refreshDynamicConfig`, which sets `userPosition.dynamicConfigKey = reserve.dynamicConfigKey` for the single Reserve being enabled and emits a `RefreshSingleUserDynamicConfig` event.

**Actions that do not refresh snapshots**

- `supply`
- `repay`
- `withdraw` (only when the withdrawn Reserve has `usingAsCollateral` disabled)
- `updateUserRiskPremium`
- `liquidationCall`

These actions evaluate health and risk using the user's existing snapshot keys. For `supply` and `repay`, the user's risk exposure decreases or stays neutral, so rebinding to latest configurations is not required. For `liquidationCall`, the liquidator acts on the position as-is; the health factor check uses the borrower's current snapshots.

## Health Factor Guard

When any action triggers a full snapshot refresh, the Spoke applies the following sequence atomically within the same transaction, before committing final state:

1. Iterate over all collateral Reserves in the position and set `userPosition.dynamicConfigKey = reserve.dynamicConfigKey` for each.
2. Recompute the health factor using the newly bound configurations.
3. If `healthFactor < HEALTH_FACTOR_LIQUIDATION_THRESHOLD`, revert with `HealthFactorBelowThreshold`.

This guard prevents a user from taking a risk-increasing action while pinned to a configuration that, after rebinding, would leave the position under-collateralized. The rebind is unconditional, but if the transaction reverts due to the health factor check, the user's position remains unchanged.

A position that is healthy under its current snapshot keys, but under-collateralized under the latest Reserve configuration is effectively blocked from further risk-increasing actions until the user either repays debt, adds collateral via `supply`, or the Governor adjusts the latest configuration to one under which the position remains solvent.

## Governance Intervention

`updateUserDynamicConfig` force-migrates a user position to the latest configuration for all collateral Reserves without requiring the user to perform a standard action. The function is callable by:

- The user themselves (`onBehalfOf == msg.sender`).
- An approved Position Manager for the user.
- An authorized admin role via the Spoke's access manager.

`updateUserDynamicConfig` runs the same full refresh and validation sequence as other risk-increasing actions: it rebinds all collateral snapshots to the current latest keys, validates health factor, updates the risk premium, and reverts with `HealthFactorBelowThreshold` if the migrated position is under-collateralized.

The expected governance workflow when introducing tightened parameters is:

1. Call `addDynamicReserveConfig` to publish the new configuration as the latest key for the Reserve. Existing positions retain their prior snapshot keys and are unaffected.
2. Call `updateUserDynamicConfig` on targeted positions to migrate them to the new parameters immediately.

> **Note:** `updateUserDynamicConfig` migrates the user to whatever key is current at call time. If `addDynamicReserveConfig` is called again after migration, the user will hold a snapshot at the intermediate key until their next risk-increasing action.

> **Note:** `updateUserDynamicConfig` updates all collateral Reserves in the position simultaneously. There is no function to migrate the snapshot for a single Reserve independently.

## Out of Scope

The following are explicitly excluded from the Dynamic Risk Configuration system:

- **Hub-level accounting**: CF, LB, and LF are not visible to the Hub. The Hub operates on share math, drawn indices, and liquidity caps only.
- **Per-Reserve snapshot migration**: `updateUserDynamicConfig` updates all collateral Reserves simultaneously. Individual Reserve snapshot updates are not exposed as a separate call.
- **Collateral Risk**: The risk premium parameter (`collateralRisk`) is stored in `ReserveConfig`, not in `DynamicReserveConfig`. It governs the risk premium interest component and is updated independently via `updateReserveConfig`. Dynamic configuration updates do not alter `collateralRisk`.
- **Liquidation execution logic**: Dynamic configurations supply the parameters used in the liquidation flow. The liquidation execution itself is documented separately.
- **Interest rate strategy**: Utilization-based borrow rates are a Hub-level concern and are unaffected by `DynamicReserveConfig`.
- **Cross-Spoke configuration sharing**: Each Spoke maintains its own `_dynamicConfig` mapping and independent key counters. Two Spokes connected to the same Hub asset do not share configuration history.

## Key Differences from Aave V3

**Single global configuration per asset**: In Aave V3, each asset carries exactly one risk configuration record. A governance update to Loan to Value, Liquidation Threshold, or Liquidation Bonus takes effect immediately for every open position borrowing against that asset. There is no mechanism to stage or scope the change to new positions only.

**Immediate liquidation exposure from parameter changes**: Because Aave V3 applies updates globally, reducing the Liquidation Threshold for a widely used asset can bring a large number of positions below the liquidation threshold simultaneously. Governance must either accept this risk or execute parameter changes in small increments across multiple proposals, increasing operational overhead.

**Aave V4 versioned configurations**: Aave V4 maintains a per-Reserve configuration history keyed by a monotonically incrementing `uint32`. Parameter updates create new entries; existing positions retain their snapshot keys until the user performs a risk-increasing action. This gives users the opportunity to adjust their positions before being subject to new parameters, and limits the immediate liquidation surface to positions that voluntarily take on new risk after the update is published.
