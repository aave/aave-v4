<!-- SOURCE OF TRUTH for Aave V4 Avalanche configuration -->
<!-- Cloned from Outline: https://outline.llamarisk.com/s/76c5fca4-182b-4519-bf2a-859c699f6e1b -->
<!-- Title: Aave V4 Avalanche Parameters | Outline id: 1e20fd89-c647-4ac9-a28c-ccfcc2e483a5 | urlId: CviX1PyiIo -->
<!-- updatedAt: n/a -->

## Summary

LlamaRisk supports Aave V4 deployment to Avalanche. This document consolidates the hub-and-spoke architecture configuration, liquidation parameters, collateral factors, interest rate model settings, and Add Cap/Draw Cap recommendations. The deployment will launch with a single Core Hub and three specialized spokes. The Core Hub will serve as the primary liquidity venue, while each spoke is designed for a specific use case.

The initial configuration adopts a conservative approach to cumulative Add Caps, reflecting the relatively limited liquidity available on Avalanche. This is particularly important given that the same assets are already listed on the Aave V3 deployment, where they operate with substantially higher caps and share the same underlying liquidity. The objective is to launch with prudent risk parameters and gradually increase caps as market adoption grows and liquidity conditions improve.

## Market Design

The recommended launch configuration consists of one hub and three spokes. The Core Hub serves as the sole borrowing environment, structured around three spokes targeting a distinct collateral type, user intent, and risk profile:

