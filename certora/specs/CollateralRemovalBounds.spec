// Property 3: removed collateral respects maxCollateralToRemove and the user's supply; shares drop accordingly.
// Assumes the collateral reserve's hub is the Aave Hub (its added-asset share conversion is modeled below).

methods {
    function MANAGED_COLLATERAL_RESERVE_ID() external returns (uint256) envfree;

    // Raw readers are outside the rule and prevent storage splitting.
    function _.extSload(bytes32) external => NONDET DELETE;
    function _.extSloads(bytes32[]) external => NONDET DELETE;

    // Run after the collateral update and never write suppliedShares; dropping their effects and reverts only adds paths.
    function Spoke._notifyRiskPremiumUpdate(address, uint256) internal => NONDET;
    function LiquidationLogic.notifyReportDeficit(mapping(uint256 => ISpoke.Reserve) storage, mapping(address => mapping(uint256 => ISpoke.UserPosition)) storage, mapping(address => ISpoke.PositionStatus) storage, uint256, address) external => NONDET;
    function _.safeTransferFrom(address, address, address, uint256) internal => NONDET;

    // Pure/view pricing and premium math with arbitrary results; the cap, share update and removal stay concrete.
    function LiquidationLogic._calculateCollateralToLiquidate(LiquidationLogic.CalculateCollateralToLiquidateParams memory) internal returns (uint256) => NONDET;
    function LiquidationLogic.calculateLiquidationBonus(uint256, uint256, uint256, uint256) internal returns (uint256) => NONDET;
    function Math.mulDiv(uint256, uint256, uint256) internal returns (uint256) => NONDET;
    function Math.mulDiv(uint256, uint256, uint256, Math.Rounding) internal returns (uint256) => NONDET;
    function MathUtils.divUp(uint256, uint256) internal returns (uint256) => NONDET;
    function MathUtils.uncheckedExp(uint256, uint256) internal returns (uint256) => NONDET;
    function WadRayMath.rayMulUp(uint256, uint256) internal returns (uint256) => NONDET;
    function Premium.calculatePremiumRay(uint256, int256, uint256) internal returns (uint256) => NONDET;

    // Hub's added-asset conversions at a fixed rate per (hub, asset); a view call cannot change the rate.
    function _.previewAddByAssets(uint256 assetId, uint256 assets) external => hubAddByAssets(calledContract, assetId, assets) expect uint256;
    function _.previewRemoveByShares(uint256 assetId, uint256 shares) external => hubRemoveByShares(calledContract, assetId, shares) expect uint256;

    // Other view calls return arbitrary values; state-changing calls may change anything, including the rate ghosts.
    function _.previewAddByShares(uint256, uint256) external => NONDET;
    function _.getReservePrice(uint256) external => NONDET;
    function _.getAssetDrawnIndex(uint256) external => NONDET;
    function _.remove(uint256, uint256, address) external => HAVOC_ALL;
    function _.restore(uint256, uint256, IHubBase.PremiumDelta) external => HAVOC_ALL;

    // Read-only helpers with unconstrained results.
    function Spoke._calculateUserAccountData(address) internal returns (ISpoke.UserAccountData memory)
        => arbitraryAccountData();
    function UserPositionUtils.calculatePremiumDelta(ISpoke.UserPosition storage, uint256, uint256, uint256, uint256) internal returns (IHubBase.PremiumDelta memory)
        => arbitraryPremiumDelta();

    unresolved external in _._ => DISPATCH [] default ASSERT_FALSE;
}

// SharesMath VIRTUAL_ASSETS / VIRTUAL_SHARES.
definition VIRTUAL() returns mathint = 1000000;

// Hub totalAddedAssets and addedShares; havoced by state-changing calls.
ghost mapping(address => mapping(uint256 => uint256)) hubAssets;
ghost mapping(address => mapping(uint256 => uint256)) hubShares;

// Observed write of the liquidated user's collateral shares.
persistent ghost address trackedUser;
persistent ghost uint256 trackedReserve;
persistent ghost bool sharesWritten;
persistent ghost mathint sharesAfter;

hook Sstore currentContract._userPositions[KEY address u][KEY uint256 r].suppliedShares uint120 newShares {
    if (u == trackedUser && r == trackedReserve) {
        sharesWritten = true;
        sharesAfter = newShares;
    }
}

