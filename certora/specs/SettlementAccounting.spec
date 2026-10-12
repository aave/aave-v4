// Property 4: Settlement Accounting
// - the repayment settles only against debtReserveId
// - the collateral debit is sent in full to the liquidator
// - deficit is reported iff the managed collateral is emptied while debt remains

// Scope: at most four listed reserves (one bitmap word). Liquidation sizing is arbitrary, so the
// settlement checks hold for any amounts.
methods {
    function MANAGED_COLLATERAL_RESERVE_ID() external returns (uint256) envfree;

    // Raw readers are outside the rule and prevent storage splitting.
    function _.extSload(bytes32) external => NONDET DELETE;
    function _.extSloads(bytes32[]) external => NONDET DELETE;

    // Read-only sizing, bonus and premium math with arbitrary results; the share updates stay concrete.
    function _.calculateLiquidationBonus(uint256, uint256, uint256, uint256) external => NONDET;
    function LiquidationLogic.calculateLiquidationBonus(uint256, uint256, uint256, uint256) internal returns (uint256) => NONDET;
    function MathUtils.uncheckedExp(uint256, uint256) internal returns (uint256) => NONDET;
    function WadRayMath.rayMulUp(uint256, uint256) internal returns (uint256) => NONDET;
    function Premium.calculatePremiumRay(uint256, int256, uint256) internal returns (uint256) => NONDET;

    // Post-settlement premium refresh (no-deficit branch). It never writes supplied or drawn shares, but it does
    // write premiumShares/premiumOffsetRay of every borrowed reserve, so !otherDebtWrite covers settlement only.
    function Spoke._notifyRiskPremiumUpdate(address, uint256) internal => NONDET;

    // Hub, oracle and token boundaries, without callbacks into the Spoke.
    function _.getReservePrice(uint256) external => NONDET;
    function _.getAssetDrawnIndex(uint256) external => NONDET;
    function _.previewAddByAssets(uint256, uint256) external => NONDET;

    // Arbitrary liquidation amounts and premium delta.
    function BabylonLiquidationLogic._calculateLiquidationAmounts(BabylonLiquidationLogic.CalculateLiquidationAmountsParams memory) internal returns (BabylonLiquidationLogic.LiquidationAmounts memory)
        => arbitraryLiquidationAmounts();
    function UserPositionUtils.calculatePremiumDelta(ISpoke.UserPosition storage, uint256, uint256, uint256, uint256) internal returns (IHubBase.PremiumDelta memory)
        => arbitraryPremiumDelta();

    // Only the two counts feed the deficit decision; everything else is arbitrary.
    function Spoke._calculateUserAccountData(address user) internal returns (ISpoke.UserAccountData memory)
        => accountData(user);

    // Hub, oracle and token boundaries, without callbacks into the Spoke.
    function _.previewRemoveByShares(uint256 assetId, uint256 shares) external
        => removeByShares(calledContract, assetId, shares) expect uint256;
    function _.remove(uint256 assetId, uint256 amount, address to) external 
        => recordRemove(calledContract, assetId, amount, to) expect uint256;
    function _.payFeeShares(uint256, uint256) external 
        => recordFee() expect void;
    // Records the deficit decision only; its debt clearing is dropped, so post-call debt reads are the settled values.
    function LiquidationLogic.notifyReportDeficit(mapping(uint256 => ISpoke.Reserve) storage, mapping(address => mapping(uint256 => ISpoke.UserPosition)) storage, mapping(address => ISpoke.PositionStatus) storage, uint256, address user) external
        => recordDeficit(user);
    function _.restore(uint256 assetId, uint256, IHubBase.PremiumDelta) external
        => recordRestore(calledContract, assetId) expect uint256;
    function _.safeTransferFrom(address token, address from, address to, uint256) internal
        => recordPull(token, from, to) expect void;

    unresolved external in _._ => DISPATCH [] default ASSERT_FALSE;
}


definition MAX_RESERVES() returns uint256 = 4;

// Hub conversion: one fixed result per (hub, asset, shares).
ghost removeByShares(address, uint256, uint256) returns uint256;

// Observed writes of the user's collateral and debt shares.
persistent ghost address trackedUser;
persistent ghost uint256 trackedCollateral;
persistent ghost uint256 trackedDebt;
persistent ghost bool otherSupplyWrite;
persistent ghost bool otherDebtWrite;
// Positive counterparts: the hooks fire on the tracked positions, so the negative checks are not vacuous.
persistent ghost bool collateralWritten;
persistent ghost bool debtWritten;

