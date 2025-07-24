
/**
@title Prove unit test properties of AssetLogic.accrue() function
This is proven on LiquidityHubHarness which expose accure() as an external function 

To run this spec file:
 certoraRun certora/conf/LiquidityHubAccrueIntegrity.conf 
**/

import "./Math_CVL.spec";

using LiquidityHubHarness as liquidityHub;
using MathWrapper as mathWrapper; 
using WadRayMathWrapper as wadRayMath;


methods {
    // envfree functions
    function WadRayMathWrapper.RAY() external returns (uint256) envfree;
    function mathWrapper.SECONDS_PER_YEAR() external returns (uint256) envfree;


    // standard summarization of mulDiv 
    function Math.mulDiv(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) internal  returns (uint256) => 
        mulDivCVL(x,y,denominator,rounding);

    // summarization proved in Math.spec 
    function WadRayMath.rayMul(uint256 a, uint256 b) internal returns (uint256) => 
        mulDivHalf(a,b,wadRayMath.RAY());
    
    function WadRayMath.rayDiv(uint256 a, uint256 b) internal returns (uint256) => 
        mulDivHalf(a,wadRayMath.RAY(),b);

    function WadRayMathExtended.rayMulDown(uint256 a, uint256 b) internal returns (uint256) => 
        mulDivDownCVL(a,b,wadRayMath.RAY());
    
    function WadRayMathExtended.rayMulUp(uint256 a, uint256 b) internal returns (uint256) => 
        mulDivUpCVL(a,b,wadRayMath.RAY());
    
    function WadRayMathExtended.rayDivDown(uint256 a, uint256 b) internal returns (uint256) => 
        mulDivDownCVL(a,wadRayMath.RAY(),b);
    
    function WadRayMathExtended.rayDivUp(uint256 a, uint256 b) internal returns (uint256) => 
        mulDivUpCVL(a,wadRayMath.RAY(),b);

    function AssetLogic.previewFeeShares(
    DataTypes.Asset storage asset,
    uint256 indexDelta
  ) internal returns (uint256) =>  ALWAYS(0);
    /*
    function AssetLogic.previewFeeShares(
    DataTypes.Asset storage asset,
    uint256 indexDelta
  ) internal returns (uint256) => SummaryLibrary.previewFeeShares(asset, indexDelta);

  function SummaryLibrary.calcFees(uint256 indexDelta, uint256 totalDrawnShares, uint256 liquidityFee) internal  returns (uint256) => calcFeesApproximation(indexDelta, totalDrawnShares, liquidityFee);  */
}

