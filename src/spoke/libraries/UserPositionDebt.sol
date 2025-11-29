// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {Premium} from 'src/hub/libraries/Premium.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title User Debt library
/// @author Aave Labs
/// @notice Implements debt calculations for user positions.
library UserPositionDebt {
  using UserPositionDebt for ISpoke.UserPosition;
  using SafeCast for *;
  using PercentageMath for uint256;
  using WadRayMath for *;
  using MathUtils for *;

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

  /// @notice Calculates the premium delta for a user position given a new risk premium.
  /// @param userPosition The user position.
  /// @param drawnSharesTaken The amount of drawn shares taken from the user position.
  /// @param drawnIndex The current drawn index.
  /// @param riskPremium The new risk premium, expressed in BPS.
  /// @param restoredPremiumRay The amount of premium to be restored, expressed in asset units and scaled by RAY.
  /// @return The calculated premium delta.
  function getPremiumDelta(
    ISpoke.UserPosition storage userPosition,
    uint256 drawnSharesTaken,
    uint256 drawnIndex,
    uint256 riskPremium,
    uint256 restoredPremiumRay
  ) internal view returns (IHubBase.PremiumDelta memory) {
    uint256 oldPremiumShares = userPosition.premiumShares;
    int256 oldPremiumOffsetRay = userPosition.premiumOffsetRay;
    uint256 premiumDebtRay = Premium.calculatePremiumRay({
      premiumShares: oldPremiumShares,
      premiumOffsetRay: oldPremiumOffsetRay,
      drawnIndex: drawnIndex
    });
    uint256 newPremiumShares = (userPosition.drawnShares - drawnSharesTaken).percentMulUp(
      riskPremium
    );
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

  /// @dev Calculates the drawn debt and premium debt to restore for the given user position and amount.
  /// @param userPosition The user position.
  /// @param drawnIndex The drawn index of the reserve.
  /// @param amount The amount to restore.
  /// @return The amount of drawn debt to restore, expressed in asset units.
  /// @return The amount of premium debt to restore, expressed in asset units and scaled by RAY.
  function calculateRestoreAmount(
    ISpoke.UserPosition storage userPosition,
    uint256 drawnIndex,
    uint256 amount
  ) internal view returns (uint256, uint256) {
    (uint256 drawnDebt, uint256 premiumDebtRay) = userPosition.getDebt(drawnIndex);
    uint256 premiumDebt = premiumDebtRay.fromRayUp();
    if (amount >= drawnDebt + premiumDebt) {
      return (drawnDebt, premiumDebtRay);
    }

    if (amount < premiumDebt) {
      // amount.toRay() cannot overflow here
      uint256 amountRay = amount.toRay();
      return (0, amountRay);
    }
    return (amount - premiumDebt, premiumDebtRay);
  }

  /// @return The user's drawn debt, expressed in asset units.
  /// @return The user's premium debt, expressed in asset units and scaled by RAY.
  function getDebt(
    ISpoke.UserPosition storage userPosition,
    IHubBase hub,
    uint256 assetId
  ) internal view returns (uint256, uint256) {
    return userPosition.getDebt(hub.getAssetDrawnIndex(assetId));
  }

  /// @return The user's drawn debt, expressed in asset units.
  /// @return The user's premium debt, expressed in asset units and scaled by RAY.
  function getDebt(
    ISpoke.UserPosition storage userPosition,
    uint256 drawnIndex
  ) internal view returns (uint256, uint256) {
    uint256 premiumDebtRay = _calculatePremiumRay(userPosition, drawnIndex);
    return (userPosition.drawnShares.rayMulUp(drawnIndex), premiumDebtRay);
  }

  /// @dev Calculates the premium debt of a user position with full precision.
  /// @param userPosition The user position.
  /// @param drawnIndex The current drawn index.
  /// @return The premium debt, expressed in asset units and scaled by RAY.
  function _calculatePremiumRay(
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
}
