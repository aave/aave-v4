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
 * @link_property view function integrity over time
 */
rule previewRemoveByShares_withoutAccrue_time_monotonic(uint256 assetId, uint256 shares) {
    env e1; env e2; env e3;
    setup_three_timestamps(assetId, e1, e2, e3);

    mathint assets_e1 = previewRemoveByShares(e1, assetId, shares);
    mathint assets_e2 = previewRemoveByShares(e2, assetId, shares);
    mathint assets_e3 = previewRemoveByShares(e3, assetId, shares);

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
 * @link_property view function integrity over time
 */
rule previewRemoveByAssets_withoutAccrue_time_monotonic(uint256 assetId, uint256 assets) {
    env e1; env e2; env e3;
    setup_three_timestamps(assetId, e1, e2, e3);

    mathint shares_e1 = previewRemoveByAssets(e1, assetId, assets);
    mathint shares_e2 = previewRemoveByAssets(e2, assetId, assets);
    mathint shares_e3 = previewRemoveByAssets(e3, assetId, assets);

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