
import "./symbolicRepresentation/ERC20s_CVL.spec";
import "./symbolicRepresentation/Math_CVL.spec";

using WadRayMathWrapper as wadRayMath;

/***

Base definitions used in all of Hub spec files

Here we have only safe assumptions, safe summarization that are either proved in math.spec or a nondet summary

***/

methods {
 
    function WadRayMathWrapper.RAY() external returns (uint256) envfree;
    function WadRayMathWrapper.PERCENTAGE_FACTOR() external returns (uint256) envfree;


    function _.mulDiv(uint256 x, uint256 y, uint256 denominator) internal  => 
        mulDivDownCVL(x,y,denominator) expect uint256;
    
    function _.mulDivDown(uint256 a, uint256 b, uint256 c) internal => 
        mulDivDownCVL(a,b,c) expect uint256;
    
    function _.mulDivUp(uint256 a, uint256 b, uint256 c) internal => 
        mulDivUpCVL(a,b,c) expect uint256;
    
    function _.mulDiv(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) internal => 
        mulDivCheckRounding(x,y,denominator,rounding) expect uint256;

    function WadRayMathWrapper.rayMulDown(uint256 a, uint256 b) internal returns (uint256) => 
        mulDivRayDownCVL(a,b);

    function WadRayMath.rayMulDown(uint256 a, uint256 b) internal returns (uint256) => 
        mulDivRayDownCVL(a,b);
    
    function WadRayMathWrapper.rayMulUp(uint256 a, uint256 b) internal returns (uint256) => 
        mulDivRayUpCVL(a,b);    

    function WadRayMath.rayMulUp(uint256 a, uint256 b) internal returns (uint256) => 
        mulDivRayUpCVL(a,b);
    
    function WadRayMathWrapper.rayDivDown(uint256 a, uint256 b) internal returns (uint256) => 
        mulDivDownCVL(a,wadRayMath.RAY(),b);

    function WadRayMath.rayDivDown(uint256 a, uint256 b) internal returns (uint256) => 
        mulDivDownCVL(a,wadRayMath.RAY(),b);
    
    function WadRayMathWrapper.rayDivUp(uint256 a, uint256 b) internal returns (uint256) => 
        mulDivUpCVL(a,wadRayMath.RAY(),b);
        
    function WadRayMath.rayDivUp(uint256 a, uint256 b) internal returns (uint256) => 
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
 