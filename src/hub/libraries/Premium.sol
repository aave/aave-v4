// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

/// @title Premium library
/// @author Aave Labs
/// @notice Implements the premium calculations.
library Premium {
  /// @notice Calculates the accrued premium with full precision.
  /// @param premiumShares The number of premium shares.
  /// @param drawnIndex The current drawn index.
  /// @param premiumOffsetRay The premium offset, expressed in asset units and scaled by RAY.
  /// @return The accrued premium, expressed in asset units and scaled by RAY.
  function calculateAccruedPremiumRay(
    uint256 premiumShares,
    uint256 drawnIndex,
    uint256 premiumOffsetRay
  ) internal pure returns (uint256) {
    return premiumShares * drawnIndex - premiumOffsetRay;
  }

  /// @notice Calculates the premium debt with full precision.
  /// @param premiumShares The number of premium shares.
  /// @param drawnIndex The current drawn index.
  /// @param premiumOffsetRay The premium offset, expressed in asset units and scaled by RAY.
  /// @param realizedPremiumRay The realized premium, expressed in asset units and scaled by RAY.
  /// @return The premium debt, expressed in asset units and scaled by RAY.
  function calculatePremiumRay(
    uint256 premiumShares,
    uint256 drawnIndex,
    uint256 premiumOffsetRay,
    uint256 realizedPremiumRay
  ) internal pure returns (uint256) {
    return
      realizedPremiumRay +
      calculateAccruedPremiumRay({
        premiumShares: premiumShares,
        drawnIndex: drawnIndex,
        premiumOffsetRay: premiumOffsetRay
      });
  }
}
