/**
 * @title Hub Additivity Specification
 * @notice Verify the additivity of the operations: add, remove, draw, restore, reportDeficit, eliminateDeficit
 * @dev For each operation, we verify that splitting an operation to two operations is less beneficial to the user than doing it in one step.
 *

 *
 * To run this spec file:
 * certoraRun certora/conf/HubAdditivity.conf
 */

import "./symbolicRepresentation/ERC20s_CVL.spec";
import "./symbolicRepresentation/Math_CVL.spec";
import "./Hub.spec";

// Record inputs and result of rounded up muldivCalls 
// Split proof of removeAdditivity: inputs and result of the last ceil Math.mulDiv
// (same body as Math_CVL.spec + ghost writes).
ghost mathint mdCx; ghost mathint mdCy; ghost mathint mdCden; ghost mathint mdCres;

// override preserves the imported summary’s arithmetic and records these values before returning
override function mulDivCVL(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) returns uint256 {
    if (denominator == 0) {
        revert();
    }
    mathint product = x * y;
    if (rounding == Math.Rounding.Ceil) {
        uint256 res = require_uint256((product + denominator - 1) / denominator);
        // Save result in ghosts variable
        mdCx = x; mdCy = y; mdCden = denominator; mdCres = res;
        return res;
    } else { // Math.Rounding.Floor
        return require_uint256(product / denominator);
    }
}

////////////////////////////////////////////////////////////////////////////
//                                 RULES                                  //
////////////////////////////////////////////////////////////////////////////

/**
 * @title Adding in two steps is less beneficial to the user than doing it in one step
 * @link_property additivity of the operations
 */
rule addAdditivity(uint256 assetId, uint256 amountX, uint256 amountY, address from) {
    env e;
    address spoke = e.msg.sender;
    setup_additivity(assetId,e);
    storage init = lastStorage;

    add(e, assetId, amountX);
    add(e, assetId, amountY);
    uint256 afterTwoSteps = getSpokeAddedShares(e, assetId, spoke);

    //expecting the code to enforce that amountX+amountY can not overflow
    add(e, assetId, assert_uint256(amountX + amountY)) at init;
    uint256 afterOneStep = getSpokeAddedShares(e, assetId, spoke);

    //rounding should be in favor of the house
    assert afterOneStep >= afterTwoSteps;
    satisfy afterOneStep > afterTwoSteps;
}

/**     
* @title Removing in two steps is less beneficial to the user than doing it in one step
* @dev Split proof (multi_assert_check). Shares burned by remove(a) = ceil(a * S / A).
*      s1 = ceil(X*S/A), s2 = ceil(Y*S1/A1) with S1 = S - s1, A1 = A - X, s12 = ceil((X+Y)*S/A); delta = s1*A - X*S >= 0.
*      No underflow in step 2 gives s2 < S1, hence Y < A1. Then s2*A >= Y*S - delta, so (s1+s2)*A >= (X+Y)*S > (s12-1)*A.
* @link_property additivity of the operations
**/
rule removeAdditivity(uint256 assetId, uint256 amountX, uint256 amountY, address from) {
    env e;
    address spoke = e.msg.sender;
    setup_additivity(assetId,e);
    // Read storage
    mathint sharesInit = hub._spokes[assetId][spoke].addedShares;
    storage init = lastStorage;

    remove(e, assetId, amountX, from);
    // Conversion inputs and shares burned by first withdrawal
    mathint x1 = mdCx; mathint y1 = mdCy; mathint d1 = mdCden; mathint s1 = mdCres;
    remove(e, assetId, amountY, from);
    // Conversion inputs and shares burned by second withdrawal
    mathint x2 = mdCx; mathint y2 = mdCy; mathint d2 = mdCden; mathint s2 = mdCres;
    // Hub asset's remaining total shares
    mathint assetSharesAfterTwoSteps = hub._assets[assetId].addedShares;
    uint256 afterTwoSteps = getSpokeAddedShares(e, assetId, spoke);

    // Expecting the code to enforce that amountX+amountY can not overflow
    remove(e, assetId, assert_uint256(amountX + amountY), from)at init;
    // Combined withdrawal's conversion
    mathint x3 = mdCx; mathint y3 = mdCy; mathint d3 = mdCden; mathint s12 = mdCres;
    uint256 afterOneStep = getSpokeAddedShares(e, assetId, spoke);

    // Delta measures the first withdrawal's rounding excess
    mathint delta = s1 * d1 - x1 * y1;

    // link captured values to the code
    assert x1 == amountX && x2 == amountY && x3 == amountX + amountY, "K1: mulDiv amounts";
    assert y3 == y1 && d3 == d1, "K2: one step starts from same state";
    assert y2 == y1 - s1, "K3: shares after first remove";
    assert d2 == d1 - amountX, "K4: assets after first remove";
    assert afterTwoSteps == sharesInit - s1 - s2, "K5: two-step spoke shares";
    assert afterOneStep == sharesInit - s12, "K6: one-step spoke shares";
    assert d1 > 0 && d2 > 0, "K7: denominators positive";

    // arithmetic chain
    // Express ceiling rounding bounds
    assert s1 * d1 >= x1 * y1, "L1: ceil step 1";
    assert s2 * d2 >= x2 * y2, "L2: ceil step 2";
    assert y2 == assetSharesAfterTwoSteps + s2 + 10^6, "N1a: S1 = asset shares after step 2 + s2 + virtual";
    assert s2 + 10^6 <= y2, "N1: no underflow in step 2";
    assert x2 * y2 < y2 * d2, "N2a: L2, N1";
    assert x2 < d2, "N2: Y < A1";
    assert s2 * d1 * d2 >= x2 * y1 * d2 - x2 * delta, "M1: L2 * A, substitute S1";
    assert delta * (d2 - x2) >= 0, "M2: delta >= 0, Y < A1";
    assert s2 * d1 * d2 >= (x2 * y1 - delta) * d2, "M3: M1 + M2";
    assert s2 * d1 >= x2 * y1 - delta, "M4: divide by A1";
    assert (s1 + s2) * d1 >= x3 * y1, "L5: sum";
    assert (s12 - 1) * d1 < x3 * y3, "L6: ceil lower bound";
    assert s1 + s2 >= s12, "L7: integer bound";

    //rounding should be in favor of the house
    assert afterOneStep >= afterTwoSteps;
}


