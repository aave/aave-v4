/*
 * Borrowing flag consistency (BabylonSpoke)
 *
 * PROPERTY
 *   A user's borrowing bit for a reserve is set exactly when the user has drawn shares in
 *   that reserve. It holds after the constructor and is preserved by every external function
 *   of the Babylon spoke, including the 4-argument liquidationCall.
 *
 * FORMALIZATION
 *   invariant borrowingFlagIffDrawnShares(address user, uint256 reserveId)
 *       isBorrowing[user][reserveId]
 *           <=> _userPositions[user][reserveId].drawnShares > 0
 *
 *   - isBorrowing is the ghost of the upstream symbolic bitmap (S5). It stands for the borrowing
 *     bit of PositionStatusMap.
 *   - user and reserveId are unconstrained. Unlisted reserve ids need no side condition:
 *     the iff holds for them as well (in a real deployment both sides are false).
 *   - Checked on every external function of the Spoke except multicall. The Hub's own functions
 *     are not induction steps: the Hub never calls the Spoke.
 *   - The bit follows drawn shares, not total debt. Premium debt is BabylonDrawnSharesZero.spec.
 *   - This closes the assumption made by setup() in BabylonSettlementAccounting.spec
 *     ("drawn shares imply the borrowing bit"), and proves the converse as well.
 *
 * WHERE THE STATE IS WRITTEN
 *   Spoke.borrow                          drawnShares += hub.draw(...), sets the bit
 *   Spoke.repay                           drawnShares -= restored, clears the bit at zero
 *   LiquidationLogic._liquidateDebt       same as repay (reached from the 4-argument liquidationCall)
 *   LiquidationLogic.notifyReportDeficit  zeroes drawnShares and clears the bit, per borrowed reserve
 *   Nothing else writes drawnShares or a borrowing bit.
 *
 * REQUIRES / PRESERVED BLOCKS
 *   None.
 *
 * SUMMARIES (all of them)
 *   S1. extSload / extSloads => NONDET DELETE (removed from the scene).
 *       Why: they sload a slot chosen by the caller, so the Prover's storage analysis of the Spoke
 *       fails, and without it CVL cannot read _userPositions directly.
 *       Soundness: both are views that write nothing, so they cannot break the invariant, and no
 *       Spoke function calls them. They are no longer induction steps.
 *   S2. Spoke._processUserAccountData => arbitrary account data (same as BabylonCollateralRestrictions).
 *       Why: the loop over the user's reserves (price x shares x index, sort, health factor, risk
 *       premium) was 68% of the nonlinear operations of borrow, withdraw, setUsingAsCollateral,
 *       updateUserDynamicConfig, updateUserRiskPremium and liquidationCall, none of which finished.
 *       Soundness: it writes only dynamicConfigKey, which the invariant does not read. Its result
 *       only feeds health-factor checks (reverts) and the risk premium of S3, so an arbitrary
 *       result only adds behaviours.
 *   S3. Spoke._notifyRiskPremiumUpdate => NONDET.
 *       Why: it refreshes the premium of every borrowed reserve, with a Hub call per reserve.
 *       Soundness: it writes riskPremium, premiumShares and premiumOffsetRay only. None is read here.
 *   S4. The Hub is the upstream symbolic Hub (helpers/symbolicRepresentation/SymbolicHub.spec, copied
 *       unchanged from aave-v4-pub feat/certora-cvl-v0.5.11), with its ERC20 model (ERC20s_CVL.spec).
 *       Why: with the real Hub, borrow, repay and liquidationCall timed out even when run one per job
 *       with 2 hours each (76%, 1.6% and 0% proved). Hub.draw, Hub.restore, Hub.remove and the preview
 *       functions were most of their nonlinear operations.
 *       What it keeps: draw requires amount > 0 and returns ceil(amount * RAY / index) with a drawn
 *       index >= RAY, so it returns at least 1 share. That is the only Hub fact this invariant uses
 *       (borrow adds draw's result to drawnShares and sets the bit). repay and liquidationCall
 *       subtract shares computed by the Spoke and ignore restore's return value.
 *       Soundness: the summaries write only CVL ghosts, never the Spoke. The Hub views that are not
 *       summarized (getSpokeOwed, getSpokeTotalOwed, getSpokeAddedShares, getSpokeAddedAssets) are
 *       unresolved and use the Prover default (arbitrary results, no change to the Spoke).
 *   S5. PositionStatusMap is the upstream symbolic bitmap
 *       (helpers/symbolicRepresentation/SymbolicPositionStatus.spec, copied unchanged): the bits are
 *       the ghosts isBorrowing / isUsingAsCollateral of the user userGhost.
 *       Why: the real bitmap needs precise_bitwise_ops. With it, repay still timed out with 10
 *       nonlinear operations left, and the symbolic draw's amount * RAY wrapped at 2^256, which gave a
 *       spurious counterexample on borrow (draw returned 0 shares for amount 2^256 - 7).
 *       Soundness: upstream proves the summary against PositionStatusMap.sol
 *       (VerifySymbolicPositionStatus.conf). This repo's PositionStatusMap.sol is identical to upstream's.
 *   S6. AccessManager.consumeScheduledOp and the oracle's setReserveSource => NONDET (as upstream).
 *       Why: unresolved, the Prover's default havocs every non-persistent ghost, the isBorrowing
 *       ghost of S5 included. That gave spurious counterexamples on the 9 restricted functions
 *       (e.g. updatePositionManager: isBorrowing flipped to true with drawnShares 0).
 *       Soundness: neither contract can write the Spoke's bitmap or drawnShares (assumption 2).
 *
 * ASSUMPTIONS (all of them)
 *   1. Hub.draw returns at least one share (S4). The real Hub.draw reverts on amount == 0
 *      (Hub._validateDraw) and rounds shares up (toDrawnSharesUp, Hub.sol:259). Read from the code,
 *      not proved here. The property is false for a hub whose draw can return 0.
 *   2. No re-entrancy into the Spoke from external calls (oracle, authority, ERC20 tokens). The calls
 *      made by the Spoke that remain unresolved use the Prover default: arbitrary return values and
 *      arbitrary changes to every contract except the Spoke.
 *      Not proved here. Argument: every Spoke function that writes drawnShares or the bitmap is
 *      nonReentrant, so a re-entrant call to one of them reverts while another is running. The
 *      functions without the guard never write drawnShares or the bitmap, and a call re-entering
 *      through one of them is a complete call that this invariant already covers.
 *   3. Loop bound: optimistic_loop with loop_iter 3. Executions where a loop runs more than
 *      3 times are not checked. This is an under-approximation. The loops are over a user's
 *      flagged reserves, over bitmap buckets (128 reserves each) and over the updates of
 *      setUserPositionManagersWithSig. The writes in each iteration are the same, but that is
 *      an argument, not a proof.
 *   4. One user per call (S5): every write to drawnShares in a call is for the user userGhost, the
 *      user whose bitmap the symbolic summary updates (hook below, same as upstream Spoke.spec).
 *      Executions that write drawnShares of two users are not checked.
 *      Not proved here (upstream proves it for SpokeInstance in SpokeUserIntegrity.spec). Argument:
 *      borrow, repay and the deficit path write the position of one user, and the Babylon
 *      liquidationCall reads the liquidator's position but writes the bitmap and drawnShares of the
 *      liquidated user only.
 *
 * EXCLUDED FUNCTIONS
 *   multicall(bytes[]) only. See the filter below.
 *
 * NOT EXCLUDED, BUT VACUOUS
 *   liquidationCall(uint256,uint256,address,uint256,bool) always reverts in BabylonSpoke, so
 *   rule_sanity reports it as vacuous. That is expected.
 */

