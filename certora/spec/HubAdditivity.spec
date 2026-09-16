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
* @link_property additivity of the operations
**/
rule removeAdditivity(uint256 assetId, uint256 amountX, uint256 amountY, address from) {
    env e;
    address spoke = e.msg.sender;
    setup_additivity(assetId,e);
    storage init = lastStorage;

    remove(e, assetId, amountX, from);
    remove(e, assetId, amountY, from);
    uint256 afterTwoSteps = getSpokeAddedShares(e, assetId, spoke);

    //expecting the code to enforce that amountX+amountY can not overflow
    remove(e, assetId, assert_uint256(amountX + amountY), from)at init;
    uint256 afterOneStep = getSpokeAddedShares(e, assetId, spoke);

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
