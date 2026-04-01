// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Constants {
  uint64 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18;
  uint256 public constant DUST_LIQUIDATION_THRESHOLD = 1000e26;
  uint24 public constant MAX_ALLOWED_COLLATERAL_RISK = 1000_00; // 1000.00%
  uint256 public constant MAX_ALLOWED_DYNAMIC_CONFIG_KEY = type(uint32).max;
  uint256 public constant MAX_ALLOWED_ASSET_ID = type(uint16).max;
  uint16 public constant MAX_ALLOWED_USER_RESERVES_LIMIT = type(uint16).max;
  uint32 public constant MIN_LIQUIDATION_BONUS = 100_00; // 100.00%
  uint16 internal constant MIN_LIQUIDATION_FEE = 0;
  uint16 internal constant MAX_LIQUIDATION_FEE = 100_00;
  uint128 internal constant MIN_TARGET_HEALTH_FACTOR = 1e18;
  uint32 internal constant MAX_LIQUIDATION_BONUS = 150_00;
  uint24 internal constant MIN_COLLATERAL_RISK_BPS = 0;
  uint24 internal constant MAX_COLLATERAL_RISK_BPS = 1000_00;
  uint16 internal constant MAX_LIQUIDATION_BONUS_FACTOR = 100_00; // 100.00%
}