ghost calcFeesApproximation(uint256, uint256, uint256) returns uint256;
/* 
 select which cvl math function to use
*/
function mulDivCVL(uint256 x, uint256 y, uint256 z, Math.Rounding rounding) returns uint256 {
    mathint mul  = x * y;
    if (z == 0 ) {
        revert();
    }
    if (rounding == Math.Rounding.Floor) 
        return mulDivDownCVL(x, y, z);
    else if (rounding == Math.Rounding.Ceil) 
        return mulDivUpCVL(x, y, z);
    else
        assert false; 
    return 0; 
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
    require liquidityHub._assets[assetId].baseDebtIndex == 0 || liquidityHub._assets[assetId].baseDebtIndex >= wadRayMath.RAY();

    accrueInterest(e,assetId);
    assert liquidityHub._assets[assetId].baseDebtIndex == 0 || liquidityHub._assets[assetId].baseDebtIndex >= wadRayMath.RAY();

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
    require liquidityHub._assets[assetId].baseDebtIndex >= wadRayMath.RAY();

    uint256 before = liquidityHub._assets[assetId].baseDebtIndex;

    env e;
    require e.block.timestamp >  liquidityHub._assets[assetId].lastUpdateTimestamp;
    uint256 baseDebt;
    uint256 premiumDebt;
    (baseDebt,premiumDebt) = getAssetDebt(e, assetId);

    accrueInterest(e,assetId);
    
    assert liquidityHub._assets[assetId].baseDebtIndex >= before;
    assert (liquidityHub._assets[assetId].baseBorrowRate >= mathWrapper.SECONDS_PER_YEAR() 
            && baseDebt > 0 ) =>
             liquidityHub._assets[assetId].baseDebtIndex > before;
    satisfy liquidityHub._assets[assetId].baseBorrowRate == mathWrapper.SECONDS_PER_YEAR();
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
    require liquidityHub._assets[assetId].baseDebtIndex >= wadRayMath.RAY();

    mathint assetsBefore = getAssetSuppliedAmount(e1, assetId);
    mathint sharesBefore = getAssetSuppliedShares(e1, assetId); 
    //requireInvariant totalAssetsVsShares(assetId,e);
    require assetsBefore >= sharesBefore;

    uint256 baseDebt;
    uint256 premiumDebt;
    (baseDebt,premiumDebt) = getAssetDebt(e1, assetId);
    accrueInterest(e2,assetId);

    mathint assetsAfter = getAssetSuppliedAmount(e3, assetId);
    mathint sharesAfter = getAssetSuppliedShares(e3, assetId);

    assert assetsAfter * sharesBefore >= assetsBefore * sharesAfter; 
    // > when only considering accrue interest
    assert  ( liquidityHub._assets[assetId].baseBorrowRate >= mathWrapper.SECONDS_PER_YEAR() &&
                sharesBefore > 0 &&
                baseDebt > wadRayMath.RAY()
            )
                => assetsAfter * sharesBefore > assetsBefore * sharesAfter; 
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
    require liquidityHub._assets[assetId].baseDebtIndex >= wadRayMath.RAY();
    
    // lastUpdateTimestamp can not be in the future, rule lastUpdateTimestamp_notInFuture 
    require liquidityHub._assets[assetId].lastUpdateTimestamp <= e.block.timestamp; 

    require liquidityHub._assets[assetId].baseBorrowRate >= mathWrapper.SECONDS_PER_YEAR();

    storage init = lastStorage;
    mathint assetsBefore = getAssetSuppliedAmount(e, assetId);

    accrueInterest(e,assetId);
    accrueInterest(eNext,assetId);
    uint256 timestamp_afterTwoSteps = liquidityHub._assets[assetId].lastUpdateTimestamp;
    uint256 baseDebtIndex_afterTwoSteps = liquidityHub._assets[assetId].baseDebtIndex;
    
    storage afterTwoSteps = lastStorage;
    
    accrueInterest(eNext,assetId) at init;

    satisfy baseDebtIndex_afterTwoSteps > liquidityHub._assets[assetId].baseDebtIndex;
    assert assetsBefore >= wadRayMath.RAY() => baseDebtIndex_afterTwoSteps >= liquidityHub._assets[assetId].baseDebtIndex;

    assert timestamp_afterTwoSteps == liquidityHub._assets[assetId].lastUpdateTimestamp;
    
    /* only baseDebtIndex  can change
     the assert version is not strong, it only checks that some other storage is not changes while baseDebtIndex
      does not change
      https://certora.atlassian.net/browse/CERT-8924  is blocking a stronger rule */    
    assert 
        baseDebtIndex_afterTwoSteps != liquidityHub._assets[assetId].baseDebtIndex ||
        lastStorage == afterTwoSteps;
    
}



/**
@title  View functions are isomorphic to accrue, they return the same value if accrue was called or not
**/

rule viewFunctionsIntegrity(uint256 assetId, method f) filtered { f-> f.isView &&
                                f.selector != sig:getAsset(uint256).selector &&
                                f.selector != sig:getAssetConfig(uint256).selector &&
                                f.selector != sig:MAX_ALLOWED_ASSET_DECIMALS().selector &&
                            //    f.selector != sig:assetsList(uint256).selector &&
                                f.selector != sig:getSpoke(uint256,address).selector &&
                                f.selector != sig:getSpokeConfig(uint256,address).selector &&
                                f.selector != sig:toSharesDown(uint256,uint256,uint256).selector &&
                                f.selector != sig:toAssetsDown(uint256,uint256,uint256).selector &&
                                f.selector != sig:toSharesUp(uint256,uint256,uint256).selector &&
                                f.selector != sig:toAssetsUp(uint256,uint256,uint256).selector &&
                                f.selector != sig:getAssetSuppliedAmountUp(uint256).selector }
{
    env e;
    calldataarg args; 
    storage init = lastStorage;
    

    // lastUpdateTimestamp can not be in the future, prove... 
    require liquidityHub._assets[assetId].lastUpdateTimestamp <= e.block.timestamp; 
    
    //requireInvariant baseDebtIndexMin(assetId); 
    require liquidityHub._assets[assetId].baseDebtIndex == 0 || liquidityHub._assets[assetId].baseDebtIndex >= wadRayMath.RAY();


    accrueInterest(e, assetId);
    mathint ret_withAccrue = callViewFunction(f, e, args);

    // get back to init
    getAsset(e, assetId) at init;
    mathint ret_withoutAccrue = callViewFunction(f, e, args);
    
    assert ret_withAccrue == ret_withoutAccrue;
}