// S4.
import "./helpers/symbolicRepresentation/SymbolicHub.spec";

// S5.
import "./helpers/symbolicRepresentation/SymbolicPositionStatus.spec";

// Used by SymbolicHub.spec (upstream defines it in common.spec).
persistent ghost uint256 RAY {
    axiom RAY == 10^27;
}

// Assumption 4.
hook Sstore _userPositions[KEY address user][KEY uint256 reserveId].drawnShares uint120 newValue (uint120 oldValue) {
    require userGhost == user, "Assumption 4: one user per call";
}

methods {
    // S1.
    function _.extSload(bytes32) external => NONDET DELETE;
    function _.extSloads(bytes32[]) external => NONDET DELETE;

    // S2.
    function Spoke._processUserAccountData(address user, bool refreshConfig) internal returns (ISpoke.UserAccountData memory)
        => arbitraryAccountData();

    // S3.
    function Spoke._notifyRiskPremiumUpdate(address user, uint256 newRiskPremium) internal => NONDET;

    // S6. Same lines as upstream SpokeBaseSummaries.spec.
    function _.consumeScheduledOp(address caller, bytes data) external => NONDET ALL;
    function _.setReserveSource(uint256 reserveId, address source) external => NONDET ALL;
}

function arbitraryAccountData() returns ISpoke.UserAccountData {
    ISpoke.UserAccountData result;
    return result;
}

invariant borrowingFlagIffDrawnShares(address user, uint256 reserveId)
    isBorrowing[user][reserveId] <=> currentContract._userPositions[user][reserveId].drawnShares > 0
    // multicall is excluded. It delegatecalls into this same contract with calldata chosen by the
    // caller. The Prover cannot tell which function runs, so it havocs the Spoke's storage and the
    // invariant fails for a reason that has nothing to do with the code.
    // Unproved here: that multicall preserves the invariant. The argument is that each inner call
    // is one of this contract's own functions, run with the same msg.sender, and each of them is
    // checked on its own by this invariant.
    filtered { f -> f.selector != sig:multicall(bytes[]).selector }
