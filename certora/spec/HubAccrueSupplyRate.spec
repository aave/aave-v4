
/**
@title Prove that accrue can not decrease the share rate

assets / shares is increasing

This is proven by showing that:
(assets after accrue) / (shares before accrue + fee share) is increasing compared to (assets before accrue) / (shares before accrue)

Next we prove thet accrue mints shares as result of fee shares 
**/

import "./HubBase.spec";

using HubHarness as hub;
using MathWrapper as mathWrapper; 

methods {
    
    function AssetLogic.getDrawnIndex(IHub.Asset storage asset) internal returns (uint256)  with (env e) => symbolicDrawnIndex(e.block.timestamp);

    // proved in HubAccrueIntegrityUnrealizedFee.spec that this is the max value of unrealizedFeeShares
    function PercentageMath.percentMulDown(uint256 value, uint256 percentage) internal  returns (uint256) => 
    identity(value);

}
// fee is always 100%
function identity(uint256 x) returns uint256 {
    return x;
}

// symbolic representation of drawnIndex that is a function of the block timestamp.
ghost symbolicDrawnIndex(uint256) returns uint256;

/*
@title Prove that accrue can not decrease the share rate

Given e1, a timestamp last accrue, we prove that the share rate is the same or increasing at e2
We prove this for the maximum value of unrealizedFeeShares, as proved in HubAccrueIntegrityUnrealizedFee.spec
Therefore, it holds for any smaller value of unrealizedFeeShares, as shares_e2 will be smaller
**/


rule unrealizedFeeSharesSupplyRate(uint256 assetId){
    env e1; env e2; 
    uint256 oneM = 1000000;
    require e1.block.timestamp < e2.block.timestamp;


    // e1 is the last accrued timestamp
    require hub._assets[assetId].lastUpdateTimestamp!=0 && hub._assets[assetId].lastUpdateTimestamp == e1.block.timestamp; 
    
    
    //correlate the drawn index with the symbolic one, assume increasing and min value as proved in
    // HubAccrueIntegrityDrawnIndex.spec
    require hub._assets[assetId].drawnIndex == symbolicDrawnIndex(e1.block.timestamp);
    //based on rule drawnIndex_increasing(assetId);
    require  symbolicDrawnIndex(e1.block.timestamp) <= symbolicDrawnIndex(e2.block.timestamp);
    //based on requireInvariant baseDebtIndexMin(assetId); 
    require  symbolicDrawnIndex(e1.block.timestamp) >= wadRayMath.RAY();
    assert unrealizedFeeShares(e1,assetId) == 0 ;


    mathint assets_e1 = getAddedAssets(e1, assetId);
    mathint shares_e1 = hub._assets[assetId].addedShares;
    //requireInvariant totalAssetsVsShares(assetId,e);
    require assets_e1 >= shares_e1 ;
    
    // get the fee shares and asset at e2
    uint256 feeShares = unrealizedFeeShares(e2,assetId);
    mathint assets_e2 = getAddedAssets(e2, assetId);
    mathint shares_e2 = hub._assets[assetId].addedShares + feeShares;

    mathint changeInAsset  = assets_e2 - assets_e1;
    assert previewAddByAssets(e1,assetId, assert_uint256(changeInAsset)) >= feeShares;

    assert (assets_e2 + oneM) * (shares_e1 + oneM) >= (assets_e1 + oneM) * (shares_e2 + oneM); 
    satisfy (assets_e2 + oneM) * (shares_e1 + oneM) > (assets_e1 + oneM) * (shares_e2 + oneM); 

}

