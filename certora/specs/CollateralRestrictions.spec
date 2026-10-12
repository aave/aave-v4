/*
 * Property 1 in certora/ppties.md; assumes Spoke reserve validity.
 * Real BabylonSpoke entry points, bitmap operations, counts and reserve guards.
 * Bounded to <= 4 listed reserves and <= 4 signed manager updates per call.
 */
import "./helpers/BitMath.spec";

using BabylonSpokeHarness as spoke;

methods {
    function getReserveCount() external returns (uint256) envfree;
    function MAX_USER_RESERVES_LIMIT() external returns (uint16) envfree;
    function MANAGED_COLLATERAL_RESERVE_ID() external returns (uint256) envfree;
    function harnessIsCollateral(address,uint256) external returns (bool) envfree;
    function harnessIsBorrowing(address,uint256) external returns (bool) envfree;
    function harnessCollateralCount(address) external returns (uint256) envfree;
    function harnessBorrowCount(address) external returns (uint256) envfree;
    function harnessIsBorrowable(uint256) external returns (bool) envfree;

    // Premium notification writes riskPremium/premiumShares/premiumOffsetRay, never map
    // bits, reserve flags, reserve hubs or reserveCount.
    // Its external callbacks are excluded by the same external-call model used below.
    function Spoke._notifyRiskPremiumUpdate(address user, uint256 newRiskPremium) internal  => NONDET;
    function Premium.calculatePremiumRay(uint256,int256,uint256) internal returns (uint256)  => NONDET;
    // Only premiumShares/premiumOffsetRay are written by this helper. Keep the
    // subsequent drawnShares subtraction and setBorrowing(false) concrete.
    function UserPositionUtils.applyPremiumDelta(ISpoke.UserPosition storage position, IHubBase.PremiumDelta memory delta) internal
        => NONDET;
    // Pure pricing used by liquidation and the liquidation-bonus getter.
    function _.calculateLiquidationBonus(uint256,uint256,uint256,uint256)
        external => NONDET;
    function LiquidationLogic.calculateLiquidationBonus(uint256,uint256,uint256,uint256)
        internal returns (uint256) => NONDET;
    // Arbitrary external results, without callbacks into the Spoke.
    function _.decimals() external => NONDET;
    function _.getAssetUnderlyingAndDecimals(uint256) external => NONDET;
    function _.getReservePrice(uint256) external => NONDET;
    function _.getAssetDrawnIndex(uint256) external => NONDET;
    function _.previewAddByAssets(uint256,uint256) external => NONDET;
    function _.previewRemoveByShares(uint256,uint256) external => NONDET;
    function _.add(uint256,uint256) external => NONDET;
    function _.draw(uint256,uint256,address) external => NONDET;
    function _.remove(uint256,uint256,address) external => NONDET;
    function _.restore(uint256,uint256,IHubBase.PremiumDelta) external => NONDET;
    function _.reportDeficit(uint256,uint256,IHubBase.PremiumDelta) external => NONDET;
    function _.setReserveSource(uint256,address) external => NONDET;
    function _.consumeScheduledOp(address,bytes) external => NONDET;
    function _.permit(address,address,uint256,uint256,uint8,bytes32,bytes32) external => NONDET;
    function _.safeTransferFrom(address,address,address,uint256) internal => NONDET;
    function _.safeTransfer(address,address,uint256) internal => NONDET;
    function AuthorityUtils.canCallWithDelay(address,address,address,bytes4) internal returns (bool,uint32)
        => NONDET;
    function SignatureChecker.isValidSignatureNowCalldata(address,bytes32,bytes calldata) internal returns (bool)
        => NONDET;
    // Over-approximate accounting arithmetic only.
    function MathUtils.uncheckedExp(uint256,uint256) internal returns (uint256) => NONDET;
    function WadRayMath.rayMulUp(uint256,uint256) internal returns (uint256) => NONDET;
    // View-only raw readers are not invariant transitions and inhibit storage splitting.
    function _.extSload(bytes32) external => NONDET DELETE;
    function _.extSloads(bytes32[]) external => NONDET DELETE;

    // Exact bit-search model, independently proved by BitMathEquivalence.conf.
    // All bitmap writes, masks, counts and reserve guards remain concrete.
    function LibBit.fls(uint256 word) internal returns (uint256) => exactFls(word);

    // Keep _refreshAndValidateUserAccountData's real health-factor guard.
    function UserPositionUtils.calculatePremiumDelta(ISpoke.UserPosition storage position, uint256 sharesTaken, uint256 index,uint256 riskPremium, uint256 restoredPremiumRay) internal returns (IHubBase.PremiumDelta memory)
        => restrictionOnlyPremiumDelta();
    // Read-only sizing arithmetic, with arbitrary unsigned results. The real
    // validation, share updates, debt clearing and deficit handling remain.
    function BabylonLiquidationLogic._calculateLiquidationAmounts(BabylonLiquidationLogic.CalculateLiquidationAmountsParams memory params) internal returns (BabylonLiquidationLogic.LiquidationAmounts memory)
        => arbitraryLiquidationAmounts();
    // Property-specific frame abstraction. _processUserAccountData only reads
    // restriction state and may write UserPosition.dynamicConfigKey.
    function Spoke._processUserAccountData(address user, bool refreshConfig) internal returns (ISpoke.UserAccountData memory)
        => arbitraryAccountData();

    // Fail on missing models rather than silently havocing library delegatecalls.
    unresolved external in _._ => DISPATCH [] default ASSERT_FALSE;
}

