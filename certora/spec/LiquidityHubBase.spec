
import "./ERC20s_CVL.spec";
import "./Math_CVL.spec";

using WadRayMathWrapper as wadRayMath;

/***

Base definitions used in all of LiquidityHuv spec files

***/

methods {
 
    function Math.mulDiv(uint256 x, uint256 y, uint256 denominator) internal  returns (uint256) => mulDivDownCVL(x,y,denominator);

    function WadRayMathWrapper.RAY() external returns (uint256) envfree;

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

    //envfree function
    function getSpokeSuppliedShares(uint256 assetId, address spoke) external returns (uint256) envfree;

}