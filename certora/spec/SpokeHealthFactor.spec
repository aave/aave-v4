/**
 * @title Spoke Health Factor Specification
 * @notice Verify that the health factor is above threshold after any operation
 * @dev Symbolic representation of the total collateral value and total debt value.
 * The health factor is calculated as the total collateral value divided by the total debt value.
 *
 * To run this spec:
 * certoraRun certora/conf/SpokeHealthFactor.conf
 */

import "./SpokeBaseSummaries.spec";
import "./symbolicRepresentation/SymbolicHub.spec";

using SpokeInstance as spoke;

////////////////////////////////////////////////////////////////////////////
//                                METHODS                                 //
////////////////////////////////////////////////////////////////////////////

methods {
    // Represent activeCollateralCount and healthFactor only
    function Spoke._processUserAccountData(address user, bool refreshConfig) internal returns (ISpoke.UserAccountData memory) => processUserAccountDataCVL(user, refreshConfig);

    // PositionStatus are safe assumed any value, beside setUsingAsCollateral, nextBorrowing and isUsingAsCollateral that are symbolically represented by a cvl function
    function _.setBorrowing(ISpoke.PositionStatus storage positionStatus, uint256 reserveId, bool borrowing) internal => NONDET;

    function _.setUsingAsCollateral(ISpoke.PositionStatus storage positionStatus, uint256 reserveId, bool usingAsCollateral) internal => setUsingAsCollateralCVL_updateTotals(reserveId, usingAsCollateral) expect void;

    function _.isUsingAsCollateralOrBorrowing(ISpoke.PositionStatus storage positionStatus, uint256 reserveId) internal => NONDET;

    function _.isBorrowing(ISpoke.PositionStatus storage positionStatus, uint256 reserveId) internal => NONDET;

    function _.isUsingAsCollateral(ISpoke.PositionStatus storage positionStatus, uint256 reserveId) internal => isUsingAsCollateralCVL(reserveId) expect bool;

    function _.collateralCount(ISpoke.PositionStatus storage positionStatus, uint256 reserveCount) internal => NONDET;

    function _.next(ISpoke.PositionStatus storage positionStatus, uint256 startReserveId) internal => NONDET;

    function _.nextBorrowing(ISpoke.PositionStatus storage positionStatus, uint256 startReserveId) internal => nextBorrowingCVL(startReserveId) expect uint256;

    function _.nextCollateral(ISpoke.PositionStatus storage positionStatus, uint256 startReserveId) internal => NONDET;

    // proved in Spoke.spec : updateUserRiskPremium_preservesPremiumDebt that this function preserves debt
    function _.notifyRiskPremiumUpdate(address user, uint256 newRiskPremium) internal => NONDET;
}

////////////////////////////////////////////////////////////////////////////
//                                 GHOSTS                                 //
////////////////////////////////////////////////////////////////////////////

persistent ghost mapping(mathint /* totalCollateralValue */ => mapping(mathint /* totalDebtValue */ => uint256 /* healthFactor */)) ghostHealthFactor {
    init_state axiom forall mathint totalCollateralValue. forall mathint totalDebtValue. ghostHealthFactor[totalCollateralValue][totalDebtValue] == 0;
    axiom forall mathint totalCollateralValue. forall mathint totalDebtValue. totalDebtValue > 0 ? ghostHealthFactor[totalCollateralValue][totalDebtValue] == totalCollateralValue / totalDebtValue : ghostHealthFactor[totalCollateralValue][totalDebtValue] == max_uint256;
}

ghost mathint totalCollateralValueGhost;

ghost mathint totalDebtValueGhost;

ghost uint256 currentTime;

ghost address currentUser;

ghost uint256 debtReserveId_1;

ghost uint256 debtReserveId_2;

ghost uint256 debtReserveId_3;

ghost uint256 collateralReserveId_1;

ghost uint256 collateralReserveId_2;

ghost uint256 collateralReserveId_3;

ghost mapping(uint256 /*reserveId*/ => bool /*usingAsCollateral*/) isUsingAsCollateral {
    init_state axiom forall uint256 reserveId. !isUsingAsCollateral[reserveId];
}

ghost mathint activeCollateralCountGhost;

