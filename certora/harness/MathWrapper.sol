

import {Math} from '../../src/dependencies/openzeppelin/Math.sol';
import {WadRayMath} from '../../src/libraries/math/WadRayMath.sol';
import {WadRayMathExtended} from '../../src/libraries/math/WadRayMathExtended.sol';
import {PercentageMathExtended} from '../../src/libraries/math/PercentageMathExtended.sol';
pragma solidity ^0.8.0;


contract MathWrapper  {

    function SECONDS_PER_YEAR() pure external returns (uint256) { 
        return 365 days; 
    } 

    function mulDiv(uint256 x, uint256 y, uint256 denominator) external pure returns (uint256 result) {
        return Math.mulDiv(x,y, denominator);
    }

    function RAY() public pure returns (uint256) {
        return WadRayMathExtended.RAY;
    }

    function rayMul(uint256 a, uint256 b) public pure returns (uint256) {
        return WadRayMath.rayMul(a, b);
    }

    function rayDiv(uint256 a, uint256 b) public pure returns (uint256) {
    return WadRayMath.rayDiv(a, b);
    }

    function rayMulDown(uint256 a, uint256 b) public pure returns (uint256) {
        return WadRayMathExtended.rayMulDown(a, b);
    }

    function rayMulUp(uint256 a, uint256 b) public pure returns (uint256) {
        return WadRayMathExtended.rayMulUp(a, b);
    }

    function rayDivDown(uint256 a, uint256 b) public pure returns (uint256) {
        return WadRayMathExtended.rayDivDown(a, b);
    }
    function rayDivUp(uint256 a, uint256 b) public pure returns (uint256) {
        return WadRayMathExtended.rayDivUp(a, b);
    }

    function percentMulDown(uint256 value,uint256 percentage) public pure returns (uint256) {
        return PercentageMathExtended.percentMulDown(value, percentage);
    }
}
