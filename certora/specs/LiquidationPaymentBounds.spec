import "./helpers/MulDiv.spec";

// Property 2: successful liquidation requests at most debtToCover and the user's pre-call reserve debt.
// The collateral value bound is in LiquidationCollateralBound.spec.

methods {
    function MANAGED_COLLATERAL_RESERVE_ID() external returns (uint256) envfree;

    // Model mulDiv rounding exactly; use galoisLemma for inverse pricing and share conversions.
    function _.mulDiv(uint256 x, uint256 y, uint256 denominator) internal
        => exactMulDiv(x, y, denominator, false) expect uint256;
    function Math.mulDiv(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) internal returns (uint256)
        => mulDivWithGalois(x, y, denominator, rounding == Math.Rounding.Ceil || rounding == Math.Rounding.Expand);
    function _.previewAddByAssets(uint256 assetId, uint256 assets) external
        => previewAddByAssetsRecorded(calledContract, assetId, assets) expect uint256;
    function _.previewAddByShares(uint256 assetId, uint256 shares) external
        => previewAddBySharesWithGalois(calledContract, assetId, shares) expect uint256;

    // Use an arbitrary bonus, asset units keyed by decimals and prices keyed by reserve.
    function _.calculateLiquidationBonus(uint256,uint256,uint256,uint256) external => NONDET;
    function LiquidationLogic.calculateLiquidationBonus(uint256,uint256,uint256,uint256) internal returns (uint256) => NONDET;
    function MathUtils.uncheckedExp(uint256, uint256 exponent) internal returns (uint256) => assetUnit(exponent);
    function _.getReservePrice(uint256 reserveId) external => oraclePrice(reserveId) expect uint256;

    // Remove raw read-only storage accessors from the scene to allow storage splitting.
    function _.extSload(bytes32) external => NONDET DELETE;
    function _.extSloads(bytes32[]) external => NONDET DELETE;

    // After payment, omit premium refresh effects and havoc deficit-reporting effects.
    function Spoke._notifyRiskPremiumUpdate(address,uint256) internal => NONDET;
    function LiquidationLogic.notifyReportDeficit(mapping(uint256 => ISpoke.Reserve) storage, mapping(address => mapping(uint256 => ISpoke.UserPosition)) storage, mapping(address => ISpoke.PositionStatus) storage, uint256, address) external => HAVOC_ALL;

    // Model the Hub index and rounded-down share value per (hub, asset).
    // All three conversion previews use the same asset and share totals before any HAVOC_ALL call.
    function _.getAssetDrawnIndex(uint256 assetId) external => hubDrawnIndex(calledContract, assetId) expect uint256;
    function _.previewRemoveByShares(uint256 assetId, uint256 shares) external
        => exactMulDiv(shares, hubAddedAssets(calledContract, assetId) + VIRTUAL(), hubAddedShares(calledContract, assetId) + VIRTUAL(), false) expect uint256;

    // Havoc storage and non-persistent ghosts after sizing.
    function _.remove(uint256,uint256,address) external => HAVOC_ALL;
    function _.restore(uint256,uint256,IHubBase.PremiumDelta) external => HAVOC_ALL;
    function _.reportDeficit(uint256,uint256,IHubBase.PremiumDelta) external => HAVOC_ALL;
    function _.refreshPremium(uint256,IHubBase.PremiumDelta) external => HAVOC_ALL;

    // Return arbitrary account data without changing storage.
    function Spoke._calculateUserAccountData(address) internal returns (ISpoke.UserAccountData memory)
        => arbitraryAccountData();

    // Record requested transfers from the liquidator; omit token execution and callbacks.
    function _.safeTransferFrom(address token, address from, address to, uint256 amount) internal
        => recordLiquidatorPull(from, amount) expect void;

    unresolved external in _._ => DISPATCH [] default ASSERT_FALSE;
}

definition VIRTUAL() returns mathint = 10^6;

// For x,n >= 0 and k,q > 0: floor(x*k/q) >= n implies ceil(n*q/k) <= x.
// Asserted separately by galoisLemma.
definition galois(mathint x, mathint k, mathint q, mathint n) returns bool =
    (x >= 0 && n >= 0 && k > 0 && q > 0) => (x * k / q >= n => (n * q + k - 1) / k <= x);

