// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Math} from 'src/dependencies/openzeppelin/Math.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';

/// @title MathHelpers
/// @notice Pure math helpers for the Aave V4 test suite.
abstract contract MathHelpers {
  using WadRayMath for *;

  function _min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }

  function _max(uint256 a, uint256 b) internal pure returns (uint256) {
    return a > b ? a : b;
  }

  function _divUp(uint256 a, uint256 b) internal pure returns (uint256) {
    return (a + b - 1) / b;
  }

  function _convertAmountToValue(
    uint256 amount,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal pure returns (uint256) {
    return (amount * assetPrice) * (WadRayMath.WAD / assetUnit);
  }

  function _convertValueToAmount(
    uint256 valueAmount,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal pure returns (uint256) {
    return ((valueAmount * assetUnit) / assetPrice).fromWadDown();
  }

  function _convertDecimals(
    uint256 amount,
    uint256 fromDecimals,
    uint256 toDecimals,
    bool roundUp
  ) internal pure returns (uint256) {
    return
      Math.mulDiv(
        amount,
        10 ** toDecimals,
        10 ** fromDecimals,
        (roundUp) ? Math.Rounding.Ceil : Math.Rounding.Floor
      );
  }

  function _bpsToRay(uint256 bps) internal pure returns (uint256) {
    return (bps * WadRayMath.RAY) / PercentageMath.PERCENTAGE_FACTOR;
  }
}