// Split proofs of userHealthAboveThreshold / userHealthBelowThresholdCanOnlyIncreaseHealthFactor:
// snapshots of (C, D) at each nextBorrowing call (start of each _notifyRiskPremiumUpdate iteration), and per
// iteration k the refreshed reserve, its premium shares/offset before (psB/offB) and after (psA/offA), index and price.
ghost mathint nbCount;
ghost mapping(mathint => mathint) dSnap;
ghost mapping(mathint => mathint) cSnap;
ghost address snapUser;
ghost mapping(mathint => uint256) ridSnap;
ghost mapping(mathint => mathint) psB;
ghost mapping(mathint => mathint) offB;
ghost mapping(mathint => mathint) psA;
ghost mapping(mathint => mathint) offA;
ghost mapping(mathint => mathint) idxS;
ghost mapping(mathint => mathint) priceS;
// last _processUserAccountData call: (C, D) and returned health factor
ghost bool pcCalled;
ghost mathint pcC;
ghost mathint pcD;
ghost mathint pcHf;
// last hub.restore call
ghost mathint rsRestoredRay;

////////////////////////////////////////////////////////////////////////////
//                              DEFINITIONS                               //
////////////////////////////////////////////////////////////////////////////

definition knownDebtReserveIds(uint256 reserveId) returns bool =
    reserveId == debtReserveId_1 || reserveId == debtReserveId_2 || reserveId == debtReserveId_3;

definition knownCollateralReserveIds(uint256 reserveId) returns bool =
    reserveId == collateralReserveId_1 || reserveId == collateralReserveId_2 || reserveId == collateralReserveId_3;

definition HEALTH_FACTOR_LIQUIDATION_THRESHOLD() returns uint256 = 10 ^ 18;

// definition of function that should revert if the health factor is below the threshold
definition belowThresholdRevertingFunctions(method f) returns bool =
    f.selector == sig:updateUserDynamicConfig(address).selector ||
    f.selector == sig:borrow(uint256, uint256, address).selector;

////////////////////////////////////////////////////////////////////////////
//                              FUNCTIONS                                 //
////////////////////////////////////////////////////////////////////////////

function setUsingAsCollateralCVL_updateTotals(uint256 reserveId, bool usingAsCollateral) {
    uint256 assetId = spoke._reserves[reserveId].assetId;
    require knownCollateralReserveIds(reserveId);
    mathint currValue = collateralIDValue(reserveId);
    if (isUsingAsCollateral[reserveId] && !usingAsCollateral) {
        totalCollateralValueGhost = totalCollateralValueGhost - currValue;
    } else if (!isUsingAsCollateral[reserveId] && usingAsCollateral) {
        totalCollateralValueGhost = totalCollateralValueGhost + currValue;
    }
    isUsingAsCollateral[reserveId] = usingAsCollateral;
}

function isUsingAsCollateralCVL(uint256 reserveId) returns (bool) {
    return isUsingAsCollateral[reserveId];
}

function processUserAccountDataCVL(address user, bool refreshConfig) returns (ISpoke.UserAccountData) {
    pcCalled = true;
    pcC = totalCollateralValueGhost;
    pcD = totalDebtValueGhost;
    ISpoke.UserAccountData userAccountData;
    require userAccountData.healthFactor == ghostHealthFactor[totalCollateralValueGhost][totalDebtValueGhost];
    activeCollateralCountGhost = 0;
    if (collateralIDValue(collateralReserveId_1) > 0) {
        activeCollateralCountGhost = activeCollateralCountGhost + 1;
    }
    if (collateralIDValue(collateralReserveId_2) > 0) {
        activeCollateralCountGhost = activeCollateralCountGhost + 1;
    }
    if (collateralIDValue(collateralReserveId_3) > 0) {
        activeCollateralCountGhost = activeCollateralCountGhost + 1;
    }
    require userAccountData.activeCollateralCount == activeCollateralCountGhost;
    pcHf = userAccountData.healthFactor;
    return userAccountData;
}

/**
 * 
 * suppliedShares * shareToAssetsRatio * price.
 */
function collateralIDValue(uint256 reserveId) returns (mathint) {
    uint256 assetId = spoke._reserves[reserveId].assetId;
    return spoke._userPositions[currentUser][reserveId].suppliedShares * shareToAssetsRatio[assetId][currentTime] * symbolicPrice(reserveId, currentTime);
}

