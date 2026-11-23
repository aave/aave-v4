// Property 4: check settlement writes, transfer and Hub call arguments, and the deficit decision.
// At most four listed reserves. Sizing results are arbitrary; the rules check successful calls.
// Hub and token effects, premium refresh and deficit debt clearing are omitted.
methods {
    function MANAGED_COLLATERAL_RESERVE_ID() external returns (uint256) envfree;

    // Remove raw read-only storage accessors from the scene to allow storage splitting.
    function _.extSload(bytes32) external => NONDET DELETE;
    function _.extSloads(bytes32[]) external => NONDET DELETE;

    // Return arbitrary bonus, asset-unit and debt-arithmetic results; keep settlement share writes.
    function _.calculateLiquidationBonus(uint256, uint256, uint256, uint256) external => NONDET;
    function LiquidationLogic.calculateLiquidationBonus(uint256, uint256, uint256, uint256) internal returns (uint256) => NONDET;
    function MathUtils.uncheckedExp(uint256, uint256) internal returns (uint256) => NONDET;
    function WadRayMath.rayMulUp(uint256, uint256) internal returns (uint256) => NONDET;
    function Premium.calculatePremiumRay(uint256, int256, uint256) internal returns (uint256) => NONDET;

    // Omit post-settlement premium refresh, which can update premium fields in other borrowed reserves.
    // otherDebtWrite therefore checks settlement writes only.
    function Spoke._notifyRiskPremiumUpdate(address, uint256) internal => NONDET;

    // Return arbitrary prices, drawn indexes and cap-to-share conversions without changing storage.
    function _.getReservePrice(uint256) external => NONDET;
    function _.getAssetDrawnIndex(uint256) external => NONDET;
    function _.previewAddByAssets(uint256, uint256) external => NONDET;

    // Arbitrary liquidation amounts and premium delta.
    function BabylonLiquidationLogic._calculateLiquidationAmounts(BabylonLiquidationLogic.CalculateLiquidationAmountsParams memory) internal returns (BabylonLiquidationLogic.LiquidationAmounts memory)
        => arbitraryLiquidationAmounts();
    function UserPositionUtils.calculatePremiumDelta(ISpoke.UserPosition storage, uint256, uint256, uint256, uint256) internal returns (IHubBase.PremiumDelta memory)
        => arbitraryPremiumDelta();

    // Bound activeCollateralCount by one and count borrowing bits; leave other account fields arbitrary.
    function Spoke._calculateUserAccountData(address user) internal returns (ISpoke.UserAccountData memory)
        => accountData(user);

    // Model the share conversion and record Hub/token calls without executing them or their callbacks.
    function _.previewRemoveByShares(uint256 assetId, uint256 shares) external
        => removeByShares(calledContract, assetId, shares) expect uint256;
    function _.remove(uint256 assetId, uint256 amount, address to) external 
        => recordRemove(calledContract, assetId, amount, to) expect uint256;
    function _.payFeeShares(uint256, uint256) external 
        => recordFee() expect void;
    // Record the notifyReportDeficit call; omit its debt clearing so post-call reads show debt after repayment.
    function LiquidationLogic.notifyReportDeficit(mapping(uint256 => ISpoke.Reserve) storage, mapping(address => mapping(uint256 => ISpoke.UserPosition)) storage, mapping(address => ISpoke.PositionStatus) storage, uint256, address user) external
        => recordDeficit(user);
    function _.restore(uint256 assetId, uint256, IHubBase.PremiumDelta) external
        => recordRestore(calledContract, assetId) expect uint256;
    function _.safeTransferFrom(address token, address from, address to, uint256) internal
        => recordPull(token, from, to) expect void;

    unresolved external in _._ => DISPATCH [] default ASSERT_FALSE;
}


definition MAX_RESERVES() returns uint256 = 4;

// Arbitrary conversion result, fixed per (hub, asset, shares); no Hub conversion formula is assumed.
ghost removeByShares(address, uint256, uint256) returns uint256;

// Identify the tracked positions and flag writes to any other user's or reserve's position.
persistent ghost address trackedUser;
persistent ghost uint256 trackedCollateral;
persistent ghost uint256 trackedDebt;
persistent ghost bool otherSupplyWrite;
persistent ghost bool otherDebtWrite;
// Record whether suppliedShares and drawnShares were written in the tracked positions.
persistent ghost bool collateralWritten;
persistent ghost bool debtWritten;

