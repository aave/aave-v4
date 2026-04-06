
/**
Verify  the additivity of the operation: add, remove, draw, restore, reportDeficit, eliminateDeficit.
For each operation, we verify that splitting an operation to two operations is less beneficial to the user than doing it in one step.

This spec uses summarization to the shareMath library. The summarization follow the proof in ShareMath.spec. The rules of SharesMath.spec are verified on the CVL representation.

To run this spec file:
 certoraRun certora/conf/HubAdditivity.conf 

**/

import "./symbolicRepresentation/ERC20s_CVL.spec";
import "./symbolicRepresentation/Math_CVL.spec";
import "./libs/SharesMath.spec";
import "./common.spec";

methods {
    function SharesMath.toSharesDown(uint256 assets, uint256 totalAssets, uint256 totalShares) internal returns (uint256) =>
            symbolic_toSharesDown(assets, totalAssets, totalShares) ;
    function SharesMath.toAssetsDown(uint256 shares, uint256 totalAssets, uint256 totalShares) internal returns (uint256) =>
            symbolic_toAssetsDown(shares, totalAssets, totalShares) ; 
    function SharesMath.toSharesUp(uint256 assets, uint256 totalAssets, uint256 totalShares) internal returns (uint256) =>
            symbolic_toSharesUp(assets, totalAssets, totalShares) ; 
    function SharesMath.toAssetsUp(uint256 shares, uint256 totalAssets, uint256 totalShares) internal returns (uint256) =>
            symbolic_toAssetsUp(shares, totalAssets, totalShares) ; 

}
ghost symbolic_toSharesDown(mathint /*assets*/, mathint /*totalAssets*/, mathint /*totalShares*/) returns uint256 {
        // monotonicity
        axiom forall mathint x. forall mathint y. forall mathint ta. forall mathint ts. 
                x > y => symbolic_toSharesDown(x, ta, ts) >= symbolic_toSharesDown(y, ta, ts);
        // additivity with respect to side effect
        axiom forall mathint x. forall mathint y.  forall mathint ta. forall mathint ts. 
                symbolic_toSharesDown(x, ta, ts) +  symbolic_toSharesDown(y, ta + x, ts + symbolic_toSharesDown(x, ta, ts))  <= symbolic_toSharesDown(x + y, ta, ts);
}

ghost symbolic_toAssetsDown(mathint /*shares*/, mathint /*totalAssets*/, mathint /*totalShares*/) returns uint256 {
        // monotonicity
        axiom forall mathint x. forall mathint y. forall mathint ta. forall mathint ts. 
                x > y => symbolic_toAssetsDown(x, ta, ts) >= symbolic_toAssetsDown(y, ta, ts);
        // additivity with respect to side effect
        axiom forall mathint x. forall mathint y.  forall mathint ta. forall mathint ts. 
                symbolic_toAssetsDown(x, ta, ts) +  symbolic_toAssetsDown(y, ta + symbolic_toAssetsDown(x, ta, ts), ts + x)  <= symbolic_toAssetsDown(x + y, ta, ts);
}

ghost symbolic_toSharesUp(mathint /*assets*/, mathint /*totalAssets*/, mathint /*totalShares*/) returns uint256 {
        // monotonicity
        axiom forall mathint x. forall mathint y. forall mathint ta. forall mathint ts. 
                x > y => symbolic_toSharesUp(x, ta, ts) >= symbolic_toSharesUp(y, ta, ts);
        // additivity with respect to side effect
        axiom forall mathint x. forall mathint y.  forall mathint ta. forall mathint ts. 
                symbolic_toSharesUp(x, ta, ts) +  symbolic_toSharesUp(y, ta - x, ts - symbolic_toSharesUp(x, ta, ts))  >= symbolic_toSharesUp(x + y, ta, ts);
        axiom forall mathint x. forall mathint ta. forall mathint ts. symbolic_toSharesUp(x, ta, ts) == 0 <=> x == 0;
}


