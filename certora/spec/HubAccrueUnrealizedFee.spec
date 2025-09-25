
/**
@title Prove unit test properties of UnrealizedFeeShares:
**/

import "./HubBase.spec";

using HubHarness as hub;
using MathWrapper as mathWrapper; 

methods {

    function MathWrapper.PERCENTAGE_FACTOR() external returns (uint256) envfree;
    function AssetLogic.getDrawnIndex(IHub.Asset storage asset) internal returns (uint256)  with (env e) => symbolicDrawnIndex(e.block.timestamp);

    function PercentageMath.percentMulDown(uint256 percentage, uint256 value) internal  returns (uint256) => 
    mulDivDownCVL(value,percentage,mathWrapper.PERCENTAGE_FACTOR());
}

// symbolic representation of drawnIndex that is a function of the block timestamp.
ghost symbolicDrawnIndex(uint256) returns uint256;

/**
@title Share increase in accrue is equal to the unrealized fee shares at this timestamp
**/
rule sharesIncreaseAsFeeShares(uint256 assetId){
    env e1; env e2; 
    
    require e1.block.timestamp < e2.block.timestamp;

    //assume accrue was called at e1.block.timestamp  
    require hub._assets[assetId].lastUpdateTimestamp!=0 && hub._assets[assetId].lastUpdateTimestamp == e1.block.timestamp; 
    uint256 sharesBefore = hub._assets[assetId].addedShares;
    
    uint256 feeShares = unrealizedFeeShares(e2,assetId);
    accrueInterest(e2,assetId);
    assert hub._assets[assetId].addedShares == sharesBefore + feeShares;
}

/**
@title Prove that the maximum value of unrealizedFeeShares is at 100% liquidityFee
**/
rule maxUnrealizedFeeShares(uint256 assetId){
    env e1; env e2;
    require e1.block.timestamp < e2.block.timestamp;
    require hub._assets[assetId].lastUpdateTimestamp!=0 && hub._assets[assetId].lastUpdateTimestamp == e1.block.timestamp; 

    require hub._assets[assetId].drawnIndex == symbolicDrawnIndex(e1.block.timestamp);
    require symbolicDrawnIndex(e1.block.timestamp) <= symbolicDrawnIndex(e2.block.timestamp);
    require symbolicDrawnIndex(e1.block.timestamp) >= wadRayMath.RAY();
    assert unrealizedFeeShares(e1,assetId) == 0 ;

    storage init_state = lastStorage;
    require hub._assets[assetId].liquidityFee == mathWrapper.PERCENTAGE_FACTOR();
    uint256 feeSharesAtMax = unrealizedFeeShares(e2,assetId);

    //assume any value that can be set in updateAssetConfig
    // must be called at e1 as accrue is happening in updateAssetConfig
    IHub.AssetConfig config;
    bytes irData;
    updateAssetConfig(e1,assetId,config,irData) at init_state;
    assert unrealizedFeeShares(e2,assetId) <= feeSharesAtMax;

}