// Count calls and record their arguments; feeCharged records whether payFeeShares was called.
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


function arbitraryLiquidationAmounts() returns BabylonLiquidationLogic.LiquidationAmounts {
    BabylonLiquidationLogic.LiquidationAmounts result;
    return result;
}

function arbitraryPremiumDelta() returns IHubBase.PremiumDelta {
    IHubBase.PremiumDelta result;
    return result;
}

// Read borrowing bit 2r for listed reserve IDs 0..3; return false for other IDs.
function borrowed(address user, uint256 r) returns bool {
    uint256 word = currentContract._positionStatus[user].map[0];
    if (r >= currentContract._reserveCount) { return false; }
    if (r == 0) { return word % 2 == 1; }
    if (r == 1) { return (word / 4) % 2 == 1; }
    if (r == 2) { return (word / 16) % 2 == 1; }
    if (r == 3) { return (word / 64) % 2 == 1; }
    return false;
}

// Count borrowing bits for the four-reserve scope and assume at most one active collateral reserve.
function accountData(address user) returns ISpoke.UserAccountData {
    ISpoke.UserAccountData result;
    require result.activeCollateralCount <= 1, "Property 1: only the managed reserve can be collateral.";
    require to_mathint(result.borrowCount) == (borrowed(user, 0) ? 1 : 0) + (borrowed(user, 1) ? 1 : 0)
        + (borrowed(user, 2) ? 1 : 0) + (borrowed(user, 3) ? 1 : 0), "Real count of borrowed listed reserves.";
    return result;
}

// Count notifyReportDeficit calls and record the last user.
function recordDeficit(address u) {
    deficitCount = deficitCount + 1;
    deficitUser = u;
}

// Count remove calls, record the last arguments and return arbitrary shares.
function recordRemove(address hub, uint256 assetId, uint256 amount, address to) returns uint256 {
    removeCount = removeCount + 1;
    removeHub = hub;
    removeAsset = assetId;
    removeAmount = amount;
    removeTo = to;
    uint256 shares;
    return shares;
}

// Record whether payFeeShares was called.
function recordFee() {
    feeCharged = true;
}

// Count restore calls, record the last Hub and asset and return arbitrary shares.
function recordRestore(address hub, uint256 assetId) returns uint256 {
    restoreCount = restoreCount + 1;
    restoreHub = hub;
    restoreAsset = assetId;
    uint256 shares;
    return shares;
}

// Count safeTransferFrom calls and record the last token, sender and recipient.
function recordPull(address token, address from, address to) {
    pullCount = pullCount + 1;
    pullToken = token;
    pullFrom = from;
    pullTo = to;
}

// Track writes to the user's collateral shares and flag writes to any other suppliedShares field.
hook Sstore currentContract._userPositions[KEY address u][KEY uint256 r].suppliedShares uint120 newValue {
    if (u != trackedUser || r != trackedCollateral) { otherSupplyWrite = true; } else { collateralWritten = true; }
}

// Track writes to the user's debt shares and flag writes to any other drawnShares field.
hook Sstore currentContract._userPositions[KEY address u][KEY uint256 r].drawnShares uint120 newValue {
    if (u != trackedUser || r != trackedDebt) { otherDebtWrite = true; } else { debtWritten = true; }
}

// Flag premium-share writes outside the tracked debt position.
hook Sstore currentContract._userPositions[KEY address u][KEY uint256 r].premiumShares uint120 newValue {
    if (u != trackedUser || r != trackedDebt) { otherDebtWrite = true; }
}

// Flag premium-offset writes outside the tracked debt position.
hook Sstore currentContract._userPositions[KEY address u][KEY uint256 r].premiumOffsetRay int200 newValue {
    if (u != trackedUser || r != trackedDebt) { otherDebtWrite = true; }
}

// Check for another listed reserve with its borrowing bit set, within IDs 0..3.
function otherBorrowed(address user, uint256 debtId) returns bool {
    return (debtId != 0 && borrowed(user, 0)) || (debtId != 1 && borrowed(user, 1))
        || (debtId != 2 && borrowed(user, 2)) || (debtId != 3 && borrowed(user, 3));
}

