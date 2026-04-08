# TokenizationSpoke

## Summary

The TokenizationSpoke is a minimal ERC-4626–compliant contract that registers as a Spoke on an Aave V4 Hub, wrapping supply-only Hub positions into transferable ERC-20 shares. Its primary purpose is DeFi composability: the standard vault interface allows external protocols to interact with Aave V4 liquidity without custom adapters. The TokenizationSpoke does not implement borrowing or the full `ISpoke` interface. It is a pure supply tokenization primitive.

## Relationship to the Hub/Spoke Architecture

Standard Spokes in Aave V4 manage both supply and borrow flows, enforce collateralization constraints, manage reserve-level risk configuration, and support the full `ISpoke` interface including Position Manager delegation. The TokenizationSpoke operates at a narrower scope. It connects exclusively to the supply side of the Hub, calling `Hub.add` on supply and `Hub.remove` on withdrawal, and exposes no debt surface.

A TokenizationSpoke instance wraps exactly one underlying ERC-20 asset. Where a standard Spoke manages multiple Reserves, each TokenizationSpoke deployment is scoped to a single token. The Hub registers the TokenizationSpoke as a distinct Spoke address for that underlying, alongside any other Spokes for the same asset. Hub exposure is partitioned **per Spoke** via each Spoke’s own `addCap`, the same model used when several standard Spokes share an asset.

Because the TokenizationSpoke sits on the Hub's supply side without drawing debt, it does not participate in the risk premium system. Positions held through the TokenizationSpoke cannot be used as collateral and do not contribute to a user's health factor.

## ERC-4626 Interface

The TokenizationSpoke implements the ERC-4626 standard. User entry points include `deposit`, `mint`, `withdraw`, and `redeem` alongside the standard view functions: `totalAssets`, `convertToShares`, `convertToAssets`, `maxDeposit`, `maxMint`, `maxWithdraw`, and `maxRedeem`.

Unlike `Spoke.supply`, which restricts `onBehalfOf` to approved Position Managers, the ERC-4626 interface permits callers to specify any `receiver` on deposit and any `owner` on withdrawal, following standard allowance semantics. `withSig` and EIP-2612 permit operations are natively supported within the TokenizationSpoke, covering the majority of meta-transaction use cases without requiring external Position Manager approval flows.

**Deposit flow**

1. The caller approves the underlying ERC-20 asset to the TokenizationSpoke.
2. `deposit` transfers the input amount of underlying assets directly from the caller to the Hub via `safeTransferFrom`. The TokenizationSpoke calls `Hub.add` to account for the deposited amount against its position.
3. Shares are minted to `receiver`; ERC-4626 events are emitted.

**Mint flow**

1. The caller approves the underlying ERC-20 to the TokenizationSpoke.
2. `mint` computes the assets required for the requested shares, transfers underlying from the caller to the Hub via `safeTransferFrom`, and calls `Hub.add`.
3. Shares are minted to `receiver`; ERC-4626 events are emitted.

**Withdrawal flow**

1. `withdraw` takes the requested asset amount as input, computes the shares to burn, and burns those shares from `owner`.
2. The TokenizationSpoke calls `Hub.remove`.
3. The Hub transfers underlying directly to `receiver`.

**Redeem flow**

1. `redeem` takes the share amount to burn as input and burns those shares from `owner`.
2. The TokenizationSpoke calls `Hub.remove`.
3. The Hub transfers underlying directly to `receiver`.

All four entry points round in favor of the vault per ERC-4626 conventions: `deposit` rounds down shares minted, `mint` rounds up assets required, `withdraw` rounds up shares burned, and `redeem` rounds down assets returned. This asymmetry protects the vault from rounding-based value extraction.

## Share Price and Accounting

The TokenizationSpoke carries no fee logic at the vault layer. There are no performance fees, management fees, or protocol spreads applied by the contract itself. The share price (the ratio of `totalAssets` to total share supply) grows solely as a function of hub-level interest accrual on the underlying asset. As the Hub accrues yield for the TokenizationSpoke's position, `totalAssets` increases accordingly, and outstanding shares appreciate in underlying terms over time.

`totalAssets` converts the vault's total share supply to underlying via the Hub's exchange rate (`previewRemoveByShares`), denominated in the underlying asset's smallest unit. Caps (`addCap`, type `uint40`) are stored in whole asset units and scaled by `10^decimals` during validation.

## Cap Management and Deployment

The TokenizationSpoke does not get deployed through the standard Spoke factory. Each instance is deployed and registered on the Hub with governor-authorized `SpokeConfig` (including `addCap`), the same pattern as adding any Spoke via `HubConfigurator.addSpoke`.

The TVL ceiling for a TokenizationSpoke instance is controlled by the `addCap` field in `SpokeConfig` (type `uint40`). In practice it is commonly managed via governance-authorized calls to `HubConfigurator.updateSpokeAddCap`, but the source of truth is the Hub’s per-asset and per-spoke configuration (`Hub.updateSpokeConfig`). The cap is enforced by the Hub on every supply-add path (`deposit` and `mint`) when `Hub.add` is invoked. The Hub scales the configured cap to the asset’s decimals, values the Spoke’s existing position in underlying by converting its Hub shares (rounding up), adds the incoming amount, and reverts if that total would exceed the cap.

## Upgradeability

The TokenizationSpoke is deployed behind an upgradeable proxy. The current implementation uses `TransparentUpgradeableProxy` per instance (same as standard Spokes).

## Safety Controls

The TokenizationSpoke is governed by the same Hub-level emergency control states as standard Spokes (`halted` and `active`) which apply to deposits and withdrawals. Enforcement is layered: the TokenizationSpoke's `maxDeposit`/`maxWithdraw` view functions return zero when either flag is in its blocking state, and the Hub's `_validateAdd`/`_validateRemove` independently enforce the same checks, reverting onchain if violated. Both flags are governance-controlled and enforced per Spoke at Hub validation time.

## Out of Scope

The following are explicitly excluded from the TokenizationSpoke:

- **Borrowing**: No draw, repay, or collateralization logic. Positions through the TokenizationSpoke are supply-only.
- **Position Managers**: External Position Managers cannot be plugged in. `withSig` and permit cover the key meta-transaction use cases natively.
- **Fees**: No performance or management fees at the vault layer.
- **Multi-asset**: Each deployment handles exactly one underlying ERC-20.
- **Factory deployment**: Unlike standard Spokes, the TokenizationSpoke is not deployed through a Spoke factory. Each instance must be deployed and registered manually with `addCap` governance setup.
- **Rebalancing, strategies, or flashloans**: The contract has no strategy/rebalancing/flashloan logic. Its core state-changing interactions are with `Hub.add`/`Hub.remove`; aside from that, it only performs underlying-token transfer/permit calls required for vault flows.
- **Collateral use**: Shares held in a TokenizationSpoke cannot serve as collateral in any spoke configuration.

## Key Differences from Standard Spokes

**No debt surface**: Standard Spokes expose both `supply` and `borrow` paths. The TokenizationSpoke exposes only the supply side via ERC-4626. There is no `draw`, no `repay`, and no risk premium calculation.

**No Position Manager integration**: Standard Spokes restrict `onBehalfOf` operations to approved Position Managers. The TokenizationSpoke instead uses ERC-4626 `receiver`/`owner` semantics and natively supports `withSig` flows, reducing friction for integrators who do not need Position Manager delegation.

**Single asset per deployment**: A standard Spoke manages multiple Reserves across multiple assets. Each TokenizationSpoke instance corresponds to exactly one underlying ERC-20, making it a per-asset tokenization contract rather than a market-level entry point.
