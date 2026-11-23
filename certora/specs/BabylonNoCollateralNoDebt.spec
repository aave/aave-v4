/*
 * No debt without collateral (BabylonSpoke, 4-argument liquidationCall)
 *
 * PROPERTY
 *   If a user had collateral whenever they had debt before a Babylon liquidationCall, that still
 *   holds after the call, including after deficit reporting.
 *
 * WHY THIS SPEC EXISTS
 *   BabylonSettlementAccounting.spec (deficitIffCollateralEmptiedWithDebt) checks that notifyReportDeficit
 *   is CALLED and summarizes away what it does. Upstream's noCollateralNoDebt excludes
 *   liquidationCall. Here notifyReportDeficit runs for real; the Hub is the upstream symbolic Hub (H).
 *
 * FORMALIZATION
 *   hasCollateral(u)  :=  _userPositions[u][MANAGED].suppliedShares > 0
 *                         && isUsingAsCollateral[u][MANAGED] (collateral bit, symbolic bitmap I)
 *                         && _dynamicConfig[MANAGED][u's dynamicConfigKey].collateralFactor > 0
 *   noDebt(u, r)      :=  _userPositions[u][r].drawnShares == 0
 *                         && _userPositions[u][r].premiumShares == 0
 *                         && _userPositions[u][r].premiumOffsetRay == 0
 *   Property for user u, for every reserve id r:   !hasCollateral(u) => noDebt(u, r)
 *
 *   Rule noCollateralNoDebtAfterLiquidation        the liquidated user, after any successful call.
 *   Rule liquidationKeepsNoCollateralNoDebtForOthers   any other user: assumed before, asserted after.
 *
 *   Rule liquidationReachableUnderRuleRequires     the vacuity check of both rules (satisfy), in place
 *                                                  of rule_sanity. Its pins apply to it only.
 *
 *   The rule for the liquidated user does NOT assume the property before the call. It is not needed:
 *   the call reverts unless the user has collateral (ReserveNotSupplied, ReserveNotEnabledAsCollateral),
 *   so "no collateral => no debt" is trivially true before every successful call. The rule is
 *   therefore stronger than the plain-English property.
 *
 * WHY STORAGE AND NOT getUserAccountData (upstream: totalCollateralValue == 0 => totalDebtValueRay == 0)
 *   - The code decides the deficit on shares (newUserSuppliedShares == 0), not on value.
 *   - Account data only counts debt of reserves whose borrowing bit is set. Debt left in a position
 *     without the bit would be invisible to it. Storage sees it.
 *   - Values go through the oracle price and the Hub share price. A storage statement holds for any
 *     price and any index, and "all three debt fields are zero" means zero drawn debt and zero
 *     premium debt at every index.
 *   - hasCollateral is exactly the condition under which Spoke._processUserAccountData counts a
 *     reserve as collateral. It looks at the managed reserve only: invariant onlyManagedCollateral
 *     (BabylonCollateralRestrictions.spec) proves no other listed reserve can be enabled as collateral.
 *   - "At most one debt reserve" (borrowCountAtMostOne) is used only as a loop bound (assumption
 *     2b). r still ranges over all reserve ids and the real deficit loop runs.
 *
 * SCENE (BabylonNoCollateralNoDebt.conf). The oracle and the token run their real code.
 *   - Spoke: BabylonSpokeAccountDataHarness = BabylonSpokeInstance + harnessAccountData (summary D).
 *     Its bitmap readers are not used: they would go through summary I and read userGhost's bits.
 *   - Hub: none. Summary H.
 *   - Token: the real OpenZeppelin ERC20, arbitrary balances and allowances, one instance for every
 *     asset. The Spoke never reads token state; tokens only add revert conditions. Fee-on-transfer
 *     or callback tokens are not modelled.
 *     ponytail: one shared token. Add a second instance and DISPATCHER if token identity matters.
 *   - Oracle: NoCollateralNoDebtOracle, one arbitrary non-zero price per reserve, constant during
 *     the call. A zero price reverts, as in AaveOracle.
 *
 * ASSUMPTIONS (every require in this file)
 *   1. getReserveCount() <= 4.  [proofScope]
 *      Scope of the proof. This is a real restriction: spokes with more than four listed reserves
 *      are not covered. Same bound as the sibling specs, and the bound under which the invariants
 *      restated in 2, 2b and 4 are proved.
 *   2. reserveCountGhost == (isUsingAsCollateral[user][MANAGED] ? 1 : 0).  [proofScope]
 *      reserveCountGhost is the symbolic bitmap's collateral count (summary I) of the liquidated user.
 *      Restates invariants collateralCountAtMostOne and onlyManagedCollateral
 *      (BabylonCollateralRestrictions.spec): the only collateral is the managed reserve.
 *      Needed: with a second active collateral, _evaluateDeficit reports no deficit when the managed
 *      collateral is emptied, and debt would remain. Also needed so that clearing the managed bit
 *      does not underflow the count (summary I requires it), which would hide the deficit path.
 *   2b. At most one borrowing bit: isBorrowing[user][a] && isBorrowing[user][b] => a == b.  [proofScope]
 *      Restates invariant borrowCountAtMostOne (BabylonCollateralRestrictions.spec).
 *      Needed for the loop bound only (loop_iter 3, optimistic_loop false). The loops over a user's
 *      reserves run once per flagged reserve plus once to exit, so three unrollings cover exactly
 *      one collateral and one debt reserve. Without it the rules fail on loop unwinding.
 *   3. drawnShares > 0 => borrowing bit set, for the liquidated user in debtReserveId and in r.
 *      Restates invariant borrowingFlagIffDrawnShares (BabylonBorrowingFlagConsistency.spec).
 *      Needed: borrowCount and the deficit loop only see reserves whose bit is set.
 *   4. borrowing bit set => reserve id < getReserveCount(), same positions.
 *      Restates invariant unlistedReserveIsEmpty (BabylonCollateralRestrictions.spec).
 *      Needed: both loops start below the reserve count.
 *   5. drawnShares == 0 => premiumShares == 0 && premiumOffsetRay == 0, same positions.
 *      Restates invariant drawnSharesZero (BabylonDrawnSharesZero.spec), checked on every
 *      BabylonSpoke function except multicall, 4-argument liquidationCall included.
 *      Needed: premium fields in a position without the borrowing bit are never cleared.
 *   6. otherUser != user in the second rule. A case split, not an assumption: the liquidated user
 *      is the first rule.
 *   7. activeCollateralCount returned by summary G <= reserveCountGhost.  [countsOnlyAccountData]
 *      Read from the code, not machine-checked: _processUserAccountData increments
 *      activeCollateralCount only for reserves below _reserveCount whose collateral bit is set, and
 *      the collateral count (reserveCountGhost, assumption 2) counts exactly those bits.
 *      Needed: with activeCollateralCount > 1, _evaluateDeficit skips the deficit and leaves the debt.
 *   8. userGhost == user (the liquidated user).  [proofScope]
 *      Summary I keeps the bits of one user, userGhost. Read from the code, not machine-checked:
 *      the Babylon liquidation reads and writes the bitmap of the liquidated user only (the
 *      liquidator's position gets supplied shares, never a bit). Upstream proves "one user per call"
 *      for SpokeInstance in SpokeUserIntegrity.spec.
 *
 * SUMMARIES (all of them)
 *   Why A to F exist: the Prover's memory analysis (pointer analysis) fails on four pieces of
 *   code reached by liquidationCall. In a function where it fails, no external call is resolved,
 *   library delegatecalls included, so nothing could be checked. Each piece is replaced by a
 *   summary that does the same thing. None of them invents or drops behaviour.
 *   G is the one summary that drops behaviour, to remove the timeout.
 *   A. KeyValueList.sortByKey => sortOfAtMostOneEntry.
 *      Why: OpenZeppelin's Arrays._quickSort is recursive and written in assembly.
 *      Soundness: it does nothing and ASSERTS the list has at most one entry. Sorting such a list
 *      changes nothing, so the summary is exact; a longer list fails the rule. Assumption 2 is what
 *      keeps the list that short.
 *   B, C, D. helpers/PointerAnalysisSummaries.spec (its summaries 1, 2 and 3): uncheckedAt, the two
 *      SafeERC20 transfers and _calculateUserAccountData. Each runs the same logic as the code it
 *      replaces; the reasons and the soundness argument are in that file.
 *   E. extSload / extSloads => NONDET DELETE (removed from the scene).
 *      Why: they sload a slot chosen by the caller, so the Prover's storage analysis of the Spoke
 *      fails, and without it CVL cannot read _userPositions or _dynamicConfig directly.
 *      Soundness: both are views that write nothing, and liquidationCall never calls them.
 *   F. unresolved external in _._ => ASSERT_FALSE.
 *      Any external call the Prover cannot resolve fails the rule instead of being havoced.
 *   G. Spoke._processUserAccountData => countsOnlyAccountData: arbitrary health factor, values and
 *      risk premium; activeCollateralCount bounded by assumption 7; borrowCount arbitrary.
 *      Why: the loop over the user's reserves (oracle price x shares x Hub index, sort, health
 *      factor, risk premium) carried about 40% of the nonlinear operations and 2 x 2^34 paths of
 *      the timed-out runs. Summary D still routes _calculateUserAccountData through harnessAccountData,
 *      which now lands here. A and B are no longer reached while G is active.
 *      Soundness: over-approximation. It writes only dynamicConfigKey, which nothing here reads.
 *      The deficit decision (_evaluateDeficit) reads only activeCollateralCount and borrowCount; the
 *      other fields size the liquidation, gate the health-factor revert and set the risk premium,
 *      so arbitrary values only add behaviours. An arbitrary borrowCount can only add deficit
 *      reports (borrowCount > 1), which zero debt.
 *      What it costs: a counterexample may use account data the real code cannot produce.
 *   H. The Hub is the upstream symbolic Hub (helpers/symbolicRepresentation/SymbolicHub.spec, copied
 *      unchanged), with its ERC20 model for the Hub's own transfers.
 *      Why: with the real Hub, its strategy and precise_bitwise_ops, the run spent 2 hours in the
 *      Prover's storage analysis and proved nothing.
 *      Soundness: the summaries write only CVL ghosts, never the Spoke. The property is about Spoke
 *      storage; the Spoke decides the deficit on its own share counts, and ignores the return
 *      values of reportDeficit and restore. The Hub's requires (amount > 0, shares > 0) match reverts
 *      of the real Hub.
 *   I. PositionStatusMap is the upstream symbolic bitmap
 *      (helpers/symbolicRepresentation/SymbolicPositionStatus.spec, copied unchanged), proved against
 *      PositionStatusMap.sol upstream (VerifySymbolicPositionStatus.conf). Replaces precise_bitwise_ops.
 *
 * NOT COVERED
 *   multicall, and every function other than the 4-argument liquidationCall.
 *   Re-entrancy from tokens, oracle or strategy (the scene contracts make no callbacks).
 */

