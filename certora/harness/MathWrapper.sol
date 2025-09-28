import {Math} from '../../src/dependencies/openzeppelin/Math.sol';
import {WadRayMath} from '../../src/libraries/math/WadRayMath.sol';
import {PercentageMath} from '../../src/libraries/math/PercentageMath.sol';
import {MathUtils} from '../../src/libraries/math/MathUtils.sol';

pragma solidity ^0.8.0;

contract MathWrapper {
  function SECONDS_PER_YEAR() external pure returns (uint256) {
    return 365 days;
  }

  function mulDiv(
    uint256 x,
    uint256 y,
    uint256 denominator
  ) external pure returns (uint256 result) {
    return Math.mulDiv(x, y, denominator);
  }

  function mulDivDown(
    uint256 x,
    uint256 y,
    uint256 denominator
  ) external pure returns (uint256 result) {
    return MathUtils.mulDivDown(x, y, denominator);
  }

  function mulDivUp(
    uint256 x,
    uint256 y,
    uint256 denominator
  ) external pure returns (uint256 result) {
    return MathUtils.mulDivUp(x, y, denominator);
  }

  function RAY() public pure returns (uint256) {
    return WadRayMath.RAY;
  }

  function rayMulDown(uint256 a, uint256 b) public pure returns (uint256) {
    return WadRayMath.rayMulDown(a, b);
  }

  function rayMulUp(uint256 a, uint256 b) public pure returns (uint256) {
    return WadRayMath.rayMulUp(a, b);
  }

  function rayDivDown(uint256 a, uint256 b) public pure returns (uint256) {
    return WadRayMath.rayDivDown(a, b);
  }

  function rayDivUp(uint256 a, uint256 b) public pure returns (uint256) {
    return WadRayMath.rayDivUp(a, b);
  }

  function percentMulDown(uint256 percentage, uint256 value) public pure returns (uint256) {
    return PercentageMath.percentMulDown(percentage, value);
  }

  function PERCENTAGE_FACTOR() public pure returns (uint256) {
    return PercentageMath.PERCENTAGE_FACTOR;
  }
}
