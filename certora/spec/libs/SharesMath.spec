/**
@title Prove mathematical properties of SharesMath.sol library
The rules proven here are used for summarizing additional functions

**/

import "../HubBase.spec";

methods { 
    // envfree functions 
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
    require totalAssets >= totalShares;
    assert x < y => 
            toSharesUp(x, totalAssets, totalShares) <= toSharesUp(y, totalAssets, totalShares);
}

/** 
@title Additivity of toSharesUp
While taking into account changes to totalSupply and totalAssets 
toSharesUp(x) + toSharesUp(y) >= toSharesUp(x+y) 
**/
rule toSharesUp_additivity(uint256 assetId, uint256 x, uint256 y){
    uint256 totalAssets; uint256 totalShares;
    require totalAssets >= totalShares;
    require totalAssets == 0 <=> totalShares == 0; //todo : verify this
    require totalAssets >= x + y;


    uint256 sharesForX = toSharesUp(x, totalAssets, totalShares);
    
    uint256 sharesForYAfterX = toSharesUp(y, require_uint256(totalAssets - x), 
    require_uint256(totalShares - sharesForX));

    uint256 sharesForXplusY = toSharesUp(require_uint256(x + y), totalAssets, totalShares);  
    assert  sharesForXplusY <= (sharesForX + sharesForYAfterX);
    satisfy sharesForXplusY == (sharesForX + sharesForYAfterX);
    satisfy sharesForXplusY < (sharesForX + sharesForYAfterX);
}

/** 
@title toSharesUp non zero
toSharesUp(x) == 0  <=>  x == 0
**/
rule toSharesUp_nonZero(uint256 assetId, uint256 x, uint256 y){
    uint256 totalAssets; uint256 totalShares;
    require totalAssets >= totalShares;

    uint256 sharesForX = toSharesUp(x, totalAssets, totalShares); 
    assert sharesForX == 0 <=> x ==0;
    satisfy x == 0;
    satisfy x != 0;
}

/** 
@title Monotonicity of toAssetsUp
x > y => toAssetsUp(x) >= toAssetsUp(y)
**/
rule toAssetsUp_monotonicity(uint256 assetId, uint256 x, uint256 y){
    uint256 totalAssets; uint256 totalShares;
    require totalAssets >= totalShares;
    assert x < y => 
            toAssetsUp(x, totalAssets, totalShares) <= toAssetsUp(y, totalAssets, totalShares);
}

/** 
@title Additivity of toAssetsUp
While taking into account changes to totalSupply and totalAssets 
toAssetsUp(x) + toAssetsUp(y) >=  toAssetsUp(x+y) 
**/
rule toAssetsUp_additivity(uint256 assetId, uint256 x, uint256 y){
    uint256 totalAssets; uint256 totalShares;
    require totalAssets >= totalShares;

    uint256 assetsForX = toAssetsUp(x, totalAssets, totalShares);
    uint256 assetsForYAfterX = toAssetsUp(y, require_uint256(totalAssets + assetsForX), require_uint256(totalShares + x));

    uint256 assetsForXplusY = toAssetsUp(require_uint256(x + y), totalAssets, totalShares);  
    assert assetsForXplusY <= assetsForX + assetsForYAfterX;
}

/** 
@title Monotonicity of toSharesDown
x > y => toSharesDown(x) >= toSharesDown(y)
**/
rule toSharesDown_monotonicity(uint256 assetId, uint256 x, uint256 y){
    uint256 totalAssets; uint256 totalShares;
    require totalAssets >= totalShares;
    assert x < y => 
            toSharesDown(x, totalAssets, totalShares) <= toSharesDown(y, totalAssets, totalShares);
}

/** 
@title Additivity of toSharesDown
While taking into account changes to totalSupply and totalAssets 
toSharesDown(x) + toSharesDown(y) <=  toSharesDown(x+y) 
**/
rule toSharesDown_additivity(uint256 assetId, uint256 x, uint256 y){
    uint256 totalAssets; uint256 totalShares;
    require totalAssets >= totalShares;

    uint256 sharesForX = toSharesDown(x, totalAssets, totalShares);
    uint256 sharesForYAfterX = toSharesDown(y, require_uint256(totalAssets + x), require_uint256(totalShares + sharesForX));

    uint256 sharesForXplusY = toSharesDown(require_uint256(x + y), totalAssets, totalShares);  
    assert sharesForXplusY >= sharesForX + sharesForYAfterX;
}

/** 
@title Monotonicity of toAssetsDown
x > y => toAssetsDown(x) >= toAssetsDown(y)
**/
rule toAssetsDown_monotonicity(uint256 assetId, uint256 x, uint256 y){
    uint256 totalAssets; uint256 totalShares;
    require totalAssets >= totalShares;
    assert x < y => 
            toAssetsDown(x, totalAssets, totalShares) <= toAssetsDown(y, totalAssets, totalShares);
}

/** 
@title Additivity of toAssetsDown
While taking into account changes to totalSupply and totalAssets 
toAssetsDown(x) + toAssetsDown(y) <=  toAssetsDown(x+y) 
**/
rule toAssetsDown_additivity(uint256 assetId, uint256 x, uint256 y){
    uint256 totalAssets; uint256 totalShares;
    require totalAssets >= totalShares;
    require totalAssets == 0 <=> totalShares == 0; //todo : verify this

    uint256 assetsForX = toAssetsDown(x, totalAssets, totalShares);
    uint256 assetsForYAfterX = toAssetsDown(y, require_uint256(totalAssets + assetsForX), require_uint256(totalShares + x));

    uint256 assetsForXplusY = toAssetsDown(require_uint256(x + y), totalAssets, totalShares);  
    assert assetsForXplusY >= assetsForX + assetsForYAfterX;
}