/**
 * 
 * drawnShares * index + (premiumShares * index - premiumOffsetRay), all multiplied by price.
 */
function debtIDValue(uint256 reserveId) returns (mathint) {
    uint256 assetId = spoke._reserves[reserveId].assetId;
    mathint idx = indexOfAssetPerBlock[assetId][currentTime];

    mathint drawnTerm = spoke._userPositions[currentUser][reserveId].drawnShares * idx;
    mathint premiumTerm =
        spoke._userPositions[currentUser][reserveId].premiumShares * idx
        - spoke._userPositions[currentUser][reserveId].premiumOffsetRay;

    return (drawnTerm + premiumTerm) * symbolicPrice(reserveId, currentTime);
}

function nextBorrowingCVL(uint256 startReserveId) returns (uint256) {
    mathint k = nbCount;
    dSnap[k] = totalDebtValueGhost;
    cSnap[k] = totalCollateralValueGhost;
    if (k > 0) {
        psA[k - 1] = spoke._userPositions[snapUser][ridSnap[k - 1]].premiumShares;
        offA[k - 1] = spoke._userPositions[snapUser][ridSnap[k - 1]].premiumOffsetRay;
    }
    uint256 ret;
    if (startReserveId > debtReserveId_1 && debtIDValue(debtReserveId_1) > 0) {
        ret = debtReserveId_1;
    } else if (startReserveId > debtReserveId_2 && debtIDValue(debtReserveId_2) > 0) {
        ret = debtReserveId_2;
    } else if (startReserveId > debtReserveId_3 && debtIDValue(debtReserveId_3) > 0) {
        ret = debtReserveId_3;
    } else {
        ret = max_uint256;
    }
    ridSnap[k] = ret;
    psB[k] = spoke._userPositions[snapUser][ret].premiumShares;
    offB[k] = spoke._userPositions[snapUser][ret].premiumOffsetRay;
    idxS[k] = indexOfAssetPerBlock[spoke._reserves[ret].assetId][currentTime];
    priceS[k] = symbolicPrice(ret, currentTime);
    nbCount = k + 1;
    return ret;
}

// same body as SymbolicHub.spec + records the restored premium
override function restoreSummaryCVL(uint256 assetId, uint256 drawnAmount, IHubBase.PremiumDelta premiumDelta,  env e) returns (uint256) {
    rsRestoredRay = premiumDelta.restoredPremiumRay;
    return previewRestoreByAssetsCVL(assetId, drawnAmount, e);
}

