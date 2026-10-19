/**
 * @title Hub Accrue Supply Rate Specification
 * @notice Prove that accrue cannot decrease the share rate
 * @dev Assets / shares is increasing over time
 * @safe_assumption getDrawnIndex is the same value  in the same block timestamp, rule runningTwiceIsEquivalentToOne
 */

import "./HubBase.spec";

using HubHarness as hub;


////////////////////////////////////////////////////////////////////////////
//                                METHODS                                 //
////////////////////////////////////////////////////////////////////////////

methods {
    function AssetLogic.getDrawnIndex(IHub.Asset storage asset) internal returns (uint256) with (env e) => symbolicDrawnIndex(e.block.timestamp);
}


////////////////////////////////////////////////////////////////////////////
//                              GHOST VARIABLES                           //
////////////////////////////////////////////////////////////////////////////

// Symbolic representation of drawnIndex that is a function of the block timestamp.
ghost symbolicDrawnIndex(uint256) returns uint256;

// Split proofs of previewRemoveBy{Shares,Assets}_withoutAccrue_time_monotonic: inputs of the
// last Math.mulDiv (the SharesMath conversion in a preview call); same body as Math_CVL.spec + ghost writes.
ghost mathint mdX; ghost mathint mdY; ghost mathint mdDen;

override function mulDivCVL(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) returns uint256 {
    if (denominator == 0) {
        revert();
    }
    mathint product = x * y;
    uint256 res;
    if (rounding == Math.Rounding.Ceil) {
        res = require_uint256((product + denominator - 1) / denominator);
    } else { // Math.Rounding.Floor
        res = require_uint256(product / denominator);
    }
    // Record captured values for the proof
    mdX = x; mdY = y; mdDen = denominator;
    return res;
}

////////////////////////////////////////////////////////////////////////////
//                                  RULES                                 //
////////////////////////////////////////////////////////////////////////////

/**
 * @title Prove that accrue cannot decrease the share rate
 * @notice Given e1, a timestamp last accrue, we prove that the share rate is the same or increasing at e2
 * @dev We prove this for the maximum value of getUnrealizedFees, as proved in HubAccrueIntegrityUnrealizedFee.spec
 *      Therefore, it holds for any smaller value of getUnrealizedFees, as shares_e2 will be smaller
 * @link_property share rate integrity
 */
rule accrueSupplyRate(uint256 assetId) {
    env e1; env e2;
    uint256 oneM = 1000000;
    require e1.block.timestamp < e2.block.timestamp;

    // e1 is the last accrued timestamp
    require hub._assets[assetId].lastUpdateTimestamp != 0 && hub._assets[assetId].lastUpdateTimestamp == e1.block.timestamp;
    require hub._assets[assetId].liquidityFee <= PERCENTAGE_FACTOR, "invariant liquidityFee_upper_bound";

    // Correlate the drawn index with the symbolic one, assume increasing and min value as proved in
    // HubAccrueIntegrityDrawnIndex.spec
    require hub._assets[assetId].drawnIndex == symbolicDrawnIndex(e1.block.timestamp);
    // Based on rule drawnIndex_increasing(assetId);
    require symbolicDrawnIndex(e1.block.timestamp) <= symbolicDrawnIndex(e2.block.timestamp);
    // Based on requireInvariant baseDebtIndexMin(assetId);
    require symbolicDrawnIndex(e1.block.timestamp) >= RAY;

    mathint assets_e1 = getAddedAssets(e1, assetId);
    mathint shares_e1 = hub._assets[assetId].addedShares;
    // requireInvariant totalAssetsVsShares(assetId,e);
    require assets_e1 >= shares_e1;

    // Accrue interest
    accrueInterest(e2, assetId);
    mathint assets_e2 = getAddedAssets(e2, assetId);
    mathint shares_e2 = hub._assets[assetId].addedShares;

    // Verify the assumption that total added assets is always greater than or equal to added shares
    assert assets_e2 >= shares_e2;

    assert (assets_e2 + oneM) * (shares_e1 + oneM) >= (assets_e1 + oneM) * (shares_e2 + oneM);
    satisfy (assets_e2 + oneM) * (shares_e1 + oneM) > (assets_e1 + oneM) * (shares_e2 + oneM);
}

/**
 * @title Check assumption that total added shares matches hub storage
 */
rule checkAssumptionTotalAddedShares(uint256 assetId, env e) {
    assert hub._assets[assetId].addedShares == getAddedShares(e, assetId);
}

////////////////////////////////////////////////////////////////////////////
//                              HELPER FUNCTIONS                          //
////////////////////////////////////////////////////////////////////////////