//* helper function for calling view functions and fetching the return value as mathint */
function callViewFunction(method f, env e, calldataarg args) returns mathint {
    if (f.selector == sig:convertToDrawnAssets(uint256, uint256).selector) {
        return convertToDrawnAssets(e,args);
    } 
    else if (f.selector == sig:convertToDrawnShares(uint256, uint256).selector) {
        return convertToDrawnShares(e,args);
    } 
    else if (f.selector == sig:convertToSuppliedAssets(uint256, uint256).selector) {
        return convertToSuppliedAssets(e,args);
    } 
    else if (f.selector == sig:convertToSuppliedShares(uint256, uint256).selector) {
        return convertToSuppliedShares(e,args);
    } 
    else if (f.selector == sig:previewOffset(uint256, uint256).selector) {
        return previewOffset(e,args);
    } 
    else if (f.selector == sig:getAssetDebt(uint256).selector) {
        uint256 a;
        uint256 b;
        (a,b) = getAssetDebt(e,args);
        return a+b;
    } 
    else if (f.selector == sig:getAssetSuppliedAmount(uint256).selector) {
        return getAssetSuppliedAmount(e,args);
    }
    else if (f.selector == sig:getAssetSuppliedShares(uint256).selector) {
        return getAssetSuppliedShares(e,args);
    }
    else if (f.selector == sig:getAssetTotalDebt(uint256).selector) {
        return getAssetTotalDebt(e,args);
    }
    else if (f.selector == sig:getAssetTotalDebt(uint256).selector) {
        return getAssetTotalDebt(e,args);
    }
    else if (f.selector == sig:getAvailableLiquidity(uint256).selector) {
        return getAvailableLiquidity(e,args);
    }
    else if (f.selector == sig:getBaseInterestRate(uint256).selector) {
        return getBaseInterestRate(e,args);
    }
/*    else if (f.selector == sig:assetCount().selector) {
        return assetCount(e,args);
    } */
    else if (f.selector == sig:getBaseInterestRate(uint256).selector) {
        return getBaseInterestRate(e,args);
    }
    else if (f.selector == sig:getSpokeSuppliedShares(uint256,address).selector) {
        return getSpokeSuppliedShares(e,args);
    }
    else if (f.selector == sig:getSpokeSuppliedAmount(uint256,address).selector) {
        return getSpokeSuppliedAmount(e,args);
    }
    else if (f.selector == sig:getSpokeDebt(uint256,address).selector) {
        uint256 a;
        uint256 b;
        (a,b) = getSpokeDebt(e,args);
        return a + b;
    }
    else if (f.selector == sig:getTotalSuppliedAssets(uint256).selector) {
        return getTotalSuppliedAssets(e,args);
    }
    else if (f.selector == sig:getSpokeTotalDebt(uint256,address).selector) {
        return getSpokeTotalDebt(e,args);
    }
    else if (f.selector == sig:getTotalSuppliedShares(uint256).selector) {
        return getTotalSuppliedShares(e,args);
    }
    else if (f.selector == sig:previewDrawnIndex(uint256).selector) {
        return previewDrawnIndex(e,args);
    }
    else if (f.selector == sig:convertToSuppliedSharesUp(uint256,uint256).selector) {
        return convertToSuppliedSharesUp(e,args);
    }
    else if (f.selector == sig:convertToSuppliedAssetsUp(uint256,uint256).selector) {
        return convertToSuppliedAssetsUp(e,args);
    }
    else  {
        assert false, "unknown view function";
        return 0;
    }
    

}
