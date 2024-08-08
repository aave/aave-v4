// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Math} from '../dependencies/openzeppelin/Math.sol';

library SharesMath {
  using Math for uint256;

  function toSharesDown(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
  ) internal pure returns (uint256) {
    if (totalShares == 0) return assets;
    return assets.mulDiv(totalShares, totalAssets, Math.Rounding.Floor);
  }

  function toAssetsDown(
    uint256 shares,
    uint256 totalAssets,
    uint256 totalShares
  ) internal pure returns (uint256) {
    if (totalShares == 0) return shares;
    return shares.mulDiv(totalAssets, totalShares, Math.Rounding.Floor);
  }

  function toSharesUp(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
  ) internal pure returns (uint256) {
    if (totalShares == 0) return assets;
    return assets.mulDiv(totalShares, totalAssets, Math.Rounding.Ceil);
  }

  function toAssetsUp(
    uint256 shares,
    uint256 totalAssets,
    uint256 totalShares
  ) internal pure returns (uint256) {
    if (totalShares == 0) return shares;
    return shares.mulDiv(totalAssets, totalShares, Math.Rounding.Ceil);
  }
}
