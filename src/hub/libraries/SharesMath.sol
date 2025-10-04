// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {MathUtils} from 'src/libraries/math/MathUtils.sol';

/// @title SharesMath library
/// @author Aave Labs
/// @notice Implements the logic to convert between assets and shares.
/// @dev Utilizes virtual assets and shares to mitigate share manipulation attacks.
library SharesMath {
  using MathUtils for uint256;

  uint256 internal constant VIRTUAL_ASSETS = 1e6;
  uint256 internal constant VIRTUAL_SHARES = 1e6;

  /// @notice Converts an amount of assets to the equivalent amount of shares, rounding down.
  function toSharesDown(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
  ) internal pure returns (uint256) {
    return assets.mulDivDown(totalShares + VIRTUAL_SHARES, totalAssets + VIRTUAL_ASSETS);
  }

  /// @notice Converts an amount of shares to the equivalent amount of assets, rounding down.
  function toAssetsDown(
    uint256 shares,
    uint256 totalAssets,
    uint256 totalShares
  ) internal pure returns (uint256) {
    return shares.mulDivDown(totalAssets + VIRTUAL_ASSETS, totalShares + VIRTUAL_SHARES);
  }

  /// @notice Converts an amount of assets to the equivalent amount of shares, rounding up.
  function toSharesUp(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
  ) internal pure returns (uint256) {
    return assets.mulDivUp(totalShares + VIRTUAL_SHARES, totalAssets + VIRTUAL_ASSETS);
  }

  /// @notice Converts an amount of shares to the equivalent amount of assets, rounding up.
  function toAssetsUp(
    uint256 shares,
    uint256 totalAssets,
    uint256 totalShares
  ) internal pure returns (uint256) {
    return shares.mulDivUp(totalAssets + VIRTUAL_ASSETS, totalShares + VIRTUAL_SHARES);
  }
}
