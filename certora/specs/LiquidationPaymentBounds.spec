import "./helpers/MulDiv.spec";

// Property 2: a successful liquidation pulls at most debtToCover, and at most the user's debt.
// The collateral removed is worth at most the pulled debt times the liquidation bonus.
methods {
    function MANAGED_COLLATERAL_RESERVE_ID() external returns (uint256) envfree;

    // Replace the mulDiv functions with CVL exactMulDiv function.
    function _.mulDiv(uint256 x, uint256 y, uint256 denominator) internal
        => exactMulDiv(x, y, denominator, false) expect uint256;
    function Math.mulDiv(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) internal returns (uint256)
        => mulDivWithGalois(x, y, denominator, rounding == Math.Rounding.Ceil || rounding == Math.Rounding.Expand);
    function _.previewAddByAssets(uint256 assetId, uint256 assets) external
        => previewAddByAssetsRecorded(calledContract, assetId, assets) expect uint256;
    function _.previewAddByShares(uint256 assetId, uint256 shares) external
        => previewAddBySharesWithGalois(calledContract, assetId, shares) expect uint256;

    // The bounds hold for any bonus, and for any asset unit and price fixed per decimals and reserve.
    function _.calculateLiquidationBonus(uint256,uint256,uint256,uint256) external => NONDET;
    function LiquidationLogic.calculateLiquidationBonus(uint256,uint256,uint256,uint256) internal returns (uint256) => NONDET;
    function MathUtils.uncheckedExp(uint256, uint256 exponent) internal returns (uint256) => assetUnit(exponent);
    function _.getReservePrice(uint256 reserveId) external => oraclePrice(reserveId) expect uint256;

    // These raw readers are outside the rule and prevent storage splitting.
    function _.extSload(bytes32) external => NONDET DELETE;
    function _.extSloads(bytes32[]) external => NONDET DELETE;

    // Post-payment bookkeeping: no direct pulls.
    function Spoke._notifyRiskPremiumUpdate(address,uint256) internal => NONDET;
    function LiquidationLogic.notifyReportDeficit(mapping(uint256 => ISpoke.Reserve) storage, mapping(address => mapping(uint256 => ISpoke.UserPosition)) storage, mapping(address => ISpoke.PositionStatus) storage, uint256, address) external => HAVOC_ALL;

    // Hub views as in Hub.sol: one drawn index and one (addedAssets, addedShares) pair per asset,
    // with SharesMath rounding. The cap-resized sizing is only bounded if both previews share that pair.
    function _.getAssetDrawnIndex(uint256 assetId) external => hubDrawnIndex(calledContract, assetId) expect uint256;
    function _.previewRemoveByShares(uint256 assetId, uint256 shares) external
        => exactMulDiv(shares, hubAddedAssets(calledContract, assetId) + VIRTUAL(), hubAddedShares(calledContract, assetId) + VIRTUAL(), false) expect uint256;

    // These do not feed the sizing; arbitrary effects.
    function _.remove(uint256,uint256,address) external => HAVOC_ALL;
    function _.restore(uint256,uint256,IHubBase.PremiumDelta) external => HAVOC_ALL;
    function _.reportDeficit(uint256,uint256,IHubBase.PremiumDelta) external => HAVOC_ALL;
    function _.refreshPremium(uint256,IHubBase.PremiumDelta) external => HAVOC_ALL;

    // This helper reads state and calls only view functions; its result is unconstrained.
    function Spoke._calculateUserAccountData(address) internal returns (ISpoke.UserAccountData memory)
        => arbitraryAccountData();

    function _.safeTransferFrom(address token, address from, address to, uint256 amount) internal
        => recordLiquidatorPull(from, amount) expect void;

    unresolved external in _._ => DISPATCH [] default ASSERT_FALSE;
}

definition VIRTUAL() returns mathint = 10^6;

// Rounding down x*k/q to at least n means rounding up n*q/k is at most x. Proved by galoisLemma.
definition galois(mathint x, mathint k, mathint q, mathint n) returns bool =
    (x >= 0 && n >= 0 && k > 0 && q > 0) => (x * k / q >= n => (n * q + k - 1) / k <= x);

// Hub views.
ghost hubDrawnIndex(address, uint256) returns uint256;
ghost hubAddedAssets(address, uint256) returns uint256;
ghost hubAddedShares(address, uint256) returns uint256;

// Oracle price per reserve and asset unit per decimals.
ghost oraclePrice(uint256) returns uint256;
ghost assetUnit(uint256) returns uint256;

