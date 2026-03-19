// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Constants {
  uint8 public constant MAX_ALLOWED_UNDERLYING_DECIMALS = 18;
  uint8 public constant MIN_ALLOWED_UNDERLYING_DECIMALS = 6;
  uint40 public constant MAX_ALLOWED_SPOKE_CAP = type(uint40).max;
  uint24 public constant MAX_RISK_PREMIUM_THRESHOLD = type(uint24).max; // 167772.15%
  uint256 internal constant MIN_DRAWN_INDEX = 1e27;
  uint256 public constant VIRTUAL_ASSETS = 1e6;
  uint256 public constant VIRTUAL_SHARES = 1e6;
  /// @dev AssetInterestRateStrategy Constants
  uint256 internal constant MAX_ALLOWED_DRAWN_RATE = 1000_00; // 1000.00% in BPS
  uint256 internal constant MIN_ALLOWED_DRAWN_RATE = 0; // not defined in AssetInterestRateStrategy
  uint256 internal constant MIN_OPTIMAL_RATIO = 1_00; // 1.00% in BPS
  uint256 internal constant MAX_OPTIMAL_RATIO = 99_00; // 99.00% in BPS
}