definition MAX_RESERVES() returns uint256 = 4;

function arbitraryAccountData() returns ISpoke.UserAccountData {
    ISpoke.UserAccountData result;
    return result;
}

function arbitraryLiquidationAmounts() returns BabylonLiquidationLogic.LiquidationAmounts {
    BabylonLiquidationLogic.LiquidationAmounts result;
    return result;
}

// Signed payload is unobserved (NONDET Hub calls, no-op applyPremiumDelta, events), so zero represents it.
// restoredPremiumRay is unconstrained; the signed fields are fixed to avoid symbolic signed-field encoding issues.
function restrictionOnlyPremiumDelta() returns IHubBase.PremiumDelta {
    IHubBase.PremiumDelta result;
    require result.sharesDelta == 0, "Unobserved payload; its consumers are summarized.";
    require result.offsetRayDelta == 0, "Unobserved payload; its consumers are summarized.";
    return result;
}

// Spoke reserve-validity facts and Babylon's constructor-set limit are assumed here.
function setup() {
    require spoke._reserveCount <= MAX_RESERVES(), "Proof scope: at most four reserves.";
    require MAX_USER_RESERVES_LIMIT() == 1, "Set by the BabylonSpoke constructor.";
}

// Only the managed reserve can be enabled as collateral among listed reserves.
invariant onlyManagedCollateral(address user, uint256 reserveId)
    reserveId < getReserveCount() => (harnessIsCollateral(user, reserveId) => reserveId == MANAGED_COLLATERAL_RESERVE_ID())
    filtered { f -> f.selector != sig:multicall(bytes[]).selector }
{
    preserved {
        setup();
        require reserveId >= getReserveCount() => (!harnessIsCollateral(user, reserveId) && !harnessIsBorrowing(user, reserveId)), "Spoke validReserveId: unlisted reserves have no position flags.";
    }
    preserved liquidationCall(uint256 debtId, uint256 cover, address liquidatedUser, uint256 cap) with (env e) {
        setup();
    }
    preserved setUserPositionManagersWithSig(ISpoke.SetUserPositionManagers params, bytes signature) with (env e) {
        setup();
    }
}

// With at most four listed reserves, each user has at most one enabled as collateral.
invariant collateralCountAtMostOne(address user)
    getReserveCount() <= MAX_RESERVES() => harnessCollateralCount(user) <= 1
    filtered { f -> f.selector != sig:multicall(bytes[]).selector }
{
    preserved {
        setup();
        // Newly listed reserves must start with no position flags.
        require (!harnessIsCollateral(user, spoke._reserveCount) && !harnessIsBorrowing(user, spoke._reserveCount)), "Spoke validReserveId: unlisted reserves have no position flags.";
    }
    preserved liquidationCall(uint256 debtId, uint256 cover, address liquidatedUser, uint256 cap) with (env e) {
        setup();
    }
    preserved setUserPositionManagersWithSig(ISpoke.SetUserPositionManagers params, bytes signature) with (env e) {
        setup();
    }
}

// With at most four listed reserves, each user borrows at most one reserve.
invariant borrowCountAtMostOne(address user)
    getReserveCount() <= MAX_RESERVES() => harnessBorrowCount(user) <= 1
    filtered { f -> f.selector != sig:multicall(bytes[]).selector }
{
    preserved {
        setup();
        // Newly listed reserves must start with no position flags.
        require (!harnessIsCollateral(user, spoke._reserveCount) && !harnessIsBorrowing(user, spoke._reserveCount)), "Spoke validReserveId: unlisted reserves have no position flags.";
    }
    preserved liquidationCall(uint256 debtId, uint256 cover, address liquidatedUser, uint256 cap) with (env e) {
        setup();
    }
    preserved setUserPositionManagersWithSig(ISpoke.SetUserPositionManagers params, bytes signature) with (env e) {
        setup();
    }
}

// The managed reserve's borrowable flag is always disabled.
invariant managedReserveNeverBorrowable()
    !harnessIsBorrowable(MANAGED_COLLATERAL_RESERVE_ID())
    filtered { f -> f.selector != sig:multicall(bytes[]).selector }
{
    preserved {
        setup();
    }
}

// No user has the borrowing flag set for the managed reserve when it is listed.
invariant managedReserveNeverBorrowed(address user)
    MANAGED_COLLATERAL_RESERVE_ID() < getReserveCount() => !harnessIsBorrowing(user, MANAGED_COLLATERAL_RESERVE_ID())
    filtered { f -> f.selector != sig:multicall(bytes[]).selector }
{
    preserved {
        setup();
        // Newly listed reserves must start with no position flags.
        require MANAGED_COLLATERAL_RESERVE_ID() >= getReserveCount() => (!harnessIsCollateral(user, MANAGED_COLLATERAL_RESERVE_ID()) && !harnessIsBorrowing(user, MANAGED_COLLATERAL_RESERVE_ID())), "Spoke validReserveId: unlisted reserves have no position flags.";
        // The managed reserve's borrowable flag is always disabled.
        requireInvariant managedReserveNeverBorrowable();
    }
    preserved liquidationCall(uint256 debtId, uint256 cover, address liquidatedUser, uint256 cap) with (env e) {
        setup();
    }
    preserved setUserPositionManagersWithSig(ISpoke.SetUserPositionManagers params, bytes signature) with (env e) {
        setup();
    }
}