import "./helpers/PointerAnalysisSummaries.spec";

// Summary H.
import "./helpers/symbolicRepresentation/SymbolicHub.spec";

// Summary I.
import "./helpers/symbolicRepresentation/SymbolicPositionStatus.spec";

using BabylonSpokeAccountDataHarness as spoke;
using NoCollateralNoDebtOracle as oracle;

// Used by SymbolicHub.spec (upstream defines it in common.spec).
persistent ghost uint256 RAY {
    axiom RAY == 10^27;
}

methods {
    function MANAGED_COLLATERAL_RESERVE_ID() external returns (uint256) envfree;
    function getReserveCount() external returns (uint256) envfree;

    // Summary A (see header).
    function KeyValueList.sortByKey(KeyValueList.List memory list) internal => sortOfAtMostOneEntry(list);

    // Summaries B, C and D are in helpers/PointerAnalysisSummaries.spec.

    // Summary E (see header).
    function _.extSload(bytes32) external => NONDET DELETE;
    function _.extSloads(bytes32[]) external => NONDET DELETE;

    // Summary F (see header).
    unresolved external in _._ => DISPATCH [] default ASSERT_FALSE;

    // Summary G (see header).
    function Spoke._processUserAccountData(address user, bool refreshConfig) internal returns (ISpoke.UserAccountData memory)
        => countsOnlyAccountData(user);
}

