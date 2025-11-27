// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {Premium} from 'src/hub/libraries/Premium.sol';

/// @title User Position Premium library
/// @author Aave Labs
/// @notice Implements premium calculations for user positions.
library UserPositionPremium {
  using PercentageMath for *;
  using MathUtils for *;
  using SafeCast for *;

  /// @notice Calculates the premium debt of a user position with full precision.
  /// @param userPosition The user position.
  /// @param drawnIndex The current drawn index.
  /// @return The premium debt, expressed in asset units and scaled by RAY.
  function calculatePremiumRay(
    ISpoke.UserPosition storage userPosition,
    uint256 drawnIndex
  ) internal view returns (uint256) {
    return
      Premium.calculatePremiumRay({
        premiumShares: userPosition.premiumShares,
        premiumOffsetRay: userPosition.premiumOffsetRay,
        drawnIndex: drawnIndex
      });
  }

  /// @notice Computes the premium delta for a user position given a new risk premium.
  /// @param userPosition The user position.
  /// @param drawnIndex The current drawn index.
  /// @param riskPremium The new risk premium, expressed in BPS.
  /// @param restoredPremiumRay The amount of premium to be restored, expressed in asset units and scaled by RAY.
  /// @return The computed premium delta.
  function getPremiumDelta(
    ISpoke.UserPosition storage userPosition,
    uint256 drawnIndex,
    uint256 riskPremium,
    uint256 restoredPremiumRay
  ) internal view returns (IHubBase.PremiumDelta memory) {
    uint256 oldPremiumShares = userPosition.premiumShares;
    int256 oldPremiumOffsetRay = userPosition.premiumOffsetRay;

    return
      getPremiumDelta(
        oldPremiumShares,
        oldPremiumOffsetRay,
        userPosition.drawnShares,
        drawnIndex,
        riskPremium,
        restoredPremiumRay
      );
  }

  /// @notice Calculates the premium delta for a user position given a new risk premium and new drawn shares.
  /// @param oldPremiumShares The current value of premium shares.
  /// @param oldPremiumOffsetRay The current value of premium offset, expressed in asset units and scaled by RAY.
  /// @param newDrawnShares The new drawn shares, including the restored shares.
  /// @param drawnIndex The current drawn index.
  /// @param riskPremium The new risk premium, expressed in BPS.
  /// @param restoredPremiumRay The amount of premium to be restored, expressed in asset units and scaled by RAY.
  /// @return The computed premium delta.
  function getPremiumDelta(
    uint256 oldPremiumShares,
    int256 oldPremiumOffsetRay,
    uint256 newDrawnShares,
    uint256 drawnIndex,
    uint256 riskPremium,
    uint256 restoredPremiumRay
  ) internal pure returns (IHubBase.PremiumDelta memory) {
    uint256 premiumDebtRay = Premium.calculatePremiumRay({
      premiumShares: oldPremiumShares,
      premiumOffsetRay: oldPremiumOffsetRay,
      drawnIndex: drawnIndex
    });
    uint256 newPremiumShares = newDrawnShares.percentMulUp(riskPremium);
    int256 newPremiumOffsetRay = (newPremiumShares * drawnIndex).signedSub(
      premiumDebtRay - restoredPremiumRay
    );

    return
      IHubBase.PremiumDelta({
        sharesDelta: newPremiumShares.signedSub(oldPremiumShares),
        offsetRayDelta: newPremiumOffsetRay - oldPremiumOffsetRay,
        restoredPremiumRay: restoredPremiumRay
      });
  }

  /// @notice Applies the premium delta to the user position.
  /// @param userPosition The user position.
  /// @param premiumDelta The premium delta to apply.
  function applyPremiumDelta(
    ISpoke.UserPosition storage userPosition,
    IHubBase.PremiumDelta memory premiumDelta
  ) internal {
    userPosition.premiumShares = userPosition
      .premiumShares
      .add(premiumDelta.sharesDelta)
      .toUint120();
    userPosition.premiumOffsetRay = (userPosition.premiumOffsetRay + premiumDelta.offsetRayDelta)
      .toInt200();
  }
}
