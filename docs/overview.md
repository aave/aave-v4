# Untitled

# Overview

Aave V4 introduces an architectural redesign centered around the Liquidity Hub, enabling protocol flexibility and efficiency. This innovative architecture allows the Governor (e.g. the Aave DAO) to dynamically manage Spokes, adding new borrowing capabilities and removing outdated ones without requiring costly liquidity migrations.

The protocol implements sophisticated risk management through its Liquidity Premiums system, where each asset receives a dynamic risk factor (called collateral risk) ranging from 0.00 to 1000.00 (BPS) based on asset's implied volatility, market conditions, liquidity, risk, etc. This granular pricing mechanism introduces base rates for high-quality collaterals (such as ETH) while adjusting borrowing costs proportionally to risk profiles.

By providing preferential rates for stronger collaterals and optimizing capital efficiency, Aave V4 creates a more robust lending environment that accurately prices risk and rewards. Consequently, attracting higher-quality collateral while offering improved yields for suppliers and lower fees for borrowers utilizing safer assets.

# Liquidity Hub and Spokes

Aave V4 introduces a hub-and-spoke model for liquidity management. The Liquidity Hub (LH) coordinates liquidity, while Spokes handle asset-specific lending and borrowing.

[DIAGRAM]

Spokes are individual modules that can connect to one or multiple LHs. They route user actions (supply/withdraw and borrow/repay) to the appropriate LH based on reserve configuration and available caps. Whenever liquidity is restored, Spokes pay a base interest (determined by an interest rate strategy at the LH level) and a risk premium that determines how much borrowers will pay on top of the base rate, depending on the collateral composition of each user.

A LH can have an unspecified number of Spokes, each one contributing to the total outstanding debt and to the interest generated. The LH manages the basic accounting (total liquidity vs available), the interest rates, the draw and supply caps, among others.

## Liquidity Hub (LH)

The LH is immutable and serves as the central coordinator for liquidity management in Aave V4. The design allows for multiple LHs to exist, with each LH maintaining oversight of its own set of Spokes. Each LH sets the supply/borrow caps for its Spokes and enforces crucial accounting invariants. The design objective is to make the LH as simple as possible.

The key aspects of the LH include

- Maintaining a registry of authorized Spokes for each supported asset.
- Setting liquidity caps to limit Spoke drawing.
- Enforcing accounting invariants:
  - Total borrowed assets <= total supplied assets
  - Total borrowed shares <= total minted shares
  - LH assets <= sum of Spoke assets (converted from shares)

## Spokes

The Spokes are upgradeable and the primary components responsible for facilitating lending and borrowing functionalities for specific assets within the Aave V4 ecosystem. They can register into LHs and are allowed to draw (borrow) liquidity from them. The nature of the spoke is not specific and can be anything, crypto based, RWA based, DEX LPs based, and so on.

Users interact with the Spokes, which interact directly with the LHs, managing the following aspects:

- Handling lending and borrowing functionality.
- Managing user data structures and configurations.
- Providing emergency stop functionality to halt operations, if needed.
- Utilizing share-based accounting internally to optimize gas costs and ensure assets remain within designated caps as interest accrues.
- Having a distinct `reserveId` in each Spoke, different from the `assetId` in the LH, to allow for Spoke-specific configurations.
- Managing Oracle interactions.

# Risk Premium

Interest paid as a result of a user's debt is directly impacted by the quality of the assets used as collateral. Likewise, risk level (quality) of the collateral assets of the user determines the additional charge for borrowing, on top of the asset's drawn interest rate.

[DIAGRAM]

## Premium

### Collateral Risk

The collateral risk $CR_i$ is specified by the asset’s quality, which is a BPS number, ranging from 0_00 to 1000_00. A value of 0% means highest quality and risk free, while a value of 1000% signifies the lowest quality and maximum risk possible within the system.

This parameter is configurable and part of the Spoke's risk parameters. This means the same asset can have a different collateral risk value across Spokes.

$CR_i$ is the collateral risk of the asset $i$

