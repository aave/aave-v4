// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';

contract WadRayMathWrapper {
  function WAD() public pure returns (uint256) {
    return WadRayMath.WAD;
  }

  function RAY() public pure returns (uint256) {
    return WadRayMath.RAY;
  }

  function PERCENTAGE_FACTOR() public pure returns (uint256) {
    return WadRayMath.PERCENTAGE_FACTOR;
  }

  function wadMulDown(uint256 a, uint256 b) public pure returns (uint256) {
    return WadRayMath.wadMulDown(a, b);
  }

  function wadMulUp(uint256 a, uint256 b) public pure returns (uint256) {
    return WadRayMath.wadMulUp(a, b);
  }

  function wadDivDown(uint256 a, uint256 b) public pure returns (uint256) {
    return WadRayMath.wadDivDown(a, b);
  }

  function wadDivUp(uint256 a, uint256 b) public pure returns (uint256) {
    return WadRayMath.wadDivUp(a, b);
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

  function toWad(uint256 a) public pure returns (uint256) {
    return WadRayMath.toWad(a);
  }

  function fromWadDown(uint256 a) public pure returns (uint256) {
    return WadRayMath.fromWadDown(a);
  }

  function bpsToRay(uint256 a) public pure returns (uint256) {
    return WadRayMath.bpsToRay(a);
  }
}
