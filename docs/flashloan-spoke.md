# FlashLoan Spoke

The FlashLoanSpoke is a standalone Spoke that lends the liquidity of its Hub for the duration of a single call. It exposes `flashLoan` and `flashLoanSimple` entry points without the V3 interest rate modes, `onBehalfOf` and referral code, and calls the same `executeOperation` callbacks, so existing V3 receivers can be reused.

Unlike V3, a flashloan can never be converted into a debt position: the repayment is always pulled from the receiver, and the whole transaction reverts if it cannot be.

## Flashloan Flow

For each flash-borrowed asset, the FlashLoanSpoke:

1. Draws `amount` from the Hub directly to the receiver.
2. Calls `executeOperation` on the receiver with the `premium` owed for each asset, and the `initiator` (`msg.sender`).
3. Pulls `amount + premium` from the receiver into the Hub with `transferFrom`, and restores the drawn liquidity.

The Hub checks its balance on every `restore` and `add`, so the drawn liquidity is back in the Hub before any accounting is updated. Flashloans can be nested, and the receiver can call any other Spoke during the callback.

## Hub Configuration

The FlashLoanSpoke is registered as a Spoke of each Hub asset it can flashloan, and the existing Spoke controls apply:

- The `drawCap` limits the liquidity that can be flash-borrowed at once, nested flashloans included.
- The `addCap` must allow for the fees added on behalf of the Hub fee receiver.
- The `riskPremiumThreshold` is 0, as the FlashLoanSpoke never reports premium.
- The `active` and `halted` flags pause the flashloans of the asset.

The asset must also be enabled on the FlashLoanSpoke with `updateAssetConfig`.

## Premium

Each asset is configured with a premium, expressed in BPS:

- `USE_DEFAULT_PREMIUM` applies the `DEFAULT_PREMIUM` (0.05%).
- Any value up to 100.00% applies its own premium.
- 0 disables the premium of the asset.

The fee is rounded up, and 100% of it goes to the Hub fee receiver: the fee tokens are added to the Hub and their added shares are sent to the fee receiver with `payFeeShares`. Authorized flash borrowers, keyed on the initiator, pay no premium on both `flashLoan` and `flashLoanSimple`.

### Fee Aggregation

Fees are accrued in transient storage per asset, along with the flash-borrowed amount not repaid yet. The fee of an asset is only paid once all its ongoing flashloans are repaid, so duplicated assets and nested flashloans of the same asset add the fees once.

A fee too small to mint one added share stays in the Hub as untracked liquidity, and is recorded as the `pendingFee` of the asset, to be paid with its next fee.

The pending fee is only accounted by the FlashLoanSpoke, so it must not be skimmed from the Hub (e.g. through `TreasurySpoke.supplySkimmed`). Otherwise the next fee payment of the asset reverts, and so do its fee-paying flashloans, until the skimmed `pendingFee` is transferred back to the Hub.

## Hub Rounding

Drawing rounds the drawn shares up, while restoring an amount rounds the restored shares down. Restoring all the drawn shares therefore costs slightly more than the flash-borrowed amount:

$$rounding = \left\lceil \left\lceil \frac{amount}{index} \right\rceil \cdot index \right\rceil - amount$$

With a drawn index between 1 and 2, the rounding is 1 wei, or 2 wei with a probability of about $1 - \frac{1}{index}$ (e.g. 5% at an index of 1.05). It is only 0 while the index is exactly 1, or when the amount is a multiple of the index. This cost protects the suppliers and cannot be avoided, so the FlashLoanSpoke decides who pays it:

- When the fee covers the rounding, the rounding is paid out of the fee, and the premium is exactly the fee.
- When the fee is smaller (0 premium or tiny amounts), the premium is the rounding.
- Authorized flash borrowers repay exactly the amount. The rounded up drawn share, at most one per flashloan, is left on the FlashLoanSpoke as a rounding debt, restored out of the next fees of the asset before paying the fee receiver. A fee not covering the rounding debt is kept pending.

An asset without premium never pays fees, so its rounding debt grows by up to one drawn share per fee-waived flashloan. It can be repaid at any time with the restricted `repayRoundingDebt`, which pulls the rounding debt from the caller and leaves the pending fee to be paid with the next fee.
