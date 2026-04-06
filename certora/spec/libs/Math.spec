import "../symbolicRepresentation/Math_CVL.spec";


/**
Prove the summarization of mathematical functions.

For each summarization prove that the cvl representation is exactly the same of the solidity implementation. 
For each summarization there is a rule that proves:
1. same value
2. reverts on the same cases 

To run this spec file:
 certoraRun certora/conf/Math.conf 

**/

    methods {
        // envfree functions
        function RAY() external returns (uint256) envfree;
        function WAD() external returns (uint256) envfree;
        function rayMulDown(uint256 a, uint256 b) external returns (uint256) envfree;
        function rayMulUp(uint256 a, uint256 b) external returns (uint256) envfree;
        function rayDivDown(uint256 a, uint256 b) external returns (uint256) envfree;
        function rayDivUp(uint256 a, uint256 b) external returns (uint256) envfree;
        function wadDivDown(uint256 a, uint256 b) external returns (uint256) envfree;
        function wadDivUp(uint256 a, uint256 b) external returns (uint256) envfree;
        function percentMulDown(uint256 percentage, uint256 value) external  returns (uint256) envfree;
        function percentMulUp(uint256 percentage, uint256 value) external  returns (uint256) envfree;
        function mulDivDown(uint256 x, uint256 y, uint256 denominator) external returns (uint256) envfree;
        function mulDivUp(uint256 x, uint256 y, uint256 denominator) external returns (uint256) envfree;
        function fromRayUp(uint256 a) external returns (uint256) envfree;
        function toRay(uint256 a) external returns (uint256) envfree;

    }


/** @title Prove:
    function MathUtils.mulDivDown(uint256 x, uint256 y, uint256 denominator) internal returns (uint256) => 
        mulDivDownCVL(x,y,denominator);
*/
    rule MathUtils_mulDivDown(uint256 x, uint256 y, uint256 denominator)  {
        uint256 cvlResult = mulDivDownCVL@withrevert(x, y, denominator);
        bool cvlReverted = lastReverted;
        uint256 solResult = mulDivDown@withrevert(x, y, denominator);
        bool solReverted = lastReverted;
        assert cvlReverted == solReverted;
        assert !cvlReverted => cvlResult == solResult;
    }


/** @title Prove:
    function MathUtils.mulDivUp(uint256 x, uint256 y, uint256 denominator) internal returns (uint256) => 
        mulDivUpCVL(x,y,denominator);
*/
    rule MathUtils_mulDivUp(uint256 x, uint256 y, uint256 denominator)  {
        uint256 cvlResult = mulDivUpCVL@withrevert(x, y, denominator);
        bool cvlReverted = lastReverted;
        uint256 solResult = mulDivUp@withrevert(x, y, denominator);
        bool solReverted = lastReverted;
        assert cvlReverted == solReverted;
        assert !cvlReverted => cvlResult == solResult;
    }

/** @title Prove:
    function WadRayMathExtended.rayMulDown(uint256 a, uint256 b) internal returns (uint256) => 
        mulDivDownCVL(a,b,wadRayMath.RAY());
*/
    rule WadRayMathExtended_rayMulDown(uint256 a, uint256 b)  {
        uint256 cvlResult = mulDivDownCVL@withrevert(a, b, RAY());
        bool cvlReverted = lastReverted;
        uint256 solResult = rayMulDown@withrevert(a, b);
        bool solReverted = lastReverted;
        assert cvlReverted == solReverted;
        assert !cvlReverted => cvlResult == solResult;
    }


/** @title Prove:
    function WadRayMathExtended.rayMulUp(uint256 a, uint256 b) internal returns (uint256) => 
        mulDivUpCVL(a,b,wadRayMath.RAY());
*/
    rule WadRayMathExtended_rayMulUp(uint256 a, uint256 b)  {
        uint256 cvlResult = mulDivUpCVL@withrevert(a, b, RAY());
        bool cvlReverted = lastReverted;
        uint256 solResult = rayMulUp@withrevert(a, b);
        bool solReverted = lastReverted;
        assert cvlReverted == solReverted;
        assert !cvlReverted => cvlResult == solResult;
    }

/** @title Prove:    
    function WadRayMathExtended.rayDivDown(uint256 a, uint256 b) internal returns (uint256) => 
        mulDivDownCVL(a,wadRayMath.RAY(),b);
*/
    rule WadRayMathExtended_rayDivDown(uint256 a, uint256 b)  {
        uint256 cvlResult = mulDivDownCVL@withrevert(a, RAY(), b);
        bool cvlReverted = lastReverted;
        uint256 solResult = rayDivDown@withrevert(a, b);
        bool solReverted = lastReverted;
        assert cvlReverted == solReverted;
        assert !cvlReverted => cvlResult == solResult;
    }

/** @title Prove:   
    function WadRayMathExtended.rayDivUp(uint256 a, uint256 b) internal returns (uint256) => 
        mulDivUpCVL(a,wadRayMath.RAY(),b);
*/
    rule WadRayMathExtended_rayDivUp(uint256 a, uint256 b)  {
        uint256 cvlResult = mulDivUpCVL@withrevert(a, RAY(), b);
        bool cvlReverted = lastReverted;
        uint256 solResult = rayDivUp@withrevert(a, b);
        bool solReverted = lastReverted;
        assert cvlReverted == solReverted;
        assert !cvlReverted => cvlResult == solResult;
    }