function setup_three_timestamps(uint256 assetId, env e1, env e2, env e3) {
    require e1.block.timestamp < e2.block.timestamp && e2.block.timestamp < e3.block.timestamp;

    require hub._assets[assetId].lastUpdateTimestamp != 0 && hub._assets[assetId].lastUpdateTimestamp == e1.block.timestamp;
    // Correlate the drawn index with the symbolic one, assume increasing and min value as proved in
    // HubAccrueIntegrityDrawnIndex.spec
    require hub._assets[assetId].drawnIndex == symbolicDrawnIndex(e1.block.timestamp);
    // Based on rule drawnIndex_increasing(assetId);
    require symbolicDrawnIndex(e1.block.timestamp) <= symbolicDrawnIndex(e2.block.timestamp);
    require symbolicDrawnIndex(e2.block.timestamp) <= symbolicDrawnIndex(e3.block.timestamp);
    // Based on requireInvariant baseDebtIndexMin(assetId);
    require symbolicDrawnIndex(e1.block.timestamp) >= RAY;
    require hub._assets[assetId].liquidityFee <= PERCENTAGE_FACTOR, "invariant liquidityFee_upper_bound";
}


/**
 * @title Share rate is monotonic over time without accrue
 * @link_property share rate integrity
 */
rule shareRate_withoutAccrue_time_monotonic(uint256 assetId) {
    env e1; env e2; env e3;
    setup_three_timestamps(assetId, e1, e2, e3);
    require hub._assets[assetId].liquidityFee <= PERCENTAGE_FACTOR, "invariant liquidityFee_upper_bound";

    mathint assets_e1 = getAddedAssets(e1, assetId);
    // Proved in checkAssumptionTotalAddedShares that totalAddedShares is always the hub._assets[assetId].addedShares
    mathint shares = hub._assets[assetId].addedShares;
    // requireInvariant totalAssetsVsShares(assetId,e);
    require assets_e1 >= shares;

    // Get the fee shares and asset at e2
    mathint assets_e2 = getAddedAssets(e2, assetId);

    // Get the fee shares and asset at e3
    mathint assets_e3 = getAddedAssets(e3, assetId);

    // We prove this:
    // assert (assets_e3 + oneM) * (shares + oneM) >= (assets_e2 + oneM) * (shares + oneM);
    // by proving:
    assert assets_e3 >= assets_e2;
}


/**
 * @title Preview remove by shares is monotonic over time without accrue
 * @dev Split proof (multi_assert_check). With i0 = i1 <= i2 <= i3, Ou(i) = ceil(owedRay(i) / RAY),
 *      D(i) = Ou(i) - Ou(i0), UF(i) = floor(D(i) * fee / PF): TA(i) = C + Ou(i) - UF(i) is monotone because
 *      D - floor(D * fee / PF) is non-decreasing for fee <= PF. The preview is a floor/ceil conversion by TA + 1e6.
 * @link_property view function integrity over time
 */