// Sorting a list of at most one entry is a no-op. Longer lists fail the rule instead of going unsorted.
function sortOfAtMostOneEntry(KeyValueList.List list) {
    assert list._inner.length <= 1, "sort summary is only exact for at most one entry";
}

// Summary G: everything arbitrary except the active collateral count (assumption 7).
function countsOnlyAccountData(address user) returns ISpoke.UserAccountData {
    ISpoke.UserAccountData result;
    require result.activeCollateralCount <= reserveCountGhost,
        "Read from _processUserAccountData: only reserves with the collateral bit set are counted.";
    return result;
}

// Zero drawn debt and zero premium debt, whatever the Hub's drawn index is.
definition noDebt(address user, uint256 reserveId) returns bool =
    spoke._userPositions[user][reserveId].drawnShares == 0
        && spoke._userPositions[user][reserveId].premiumShares == 0
        && spoke._userPositions[user][reserveId].premiumOffsetRay == 0;

// Premium fields are zero when there are no drawn shares (upstream invariant drawnSharesZero).
definition premiumBackedByDrawnShares(address user, uint256 reserveId) returns bool =
    spoke._userPositions[user][reserveId].drawnShares == 0 =>
        (spoke._userPositions[user][reserveId].premiumShares == 0
            && spoke._userPositions[user][reserveId].premiumOffsetRay == 0);

