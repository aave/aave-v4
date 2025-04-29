
import "./Math_CVL.spec";

using LiquidityHubHarness as liquidityHub;

using WadRayMathWrapper as wadRayMath;


methods {
 
    function WadRayMathWrapper.RAY() external returns (uint256) envfree;

    function Math.mulDiv(uint256 x, uint256 y, uint256 denominator) internal  returns (uint256) => 
        mulDivDownCVL(x,y,denominator);

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
}

rule runningTwiceIsEquivalentToOne() { 
    env e;
    uint256 assetId;
    accrueInterest(e,assetId);
    storage afterOne = lastStorage;
    accrueInterest(e,assetId);
    assert lastStorage == afterOne;
}


rule baseDebtIndexMin_accrue(){
    env e;
    uint256 assetId;
    require liquidityHub._assets[assetId].baseDebtIndex==0 || liquidityHub._assets[assetId].baseDebtIndex >= wadRayMath.RAY();

    accrueInterest(e,assetId);
    assert liquidityHub._assets[assetId].baseDebtIndex==0 || liquidityHub._assets[assetId].baseDebtIndex >= wadRayMath.RAY();

}
rule baseDebtIndex_increasing(uint256 assetId) {
    require liquidityHub._assets[assetId].baseDebtIndex >= wadRayMath.RAY() &&
            liquidityHub._assets[assetId].baseBorrowRate > 0;
    uint256 before = liquidityHub._assets[assetId].baseDebtIndex;

    env e;
    require e.block.timestamp >  liquidityHub._assets[assetId].lastUpdateTimestamp;
    accrueInterest(e,assetId);
    assert liquidityHub._assets[assetId].baseDebtIndex > before;
}

rule supplyExchangeRateIsMonotonic_accrue(){
    uint256 assetId;

    env e1; env e2; env e3;
    require e1.block.timestamp <= e2.block.timestamp && e2.block.timestamp <= e3.block.timestamp;


    // lastUpdateTimestamp can not be in the future, prove... 
    require liquidityHub._assets[assetId].lastUpdateTimestamp <=e1.block.timestamp; 
    
    //requireInvariant baseDebtIndexMin(assetId); 
    require liquidityHub._assets[assetId].baseDebtIndex==0 || liquidityHub._assets[assetId].baseDebtIndex >= wadRayMath.RAY();

    mathint assetsBefore = getAssetSuppliedAmount(e1, assetId);
    mathint sharesBefore = getAssetSuppliedShares(e1, assetId); 
    //requireInvariant totalAssetsVsShares(assetId,e);
    require assetsBefore >= sharesBefore;

    accrueInterest(e2,assetId);

    mathint assetsAfter = getAssetSuppliedAmount(e3, assetId);
    mathint sharesAfter = getAssetSuppliedShares(e3, assetId);

    // > when only considering accrue interest
    assert assetsAfter * sharesBefore >= assetsBefore * sharesAfter; 
    }


rule twoStepVsOneStep(uint256 assetId) { 
    env e;
    env eNext;
    require eNext.block.timestamp > e.block.timestamp;
    
    //requireInvariant baseDebtIndexMin(assetId); 
    require liquidityHub._assets[assetId].baseDebtIndex==0 || liquidityHub._assets[assetId].baseDebtIndex >= wadRayMath.RAY();

    // lastUpdateTimestamp can not be in the future, prove... 
    require liquidityHub._assets[assetId].lastUpdateTimestamp <= e.block.timestamp; 

    storage init = lastStorage;
    accrueInterest(e,assetId);
    accrueInterest(eNext,assetId);
    uint256 timestamp_afterTwoSteps = liquidityHub._assets[assetId].lastUpdateTimestamp;
    uint256 baseDebtIndex_afterTwoSteps = liquidityHub._assets[assetId].baseDebtIndex;
    storage afterTwoSteps = lastStorage;
    
    accrueInterest(eNext,assetId) at init;
    
    assert baseDebtIndex_afterTwoSteps <= liquidityHub._assets[assetId].baseDebtIndex;
    // only baseDebtIndex and lastUpdateTimestamp can change
    assert 
        baseDebtIndex_afterTwoSteps != liquidityHub._assets[assetId].baseDebtIndex ||
        timestamp_afterTwoSteps != liquidityHub._assets[assetId].lastUpdateTimestamp || 
        lastStorage == afterTwoSteps;
}



/* for view function - calling accrue does not impact value */ 

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
    else if (f.selector == sig:assetCount().selector) {
        return assetCount(e,args);
    }
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
    else if (f.selector == sig:getSpokeTotalDebt(uint256,address).selector) {
        return getSpokeTotalDebt(e,args);
    }
    else {
        assert false, "unknown view function";
        return 0;
    }
    

}
rule viewFunctionsIntegrity(uint256 assetId, method f) filtered { f-> f.isView &&
                                f.selector != sig:getAsset(uint256).selector &&
                                f.selector != sig:getAssetConfig(uint256).selector &&
                                f.selector != sig:MAX_ALLOWED_ASSET_DECIMALS().selector &&
                                f.selector != sig:assetsList(uint256).selector &&
                                f.selector != sig:getSpoke(uint256,address).selector &&
                                f.selector != sig:getSpokeConfig(uint256,address).selector
} {
    env e;
    calldataarg args; 
    storage init = lastStorage;
    

    // lastUpdateTimestamp can not be in the future, prove... 
    require liquidityHub._assets[assetId].lastUpdateTimestamp <= e.block.timestamp; 
    
    //requireInvariant baseDebtIndexMin(assetId); 
    require liquidityHub._assets[assetId].baseDebtIndex==0 || liquidityHub._assets[assetId].baseDebtIndex >= wadRayMath.RAY();


    accrueInterest(e, assetId);
    mathint ret_withAccrue = callViewFunction(f, e, args);

    // get back to init
    getAsset(e, assetId) at init;
    mathint ret_withoutAccrue = callViewFunction(f, e, args);
    
    assert ret_withAccrue == ret_withoutAccrue;
}

/* calling accure before sload to relevant slots  */