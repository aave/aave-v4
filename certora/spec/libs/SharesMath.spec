/**
 * @title SharesMath Library Specification
 * @notice Formal verification of mathematical properties for asset-to-share and share-to-asset conversions.
 * @dev This spec verifies monotonicity and additivity for rounding-up and rounding-down conversion functions.
 * 
 * Verification Scope:
 * - Monotonicity: Ensuring larger inputs always result in larger or equal outputs.
 * - Additivity: Verifying that the sum of parts relates correctly to the whole, accounting for state changes.
 * - Non-zero integrity: Ensuring that non-zero assets always result in non-zero shares when rounding up.
 */

import "../HubBase.spec";

////////////////////////////////////////////////////////////////////////////
//                                METHODS                                 //
////////////////////////////////////////////////////////////////////////////

methods { 
    // envfree functions 
    function toSharesDown(uint256 assets, uint256 totalAssets, uint256 totalShares) external returns (uint256) envfree;
    function toAssetsDown(uint256 shares, uint256 totalAssets, uint256 totalShares) external returns (uint256) envfree;
    function toSharesUp(uint256 assets, uint256 totalAssets, uint256 totalShares) external returns (uint256) envfree;
    function toAssetsUp(uint256 shares, uint256 totalAssets, uint256 totalShares) external returns (uint256) envfree;
}

////////////////////////////////////////////////////////////////////////////
//                                 RULES                                  //
////////////////////////////////////////////////////////////////////////////

/**
 * @title toSharesUp Monotonicity
 * @notice Verifies that larger asset amounts result in larger or equal share amounts when rounding up.
 * @link_property ShareMath integrity
 */
rule toSharesUp_monotonicity(uint256 x, uint256 y) {
    uint256 totalAssets; uint256 totalShares;
    require totalAssets >= totalShares;
    
    assert x < y => toSharesUp(x, totalAssets, totalShares) <= toSharesUp(y, totalAssets, totalShares), "Monotonicity violation";
    satisfy x < y && toSharesUp(x, totalAssets, totalShares) == toSharesUp(y, totalAssets, totalShares);
}

/**
 * @title toSharesUp Additivity
 * @notice Verifies that toSharesUp(x) + toSharesUp(y) >= toSharesUp(x+y), accounting for supply/asset changes.
 * @link_property ShareMath integrity
 */
rule toSharesUp_additivity(uint256 x, uint256 y) {
    uint256 totalAssets; uint256 totalShares;
    require totalAssets >= totalShares;
    require totalAssets >= x + y;

    uint256 sharesForX = toSharesUp(x, totalAssets, totalShares);
    uint256 sharesForYAfterX = toSharesUp(y, require_uint256(totalAssets - x), require_uint256(totalShares - sharesForX));
    uint256 sharesForXplusY = toSharesUp(require_uint256(x + y), totalAssets, totalShares);  
    
    assert sharesForXplusY <= (sharesForX + sharesForYAfterX), "Additivity violation (upper bound)";
    satisfy sharesForXplusY == (sharesForX + sharesForYAfterX);
    satisfy sharesForXplusY < (sharesForX + sharesForYAfterX);
}

/**
 * @title toSharesUp Non-Zero Integrity
 * @notice Ensures that any non-zero asset amount results in at least one share when rounding up.
 * @link_property ShareMath integrity
 */
rule toSharesUp_nonZero(uint256 x) {
    uint256 totalAssets; uint256 totalShares;
    require totalAssets >= totalShares;

    uint256 sharesForX = toSharesUp(x, totalAssets, totalShares); 
    assert sharesForX == 0 <=> x == 0, "Non-zero assets must result in non-zero shares";
    satisfy x == 0;
    satisfy x != 0;
}

/**
 * @title toAssetsUp Monotonicity
 * @notice Verifies that larger share amounts result in larger or equal asset amounts when rounding up.
 * @link_property ShareMath integrity
 */
