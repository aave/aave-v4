
/**
@title Prove unit test properties of AssetLogic.accrue() function
This is proven on LiquidityHubHarness which expose accure() as an external function 

To run this spec file:
 certoraRun certora/conf/LiquidityHubAccrueIntegrity.conf 
**/

import "./HubBase.spec";

using HubHarness as hub;
using MathWrapper as mathWrapper; 

methods {
    // envfree functions
    function mathWrapper.SECONDS_PER_YEAR() external returns (uint256) envfree;

    function AssetLogic.getDrawnIndex(DataTypes.Asset storage asset) internal returns (uint256)  with (env e) => symbolicDrawnIndex(e.block.timestamp);

    function PercentageMath.percentMulDown(uint256 percentage, uint256 value) internal  returns (uint256) => 
    //mulDivDownCVL(value,percentage,wadRayMathExtended.PERCENTAGE_FACTOR());
    identity(value);

}

function identity(uint256 x) returns uint256 {
    return x;
}

// symbolic representation of drawnIndex that is a function of the block timestamp.
ghost symbolicDrawnIndex(uint256) returns uint256;

/**
@title supplyExchangeRate is increasing on accrue. 

**/ 

rule supplyExchangeRateIsMonotonic_accrue_no_realizedPremium(){
    uint256 assetId;
    uint256 oneM = 1000000;
    env e1; env e2;
    require e1.block.timestamp < e2.block.timestamp ;


    // lastUpdateTimestamp can not be in the future, prove... 
    require hub._assets[assetId].lastUpdateTimestamp!=0 && hub._assets[assetId].lastUpdateTimestamp == e1.block.timestamp; 
    
    //requireInvariant baseDebtIndexMin(assetId); 
    require hub._assets[assetId].drawnIndex == symbolicDrawnIndex(e1.block.timestamp);
    require  symbolicDrawnIndex(e1.block.timestamp) <= symbolicDrawnIndex(e2.block.timestamp);
    require  symbolicDrawnIndex(e1.block.timestamp) >= wadRayMath.RAY();

     require hub._assets[assetId].realizedPremium == 0 ;
    require hub._assets[assetId].swept == 0 ;
    require hub._assets[assetId].liquidity == 0 ;
    require hub._assets[assetId].deficit == 0 ; 

    mathint assetsBefore = getTotalAddedAssets(e1, assetId);
    mathint sharesBefore = getTotalAddedShares(e1, assetId); 
    //requireInvariant totalAssetsVsShares(assetId,e);
    require assetsBefore >= sharesBefore;
    // simplification: fee is always 100%
    require hub._assets[assetId].liquidityFee == 10000;
    uint256 baseDebt = getAssetTotalOwed(e1, assetId);
    require hub._assets[assetId].drawnRate >= mathWrapper.SECONDS_PER_YEAR() &&
                sharesBefore > 0 &&
                baseDebt > wadRayMath.RAY();
    accrueInterest(e2,assetId);
    require hub._assets[assetId].drawnIndex == symbolicDrawnIndex(e2.block.timestamp);
    mathint assetsAfter = getTotalAddedAssets(e2, assetId);
    mathint sharesAfter = getTotalAddedShares(e2, assetId);
    require assetsAfter >= sharesAfter;
    satisfy (assetsAfter + oneM) * (sharesBefore + oneM) > (assetsBefore + oneM) * (sharesAfter + oneM); 
    assert (assetsAfter + oneM) * (sharesBefore + oneM) >= (assetsBefore + oneM) * (sharesAfter + oneM); 
}

