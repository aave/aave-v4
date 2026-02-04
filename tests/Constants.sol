// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

library Constants {
  /// @dev Hub Constants
  uint8 public constant MAX_ALLOWED_UNDERLYING_DECIMALS = 18;
  uint8 public constant MIN_ALLOWED_UNDERLYING_DECIMALS = 6;
  uint40 public constant MAX_ALLOWED_SPOKE_CAP = type(uint40).max;
  uint24 public constant MAX_RISK_PREMIUM_THRESHOLD = type(uint24).max; // 167772.15%

  /// @dev Spoke Constants
  uint8 public constant ORACLE_DECIMALS = 8;
  uint64 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18;
  uint256 public constant DUST_LIQUIDATION_THRESHOLD = 1000e26;
  uint24 public constant MAX_ALLOWED_COLLATERAL_RISK = 1000_00; // 1000.00%
  uint256 public constant MAX_ALLOWED_DYNAMIC_CONFIG_KEY = type(uint24).max;
  uint256 public constant MAX_ALLOWED_ASSET_ID = type(uint16).max;
  uint16 public constant MAX_ALLOWED_USER_RESERVES_LIMIT = type(uint16).max;
}
