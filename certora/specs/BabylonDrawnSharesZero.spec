/*
 * No premium debt without drawn debt (BabylonSpoke)
 *
 * PROPERTY
 *   A position with zero drawn shares has zero premium shares and zero premium offset. It holds
 *   after the constructor and is preserved by every external function of the Babylon spoke,
 *   including the 4-argument liquidationCall.
 *
 * FORMALIZATION
 *   invariant drawnSharesZero(address user, uint256 reserveId)
 *       _userPositions[user][reserveId].drawnShares == 0
 *           => premiumShares == 0 && premiumOffsetRay == 0     (same position)
 *
 *   - Same statement and name as the upstream invariant (aave-v4 certora/spec/Spoke.spec), which
 *     was proved on SpokeInstance with liquidationCall excluded.
 *   - Assumption 5 of BabylonNoCollateralNoDebt.spec restates it.
 *   - Separate from BabylonBorrowingFlagConsistency.spec because that spec summarizes
 *     _notifyRiskPremiumUpdate, which writes the premium fields read here.
 *
 * WHERE THE STATE IS WRITTEN
 *   drawnShares: borrow, repay, LiquidationLogic._liquidateDebt, LiquidationLogic.notifyReportDeficit.
 *   premiumShares / premiumOffsetRay: the same paths (applyPremiumDelta), and
 *   Spoke._notifyRiskPremiumUpdate, reached from every function that refreshes the risk premium.
 *
 * REQUIRES / PRESERVED BLOCKS
 *   None.
 *
 * SUMMARIES (all of them). S1, S2, S4, S5 and S6 of BabylonBorrowingFlagConsistency.spec, same
 * reasons. _notifyRiskPremiumUpdate (S3 there) runs for real here.
 *   S1. extSload / extSloads => NONDET DELETE.
 *   S2. Spoke._processUserAccountData => arbitrary account data. It writes only dynamicConfigKey.
 *       Its risk premium feeds _notifyRiskPremiumUpdate, so the premium refresh runs with an
 *       arbitrary risk premium: that covers every real one.
 *   S4. The upstream symbolic Hub (and its ERC20 model). With the real Hub and precise_bitwise_ops,
 *       the run spent 2 hours in the Prover's storage analysis and proved nothing.
 *       Hub fact this invariant uses: getAssetDrawnIndex returns the same index for the same asset
 *       within one call, so the premium debt computed before and after a write agree.
 *   S5. The upstream symbolic bitmap. The invariant does not read the bitmap; the bitmap only
 *       decides which reserves _notifyRiskPremiumUpdate visits and which paths revert.
 *   S6. consumeScheduledOp / setReserveSource => NONDET ALL, so unresolved calls do not havoc the
 *       symbolic Hub's index ghosts.
 *
 * ASSUMPTIONS
 *   1, 2 and 3 of BabylonBorrowingFlagConsistency.spec (Hub.draw returns at least one share, no
 *   re-entrancy into the Spoke, optimistic loop bound 3).
 *   4. One user per call, for the bitmap only (S5): the symbolic bitmap keeps the bits of a single
 *      user, userGhost. No hook ties userGhost to the written position here, because the invariant
 *      does not read the bitmap. Same argument as assumption 4 of BabylonBorrowingFlagConsistency.spec.
 *
 * EXCLUDED FUNCTIONS
 *   multicall(bytes[]) only, for the reason given in BabylonBorrowingFlagConsistency.spec.
 */

// S4.
import "./helpers/symbolicRepresentation/SymbolicHub.spec";

// S5.
import "./helpers/symbolicRepresentation/SymbolicPositionStatus.spec";

// Used by SymbolicHub.spec (upstream defines it in common.spec).
persistent ghost uint256 RAY {
    axiom RAY == 10^27;
}

methods {
    // S1.
    function _.extSload(bytes32) external => NONDET DELETE;
    function _.extSloads(bytes32[]) external => NONDET DELETE;

    // S2.
    function Spoke._processUserAccountData(address user, bool refreshConfig) internal returns (ISpoke.UserAccountData memory)
        => arbitraryAccountData();

    // S6. Same lines as upstream SpokeBaseSummaries.spec.
    function _.consumeScheduledOp(address caller, bytes data) external => NONDET ALL;
    function _.setReserveSource(uint256 reserveId, address source) external => NONDET ALL;
}

function arbitraryAccountData() returns ISpoke.UserAccountData {
    ISpoke.UserAccountData result;
    return result;
}

invariant drawnSharesZero(address user, uint256 reserveId)
    currentContract._userPositions[user][reserveId].drawnShares == 0 =>
        (currentContract._userPositions[user][reserveId].premiumShares == 0
            && currentContract._userPositions[user][reserveId].premiumOffsetRay == 0)
    filtered { f -> f.selector != sig:multicall(bytes[]).selector }
