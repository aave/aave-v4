// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

library Constants {
  /// @dev Hub Constants
  uint8 public constant MAX_ALLOWED_ASSET_DECIMALS = 18;
  uint56 internal constant MAX_CAP = type(uint56).max;
  /// @dev Spoke Constants
  uint64 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18;
  uint24 public constant MAX_COLLATERAL_RISK = 1000_00; // 1000.00%
}
