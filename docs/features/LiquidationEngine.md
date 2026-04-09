# Liquidation Engine

## Summary

The Liquidation Engine determines when and how under-collateralized positions are closed in Aave V4. It replaces the fixed close-factor logic of Aave V3 with a target-health-factor approach: liquidation sizing is target-health-factor-driven, but the final repaid amount is also constrained by `debtToCover`, dust-prevention adjustments, and collateral availability, preventing the over-liquidation inherent in Aave V3's 50% close factor. A Dutch-auction-style variable bonus incentivizes timely intervention by increasing linearly as the borrower's health factor falls. Dust-prevention logic, rounding rules designed to neutralize griefing, and a deficit-reporting path cover the edge cases that arise from rounding effects and partial liquidations.

The engine operates on both drawn debt (principal borrowed from the Hub) and premium debt (additional interest from the user's risk premium). It settles collateral to the liquidator either as underlying assets or, when `receiveSharesEnabled` is active and the liquidator opts in, as Hub-added shares.

## Relationship to the Hub/Spoke Architecture

Liquidation logic is implemented in `LiquidationLogic.sol`, an external library loaded by the Spoke. The Spoke exposes `liquidationCall` to callers; internally it reads the borrower's account data from Spoke storage, assembles a `LiquidateUserParams` struct, and delegates to `LiquidationLogic.liquidateUser`.

Within the library, execution can involve up to three Hub interactions, depending on path and amounts. Collateral settlement executes before debt settlement:

1. `Hub.remove` on the collateral Hub: when `receiveShares = false`, collateral is removed and transferred to the liquidator. When `receiveShares = true`, shares are credited directly to the liquidator's Spoke position without a `Hub.remove` call.
2. `Hub.payFeeShares` on the collateral Hub: if fee shares are non-zero, the protocol fee portion is transferred to the fee receiver as shares.
3. `Hub.restore` on the debt Hub: the liquidator's repayment is pulled via `safeTransferFrom` and credited, retiring drawn and premium shares.

Each Reserve references its own Hub through `Reserve.hub`, so the collateral and debt Reserves in a single liquidation can reference different Hubs. Spoke-wide liquidation parameters (`targetHealthFactor`, `healthFactorForMaxBonus`, `liquidationBonusFactor`) are stored in `LiquidationConfig`. Per-reserve parameters (`maxLiquidationBonus`, `liquidationFee`) are stored in `DynamicReserveConfig`, allowing different collateral assets within the same Spoke to carry different bonus ceilings and fee rates.

## Parameters and Configuration

Liquidation behavior is controlled by Spoke-wide parameters stored in `LiquidationConfig` and per-reserve parameters stored in `DynamicReserveConfig`.

| **Parameter**                | **Description**                                                                                                                                                                                                                                                                                                                                                                                                                                | **Constraints**                                                                                                                                                    |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `targetHealthFactor`         | Spoke-wide HF target (WAD) used to compute debt-to-target during liquidation. Actual post-liquidation HF can differ due to `debtToCover`, collateral exhaustion, dust-handling adjustments, and rounding effects.                                                                                                                                                                                                                              | Must be ≥ `HEALTH_FACTOR_LIQUIDATION_THRESHOLD`.                                                                                                                   |
| `DUST_LIQUIDATION_THRESHOLD` | Hard-coded threshold below which leftover debt or collateral qualifies as dust. Liquidation amounts are adjusted to avoid leaving dust on either side unless the opposite side is fully exhausted (including debt extension and collateral-exhaustion recomputation paths).                                                                                                                                                                    | Hard-coded constant set to `$1_000` in protocol value units.                                                                                                       |
| `maxLiquidationBonus`        | Per-collateral maximum bonus, expressed in BPS. A value of `105_00` means the liquidator receives collateral worth 5% more in base currency than the debt repaid.                                                                                                                                                                                                                                                                              | Must be ≥ `100_00`, and must satisfy the reserve-level solvency invariant with `collateralFactor` (`maxLiquidationBonus.percentMulUp(collateralFactor) < 100_00`). |
| `healthFactorForMaxBonus`    | Spoke-wide HF threshold below which the maximum bonus applies, expressed in WAD.                                                                                                                                                                                                                                                                                                                                                               | Must be < `HEALTH_FACTOR_LIQUIDATION_THRESHOLD`.                                                                                                                   |
| `liquidationBonusFactor`     | Spoke-wide percentage applied to the effective bonus (the part of `maxLiquidationBonus` above 100%) to compute the minimum bonus at `HEALTH_FACTOR_LIQUIDATION_THRESHOLD`. Formula: `minLB = (maxLB - 100%) × lbFactor + 100%`. Expressed in BPS.                                                                                                                                                                                              | Must be ≤ `100_00`.                                                                                                                                                |
| `liquidationFee`             | Per-collateral protocol fee expressed as a percentage of the effective bonus (the collateral bonus above 100%), in BPS. Fee shares are transferred to the Hub fee receiver via `Hub.payFeeShares`.                                                                                                                                                                                                                                             | Must be ≤ `100_00`.                                                                                                                                                |
| `receiveSharesEnabled`       | Per-reserve flag. When `true` and the Reserve is not frozen, liquidators can opt to receive collateral as Hub-added shares instead of underlying assets by passing `receiveShares = true` to `liquidationCall`.                                                                                                                                                                                                                                | `true` or `false`.                                                                                                                                                 |
| `riskPremiumThreshold`       | Per-Spoke, per-asset Hub parameter limiting the maximum ratio of premium shares to drawn shares a Spoke can hold, expressed in BPS. If configured too strictly, premium share increases that arise when safer collateral is liquidated can cause the post-liquidation `Hub.refreshPremium` call to revert with `InvalidPremiumChange`, reverting the liquidation transaction. A value of `MAX_RISK_PREMIUM_THRESHOLD` disables the constraint. | Configured via `HubConfigurator.updateSpokeRiskPremiumThreshold`.                                                                                                  |

## Eligibility and Validation

Any address can call `liquidationCall` on a Spoke to initiate a liquidation. Self-liquidation reverts with `SelfLiquidation`. Before computing amounts, the engine validates:

- `debtToCover` is non-zero; otherwise reverts with `InvalidDebtToCover`.
- Neither the collateral Reserve nor the debt Reserve is paused; violation reverts with `ReservePaused`. (Frozen Reserves, unlike paused ones, can be liquidated.)
- The borrower holds supply in the target collateral Reserve; otherwise reverts with `ReserveNotSupplied`.
- The borrower holds active drawn shares in the target debt Reserve; otherwise reverts with `ReserveNotBorrowed`.
- The borrower's health factor is strictly below `HEALTH_FACTOR_LIQUIDATION_THRESHOLD`; otherwise reverts with `HealthFactorNotBelowThreshold`.
- The collateral Reserve has `collateralFactor > 0` and the borrower has `usingAsCollateral` enabled for it; otherwise reverts with `ReserveNotEnabledAsCollateral`.
- If the liquidator passes `receiveShares = true`, the collateral Reserve must not be frozen and must have `receiveSharesEnabled = true`; otherwise reverts with `CannotReceiveShares`.

Frozen Reserves can be liquidated, but cannot be received as shares (see `receiveShares` validation). Paused Reserves in the borrower's position that are not the specific collateral or debt target being liquidated do not block the call.

## Liquidation Process

A liquidation executes in six sequential steps.

1. **Compute account data**: The Spoke calculates the borrower's health factor, total debt value (RAY-scaled), total collateral value (counting Reserves with `collateralFactor > 0`, `usingAsCollateral` enabled, and `suppliedShares > 0`), and the counts of active collateral and borrow Reserves.

2. **Compute debt to liquidate**: The engine determines how much debt must be repaid to restore the borrower to `targetHealthFactor`, using the following formula derived from the health factor definition and the liquidation bonus:

$$l = \frac{D \cdot (THF - HF)}{THF - lb \cdot cf}$$

- $l$ is the debt to liquidate in base currency
- $D$ is the user's total debt value in base currency
- $THF$ is `targetHealthFactor`
- $HF$ is the borrower's health factor before liquidation
- $lb$ is the liquidation bonus from the Dutch-auction formula
- $cf$ is the collateral factor of the collateral being seized

3. **Adjust for dust**: If the debt remaining after a standard liquidation falls below `DUST_LIQUIDATION_THRESHOLD`, the engine extends `maxDebtToLiquidate` to cover the full debt position in the target Reserve. The liquidator's `debtToCover` input must be large enough to cover the extended amount; otherwise the transaction reverts with `MustNotLeaveDust`. Debt dust may still remain if the collateral Reserve is fully exhausted before the debt is fully covered.

4. **Compute collateral to seize**: The debt to liquidate is converted into collateral units at the current oracle price and scaled by the liquidation bonus. If the computed collateral exceeds available supply, all remaining collateral is seized and debt-to-liquidate is recomputed downward from available collateral. Separately, if remaining collateral would fall below `DUST_LIQUIDATION_THRESHOLD` and drawn shares would remain in the target debt Reserve after liquidation, all collateral is seized and debt-to-liquidate is increased to fully consume the collateral (potentially bypassing the target health factor). The liquidator's `debtToCover` must be large enough to cover this increased amount; otherwise the transaction reverts with `MustNotLeaveDust`.

5. **Settle collateral and repay debt**: Collateral shares are deducted from the borrower. The net collateral goes to the liquidator via `Hub.remove` (underlying assets) or is credited directly as added shares in the liquidator's Spoke position (`receiveShares = true` path). Fee shares (the `liquidationFee` fraction of the effective bonus) are sent to the fee receiver via `Hub.payFeeShares`. Finally, the liquidator's repayment is pulled via `safeTransferFrom` to the debt Hub, which credits the position via `Hub.restore`.

6. **Evaluate deficit**: The engine calls `_evaluateDeficit` after execution. If the collateral position is fully emptied, it was the borrower's only active collateral, and debt still remains in any Reserve, the Spoke invokes `notifyReportDeficit`. This iterates all remaining debt Reserves, calls `Hub.reportDeficit` for each, zeroes drawn and premium shares, and resets the borrower's risk premium to zero. A `ReportDeficit` event is emitted per Reserve and `UpdateUserRiskPremium` is emitted with value zero.

## Dutch-Auction Style Liquidation Bonus

The liquidation bonus varies linearly with the borrower's health factor. Once a position becomes liquidatable, the minimum bonus is:

$$minLB = (maxLB - 100\%) \times lbFactor + 100\%$$

- $maxLB$ is `maxLiquidationBonus` for the collateral Reserve, as a ratio (e.g., 1.05 for `105_00`)
- $lbFactor$ is `liquidationBonusFactor` for the Spoke, as a ratio (e.g., 0.80 for `80_00`)

For a liquidatable position, the bonus is:

$$lb = \begin{cases} maxLB & \text{if } HF \le hfForMaxBonus \\ minLB + (maxLB - minLB) \times \dfrac{HF\_LIQ - HF}{HF\_LIQ - hfForMaxBonus} & \text{if } HF > hfForMaxBonus \end{cases}$$

- $HF\_LIQ$ is `HEALTH_FACTOR_LIQUIDATION_THRESHOLD` (equals 1)
- $hfForMaxBonus$ is `healthFactorForMaxBonus`

**Example 1:** `maxLiquidationBonus = 105_00`, `liquidationBonusFactor = 80_00`, `healthFactorForMaxBonus = 0.85e18`. At `HF = 0.95` (between the liquidation threshold and the max-bonus boundary):

$minLB = (1.05 - 1.00) \times 0.80 + 1.00 = 1.04$

$lb = 1.04 + (1.05 - 1.04) \times \frac{1.00 - 0.95}{1.00 - 0.85} = 1.04 + 0.01 \times \frac{1}{3} \approx 1.0433$

**Example 2:** At `HF = 0.80 ≤ 0.85`, the liquidator earns the full `maxLiquidationBonus = 105_00`, a 5% collateral surplus over the debt repaid in base currency.

**Protocol fee**: `liquidationFee` is applied to the effective bonus only, not to the full collateral seized. A `liquidationFee = 10_00` with a 5% effective bonus yields a 0.5% protocol fee, giving the liquidator a net 4.5% collateral bonus.

## Preventing Liquidation Splits

The variable bonus creates an incentive risk: if a partial liquidation lowers the borrower's health factor, a liquidator could split a single liquidation into multiple smaller calls, obtaining a higher bonus on each subsequent call. This increases the probability of bad debt and harms the borrower.

A partial liquidation decreases health factor when $lb_k \times cf_k > HF_{beforeLiq}$, where $lb_k$ is the bonus and $cf_k$ is the collateral factor for the collateral seized. It increases or preserves health factor when $lb_k \times cf_k \le HF_{beforeLiq}$.

The Dutch-auction interpolation region is $HF > hfForMaxBonus$. In that region, $lb_k \le maxLB_k$ (strictly `<` unless `liquidationBonusFactor = 100_00`, where `minLB = maxLB` and the bonus is flat). If the Governor enforces:

$$maxLB_i \times cf_i \le hfForMaxBonus, \quad \forall i$$

then whenever the Dutch-auction interpolation region applies ($HF > hfForMaxBonus$), it holds that $lb_k \times cf_k \le hfForMaxBonus < HF_{beforeLiq}$, guaranteeing health factor improvement after every liquidation. When $HF \le hfForMaxBonus$, the full $maxLB_k$ applies uniformly regardless of health factor, so there is no incremental incentive to split. Under this condition, liquidation splits are never profitable.

The Governor must verify this condition for every collateral across all active `DynamicReserveConfig` keys. Because `hfForMaxBonus` is spoke-wide while `maxLiquidationBonus` and `collateralFactor` are per-reserve and per-config-key, changes to any of these values must be validated against the condition before they are applied.

## Dust and Rounding

Dust prevention and rounding direction are enforced independently within the liquidation flow.

**Dust prevention**: The engine prevents leaving sub-threshold dust on either side unless the opposite side is fully exhausted. If remaining debt would be dust, liquidation is extended to full debt; if remaining collateral would be dust, liquidation is adjusted to fully consume collateral (or otherwise satisfy dust constraints). Calls that do not provide enough `debtToCover` for these dust-safe bounds revert with `MustNotLeaveDust`. Dust can still remain on one side when the other side is fully exhausted.

**Rounding direction**: The engine rounds against the liquidator at every step to prevent value extraction via repeated small liquidations:

- **Collateral rounds down**: collateral shares are computed from debt-to-liquidate using floor division, giving the liquidator slightly fewer collateral units.
- **Debt rounds up**: drawn shares are derived from debt-to-liquidate by dividing by the drawn index with ceiling division (`divUp`); the corresponding debt amount used in validation is computed with rounding-up multiplication (`rayMulUp`). Both round against the liquidator.

This asymmetry means very small positions (a few cents in value) may become unprofitable to liquidate even at zero gas cost. A cleanup liquidator mechanism should be considered for such positions.

**Zero-collateral liquidations**: Because collateral is computed from debt-to-liquidate using floor division, it is possible for a liquidation to repay a non-zero amount of debt yet yield zero collateral shares. This does not cause a revert regardless of whether `receiveShares` is `true` or `false`: the `Hub.remove` path transfers zero underlying, and the share-credit path adds zero shares to the liquidator's position. The liquidator pays for debt repayment and receives nothing in return. This can occur with very small debt amounts where the debt-to-collateral conversion rounds down to zero.

**Two-wei premium effect and rounding asymmetry**: Premium accounting updates during `Hub.restore` can leave up to two wei of instantaneous premium debt due to premium-share/premium-offset rounding. Additionally, the systematic rounding asymmetry (collateral rounds down against liquidator, debt rounds up against liquidator) causes post-liquidation HF to typically exceed `targetHealthFactor` slightly rather than equaling it. HF remains below target when the computed debt-to-target cannot be fully achieved due to liquidation bounds (for example insufficient `debtToCover`, collateral exhaustion, or target debt-reserve exhaustion). Dust-prevention overrides can move post-liquidation HF further away from the exact target and may worsen it when `lb * cf > HF_before`.

## Premium Debt in Liquidations

Both drawn debt and premium debt are settled in a single atomic operation. Premium debt is liquidated first: the engine computes `premiumDebtRayToLiquidate` and subtracts it from the borrower's premium obligation before reducing drawn shares.

If the liquidated collateral was lower-risk than the collateral remaining in the position, the borrower's effective risk premium increases after the liquidation, causing premium shares on the Hub to rise. If `riskPremiumThreshold` is set below the post-liquidation premium-to-drawn ratio, the post-liquidation `Hub.refreshPremium` call reverts with `InvalidPremiumChange`, causing the liquidation transaction to revert. The Governor must set `riskPremiumThreshold` with sufficient headroom to accommodate the premium increases that naturally arise when safer collateral is partially liquidated while riskier collateral remains.

## Deficit Reporting and Elimination

Deficit arises when a liquidation fully exhausts the borrower's last active collateral Reserve and debt remains. The Spoke reports it to the Hub; any authorized active Spoke can eliminate it.

**Deficit condition**: After liquidating the target collateral Reserve and repaying the target debt, the engine evaluates deficit via `_evaluateDeficit`. Deficit is signaled when the collateral position is fully emptied, `activeCollateralCount` was 1 (it was the borrower's only active collateral), and debt remains in at least one Reserve (the target debt Reserve or any other).

**Reporting**: `notifyReportDeficit` iterates all of the borrower's remaining debt Reserves, calls `Hub.reportDeficit` for each outstanding debt position, applies the corresponding premium delta to clear premium accounting, zeroes drawn and premium shares, and clears the borrow flag per Reserve. The borrower's risk premium is reset to zero. Deficit reporting proceeds even when the Spoke is halted, as long as it remains active.

**Griefing via dust collateral**: Deficit is only triggered when `activeCollateralCount == 1` and the target collateral position is fully emptied. A borrower can prevent deficit reporting by maintaining a dust supply in a second collateral Reserve, keeping `activeCollateralCount > 1`. This blocks protocol recovery from bad debt. Possible mitigations include enforcing minimum collateral thresholds or extending deficit logic to treat collateral below a value threshold (e.g. `DUST_LIQUIDATION_THRESHOLD`) as inactive for deficit evaluation.

**Elimination**: Any authorized active Spoke can call `Hub.eliminateDeficit` to use its own added shares to cover another Spoke's reported deficit for a given asset. The calling Spoke must hold sufficient added shares. Deficit elimination is permitted even when the eliminating Spoke is halted.

## Out of Scope

The following are explicitly excluded from the Liquidation Engine:

- **Cross-Spoke liquidations**: Each `liquidationCall` operates entirely within a single Spoke. A borrower's positions in other Spokes are not affected and cannot be targeted in the same call.
- **Multi-reserve batch liquidation**: A single `liquidationCall` targets exactly one collateral Reserve and one debt Reserve. Liquidating multiple debt or collateral Reserves requires separate calls.
- **Flash-loan integration**: The Liquidation Engine provides no native flash-loan or callback mechanism for liquidators. External flash-loan providers operate independently.

## Key Differences from Aave V3

**Target Health Factor vs. Close Factor**: In Aave V3, the default close factor is 50%, rising to 100% when the borrower's HF falls below 0.95 or the position falls below a base currency threshold. Aave V4 removes the default close factor entirely: liquidation sizing is target-health-factor-driven, but the final repaid amount is also constrained by `debtToCover`, dust-prevention adjustments, and collateral availability, preventing the systematic over-liquidation of Aave V3 while maintaining protocol safety.

**Variable Liquidation Bonus**: Aave V3 applies a static per-reserve bonus regardless of health factor. Aave V4 introduces the Dutch-auction bonus: it varies linearly with health factor. When HF ≤ `healthFactorForMaxBonus`, the liquidator receives the maximum bonus. When HF is between `healthFactorForMaxBonus` and `HEALTH_FACTOR_LIQUIDATION_THRESHOLD`, the bonus interpolates linearly from maximum to minimum. Lower health factors earn higher bonuses, incentivizing faster intervention as a position deteriorates.

**Dynamic Dust Handling**: Aave V3 reverts when remaining collateral or debt falls below a dust threshold with no cleanup path. Aave V4 dynamically extends the maximum liquidatable amounts to prevent both debt and collateral dust, while dust may still remain on either Reserve when the counterpart Reserve is fully exhausted first.

**Share-based Collateral Settlement**: Aave V3 always transfers underlying assets to liquidators. Aave V4 introduces the `receiveShares` path: when `receiveSharesEnabled` is true and the Reserve is not frozen, liquidators can receive Hub-added shares directly, accruing yield without an asset transfer. This enables capital-efficient liquidation in low-liquidity environments.

**Premium Debt Settlement**: Aave V3 liquidations operate solely on principal drawn debt. Aave V4 liquidations simultaneously settle drawn debt and the associated premium debt, repaying the premium obligation atomically alongside the principal.
