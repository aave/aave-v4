
/**
@title Prove unit test properties of AssetLogic.accrue() function
This is proven on HubHarness which expose accure() as an external function 

**/

import "./HubBase.spec";

using HubHarness as hub;
using MathWrapper as mathWrapper; 

methods {
    // envfree functions
    function mathWrapper.SECONDS_PER_YEAR() external returns (uint256) envfree;
}

/**
@title Two invocations of accure() at the same block result in a state exactly the same as the first execution 
**/
rule runningTwiceIsEquivalentToOne() { 
    env e;
    uint256 assetId;
    accrueInterest(e,assetId);
    storage afterOne = lastStorage;
    accrueInterest(e,assetId);
    assert lastStorage == afterOne;
}

/**
@title Once baseDebtIndex is set it is at least Ray  
Proved also in invariant baseDebtIndexMin on all Hub functions 
**/
rule baseDebtIndexMin_accrue(){
    env e;
    uint256 assetId;
    require hub._assets[assetId].drawnIndex == 0 || hub._assets[assetId].drawnIndex >= wadRayMath.RAY();

    accrueInterest(e,assetId);
    assert hub._assets[assetId].drawnIndex == 0 || hub._assets[assetId].drawnIndex >= wadRayMath.RAY();

}

/**
@title lastUpdateTimestamp is not in the future
**/
rule lastUpdateTimestamp_notInFuture(){
    env e;
    uint256 assetId;
    require hub._assets[assetId].lastUpdateTimestamp <= e.block.timestamp;
    accrueInterest(e,assetId);
    assert hub._assets[assetId].lastUpdateTimestamp == e.block.timestamp;
}


definition emptyAsset(uint256 assetId) returns bool =
    hub._assets[assetId].addedShares == 0 &&
        hub._assets[assetId].liquidity == 0 &&
        hub._assets[assetId].addedShares == 0 &&
        hub._assets[assetId].deficit == 0 &&
        hub._assets[assetId].swept == 0 &&
        hub._assets[assetId].premiumShares == 0 &&
        hub._assets[assetId].premiumOffset == 0 &&
        hub._assets[assetId].realizedPremium == 0 &&
        hub._assets[assetId].drawnShares == 0 &&
        hub._assets[assetId].drawnIndex == 0 &&
        hub._assets[assetId].drawnRate == 0 &&
        hub._assets[assetId].lastUpdateTimestamp == 0 &&
        ( forall address spoke. 
            hub._spokes[assetId][spoke].addedShares == 0 &&
            hub._spokes[assetId][spoke].drawnShares == 0 &&
            hub._spokes[assetId][spoke].premiumShares == 0  &&
            hub._spokes[assetId][spoke].premiumOffset == 0 &&
            hub._spokes[assetId][spoke].realizedPremium == 0 
        ) && 
        hub._assets[assetId].underlying == 0;


/**
@title BaseDebtIndex is increasing on block change when baseRate is at least SECONDS_PER_YEAR and index is set
Fails on cases in which baseBorrowRate <= SECONDS_PER_YEAR
**/
rule baseDebtIndex_increasing(uint256 assetId) {
    //Proved in invariant baseDebtIndexMin and baseDebtIndexMin_accrue
    require hub._assets[assetId].drawnIndex >= wadRayMath.RAY();

    uint256 before = hub._assets[assetId].drawnIndex;

    env e;
    require e.block.timestamp >  hub._assets[assetId].lastUpdateTimestamp && e.block.timestamp <= max_uint40;
    uint256 baseDebt = getAssetTotalOwed(e, assetId);

    accrueInterest(e,assetId);
    
    assert hub._assets[assetId].drawnIndex >= before;
    // if the debt is all realized premium, then the drawnIndex should not increase
    assert (hub._assets[assetId].drawnRate >= mathWrapper.SECONDS_PER_YEAR() 
            && baseDebt > hub._assets[assetId].realizedPremium) =>
             hub._assets[assetId].drawnIndex > before;
    satisfy hub._assets[assetId].drawnRate == mathWrapper.SECONDS_PER_YEAR();
}

