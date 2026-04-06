
/**
@title Prove that accrue can not decrease the share rate

assets / shares is increasing


**/

import "./HubBase.spec";

using HubHarness as hub;

methods {
    
    function AssetLogic.getDrawnIndex(IHub.Asset storage asset) internal returns (uint256)  with (env e) => symbolicDrawnIndex(e.block.timestamp);


}


// symbolic representation of drawnIndex that is a function of the block timestamp.
ghost symbolicDrawnIndex(uint256) returns uint256;

/*
@title Prove that accrue can not decrease the share rate

Given e1, a timestamp last accrue, we prove that the share rate is the same or increasing at e2
We prove this for the maximum value of getUnrealizedFees, as proved in HubAccrueIntegrityUnrealizedFee.spec
Therefore, it holds for any smaller value of getUnrealizedFees, as shares_e2 will be smaller
**/


rule accrueSupplyRate(uint256 assetId){
    env e1; env e2; 
    uint256 oneM = 1000000;
    require e1.block.timestamp < e2.block.timestamp;


    // e1 is the last accrued timestamp
    require hub._assets[assetId].lastUpdateTimestamp!=0 && hub._assets[assetId].lastUpdateTimestamp == e1.block.timestamp; 
    require hub._assets[assetId].liquidityFee <= PERCENTAGE_FACTOR, "invariant liquidityFee_upper_bound";
    
    
    //correlate the drawn index with the symbolic one, assume increasing and min value as proved in
    // HubAccrueIntegrityDrawnIndex.spec
    require hub._assets[assetId].drawnIndex == symbolicDrawnIndex(e1.block.timestamp);
    //based on rule drawnIndex_increasing(assetId);
    require  symbolicDrawnIndex(e1.block.timestamp) <= symbolicDrawnIndex(e2.block.timestamp);
    //based on requireInvariant baseDebtIndexMin(assetId); 
    require  symbolicDrawnIndex(e1.block.timestamp) >= RAY;


    mathint assets_e1 = getAddedAssets(e1, assetId);
    mathint shares_e1 = hub._assets[assetId].addedShares;
    //requireInvariant totalAssetsVsShares(assetId,e);
    require assets_e1 >= shares_e1 ;
    
    //accrue interest
    accrueInterest(e2, assetId);
    mathint assets_e2 = getAddedAssets(e2, assetId);
    mathint shares_e2 = hub._assets[assetId].addedShares;

    assert (assets_e2 + oneM) * (shares_e1 + oneM) >= (assets_e1 + oneM) * (shares_e2 + oneM); 
    satisfy (assets_e2 + oneM) * (shares_e1 + oneM) > (assets_e1 + oneM) * (shares_e2 + oneM); 

}

function setup_three_timestamps(uint256 assetId, env e1, env e2, env e3){
    require e1.block.timestamp < e2.block.timestamp && e2.block.timestamp < e3.block.timestamp;

    require hub._assets[assetId].lastUpdateTimestamp!=0 && hub._assets[assetId].lastUpdateTimestamp == e1.block.timestamp; 
    //correlate the drawn index with the symbolic one, assume increasing and min value as proved in
    // HubAccrueIntegrityDrawnIndex.spec
    require hub._assets[assetId].drawnIndex == symbolicDrawnIndex(e1.block.timestamp);
    //based on rule drawnIndex_increasing(assetId);
    require  symbolicDrawnIndex(e1.block.timestamp) <= symbolicDrawnIndex(e2.block.timestamp);
    require  symbolicDrawnIndex(e2.block.timestamp) <= symbolicDrawnIndex(e3.block.timestamp);
    //based on requireInvariant baseDebtIndexMin(assetId); 
    require  symbolicDrawnIndex(e1.block.timestamp) >= RAY;
}


rule shareRate_withoutAccrue_time_monotonic(uint256 assetId){
    env e1; env e2; env e3;
    setup_three_timestamps(assetId, e1, e2, e3);
    require hub._assets[assetId].liquidityFee <= PERCENTAGE_FACTOR, "invariant liquidityFee_upper_bound";

    mathint assets_e1 = getAddedAssets(e1, assetId);
    mathint shares = hub._assets[assetId].addedShares;
    //requireInvariant totalAssetsVsShares(assetId,e);
    require assets_e1 >= shares;

    // get the fee shares and asset at e2
    mathint assets_e2 = getAddedAssets(e2, assetId);
    assert shares == hub._assets[assetId].addedShares;
    
    // get the fee shares and asset at e2;
    mathint assets_e3 = getAddedAssets(e3, assetId);

    assert assets_e3  >= assets_e2  ;
}


rule previewRemoveByShares_withoutAccrue_time_monotonic(uint256 assetId, uint256 shares){
    env e1; env e2; env e3;
    setup_three_timestamps(assetId, e1, e2, e3);
    require hub._assets[assetId].liquidityFee <= PERCENTAGE_FACTOR, "invariant liquidityFee_upper_bound";

    mathint assets_e1 = previewRemoveByShares(e1, assetId, shares);
    mathint assets_e2 = previewRemoveByShares(e2, assetId, shares);
    mathint assets_e3 = previewRemoveByShares(e3, assetId, shares);
    
    assert assets_e3 >= assets_e2 && assets_e2 >= assets_e1 ;
}