// Restrict the initial state and reset the write and call observations.
function setup(address user, uint256 debtReserveId) {
    require currentContract._reserveCount <= MAX_RESERVES(), "Proof scope: at most four reserves.";
    require debtReserveId < currentContract._reserveCount, "Spoke validReserveId: only listed reserves have a hub.";
    // Assume positive drawn shares imply a borrowing bit for this debt reserve; this rule does not prove it.
    require currentContract._userPositions[user][debtReserveId].drawnShares > 0 => borrowed(user, debtReserveId), "Spoke invariant: drawn shares imply the borrowing bit.";

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

// Check repayment call targets and restrict debt writes to the user's debtReserveId position.
rule repaymentSettlesOnlyDebtReserve(env e, uint256 debtReserveId, uint256 debtToCover, address user, uint256 maxCollateralToRemove) {
    setup(user, debtReserveId);
    address debtHub = currentContract._reserves[debtReserveId].hub;
    uint256 debtAssetId = currentContract._reserves[debtReserveId].assetId;
    address debtUnderlying = currentContract._reserves[debtReserveId].underlying;

    liquidationCall(e, debtReserveId, debtToCover, user, maxCollateralToRemove);

    // Exactly one transfer is requested from the liquidator to the debt Hub, using the debt reserve's token.
    assert pullCount == 1 && pullFrom == e.msg.sender && pullToken == debtUnderlying && pullTo == debtHub;
    // restore is called exactly once for the debt reserve's Hub and asset.
    assert restoreCount == 1 && restoreHub == debtHub && restoreAsset == debtAssetId;
    // The user's drawn shares in the debt reserve must be written.
    assert debtWritten;
    // Drawn shares and premium fields are written only in the user's debt reserve position.
    assert !otherDebtWrite;
}

// Match the collateral debit to the remove call and returned amount; exclude fee calls and other supply writes.
rule collateralDebitSentToLiquidator(env e, uint256 debtReserveId, uint256 debtToCover, address user, uint256 maxCollateralToRemove) {
    setup(user, debtReserveId);
    uint256 collateralId = MANAGED_COLLATERAL_RESERVE_ID();
    address hub = currentContract._reserves[collateralId].hub;
    uint256 assetId = currentContract._reserves[collateralId].assetId;
    mathint sharesBefore = currentContract._userPositions[user][collateralId].suppliedShares;

    uint256 liquidationBonus;
    uint256 collateralAmountRemoved;
    liquidationBonus, collateralAmountRemoved = liquidationCall(e, debtReserveId, debtToCover, user, maxCollateralToRemove);

    // Value the share debit using the same conversion summary as liquidation.
    mathint debited = sharesBefore - currentContract._userPositions[user][collateralId].suppliedShares;
    uint256 debitValue = removeByShares(hub, assetId, assert_uint256(debited));

    // The user's supplied shares in the collateral reserve must be written.
    assert collateralWritten;
    // No payFeeShares call occurs.
    assert !feeCharged;
    // Supplied shares are written only in the user's collateral position.
    assert !otherSupplyWrite;
    // A positive share debit requests one removal of its full asset value from the collateral Hub to the liquidator.
    assert debited > 0 => (removeCount == 1 && removeHub == hub && removeAsset == assetId
        && removeTo == e.msg.sender && removeAmount == debitValue);
    // No collateral removal is requested when no shares are debited.
    assert debited == 0 => removeCount == 0;
    // The returned asset amount equals the converted share debit.
    assert collateralAmountRemoved == debitValue;
}

// Call notifyReportDeficit iff collateral is empty and either drawn shares remain or another borrowing bit was set.
rule deficitIffCollateralEmptiedWithDebt(env e, uint256 debtReserveId, uint256 debtToCover, address user, uint256 maxCollateralToRemove) {
    setup(user, debtReserveId);
    uint256 collateralId = MANAGED_COLLATERAL_RESERVE_ID();
    bool otherDebt = otherBorrowed(user, debtReserveId);

    liquidationCall(e, debtReserveId, debtToCover, user, maxCollateralToRemove);

    // Read the remaining collateral and drawn shares before any deficit debt clearing.
    bool emptied = currentContract._userPositions[user][collateralId].suppliedShares == 0;
    bool debtRemains = currentContract._userPositions[user][debtReserveId].drawnShares > 0;

    // Report once iff collateral is empty and either this reserve has drawn shares or another has a borrowing bit.
    assert deficitCount == (emptied && (debtRemains || otherDebt) ? 1 : 0);
    // Any report must target the liquidated user.
    assert deficitCount > 0 => deficitUser == user;
}