// The condition under which Spoke._processUserAccountData counts the managed reserve as collateral.
// Only the managed reserve is read: invariant onlyManagedCollateral (BabylonCollateralRestrictions.spec)
// proves no other listed reserve can be enabled as collateral.
function hasCollateral(address user) returns bool {
    uint256 managed = MANAGED_COLLATERAL_RESERVE_ID();
    uint32 configKey = spoke._userPositions[user][managed].dynamicConfigKey;
    return spoke._userPositions[user][managed].suppliedShares > 0
        && isUsingAsCollateral[user][managed]
        && spoke._dynamicConfig[managed][configKey].collateralFactor > 0;
}

// Assumptions 1, 2, 2b and 8.
function proofScope(address liquidatedUser) {
    require userGhost == liquidatedUser,
        "Assumption 8: the liquidation touches the bitmap of the liquidated user only.";
    require getReserveCount() <= 4,
        "Proof scope for loop unrolling: at most four listed reserves. Larger spokes are not covered.";
    require reserveCountGhost == (isUsingAsCollateral[liquidatedUser][MANAGED_COLLATERAL_RESERVE_ID()] ? 1 : 0),
        "Invariants collateralCountAtMostOne and onlyManagedCollateral (BabylonCollateralRestrictions.spec): the managed reserve is the only collateral.";
    require forall uint256 a. forall uint256 b. isBorrowing[liquidatedUser][a] && isBorrowing[liquidatedUser][b] => a == b,
        "Invariant borrowCountAtMostOne (BabylonCollateralRestrictions.spec): loop bound, three unrollings cover one collateral and one debt reserve.";
}

// Assumptions 3, 4 and 5 for one position of the liquidated user.
function provedPositionInvariants(address user, uint256 reserveId) {
    require spoke._userPositions[user][reserveId].drawnShares > 0 => isBorrowing[user][reserveId],
        "Invariant borrowingFlagIffDrawnShares (BabylonBorrowingFlagConsistency.spec): the deficit loop only visits flagged reserves.";
    require isBorrowing[user][reserveId] => reserveId < getReserveCount(),
        "Invariant unlistedReserveIsEmpty (BabylonCollateralRestrictions.spec): unlisted reserves carry no flag; the loops start below the count.";
    require premiumBackedByDrawnShares(user, reserveId),
        "Invariant drawnSharesZero (BabylonDrawnSharesZero.spec): unflagged premium is never cleared.";
}

// After a successful liquidation, the liquidated user has no debt in any reserve unless they still
// have collateral. The deficit reporting runs for real; the Hub is symbolic (summary H).
rule noCollateralNoDebtAfterLiquidation(env e, uint256 debtReserveId, uint256 debtToCover, address user, uint256 maxCollateralToRemove, uint256 reserveId) {
    proofScope(user);
    provedPositionInvariants(user, debtReserveId);
    provedPositionInvariants(user, reserveId);

    // No "no collateral => no debt" assumption here: the call reverts if the user has no collateral.
    liquidationCall(e, debtReserveId, debtToCover, user, maxCollateralToRemove);

    assert !hasCollateral(user) => noDebt(user, reserveId);
}