rule toAssetsUp_monotonicity(uint256 x, uint256 y) {
    uint256 totalAssets; uint256 totalShares;
    require totalAssets >= totalShares;
    
    assert x < y => toAssetsUp(x, totalAssets, totalShares) < toAssetsUp(y, totalAssets, totalShares), "Monotonicity violation";
}


/**
 * @title toAssetsUp Additivity
 * @notice Verifies that toAssetsUp(x) + toAssetsUp(y) >= toAssetsUp(x+y), accounting for supply/asset changes.
 * @link_property ShareMath integrity
 */
rule toAssetsUp_additivity(uint256 x, uint256 y) {
    uint256 totalAssets; uint256 totalShares;
    require totalAssets >= totalShares;

    uint256 assetsForX = toAssetsUp(x, totalAssets, totalShares);
    uint256 assetsForYAfterX = toAssetsUp(y, require_uint256(totalAssets + assetsForX), require_uint256(totalShares + x));
    uint256 assetsForXplusY = toAssetsUp(require_uint256(x + y), totalAssets, totalShares);  
    
    assert assetsForXplusY <= assetsForX + assetsForYAfterX, "Additivity violation (upper bound)";
}

/**
 * @title toSharesDown Monotonicity
 * @notice Verifies that larger asset amounts result in larger or equal share amounts when rounding down.
 * @link_property ShareMath integrity
 */
rule toSharesDown_monotonicity(uint256 x, uint256 y) {
    uint256 totalAssets; uint256 totalShares;
    require totalAssets >= totalShares;
    
    assert x < y => toSharesDown(x, totalAssets, totalShares) <= toSharesDown(y, totalAssets, totalShares), "Monotonicity violation";
    satisfy x < y && toSharesDown(x, totalAssets, totalShares) == toSharesDown(y, totalAssets, totalShares);
}

/**
 * @title toSharesDown Additivity
 * @notice Verifies that toSharesDown(x) + toSharesDown(y) <= toSharesDown(x+y), accounting for supply/asset changes.
 * @link_property ShareMath integrity
 */
rule toSharesDown_additivity(uint256 x, uint256 y) {
    uint256 totalAssets; uint256 totalShares;
    require totalAssets >= totalShares;

    uint256 sharesForX = toSharesDown(x, totalAssets, totalShares);
    uint256 sharesForYAfterX = toSharesDown(y, require_uint256(totalAssets + x), require_uint256(totalShares + sharesForX));
    uint256 sharesForXplusY = toSharesDown(require_uint256(x + y), totalAssets, totalShares);  
    
    assert sharesForXplusY >= sharesForX + sharesForYAfterX, "Additivity violation (lower bound)";
}

/**
 * @title toAssetsDown Monotonicity
 * @notice Verifies that larger share amounts result in larger or equal asset amounts when rounding down.
 * @link_property ShareMath integrity
 */
rule toAssetsDown_monotonicity(uint256 x, uint256 y) {
    uint256 totalAssets; uint256 totalShares;
    require totalAssets >= totalShares;
    
    assert x < y => toAssetsDown(x, totalAssets, totalShares) <= toAssetsDown(y, totalAssets, totalShares), "Monotonicity violation";
}

/**
 * @title toAssetsDown Additivity
 * @notice Verifies that toAssetsDown(x) + toAssetsDown(y) <= toAssetsDown(x+y), accounting for supply/asset changes.
 * @link_property ShareMath integrity
 */
rule toAssetsDown_additivity(uint256 x, uint256 y) {
    uint256 totalAssets; uint256 totalShares;
    require totalAssets >= totalShares;

    uint256 assetsForX = toAssetsDown(x, totalAssets, totalShares);
    uint256 assetsForYAfterX = toAssetsDown(y, require_uint256(totalAssets + assetsForX), require_uint256(totalShares + x));
    uint256 assetsForXplusY = toAssetsDown(require_uint256(x + y), totalAssets, totalShares);  
    
    assert assetsForXplusY >= assetsForX + assetsForYAfterX, "Additivity violation (lower bound)";
}
