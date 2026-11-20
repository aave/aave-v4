import "./helpers/MulDiv.spec";

// Property 2: bound the returned collateral value by the recorded payment value times the bonus / 10000.
// Intermediate assertions check the share conversion, pricing and payment bounds.

methods {
    function MANAGED_COLLATERAL_RESERVE_ID() external returns (uint256) envfree;

    // Model mulDiv rounding exactly and record the four-argument pricing calls.
    function _.mulDiv(uint256 x, uint256 y, uint256 denominator) internal
        => exactMulDiv(x, y, denominator, false) expect uint256;
    function Math.mulDiv(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) internal returns (uint256)
        => recordPricingMulDiv(x, y, denominator, rounding == Math.Rounding.Ceil || rounding == Math.Rounding.Expand);

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

    // Model the Hub index and conversion totals per (hub, asset), with SharesMath rounding.
    function _.getAssetDrawnIndex(uint256 assetId) external => hubDrawnIndex(calledContract, assetId) expect uint256;
    function _.previewAddByAssets(uint256 assetId, uint256 assets) external
        => checkedMulDiv(assets, hubAddedShares(calledContract, assetId) + VIRTUAL(), hubAddedAssets(calledContract, assetId) + VIRTUAL(), false) expect uint256;
    function _.previewAddByShares(uint256 assetId, uint256 shares) external
        => checkedMulDiv(shares, hubAddedAssets(calledContract, assetId) + VIRTUAL(), hubAddedShares(calledContract, assetId) + VIRTUAL(), true) expect uint256;
    function _.previewRemoveByShares(uint256 assetId, uint256 shares) external
        => checkedMulDiv(shares, hubAddedAssets(calledContract, assetId) + VIRTUAL(), hubAddedShares(calledContract, assetId) + VIRTUAL(), false) expect uint256;

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

// Hub values stay fixed until a HAVOC_ALL call.
ghost hubDrawnIndex(address, uint256) returns uint256;
ghost hubAddedAssets(address, uint256) returns uint256;
ghost hubAddedShares(address, uint256) returns uint256;

// Arbitrary oracle prices per reserve and asset units per decimals value.
ghost oraclePrice(uint256) returns uint256;
ghost assetUnit(uint256) returns uint256;

// Accumulate requested transfers from the liquidator across HAVOC_ALL calls.
persistent ghost address liquidator;
persistent ghost mathint amountPulled;

// Retain pricing observations across HAVOC_ALL calls.
// The last round-down call prices debt as collateral; a round-up call prices the capped collateral as debt.
persistent ghost mathint forwardDebtRay;
persistent ghost mathint forwardCollateralAssets;
persistent ghost bool capResized;
persistent ghost mathint inverseCollateralAssets;
persistent ghost mathint inverseDebtRay;

// Assert the floor or ceiling inequality for each conversion.
function checkedMulDiv(mathint x, mathint y, mathint denominator, bool up) returns uint256 {
    uint256 result = exactMulDiv(x, y, denominator, up);
    if (up) {
        // The rounded-up result is at least the exact quotient.
        assert x * y <= result * denominator, "Ceil conversion covers its input";
    } else {
        // The rounded-down result is at most the exact quotient.
        assert result * denominator <= x * y, "Floor conversion does not exceed its input";
    }
    return result;
}

// Record the input and result of each rounded pricing call.
function recordPricingMulDiv(uint256 x, uint256 y, uint256 denominator, bool up) returns uint256 {
    uint256 result = checkedMulDiv(x, y, denominator, up);
    if (up) {
        capResized = true;
        inverseCollateralAssets = x;
        inverseDebtRay = result;
    } else {
        forwardDebtRay = x;
        forwardCollateralAssets = result;
    }
    return result;
}

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

// Compare collateral and payment in the same price units, with the bonus in basis points.
rule collateralWithinBonusPricedRepayment(env e, uint256 debtReserveId, uint256 debtToCover, address user, uint256 maxCollateralToRemove) {
    // Snapshot prices and units before liquidation can havoc their ghosts.
    uint256 collateralReserveId = MANAGED_COLLATERAL_RESERVE_ID();
    mathint collateralPrice = oraclePrice(collateralReserveId);
    mathint debtPrice = oraclePrice(debtReserveId);
    mathint collateralUnit = assetUnit(currentContract._reserves[collateralReserveId].decimals);
    mathint debtUnit = assetUnit(currentContract._reserves[debtReserveId].decimals);

    // Reset transfer and pricing observations.
    liquidator = e.msg.sender;
    amountPulled = 0;
    capResized = false;
    forwardDebtRay = 0;
    forwardCollateralAssets = 0;
    inverseCollateralAssets = 0;
    inverseDebtRay = 0;

    uint256 liquidationBonus;
    uint256 collateralAmountRemoved;
    liquidationBonus, collateralAmountRemoved = liquidationCall(e, debtReserveId, debtToCover, user, maxCollateralToRemove);

    mathint collateralFactor = collateralPrice * debtUnit * 10000;
    mathint debtFactor = debtPrice * collateralUnit * liquidationBonus;
    mathint ray = 10^27;

    if (capResized) {
        // The removed collateral amount does not exceed the amount used to resize the debt.
        assert collateralAmountRemoved <= inverseCollateralAssets;
        // The resized debt value, multiplied by the bonus / 10000, covers the collateral value used for resizing.
        assert inverseCollateralAssets * collateralFactor * ray <= inverseDebtRay * debtFactor;
        // The recorded payment covers the resized debt.
        assert inverseDebtRay <= amountPulled * ray;
    } else {
        // The removed collateral amount does not exceed the amount initially priced from the debt.
        assert collateralAmountRemoved <= forwardCollateralAssets;
        // The initially priced collateral value is at most the debt value times the bonus / 10000.
        assert forwardCollateralAssets * collateralFactor * ray <= forwardDebtRay * debtFactor;
        // The recorded payment covers the ray debt used for pricing.
        assert forwardDebtRay <= amountPulled * ray;
    }

    // In ray units, the removed collateral value is at most the recorded payment value times the bonus / 10000.
    assert collateralAmountRemoved * collateralFactor * ray <= amountPulled * ray * debtFactor;

    // The removed collateral is worth at most the recorded payment value times liquidationBonus / 10000.
    assert collateralAmountRemoved * collateralPrice * debtUnit * 10000 <= amountPulled * debtPrice * collateralUnit * liquidationBonus;
}
