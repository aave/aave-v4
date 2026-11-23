// Property 3: bound the recorded collateral share debit and returned asset amount.
// Hub previews use Aave's added-asset conversion formulas.

methods {
    function MANAGED_COLLATERAL_RESERVE_ID() external returns (uint256) envfree;

    // Remove raw read-only storage accessors from the scene to allow storage splitting.
    function _.extSload(bytes32) external => NONDET DELETE;
    function _.extSloads(bytes32[]) external => NONDET DELETE;

    // Omit these calls' effects; they occur after the tracked collateral write.
    function Spoke._notifyRiskPremiumUpdate(address, uint256) internal => NONDET;
    function LiquidationLogic.notifyReportDeficit(mapping(uint256 => ISpoke.Reserve) storage, mapping(address => mapping(uint256 => ISpoke.UserPosition)) storage, mapping(address => ISpoke.PositionStatus) storage, uint256, address) external => NONDET;
    function _.safeTransferFrom(address, address, address, uint256) internal => NONDET;

    // Return arbitrary pricing and premium results; keep the collateral cap and share subtraction.
    function LiquidationLogic._calculateCollateralToLiquidate(LiquidationLogic.CalculateCollateralToLiquidateParams memory) internal returns (uint256) => NONDET;
    function LiquidationLogic.calculateLiquidationBonus(uint256, uint256, uint256, uint256) internal returns (uint256) => NONDET;
    function Math.mulDiv(uint256, uint256, uint256) internal returns (uint256) => NONDET;
    function Math.mulDiv(uint256, uint256, uint256, Math.Rounding) internal returns (uint256) => NONDET;
    function MathUtils.divUp(uint256, uint256) internal returns (uint256) => NONDET;
    function MathUtils.uncheckedExp(uint256, uint256) internal returns (uint256) => NONDET;
    function WadRayMath.rayMulUp(uint256, uint256) internal returns (uint256) => NONDET;
    function Premium.calculatePremiumRay(uint256, int256, uint256) internal returns (uint256) => NONDET;

    // Both previews round down using the same totals for each (hub, asset).
    function _.previewAddByAssets(uint256 assetId, uint256 assets) external => hubAddByAssets(calledContract, assetId, assets) expect uint256;
    function _.previewRemoveByShares(uint256 assetId, uint256 shares) external => hubRemoveByShares(calledContract, assetId, shares) expect uint256;

    // Return arbitrary values from the remaining views.
    function _.previewAddByShares(uint256, uint256) external => NONDET;
    function _.getReservePrice(uint256) external => NONDET;
    function _.getAssetDrawnIndex(uint256) external => NONDET;
    // Havoc contract storage and non-persistent ghosts, including the Hub totals.
    function _.remove(uint256, uint256, address) external => HAVOC_ALL;
    function _.restore(uint256, uint256, IHubBase.PremiumDelta) external => HAVOC_ALL;

    // Read-only helpers with unconstrained results.
    function Spoke._calculateUserAccountData(address) internal returns (ISpoke.UserAccountData memory)
        => arbitraryAccountData();
    function UserPositionUtils.calculatePremiumDelta(ISpoke.UserPosition storage, uint256, uint256, uint256, uint256) internal returns (IHubBase.PremiumDelta memory)
        => arbitraryPremiumDelta();

    unresolved external in _._ => DISPATCH [] default ASSERT_FALSE;
}

// Both SharesMath virtual offsets are 10^6.
definition VIRTUAL() returns mathint = 1000000;

// Model Hub totalAddedAssets and addedShares; HAVOC_ALL can change these totals.
ghost mapping(address => mapping(uint256 => uint256)) hubAssets;
ghost mapping(address => mapping(uint256 => uint256)) hubShares;

// Record the last collateral share write; retain it across HAVOC_ALL calls.
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

function arbitraryAccountData() returns ISpoke.UserAccountData {
    ISpoke.UserAccountData result;
    return result;
}

function arbitraryPremiumDelta() returns IHubBase.PremiumDelta {
    IHubBase.PremiumDelta result;
    return result;
}

// Convert assets to shares, rounding down; discard results above uint256 as mulDiv would revert.
function hubAddByAssets(address hub, uint256 assetId, uint256 assets) returns uint256 {
    return require_uint256(assets * (hubShares[hub][assetId] + VIRTUAL()) / (hubAssets[hub][assetId] + VIRTUAL()));
}

// Convert shares to assets, rounding down with the same Hub totals.
function hubRemoveByShares(address hub, uint256 assetId, uint256 shares) returns uint256 {
    return require_uint256(shares * (hubAssets[hub][assetId] + VIRTUAL()) / (hubShares[hub][assetId] + VIRTUAL()));
}

// Bound the recorded share debit and returned assets at the pre-call Hub rate.
rule collateralRemovalBounds(env e, uint256 debtReserveId, uint256 debtToCover, address user, uint256 maxCollateralToRemove) {
    uint256 collateralId = MANAGED_COLLATERAL_RESERVE_ID();
    address hub = currentContract._reserves[collateralId].hub;
    uint256 assetId = currentContract._reserves[collateralId].assetId;
    mathint sharesBefore = currentContract._userPositions[user][collateralId].suppliedShares;

    // Snapshot the Hub totals before any HAVOC_ALL call.
    mathint rateAssets = hubAssets[hub][assetId] + VIRTUAL();
    mathint rateShares = hubShares[hub][assetId] + VIRTUAL();

    trackedUser = user;
    trackedReserve = collateralId;
    sharesWritten = false;

    uint256 liquidationBonus;
    uint256 collateralAmountRemoved;
    liquidationBonus, collateralAmountRemoved = liquidationCall(e, debtReserveId, debtToCover, user, maxCollateralToRemove);

    // Use the recorded write, since later HAVOC_ALL calls can change storage.
    mathint sharesRemoved = sharesBefore - sharesAfter;

    // The collateral share hook must have recorded a write.
    assert sharesWritten;
    // The share debit is nonnegative and does not exceed the user's supplied shares.
    assert 0 <= sharesRemoved && sharesRemoved <= sharesBefore;
    // The share debit is at most the cap converted to shares, rounded down.
    assert sharesRemoved <= maxCollateralToRemove * rateShares / rateAssets;
    // Returned assets equal the share debit converted to assets, rounded down.
    assert collateralAmountRemoved == sharesRemoved * rateAssets / rateShares;
    // Returned assets do not exceed the cap.
    assert collateralAmountRemoved <= maxCollateralToRemove;
    // Returned assets do not exceed the pre-call value of the supplied shares.
    assert collateralAmountRemoved <= sharesBefore * rateAssets / rateShares;
}

// Value the starting and recorded remaining shares at the pre-call Hub rate; the drop is at most the cap.
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

    liquidationCall(e, debtReserveId, debtToCover, user, maxCollateralToRemove);

    // The collateral share hook must have recorded a write.
    assert sharesWritten;
    // The collateral value drops by at most maxCollateralToRemove when both balances use the pre-call Hub rate.
    assert sharesBefore * rateAssets / rateShares - sharesAfter * rateAssets / rateShares <= maxCollateralToRemove;
}
