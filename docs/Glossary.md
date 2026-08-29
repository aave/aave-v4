# Glossary

Canonical terminology for Aave V4. Terms appear in alphabetical order.

---

**Base Drawn Rate:** Per-asset interest rate set at the Hub level, applied to all drawn debt for that asset. Determined by the Hub's interest rate strategy, based on current utilization. The symbol $R_{sbase,i}$ refers to the base drawn rate for asset $i$.

**Collateral Factor:** Maximum percentage of collateral value that can be borrowed against a collateral asset.

**Collateral Risk:** Additional risk parameter per asset, managed by the Governor. Introduces a charge on borrowers above the base drawn rate.

**Deficit:** Protocol accounting state in which a borrower has outstanding debt but no remaining collateral after a liquidation. Deficits are tracked per asset at the Hub level and reported per Spoke (the Spoke where the shortfall arose). Authorized active Spokes can eliminate a deficit on behalf of a specific other Spoke's reported deficit for that asset by deploying their supplied shares.

**Draw Cap:** Maximum amount a Spoke can draw from a Hub.

**Drawn Debt:** Base debt of a position, accruing interest at the base drawn rate.

**Dynamic Risk Configuration:** Combination of Risk Configuration parameters that allows different users to be subscribed to different configurations.

**Governor:** Entity authorized to manage Spokes and Hubs, set risk parameters, configure caps, and execute emergency controls. In the Aave V4 deployment, this is the Aave DAO.

**Health Factor (HF):** Ratio of a user's weighted collateral value (adjusted by Collateral Factor) to total outstanding debt value. When HF drops below `HEALTH_FACTOR_LIQUIDATION_THRESHOLD`, the position becomes eligible for liquidation.

**Hub:** Central store where all liquidity is held, accessed by attached Spokes. No collateralization is enforced on the Hub.

**Isolation Mode:** Configuration pattern that deploys a dedicated Spoke and Hub pair for a new or experimental asset with contained risk. This asset is the only allowed collateral asset. Borrowable assets are restricted by the `borrowable` flag on each Reserve; maximum borrow exposure is controlled per asset through `SpokeData.drawCap` at the Hub. Users can retain positions in other Spokes simultaneously using the same wallet.

**Liquidation Bonus:** Collateral surplus awarded to a liquidator above the base currency value of the debt repaid. In Aave V4, the bonus follows a Dutch-auction formula that interpolates linearly between a governance-set minimum at `HEALTH_FACTOR_LIQUIDATION_THRESHOLD` and the per-collateral `maxLiquidationBonus` at `healthFactorForMaxBonus`. The net bonus after the protocol fee equals the effective collateral surplus received by the liquidator.

**Liquidation Fee:** Protocol fee applied to the effective bonus portion of collateral seized during a liquidation. A fraction of the bonus collateral is transferred to the Hub fee receiver as shares via `Hub.payFeeShares`. Expressed in BPS as `liquidationFee` in `DynamicReserveConfig`.

**Position Manager:** Authorized entity allowed to manage a user position after the user has granted explicit permissions to do so.

**Premium Debt:** Extra debt of a position, corresponding to the user's collateral risk, determined by `premiumShares`, `premiumOffset`, and `realizedPremium`.

**Premium Offset:** In asset terms, the effective principal value at the time debt was taken, such that premium debt accrues only on interest earned on `premiumShares`.

**Premium Shares:** Effective shares on which the base drawn rate is applied to accrue interest. This helps account for the extra interest owed due to a user having riskier collateral.

**Realized Premium:** In asset terms, the completely non-interest-bearing portion of premium debt accumulated to date.

**Reinvestment Controller:** Authorized entity allowed to pull idle liquidity from the Hub to generate yield. Responsible for maintaining investment strategies, caps, and accounting for yield distribution to suppliers.

**Reserve:** Per-asset accounting unit within a Spoke. Each Reserve tracks supply and borrow state for a single asset, references its Hub via `Reserve.hub`, and carries configuration for collateral eligibility, borrowability, interest parameters, and liquidation settings.

**Risk Premium:** Weighted average of the Collateral Risk values of a user's collateral assets.

**Siloed Borrowing:** Configuration pattern in which a single asset is designated as the sole borrowable Reserve in a Spoke by setting `borrowable = false` on all other Reserves. Borrow exposure and any resulting risk are confined to the siloed asset's Hub; other Spokes and markets are not affected.

**Spoke:** Entity that can supply to and draw liquidity from the Hub.

**Supply Cap:** Maximum amount a Spoke can supply to the Hub.

**Target Health Factor:** The HF to which a borrower's position is restored after liquidation, set by the Governor at the Spoke level. Liquidators repay only the debt necessary to reach this value, replacing the fixed close-factor used in Aave V3.

**Tokenization Spoke:** Spoke variant that exposes only the supply side of the protocol via an ERC-4626 interface. Has no borrow surface and no risk premium calculation; positions through the TokenizationSpoke are supply-only.

**User Borrow Rate:** Effective borrow rate charged to an individual user, composed of the base rate from the asset's `drawnRate` and an additional Risk Premium.