// Hub values stay fixed until a HAVOC_ALL call.
ghost hubDrawnIndex(address, uint256) returns uint256;
ghost hubAddedAssets(address, uint256) returns uint256;
ghost hubAddedShares(address, uint256) returns uint256;

// Arbitrary oracle prices per reserve and asset units per decimals value.
ghost oraclePrice(uint256) returns uint256;
ghost assetUnit(uint256) returns uint256;

// Save the last round-down mulDiv and asset-to-share inputs for the inverse-conversion lemma.
ghost uint256 floorX;
ghost uint256 floorY;
ghost uint256 floorDen;
ghost address addHub;
ghost uint256 addAssetId;
ghost uint256 addAssets;

// Accumulate requested transfers from the liquidator across HAVOC_ALL calls.
persistent ghost address liquidator;
persistent ghost mathint amountPulled;

function arbitraryAccountData() returns ISpoke.UserAccountData {
    ISpoke.UserAccountData result;
    return result;
}

// Sum transfer amounts whose sender is the liquidator.
function recordLiquidatorPull(address from, uint256 amount) {
    if (from == liquidator) {
        amountPulled = amountPulled + amount;
    }
}

// Record round-down inputs; apply galoisLemma when a round-up call swaps the multiplier and denominator.
function mulDivWithGalois(uint256 x, uint256 y, uint256 denominator, bool up) returns uint256 {
    if (up) {
        require (y == floorDen && denominator == floorY) => galois(floorX, floorY, floorDen, x), "galoisLemma";
    } else {
        floorX = x;
        floorY = y;
        floorDen = denominator;
    }
    return exactMulDiv(x, y, denominator, up);
}

// Record the asset-to-share input and return the rounded-down share amount.
function previewAddByAssetsRecorded(address hub, uint256 assetId, uint256 assets) returns uint256 {
    addHub = hub;
    addAssetId = assetId;
    addAssets = assets;

    return exactMulDiv(assets, hubAddedShares(hub, assetId) + VIRTUAL(), hubAddedAssets(hub, assetId) + VIRTUAL(), false);
}

// Convert shares to assets, rounding up; apply galoisLemma for the last matching (hub, asset).
function previewAddBySharesWithGalois(address hub, uint256 assetId, uint256 shares) returns uint256 {
    mathint addedAssets = hubAddedAssets(hub, assetId) + VIRTUAL();
    mathint addedShares = hubAddedShares(hub, assetId) + VIRTUAL();

    require (hub == addHub && assetId == addAssetId) => galois(addAssets, addedShares, addedAssets, shares), "galoisLemma";

    return exactMulDiv(shares, addedAssets, addedShares, true);
}


// Check the rounding implication for arbitrary integers; its definition includes the domain conditions.
rule galoisLemma {
    mathint x; mathint k; mathint q; mathint n;

    // For x,n >= 0 and k,q > 0, rounding x*k/q down to at least n means rounding n*q/k up gives at most x.
    assert galois(x, k, q, n);
}

// Bound the total requested transfers from the liquidator by debtToCover.
rule liquidationPaymentWithinDebtToCover(env e, uint256 debtReserveId, uint256 debtToCover, address user, uint256 maxCollateralToRemove) {
    liquidator = e.msg.sender;
    amountPulled = 0;

    liquidationCall(e, debtReserveId, debtToCover, user, maxCollateralToRemove);

    // The total requested payment from the liquidator does not exceed debtToCover.
    assert amountPulled <= debtToCover;
}

// Bound the total requested transfers by the user's pre-call drawn and premium debt in debtReserveId.
rule liquidationPaymentWithinUserDebt(env e, uint256 debtReserveId, uint256 debtToCover, address user, uint256 maxCollateralToRemove) {
    uint256 drawnDebt;
    uint256 premiumDebt;
    drawnDebt, premiumDebt = getUserDebt(e, debtReserveId, user);

    liquidator = e.msg.sender;
    amountPulled = 0;

    liquidationCall(e, debtReserveId, debtToCover, user, maxCollateralToRemove);

    // The total requested payment does not exceed the user's pre-call drawn and premium debt in this reserve.
    assert amountPulled <= drawnDebt + premiumDebt;
}