// Observed writes of the liquidator's pull, restore, remove and fee.
persistent ghost mathint pullCount;
persistent ghost address pullToken;
persistent ghost address pullFrom;
persistent ghost address pullTo;
persistent ghost mathint restoreCount;
persistent ghost address restoreHub;
persistent ghost uint256 restoreAsset;
persistent ghost mathint removeCount;
persistent ghost address removeHub;
persistent ghost uint256 removeAsset;
persistent ghost uint256 removeAmount;
persistent ghost address removeTo;
persistent ghost bool feeCharged;
persistent ghost mathint deficitCount;
persistent ghost address deficitUser;


// Arbitrary liquidation amounts.
function arbitraryLiquidationAmounts() returns BabylonLiquidationLogic.LiquidationAmounts {
    BabylonLiquidationLogic.LiquidationAmounts result;
    return result;
}

// Arbitrary premium delta.
function arbitraryPremiumDelta() returns IHubBase.PremiumDelta {
    IHubBase.PremiumDelta result;
    return result;
}

// Reserve r < 4 lives in bucket 0: borrowing bit 2r, collateral bit 2r + 1.
function borrowed(address user, uint256 r) returns bool {
    uint256 word = currentContract._positionStatus[user].map[0];
    if (r >= currentContract._reserveCount) { return false; }
    if (r == 0) { return word % 2 == 1; }
    if (r == 1) { return (word / 4) % 2 == 1; }
    if (r == 2) { return (word / 16) % 2 == 1; }
    if (r == 3) { return (word / 64) % 2 == 1; }
    return false;
}

// Same borrowCount as Spoke._processUserAccountData: borrowing bits of listed reserves.
function accountData(address user) returns ISpoke.UserAccountData {
    ISpoke.UserAccountData result;
    require result.activeCollateralCount <= 1, "Property 1: only the managed reserve can be collateral.";
    require to_mathint(result.borrowCount) == (borrowed(user, 0) ? 1 : 0) + (borrowed(user, 1) ? 1 : 0)
        + (borrowed(user, 2) ? 1 : 0) + (borrowed(user, 3) ? 1 : 0), "Real count of borrowed listed reserves.";
    return result;
}

// Record a deficit report for the user.
function recordDeficit(address u) {
    deficitCount = deficitCount + 1;
    deficitUser = u;
}

// Record a remove operation.
function recordRemove(address hub, uint256 assetId, uint256 amount, address to) returns uint256 {
    removeCount = removeCount + 1;
    removeHub = hub;
    removeAsset = assetId;
    removeAmount = amount;
    removeTo = to;
    uint256 shares;
    return shares;
}

// Record a fee charge.
function recordFee() {
    feeCharged = true;
}

// Record a restore operation.
function recordRestore(address hub, uint256 assetId) returns uint256 {
    restoreCount = restoreCount + 1;
    restoreHub = hub;
    restoreAsset = assetId;
    uint256 shares;
    return shares;
}

// Record a pull operation.
function recordPull(address token, address from, address to) {
    pullCount = pullCount + 1;
    pullToken = token;
    pullFrom = from;
    pullTo = to;
}

// Hooks to track writes to the user's collateral shares.
hook Sstore currentContract._userPositions[KEY address u][KEY uint256 r].suppliedShares uint120 newValue {
    if (u != trackedUser || r != trackedCollateral) { otherSupplyWrite = true; } else { collateralWritten = true; }
}

// Hook to track writes to the user's debt shares.
hook Sstore currentContract._userPositions[KEY address u][KEY uint256 r].drawnShares uint120 newValue {
    if (u != trackedUser || r != trackedDebt) { otherDebtWrite = true; } else { debtWritten = true; }
}

// Hook to track writes to the user's premium shares.
hook Sstore currentContract._userPositions[KEY address u][KEY uint256 r].premiumShares uint120 newValue {
    if (u != trackedUser || r != trackedDebt) { otherDebtWrite = true; }
}

// Hook to track writes to the user's premium offset ray.
hook Sstore currentContract._userPositions[KEY address u][KEY uint256 r].premiumOffsetRay int200 newValue {
    if (u != trackedUser || r != trackedDebt) { otherDebtWrite = true; }
}

// Return true if the user has a borrowed position in any reserve other than debtId.
function otherBorrowed(address user, uint256 debtId) returns bool {
    return (debtId != 0 && borrowed(user, 0)) || (debtId != 1 && borrowed(user, 1))
        || (debtId != 2 && borrowed(user, 2)) || (debtId != 3 && borrowed(user, 3));
}