rule previewRemoveByShares_withoutAccrue_time_monotonic(uint256 assetId, uint256 shares) {
    env e1; env e2; env e3;
    setup_three_timestamps(assetId, e1, e2, e3);


    // CVL model of totalAddedAssets at each index (split proof)
    mathint V = 10^6;
    mathint i0 = hub._assets[assetId].drawnIndex;
    mathint i1 = symbolicDrawnIndex(e1.block.timestamp);
    mathint i2 = symbolicDrawnIndex(e2.block.timestamp);
    mathint i3 = symbolicDrawnIndex(e3.block.timestamp);
    mathint dS = hub._assets[assetId].drawnShares;
    mathint pS = hub._assets[assetId].premiumShares;
    mathint off = hub._assets[assetId].premiumOffsetRay;
    mathint def = hub._assets[assetId].deficitRay;
    mathint fee = hub._assets[assetId].liquidityFee;
    mathint C = hub._assets[assetId].liquidity + hub._assets[assetId].swept - hub._assets[assetId].realizedFees;
    mathint S = hub._assets[assetId].addedShares;
    // Reconstruct aggregated owed amount at each index (drawn debt, premium debt, and deficit)
    mathint O0 = dS * i0 + (pS * i0 - off) + def;
    mathint O1 = dS * i1 + (pS * i1 - off) + def;
    mathint O2 = dS * i2 + (pS * i2 - off) + def;
    mathint O3 = dS * i3 + (pS * i3 - off) + def;
    // convert amounts into asset units rounding up
    mathint Ou0 = (O0 + RAY - 1) / RAY;
    mathint Ou1 = (O1 + RAY - 1) / RAY;
    mathint Ou2 = (O2 + RAY - 1) / RAY;
    mathint Ou3 = (O3 + RAY - 1) / RAY;
    // Calculate growth 
    mathint D2 = Ou2 - Ou0;
    mathint D3 = Ou3 - Ou0;
    // Calculate fees
    mathint UF2 = (i2 == i0 || fee == 0) ? 0 : (D2 * fee) / PERCENTAGE_FACTOR;
    mathint UF3 = (i3 == i0 || fee == 0) ? 0 : (D3 * fee) / PERCENTAGE_FACTOR;
    // Reconstruct total added assets at each timestamp
    mathint TA1 = C + Ou1;
    mathint TA2 = C + Ou2 - UF2;
    mathint TA3 = C + Ou3 - UF3;

    mathint assets_e1 = previewRemoveByShares(e1, assetId, shares);
    // Record captured values for the proof
    mathint x1 = mdX; mathint y1 = mdY; mathint n1 = mdDen;
    mathint assets_e2 = previewRemoveByShares(e2, assetId, shares);
    // Record captured values for the proof
    mathint x2 = mdX; mathint y2 = mdY; mathint n2 = mdDen;
    mathint assets_e3 = previewRemoveByShares(e3, assetId, shares);
    // Record captured values for the proof
    mathint x3 = mdX; mathint y3 = mdY; mathint n3 = mdDen;

    // link captured values to the code
    assert x1 == shares && x2 == shares && x3 == shares, "K1: mulDiv amount";
    assert n1 == S + V && n2 == S + V && n3 == S + V, "K2: mulDiv denominator = S + V";
    assert y1 == TA1 + V, "K3: e1 totalAddedAssets (UF = 0)";
    assert y2 == TA2 + V, "K4: e2 totalAddedAssets";
    assert y3 == TA3 + V, "K5: e3 totalAddedAssets";

    // TA monotone
    assert O1 <= O2 && O2 <= O3, "M1: owed monotone";
    assert Ou1 == Ou0 && Ou1 <= Ou2 && Ou2 <= Ou3, "M2: owedUp monotone";
    assert 0 <= D2 && D2 <= D3, "M2b: D monotone";
    assert UF2 * PERCENTAGE_FACTOR <= D2 * fee && D2 * fee < (UF2 + 1) * PERCENTAGE_FACTOR, "M3a: UF2 is floor";
    assert UF3 * PERCENTAGE_FACTOR <= D3 * fee, "M3b: UF3 floor lower bound";
    assert (UF3 - UF2 - 1) * PERCENTAGE_FACTOR < (D3 - D2) * fee, "M4a: floor difference";
    assert (D3 - D2) * fee <= (D3 - D2) * PERCENTAGE_FACTOR, "M4b: fee <= PF";
    assert UF3 - UF2 <= D3 - D2, "M4: UF grows slower than D";
    assert UF2 <= D2, "M4c: UF2 <= D2";
    assert TA1 <= TA2 && TA2 <= TA3, "M5: TA monotone";

    // floor conversion
    assert assets_e1 * n1 <= x1 * y1 && assets_e2 * n2 <= x2 * y2, "F1: floor lower";
    assert (assets_e2 + 1) * n2 > x2 * y2 && (assets_e3 + 1) * n3 > x3 * y3, "F2: floor upper";
    assert shares * y1 <= shares * y2 && shares * y2 <= shares * y3, "F3: scale by shares";

    assert assets_e3 >= assets_e2;
    assert assets_e2 >= assets_e1;
}


/**
 * @title Preview add by assets is monotonic over time without accrue
 * @link_property view function integrity over time
 */
rule previewAddByAssets_withoutAccrue_time_monotonic(uint256 assetId, uint256 assets) {
    env e1; env e2; env e3;
    setup_three_timestamps(assetId, e1, e2, e3);

    mathint shares_e1 = previewAddByAssets(e1, assetId, assets);
    mathint shares_e2 = previewAddByAssets(e2, assetId, assets);
    mathint shares_e3 = previewAddByAssets(e3, assetId, assets);

    assert shares_e3 <= shares_e2 && shares_e2 <= shares_e1;
}


/**
 * @title Preview add by shares is monotonic over time without accrue
 * @notice Due to timeouts Prove that previewAddByShares is monotonic over time without accrue for the case where liquidityFee is 0, PERCENTAGE_FACTOR or PERCENTAGE_FACTOR / 2
 * @link_property view function integrity over time
 */