> 💡 This parameter is only a factor if an asset is utilized as collateral.

### User Risk Premium

The user risk premium $RP_u$ represents the quality of assets used as collateral to borrow against. It depends on multiple dynamic parameters:

- Collateral amount ($C_{u, i}$): Liquidity supplied as collateral, monotonically increasing due to interest it generates if borrowed.
- Asset price ($P_i$): Prices are continuously fluctuating, with some assets being less volatile than others.
- Collateral Risk ($CR_i$): Risk parameter configured and updated on a regular basis by the Governor.

Ideally, the user risk premium would be updated continuously to reflect its dynamic nature, ensuring it is always up-to-date and aligned with the last state of the user’s position. However, this is technically infeasible because of the limitations of EVM blockchains, requiring constant updates by means of onchain transactions. Instead, the user risk premium is updated only when the user performs certain actions which affect collateralization (withdraw, borrow, repay); or an update is permissionlessly triggered (updateUserRiskPremium) by the same user, a position manager or governance, when it is beneficial for a given user position. If the user remains inactive, their user risk premium remains constant. Exceptionally the Governor retains the ability to forcibly update the user risk premium of a given user to match the most recent risk parameters of its collateral assets, even in the absence of user interaction. This is particularly relevant in scenarios where a specific user position has accumulated additional risk between interactions.

$RP_u$ is the risk premium of the user $u$

### Risk Premium Algorithm

The algorithm used to calculate it for a given user position follows these steps, with the purpose of first finding the collateral assets and its corresponding amounts which are sufficient to cover the position's debts, in base currency. The weighted average of the Collateral Risk of these collateral assets is then calculated to yield the User Risk Premium:

1. **Sort collateral assets by Collateral Risk (ascending):** Sort collateral assets by Collateral Risk in ascending order of risk value, from least risky (lowest collateral risk) to the most risky (highest collateral risk).
2. **Calculate total debt:** Calculate the user’s total debt value (interest included) in base currency (`totalDebt`).
3. **Iterate over collateral assets** to calculate the total amount of collateral asset sufficient to cover the total debt of the user position, utilizing an auxiliary variable `coveredDebt` which is initialized to `0`:

   a. Compute `remainingDebt = totalDebt – coveredDebt`.

   b. If `remainingDebt` ≤ current collateral asset's supplied amount in base currency: use only that portion of collateral and break.

   c. If `remainingDebt` > current asset’s value: include the asset fully, add it to `coveredDebt`, continue.

4. **Compute weighted average of collateral risk** for the included collateral assets and its amounts.

**Formula** to calculate the weighted average of collateral assets value:

$RP_u = f(CR_i, C_{u, i}, P_i) = \frac{\sum_{i=1}^n CR_iC_{u, i}P_i}{\sum_{i=1}^nC_{u, i}P_i}$

- ${CR}_i$ is the collateral risk of the asset $i$
- $C_{u, i}$ is the amount of asset $i$ supplied as collateral by the user $u$, which sufficiently covers the users debt, as specified in the above algorithm
- $P_i$ is the price of asset $i$

**Example 1:** the value of the first collateral asset matches the value of the user’s total debt:

$RP_u = f(CR_0, C_{u,0}, P_0) = CR_0$

**Example 2:** the total value of the first and second collateral assets matches the user’s total debt.

$RP_u = f(CR_i, C_{u, i}, P_i) = \frac{CR_0C_{u,0}P_0 + CR_1C_{u,1}P_1}{C_{u,0}P_0+C_{u,1}P_1}$

### Premium Offset

Operationally, the premium is accounted for by assigning additional (virtual) debt shares (premium debt shares) that exist solely to increase interest accrual and are not repayable principal. To separate this premium component from principal interest, we track a premium offset. Premium drawn shares are recorded in shares units, while the premium offset is tracked in asset units. A user’s accrued premium debt at any time equals the assets value of their premium drawn shares minus the premium offset. On user actions, this accrued amount is moved to a realized‑premium variable and both the premium drawn shares and premium offset are reset, since a user’s risk premium may change and the accounting must be recalibrated.

