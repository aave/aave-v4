
import "./ERC20s_CVL.spec";
import "./Math_CVL.spec";

using WadRayMathWrapper as wadRayMath;

/***

Base definitions used in all of LiquidityHuv spec files

Here we have only safe assumptions, safe summarization that are either proved in math.spec or a nondet summary

***/

methods {
 
    function Math.mulDiv(uint256 x, uint256 y, uint256 denominator) internal  returns (uint256) => mulDivDownCVL(x,y,denominator);
    function Math.mulDiv(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding
  ) internal returns (uint256) => mulDivCheckRounding(x,y,denominator,rounding);

    function WadRayMathWrapper.RAY() external returns (uint256) envfree;
    function WadRayMathWrapper.PERCENTAGE_FACTOR() external returns (uint256) envfree;

    function WadRayMathWrapper.rayMulDown(uint256 a, uint256 b) internal returns (uint256) => 
        mulDivDownCVL(a,b,wadRayMath.RAY());
    
    function WadRayMathWrapper.rayMulUp(uint256 a, uint256 b) internal returns (uint256) => 
        mulDivUpCVL(a,b,wadRayMath.RAY());
    
    function WadRayMathWrapper.rayDivDown(uint256 a, uint256 b) internal returns (uint256) => 
        mulDivDownCVL(a,wadRayMath.RAY(),b);
    
    function WadRayMathWrapper.rayDivUp(uint256 a, uint256 b) internal returns (uint256) => 
        mulDivUpCVL(a,wadRayMath.RAY(),b);

    function _.setInterestRateData(uint256 assetId, bytes data) external => NONDET; 

    function _._checkCanCall(address caller, bytes calldata data) internal => NONDET; 
}

function mulDivCheckRounding(uint256 x, uint256 y, uint256 z, Math.Rounding rounding) returns (uint256){
    if (rounding == Math.Rounding.Floor) {
        return mulDivDownCVL(x,y,z);
    }
    else if (rounding == Math.Rounding.Ceil) {
        return mulDivUpCVL(x,y,z);
    }
    else {
        assert false; 
    }
    return 0;
}
 