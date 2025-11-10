// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';

/// @title Premium library
/// @author Aave Labs
/// @notice Implements the premium calculations.
library Premium {
  using MathUtils for uint256;
  using WadRayMath for uint256;

  function calculatePremiumDebtRay(
    uint256 premiumShares,
    uint256 drawnIndex,
    int256 premiumOffsetRay
  ) internal pure returns (uint256) {
    return (premiumShares * drawnIndex).sub(premiumOffsetRay);
  }

  function calculatePremiumDebt(
    uint256 premiumShares,
    uint256 drawnIndex,
    int256 premiumOffsetRay
  ) internal pure returns (uint256) {
    return calculatePremiumDebtRay(premiumShares, drawnIndex, premiumOffsetRay).fromRayUp();
  }
}
