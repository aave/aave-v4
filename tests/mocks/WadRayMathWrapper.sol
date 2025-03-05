// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {WadRayMath} from 'src/contracts/WadRayMath.sol';

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

  function wadify(uint256 a) public pure returns (uint256) {
    return WadRayMath.wadify(a);
  }

  function dewadify(uint256 a) public pure returns (uint256) {
    return WadRayMath.dewadify(a);
  }

  function bpsToRay(uint256 a) internal pure returns (uint256) {
    return WadRayMath.bpsToRay(a);
  }

  function rayToBps(uint256 a) internal pure returns (uint256) {
    return WadRayMath.rayToBps(a);
  }
}