rule previewAddByAssets_withoutAccrue_time_monotonic(uint256 assetId, uint256 assets){
    env e1; env e2; env e3;
    setup_three_timestamps(assetId, e1, e2, e3);
    require hub._assets[assetId].liquidityFee <= PERCENTAGE_FACTOR, "invariant liquidityFee_upper_bound";

    mathint shares_e1 = previewAddByAssets(e1, assetId, assets);
    mathint shares_e2 = previewAddByAssets(e2, assetId, assets);
    mathint shares_e3 = previewAddByAssets(e3, assetId, assets);
    
    assert shares_e3 <= shares_e2 && shares_e2 <= shares_e1 ;
}


rule previewAddByShares_withoutAccrue_time_monotonic(uint256 assetId, uint256 shares){
    env e1; env e2; env e3;
    setup_three_timestamps(assetId, e1, e2, e3);
    require hub._assets[assetId].liquidityFee <= PERCENTAGE_FACTOR, "invariant liquidityFee_upper_bound";

    mathint assets_e1 = previewAddByShares(e1, assetId, shares);
    mathint assets_e2 = previewAddByShares(e2, assetId, shares);
    mathint assets_e3 = previewAddByShares(e3, assetId, shares);
    
    assert assets_e3 >= assets_e2 && assets_e2 >= assets_e1 ;
}


rule previewRemoveByAssets_withoutAccrue_time_monotonic(uint256 assetId, uint256 assets){
    env e1; env e2; env e3;
    setup_three_timestamps(assetId, e1, e2, e3);
    require hub._assets[assetId].liquidityFee <= PERCENTAGE_FACTOR, "invariant liquidityFee_upper_bound";

    mathint shares_e1 = previewRemoveByAssets(e1, assetId, assets);
    mathint shares_e2 = previewRemoveByAssets(e2, assetId, assets);
    mathint shares_e3 = previewRemoveByAssets(e3, assetId, assets);
    
    assert shares_e3 <= shares_e2 && shares_e2 <= shares_e1 ;
}



rule previewDrawByAssets_withoutAccrue_time_monotonic(uint256 assetId, uint256 assets){
    env e1; env e2; env e3;
    setup_three_timestamps(assetId, e1, e2, e3);
    require hub._assets[assetId].liquidityFee <= PERCENTAGE_FACTOR, "invariant liquidityFee_upper_bound";

    mathint shares_e1 = previewDrawByAssets(e1, assetId, assets);
    mathint shares_e2 = previewDrawByAssets(e2, assetId, assets);
    mathint shares_e3 = previewDrawByAssets(e3, assetId, assets);
    
    assert shares_e3 <= shares_e2 && shares_e2 <= shares_e1 ;
}


rule previewDrawByShares_withoutAccrue_time_monotonic(uint256 assetId, uint256 shares){
    env e1; env e2; env e3;
    setup_three_timestamps(assetId, e1, e2, e3);
    require hub._assets[assetId].liquidityFee <= PERCENTAGE_FACTOR, "invariant liquidityFee_upper_bound";

    mathint assets_e1 = previewDrawByShares(e1, assetId, shares);
    mathint assets_e2 = previewDrawByShares(e2, assetId, shares);
    mathint assets_e3 = previewDrawByShares(e3, assetId, shares);
    
    assert assets_e3 >= assets_e2 && assets_e2 >= assets_e1 ;
}



rule previewRestoreByAssets_withoutAccrue_time_monotonic(uint256 assetId, uint256 assets){
    env e1; env e2; env e3;
    setup_three_timestamps(assetId, e1, e2, e3);
    require hub._assets[assetId].liquidityFee <= PERCENTAGE_FACTOR, "invariant liquidityFee_upper_bound";

    mathint shares_e1 = previewRestoreByAssets(e1, assetId, assets);
    mathint shares_e2 = previewRestoreByAssets(e2, assetId, assets);
    mathint shares_e3 = previewRestoreByAssets(e3, assetId, assets);
    
    assert shares_e3 <= shares_e2 && shares_e2 <= shares_e1 ;
}


rule previewRestoreByShares_withoutAccrue_time_monotonic(uint256 assetId, uint256 shares){
    env e1; env e2; env e3;
    setup_three_timestamps(assetId, e1, e2, e3);
    require hub._assets[assetId].liquidityFee <= PERCENTAGE_FACTOR, "invariant liquidityFee_upper_bound";

    mathint assets_e1 = previewRestoreByShares(e1, assetId, shares);
    mathint assets_e2 = previewRestoreByShares(e2, assetId, shares);
    mathint assets_e3 = previewRestoreByShares(e3, assetId, shares);
    
    assert assets_e3 >= assets_e2 && assets_e2 >= assets_e1 ;
}