/** @title Prove:    
    function WadRayMathExtended.wadDivDown(uint256 a, uint256 b) internal returns (uint256) => 
        mulDivDownCVL(a,wadRayMath.WAD(),b);
*/
    rule WadRayMathExtended_wadDivDown(uint256 a, uint256 b)  {
        uint256 cvlResult = mulDivDownCVL@withrevert(a, WAD(), b);
        bool cvlReverted = lastReverted;
        uint256 solResult = wadDivDown@withrevert(a, b);
        bool solReverted = lastReverted;
        assert cvlReverted == solReverted;
        assert !cvlReverted => cvlResult == solResult;
    }

/** @title Prove:   
    function WadRayMathExtended.wadDivUp(uint256 a, uint256 b) internal returns (uint256) => 
        mulDivUpCVL(a,wadRayMath.WAD(),b);
*/
    rule WadRayMathExtended_wadDivUp(uint256 a, uint256 b)  {
        uint256 cvlResult = mulDivUpCVL@withrevert(a, WAD(), b);
        bool cvlReverted = lastReverted;
        uint256 solResult = wadDivUp@withrevert(a, b);
        bool solReverted = lastReverted;
        assert cvlReverted == solReverted;
        assert !cvlReverted => cvlResult == solResult;
    }

/** @title Prove:
    function WadRayMathExtended.fromRayUp(uint256 a) internal returns (uint256) => 
        divRayUpCVL(a) expect uint256;
*/
    rule WadRayMathExtended_fromRayUp(uint256 a)  {
        uint256 cvlResult = divRayUpCVL@withrevert(a);
        bool cvlReverted = lastReverted;
        uint256 solResult = fromRayUp@withrevert(a);
        bool solReverted = lastReverted;
        assert cvlReverted == solReverted;
        assert !cvlReverted => cvlResult == solResult;
    }

/** @title Prove:
    function WadRayMathExtended.toRay(uint256 a) internal returns (uint256) => 
        mulRayCVL(a);
*/
    rule WadRayMathExtended_toRay(uint256 a)  {
        uint256 cvlResult = mulRayCVL@withrevert(a);
        bool cvlReverted = lastReverted;
        uint256 solResult = toRay@withrevert(a);
        bool solReverted = lastReverted;
        assert cvlReverted == solReverted;
        assert !cvlReverted => cvlResult == solResult;
    }

/** @title Prove:
    function PercentageMath.percentMulDown(uint256 value, uint256 percentage) internal returns (uint256) => 
        mulDivDownCVL(value, percentage, PERCENTAGE_FACTOR);
*/
    rule percentMulDown_integrity(uint256 percentage, uint256 value)  {    
        uint256 solResult = percentMulDown@withrevert(value, percentage);
        bool solReverted = lastReverted;
        uint256 cvlResult = mulDivDownCVL@withrevert(value, percentage, PERCENTAGE_FACTOR);
        bool cvlReverted = lastReverted;
        assert cvlReverted == solReverted;
        assert !cvlReverted => cvlResult == solResult;
    }

/** @title Prove: order of arguments does not matter for percentMulDown
*/
    rule percentMulDown_associativity(uint256 percentage, uint256 value)  {    
        uint256 result1 = percentMulDown@withrevert(percentage, value);
        bool result1Reverted = lastReverted;
        uint256 result2 = percentMulDown@withrevert(value, percentage);
        bool result2Reverted = lastReverted;
        assert result1Reverted == result2Reverted;
        assert !result1Reverted => result1 == result2;
        satisfy value == 0 && !result1Reverted; 
        satisfy percentage == 0 && !result1Reverted; 
    }

/** @title Prove:
    function PercentageMath.percentMulUp(uint256 value, uint256 percentage) internal returns (uint256) => 
        mulDivUpCVL(value, percentage, PERCENTAGE_FACTOR);
*/
    rule percentMulUp_integrity(uint256 percentage, uint256 value)  {    
        uint256 solResult = percentMulUp@withrevert(value, percentage);
        bool solReverted = lastReverted;
        uint256 cvlResult = mulDivUpCVL@withrevert(value, percentage, PERCENTAGE_FACTOR);
        bool cvlReverted = lastReverted;
        assert cvlReverted == solReverted;
        assert !cvlReverted => cvlResult == solResult;
    }

/** @title Prove: order of arguments does not matter for percentMulUp
*/
    rule percentMulUp_associativity(uint256 percentage, uint256 value)  {    
        uint256 result1 = percentMulUp@withrevert(percentage, value);
        bool result1Reverted = lastReverted;
        uint256 result2 = percentMulUp@withrevert(value, percentage);
        bool result2Reverted = lastReverted;
        assert result1Reverted == result2Reverted;
        assert !result1Reverted => result1 == result2;
        satisfy value == 0 && !result1Reverted; 
        satisfy percentage == 0 && !result1Reverted; 
    }
    
    rule RAY_definition() {
        assert RAY() == 10^27;
    }
    
    rule WAD_definition() {
        assert WAD() == 10^18;
    }

    persistent ghost uint256 PERCENTAGE_FACTOR {
    axiom PERCENTAGE_FACTOR == 10000;
    }