// (N) when cond: _notifyRiskPremiumUpdate preserves (C, D) = (Cin, Din). Per iteration k:
// premium debt preserved (a), distributivity (b), shares change * idx == offset change (c),
// hook delta in the hooks' own form (e), times price (f), collateral unchanged (d).
// Breaking out distributivity and multiplication by price gives the solver explicit steps through the nonlinear arithmetic.
function assertNotifyPreserves(bool cond, mathint Cin, mathint Din) {
    assert cond => (nbCount > 0 => (cSnap[0] == Cin && dSnap[0] == Din)), "N0: loop starts from (Cin, Din)";
    assert cond => (nbCount >= 2 => psA[0] * idxS[0] - offA[0] == psB[0] * idxS[0] - offB[0]), "I1a: iteration 1 preserves premium debt";
    assert cond => (nbCount >= 2 => (psA[0] - psB[0]) * idxS[0] == psA[0] * idxS[0] - psB[0] * idxS[0]), "I1b: distributivity";
    assert cond => (nbCount >= 2 => (psA[0] - psB[0]) * idxS[0] == offA[0] - offB[0]), "I1c: shares change * idx == offset change";
    assert cond => (nbCount >= 2 => dSnap[1] - dSnap[0] == (psA[0] - psB[0]) * idxS[0] * priceS[0] - (offA[0] - offB[0]) * priceS[0]), "I1e: iteration 1 hook accounting (hook form)";
    assert cond => (nbCount >= 2 => (psA[0] - psB[0]) * idxS[0] * priceS[0] == (offA[0] - offB[0]) * priceS[0]), "I1f: congruence with price";
    assert cond => (nbCount >= 2 => cSnap[1] == cSnap[0]), "I1d: iteration 1 keeps C";
    assert cond => (nbCount >= 2 => (cSnap[1] == cSnap[0] && dSnap[1] == dSnap[0])), "N1: iteration 1 preserves C, D";
    assert cond => (nbCount >= 3 => psA[1] * idxS[1] - offA[1] == psB[1] * idxS[1] - offB[1]), "I2a: iteration 2 preserves premium debt";
    assert cond => (nbCount >= 3 => (psA[1] - psB[1]) * idxS[1] == psA[1] * idxS[1] - psB[1] * idxS[1]), "I2b: distributivity";
    assert cond => (nbCount >= 3 => (psA[1] - psB[1]) * idxS[1] == offA[1] - offB[1]), "I2c: shares change * idx == offset change";
    assert cond => (nbCount >= 3 => dSnap[2] - dSnap[1] == (psA[1] - psB[1]) * idxS[1] * priceS[1] - (offA[1] - offB[1]) * priceS[1]), "I2e: iteration 2 hook accounting (hook form)";
    assert cond => (nbCount >= 3 => (psA[1] - psB[1]) * idxS[1] * priceS[1] == (offA[1] - offB[1]) * priceS[1]), "I2f: congruence with price";
    assert cond => (nbCount >= 3 => cSnap[2] == cSnap[1]), "I2d: iteration 2 keeps C";
    assert cond => (nbCount >= 3 => (cSnap[2] == cSnap[1] && dSnap[2] == dSnap[1])), "N2: iteration 2 preserves C, D";
    assert cond => (nbCount >= 4 => psA[2] * idxS[2] - offA[2] == psB[2] * idxS[2] - offB[2]), "I3a: iteration 3 preserves premium debt";
    assert cond => (nbCount >= 4 => (psA[2] - psB[2]) * idxS[2] == psA[2] * idxS[2] - psB[2] * idxS[2]), "I3b: distributivity";
    assert cond => (nbCount >= 4 => (psA[2] - psB[2]) * idxS[2] == offA[2] - offB[2]), "I3c: shares change * idx == offset change";
    assert cond => (nbCount >= 4 => dSnap[3] - dSnap[2] == (psA[2] - psB[2]) * idxS[2] * priceS[2] - (offA[2] - offB[2]) * priceS[2]), "I3e: iteration 3 hook accounting (hook form)";
    assert cond => (nbCount >= 4 => (psA[2] - psB[2]) * idxS[2] * priceS[2] == (offA[2] - offB[2]) * priceS[2]), "I3f: congruence with price";
    assert cond => (nbCount >= 4 => cSnap[3] == cSnap[2]), "I3d: iteration 3 keeps C";
    assert cond => (nbCount >= 4 => (cSnap[3] == cSnap[2] && dSnap[3] == dSnap[2])), "N3: iteration 3 preserves C, D";
    assert cond => (nbCount > 0 => (totalCollateralValueGhost == cSnap[nbCount - 1] && totalDebtValueGhost == dSnap[nbCount - 1])), "N4: nothing changes after the loop";
    assert cond => (nbCount == 0 => (totalCollateralValueGhost == Cin && totalDebtValueGhost == Din)), "N5: early return";
    assert cond => (totalCollateralValueGhost == Cin && totalDebtValueGhost == Din), "N6: refresh preserves C, D";
}

// (H) when cond: C' >= C, D' == D  ==>  hf(C', D') >= hf(C, D)
// Add the arithmetic argument for increasing collateral
function assertHfMonotoneInC(bool cond, mathint C0, mathint D0, mathint C1, mathint D1) {
    mathint hf0 = ghostHealthFactor[C0][D0];
    mathint hf1 = ghostHealthFactor[C1][D1];
    assert cond => (D0 > 0 => hf0 * D0 <= C0), "HC1: hf0 floor";
    assert cond => (D1 > 0 => (hf1 + 1) * D1 > C1), "HC2: hf1 floor";
    assert cond => (D0 > 0 => hf0 * D1 <= C1), "HC3: hf0 * D <= C <= C'";
    assert cond => hf1 >= hf0, "HC4: hf monotone in C";
}

