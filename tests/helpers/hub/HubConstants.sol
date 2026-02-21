// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

library HubConstants {
  uint8 public constant MAX_ALLOWED_UNDERLYING_DECIMALS = 18;
  uint8 public constant MIN_ALLOWED_UNDERLYING_DECIMALS = 6;
  uint40 public constant MAX_ALLOWED_SPOKE_CAP = type(uint40).max;
  uint24 public constant MAX_RISK_PREMIUM_THRESHOLD = type(uint24).max; // 167772.15%
  uint256 public constant VIRTUAL_ASSETS = 1e6;
  uint256 public constant VIRTUAL_SHARES = 1e6;
  uint24 internal constant MIN_BORROW_RATE = 0;
  uint256 internal constant MAX_BORROW_RATE = 1000_00;
  uint256 internal constant MIN_OPTIMAL_RATIO = 1_00;
  uint256 internal constant MAX_OPTIMAL_RATIO = 99_00;
}
