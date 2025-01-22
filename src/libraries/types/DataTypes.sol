// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

library DataTypes {
  struct CalculateInterestRatesParams {
    uint256 liquidityAdded;
    uint256 liquidityTaken;
    uint256 totalDebt;
    uint256 reserveFactor; // likely not required
    uint256 assetId;
    uint256 virtualUnderlyingBalance;
    bool usingVirtualBalance;
  }

  // TODO: borrow cap per spoke
  struct SpokeConfig {
    uint256 drawCap; // asset denominated
    uint256 supplyCap; // asset denominated
  }

  struct AssetConfig {
    uint256 decimals;
    bool active; // TODO: frozen, paused
    address irStrategy; // todo use interface
  }
}