![](https://llamarisk-outline-storage.nyc3.digitaloceanspaces.com/uploads/e016f71f-f6a8-426b-ae01-2385d0162630/c84eb94b-0c34-4c3b-a44d-5090df2053c7/image.png?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Content-Sha256=UNSIGNED-PAYLOAD&X-Amz-Credential=DO0037B6TFPQJHE2MVB8%2F20260616%2Fnyc3%2Fs3%2Faws4_request&X-Amz-Date=20260616T121808Z&X-Amz-Expires=3600&X-Amz-Signature=2bfc6d125e94d5528d6d49f3e6a158b88ea778fec6c140617e7db6ec9838f2c7&X-Amz-SignedHeaders=host&x-amz-checksum-mode=ENABLED&x-id=GetObject " =1280x785")

_Source: LlamaRisk_

- **Main Spoke:** The Main Spoke is the general-purpose lending venue and is expected to host the majority of liquidity within the deployment. It accepts the broadest collateral set and the broadest borrowable set in the deployment, where WAVAX, BTC.b, USDC, USDT, and WETH.e are collateral against which users can borrow stablecoins, WAVAX, BTC.b, and WETH.e. In the future, the Main Spoke can provide credit lines to specialized Hubs, such as an RWA Hub, allowing them to access its liquidity while preserving separate risk profiles.
- **AVAX Correlated Spoke:** This spoke is dedicated to the AVAX LST looping environment, with sAVAX as collateral and WAVAX as the only borrowable asset. This design isolates looping risk and allows spoke-specific add/draw caps.
- **Forex Spoke:** It supports trading and hedging across fiat-pegged stablecoins, with EURC, USDC, and USDT as collateral, which can be borrowed against each other. Due to limited secondary market liquidity for EURC, conservative caps have been set.

### Dynamic Liquidation Bonus Configuration

V4 introduces a dynamic liquidation bonus that increases linearly as the health factor decreases, in contrast to V3's static bonus. Two spoke-wide parameters shape the bonus curve. The `targetHealthFactor` is the HF to which a borrower is restored after liquidation; liquidators repay only enough debt to reach this value under normal circumstances. The `healthFactorForMaxBonus` is the HF at which the maximum liquidation bonus becomes active, with the bonus ramping linearly between HF of 1.0 and this value. The `liquidationBonusFactor` is a scaling parameter that controls both the steepness of the bonus ramp and, together with the target multiplier, the derived `maxLiquidationBonus`, ensuring that at an HF of 1.0, the liquidation bonus remains consistent with the corresponding V3 value.

For correlated-asset spokes (AVAX Correlated and Forex), `liquidationBonusFactor` is set to 1.0 because the health factor (HF) range between liquidation eligibility and bad debt is already narrow. Any reduction below this level would steepen the bonus curve and increase losses for leveraged correlated positions.

For volatile spokes (Main), `healthFactorForMaxBonus` is set to 0.9, ensuring that maximum liquidator incentives are active well before positions approach bad-debt levels. To maintain incentive continuity with V3, `maxLiquidationBonus` on the Main Spoke is set to 1.11 times its V3 value. This keeps the liquidation bonus at HF = 1.0 aligned with V3 while allowing higher incentives as positions deteriorate further.

| Chain     | Hub      | Spoke                 | Liquidation Bonus Factor | Target Health Factor | Health Factor For Max Bonus |
| --------- | -------- | --------------------- | ------------------------ | -------------------- | --------------------------- |
| Avalanche | Core Hub | Main Spoke            | 90.00%                   | 1.2400               | 0.90                        |
| Avalanche | Core Hub | AVAX Correlated Spoke | 100.00%                  | 1.0350               | 0.99                        |
| Avalanche | Core Hub | Forex Spoke           | 100.00%                  | 1.0442               | 0.99                        |

### V4 Spoke Parameters

The liquidation protocol fee is proposed to be set at 10% across all assets, aligning with the configuration used for the majority of assets on Aave V3.

| **Chain** | **Hub**  | **Spoke**             | **Reserve** | **Collateral Factor** | **Max Liquidation Bonus** | **Borrowable** | **Collateral Risk** | **Liquidation Fee** |
| --------- | -------- | --------------------- | ----------- | --------------------- | ------------------------- | -------------- | ------------------- | ------------------- |
| Avalanche | Core Hub | Main Spoke            | WAVAX       | 73.00%                | 10.00%                    | TRUE           | 0                   | 10.00%              |
| Avalanche | Core Hub | Main Spoke            | BTC.b       | 75.00%                | 7.22%                     | TRUE           | 0                   | 10.00%              |
| Avalanche | Core Hub | Main Spoke            | USDC        | 78.00%                | 5.55%                     | TRUE           | 0                   | 10.00%              |
| Avalanche | Core Hub | Main Spoke            | USDT        | 78.00%                | 5.55%                     | TRUE           | 0                   | 10.00%              |
| Avalanche | Core Hub | Main Spoke            | WETH.e      | 83.00%                | 5.55%                     | TRUE           | 0                   | 10.00%              |
| Avalanche | Core Hub | Main Spoke            | EURC        | 0.00%                 | -                         | TRUE           | -                   | -                   |
| Avalanche | Core Hub | AVAX Correlated Spoke | sAVAX       | 95.00%                | 1.00%                     | FALSE          | 0                   | 10.00%              |
| Avalanche | Core Hub | AVAX Correlated Spoke | WAVAX       | 0.00%                 | -                         | TRUE           | -                   | -                   |
| Avalanche | Core Hub | Forex Spoke           | EURC        | 90.00%                | 2.00%                     | TRUE           | 0                   | 10.00%              |
| Avalanche | Core Hub | Forex Spoke           | USDC        | 90.00%                | 2.00%                     | TRUE           | 0                   | 10.00%              |
| Avalanche | Core Hub | Forex Spoke           | USDT        | 90.00%                | 2.00%                     | TRUE           | 0                   | 10.00%              |

### Add and Draw Caps

Add and draw caps have been set, keeping in mind the limited liquidity available on Avalanche, with the specifications reflecting the hub-and-spoke structure of Aave V4 and the distinct risk profiles of each spoke.

| **Chain** | **Hub**  | **Spoke**             | **Reserve** | **Add Cap** | **Draw Cap** |
| --------- | -------- | --------------------- | ----------- | ----------- | ------------ |
| Avalanche | Core Hub | Main Spoke            | WAVAX       | 500,000     | 50,000       |
| Avalanche | Core Hub | Main Spoke            | BTC.b       | 100         | 10           |
| Avalanche | Core Hub | Main Spoke            | USDC        | 5,000,000   | 5,000,000    |
| Avalanche | Core Hub | Main Spoke            | USDT        | 5,000,000   | 5,000,000    |
| Avalanche | Core Hub | Main Spoke            | WETH.e      | 3,000       | 300          |
| Avalanche | Core Hub | Main Spoke            | EURC        | 500,000     | 400,000      |
| Avalanche | Core Hub | AVAX Correlated Spoke | sAVAX       | 200,000     | 0            |
| Avalanche | Core Hub | AVAX Correlated Spoke | WAVAX       | 0           | 250,000      |
| Avalanche | Core Hub | Forex Spoke           | EURC        | 300,000     | 400,000      |
| Avalanche | Core Hub | Forex Spoke           | USDC        | 200,000     | 150,000      |
| Avalanche | Core Hub | Forex Spoke           | USDT        | 200,000     | 150,000      |

### Interest Rate Curves

The IRM parameters apply to an asset across all spokes within that hub. The parameters follow the same two-slope utilization curve used in V3, defined by a base variable borrow rate, slope below the optimal usage ratio (Slope 1), slope above it (Slope 2), and the optimal usage ratio itself (Uoptimal). The Liquidity Fee is the fraction of borrower interest captured by the protocol treasury, equivalent to the reserve factor in V3. The goal of the initial configuration is to keep the setup as similar as possible to the one currently used in Aave V3.

| **Chain** | **Hub**  | **Reserve** | **Base** | **Slope 1** | **Slope 2** | **Uoptimal** | **Liquidity Fee** |
| --------- | -------- | ----------- | -------- | ----------- | ----------- | ------------ | ----------------- |
| Avalanche | Core Hub | WAVAX       | 1.00%    | 4.00%       | 144.28%     | 65.00%       | 20.00%            |
| Avalanche | Core Hub | BTC.b       | 0.00%    | 4.00%       | 80.00%      | 80.00%       | 25.00%            |
| Avalanche | Core Hub | USDC        | 0.00%    | 4.00%       | 10.00%      | 90.00%       | 10.00%            |
| Avalanche | Core Hub | USDT        | 0.00%    | 4.00%       | 10.00%      | 90.00%       | 10.00%            |
| Avalanche | Core Hub | WETH.e      | 0.00%    | 2.50%       | 8.00%       | 90.00%       | 15.00%            |
| Avalanche | Core Hub | EURC        | 0.00%    | 5.50%       | 50.00%      | 90.00%       | 10.00%            |

## **Disclosure**

This review was independently prepared by LlamaRisk, a DeFi risk service provider funded in part by the Aave DAO. LlamaRisk is not directly affiliated with the protocol(s) reviewed in this assessment and did not receive any compensation from the protocol(s) or their affiliated entities for this work.

The information provided should not be construed as legal, financial, tax, or professional advice.
