# Efficiency Mode

## Summary

Efficiency Mode (E-Mode) in Aave V3 lets users opt a position into a category of correlated assets (e.g., stablecoins, or ETH-correlated liquid staking tokens) that carries its own Loan-to-Value (LTV), Liquidation Threshold (LT), Liquidation Bonus, and restricted borrowable set, tuned tighter than the general market because the assets in the category have correlated price movements. Liquid E-Mode in Aave V3.2 extends this further by allowing a single asset to belong to multiple categories simultaneously, so the best available category can be selected per position rather than per asset.

Aave V4 has no dedicated E-Mode feature, account-level category flag, or category registry. The same functional outcome is achieved entirely through the existing Hub/Spoke architecture and the Dynamic Risk Configuration primitives described in [Isolation Mode](./IsolationMode.md) and [Dynamic Risk Configuration](./DynamicConfiguration.md): a category is simply a Spoke whose Reserves are configured with category-tailored `DynamicReserveConfig` parameters and a `borrowable` set restricted to the category's assets. Users select a category by choosing which Spoke they supply and borrow through, rather than by toggling a category identifier on their account.

## Relationship to the Hub/Spoke Architecture

Efficiency Mode, like Isolation Mode and Siloed Borrowing, is not a contract-level primitive but a configuration pattern layered on top of ordinary Spokes. A "category" is a Spoke listing Reserves for the correlated assets that belong to it (e.g., a Stablecoins Spoke listing USDC, USDT, and GHO), each configured with a `collateralFactor`, `maxLiquidationBonus`, and `liquidationFee` in `DynamicReserveConfig` that reflect the tighter risk profile justified by the assets' correlation, and each Reserve's `borrowable` flag restricted to the assets the Governor wants borrowable within that category.

Because `Reserve.hub` is set independently per Reserve, the same underlying Hub asset can be listed as a Reserve in the Canonical Spoke under standard parameters and, at the same time, as a Reserve in one or more category Spokes under category-specific parameters. Each Spoke tracks its own draw and add caps against the Hub via `SpokeData.drawCap`, so exposure through a category Spoke is accounted independently of exposure through the Canonical Spoke or any other category Spoke, even when they reference the same Hub asset.

## Category Configuration

Configuring a category Spoke uses the same primitives documented elsewhere, applied together:

- **Collateral and liquidation parameters**: Each Reserve's `collateralFactor`, `maxLiquidationBonus`, and `liquidationFee` are set via `addDynamicReserveConfig` / `updateDynamicReserveConfig`, the same Dynamic Risk Configuration mechanism used protocol-wide. A category Spoke simply uses values calibrated for the correlated asset set (e.g., a higher `collateralFactor` for stablecoin-against-stablecoin borrowing than the Canonical Spoke would allow) rather than a value specific to some separate "E-Mode" config type.
- **Borrowable restriction**: The Governor sets `borrowable = true` only on the Reserves meant to be borrowable within the category, using the same `borrowable` flag described in [Siloed Borrowing](./SiloedBorrowing.md) and [Isolation Mode](./IsolationMode.md). Attempting to borrow a Reserve with `borrowable = false` reverts with `ReserveNotBorrowable`.
- **Exposure ceilings**: Per-asset draw caps on the category Spoke, enforced at the Hub via `SpokeData.drawCap` and configured through `HubConfigurator.updateSpokeDrawCap`, bound how much of each borrowable asset the category can draw, independent of any cap the same asset carries in the Canonical Spoke or other category Spokes.

Aave V4 does not distinguish between a single Loan-to-Value and a separate Liquidation Threshold the way Aave V3 does. A single `collateralFactor` per Reserve per dynamic configuration key serves both roles; there is no separate LT field to configure for a category.

## Choosing a Category

Because the category boundary is a Spoke rather than an account flag, there is no explicit "enable E-Mode" call in Aave V4. A user's category is implicit in which Spoke their `supply` and `borrow` calls target: routing a transaction to a Stablecoins Spoke is functionally equivalent to activating the Stablecoins E-Mode category in Aave V3, and no separate opt-in transaction is required beyond the ordinary `supply`/`borrow` calls to that Spoke.

Because positions in different Spokes are independent (the same relationship documented in Isolation Mode and Siloed Borrowing), a single wallet can hold a position in a category Spoke and, at the same time, an entirely separate position in the Canonical Spoke or another category Spoke. This reproduces the effect of Liquid E-Mode, where an asset (and by extension a user's exposure to it) is not confined to a single category: rather than one asset carrying membership in several categories simultaneously, Aave V4 lists that asset as a Reserve in each Spoke whose parameters should apply to it, and the user picks the applicable parameter set by picking the Spoke. Before supplying or borrowing through a category Spoke, users should review that Spoke's Reserve list, collateral factors, and borrowable set, since these are configured independently per category and can differ meaningfully from the Canonical Spoke.

## Out of Scope

The following are explicitly excluded from Efficiency Mode as a configuration pattern:

- **Account-level category state**: There is no per-user category identifier, no enable/disable call, and no on-chain concept of a user being "in" a category. The pattern is realized entirely through which Spoke a position lives in.
- **Automatic single-category enforcement**: Nothing in the contracts prevents a user from holding positions in multiple category Spokes, or in a category Spoke and the Canonical Spoke, at the same time.
- **Cross-Spoke health factor aggregation**: Collateral and debt held through a category Spoke are evaluated independently of collateral and debt held in any other Spoke. There is no combined health factor across categories.
- **Dedicated E-Mode liquidation bonus mechanism**: Liquidations against category positions use the same Liquidation Engine as any other Spoke; only the `DynamicReserveConfig` parameters differ.

## Key Differences from Aave V3

**No dedicated category primitive**: Aave V3 tracks an explicit E-Mode category id per user and per asset, with dedicated storage and `setUserEMode` / category-admin entry points. Aave V4 has no equivalent state or function; the same outcome follows from ordinary Spoke and Dynamic Risk Configuration primitives that already exist for other purposes.

**Spoke-scoped vs. account-scoped selection**: In Aave V3, E-Mode is a flag on the user's account: activating a category restricts borrowing across the entire account to that category's assets, and only one category can be active at a time. In Aave V4, the "category" is a property of the Spoke, not the account. A wallet can simultaneously hold a position in one category Spoke and a different position in another category Spoke (or the Canonical Spoke), each independently accounted, with no single active category and no account-wide restriction.

**Single collateral factor vs. separate LTV/LT**: Aave V3 E-Mode categories configure a separate LTV and Liquidation Threshold. Aave V4's Dynamic Risk Configuration uses a single `collateralFactor` per Reserve per configuration key that serves both roles.

**Structural multi-category assets vs. liquid category membership**: Aave V3's Liquid E-Mode allows one asset to be declared a member of several categories, with the user's active category determining which parameter set applies. Aave V4 achieves the same flexibility structurally: the same underlying asset can be listed as a Reserve in several Spokes at once, each with independently configured parameters, and the user selects the applicable parameters by choosing which Spoke to use rather than by the asset declaring category membership.