# Interest Accrual

Interest on every borrow position is split into two concurrent streams: **drawn debt** accrues at the hub’s Drawn Rate $R_{s,i}$, reflecting utilization of Hub liquidity, while a separate **premium debt** stream accrues at the incremental rate $R_{sbase,i}RP_u$, where $RP_u$ is the user-specific risk premium derived from the quality mix of their collateral.

$D_{u,i}$ is the debt of a user $u$ for asset $i$

$D_{u,i} = D_{u,ibase} + D_{u,premium}$

- $D_{u,ibase}$ is the base debt of a user $u$ for the asset $i$
- $D_{u,premium}$ is the premium debt of a user $u$

The sum of these gives the expected total interest accumulation such that the user’s debt $D_{u,i}$ grows at rate $R_{u,i}$. This separation is purely internal and separate from the user’s perspective, they simply see their total owed amount increase at the higher rate $R_{u,i}$.

## Base Debt

Base Debt refers to the core portion of a user’s outstanding borrow position that is tied to the actual liquidity drawn from the Liquidity Hub. When a user in Spoke $s$ borrows an asset $i$, the system records this borrowed amount as the user’s base debt.

$D_{u,ibase}$ is the borrowed amount of asset $i$ by a user $u$

This represents the principal liquidity provided by the Liquidity Hub’s reserve to the Spoke on the user’s behalf. At the moment of borrowing, the user’s base debt equals the amount borrowed.

Over time, the base debt accrues interest at the hub’s base borrow rate strategy $R_{sbase,i}$, in accordance with the interest rate strategy for that Spoke. This means that as time progresses, the accrued base interest is added to the user’s base debt, increasing the amount the user owes to the protocol’s liquidity providers for that particular asset.

$D_{u,i} = D_{u,ibase} + R_{sbase,i}D_{u,ibase}$

$R_{sbase,i}D_{u,ibase} = ΔD_{u,ibase}$

## Premium Debt

Premium Debt is the portion of a user’s debt that represents the additional interest accumulated due to the quality of user’s collateral assets (i.e. their risk premium on top of the base rate).

$D_{u,premium}$ is a running total of the extra interest accrued on user u

Unlike base debt, premium debt does not originate from an actual asset withdrawal from the LiquidityHub; instead, it is a bookkeeping entry that tracks how much extra the user owes because of the user risk premium.

$D_{u,premium}= D_{u,premium} + R_{sbase,i}RP_uD_{u,ibase}$

$R_{sbase,i}RP_uD_{u,ibase} = ΔD_{u,premium}$

# Dynamic Risk Configuration

One of the major risk‑side limitations of V3 lies in its single, global risk configuration per asset. This design creates significant governance overhead and potential user harm through unexpected liquidations, as any parameter change, in particular lowering the liquidation threshold, immediately affects every open position.