// (H) when cond: C' == C, D' <= D  ==>  hf(C', D') >= hf(C, D)
// Add the corresponding argument for decreasing debt
function assertHfMonotoneInD(bool cond, mathint C0, mathint D0, mathint C1, mathint D1) {
    mathint hf0 = ghostHealthFactor[C0][D0];
    mathint hf1 = ghostHealthFactor[C1][D1];
    assert cond => (D1 == 0 => hf1 == max_uint256), "HD0: no debt";
    assert cond => (D0 > 0 => hf0 * D0 <= C0), "HD1: hf0 floor";
    assert cond => (D1 > 0 => hf0 * D1 <= hf0 * D0), "HD2: scale by smaller debt";
    assert cond => (D1 > 0 => (hf1 + 1) * D1 > C1), "HD3: hf1 floor";
    assert cond => hf1 >= hf0, "HD4: hf monotone in D";
}

// repay: C unchanged, premium debt drops by restoredPremiumRay, drawn shares drop ==> D' <= D
// Connects a repayment to the decreasing-debt argument
function assertRepayReducesDebt(bool cond, mathint C0, mathint D0, mathint ps0, mathint off0, mathint dr0,
                                mathint ps1, mathint off1, mathint dr1, mathint idx, mathint price) {
    mathint C1 = totalCollateralValueGhost; mathint D1 = totalDebtValueGhost;
    assert cond => C1 == C0, "R0: collateral unchanged";
    assert cond => D1 - D0 == ((ps1 - ps0) * idx - (off1 - off0)) * price + (dr1 - dr0) * idx * price, "R1: hook accounting";
    assert cond => ps1 * idx - off1 == ps0 * idx - off0 - rsRestoredRay, "R2: premium debt drops by restored amount";
    assert cond => (rsRestoredRay >= 0 && dr1 <= dr0 && idx >= 0 && price >= 0), "R3: signs";
    assert cond => ((ps1 - ps0) * idx - (off1 - off0)) * price <= 0, "R4: premium part non-positive";
    assert cond => (dr1 - dr0) * idx * price <= 0, "R5: drawn part non-positive";
    assert cond => D1 <= D0, "R6: debt does not increase";
    assertHfMonotoneInD(cond, C0, D0, C1, D1);
}

/**
Based on the definition of validReserveId_singleUser in Spoke.spec, this function verifies that the reserveId is valid for the current user.
*/
function validReserveId_singleUser(uint256 reserveId) {
    require
    (reserveId < spoke._reserveCount =>
    // has underlying and hub
    (spoke._reserves[reserveId].underlying != 0 && spoke._reserves[reserveId].hub != 0 && spoke._hubAssetIdToReserveId[spoke._reserves[reserveId].hub][spoke._reserves[reserveId].assetId] != 0))
    &&
    // not exists
    (reserveId >= spoke._reserveCount =>
    // has no underlying, hub, assetId
    spoke._reserves[reserveId].underlying == 0 && spoke._reserves[reserveId].assetId == 0 && spoke._reserves[reserveId].hub == 0 && spoke._reserves[reserveId].dynamicConfigKey == 0 && spoke._reserves[reserveId].flags == 0 && spoke._reserves[reserveId].collateralRisk == 0 &&
    spoke._dynamicConfig[reserveId][0].collateralFactor == 0 &&
    // not used as collateral
    !isUsingAsCollateral[reserveId] &&
    // no supplied or drawn shares
    spoke._userPositions[currentUser][reserveId].suppliedShares == 0 && spoke._userPositions[currentUser][reserveId].drawnShares == 0 &&
    // no premium shares or offset
    spoke._userPositions[currentUser][reserveId].premiumShares == 0 && spoke._userPositions[currentUser][reserveId].premiumOffsetRay == 0);
}

function drawnSharesRiskLEPremiumShares(uint256 reserveId) {
    require (spoke._userPositions[currentUser][reserveId].drawnShares * spoke._positionStatus[currentUser].riskPremium + PERCENTAGE_FACTOR - 1) / PERCENTAGE_FACTOR == spoke._userPositions[currentUser][reserveId].premiumShares;
}

function drawnSharesZero(uint256 reserveId) {
    require spoke._userPositions[currentUser][reserveId].drawnShares == 0 => (spoke._userPositions[currentUser][reserveId].premiumShares == 0 && spoke._userPositions[currentUser][reserveId].premiumOffsetRay == 0);
}

