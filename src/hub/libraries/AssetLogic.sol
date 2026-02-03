// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {TransientSlot} from 'src/dependencies/openzeppelin/TransientSlot.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {SharesMath} from 'src/hub/libraries/SharesMath.sol';
import {Premium} from 'src/hub/libraries/Premium.sol';
import {IBasicInterestRateStrategy} from 'src/hub/interfaces/IBasicInterestRateStrategy.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

/// @title AssetLogic library
/// @author Aave Labs
/// @notice Implements the base logic and share price conversions for asset data.
library AssetLogic {
  using AssetLogic for IHub.Asset;
  using SafeCast for uint256;
  using MathUtils for uint256;
  using PercentageMath for uint256;
  using WadRayMath for *;
  using SharesMath for uint256;
  using TransientSlot for *;

  /// bytes32(uint256(keccak256("FEE_AMOUNT")) - 1)
  TransientSlot.Uint256Slot internal constant FEE_AMOUNT_RAY_SLOT =
    TransientSlot.Uint256Slot.wrap(
      0x91879d3c2c3ce12810fbfcd08f5ed8e2c386a19457ed8bebc2151a0f05b4836c
    );

  /// bytes32(uint256(keccak256("FEE_SHARES")) - 1)
  TransientSlot.Uint256Slot internal constant FEE_SHARES_SLOT =
    TransientSlot.Uint256Slot.wrap(
      0x0f70ea74dd445701867e94c5b4520c3ee79405fb0cb270d985de5a2c5e26004a
    );

  /// @notice Converts an amount of shares to the equivalent amount of drawn assets, rounding up.
  function toDrawnAssetsUp(
    IHub.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.rayMulUp(asset.getDrawnIndex());
  }

  /// @notice Converts an amount of shares to the equivalent amount of drawn assets, rounding down.
  function toDrawnAssetsDown(
    IHub.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.rayMulDown(asset.getDrawnIndex());
  }

  /// @notice Converts an amount of drawn assets to the equivalent amount of shares, rounding up.
  function toDrawnSharesUp(
    IHub.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.rayDivUp(asset.getDrawnIndex());
  }

  /// @notice Converts an amount of drawn assets to the equivalent amount of shares, rounding down.
  function toDrawnSharesDown(
    IHub.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.rayDivDown(asset.getDrawnIndex());
  }

  /// @notice Returns the total drawn assets amount for the specified asset.
  function drawn(IHub.Asset storage asset, uint256 drawnIndex) internal view returns (uint256) {
    return asset.drawnShares.rayMulUp(drawnIndex);
  }

  /// @notice Returns the total premium amount for the specified asset.
  function premium(IHub.Asset storage asset, uint256 drawnIndex) internal view returns (uint256) {
    return
      Premium
        .calculatePremiumRay({
          premiumShares: asset.premiumShares,
          drawnIndex: drawnIndex,
          premiumOffsetRay: asset.premiumOffsetRay
        })
        .fromRayUp();
  }

  /// @notice Returns the total amount owed for the specified asset, including drawn and premium.
  function totalOwed(IHub.Asset storage asset, uint256 drawnIndex) internal view returns (uint256) {
    return asset.drawn(drawnIndex) + asset.premium(drawnIndex);
  }

  /// @notice Returns the total added assets for the specified asset.
  function totalAddedAssets(IHub.Asset storage asset) internal view returns (uint256) {
    uint256 drawnIndex = asset.getDrawnIndex();
    uint256 totalAddedSupplierAssets = asset.liquidity +
      asset.swept +
      _calculateAggregatedOwedRay({
        drawnShares: asset.drawnShares,
        premiumShares: asset.premiumShares,
        premiumOffsetRay: asset.premiumOffsetRay,
        deficitRay: asset.deficitRay,
        drawnIndex: drawnIndex
      }).fromRayUp();

    uint256 feeAmountRay = FEE_AMOUNT_RAY_SLOT.tload();
    if (feeAmountRay > 0) {
      return totalAddedSupplierAssets - feeAmountRay.fromRayDown();
    }
    return
      totalAddedSupplierAssets -
      asset.realizedFeesRay.fromRayDown() -
      asset.getUnrealizedFees(drawnIndex);
  }

  /// @notice Converts an amount of shares to the equivalent amount of added assets, rounding up.
  function toAddedAssetsUp(
    IHub.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.toAssetsUp(asset.totalAddedAssets(), asset.addedShares);
  }

  /// @notice Converts an amount of shares to the equivalent amount of added assets, rounding down.
  function toAddedAssetsDown(
    IHub.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.toAssetsDown(asset.totalAddedAssets(), asset.addedShares);
  }

  /// @notice Converts an amount of added assets to the equivalent amount of shares, rounding up.
  function toAddedSharesUp(
    IHub.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.toSharesUp(asset.totalAddedAssets(), asset.addedShares);
  }

  /// @notice Converts an amount of added assets to the equivalent amount of shares, rounding down.
  function toAddedSharesDown(
    IHub.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.toSharesDown(asset.totalAddedAssets(), asset.addedShares);
  }

  /// @notice Updates the drawn rate of a specified asset and mints fee shares.
  /// @dev Premium debt is not used in the interest rate calculation.
  /// @dev Uses last stored index; asset accrual should have already occurred.
  /// @dev Imprecision from downscaling `deficitRay` does not accumulate.
  function updateDrawnRateAndMintFeeShares(
    IHub.Asset storage asset,
    mapping(uint256 assetId => mapping(address spoke => IHub.SpokeData)) storage spokes,
    uint256 assetId
  ) internal {
    uint256 drawnIndex = asset.drawnIndex;
    uint256 newDrawnRate = IBasicInterestRateStrategy(asset.irStrategy).calculateInterestRate({
      assetId: assetId,
      liquidity: asset.liquidity,
      drawn: asset.drawn(drawnIndex),
      deficit: asset.deficitRay.fromRayUp(),
      swept: asset.swept
    });
    asset.drawnRate = newDrawnRate.toUint96();

    uint256 feeAmountRay = FEE_AMOUNT_RAY_SLOT.tload();
    uint120 feeShares = FEE_SHARES_SLOT.tload().toUint120();
    if (feeShares > 0) {
      address feeReceiver = asset.feeReceiver;
      asset.addedShares += feeShares;
      spokes[assetId][feeReceiver].addedShares += feeShares;
      FEE_SHARES_SLOT.tstore(0);
      emit IHub.MintFeeShares(assetId, feeReceiver, feeShares, asset.toAddedAssetsDown(feeShares));
    }
    asset.realizedFeesRay = feeAmountRay.toUint200();
    FEE_AMOUNT_RAY_SLOT.tstore(0);

    emit IHub.UpdateAsset(assetId, drawnIndex, newDrawnRate);
  }

  /// @notice Accrues interest and fees for the specified asset.
  function accrue(IHub.Asset storage asset) internal {
    if (asset.lastUpdateTimestamp == block.timestamp) {
      return;
    }

    uint256 drawnIndex = asset.getDrawnIndex();
    uint256 feeAmountRay = asset.realizedFeesRay + asset.getUnrealizedFees(drawnIndex).toRay();
    uint256 feeShares = asset.toAddedSharesDown(feeAmountRay.fromRayDown());
    uint256 perfectFeeAmountRay = feeShares == 0 ? 0 : asset.toAddedAssetsUp(feeShares.toRay());
    FEE_AMOUNT_RAY_SLOT.tstore(
      feeAmountRay > perfectFeeAmountRay ? feeAmountRay - perfectFeeAmountRay : 0
    );
    FEE_SHARES_SLOT.tstore(feeShares);
    asset.drawnIndex = drawnIndex.toUint120();
    asset.lastUpdateTimestamp = block.timestamp.toUint40();
  }

  /// @notice Calculates the drawn index of a specified asset based on the existing drawn rate and index.
  function getDrawnIndex(IHub.Asset storage asset) internal view returns (uint256) {
    uint256 previousIndex = asset.drawnIndex;
    uint40 lastUpdateTimestamp = asset.lastUpdateTimestamp;
    if (
      lastUpdateTimestamp == block.timestamp || (asset.drawnShares == 0 && asset.premiumShares == 0)
    ) {
      return previousIndex;
    }
    return
      previousIndex.rayMulUp(
        MathUtils.calculateLinearInterest(asset.drawnRate, lastUpdateTimestamp)
      );
  }

  /// @notice Calculates the amount of fees derived from the index growth due to interest accrual.
  /// @param drawnIndex The current drawn index.
  function getUnrealizedFees(
    IHub.Asset storage asset,
    uint256 drawnIndex
  ) internal view returns (uint256) {
    uint256 previousIndex = asset.drawnIndex;
    if (previousIndex == drawnIndex) {
      return 0;
    }

    uint256 liquidityFee = asset.liquidityFee;
    if (liquidityFee == 0) {
      return 0;
    }

    uint120 drawnShares = asset.drawnShares;
    uint120 premiumShares = asset.premiumShares;
    int256 premiumOffsetRay = asset.premiumOffsetRay;
    uint256 deficitRay = asset.deficitRay;

    uint256 aggregatedOwedRayAfter = _calculateAggregatedOwedRay({
      drawnShares: drawnShares,
      premiumShares: premiumShares,
      premiumOffsetRay: premiumOffsetRay,
      deficitRay: deficitRay,
      drawnIndex: drawnIndex
    });

    uint256 aggregatedOwedRayBefore = _calculateAggregatedOwedRay({
      drawnShares: drawnShares,
      premiumShares: premiumShares,
      premiumOffsetRay: premiumOffsetRay,
      deficitRay: deficitRay,
      drawnIndex: previousIndex
    });

    return
      (aggregatedOwedRayAfter.fromRayUp() - aggregatedOwedRayBefore.fromRayUp()).percentMulDown(
        liquidityFee
      );
  }

  /// @notice Calculates the aggregated owed amount for a specified asset, expressed in asset units and scaled by RAY.
  function _calculateAggregatedOwedRay(
    uint256 drawnShares,
    uint256 premiumShares,
    int256 premiumOffsetRay,
    uint256 deficitRay,
    uint256 drawnIndex
  ) internal pure returns (uint256) {
    uint256 premiumRay = Premium.calculatePremiumRay({
      premiumShares: premiumShares,
      premiumOffsetRay: premiumOffsetRay,
      drawnIndex: drawnIndex
    });
    return (drawnShares * drawnIndex) + premiumRay + deficitRay;
  }
}
