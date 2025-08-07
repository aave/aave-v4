// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Math} from 'src/dependencies/openzeppelin/Math.sol';

library SharesMath {
  using Math for uint256;

  /// @dev Virtual assets and shares are used to mitigate share manipulation attacks
  uint256 internal constant VIRTUAL_ASSETS = 1e6;
  uint256 internal constant VIRTUAL_SHARES = 1e6;

  function toSharesDown(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
  ) internal pure returns (uint256) {
    return
      assets.mulDiv(
        totalShares + VIRTUAL_SHARES,
        totalAssets + VIRTUAL_ASSETS,
        Math.Rounding.Floor
      );
  }

  function toAssetsDown(
    uint256 shares,
    uint256 totalAssets,
    uint256 totalShares
  ) internal pure returns (uint256) {
    return
      shares.mulDiv(
        totalAssets + VIRTUAL_ASSETS,
        totalShares + VIRTUAL_SHARES,
        Math.Rounding.Floor
      );
  }

  function toSharesUp(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
  ) internal pure returns (uint256) {
    return
      assets.mulDiv(totalShares + VIRTUAL_SHARES, totalAssets + VIRTUAL_ASSETS, Math.Rounding.Ceil);
  }

  function toAssetsUp(
    uint256 shares,
    uint256 totalAssets,
    uint256 totalShares
  ) internal pure returns (uint256) {
    return
      shares.mulDiv(totalAssets + VIRTUAL_ASSETS, totalShares + VIRTUAL_SHARES, Math.Rounding.Ceil);
  }
}