// Arbitrary account data.
function arbitraryAccountData() returns ISpoke.UserAccountData {
    ISpoke.UserAccountData result;
    return result;
}

// Arbitrary premium delta.
function arbitraryPremiumDelta() returns IHubBase.PremiumDelta {
    IHubBase.PremiumDelta result;
    return result;
}

// The real mulDiv reverts on a result above uint256, so those paths do not exist.
function hubAddByAssets(address hub, uint256 assetId, uint256 assets) returns uint256 {
    return require_uint256(assets * (hubShares[hub][assetId] + VIRTUAL()) / (hubAssets[hub][assetId] + VIRTUAL()));
}

// Hub's removed-asset conversions at a fixed rate per (hub, asset) which cannot change the rate.
function hubRemoveByShares(address hub, uint256 assetId, uint256 shares) returns uint256 {
    return require_uint256(shares * (hubAssets[hub][assetId] + VIRTUAL()) / (hubShares[hub][assetId] + VIRTUAL()));
}

// Removed collateral respects maxCollateralToRemove and the user's supply, and shares drop accordingly.
rule collateralRemovalBounds(env e, uint256 debtReserveId, uint256 debtToCover, address user, uint256 maxCollateralToRemove) {
    uint256 collateralId = MANAGED_COLLATERAL_RESERVE_ID();
    address hub = currentContract._reserves[collateralId].hub;
    uint256 assetId = currentContract._reserves[collateralId].assetId;
    mathint sharesBefore = currentContract._userPositions[user][collateralId].suppliedShares;

    // Pre-call rate, the one seen by every preview before the first Hub state change.
    mathint rateAssets = hubAssets[hub][assetId] + VIRTUAL();
    mathint rateShares = hubShares[hub][assetId] + VIRTUAL();

    // Initialize the tracked user and reserve.
    trackedUser = user;
    trackedReserve = collateralId;
    sharesWritten = false;

    // Call the liquidation logic.
    uint256 liquidationBonus;
    uint256 collateralAmountRemoved;
    liquidationBonus, collateralAmountRemoved = liquidationCall(e, debtReserveId, debtToCover, user, maxCollateralToRemove);

    // Calculate the shares removed.
    mathint sharesRemoved = sharesBefore - sharesAfter;

    // Collateral shares not updated
    assert sharesWritten;
    // Removed more shares than supplied    
    assert 0 <= sharesRemoved && sharesRemoved <= sharesBefore;
    // Removed shares exceed the cap
    assert sharesRemoved <= maxCollateralToRemove * rateShares / rateAssets;
    // Reported amount does not match the share reduction
    assert collateralAmountRemoved == sharesRemoved * rateAssets / rateShares;
    // Removed amount exceeds maxCollateralToRemove
    assert collateralAmountRemoved <= maxCollateralToRemove;
    // Removed amount exceeds supplied collateral
    assert collateralAmountRemoved <= sharesBefore * rateAssets / rateShares;
}

// User's collateral value drops by at most maxCollateralToRemove.
// Reuses CollateralRemovalBounds.spec's summaries, ghosts and suppliedShares hook; its rule is not re-run here.
rule collateralValueDrop(env e, uint256 debtReserveId, uint256 debtToCover, address user, uint256 maxCollateralToRemove) {
    
    uint256 collateralId = MANAGED_COLLATERAL_RESERVE_ID();
    address hub = currentContract._reserves[collateralId].hub;
    uint256 assetId = currentContract._reserves[collateralId].assetId;
    mathint sharesBefore = currentContract._userPositions[user][collateralId].suppliedShares;

    // Both values use the pre-call Hub rate.
    mathint rateAssets = hubAssets[hub][assetId] + VIRTUAL();
    mathint rateShares = hubShares[hub][assetId] + VIRTUAL();

    trackedUser = user;
    trackedReserve = collateralId;
    sharesWritten = false;

    // Call the liquidation logic.
    liquidationCall(e, debtReserveId, debtToCover, user, maxCollateralToRemove);

    // Collateral shares not updated (hook not firing would make the bound trivial)
    assert sharesWritten;
    // Verify that the user's collateral value didn't drop by more than maxCollateralToRemove.
    assert sharesBefore * rateAssets / rateShares - sharesAfter * rateAssets / rateShares <= maxCollateralToRemove;
}
