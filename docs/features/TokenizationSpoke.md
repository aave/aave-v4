# TokenizationSpoke

## Summary

The TokenizationSpoke is a minimal ERC-4626–compliant contract that registers as a Spoke on an Aave V4 Hub, wrapping supply-only Hub positions into transferable ERC-20 shares. Its primary purpose is DeFi composability: the standard vault interface allows external protocols to interact with Aave V4 liquidity without custom adapters. The TokenizationSpoke does not implement borrowing or the full `ISpoke` and `ISpokeBase` interface. It is a pure supply tokenization primitive.

## Relationship to the Hub/Spoke Architecture

Standard Spokes in Aave V4 manage both supply and borrow flows, enforce collateralization constraints, apply risk premium accounting, and support the full `ISpoke` and `ISpokeBase` interface including PositionManager delegation. The TokenizationSpoke operates at a narrower scope. It connects exclusively to the supply side of the Hub, calling `Hub.add` on deposit and `Hub.remove` on withdrawal, and exposes no debt surface.

A TokenizationSpoke instance wraps exactly one underlying ERC-20 asset. Where a standard Spoke manages multiple reserves, each TokenizationSpoke deployment is scoped to a single token. The Hub registers the TokenizationSpoke as a distinct entity from any co-existing standard Spoke for the same underlying asset. This means Hub exposure to a given asset can be partitioned across standard Spokes and one or more TokenizationSpoke instances, each governed by independently configured add caps.

Because the TokenizationSpoke sits on the Hub's supply side without drawing debt, it does not participate in the risk premium system. Positions held through the TokenizationSpoke cannot be used as collateral and do not contribute to a user's health factor.

## ERC-4626 Interface

The TokenizationSpoke implements the ERC-4626 standard. Entry points include `deposit`, `mint`, `withdraw`, and `redeem`, alongside the standard view surface: `totalAssets`, `convertToShares`, `convertToAssets`, `maxDeposit`, `maxMint`, `maxWithdraw`, and `maxRedeem`.

Unlike `Spoke.supply`, which restricts `onBehalfOf` to approved PositionManagers, the ERC-4626 interface permits callers to specify any `receiver` on deposit and any `owner` on withdrawal, following standard allowance semantics. `withSig` and EIP-2612 permit operations are natively supported within the TokenizationSpoke, covering the majority of meta-transaction use cases without requiring external PositionManager approval flows.

**Deposit flow**

1. The caller approves the underlying ERC-20 to the TokenizationSpoke.
2. `deposit` transfers underlying directly from the caller to the Hub via `safeTransferFrom`.
3. The TokenizationSpoke calls `Hub.add` to account for the deposited amount against its position.
4. Shares are minted to `receiver`; ERC-4626 events are emitted.

**Withdrawal flow**

1. `withdraw` burns the corresponding shares from `owner`.
2. The TokenizationSpoke calls `Hub.remove`.
3. Underlying is transferred to `receiver`.

All four entry points round in favor of the vault per ERC-4626 conventions: `deposit` rounds down shares minted, `mint` rounds up assets required, `withdraw` rounds up shares burned, and `redeem` rounds down assets returned. This asymmetry protects the vault from rounding-based value extraction.

## Share Price and Accounting

The TokenizationSpoke carries no fee logic at the vault layer. There are no performance fees, management fees, or protocol spreads applied by the contract itself. The share price (the ratio of `totalAssets` to total share supply) drifts solely as a function of Hub-level interest accrual on the underlying asset. As the Hub accrues yield for the TokenizationSpoke's registered position, the balance attributable to that position increases, and `totalAssets` reflects this, causing outstanding shares to appreciate in underlying terms over time.

`totalAssets` converts the vault's total share supply to underlying via the Hub's exchange rate (`previewRemoveByShares`), denominated in the underlying asset's smallest unit. Caps (`addCap`, type `uint40`) are stored in whole asset units and scaled by `10^decimals` during enforcement.

## Cap Management and Deployment

The TokenizationSpoke does not deploy through the standard Spoke factory. Because it registers directly on the Hub and requires governor-authorized `addCap` configuration, each instance must be deployed and registered manually. This is a deliberate constraint: the Hub's cap accounting for a TokenizationSpoke instance is independent from the add cap of any standard Spoke for the same underlying asset. Risk managers must allocate add cap budget across both entities separately when configuring exposure limits for a given token.

The TVL ceiling for a TokenizationSpoke instance is controlled by the `addCap` field in `SpokeConfig` (type `uint40`). In practice it is commonly managed via governance-authorized calls to `HubConfigurator.updateSpokeSupplyCap`, but the source of truth is the Hub’s per-asset and per-spoke configuration (`Hub.updateSpokeConfig`). The cap is enforced by the Hub on every supply-add path (`deposit` and `mint`) when `Hub.add` is invoked: `addCap × 10^decimals ≥ toAddedAssetsUp(spoke.addedShares) + amount` must hold or the transaction reverts. The left-hand side is the decimal-scaled cap; the right-hand side is the spoke's existing position (converted from Hub shares rounding up) plus the incoming assets.

## Upgradeability

The TokenizationSpoke deploys behind an upgradeable proxy. The current implementation uses `TransparentUpgradeableProxy` per instance (same as standard Spokes).

## Safety Controls

The TokenizationSpoke supports the same emergency control states as standard Spokes: `halted` and `active` are both checked for deposits and withdrawals. Enforcement is layered: the TokenizationSpoke's `maxDeposit`/`maxWithdraw` view functions return zero when either flag is in its blocking state, and the Hub's `_validateAdd`/`_validateRemove` independently enforce the same checks, reverting on-chain if violated. Both flags are governance-controlled and enforced per spoke at Hub validation time.

## Out of Scope

The following are explicitly excluded from the TokenizationSpoke:

- **Borrowing**: No draw, repay, or collateralization logic. Positions through the TokenizationSpoke are supply-only.
- **PositionManagers**: External PositionManagers cannot be plugged in. `withSig` and permit cover the key meta-transaction use cases natively.
- **Fees**: No performance or management fees at the vault layer.
- **Multi-asset**: Each deployment handles exactly one underlying ERC-20.
- **Factory deployment**: Must be deployed and registered manually with `addCap` governance setup.
- **Rebalancing, strategies, or flashloans**: The contract has no strategy/rebalancing/flashloan logic. Its core state-changing interactions are with `Hub.add`/`Hub.remove`; aside from that, it only performs underlying-token transfer/permit calls required for vault flows.
- **Collateral use**: Shares held in a TokenizationSpoke cannot serve as collateral in any Spoke configuration.

## Key Differences from Standard Spokes

**No debt surface**: Standard Spokes expose both `supply` and `borrow` paths. The TokenizationSpoke exposes only the supply side via ERC-4626. There is no `draw`, no `repay`, and no risk premium calculation.

**No PositionManager integration**: Standard Spokes restrict `onBehalfOf` operations to approved PositionManagers. The TokenizationSpoke instead uses ERC-4626 `receiver`/`owner` semantics and natively supports `withSig` flows, reducing friction for integrators who do not need PositionManager delegation.

**Single asset per deployment**: A standard Spoke manages multiple reserves across multiple assets. Each TokenizationSpoke instance corresponds to exactly one underlying ERC-20, making it a per-asset tokenization contract rather than a market-level entry point.

**Independent cap accounting**: The Hub treats the TokenizationSpoke as a distinct entity from any standard Spoke for the same asset. Add cap must be allocated to the TokenizationSpoke independently; it does not inherit or share cap budget from a co-existing standard Spoke.
