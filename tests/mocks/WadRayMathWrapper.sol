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

  function RAD() public pure returns (uint256) {
    return WadRayMath.RAD;
  }

  function HALF_RAY() public pure returns (uint256) {
    return WadRayMath.HALF_RAY;
  }

  function HALF_RAD() public pure returns (uint256) {
    return WadRayMath.HALF_RAD;
  }

  function HALF_WAD() public pure returns (uint256) {
    return WadRayMath.HALF_WAD;
  }

  function WAD_RAY_RATIO() public pure returns (uint256) {
    return WadRayMath.WAD_RAY_RATIO;
  }

  function RAD_RAY_RATIO() public pure returns (uint256) {
    return WadRayMath.RAD_RAY_RATIO;
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

  function radMul(uint256 a, uint256 b) public pure returns (uint256) {
    return WadRayMath.radMul(a, b);
  }

  function radDiv(uint256 a, uint256 b) public pure returns (uint256) {
    return WadRayMath.radDiv(a, b);
  }

  function rayToWad(uint256 a) public pure returns (uint256) {
    return WadRayMath.rayToWad(a);
  }

  function wadToRay(uint256 a) public pure returns (uint256) {
    return WadRayMath.wadToRay(a);
  }

  function rayToRad(uint256 a) public pure returns (uint256) {
    return WadRayMath.rayToRad(a);
  }

  function radToRay(uint256 a) public pure returns (uint256) {
    return WadRayMath.radToRay(a);
  }

  function toRad(uint256 a) public pure returns (uint256) {
    return WadRayMath.toRad(a);
  }

  function fromRad(uint256 a) public pure returns (uint256) {
    return WadRayMath.fromRad(a);
  }

  function bpsToRad(uint256 a) internal pure returns (uint256) {
    return WadRayMath.bpsToRad(a);
  }

  function radToBps(uint256 a) internal pure returns (uint256) {
    return WadRayMath.radToBps(a);
  }

  function bpsToRay(uint256 a) internal pure returns (uint256) {
    return WadRayMath.bpsToRay(a);
  }

  function rayToBps(uint256 a) internal pure returns (uint256) {
    return WadRayMath.rayToBps(a);
  }
}
