// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

library Constants {
  /// @dev Hub Constants
  uint8 public constant MAX_ALLOWED_UNDERLYING_DECIMALS = 18;
  uint8 public constant MIN_ALLOWED_UNDERLYING_DECIMALS = 6;
  uint56 public constant MAX_ALLOWED_SPOKE_CAP = type(uint56).max;

  /// @dev Spoke Constants
  uint8 public constant ORACLE_DECIMALS = 8;
  uint64 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18;
  uint24 public constant MAX_ALLOWED_COLLATERAL_RISK = 1000_00; // 1000.00%
  bytes32 public constant SET_USER_POSITION_MANAGER_TYPEHASH =
    // keccak256('SetUserPositionManager(address positionManager,address user,bool approve,uint256 nonce,uint256 deadline)')
    0x758d23a3c07218b7ea0b4f7f63903c4e9d5cbde72d3bcfe3e9896639025a0214;
  uint256 public constant MAX_ALLOWED_ASSET_ID = type(uint16).max;
}