// Replaces rule_sanity, which is off in the conf: its witness search for the two rules above ran into
// the 2-hour limit in 3 of 4 runs. This is one successful liquidationCall that meets every require of
// both rules (reserveId = debtReserveId), so neither rule is vacuous. The "witness pin" requires fix the
// inputs so the solver checks one concrete run instead of searching. They are not assumptions of the
// two rules, and only this rule uses them.
rule liquidationReachableUnderRuleRequires(env e, uint256 debtReserveId, address user, address otherUser) {
    uint256 collId = MANAGED_COLLATERAL_RESERVE_ID();

    // The requires of noCollateralNoDebtAfterLiquidation.
    proofScope(user);
    provedPositionInvariants(user, debtReserveId);
    // The requires of liquidationKeepsNoCollateralNoDebtForOthers.
    require otherUser != user, "Same case split as liquidationKeepsNoCollateralNoDebtForOthers.";
    require !hasCollateral(otherUser) => noDebt(otherUser, debtReserveId), "Same assumption as liquidationKeepsNoCollateralNoDebtForOthers.";

    // Witness pins: two reserves, no accrual, one price, one decimals.
    require getReserveCount() == 2, "witness pin";
    require debtReserveId < 2 && collId < 2 && debtReserveId != collId, "witness pin";
    uint16 debtAsset = spoke._reserves[debtReserveId].assetId;
    uint16 collAsset = spoke._reserves[collId].assetId;
    require indexOfAssetPerBlock[debtAsset][e.block.timestamp] == RAY, "witness pin";
    require shareToAssetsRatio[debtAsset][e.block.timestamp] == RAY, "witness pin";
    require shareToAssetsRatio[collAsset][e.block.timestamp] == RAY, "witness pin";
    require spoke._reserves[debtReserveId].decimals == 18 && spoke._reserves[collId].decimals == 18, "witness pin";
    require spoke._reserves[debtReserveId].collateralRisk == 0 && spoke._reserves[collId].collateralRisk == 0, "witness pin";
    require oracle._prices[debtReserveId] == 10^8 && oracle._prices[collId] == 10^8, "witness pin";
    // Witness pins: one example configuration (collateral factor 80%, bonus from 105% to 110%, no fee).
    uint32 key = spoke._userPositions[user][collId].dynamicConfigKey;
    require spoke._dynamicConfig[collId][key].collateralFactor == 8000, "witness pin";
    require spoke._dynamicConfig[collId][key].maxLiquidationBonus == 11000, "witness pin";
    require spoke._dynamicConfig[collId][key].liquidationFee == 0, "witness pin";
    require spoke._liquidationConfig.liquidationBonusFactor == 5000, "witness pin";
    require spoke._liquidationConfig.healthFactorForMaxBonus == 5 * 10^17, "witness pin";
    // Witness pins: 100 collateral, 100 debt, no premium, repay 10.
    require spoke._userPositions[user][collId].suppliedShares == 10^20, "witness pin";
    require spoke._userPositions[user][debtReserveId].drawnShares == 10^20, "witness pin";
    require spoke._userPositions[user][debtReserveId].premiumShares == 0, "witness pin";
    require spoke._userPositions[user][debtReserveId].premiumOffsetRay == 0, "witness pin";

    liquidationCall(e, debtReserveId, 10^19, user, max_uint256);

    satisfy true;
}

// A liquidation does not break the property for anyone else, the liquidator included.
rule liquidationKeepsNoCollateralNoDebtForOthers(env e, uint256 debtReserveId, uint256 debtToCover, address user, uint256 maxCollateralToRemove, address otherUser, uint256 reserveId) {
    // proofScope is only here for the loop bound and the sort summary; the property does not need it.
    proofScope(user);
    require otherUser != user, "Case split: the liquidated user is noCollateralNoDebtAfterLiquidation.";
    require !hasCollateral(otherUser) => noDebt(otherUser, reserveId), "The property itself, assumed before the call.";

    liquidationCall(e, debtReserveId, debtToCover, user, maxCollateralToRemove);

    assert !hasCollateral(otherUser) => noDebt(otherUser, reserveId);
}
