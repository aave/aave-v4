// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';

/// @title Premium library
/// @author Aave Labs
/// @notice Implements the premium calculations.
library Premium {
  using WadRayMath for uint256;

  function calculateAccruedPremiumRay(
    uint256 premiumShares,
    uint256 drawnIndex,
    uint256 premiumOffsetRay
  ) internal pure returns (uint256) {
    return premiumShares * drawnIndex - premiumOffsetRay;
  }

  function calculatePremiumDebtRay(
    uint256 realizedPremiumRay,
    uint256 premiumShares,
    uint256 drawnIndex,
    uint256 premiumOffsetRay
  ) internal pure returns (uint256) {
    return
      realizedPremiumRay + calculateAccruedPremiumRay(premiumShares, drawnIndex, premiumOffsetRay);
  }
}