ghost symbolic_toAssetsUp(mathint /*shares*/, mathint /*totalAssets*/, mathint /*totalShares*/) returns uint256 {
        // monotonicity
        axiom forall mathint x. forall mathint y. forall mathint ta. forall mathint ts. 
                x > y => symbolic_toAssetsUp(x, ta, ts) >= symbolic_toAssetsUp(y, ta, ts);
        // additivity with respect to side effect
        axiom forall mathint x. forall mathint y.  forall mathint ta. forall mathint ts. 
                symbolic_toAssetsUp(x, ta, ts) +  symbolic_toAssetsUp(y, ta + symbolic_toAssetsUp(x, ta, ts), ts + x)  >= symbolic_toAssetsUp(x + y, ta, ts);
}

/*** verify that the ghost variables and axioms preserve the rules *****/ 
use rule toSharesDown_additivity;
use rule toSharesDown_monotonicity;
use rule toAssetsDown_additivity;
use rule toAssetsDown_monotonicity;
use rule toSharesUp_additivity;
use rule toSharesUp_monotonicity;
use rule toSharesUp_nonZero;
use rule toAssetsUp_additivity;
use rule toAssetsUp_monotonicity;

/**
@title Prove that adding in two steps is less beneficial to the user than doing it in one step
**/
rule addAdditivity(uint256 assetId, uint256 amountX, uint256 amountY, address from) {
    env e;
    address spoke = e.msg.sender;
    requireAllInvariants(assetId,e);
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
@title Prove that removing in two steps is less beneficial to the user than doing it in one step
**/
rule removeAdditivity(uint256 assetId, uint256 amountX, uint256 amountY, address from) {
    env e;
    address spoke = e.msg.sender;
    requireAllInvariants(assetId,e);
    storage init = lastStorage;

    remove(e, assetId, amountX, from);
    remove(e, assetId, amountY, from);
    uint256 afterTwoSteps = getSpokeAddedShares(e, assetId, spoke);

    //expecting the code to enforce that amountX+amountY can not overflow
    remove(e, assetId, assert_uint256(amountX + amountY), from)at init;
    uint256 afterOneStep = getSpokeAddedShares(e, assetId, spoke);

    //rounding should be in favor of the house
    assert afterOneStep >= afterTwoSteps;
    satisfy afterOneStep > afterTwoSteps;
}


/**
@title Prove that drawing in two steps is less beneficial to the user than doing it in one step
**/
rule drawAdditivity(uint256 assetId, uint256 amountX, uint256 amountY, address from) {
    env e;
    address spoke = e.msg.sender;
    requireAllInvariants(assetId,e);
    storage init = lastStorage;

    draw(e, assetId, amountX, from);
    draw(e, assetId, amountY, from);
    uint256 afterTwoSteps = getSpokeTotalOwed(e, assetId, spoke);
    //expecting the code to enforce that amountX+amountY can not overflow
    draw(e, assetId, assert_uint256(amountX + amountY), from)at init;
    uint256 afterOneStep = getSpokeTotalOwed(e, assetId, spoke);

    //rounding should be in favor of the house
    assert afterOneStep <= afterTwoSteps;
    satisfy afterOneStep < afterTwoSteps;
}

/**
@title Prove that restoring in two steps is less beneficial to the user than doing it in one step
**/
rule restoreAdditivity(uint256 assetId, uint256 amountX, uint256 amountY, address from) {
    env e;
    address spoke = e.msg.sender;
    requireAllInvariants(assetId,e);
    storage init = lastStorage;

    IHubBase.PremiumDelta premiumDeltaX;
    IHubBase.PremiumDelta premiumDeltaY;       
    IHubBase.PremiumDelta premiumDeltaXY;
    require premiumDeltaXY.sharesDelta == premiumDeltaX.sharesDelta + premiumDeltaY.sharesDelta;
    require premiumDeltaXY.offsetRayDelta == premiumDeltaX.offsetRayDelta + premiumDeltaY.offsetRayDelta;
    require premiumDeltaXY.restoredPremiumRay == premiumDeltaX.restoredPremiumRay + premiumDeltaY.restoredPremiumRay;
    
    restore(e, assetId, amountX, premiumDeltaX);
    restore(e, assetId, amountY, premiumDeltaY);
    uint256 afterTwoSteps = getSpokeTotalOwed(e, assetId, spoke);
    //expecting the code to enforce that amountX+amountY can not overflow
    restore(e, assetId, assert_uint256(amountX + amountY), premiumDeltaXY) at init;
    uint256 afterOneStep = getSpokeTotalOwed(e, assetId, spoke);
    assert afterOneStep <= afterTwoSteps;
    satisfy afterOneStep < afterTwoSteps;
}

/**
@title Prove that reporting deficit in two steps is less beneficial to the user than doing it in one step
**/
rule reportDeficitAdditivity(uint256 assetId, uint256 amountX, uint256 amountY) {
    env e;
    address spoke = e.msg.sender;
    requireAllInvariants(assetId,e);
    storage init = lastStorage;
    IHubBase.PremiumDelta premiumDeltaX;
    IHubBase.PremiumDelta premiumDeltaY;       
    IHubBase.PremiumDelta premiumDeltaXY;

    require premiumDeltaXY.sharesDelta == premiumDeltaX.sharesDelta + premiumDeltaY.sharesDelta;
    require premiumDeltaXY.offsetRayDelta == premiumDeltaX.offsetRayDelta + premiumDeltaY.offsetRayDelta;
    require premiumDeltaXY.restoredPremiumRay == premiumDeltaX.restoredPremiumRay + premiumDeltaY.restoredPremiumRay;

    reportDeficit(e, assetId, amountX, premiumDeltaX);
    reportDeficit(e, assetId, amountY, premiumDeltaY);
    uint256 afterTwoSteps = getSpokeTotalOwed(e, assetId, spoke);
    //expecting the code to enforce that amountX+amountY can not overflow
    reportDeficit(e, assetId, assert_uint256(amountX + amountY), premiumDeltaXY) at init;
    uint256 afterOneStep = getSpokeTotalOwed(e, assetId, spoke);
    assert afterOneStep <= afterTwoSteps;
    satisfy afterOneStep < afterTwoSteps;
}

/**
@title Prove that eliminating deficit in two steps is less beneficial to the user than doing it in one step
**/
rule eliminateDeficitAdditivity(uint256 assetId, uint256 amountX, uint256 amountY, address spoke) {
    env e;
   
    requireAllInvariants(assetId,e);
    storage init = lastStorage;
    eliminateDeficit(e, assetId, amountX, spoke);
    eliminateDeficit(e, assetId, amountY, spoke);
    uint256 afterTwoSteps = getSpokeAddedShares(e, assetId, spoke);
    //expecting the code to enforce that amountX+amountY can not overflow
    eliminateDeficit(e, assetId, require_uint256(amountX + amountY), spoke)at init;
    uint256 afterOneStep = getSpokeAddedShares(e, assetId, spoke);
    assert afterOneStep >= afterTwoSteps;
    satisfy afterOneStep > afterTwoSteps;
}

/** @title Draw operation increases debt shares and transfers assets to recipient */
rule restore_debtDecrease(uint256 assetId, uint256 drawnAmount, IHubBase.PremiumDelta premiumDelta) {
    env e;
    requireAllInvariants(assetId,e);
    address spoke = e.msg.sender;
    uint256 beforeDebt = getSpokeTotalOwed(e, assetId, spoke);
    //expecting the code to enforce that amountX+amountY can not overflow
    restore(e, assetId, drawnAmount, premiumDelta);
    uint256 afterDebt = getSpokeTotalOwed(e, assetId, spoke);
    assert beforeDebt >= afterDebt;
}

// optimize the calls to certain function and save in ghost (global) variable) 
ghost uint256 supplyAmountBefore; 
ghost uint256 supplyShareBefore;

function requireAllInvariants(uint256 assetId, env e)  {
    // optimize the calls to 
    supplyAmountBefore = getAddedAssets(e,assetId);
    supplyShareBefore = getAddedShares(e,assetId); 
    //requireInvariant totalAssetsVsShares(assetId,e);
    require supplyAmountBefore >= supplyShareBefore;
}