function setUpForOne(uint256 reserveID) {
    drawnSharesRiskLEPremiumShares(reserveID);
    drawnSharesZero(reserveID);
    validReserveId_singleUser(reserveID);
}

function setup() {
    setUpForOne(debtReserveId_1);
    setUpForOne(debtReserveId_2);
    setUpForOne(debtReserveId_3);
}

////////////////////////////////////////////////////////////////////////////
//                                 HOOKS                                  //
////////////////////////////////////////////////////////////////////////////

hook Sstore _userPositions[KEY address user][KEY uint256 reserveId].drawnShares uint120 newValue (uint120 oldValue) {
    require knownDebtReserveIds(reserveId);
    uint256 assetId = spoke._reserves[reserveId].assetId;
    totalDebtValueGhost = totalDebtValueGhost + (
        (newValue - oldValue) * indexOfAssetPerBlock[assetId][currentTime] * symbolicPrice(reserveId, currentTime));
}

hook Sload uint120 value _userPositions[KEY address user][KEY uint256 reserveId].drawnShares {
    require knownDebtReserveIds(reserveId);
    uint256 assetId = spoke._reserves[reserveId].assetId;
    require totalDebtValueGhost >=
        value * indexOfAssetPerBlock[assetId][currentTime] * symbolicPrice(reserveId, currentTime);
}

hook Sstore _userPositions[KEY address user][KEY uint256 reserveId].suppliedShares uint120 newValue (uint120 oldValue) {
    require knownCollateralReserveIds(reserveId);
    if (isUsingAsCollateral[reserveId]) {
        uint256 assetId = spoke._reserves[reserveId].assetId;
        totalCollateralValueGhost = totalCollateralValueGhost + (
            (newValue - oldValue) * shareToAssetsRatio[assetId][currentTime] * symbolicPrice(reserveId, currentTime));
    }
}

hook Sload uint120 value _userPositions[KEY address user][KEY uint256 reserveId].suppliedShares {
    require knownCollateralReserveIds(reserveId);
    if (isUsingAsCollateral[reserveId]) {
        uint256 assetId = spoke._reserves[reserveId].assetId;
        require totalCollateralValueGhost >=
            value * shareToAssetsRatio[assetId][currentTime] * symbolicPrice(reserveId, currentTime);
    }
}

hook Sstore _userPositions[KEY address user][KEY uint256 reserveId].premiumShares uint120 newValue (uint120 oldValue) {
    require knownDebtReserveIds(reserveId);
    uint256 assetId = spoke._reserves[reserveId].assetId;
    totalDebtValueGhost = totalDebtValueGhost + (
        (newValue - oldValue) * indexOfAssetPerBlock[assetId][currentTime] * symbolicPrice(reserveId, currentTime));
}

hook Sload uint120 value _userPositions[KEY address user][KEY uint256 reserveId].premiumShares {
    require knownDebtReserveIds(reserveId);
    uint256 assetId = spoke._reserves[reserveId].assetId;
    require totalDebtValueGhost >=
        (value * indexOfAssetPerBlock[assetId][currentTime] - spoke._userPositions[currentUser][reserveId].premiumOffsetRay) * symbolicPrice(reserveId, currentTime);
}

hook Sstore _userPositions[KEY address user][KEY uint256 reserveId].premiumOffsetRay int200 newValue (int200 oldValue) {
    require knownDebtReserveIds(reserveId);
    totalDebtValueGhost = totalDebtValueGhost - ((newValue - oldValue) * symbolicPrice(reserveId, currentTime));
}

hook Sload int200 value _userPositions[KEY address user][KEY uint256 reserveId].premiumOffsetRay {
    require knownDebtReserveIds(reserveId);
    uint256 assetId = spoke._reserves[reserveId].assetId;
    require totalDebtValueGhost >=
        (spoke._userPositions[currentUser][reserveId].premiumShares * indexOfAssetPerBlock[assetId][currentTime] - value) * symbolicPrice(reserveId, currentTime);
}

////////////////////////////////////////////////////////////////////////////
//                                 RULES                                  //
////////////////////////////////////////////////////////////////////////////

/**
 * @title Functions revert when health factor is below threshold
 * @link_property Health check validity
 */
