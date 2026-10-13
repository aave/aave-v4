import "./helpers/MulDiv.spec";

// Property 2: the collateral removed is worth at most the pulled debt times the liquidation bonus.
// Same arithmetic model as LiquidationPaymentBounds.spec, without the galois facts.
// Intermediate assertions expose the rounding and conversion steps to multi_assert_check.
methods {
    function MANAGED_COLLATERAL_RESERVE_ID() external returns (uint256) envfree;

    // Replace the mulDiv functions with CVL exactMulDiv function.
    function _.mulDiv(uint256 x, uint256 y, uint256 denominator) internal
        => exactMulDiv(x, y, denominator, false) expect uint256;
    function Math.mulDiv(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) internal returns (uint256)
        => recordPricingMulDiv(x, y, denominator, rounding == Math.Rounding.Ceil || rounding == Math.Rounding.Expand);

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
    // with SharesMath rounding.
    function _.getAssetDrawnIndex(uint256 assetId) external => hubDrawnIndex(calledContract, assetId) expect uint256;
    function _.previewAddByAssets(uint256 assetId, uint256 assets) external
        => checkedMulDiv(assets, hubAddedShares(calledContract, assetId) + VIRTUAL(), hubAddedAssets(calledContract, assetId) + VIRTUAL(), false) expect uint256;
    function _.previewAddByShares(uint256 assetId, uint256 shares) external
        => checkedMulDiv(shares, hubAddedAssets(calledContract, assetId) + VIRTUAL(), hubAddedShares(calledContract, assetId) + VIRTUAL(), true) expect uint256;
    function _.previewRemoveByShares(uint256 assetId, uint256 shares) external
        => checkedMulDiv(shares, hubAddedAssets(calledContract, assetId) + VIRTUAL(), hubAddedShares(calledContract, assetId) + VIRTUAL(), false) expect uint256;

    // These do not feed the sizing, their effects are arbitrary.
    function _.remove(uint256,uint256,address) external => HAVOC_ALL;
    function _.restore(uint256,uint256,IHubBase.PremiumDelta) external => HAVOC_ALL;
    function _.reportDeficit(uint256,uint256,IHubBase.PremiumDelta) external => HAVOC_ALL;
    function _.refreshPremium(uint256,IHubBase.PremiumDelta) external => HAVOC_ALL;

    // This helper reads state and calls only view functions, its result is unconstrained.
    function Spoke._calculateUserAccountData(address) internal returns (ISpoke.UserAccountData memory)
        => arbitraryAccountData();

    function _.safeTransferFrom(address token, address from, address to, uint256 amount) internal
        => recordLiquidatorPull(from, amount) expect void;

    unresolved external in _._ => DISPATCH [] default ASSERT_FALSE;
}

definition VIRTUAL() returns mathint = 10^6;

// Hub views.
ghost hubDrawnIndex(address, uint256) returns uint256;
ghost hubAddedAssets(address, uint256) returns uint256;
ghost hubAddedShares(address, uint256) returns uint256;

// Oracle price per reserve and asset unit per decimals.
ghost oraclePrice(uint256) returns uint256;
ghost assetUnit(uint256) returns uint256;

// Tracked state.
persistent ghost address liquidator;
persistent ghost mathint amountPulled;

// Observations survive the HAVOC_ALL summaries after sizing. The last Floor call is
// forward collateral pricing; a subsequent Ceil call is the collateral-cap resize.
persistent ghost mathint forwardDebtRay;
persistent ghost mathint forwardCollateralAssets;
persistent ghost bool capResized;
persistent ghost mathint inverseCollateralAssets;
persistent ghost mathint inverseDebtRay;

// Prove its useful one-sided rounding bound separately.
function checkedMulDiv(mathint x, mathint y, mathint denominator, bool up) returns uint256 {
    uint256 result = exactMulDiv(x, y, denominator, up);
    if (up) {
        assert x * y <= result * denominator, "Ceil conversion covers its input";
    } else {
        assert result * denominator <= x * y, "Floor conversion does not exceed its input";
    }
    return result;
}

// Record the pricing mulDiv operation.
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
    capResized = false;
    forwardDebtRay = 0;
    forwardCollateralAssets = 0;
    inverseCollateralAssets = 0;
    inverseDebtRay = 0;

    // Run the liquidation
    uint256 liquidationBonus;
    uint256 collateralAmountRemoved;
    liquidationBonus, collateralAmountRemoved = liquidationCall(e, debtReserveId, debtToCover, user, maxCollateralToRemove);

    mathint collateralFactor = collateralPrice * debtUnit * 10000;
    mathint debtFactor = debtPrice * collateralUnit * liquidationBonus;
    mathint ray = 10^27;

    // First bridge shares back to assets, then pricing to ray debt, then ray debt to the actual pull. 
    if (capResized) {
        // Verify the inverse-priced bounds.
        assert collateralAmountRemoved <= inverseCollateralAssets;
        assert inverseCollateralAssets * collateralFactor * ray <= inverseDebtRay * debtFactor;
        assert inverseDebtRay <= amountPulled * ray;
    } else {
        // Verify the forward-priced bounds.
        assert collateralAmountRemoved <= forwardCollateralAssets;
        assert forwardCollateralAssets * collateralFactor * ray <= forwardDebtRay * debtFactor;
        assert forwardDebtRay <= amountPulled * ray;
    }

    // Compose the collateral conversion, pricing and payment bounds.
    assert collateralAmountRemoved * collateralFactor * ray <= amountPulled * ray * debtFactor;

    // Preserve the original end-to-end property.
    assert collateralAmountRemoved * collateralPrice * debtUnit * 10000 <= amountPulled * debtPrice * collateralUnit * liquidationBonus;
}