// Inputs of the last Floor mulDiv and the last previewAddByAssets: the forward pricing of the
// liquidated debt, which the cap resize inverts. Any recorded values keep the galois facts true.
ghost uint256 floorX;
ghost uint256 floorY;
ghost uint256 floorDen;
ghost address addHub;
ghost uint256 addAssetId;
ghost uint256 addAssets;

// Tracked state.
persistent ghost address liquidator;
persistent ghost mathint amountPulled;

// Arbitrary account data.
function arbitraryAccountData() returns ISpoke.UserAccountData {
    ISpoke.UserAccountData result;
    return result;
}

// Record a pull operation.
function recordLiquidatorPull(address from, uint256 amount) {
    if (from == liquidator) {
        amountPulled = amountPulled + amount;
    }
}

// Floor calls are recorded; a Ceil call inverting the last Floor call gets the galois fact.
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

// Record the values for the galois lemma
function previewAddByAssetsRecorded(address hub, uint256 assetId, uint256 assets) returns uint256 {
    addHub = hub;
    addAssetId = assetId;
    addAssets = assets;

    return exactMulDiv(assets, hubAddedShares(hub, assetId) + VIRTUAL(), hubAddedAssets(hub, assetId) + VIRTUAL(), false);
}

// The inverse conversion on the same Hub pair gets the galois fact against the last previewAddByAssets.
function previewAddBySharesWithGalois(address hub, uint256 assetId, uint256 shares) returns uint256 {
    mathint addedAssets = hubAddedAssets(hub, assetId) + VIRTUAL();
    mathint addedShares = hubAddedShares(hub, assetId) + VIRTUAL();

    // Apply galois lemma
    require (hub == addHub && assetId == addAssetId) => galois(addAssets, addedShares, addedAssets, shares), "galoisLemma";

    return exactMulDiv(shares, addedAssets, addedShares, true);
}


// Prove that rounding down x*k/q to at least n means rounding up n*q/k is at most x
rule galoisLemma {
    // Get the values for the galois lemma
    mathint x; mathint k; mathint q; mathint n;

    // Prove the galois lemma
    assert galois(x, k, q, n);
}

// Prove that the liquidator payment does not exceed debtToCover
rule liquidationPaymentWithinDebtToCover(env e, uint256 debtReserveId, uint256 debtToCover, address user, uint256 maxCollateralToRemove) {
    // Initialize the liquidator and the amount pulled
    liquidator = e.msg.sender;
    amountPulled = 0;

    // Run the liquidation
    liquidationCall(e, debtReserveId, debtToCover, user, maxCollateralToRemove);

    // Liquidator payment does not exceed debtToCover
    assert amountPulled <= debtToCover;
}

// Prove that the liquidator payment does not exceed the user's pre-liquidation debt
rule liquidationPaymentWithinUserDebt(env e, uint256 debtReserveId, uint256 debtToCover, address user, uint256 maxCollateralToRemove) {
    // Get the user's pre-liquidation debt
    uint256 drawnDebt;
    uint256 premiumDebt;
    drawnDebt, premiumDebt = getUserDebt(e, debtReserveId, user);

    // Initialize the liquidator and the amount pulled
    liquidator = e.msg.sender;
    amountPulled = 0;

    // Run the liquidation
    liquidationCall(e, debtReserveId, debtToCover, user, maxCollateralToRemove);

    // Liquidator payment does not exceed the user's pre-liquidation debt
    assert amountPulled <= drawnDebt + premiumDebt;
}

// Prove that the collateral removed is worth at most the pulled debt times the liquidation bonus
rule collateralWithinBonusPricedRepayment(env e, uint256 debtReserveId, uint256 debtToCover, address user, uint256 maxCollateralToRemove) {
    // Get the prices and asset units used by the liquidation
    uint256 collateralReserveId = MANAGED_COLLATERAL_RESERVE_ID();
    mathint collateralPrice = oraclePrice(collateralReserveId);
    mathint debtPrice = oraclePrice(debtReserveId);
    mathint collateralUnit = assetUnit(currentContract._reserves[collateralReserveId].decimals);
    mathint debtUnit = assetUnit(currentContract._reserves[debtReserveId].decimals);

    // Initialize the liquidator and the amount pulled
    liquidator = e.msg.sender;
    amountPulled = 0;

    // Run the liquidation
    uint256 liquidationBonus;
    uint256 collateralAmountRemoved;
    liquidationBonus, collateralAmountRemoved = liquidationCall(e, debtReserveId, debtToCover, user, maxCollateralToRemove);

    // Collateral value removed does not exceed the pulled debt value times the bonus
    assert collateralAmountRemoved * collateralPrice * debtUnit * 10000
        <= amountPulled * debtPrice * collateralUnit * liquidationBonus;
}
