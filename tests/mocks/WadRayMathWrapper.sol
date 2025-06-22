// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {WadRayMathExtended} from 'src/libraries/math/WadRayMathExtended.sol';

contract WadRayMathExtendedWrapper {
  function WAD() public pure returns (uint256) {
    return WadRayMathExtended.WAD;
  }

  function RAY() public pure returns (uint256) {
    return WadRayMathExtended.RAY;
  }

  function PERCENTAGE_FACTOR() public pure returns (uint256) {
    return WadRayMathExtended.PERCENTAGE_FACTOR;
  }

  function wadMulDown(uint256 a, uint256 b) public pure returns (uint256) {
    return WadRayMathExtended.wadMulDown(a, b);
  }

  function wadMulUp(uint256 a, uint256 b) public pure returns (uint256) {
    return WadRayMathExtended.wadMulUp(a, b);
  }

  function wadDivDown(uint256 a, uint256 b) public pure returns (uint256) {
    return WadRayMathExtended.wadDivDown(a, b);
  }

  function wadDivUp(uint256 a, uint256 b) public pure returns (uint256) {
    return WadRayMathExtended.wadDivUp(a, b);
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

  function wadify(uint256 a) public pure returns (uint256) {
    return WadRayMathExtended.wadify(a);
  }

  function dewadifyDown(uint256 a) public pure returns (uint256) {
    return WadRayMathExtended.dewadifyDown(a);
  }

  function bpsToRay(uint256 a) public pure returns (uint256) {
    return WadRayMathExtended.bpsToRay(a);
  }
}

contract WadRayMathWrapper {
  function WAD() public pure returns (uint256) {
    return WadRayMath.WAD;
  }

  function RAY() public pure returns (uint256) {
    return WadRayMath.RAY;
  }

  function HALF_RAY() public pure returns (uint256) {
    return WadRayMath.HALF_RAY;
  }

  function HALF_WAD() public pure returns (uint256) {
    return WadRayMath.HALF_WAD;
  }

  function WAD_RAY_RATIO() public pure returns (uint256) {
    return WadRayMath.WAD_RAY_RATIO;
  }

  function wadMul(uint256 a, uint256 b) public pure returns (uint256) {
    return WadRayMath.wadMul(a, b);
  }

  function wadDiv(uint256 a, uint256 b) public pure returns (uint256) {
    return WadRayMath.wadDiv(a, b);
  }

  function rayMul(uint256 a, uint256 b) public pure returns (uint256) {
    return WadRayMath.rayMul(a, b);
  }

  function rayDiv(uint256 a, uint256 b) public pure returns (uint256) {
    return WadRayMath.rayDiv(a, b);
  }

  function rayToWad(uint256 a) public pure returns (uint256) {
    return WadRayMath.rayToWad(a);
  }

  function wadToRay(uint256 a) public pure returns (uint256) {
    return WadRayMath.wadToRay(a);
  }

  function rayify(uint256 a) public pure returns (uint256) {
    return WadRayMath.rayify(a);
  }

  function derayify(uint256 a) public pure returns (uint256) {
    return WadRayMath.derayify(a);
  }

  function bpsToRay(uint256 a) internal pure returns (uint256) {
    return WadRayMath.bpsToRay(a);
  }

  function rayToBps(uint256 a) internal pure returns (uint256) {
    return WadRayMath.rayToBps(a);
  }
}