/**
* @title Drawing in two steps is less beneficial to the user than doing it in one step
* @link_property additivity of the operations
**/
rule drawAdditivity(uint256 assetId, uint256 amountX, uint256 amountY, address from) {
    env e;
    address spoke = e.msg.sender;
    setup_additivity(assetId,e);
    storage init = lastStorage;

    draw(e, assetId, amountX, from);
    draw(e, assetId, amountY, from);
    uint256 afterTwoSteps = getSpokeDrawnShares(e, assetId, spoke) ;
    //expecting the code to enforce that amountX+amountY can not overflow
    draw(e, assetId, assert_uint256(amountX + amountY), from)at init;
    uint256 afterOneStep = getSpokeDrawnShares(e, assetId, spoke);

    //rounding should be in favor of the house
    assert afterOneStep <= afterTwoSteps;
    satisfy afterOneStep < afterTwoSteps;
}

/**
@title Restoring in two steps is less beneficial to the user than doing it in one step
* @link_property additivity of the operations
**/
rule restoreAdditivity(uint256 assetId, uint256 amountX, uint256 amountY, address from) {
    env e;
    address spoke = e.msg.sender;
    setup_additivity(assetId,e);
    storage init = lastStorage;

    IHubBase.PremiumDelta premiumDeltaX;
    IHubBase.PremiumDelta premiumDeltaY;       
    IHubBase.PremiumDelta premiumDeltaXY;
    require premiumDeltaXY.sharesDelta == premiumDeltaX.sharesDelta + premiumDeltaY.sharesDelta;
    require premiumDeltaXY.offsetRayDelta == premiumDeltaX.offsetRayDelta + premiumDeltaY.offsetRayDelta;
    require premiumDeltaXY.restoredPremiumRay == premiumDeltaX.restoredPremiumRay + premiumDeltaY.restoredPremiumRay;
    
    restore(e, assetId, amountX, premiumDeltaX);
    restore(e, assetId, amountY, premiumDeltaY);
    uint256 drawnSharesAfterTwoSteps = hub._spokes[assetId][spoke].drawnShares;
    uint256 premiumSharesAfterTwoSteps = hub._spokes[assetId][spoke].premiumShares;
    int200 premiumOffsetRayAfterTwoSteps = hub._spokes[assetId][spoke].premiumOffsetRay;
   
    //expecting the code to enforce that amountX+amountY can not overflow
    restore(e, assetId, assert_uint256(amountX + amountY), premiumDeltaXY) at init;
   
    uint256 drawnSharesAfterOneStep = hub._spokes[assetId][spoke].drawnShares;
    uint256 premiumSharesAfterOneStep = hub._spokes[assetId][spoke].premiumShares;
    int200 premiumOffsetRayAfterOneStep = hub._spokes[assetId][spoke].premiumOffsetRay;
   
    assert drawnSharesAfterOneStep <= drawnSharesAfterTwoSteps;
    assert premiumSharesAfterOneStep == premiumSharesAfterTwoSteps;
    assert premiumOffsetRayAfterOneStep == premiumOffsetRayAfterTwoSteps;
    satisfy drawnSharesAfterOneStep < drawnSharesAfterTwoSteps;
}