/**
@title Prove premiumOffset is always less than or equal to premiumShares * drawnIndex / RAY rounded up.
This is important to avoid revert on accrue
**/
rule premiumOffset_Integrity_accrue(uint256 assetId, address spokeId) {

    env e;
    require hub._assets[assetId].lastUpdateTimestamp <= e.block.timestamp; 
    
    //requireInvariant baseDebtIndexMin(assetId); 
    require hub._assets[assetId].drawnIndex == 0 || hub._assets[assetId].drawnIndex >= wadRayMath.RAY();

    require previewRestoreByShares(e,assetId,hub._assets[assetId].premiumShares) >=  hub._assets[assetId].premiumOffset && 
    previewRestoreByShares(e,assetId,hub._spokes[assetId][spokeId].premiumShares) >=  hub._spokes[assetId][spokeId].premiumOffset; 
    
    accrueInterest(e, assetId);

    assert previewRestoreByShares(e,assetId,hub._assets[assetId].premiumShares) >=  hub._assets[assetId].premiumOffset && 
    previewRestoreByShares(e,assetId,hub._spokes[assetId][spokeId].premiumShares) >=  hub._spokes[assetId][spokeId].premiumOffset;
    
}

/**
@title  View functions are isomorphic to accrue, they return the same value if accrue was called or not
**/

rule viewFunctionsIntegrity(uint256 assetId, method f) filtered { f-> f.isView &&
                            
                                f.selector != sig:authority().selector &&
                                f.selector != sig:isConsumingScheduledOp().selector &&
                                f.selector != sig:isSpokeListed(uint256,address).selector &&
                                // returns a struct 
                                f.selector != sig:getAsset(uint256).selector &&
                                f.selector != sig:getAssetConfig(uint256).selector &&
                                f.selector != sig:getSpoke(uint256,address).selector &&
                                f.selector != sig:getSpokeConfig(uint256,address).selector &&
                                f.selector != sig:getSpokeAddress(uint256,uint256).selector &&
                                // harness functions
                                f.selector != sig:toSharesDown(uint256,uint256,uint256).selector &&
                                f.selector != sig:toAssetsDown(uint256,uint256,uint256).selector &&
                                f.selector != sig:toSharesUp(uint256,uint256,uint256).selector &&
                                f.selector != sig:toAssetsUp(uint256,uint256,uint256).selector &&
                                f.selector != sig:getAssetSuppliedAmountUp(uint256).selector &&
                                f.selector != sig:unrealizedFeeShares(uint256 ).selector &&
                                f.selector != sig:MAX_ALLOWED_UNDERLYING_DECIMALS().selector &&
                                f.selector != sig:MAX_ALLOWED_SPOKE_CAP().selector &&
                                f.selector != sig:getAssetUnderlyingAndDecimals(uint256).selector 
                                }
{
    env e;
    calldataarg args; 
    storage init = lastStorage;
    

    // lastUpdateTimestamp can not be in the future, prove... 
    require hub._assets[assetId].lastUpdateTimestamp <= e.block.timestamp; 
    
    //requireInvariant baseDebtIndexMin(assetId); 
    require hub._assets[assetId].drawnIndex == 0 || hub._assets[assetId].drawnIndex >= wadRayMath.RAY();


    accrueInterest(e, assetId);
    mathint ret_withAccrue = callViewFunction(f, e, args);

    // get back to init
    getAsset(e, assetId) at init;
    mathint ret_withoutAccrue = callViewFunction(f, e, args);
    
    assert ret_withAccrue == ret_withoutAccrue;
}