// Setup the proof state.
function setup(address user, uint256 debtReserveId) {
    require currentContract._reserveCount <= MAX_RESERVES(), "Proof scope: at most four reserves.";
    require debtReserveId < currentContract._reserveCount, "Spoke validReserveId: only listed reserves have a hub.";
    // Not proved here; Aave's Spoke specs require the same isBorrowingIFFdrawnShares fact.
    require currentContract._userPositions[user][debtReserveId].drawnShares > 0 => borrowed(user, debtReserveId), "Spoke invariant: drawn shares imply the borrowing bit.";

    // Initialize the tracked state.
    trackedUser = user;
    trackedCollateral = MANAGED_COLLATERAL_RESERVE_ID();
    trackedDebt = debtReserveId;
    otherSupplyWrite = false;
    otherDebtWrite = false;
    collateralWritten = false;
    debtWritten = false;
    pullCount = 0;
    restoreCount = 0;
    removeCount = 0;
    feeCharged = false;
    deficitCount = 0;
}

// The liquidator pays the debt reserve's Hub in its underlying, and settlement writes debt only to the user's debtReserveId position.
rule repaymentSettlesOnlyDebtReserve(env e, uint256 debtReserveId, uint256 debtToCover, address user, uint256 maxCollateralToRemove) {
    setup(user, debtReserveId);
    address debtHub = currentContract._reserves[debtReserveId].hub;
    uint256 debtAssetId = currentContract._reserves[debtReserveId].assetId;
    address debtUnderlying = currentContract._reserves[debtReserveId].underlying;

    liquidationCall(e, debtReserveId, debtToCover, user, maxCollateralToRemove);

    // Liquidator did not pay the debt reserve's Hub exactly once, in its underlying
    assert pullCount == 1 && pullFrom == e.msg.sender && pullToken == debtUnderlying && pullTo == debtHub;
    // Debt not restored exactly once on the debt reserve's Hub and asset
    assert restoreCount == 1 && restoreHub == debtHub && restoreAsset == debtAssetId;
    // The user's debtReserveId drawn shares were never written (hook not firing)
    assert debtWritten;
    // A debt position other than the user's debtReserveId was written
    assert !otherDebtWrite;
}

// The user's collateral debit is removed in full to the liquidator, with no fee and no shares credited.
rule collateralDebitSentToLiquidator(env e, uint256 debtReserveId, uint256 debtToCover, address user, uint256 maxCollateralToRemove) {
    setup(user, debtReserveId);
    uint256 collateralId = MANAGED_COLLATERAL_RESERVE_ID();
    address hub = currentContract._reserves[collateralId].hub;
    uint256 assetId = currentContract._reserves[collateralId].assetId;
    mathint sharesBefore = currentContract._userPositions[user][collateralId].suppliedShares;

    // Call the liquidation logic.
    uint256 liquidationBonus;
    uint256 collateralAmountRemoved;
    liquidationBonus, collateralAmountRemoved = liquidationCall(e, debtReserveId, debtToCover, user, maxCollateralToRemove);

    // Calculate the shares debited.
    mathint debited = sharesBefore - currentContract._userPositions[user][collateralId].suppliedShares;
    uint256 debitValue = removeByShares(hub, assetId, assert_uint256(debited));

    // The user's collateral shares were never written (hook not firing)
    assert collateralWritten;
    // A liquidation fee was charged
    assert !feeCharged;
    // Supplied shares other than the user's collateral were written
    assert !otherSupplyWrite;
    // The debited shares were not removed in full to the liquidator
    assert debited > 0 => (removeCount == 1 && removeHub == hub && removeAsset == assetId
        && removeTo == e.msg.sender && removeAmount == debitValue);
    // Collateral removed without a share debit
    assert debited == 0 => removeCount == 0;
    // Reported amount does not match the share debit
    assert collateralAmountRemoved == debitValue;
}

// Deficit is reported, for the user, iff the collateral is emptied while debt remains in any borrowed reserve.
rule deficitIffCollateralEmptiedWithDebt(env e, uint256 debtReserveId, uint256 debtToCover, address user, uint256 maxCollateralToRemove) {
    setup(user, debtReserveId);
    uint256 collateralId = MANAGED_COLLATERAL_RESERVE_ID();
    bool otherDebt = otherBorrowed(user, debtReserveId);

    liquidationCall(e, debtReserveId, debtToCover, user, maxCollateralToRemove);

    // Check if the collateral is emptied and if debt remains.
    bool emptied = currentContract._userPositions[user][collateralId].suppliedShares == 0;
    bool debtRemains = currentContract._userPositions[user][debtReserveId].drawnShares > 0;

    // Deficit reporting does not match "collateral emptied while debt remains"
    assert deficitCount == (emptied && (debtRemains || otherDebt) ? 1 : 0);
    // Deficit reported for another user
    assert deficitCount > 0 => deficitUser == user;
}