# Siloed Borrowing

## Summary

Siloed Borrowing constrains a Spoke so that only one designated asset is effectively borrowable, confining volatility or liquidity risk of that asset to the siloed market alone. A common configuration is exactly one Reserve with `borrowable = true` and all others with `borrowable = false`; alternatively, non-target Reserves can be made effectively non-borrowable via a zero `drawCap` on their `(assetId, spoke)` Hub config. Multiple collateral assets can be supplied through the Spoke, but a user's active collateral set is still bounded by `MAX_USER_RESERVES_LIMIT` when enabling Reserves via `setUsingAsCollateral`. Borrow exposure is limited to the siloed asset subject to its draw cap on the Hub.

Because the constraint is spoke-level rather than account-level, a single wallet can hold siloed borrow positions in multiple siloed Spokes simultaneously, each confined to its own asset, while also maintaining non-siloed positions in other Spokes. Collateral and debt in each Spoke remain fully segregated.

## Relationship to the Hub/Spoke Architecture

Siloed Borrowing is a reserve-level configuration. Each Reserve carries a `borrowable` boolean in `ReserveConfig`. When `borrowable = false`, any borrow attempt against that Reserve reverts with `ReserveNotBorrowable`. Configuring all Reserves except one to `borrowable = false` makes that one Reserve the sole drawable asset in the Spoke without requiring any additional contract logic.

Each Reserve in `ISpoke.Reserve` carries a `hub` field of type `IHubBase`, specifying which Hub the Spoke interacts with for that Reserve. Supply and borrow flows use the same `hub` field: `reserve.hub.add` is called on supply and `reserve.hub.draw` on borrow, so each Reserve references exactly one Hub for both operations.

The draw ceiling is enforced at the Hub level by `SpokeData.drawCap`. When the siloed Spoke calls `Hub.draw`, the Hub verifies that the sum of the Spoke's drawn amount, accrued premium, reported deficit, and the new draw amount does not exceed `drawCap`. Violation reverts with `DrawCapExceeded`. The cap is expressed in whole assets (not scaled by decimals), stored as `uint40`, and managed via `HubConfigurator.updateSpokeDrawCap`. Setting `drawCap` to `MAX_ALLOWED_SPOKE_CAP` removes the ceiling.

## Collateral Configuration

Multiple collateral assets can be supplied through the siloed Spoke. Each collateral Reserve references its own Hub via `Reserve.hub`: Reserve A may route supply to the Canonical LH, Reserve B to a second LH, and the siloed Reserve C also to the second LH. The siloed constraint applies exclusively to borrowing; supply routing is unrestricted across Reserves, while collateral activation per user remains subject to `MAX_USER_RESERVES_LIMIT`.

A user can call `setUsingAsCollateral` on any Reserve, but the asset only contributes to the health factor when its `collateralFactor` in `DynamicReserveConfig` is greater than zero. If `collateralFactor` is zero, the flag is set without effect: the position is not counted as collateral. Health factor calculations on the siloed Spoke use only the collateral held in that Spoke. Collateral in the Canonical Spoke or any other Spoke does not contribute to health factor in the siloed Spoke.

## Risk Confinement

The primary purpose of Siloed Borrowing is to prevent a newly listed asset from creating bad debt that harms suppliers of unrelated assets. Without siloing, a user could borrow both USDC and a new stablecoin XYZ in the same account. If XYZ's oracle price is manipulated upward, the resulting under-collateralization triggers liquidation. The liquidator seizes collateral to repay XYZ debt, but the remaining USDC debt may lack sufficient collateral, creating bad debt borne by USDC suppliers.

Siloed Borrowing eliminates this contagion path. Because XYZ is the only borrowable asset in its Spoke, any shortfall from a manipulated XYZ price is confined to the XYZ Spoke's Hub. USDC suppliers in the Canonical Spoke carry no exposure to the XYZ market. The Governor controls maximum exposure through the draw cap on the siloed asset, and can safely list new stablecoins or experimental assets in dedicated siloed Spokes without affecting established markets.

## Out of Scope

The following are explicitly excluded from Siloed Borrowing as a configuration pattern:

- **Cross-Spoke health factor aggregation**: Collateral and debt in one Spoke do not contribute to health factor calculations in another Spoke. Each Spoke maintains independent accounting.
- **Automatic account-level siloing**: The contracts do not prevent a user from opening borrow positions in both a siloed Spoke and the Canonical Spoke. Isolation is structural (per Spoke), not enforced at the wallet level.
- **Liquidation cross-contamination**: A liquidation event in one siloed Spoke does not affect positions in other Spokes or in the Canonical Spoke.

## Key Differences from Aave V3

**Account-level vs. Spoke-level siloing**: In Aave V3, `siloedBorrowing` is a reserve configuration, and enforcement is account-level at borrow time: if an account has debt in a siloed asset, it cannot borrow a different asset; if an account already has non-siloed debt, it cannot start borrowing a siloed asset. In Aave V4, the constraint is spoke-level: the siloed Spoke enforces single-asset borrowing, but the same wallet maintains full flexibility in the Canonical Spoke and other Spokes.

**Multiple simultaneous siloed positions**: In Aave V3, a single account can hold at most one siloed borrow position at any time. In Aave V4, a single wallet can hold siloed borrow positions in multiple siloed Spokes simultaneously, each confined to its own asset and Hub.

**Per-asset draw caps**: In Aave V3, Siloed Borrowing does not introduce its own dedicated siloed exposure ceiling; however, borrowing can still be constrained by the reserve-level `borrowCap`. (A debt ceiling also exists in Aave V3, but it belongs to Isolation Mode, a separate feature.) In Aave V4, each `(assetId, spoke)` path applies a Hub-level `SpokeData.drawCap`. For example, an exposure cap of 5,000 on a new stablecoin XYZ is implemented by creating a Spoke where XYZ is the sole borrowable Reserve and setting its draw cap to 5,000. Other Spokes and their caps remain unaffected.

**Scalable market-level listings**: Because each siloed Spoke isolates risk to a single asset and Hub, governance can list new stablecoins and experimental assets in dedicated siloed Spokes without exposing existing markets to their volatility or liquidity risk. Aave V3 also configures siloed borrowing at market/reserve level; it does not require governance intervention per user account.
