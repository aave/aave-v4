// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {
  IAssetDrawnRateStrategy,
  IBasicDrawnRateStrategy
} from 'src/hub/interfaces/IAssetDrawnRateStrategy.sol';

/// @title AssetDrawnRateStrategy
/// @author Aave Labs
/// @notice Manages the optimal-usage-based drawn rate strategy for an asset.
/// @dev Strategies are Hub-specific, due to the usage of asset identifier as index of the `_drawnRateData` mapping.
contract AssetDrawnRateStrategy is IAssetDrawnRateStrategy {
  using WadRayMath for *;

  /// @inheritdoc IAssetDrawnRateStrategy
  uint256 public constant MAX_ALLOWED_DRAWN_RATE = 1000_00;

  /// @inheritdoc IAssetDrawnRateStrategy
  uint256 public constant MIN_OPTIMAL_RATIO = 1_00;

  /// @inheritdoc IAssetDrawnRateStrategy
  uint256 public constant MAX_OPTIMAL_RATIO = 99_00;

  /// @inheritdoc IAssetDrawnRateStrategy
  address public immutable HUB;

  /// @dev Map of asset identifiers to their drawn rate data.
  mapping(uint256 assetId => DrawnRateData) internal _drawnRateData;

  /// @dev Constructor.
  /// @param hub_ The address of the associated Hub.
  constructor(address hub_) {
    require(hub_ != address(0), InvalidAddress());
    HUB = hub_;
  }

  /// @notice Sets the drawn rate parameters for a specified asset.
  /// @param assetId The identifier of the asset.
  /// @param data The encoded parameters containing BPS data used to configure the drawn rate of the asset.
  function setDrawnRateData(uint256 assetId, bytes calldata data) external {
    require(HUB == msg.sender, OnlyHub());
    DrawnRateData memory rateData = abi.decode(data, (DrawnRateData));
    require(
      MIN_OPTIMAL_RATIO <= rateData.optimalUsageRatio &&
        rateData.optimalUsageRatio <= MAX_OPTIMAL_RATIO,
      InvalidOptimalUsageRatio()
    );
    require(
      rateData.rateGrowthBeforeOptimal <= rateData.rateGrowthAfterOptimal,
      GrowthAfterOptimalMustBeGteGrowthBeforeOptimal()
    );
    require(
      rateData.baseDrawnRate + rateData.rateGrowthBeforeOptimal + rateData.rateGrowthAfterOptimal <=
        MAX_ALLOWED_DRAWN_RATE,
      InvalidMaxDrawnRate()
    );

    _drawnRateData[assetId] = rateData;

    emit UpdateDrawnRateData(
      HUB,
      assetId,
      rateData.optimalUsageRatio,
      rateData.baseDrawnRate,
      rateData.rateGrowthBeforeOptimal,
      rateData.rateGrowthAfterOptimal
    );
  }

  /// @inheritdoc IAssetDrawnRateStrategy
  function getDrawnRateData(uint256 assetId) external view returns (DrawnRateData memory) {
    return _drawnRateData[assetId];
  }

  /// @inheritdoc IAssetDrawnRateStrategy
  function getOptimalUsageRatio(uint256 assetId) external view returns (uint256) {
    return _drawnRateData[assetId].optimalUsageRatio;
  }

  /// @inheritdoc IAssetDrawnRateStrategy
  function getBaseDrawnRate(uint256 assetId) external view returns (uint256) {
    return _drawnRateData[assetId].baseDrawnRate;
  }

  /// @inheritdoc IAssetDrawnRateStrategy
  function getRateGrowthBeforeOptimal(uint256 assetId) external view returns (uint256) {
    return _drawnRateData[assetId].rateGrowthBeforeOptimal;
  }

  /// @inheritdoc IAssetDrawnRateStrategy
  function getRateGrowthAfterOptimal(uint256 assetId) external view returns (uint256) {
    return _drawnRateData[assetId].rateGrowthAfterOptimal;
  }

  /// @inheritdoc IAssetDrawnRateStrategy
  function getMaxDrawnRate(uint256 assetId) external view returns (uint256) {
    return
      _drawnRateData[assetId].baseDrawnRate +
      _drawnRateData[assetId].rateGrowthBeforeOptimal +
      _drawnRateData[assetId].rateGrowthAfterOptimal;
  }

  /// @inheritdoc IBasicDrawnRateStrategy
  function calculateDrawnRate(
    uint256 assetId,
    uint256 liquidity,
    uint256 drawn,
    uint256 /* deficit */,
    uint256 swept
  ) external view returns (uint256) {
    DrawnRateData memory rateData = _drawnRateData[assetId];
    require(rateData.optimalUsageRatio > 0, DrawnRateDataNotSet(assetId));

    uint256 currentDrawnRateRay = rateData.baseDrawnRate.bpsToRay();
    if (drawn == 0) {
      return currentDrawnRateRay;
    }

    uint256 usageRatioRay = drawn.rayDivUp(liquidity + drawn + swept);
    uint256 optimalUsageRatioRay = rateData.optimalUsageRatio.bpsToRay();

    if (usageRatioRay <= optimalUsageRatioRay) {
      currentDrawnRateRay += rateData
        .rateGrowthBeforeOptimal
        .bpsToRay()
        .rayMulUp(usageRatioRay)
        .rayDivUp(optimalUsageRatioRay);
    } else {
      currentDrawnRateRay +=
        rateData.rateGrowthBeforeOptimal.bpsToRay() +
        rateData
          .rateGrowthAfterOptimal
          .bpsToRay()
          .rayMulUp(usageRatioRay - optimalUsageRatioRay)
          .rayDivUp(WadRayMath.RAY - optimalUsageRatioRay);
    }

    return currentDrawnRateRay;
  }
}
