// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {MathUtils} from 'src/libraries/math/MathUtils.sol';

library SharesMath {
  using MathUtils for uint256;

  /// @dev Virtual assets and shares are used to mitigate share manipulation attacks
  uint256 internal constant VIRTUAL_ASSETS = 1e6;
  uint256 internal constant VIRTUAL_SHARES = 1e6;

  function toSharesDown(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
  ) internal pure returns (uint256) {
    return assets.mulDivDown(totalShares + VIRTUAL_SHARES, totalAssets + VIRTUAL_ASSETS);
  }

  function toAssetsDown(
    uint256 shares,
    uint256 totalAssets,
    uint256 totalShares
  ) internal pure returns (uint256) {
    return shares.mulDivDown(totalAssets + VIRTUAL_ASSETS, totalShares + VIRTUAL_SHARES);
  }

  function toSharesUp(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
  ) internal pure returns (uint256) {
    return assets.mulDivUp(totalShares + VIRTUAL_SHARES, totalAssets + VIRTUAL_ASSETS);
  }

  function toAssetsUp(
    uint256 shares,
    uint256 totalAssets,
    uint256 totalShares
  ) internal pure returns (uint256) {
    return shares.mulDivUp(totalAssets + VIRTUAL_ASSETS, totalShares + VIRTUAL_SHARES);
  }
}
