
/**
@title Prove unit test properties of AssetLogic.accrue() function
This is proven on LiquidityHubHarness which expose accure() as an external function 

To run this spec file:
 certoraRun certora/conf/LiquidityHubAccrueIntegrity.conf 
**/

import "./HubBase.spec";

using HubHarness as liquidityHub;
using MathWrapper as mathWrapper; 

methods {
    // envfree functions
    function mathWrapper.SECONDS_PER_YEAR() external returns (uint256) envfree;
//    function MathUtils.calculateLinearInterest(uint256 rate, uint40 lastUpdateTimestamp) internal returns (uint256) with (env e) => simpleCalculateInterest(e, lastUpdateTimestamp)  ;

}

function simpleCalculateInterest(env e, uint40 lastUpdateTimestamp) returns uint256 {
    require  e.block.timestamp >= lastUpdateTimestamp;
    return require_uint256(e.block.timestamp - lastUpdateTimestamp);
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
Proved also in invariant baseDebtIndexMin on all liquidityHub functions 
**/
rule baseDebtIndexMin_accrue(){
    env e;
    uint256 assetId;
    require liquidityHub._assets[assetId].drawnIndex == 0 || liquidityHub._assets[assetId].drawnIndex >= wadRayMath.RAY();

    accrueInterest(e,assetId);
    assert liquidityHub._assets[assetId].drawnIndex == 0 || liquidityHub._assets[assetId].drawnIndex >= wadRayMath.RAY();

}

rule lastUpdateTimestamp_notInFuture(){
    env e;
    uint256 assetId;
    require liquidityHub._assets[assetId].lastUpdateTimestamp <= e.block.timestamp;
    accrueInterest(e,assetId);
    assert liquidityHub._assets[assetId].lastUpdateTimestamp == e.block.timestamp;
}

/**
@title BaseDebtIndex is increasing on block change when baseRate is at least SECONDS_PER_YEAR and index is set
Fails on cases in which baseBorrowRate <= SECONDS_PER_YEAR
https://prover.certora.com/output/40726/749ae025befe4975a1331b981dd356d0/?anonymousKey=a5ba0b28f24ab3208ed71f9973f7c30af24765f6 
**/
rule baseDebtIndex_increasing(uint256 assetId) {
    //Proved in invariant baseDebtIndexMin and baseDebtIndexMin_accrue
    require liquidityHub._assets[assetId].drawnIndex >= wadRayMath.RAY();

    uint256 before = liquidityHub._assets[assetId].drawnIndex;

    env e;
    require e.block.timestamp >  liquidityHub._assets[assetId].lastUpdateTimestamp && e.block.timestamp <= max_uint40;
    uint256 baseDebt = getAssetTotalOwed(e, assetId);

    accrueInterest(e,assetId);
    
    assert liquidityHub._assets[assetId].drawnIndex >= before;
    assert (liquidityHub._assets[assetId].drawnRate >= mathWrapper.SECONDS_PER_YEAR() 
            && baseDebt > 0 ) =>
             liquidityHub._assets[assetId].drawnIndex > before;
    satisfy liquidityHub._assets[assetId].drawnRate == mathWrapper.SECONDS_PER_YEAR();
}

/**
@title supplyExchangeRate is increasing on accrue. 
@Note It is increasing only if the base is at least the min value in which the index is always update , see rule baseDebtIndex_increasing.
In addition baseDebt should be at least Ray (maybe less)
**/ 
rule supplyExchangeRateIsMonotonic_accrue(){
    uint256 assetId;

    env e1; env e2; env e3;
    require e1.block.timestamp < e2.block.timestamp && e2.block.timestamp < e3.block.timestamp;


    // lastUpdateTimestamp can not be in the future, prove... 
    require liquidityHub._assets[assetId].lastUpdateTimestamp < e1.block.timestamp; 
    
    //requireInvariant baseDebtIndexMin(assetId); 
    require liquidityHub._assets[assetId].drawnIndex >= wadRayMath.RAY();

    mathint assetsBefore = getTotalAddedAssets(e1, assetId);
    mathint sharesBefore = getTotalAddedShares(e1, assetId); 
    //requireInvariant totalAssetsVsShares(assetId,e);
    require assetsBefore >= sharesBefore;
    // todo - check this is always true 
    require liquidityHub._assets[assetId].liquidityFee <= 10000;
    uint256 baseDebt = getAssetTotalOwed(e1, assetId);
    accrueInterest(e2,assetId);

    mathint assetsAfter = getTotalAddedAssets(e2, assetId);
    mathint sharesAfter = getTotalAddedShares(e2, assetId);

//    assert assetsAfter * sharesBefore >= assetsBefore * sharesAfter; 
    // > when only considering accrue interest
    assert  ( liquidityHub._assets[assetId].drawnRate >= mathWrapper.SECONDS_PER_YEAR() &&
                sharesBefore > 0 &&
                baseDebt > wadRayMath.RAY()
            )
                => assetsAfter * sharesBefore >= assetsBefore * sharesAfter; 
    satisfy ( liquidityHub._assets[assetId].drawnRate >= mathWrapper.SECONDS_PER_YEAR() &&
                sharesBefore > 0 &&
                baseDebt > wadRayMath.RAY()
            ) && assetsAfter * sharesBefore > assetsBefore * sharesAfter; 
    satisfy ( liquidityHub._assets[assetId].drawnRate >= mathWrapper.SECONDS_PER_YEAR() &&
                sharesBefore > 0 &&
                baseDebt > wadRayMath.RAY()
            ) && assetsAfter * sharesBefore == assetsBefore * sharesAfter; 
}


rule supplyExchangeRateIsMonotonic_accrue_v2(){
    uint256 assetId;

    env e1; env e2;
    require e1.block.timestamp < e2.block.timestamp ;


    // lastUpdateTimestamp can not be in the future, prove... 
    require liquidityHub._assets[assetId].lastUpdateTimestamp!=0 && liquidityHub._assets[assetId].lastUpdateTimestamp == e1.block.timestamp; 
    
    //requireInvariant baseDebtIndexMin(assetId); 
    require liquidityHub._assets[assetId].drawnIndex >= wadRayMath.RAY(); 
    require liquidityHub._assets[assetId].drawnShares + liquidityHub._assets[assetId].premiumShares <= liquidityHub._assets[assetId].addedShares;

    mathint assetsBefore = getTotalAddedAssets(e1, assetId);
    mathint sharesBefore = getTotalAddedShares(e1, assetId); 
    //requireInvariant totalAssetsVsShares(assetId,e);
    require assetsBefore >= sharesBefore;
    // todo - check this is always true 
    require liquidityHub._assets[assetId].liquidityFee == 10000;
    mathint feeBefore = unrealizedFeeShares(e1, assetId);


    mathint assetsAfter = getTotalAddedAssets(e2, assetId);
    mathint feeAfter = unrealizedFeeShares(e2, assetId);
    require (   liquidityHub._assets[assetId].drawnRate >= mathWrapper.SECONDS_PER_YEAR() &&
                //liquidityHub._assets[assetId].drawnShares > wadRayMath.RAY() &&
                liquidityHub._assets[assetId].addedShares > 0
            );

//.  assets/shares / after should be bigger fee is the shares change 

    assert assetsAfter *(sharesBefore + feeBefore ) >= assetsBefore * ( sharesBefore + feeAfter) ;

}
/**
@title Comparing Accruing in two steps (t -> t1, t1 -> t2) to one step ( t -> t2):
Index can be higher on two steps, but not always. (TODO - check that this is ok)
Same final lastTimestamp 
**/
rule twoStepVsOneStep(uint256 assetId) { 
    env e;
    env eNext;
    require eNext.block.timestamp > e.block.timestamp;
    
    //requireInvariant baseDebtIndexMin(assetId); 
    require liquidityHub._assets[assetId].drawnIndex >= wadRayMath.RAY();
    
    // lastUpdateTimestamp can not be in the future, rule lastUpdateTimestamp_notInFuture 
    require liquidityHub._assets[assetId].lastUpdateTimestamp <= e.block.timestamp; 

    require liquidityHub._assets[assetId].drawnRate >= mathWrapper.SECONDS_PER_YEAR();

    storage init = lastStorage;
    mathint assetsBefore = getTotalAddedAssets(e, assetId);

    accrueInterest(e,assetId);
    accrueInterest(eNext,assetId);
    uint256 timestamp_afterTwoSteps = liquidityHub._assets[assetId].lastUpdateTimestamp;
    uint256 baseDebtIndex_afterTwoSteps = liquidityHub._assets[assetId].drawnIndex;
    
    storage afterTwoSteps = lastStorage;
    
    
    accrueInterest(eNext,assetId) at init;

    satisfy baseDebtIndex_afterTwoSteps > liquidityHub._assets[assetId].drawnIndex;
    assert assetsBefore >= wadRayMath.RAY() => baseDebtIndex_afterTwoSteps >= liquidityHub._assets[assetId].drawnIndex;

    assert timestamp_afterTwoSteps == liquidityHub._assets[assetId].lastUpdateTimestamp;
    
    /* only baseDebtIndex  can change
     the assert version is not strong, it only checks that some other storage is not changes while baseDebtIndex
      does not change
      https://certora.atlassian.net/browse/CERT-8924  is blocking a stronger rule */    
    assert 
        baseDebtIndex_afterTwoSteps != liquidityHub._assets[assetId].drawnIndex ||
        lastStorage == afterTwoSteps ;
    
}

rule getTotalAddedAssetsVsGetAssetSuppliedAmount(uint256 assetId) {
    env e;
    env eNext;
    require eNext.block.timestamp > e.block.timestamp;
    
    //requireInvariant baseDebtIndexMin(assetId); 
    require liquidityHub._assets[assetId].drawnIndex >= wadRayMath.RAY();
     
    require liquidityHub._assets[assetId].lastUpdateTimestamp == e.block.timestamp; 

    require getTotalAddedAssets(e,assetId) == getTotalAddedAssets(e,assetId);
    accrueInterest(eNext,assetId);
    assert getTotalAddedAssets(eNext,assetId) == getTotalAddedAssets(eNext,assetId); 
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
                                f.selector != sig:getFeeShares(uint256,uint256,uint256).selector &&
                                f.selector != sig:unrealizedFeeShares(uint256 ).selector 
                                }
{
    env e;
    calldataarg args; 
    storage init = lastStorage;
    

    // lastUpdateTimestamp can not be in the future, prove... 
    require liquidityHub._assets[assetId].lastUpdateTimestamp <= e.block.timestamp; 
    
    //requireInvariant baseDebtIndexMin(assetId); 
    require liquidityHub._assets[assetId].drawnIndex == 0 || liquidityHub._assets[assetId].drawnIndex >= wadRayMath.RAY();


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
    else if (f.selector == sig:convertToAddedAssets(uint256,uint256).selector) {
        return convertToAddedAssets(e, args);
    }
    else if (f.selector == sig:convertToAddedShares(uint256,uint256).selector) {
        return convertToAddedShares(e, args);
    }
    else if (f.selector == sig:convertToDrawnAssets(uint256,uint256).selector) {
        return convertToDrawnAssets(e, args);
    }
    else if (f.selector == sig:convertToDrawnShares(uint256,uint256).selector) {
        return convertToDrawnShares(e, args);
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
    else if (f.selector == sig:getAssetAddedAmount(uint256).selector) {
        return getAssetAddedAmount(e, args);
    }
    else if (f.selector == sig:getAssetDrawnRate(uint256).selector) {
        return getAssetDrawnRate(e, args);
    }
    else if (f.selector == sig:getAssetAddedShares(uint256).selector) {
        return getAssetAddedShares(e, args);
    }
    else if (f.selector == sig:getTotalAddedAssets(uint256).selector) {
        return getTotalAddedAssets(e, args);
    }
    else if (f.selector == sig:getTotalAddedShares(uint256).selector) {
        return getTotalAddedShares(e, args);
    }
    else if (f.selector == sig:getSpokeAddedAmount(uint256,address).selector) {
        return getSpokeAddedAmount(e, args);
    }
    else if (f.selector == sig:getSpokeAddedShares(uint256,address).selector) {
        return getSpokeAddedShares(e, args);
    }
    else if (f.selector == sig:getLiquidity(uint256).selector) {
        return getLiquidity(e, args);
    }
    else if (f.selector == sig:getDeficit(uint256).selector) {
        return getDeficit(e, args);
    }
    else
    {
        assert false, "unknown view function";
        return 0;
    }
    return 0;
    

}