rule belowThresholdReverting(method f) filtered {f -> belowThresholdRevertingFunctions(f)} {
    env e;
    calldataarg args;
    setup();
    require currentTime == e.block.timestamp;
    require totalCollateralValueGhost >= 0 && totalDebtValueGhost >= 0;
    require ghostHealthFactor[totalCollateralValueGhost][totalDebtValueGhost] < HEALTH_FACTOR_LIQUIDATION_THRESHOLD();
    f@withrevert(e, args);
    assert lastReverted;
}

/**
 * @title Verify that the health factor can only increase if the health factor is below the threshold
 * @dev Split proof (multi_assert_check) for repay and updateUserRiskPremium: repay keeps C and lowers D
 *      (premium debt drops by restoredPremiumRay, drawn shares drop); _notifyRiskPremiumUpdate keeps C and D
 *      (per iteration newOff - off == (newPS - pS) * idx, so the hook delta is 0). Then floor(C/D) is monotone.
 * @link_property Health check validity
 */
rule userHealthBelowThresholdCanOnlyIncreaseHealthFactor(method f) filtered {f -> !f.isView && !outOfScopeFunctions(f) && !belowThresholdRevertingFunctions(f)} {
    env e;
    setup();
    require currentTime == e.block.timestamp;
    require totalCollateralValueGhost >= 0 && totalDebtValueGhost >= 0;
    uint256 healthFactorBefore = ghostHealthFactor[totalCollateralValueGhost][totalDebtValueGhost];
    require ghostHealthFactor[totalCollateralValueGhost][totalDebtValueGhost] < HEALTH_FACTOR_LIQUIDATION_THRESHOLD();
    // split proof: ghost initialisation (spec-only state) and values before the call
    require nbCount == 0;
    require !pcCalled;
    mathint C0 = totalCollateralValueGhost; mathint D0 = totalDebtValueGhost;
    uint256 reserveId; uint256 amount; address onBehalfOf;
    mathint ps0 = spoke._userPositions[onBehalfOf][reserveId].premiumShares;
    mathint off0 = spoke._userPositions[onBehalfOf][reserveId].premiumOffsetRay;
    mathint dr0 = spoke._userPositions[onBehalfOf][reserveId].drawnShares;
    mathint idx = indexOfAssetPerBlock[spoke._reserves[reserveId].assetId][currentTime];
    mathint price = symbolicPrice(reserveId, currentTime);
    bool isRepay = f.selector == sig:repay(uint256, uint256, address).selector;
    bool isRiskPremium = f.selector == sig:updateUserRiskPremium(address).selector;

    calldataarg args;
    if (f.selector == sig:setUsingAsCollateral(uint256, bool, address).selector) {
        bool usingAsCollateral;
        setUsingAsCollateral(e, reserveId, usingAsCollateral, currentUser);
    }
    // timed-out methods called explicitly with all-symbolic arguments (same as f(e, args))
    else if (isRepay) {
        repay(e, reserveId, amount, onBehalfOf);
    }
    else if (isRiskPremium) {
        require snapUser == onBehalfOf;
        updateUserRiskPremium(e, onBehalfOf);
    }
    else {
        f(e, args);
    }

    require totalCollateralValueGhost >= 0 && totalDebtValueGhost >= 0;
    mathint ps1 = spoke._userPositions[onBehalfOf][reserveId].premiumShares;
    mathint off1 = spoke._userPositions[onBehalfOf][reserveId].premiumOffsetRay;
    mathint dr1 = spoke._userPositions[onBehalfOf][reserveId].drawnShares;
    assertRepayReducesDebt(isRepay, C0, D0, ps0, off0, dr0, ps1, off1, dr1, idx, price);
    assertNotifyPreserves(isRiskPremium, C0, D0);
    assert healthFactorBefore <= ghostHealthFactor[totalCollateralValueGhost][totalDebtValueGhost];
}

/**
 * @title Verify that the health factor is above the threshold after any operation
 * @dev Split proof (multi_assert_check) for repay, updateUserRiskPremium, updateUserDynamicConfig, withdraw,
 *      setUsingAsCollateral: repay keeps C and lowers D; the refresh loop keeps C and D; withdraw /
 *      disabling collateral pass the health check at (pcC, pcD) and the loop then keeps (C, D); enabling
 *      collateral or a no-op keeps D and does not lower C. Then floor(C/D) is monotone.
 * @notice Excludes  borrow function due to timeouts 
 * @link_property Health check validity
 */
