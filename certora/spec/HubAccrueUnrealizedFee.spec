
/**
@title Prove unit test properties of getUnrealizedFees:
**/

import "./HubBase.spec";

using HubHarness as hub;

methods {
    function AssetLogic.getDrawnIndex(IHub.Asset storage asset) internal returns (uint256)  with (env e) => symbolicDrawnIndex(e.block.timestamp);

}

// symbolic representation of drawnIndex that is a function of the block timestamp.
ghost symbolicDrawnIndex(uint256) returns uint256;

/**
@title feeAmount increase in accrue is equal to the unrealized fee at this timestamp
**/
rule feeAmountIncrease(uint256 assetId){
    env e1; env e2; 
    
    require e1.block.timestamp < e2.block.timestamp;

    //assume accrue was called at e1.block.timestamp  
    require hub._assets[assetId].lastUpdateTimestamp!=0 && hub._assets[assetId].lastUpdateTimestamp == e1.block.timestamp; 
    require hub._assets[assetId].drawnIndex == symbolicDrawnIndex(e1.block.timestamp);
    require symbolicDrawnIndex(e1.block.timestamp) <= symbolicDrawnIndex(e2.block.timestamp);
    require symbolicDrawnIndex(e1.block.timestamp) >= RAY;
    uint256 feeAssetsBefore = hub._assets[assetId].realizedFees;
    uint256 feeAssets = getUnrealizedFees(e2,assetId);
    accrueInterest(e2,assetId);
    assert hub._assets[assetId].realizedFees == feeAssetsBefore + feeAssets;
}

/**
@title Prove that the maximum value of getUnrealizedFees is at 100% liquidityFee
**/
rule maxgetUnrealizedFees(uint256 assetId){
    env e1; env e2;
    require e1.block.timestamp < e2.block.timestamp;
    require hub._assets[assetId].lastUpdateTimestamp!=0 && hub._assets[assetId].lastUpdateTimestamp == e1.block.timestamp; 

    require hub._assets[assetId].drawnIndex == symbolicDrawnIndex(e1.block.timestamp);
    require symbolicDrawnIndex(e1.block.timestamp) <= symbolicDrawnIndex(e2.block.timestamp);
    require symbolicDrawnIndex(e1.block.timestamp) >= RAY;
    assert getUnrealizedFees(e1,assetId) == 0 ;

    storage init_state = lastStorage;
    require hub._assets[assetId].liquidityFee == PERCENTAGE_FACTOR;
    uint256 feesAtMax = getUnrealizedFees(e2,assetId);

    //assume any value that can be set in updateAssetConfig
    // must be called at e1 as accrue is happening in updateAssetConfig
    IHub.AssetConfig config;
    bytes irData;
    updateAssetConfig(e1,assetId,config,irData) at init_state;
    assert getUnrealizedFees(e2,assetId) <= feesAtMax;

}

/** 
@title Prove that when the lastUpdateTimestamp is the same as the block timestamp, the unrealized fees are 0
**/
rule lastUpdateTimestampSameAsBlockTimestamp(uint256 assetId){
    env e; 
    require hub._assets[assetId].lastUpdateTimestamp!=0 && hub._assets[assetId].lastUpdateTimestamp == e.block.timestamp; 
    require hub._assets[assetId].drawnIndex == symbolicDrawnIndex(e.block.timestamp);
    assert getUnrealizedFees(e,assetId) == 0;
}