rule previewAddByShares_withoutAccrue_time_monotonic_part1(uint256 assetId, uint256 shares) {
    env e1; env e2; env e3;
    setup_three_timestamps(assetId, e1, e2, e3);
    uint256 liquidityFee = hub._assets[assetId].liquidityFee;
    require liquidityFee == PERCENTAGE_FACTOR
    ||  liquidityFee == 0 ||liquidityFee == PERCENTAGE_FACTOR / 2;

    mathint assets_e2 = previewAddByShares(e2, assetId, shares);
    mathint assets_e3 = previewAddByShares(e3, assetId, shares);

    assert assets_e3 >= assets_e2;

}

/**
 * @title Preview add by shares is monotonic over time without accrue
 * @link_property view function integrity over time
 */
rule previewAddByShares_withoutAccrue_time_monotonic_part2(uint256 assetId, uint256 shares) {
    env e1; env e2; env e3;
    setup_three_timestamps(assetId, e1, e2, e3);

    mathint assets_e1 = previewAddByShares(e1, assetId, shares);
    mathint assets_e2 = previewAddByShares(e2, assetId, shares);

    assert assets_e2 >= assets_e1;
}


/**
 * @title Preview remove by assets is monotonic over time without accrue
 * @dev Split proof (multi_assert_check). With i0 = i1 <= i2 <= i3, Ou(i) = ceil(owedRay(i) / RAY),
 *      D(i) = Ou(i) - Ou(i0), UF(i) = floor(D(i) * fee / PF): TA(i) = C + Ou(i) - UF(i) is monotone because
 *      D - floor(D * fee / PF) is non-decreasing for fee <= PF. The preview is a floor/ceil conversion by TA + 1e6.
 * @link_property view function integrity over time
 */
rule previewRemoveByAssets_withoutAccrue_time_monotonic(uint256 assetId, uint256 assets) {
    env e1; env e2; env e3;
    setup_three_timestamps(assetId, e1, e2, e3);


    // CVL model of totalAddedAssets at each index (split proof)
    mathint V = 10^6;
    mathint i0 = hub._assets[assetId].drawnIndex;
    mathint i1 = symbolicDrawnIndex(e1.block.timestamp);
    mathint i2 = symbolicDrawnIndex(e2.block.timestamp);
    mathint i3 = symbolicDrawnIndex(e3.block.timestamp);
    mathint dS = hub._assets[assetId].drawnShares;
    mathint pS = hub._assets[assetId].premiumShares;
    mathint off = hub._assets[assetId].premiumOffsetRay;
    mathint def = hub._assets[assetId].deficitRay;
    mathint fee = hub._assets[assetId].liquidityFee;
    mathint C = hub._assets[assetId].liquidity + hub._assets[assetId].swept - hub._assets[assetId].realizedFees;
    mathint S = hub._assets[assetId].addedShares;
    mathint O0 = dS * i0 + (pS * i0 - off) + def;
    mathint O1 = dS * i1 + (pS * i1 - off) + def;
    mathint O2 = dS * i2 + (pS * i2 - off) + def;
    mathint O3 = dS * i3 + (pS * i3 - off) + def;
    mathint Ou0 = (O0 + RAY - 1) / RAY;
    mathint Ou1 = (O1 + RAY - 1) / RAY;
    mathint Ou2 = (O2 + RAY - 1) / RAY;
    mathint Ou3 = (O3 + RAY - 1) / RAY;
    mathint D2 = Ou2 - Ou0;
    mathint D3 = Ou3 - Ou0;
    mathint UF2 = (i2 == i0 || fee == 0) ? 0 : (D2 * fee) / PERCENTAGE_FACTOR;
    mathint UF3 = (i3 == i0 || fee == 0) ? 0 : (D3 * fee) / PERCENTAGE_FACTOR;
    mathint TA1 = C + Ou1;
    mathint TA2 = C + Ou2 - UF2;
    mathint TA3 = C + Ou3 - UF3;

    mathint shares_e1 = previewRemoveByAssets(e1, assetId, assets);
    mathint x1 = mdX; mathint y1 = mdY; mathint n1 = mdDen;
    mathint shares_e2 = previewRemoveByAssets(e2, assetId, assets);
    mathint x2 = mdX; mathint y2 = mdY; mathint n2 = mdDen;
    mathint shares_e3 = previewRemoveByAssets(e3, assetId, assets);
    mathint x3 = mdX; mathint y3 = mdY; mathint n3 = mdDen;

    // link captured values to the code
    assert x1 == assets && x2 == assets && x3 == assets, "K1: mulDiv amount";
    assert y1 == S + V && y2 == S + V && y3 == S + V, "K2: mulDiv multiplier = S + V";
    assert n1 == TA1 + V, "K3: e1 totalAddedAssets (UF = 0)";
    assert n2 == TA2 + V, "K4: e2 totalAddedAssets";
    assert n3 == TA3 + V, "K5: e3 totalAddedAssets";

    // TA monotone
    assert O1 <= O2 && O2 <= O3, "M1: owed monotone";
    assert Ou1 == Ou0 && Ou1 <= Ou2 && Ou2 <= Ou3, "M2: owedUp monotone";
    assert 0 <= D2 && D2 <= D3, "M2b: D monotone";
    assert UF2 * PERCENTAGE_FACTOR <= D2 * fee && D2 * fee < (UF2 + 1) * PERCENTAGE_FACTOR, "M3a: UF2 is floor";
    assert UF3 * PERCENTAGE_FACTOR <= D3 * fee, "M3b: UF3 floor lower bound";
    assert (UF3 - UF2 - 1) * PERCENTAGE_FACTOR < (D3 - D2) * fee, "M4a: floor difference";
    assert (D3 - D2) * fee <= (D3 - D2) * PERCENTAGE_FACTOR, "M4b: fee <= PF";
    assert UF3 - UF2 <= D3 - D2, "M4: UF grows slower than D";
    assert UF2 <= D2, "M4c: UF2 <= D2";
    assert TA1 <= TA2 && TA2 <= TA3, "M5: TA monotone";

    // ceil conversion: shares = ceil(assets * (S + V) / (TA + V))
    mathint xy = assets * (S + V);
    assert shares_e1 * n1 >= xy && shares_e2 * n2 >= xy, "C1: ceil lower";
    assert (shares_e2 - 1) * n2 < xy && (shares_e3 - 1) * n3 < xy, "C2: ceil upper";
    assert shares_e1 * n1 <= shares_e1 * n2 && shares_e2 * n2 <= shares_e2 * n3, "C4: scale by larger TA";
    assert (shares_e2 - 1) * n2 < shares_e1 * n2, "C5: e2 vs e1";
    assert (shares_e3 - 1) * n3 < shares_e2 * n3, "C6: e3 vs e2";

    assert shares_e3 <= shares_e2 && shares_e2 <= shares_e1;
}



