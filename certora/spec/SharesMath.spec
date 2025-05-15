/**
@title Prove mathematical properties of SharesMath.sol library
The rules proven here are used for summarizing additonal functions

**/
import "./Math_CVL.spec";

using WadRayMathWrapper as wadRayMath;


methods {
 
    function WadRayMathWrapper.RAY() external returns (uint256) envfree;
    /* summary of functions prove in Math.spec */ 
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

    /* envfree functions */

    function toSharesDown(uint256 assets, uint256 totalAssets, uint256 totalShares) external  returns (uint256) envfree ;
    function toAssetsDown(uint256 shares, uint256 totalAssets, uint256 totalShares) external  returns (uint256) envfree ;
    
    function toSharesUp(uint256 assets, uint256 totalAssets, uint256 totalShares) external  returns (uint256) envfree ;
    function toAssetsUp(uint256 shares, uint256 totalAssets, uint256 totalShares) external  returns (uint256) envfree ;
    


}


/** 
@title Monotonicity of toSharesUp
x > y => toSharesUp(x) >= toSharesUp(y)
**/

rule toSharesUp_monotonicity(uint256 assetId, uint256 x, uint256 y){
    uint256 totalAssets; uint256 totalShares;
    require totalAssets <= totalShares;
    assert x < y => 
            toSharesUp(x, totalAssets, totalShares) <=  toSharesUp(y, totalAssets, totalShares);
}



/** 
@title Additivity of toSharesUp
toSharesUp(x) + toSharesUp(y) >=  toSharesUp(x+y) 
**/

rule toSharesUp_additivity(uint256 assetId, uint256 x, uint256 y){
    uint256 totalAssets; uint256 totalShares;
    require totalAssets <= totalShares;

    uint256 sharesForX =  toSharesUp(x, totalAssets, totalShares);
    uint256 sharesForYAfterX =  toSharesUp(y, require_uint256(totalAssets + x), require_uint256(totalShares + sharesForX));

    uint256 sharesForXplusY = toSharesUp(require_uint256(x + y), totalAssets, totalShares);  
    assert sharesForXplusY >= sharesForX + sharesForYAfterX;
}


/** 
@title Monotonicity of toAssetsUp
x > y => toAssetsUp(x) >= toAssetsUp(y)
**/

rule toAssetsUp_monotonicity(uint256 assetId, uint256 x, uint256 y){
    uint256 totalAssets; uint256 totalShares;
    require totalAssets <= totalShares;
    assert x < y => 
            toAssetsUp(x, totalAssets, totalShares) <=  toAssetsUp(y, totalAssets, totalShares);
}



/** 
@title Additivity of toAssetsUp
toAssetsUp(x) + toAssetsUp(y) <=  toAssetsUp(x+y) 
**/

rule toAssetsUp_additivity(uint256 assetId, uint256 x, uint256 y){
    uint256 totalAssets; uint256 totalShares;
    require totalAssets <= totalShares;

    uint256 assetsForX =  toAssetsUp(x, totalAssets, totalShares);
    uint256 assetsForYAfterX =  toAssetsUp(y, require_uint256(totalAssets + assetsForX), require_uint256(totalShares + x));

    uint256 assetsForXplusY = toAssetsUp(require_uint256(x + y), totalAssets, totalShares);  
    assert assetsForXplusY >= assetsForX + assetsForYAfterX;
}


/** 
@title Monotonicity of toSharesDown
x > y => toSharesDown(x) >= toSharesDown(y)
**/

rule toSharesDown_monotonicity(uint256 assetId, uint256 x, uint256 y){
    uint256 totalAssets; uint256 totalShares;
    require totalAssets <= totalShares;
    assert x < y => 
            toSharesDown(x, totalAssets, totalShares) <=  toSharesDown(y, totalAssets, totalShares);
}



/** 
@title Additivity of toSharesDown
toSharesDown(x) + toSharesDown(y) <=  toSharesDown(x+y) 
**/

rule toSharesDown_additivity(uint256 assetId, uint256 x, uint256 y){
    uint256 totalAssets; uint256 totalShares;
    require totalAssets <= totalShares;

    uint256 sharesForX =  toSharesDown(x, totalAssets, totalShares);
    uint256 sharesForYAfterX =  toSharesDown(y, require_uint256(totalAssets + x), require_uint256(totalShares + sharesForX));

    uint256 sharesForXplusY = toSharesDown(require_uint256(x + y), totalAssets, totalShares);  
    assert sharesForXplusY >= sharesForX + sharesForYAfterX;
}


/** 
@title Monotonicity of toAssetsDown
x > y => toAssetsDown(x) >= toAssetsDown(y)
**/

rule toAssetsDown_monotonicity(uint256 assetId, uint256 x, uint256 y){
    uint256 totalAssets; uint256 totalShares;
    require totalAssets <= totalShares;
    assert x < y => 
            toAssetsDown(x, totalAssets, totalShares) <=  toAssetsDown(y, totalAssets, totalShares);
}



/** 
@title Additivity of toAssetsDown
toAssetsDown(x) + toAssetsDown(y) <=  toAssetsDown(x+y) 
**/

rule toAssetsDown_additivity(uint256 assetId, uint256 x, uint256 y){
    uint256 totalAssets; uint256 totalShares;
    require totalAssets <= totalShares;

    uint256 assetsForX =  toAssetsDown(x, totalAssets, totalShares);
    uint256 assetsForYAfterX =  toAssetsDown(y, require_uint256(totalAssets + assetsForX), require_uint256(totalShares + x));

    uint256 assetsForXplusY = toAssetsDown(require_uint256(x + y), totalAssets, totalShares);  
    assert assetsForXplusY >= assetsForX + assetsForYAfterX;
}