// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Types
/// @notice Shared struct definitions for hub-level test helpers.
abstract contract Types {
  struct AssetPosition {
    uint256 assetId;
    uint256 addedShares;
    uint256 addedAmount;
    uint256 drawnShares;
    uint256 drawn;
    uint256 premiumShares;
    int256 premiumOffsetRay;
    uint256 premium;
    uint40 lastUpdateTimestamp;
    uint256 liquidity;
    uint256 drawnIndex;
    uint256 drawnRate;
  }

  struct HubSnapshot {
    uint256 liquidity;
    uint256 addedAssets;
    uint256 addedShares;
    uint256 drawnAssets;
    uint256 drawnShares;
  }
}
