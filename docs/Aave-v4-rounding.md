# Aave v4 rounding

Explanation of the rounding directions within the Aave V4 protocol.

## Rounding

Note that there is a difference between supply-side conversions and debt-side conversions.

On the supply side, when converting from shares to assets, we use the ratio of total assets divided by total shares, namely `assets = shares * (totalAssets / totalShares)`. For convenience in the following explanation, we will refer to the quantity `(totalAssets / totalShares)` as `sharesToAssets`, and `(totalShares / totalAssets)` as `assetsToShares`.

On the debt side, when converting from shares to assets, we use a monotonically increasing debt index, which is updated whenever debt interest is accrued. Thus `assets = shares * debtIndex`.

- when supplying assets, the resulting shares added on behalf of a user are rounded down, so that `shares = floor(assets * assetsToShares)`.
- when withdrawing assets, the resulting shares removed from a user position are rounded up, so that `shares = ceil(assets * assetsToShares)`.
- when borrowing assets, the resulting drawn shares representing a user's debt are rounded up, so that `shares = ceil(assets * assetsToShares)`.
- when repaying assets, the resulting drawn shares removed from a user's debt are rounded down, so that `shares = floor(assets * assetsToShares)`.
- when calculating the liquidation fee portion of a liquidation to distribute to the treasury, the result is rounded down.
- when calculating the value of a user's supplied collateral in the base currency, the result is rounded down.
- when calculating the value of a user's total debt in the base currency, the result is rounded up.
- when calculating the total amount of an asset supplied to the protocol (totalAddedAssets), the result is rounded down.