/**
 * @title Preview draw by assets is monotonic over time without accrue
 * @link_property view function integrity over time
 */
rule previewDrawByAssets_withoutAccrue_time_monotonic(uint256 assetId, uint256 assets) {
    env e1; env e2; env e3;
    setup_three_timestamps(assetId, e1, e2, e3);

    mathint shares_e1 = previewDrawByAssets(e1, assetId, assets);
    mathint shares_e2 = previewDrawByAssets(e2, assetId, assets);
    mathint shares_e3 = previewDrawByAssets(e3, assetId, assets);

    assert shares_e3 <= shares_e2 && shares_e2 <= shares_e1;
}


/**
 * @title Preview draw by shares is monotonic over time without accrue
 * @link_property view function integrity over time
 */
rule previewDrawByShares_withoutAccrue_time_monotonic(uint256 assetId, uint256 shares) {
    env e1; env e2; env e3;
    setup_three_timestamps(assetId, e1, e2, e3);

    mathint assets_e1 = previewDrawByShares(e1, assetId, shares);
    mathint assets_e2 = previewDrawByShares(e2, assetId, shares);
    mathint assets_e3 = previewDrawByShares(e3, assetId, shares);

    assert assets_e3 >= assets_e2 && assets_e2 >= assets_e1;
}



/**
 * @title Preview restore by assets is monotonic over time without accrue
 * @link_property view function integrity over time
 */
rule previewRestoreByAssets_withoutAccrue_time_monotonic(uint256 assetId, uint256 assets) {
    env e1; env e2; env e3;
    setup_three_timestamps(assetId, e1, e2, e3);

    mathint shares_e1 = previewRestoreByAssets(e1, assetId, assets);
    mathint shares_e2 = previewRestoreByAssets(e2, assetId, assets);
    mathint shares_e3 = previewRestoreByAssets(e3, assetId, assets);

    assert shares_e3 <= shares_e2 && shares_e2 <= shares_e1;
}


/**
 * @title Preview restore by shares is monotonic over time without accrue
 * @link_property view function integrity over time
*/
rule previewRestoreByShares_withoutAccrue_time_monotonic(uint256 assetId, uint256 shares) {
    env e1; env e2; env e3;
    setup_three_timestamps(assetId, e1, e2, e3);

    mathint assets_e1 = previewRestoreByShares(e1, assetId, shares);
    mathint assets_e2 = previewRestoreByShares(e2, assetId, shares);
    mathint assets_e3 = previewRestoreByShares(e3, assetId, shares);

    assert assets_e3 >= assets_e2 && assets_e2 >= assets_e1;
}