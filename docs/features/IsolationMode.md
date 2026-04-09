# Isolation Mode

## Summary

Isolation Mode enables new collateral assets to be added to the protocol with contained risk by registering them in a dedicated Spoke and Hub pair separate from the canonical market. Users who supply an isolated collateral asset in this Spoke can only borrow assets configured as borrowable for that market, up to per-asset draw caps set by the Governor. Because the isolated market lives in its own Spoke, users can continue to hold unrestricted positions in the Canonical Spoke and any other Spoke simultaneously.

Unlike Aave V3, which enforced a single aggregated borrow ceiling per isolated market and locked the borrower to one isolated collateral asset per account, Aave V4 assigns draw caps independently per asset and permits any number of assets to be configured as collateral within the isolated Spoke. The risk boundary is structural: it is scoped to the Spoke, not to the user's account.

## Relationship to the Hub/Spoke Architecture

Isolation Mode is not a contract-level primitive but a configuration pattern applied to a Spoke and its associated Hubs. Any Spoke becomes an isolated market when its Reserves are configured with a restricted borrowable set and the Hub enforces per-asset draw caps on that Spoke.

The enforcement point for the borrow ceiling is `SpokeData.drawCap` stored on the Hub, keyed by `(assetId, spoke)` so each asset has its own draw cap per Spoke. When a Spoke calls `Hub.draw`, the Hub checks that the Spoke's total owed (drawn plus premium), any reported deficit, and the requested draw amount would not exceed `drawCap`. A draw that would exceed the cap reverts with `DrawCapExceeded`. The cap is expressed in whole assets, not scaled by decimals, stored as `uint40` within `SpokeData`. A value of `MAX_ALLOWED_SPOKE_CAP` disables the ceiling.

Each Reserve on a Spoke references a specific Liquidity Hub through `Reserve.hub`. This means a single Spoke can draw liquidity from multiple Hubs, each subject to its own draw cap per asset. Draw caps are configured via `HubConfigurator.updateSpokeDrawCap` by governance-authorized roles (AccessManaged `restricted` access).

## Collateral and Borrow Configuration

The collateral set in an isolated market is defined by which Reserves on the Spoke carry a non-zero `collateralFactor` in their `DynamicReserveConfig`. A Reserve with `collateralFactor > 0` contributes to a user's health factor when the user has activated it as collateral via `setUsingAsCollateral`. Any number of Reserves can be configured this way within the isolated Spoke.

The borrowable set is controlled by the `borrowable` flag in `ReserveConfig`. Reserves with `borrowable = false` reject borrow requests; the Spoke reverts with `ReserveNotBorrowable`. The Governor designates borrowable assets by setting `borrowable = true` on selected Reserves.

A draw cap on the Hub supplements the `borrowable` flag. The `borrowable` flag gates access at the Spoke level; the draw cap enforces an absolute ceiling on how much the Spoke may draw from a given Hub asset. Both constraints must be satisfied for a borrow to succeed.

## Bootstrapping Liquidity

A new isolated market initially has no native liquidity. Without liquidity there are no borrowers, and without borrowers, suppliers earn no competitive rates. Aave V4 addresses this by allowing a Reserve in the isolated Spoke to reference the Canonical Hub rather than the new isolated Hub.

For instance, to bootstrap USDC liquidity, USDC from the Canonical Hub is listed as an additional Reserve (USDC') on the isolated Spoke with `Reserve.hub` pointing to the Canonical Hub. The Governor sets a draw cap on USDC' in the Canonical Hub, limiting total exposure of canonical USDC suppliers to the isolated market. Borrowers in the isolated Spoke draw USDC' from the Canonical Hub up to this cap.

Once the isolated Hub has accumulated sufficient native USDC liquidity, the Governor sets the draw cap for USDC' to zero. Existing USDC' borrow positions can still be repaid, but no new borrows are possible. Users then borrow USDC directly from the isolated Hub. At this point the credit line is wound down and the isolated market is self-sustaining.

## Out of Scope

The following are explicitly excluded from Isolation Mode as a configuration pattern:

- **Account-level enforcement**: Isolation Mode is a spoke-level pattern, not an account-level lock. The contracts do not prevent a user from holding positions in the isolated Spoke, the Canonical Spoke, or any other Spoke simultaneously.
- **Cross-Spoke health factor aggregation**: Collateral and debt in the isolated Spoke are accounted for independently. Health factors are not aggregated across Spokes.

## Key Differences from Aave V3

**Spoke-scoped isolation**: In Aave V3, Isolation Mode applies at the account level. A user who supplies an isolated collateral asset cannot use any other asset as collateral in that account. If non-isolated collateral is already active, the isolated asset cannot be added until it is removed. In Aave V4, Isolation Mode is spoke-scoped: the user is isolated within the isolated Spoke but can hold unrestricted positions in any other Spoke at the same time. This also means a single account can participate in multiple isolated markets simultaneously. For example, supplying collateral in one isolated Spoke while also borrowing against collateral in a separate isolated Spoke, with neither position affecting the other.

**Multiple isolated collaterals**: In Aave V3, only one isolated asset can serve as collateral per account. In Aave V4, any number of Reserves in the isolated Spoke can be configured with a non-zero `collateralFactor`, making them eligible as collateral simultaneously.

**Per-asset draw caps**: Aave V3 enforces a single aggregated borrow ceiling shared across all borrowable assets in the isolated market. A 10,000 USD cap shared among USDC, USDT, and GHO allows a single asset to consume the entire budget, blocking all others. Aave V4 assigns draw caps independently per asset: a 3,000 USDC draw cap, 3,000 USDT draw cap, and 4,000 GHO draw cap each enforce a distinct limit so no single asset crowds out the rest.

**Unrestricted borrowable assets**: In Aave V3, Isolation Mode restricts borrowing to a governance-approved list of stablecoins. In Aave V4, any asset can be marked `borrowable = true` in the isolated Spoke; the Governor defines the composition without a stablecoin-only constraint.

**Bootstrapped liquidity**: In Aave V3, an isolated market cannot draw liquidity from the canonical market. In Aave V4, a Reserve in the isolated Spoke can reference the Canonical Hub directly through `Reserve.hub` and draw from it under a draw cap, enabling the isolated market to operate while native liquidity grows.
