// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';

/// @title IOU library
/// @author Aave Labs
/// @notice Implements the IOU calculations.
library IOU {
  using SafeCast for *;

  /// @notice Calculates the total owed amount with full precision.
  /// @param drawnShares The number of  drawn shares.
  /// @param premiumShares The number of premium shares.
  /// @param premiumOffsetRay The premium offset, expressed in asset units and scaled by RAY.
  /// @param deficitRay The deficit amount, expressed in asset units and scaled by RAY.
  /// @param drawnIndex The current drawn index.
  /// @return The aggregated owed amount, expressed in asset units and scaled by RAY.
  function calculateTotalOwedRay(
    uint256 drawnShares,
    uint256 premiumShares,
    int256 premiumOffsetRay,
    uint256 deficitRay,
    uint256 drawnIndex
  ) internal pure returns (uint256) {
    uint256 premiumRay = calculatePremiumRay({
      premiumShares: premiumShares,
      premiumOffsetRay: premiumOffsetRay,
      drawnIndex: drawnIndex
    });
    return calculateDrawnRay(drawnShares, drawnIndex) + premiumRay + deficitRay;
  }

  /// @notice Calculate the drawn amount with full precision.
  /// @param drawnShares The number of drawn shares.
  /// @param drawnIndex The current drawn index.
  /// @return The drawn amount, expressed in asset units and scaled by RAY.
  function calculateDrawnRay(
    uint256 drawnShares,
    uint256 drawnIndex
  ) internal pure returns (uint256) {
    return drawnShares * drawnIndex;
  }

  /// @notice Calculates the premium debt with full precision.
  /// @param premiumShares The number of premium shares.
  /// @param premiumOffsetRay The premium offset, expressed in asset units and scaled by RAY.
  /// @param drawnIndex The current drawn index.
  /// @return The premium debt, expressed in asset units and scaled by RAY.
  function calculatePremiumRay(
    uint256 premiumShares,
    int256 premiumOffsetRay,
    uint256 drawnIndex
  ) internal pure returns (uint256) {
    return ((premiumShares * drawnIndex).toInt256() - premiumOffsetRay).toUint256();
  }
}