/**
@title Reporting deficit in two steps is less beneficial to the user than doing it in one step
* @link_property additivity of the operations
**/
rule reportDeficitAdditivity(uint256 assetId, uint256 amountX, uint256 amountY) {
    env e;
    address spoke = e.msg.sender;
    setup_additivity(assetId,e);
    storage init = lastStorage;
    IHubBase.PremiumDelta premiumDeltaX;
    IHubBase.PremiumDelta premiumDeltaY;       
    IHubBase.PremiumDelta premiumDeltaXY;

    require premiumDeltaXY.sharesDelta == premiumDeltaX.sharesDelta + premiumDeltaY.sharesDelta;
    require premiumDeltaXY.offsetRayDelta == premiumDeltaX.offsetRayDelta + premiumDeltaY.offsetRayDelta;
    require premiumDeltaXY.restoredPremiumRay == premiumDeltaX.restoredPremiumRay + premiumDeltaY.restoredPremiumRay;
   

    reportDeficit(e, assetId, amountX, premiumDeltaX);
    reportDeficit(e, assetId, amountY, premiumDeltaY);
    
    uint256 drawnSharesAfterTwoSteps = hub._spokes[assetId][spoke].drawnShares;
    uint256 premiumSharesAfterTwoSteps = hub._spokes[assetId][spoke].premiumShares;
    int200 premiumOffsetRayAfterTwoSteps = hub._spokes[assetId][spoke].premiumOffsetRay;
    uint256 deficitRayAfterTwoSteps = hub._spokes[assetId][spoke].deficitRay;
    //expecting the code to enforce that amountX+amountY can not overflow
    reportDeficit(e, assetId, assert_uint256(amountX + amountY), premiumDeltaXY) at init;
    uint256 drawnSharesAfterOneStep = hub._spokes[assetId][spoke].drawnShares;
    uint256 premiumSharesAfterOneStep = hub._spokes[assetId][spoke].premiumShares;
    int200 premiumOffsetRayAfterOneStep = hub._spokes[assetId][spoke].premiumOffsetRay;
    uint256 deficitRayAfterOneStep = hub._spokes[assetId][spoke].deficitRay;
   

    assert drawnSharesAfterOneStep <= drawnSharesAfterTwoSteps;
    assert premiumSharesAfterOneStep == premiumSharesAfterTwoSteps;
    assert premiumOffsetRayAfterOneStep == premiumOffsetRayAfterTwoSteps;
    assert deficitRayAfterOneStep >= deficitRayAfterTwoSteps;

    satisfy drawnSharesAfterOneStep < drawnSharesAfterTwoSteps && deficitRayAfterOneStep > deficitRayAfterTwoSteps;
}

/**
@title Prove that eliminating deficit in two steps is less beneficial to the user than doing it in one step
@notice Can only compare deficit ray as supply shares cause timeouts 
* @link_property additivity of the operations
**/
rule eliminateDeficitAdditivity_DeficitRay(uint256 assetId, uint256 amountX, uint256 amountY, address spoke) {
    env e;
   
    setup_additivity(assetId,e);
    storage init = lastStorage;
    eliminateDeficit(e, assetId, amountX, spoke);
    eliminateDeficit(e, assetId, amountY, spoke);

    uint256 addedSharesAfterTwoSteps = hub._spokes[assetId][e.msg.sender].addedShares;
    uint256 deficitRayAfterTwoSteps = hub._spokes[assetId][spoke].deficitRay;

    //expecting the code to enforce that amountX+amountY can not overflow
    eliminateDeficit(e, assetId, require_uint256(amountX + amountY), spoke) at init;
    uint256 addedSharesAfterOneStep = hub._spokes[assetId][e.msg.sender].addedShares;
    uint256 deficitRayAfterOneStep = hub._spokes[assetId][spoke].deficitRay;
    
    assert deficitRayAfterOneStep == deficitRayAfterTwoSteps;
}


function setup_additivity(uint256 assetId, env e)  {
    //requireInvariant totalAssetsVsShares(assetId,e);
    require getAddedAssets(e,assetId) >= getAddedShares(e,assetId);
}