rule userHealthAboveThreshold(method f) filtered {f -> !f.isView && !outOfScopeFunctions(f)  &&  f.selector != sig:borrow(uint256, uint256, address).selector } {
    env e;
    setup();
    require currentTime == e.block.timestamp;
    require totalCollateralValueGhost >= 0 && totalDebtValueGhost >= 0;
    require ghostHealthFactor[totalCollateralValueGhost][totalDebtValueGhost] >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD();
    // split proof: ghost initialisation (spec-only state) and values before the call
    require nbCount == 0;
    require !pcCalled;
    mathint C0 = totalCollateralValueGhost; mathint D0 = totalDebtValueGhost;
    uint256 reserveId; uint256 amount; address onBehalfOf;
    mathint ps0 = spoke._userPositions[onBehalfOf][reserveId].premiumShares;
    mathint off0 = spoke._userPositions[onBehalfOf][reserveId].premiumOffsetRay;
    mathint dr0 = spoke._userPositions[onBehalfOf][reserveId].drawnShares;
    mathint idx = indexOfAssetPerBlock[spoke._reserves[reserveId].assetId][currentTime];
    mathint price = symbolicPrice(reserveId, currentTime);
    bool isRepay = f.selector == sig:repay(uint256, uint256, address).selector;
    bool isRiskPremium = f.selector == sig:updateUserRiskPremium(address).selector;
    bool isSetCollateral = f.selector == sig:setUsingAsCollateral(uint256, bool, address).selector;
    bool isWithdraw = f.selector == sig:withdraw(uint256, uint256, address).selector;
    bool isDynamicConfig = f.selector == sig:updateUserDynamicConfig(address).selector;

    if (f.selector == sig:setUsingAsCollateral(uint256, bool, address).selector) {
        bool usingAsCollateral;
        require snapUser == currentUser;
        setUsingAsCollateral(e, reserveId, usingAsCollateral, currentUser);
    }
    // timed-out methods called explicitly with all-symbolic arguments (same as f(e, args))
    else if (isRepay) {
        repay(e, reserveId, amount, onBehalfOf);
    }
    else if (isRiskPremium) {
        require snapUser == onBehalfOf;
        updateUserRiskPremium(e, onBehalfOf);
    }
    else if (isWithdraw) {
        require snapUser == onBehalfOf;
        withdraw(e, reserveId, amount, onBehalfOf);
    }
    else if (isDynamicConfig) {
        require snapUser == onBehalfOf;
        updateUserDynamicConfig(e, onBehalfOf);
    }
    else {
        calldataarg args;
        f(e, args);
    }

    require totalCollateralValueGhost >= 0 && totalDebtValueGhost >= 0;
    mathint ps1 = spoke._userPositions[onBehalfOf][reserveId].premiumShares;
    mathint off1 = spoke._userPositions[onBehalfOf][reserveId].premiumOffsetRay;
    mathint dr1 = spoke._userPositions[onBehalfOf][reserveId].drawnShares;
    assertRepayReducesDebt(isRepay, C0, D0, ps0, off0, dr0, ps1, off1, dr1, idx, price);
    assertNotifyPreserves(isRiskPremium, C0, D0);
    assertNotifyPreserves(isDynamicConfig, C0, D0);
    mathint C1 = totalCollateralValueGhost; mathint D1 = totalDebtValueGhost;
    // withdraw / disable collateral: health checked at (pcC, pcD), then the refresh loop preserves it
    bool validated = (isWithdraw || isSetCollateral) && pcCalled;
    assert (isWithdraw || isSetCollateral) && !pcCalled => (D1 == D0 && C1 >= C0), "S1: no health check: debt same, collateral not lower";
    assertHfMonotoneInC((isWithdraw || isSetCollateral) && !pcCalled, C0, D0, C1, D1);
    assert validated => pcHf >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD(), "S2: validated health factor";
    assertNotifyPreserves(validated, pcC, pcD);
    assert ghostHealthFactor[totalCollateralValueGhost][totalDebtValueGhost] >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD();
}
