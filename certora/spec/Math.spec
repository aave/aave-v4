import "./Math_CVL.spec";


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
        function rayMul(uint256 a, uint256 b) external returns (uint256) envfree;
        function rayDiv(uint256 a, uint256 b) external returns (uint256) envfree;
        function rayMulDown(uint256 a, uint256 b) external returns (uint256) envfree;
        function rayMulUp(uint256 a, uint256 b) external returns (uint256) envfree;
        function rayDivDown(uint256 a, uint256 b) external returns (uint256) envfree;
        function rayDivUp(uint256 a, uint256 b) external returns (uint256) envfree;
    }

/** @title Prove:
    function WadRayMath.rayMul(uint256 a, uint256 b) internal returns (uint256) => 
        mulDivHalf(a,b,wadRayMath.RAY());
*/
    rule WadRayMath_rayMul(uint256 a, uint256 b)  {
        uint256 cvlResult = mulDivHalf@withrevert(a, b, RAY());
        bool cvlReverted = lastReverted;
        uint256 solResult = rayMul@withrevert(a, b);
        bool solReverted = lastReverted;
        assert cvlReverted == solReverted;
        assert !cvlReverted => cvlResult == solResult;
    }

    
/** @title Prove:
    function WadRayMath.rayDiv(uint256 a, uint256 b) internal returns (uint256) => 
        mulDivHalf(a, wadRayMath.RAY(), b);
*/
    rule WadRayMath_rayDiv(uint256 a, uint256 b)  {
        uint256 cvlResult = mulDivHalf@withrevert(a, RAY(), b);
        bool cvlReverted = lastReverted;
        uint256 solResult = rayDiv@withrevert(a, b);
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