V4 makes it possible for multiple risk configurations to exist side‑by‑side. Whenever governance adjusts collateralization parameters (currently the Collateral Factor (CF) or Liquidation Bonus (LB), the protocol adds a new configuration instead of replacing the old one. Earlier configurations continue to govern positions opened under them while updated parameters apply to new positions. In special cases defined by governance, existing positions may be modified.

Every time governance adjusts the Collateral Factor (CF) or Liquidation Bonus (LB), it corresponds to a new configuration. These configurations are stored in a bounded dictionary of up to 65k entries (2^16) identified by incremental keys, with each reserve holding the key that points to the current active configuration.

Each user position also stores the key corresponding to the active configuration when that position became risk-bearing. This key is refreshed whenever the user performs specific actions, and may continue to reference a prior configuration when there are changes on the dynamic risk configuration between user interactions.

## Governance Impact

Risk‑Config IDs allow parameter updates without affecting existing open positions. Governance retains the ability to update parameters of old keys. However, during normal operations the system updates upon user interaction without requiring governance intervention.

## Design

Dynamic configuration extends the reserve model with a per‑reserve mapping that holds every historic configuration, referenced by a `configKey`. Collateralization parameters now reside inside the dynamic mapping rather than the static reserve record; for the moment this set comprises the CF and the LB.

Each reserve stores the latest configKey, which represents the current up-to-date risk configuration. In contrast, every user position retains a snapshot of the active configKey corresponding to the configuration in effect at the time of its last risk-increasing event. This snapshot is refreshed across all assets of a user position only when the user performs an action which elevates the risk posed to the system, by disabling an asset as collateral, withdrawing, or borrowing. When a user designates a new asset as collateral, only the configKey snapshot of the asset in play is refreshed.

### Automatic Rebinding and Hard Safety Guard

When a user attempts a health‑decreasing action, the engine checks the latest configuration for each collateral in the position. If the position remains sustainable under this configuration, the engine rebinds the snapshot to this latest key and allows the action to proceed. However, if the latest configuration would leave the position under‑collateralised, the engine blocks the action.

### Feature Notes

The architecture of dynamic configuration comes with several practical constraints and behaviors that integrators and governance should note. The points that follow detail some of those mechanics.

1. The `configKey` is currently defined as a `uint16`(65k max active configurations).
2. If the system exceeds the maximum number of configurations, the key space wraps and the earliest configuration is overwritten, which can impact users bound to that configuration. Although unlikely given the large available capacity, this behavior is expected and desired.
3. For a given user position, the snapshot updates to the latest key on:
   1. `disableUsingAsCollateral`
   2. `enableUsingAsCollateral` refreshes only the configKey snapshot for the asset in play.
   3. `borrow`
   4. `withdraw`
4. The snapshot does **not** update on actions that reduce risk exposure of the system:
   1. `supply`
   2. `repay`
   3. `liquidationCall` as liquidations will always improve the health of a user position
   4. `updateRiskPremium`
5. Dynamic Risk Configurations can be adjusted by governance utilizing the following methods:
   1. `addDynamicReserveConfig` creates a new risk configuration and increments the latest configKey. User positions created or subsequently updated bind to this latest configKey.
   2. `updateDynamicReserveConfig` updates a prior configuration, affecting existing positions bound to that configKey.
6. Users can refresh their Dynamic Risk Configuration:
   1. `updateUserDynamicConfig` updates their snapshots to the latest configKey for all collateral reserves

# Liquidation Engine

Aave V4 introduces a redesigned liquidation mechanism that replaces the fixed close‑factor logic used in V3. Instead of always seizing a fixed percentage of a user’s debt and collateral, V4 allows liquidators to repay just enough debt and seize just enough collateral to bring the borrower’s health factor (HF) back to a configurable Target Health Factor (`TargetHealthFactor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD`). The mechanism includes safeguards against “dust” debt and collateral, adopts a dutch‑auction‑style variable liquidation bonus, while ensuring that liquidations do not result in remaining dust collateral or debt unless the respective corresponding debt or collateral reserves are fully liquidated. These changes aim to improve user experience and reduce the chance of protocol‑level bad debt.

## Key Differences from Aave v3

- **Target Health Factor vs Close Factor:** In V3, the default close factor is 50 % (with a 100% close factor when HF < 0.95). Liquidators would always repay half of a borrower’s debt and seize half of their collateral. V4 removes the default close‑factor: a liquidator only repays the debt required to bring the borrower back to the Target Health Factor determined by governance.
- **Dynamic Dust Debt Handling**: To avoid dust collateral or debt in user positions, V3 reverts when the remaining amount is below a hard‑coded threshold. V4 instead dynamically adjusts the maximum debt that can be liquidated (`maxDebtToLiquidate`) and, if the liquidator opts to fully repay, allows full repayment to prevent dust. Dust may still remain if either the collateral or debt reserve is fully liquidated.
- **Dutch‑Auction Style Liquidation Bonus:** V3 applies a static liquidation bonus that does not depend on the borrower’s health factor. V4 introduces a variable liquidation bonus that increases linearly as the health factor decreases. Governance can specify two spoke‑wide parameters that shape the bonus curve: `healthFactorForMaxBonus` and `liquidationBonusFactor`.

## Parameters and Configuration

Aave V4 exposes several configurable parameters that influence liquidation:

| **Parameter** **Description** **Constraints** |                                                                                                                                                                                                                                                                                                |                                                                    |
| --------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| `TargetHealthFactor`                          | A spoke‑wide value set by governance representing the HF to which a borrower should be restored after liquidation. Liquidators repay only enough debt to reach this HF under normal circumstances that do not result in dust collateral or debt remaining.                                     | Must be ≥ the `HEALTH_FACTOR_LIQUIDATION_THRESHOLD` constant.      |
| `DUST_LIQUIDATION_THRESHOLD`                  | Hard‑coded threshold used to prevent extremely small leftover debt. The maximum debt that can be liquidated is increased to ensure that debt or collateral dust less than this threshold does not remain unless the corresponding respective collateral or debt reserve is fully liquidated.   | Hard‑coded constant set to 1000 USD in base units.                 |
| `maxLiquidationBonus`                         | Per reserve defined maximum liquidation bonus for a collateral, expressed in basis points (BPS). A value of 105.00 (105%) means there is 5% extra seized collateral over the amount of debt repaid in base currency.                                                                           | Must be ≥ 100 00.                                                  |
| `healthFactorForMaxBonus`                     | Spoke‑wide value expressed in WAD units defining the HF below which the max bonus applies. It must be less than or equal to `HEALTH_FACTOR_LIQUIDATION_THRESHOLD` to avoid division‑by‑zero.                                                                                                   | `healthFactorForMaxBonus` < `HEALTH_FACTOR_LIQUIDATION_THRESHOLD`. |
| `liquidationBonusFactor`                      | Spoke‑wide percentage (expressed in BPS) specifying the fraction of the max bonus earned at the threshold `HEALTH_FACTOR_LIQUIDATION_THRESHOLD`. It defines the minimum bonus; e.g., a factor of 80.00 yields a bonus equal to 80 % of the max bonus when HF equals the liquidation threshold. | liquidationBonusFactor must be <= 100 00                           |

## Liquidation Process in V4

The following high‑level steps outline the V4 liquidation flow:

1. **Check Eligibility:** When a borrower’s HF drops below the `HEALTH_FACTOR_LIQUIDATION_THRESHOLD`, anyone can trigger a liquidation; however, accounts are not allowed to liquidate their own positions. The protocol retrieves the borrower’s total debt value, current HF, and total collateral value, counting only reserves with `usingAsCollateral` enabled, CF > 0, and the reserve not paused; freezing is allowed.
2. **Determine Debt to Repay:** Based on the Target Health Factor `TargetHealthFactor`, the protocol computes the debt that must be repaid to restore the borrower’s HF to `TargetHealthFactor`. The required repayment amount depends on the borrower’s current debt and collateral (CF, LB, HF).
3. **Handle Dust Debt:** If the borrower’s remaining debt after a standard liquidation would be below the `DUST_LIQUIDATION_THRESHOLD`, and the liquidator intends to fully repay the debt, the protocol increases the allowable debt that can be liquidated. So that the entire debt can be covered. However, dust may still remain if the liquidator targets debt equal to the full amount of the collateral reserve $C_i$ being seized (i.e., $Δ C_i = C_i$), then a residual debt $D_{dust} > 0$ can remain when there are multiple collateral reserves ($N_{coll} > 1$); if there is a single collateral reserve ($N_{coll} = 1$), the residual is recorded as a protocol deficit.
4. **Calculate Collateral to Seize**: Convert the debt to be repaid into the collateral asset’s value and apply the liquidation bonus for this specific liquidation. By this point the bonus is fixed (not variable during execution) based on the position’s HF at the start of liquidation and the reserve’s `maxLiquidationBonus`. The formula in this step just computes that liquidation bonus and the resulting collateral to transfer. If the chosen collateral is not sufficient, all of that collateral is seized and the repaid debt is recomputed; per V4 rules, collateral dust may remain.
5. **Apply Debt Repayment & Transfer Collateral**: Reduce the borrower’s debt amount by the repaid amount. Transfer the corresponding collateral to the liquidator with the liquidation bonus applied, minus the protocol fee (as in V3). The fee portion is sent to the protocol/fee receiver via the Hub as shares, accrues yield there, and the shares are assigned directly via Hub accounting.
6. **Emit Events and Update State:** A `LiquidationCall` event is emitted containing details of the liquidation. The borrower’s and reserve’s interest indices are updated. If the borrower still has debt outstanding and no remaining collateral, the system will record a protocol deficit.

## Dust and Rounding Considerations

V4 introduces a dynamic dust prevention mechanism. If the debt remaining after a standard liquidation is below the `DUST_LIQUIDATION_THRESHOLD` (e.g., $1 000 in base currency), the protocol increases the maximum debt that can be liquidated to allow full repayment, provided the liquidator has indicated intent to fully cover the debt; otherwise, the liquidation reverts under the dust condition. Dust may still remain on either the collateral reserve or debt reserve if the corresponding debt or collateral reserve, respectively, is fully exhausted.

Due to rounding effects and the creation of negligible interest premiums during liquidations, the borrower’s final health factor after liquidation may not exactly match the `TargetHealthFactor`. In rare cases the final HF may be slightly above or below the target.

A deficit is only reported if, after liquidation, the borrower has no more collateral left across any of his reserves and debt still remains.

## Dutch‑Auction Style Liquidation Bonus

The liquidation bonus in V4 varies linearly between a minimum and maximum value based on the borrower’s health factor:

- **Max‑bonus region**: When HF ≤ `healthFactorForMaxBonus`, the liquidator earns the maximum bonus (`maxLiquidationBonus`) minus a portion (`liquidationFee`) that is taken as protocol fees. Example: if `maxLiquidationBonus = 105%` and `liquidationFee = 10%`, the gross bonus is 5% of the repaid debt; 10% of that bonus is taken as fees, so the liquidator receives a net 4.5% collateral bonus (both in base currency).
- **Threshold region:** At HF = `HEALTH_FACTOR_LIQUIDATION_THRESHOLD`, the bonus equals `liquidationBonusFactor × maxLiquidationBonus`. This ensures that even the safest possible liquidation (just below the threshold) still yields a non‑zero bonus.
- **Linear interpolation:** For HF between `healthFactorForMaxBonus` and the liquidation threshold, the bonus increases linearly from `liquidationBonusFactor × maxLiquidationBonus` to `maxLiquidationBonus`.

The lower the HF of a position becomes, the larger the bonus the liquidators receive.

Once a user becomes liquidatable, the protocol offers a minimum liquidation bonus equal to

$$ minLB = (maxLB - 100\%) \times lbFactor + 100\% $$

where

- $maxLB$: per collateral. Represents the maximum liquidation bonus that can be awarded. Must be greater than 100%. For example, 103% means a 3% effective liquidation bonus.
- $lbFactor$: per collateral. Represents the minimum percentage of the effective liquidation bonus that can be awarded. Must be at most 100%. For example, 50% while $maxLB = 103\%$ means $minLB = 101.5\%$.

As a user’s health factor decreases, the protocol increases the liquidation bonus it offers to liquidators. For a liquidatable user, the liquidation bonus is

$$
lb = \begin{cases}
maxLB & \text{if } hf_{beforeLiq} \le hfForMaxBonus \\
minLB + (maxLB - minLB) \times \frac{HF\_LIQ\_THRESHOLD - hf_{beforeLiq}}{HF\_LIQ\_THRESHOLD - hfForMaxBonus} & \text{if } hf_{beforeLiq} > hfForMaxBonus
\end{cases}
$$

where

- $HF\_LIQ\_THRESHOLD$: per spoke. Represents the health factor threshold under which the user becomes liquidatable. Equals 1.
- $hf_{beforeLiq}$: per user. Represents the user’s health factor before liquidation. Exact formula detailed below.
- $hfForMaxBonus$: per spoke. Represents the health factor threshold under which the protocol awards the maximum liquidation bonus.