//* helper function for calling view functions and fetching the return value as mathint */
function callViewFunction(method f, env e, calldataarg args) returns mathint {
    if (f.selector == sig:getAssetCount().selector) {
        return getAssetCount(e, args);
    }
    else if (f.selector == sig:getSpokeCount(uint256).selector) {
        return getSpokeCount(e, args);
    }
    else if (f.selector == sig:getSpoke(uint256,address).selector) {
        // skip or handle as needed (returns struct)
    }
    else if (f.selector == sig:previewAddByAssets(uint256,uint256).selector) {
        return previewAddByAssets(e, args);
    }
    else if (f.selector == sig:previewAddByShares(uint256,uint256).selector) {
        return previewAddByShares(e, args);
    }
    else if (f.selector == sig:previewRemoveByAssets(uint256,uint256).selector) {
        return previewRemoveByAssets(e, args);
    }
    else if (f.selector == sig:previewRemoveByShares(uint256,uint256).selector) {
        return previewRemoveByShares(e, args);
    }
    else if (f.selector == sig:previewDrawByAssets(uint256,uint256).selector) {
        return previewDrawByAssets(e, args);
    }
    else if (f.selector == sig:previewDrawByShares(uint256,uint256).selector) {
        return previewDrawByShares(e, args);
    }
    else if (f.selector == sig:previewRestoreByAssets(uint256,uint256).selector) {
        return previewRestoreByAssets(e, args);
    }
    else if (f.selector == sig:previewRestoreByShares(uint256,uint256).selector) {
        return previewRestoreByShares(e, args);
    }
    else if (f.selector == sig:getAssetDrawnIndex(uint256).selector) {
        return getAssetDrawnIndex(e, args);
    }
    else if (f.selector == sig:getAssetOwed(uint256).selector) {
        uint256 a; uint256 b; (a, b) = getAssetOwed(e, args); return a + b;
    }
    else if (f.selector == sig:getAssetTotalOwed(uint256).selector) {
        return getAssetTotalOwed(e, args);
    }
    else if (f.selector == sig:getSpokeOwed(uint256,address).selector) {
        uint256 a; uint256 b; (a, b) = getSpokeOwed(e, args); return a + b;
    }
    else if (f.selector == sig:getSpokeTotalOwed(uint256,address).selector) {
        return getSpokeTotalOwed(e, args);
    }
    
    else if (f.selector == sig:getAssetDrawnRate(uint256).selector) {
        return getAssetDrawnRate(e, args);
    }
    else if (f.selector == sig:getAddedAssets(uint256).selector) {
        return getAddedAssets(e, args);
    }
    else if (f.selector == sig:getAddedShares(uint256).selector) {
        return getAddedShares(e, args);
    }
    else if (f.selector == sig:getSpokeAddedAssets(uint256,address).selector) {
        return getSpokeAddedAssets(e, args);
    }
    else if (f.selector == sig:getSpokeAddedShares(uint256,address).selector) {
        return getSpokeAddedShares(e, args);
    }
    else if (f.selector == sig:getAssetDrawnShares(uint256).selector) {
        return getAssetDrawnShares(e, args);
    }
    else if (f.selector == sig:getAssetPremiumData(uint256).selector) {
        uint256 a; uint256 b; uint256 c; 
        (a, b, c) = getAssetPremiumData(e, args); 
        return a + b + c;
    }
    else if (f.selector == sig:getSpokePremiumData(uint256,address).selector) {
        uint256 a; uint256 b; uint256 c; 
        (a, b, c) = getSpokePremiumData(e, args); 
        return a + b + c;
    }
    else if (f.selector == sig:getSpokeDrawnShares(uint256,address).selector) {
        return getSpokeDrawnShares(e, args);
    }
    else if (f.selector == sig:MIN_ALLOWED_UNDERLYING_DECIMALS().selector) {
        return MIN_ALLOWED_UNDERLYING_DECIMALS(e, args);
    }
    else if (f.selector == sig:MAX_ALLOWED_RISK_PREMIUM_CAP().selector) {
        return MAX_ALLOWED_RISK_PREMIUM_CAP(e, args);
    }
    else if (f.selector == sig:getAssetDeficit(uint256).selector) {
        return getAssetDeficit(e, args);
    }
    else if (f.selector == sig:getAssetLiquidity(uint256).selector) {
        return getAssetLiquidity(e, args);
    }
    else if (f.selector == sig:getAssetSwept(uint256).selector) {
        return getAssetSwept(e, args);
    }
    else if (f.selector == sig:getSpokeDeficit(uint256,address).selector) {
        return getSpokeDeficit(e, args);
    }
    else
    {
        assert false, "unknown view function";
        return 0;
    }
    return 0;
    

}
