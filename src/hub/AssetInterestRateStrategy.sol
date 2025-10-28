// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {IAssetInterestRateStrategy, IBasicInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';

/// @title AssetInterestRateStrategy
/// @author Aave Labs
/// @notice Manages the kink-based interest rate strategy for an asset.
/// @dev Strategies are Hub-specific, due to the usage of asset identifier as index of the `_interestRateData` mapping.
contract AssetInterestRateStrategy is IAssetInterestRateStrategy {
  using WadRayMath for *;

  /// @inheritdoc IAssetInterestRateStrategy
  uint256 public constant MAX_BORROW_RATE = 1000_00; // 1000.00% in BPS

  /// @inheritdoc IAssetInterestRateStrategy
  uint256 public constant MIN_OPTIMAL_RATIO = 1_00; // 1.00% in BPS

  /// @inheritdoc IAssetInterestRateStrategy
  uint256 public constant MAX_OPTIMAL_RATIO = 99_00; // 99.00% in BPS

  /// @inheritdoc IAssetInterestRateStrategy
  address public immutable HUB;

  /// @dev Map of asset and their interest rate data (asset => interestRateData)
  mapping(address asset => InterestRateData) internal _interestRateData;

  /// @dev Constructor.
  /// @param hub_ The address of the associated Hub.
  constructor(address hub_) {
    require(hub_ != address(0), InvalidAddress());
    HUB = hub_;
  }

  /// @notice Sets the interest rate parameters for a specified asset.
  /// @param asset The address of the asset.
  /// @param data The encoded parameters containing BPS data used to configure the interest rate of the asset.
  function setInterestRateData(address asset, bytes calldata data) external {
    require(HUB == msg.sender, OnlyHub());
    InterestRateData memory rateData = abi.decode(data, (InterestRateData));
    require(
      MIN_OPTIMAL_RATIO <= rateData.optimalUsageRatio &&
        rateData.optimalUsageRatio <= MAX_OPTIMAL_RATIO,
      InvalidOptimalUsageRatio()
    );
    require(rateData.variableRateSlope1 <= rateData.variableRateSlope2, Slope2MustBeGteSlope1());
    require(
      rateData.baseVariableBorrowRate + rateData.variableRateSlope1 + rateData.variableRateSlope2 <=
        MAX_BORROW_RATE,
      InvalidMaxRate()
    );

    _interestRateData[asset] = rateData;

    emit UpdateRateData(
      HUB,
      asset,
      rateData.optimalUsageRatio,
      rateData.baseVariableBorrowRate,
      rateData.variableRateSlope1,
      rateData.variableRateSlope2
    );
  }

  /// @inheritdoc IAssetInterestRateStrategy
  function getInterestRateData(address asset) external view returns (InterestRateData memory) {
    return _interestRateData[asset];
  }

  /// @inheritdoc IAssetInterestRateStrategy
  function getOptimalUsageRatio(address asset) external view returns (uint256) {
    return _interestRateData[asset].optimalUsageRatio;
  }

  /// @inheritdoc IAssetInterestRateStrategy
  function getBaseVariableBorrowRate(address asset) external view returns (uint256) {
    return _interestRateData[asset].baseVariableBorrowRate;
  }

  /// @inheritdoc IAssetInterestRateStrategy
  function getVariableRateSlope1(address asset) external view returns (uint256) {
    return _interestRateData[asset].variableRateSlope1;
  }

  /// @inheritdoc IAssetInterestRateStrategy
  function getVariableRateSlope2(address asset) external view returns (uint256) {
    return _interestRateData[asset].variableRateSlope2;
  }

  /// @inheritdoc IAssetInterestRateStrategy
  function getMaxVariableBorrowRate(address asset) external view returns (uint256) {
    return
      _interestRateData[asset].baseVariableBorrowRate +
      _interestRateData[asset].variableRateSlope1 +
      _interestRateData[asset].variableRateSlope2;
  }

  /// @inheritdoc IBasicInterestRateStrategy
  function calculateInterestRate(
    address asset,
    uint256 liquidity,
    uint256 drawn,
    uint256 /* deficit */,
    uint256 swept
  ) external view returns (uint256) {
    InterestRateData memory rateData = _interestRateData[asset];
    require(rateData.optimalUsageRatio > 0, InterestRateDataNotSet(asset));

    uint256 currentVariableBorrowRateRay = rateData.baseVariableBorrowRate.bpsToRay();
    if (drawn == 0) {
      return currentVariableBorrowRateRay;
    }

    uint256 usageRatioRay = drawn.rayDivUp(liquidity + drawn + swept);
    uint256 optimalUsageRatioRay = rateData.optimalUsageRatio.bpsToRay();

    if (usageRatioRay <= optimalUsageRatioRay) {
      currentVariableBorrowRateRay += rateData
        .variableRateSlope1
        .bpsToRay()
        .rayMulUp(usageRatioRay)
        .rayDivUp(optimalUsageRatioRay);
    } else {
      currentVariableBorrowRateRay +=
        rateData.variableRateSlope1.bpsToRay() +
        rateData
          .variableRateSlope2
          .bpsToRay()
          .rayMulUp(usageRatioRay - optimalUsageRatioRay)
          .rayDivUp(WadRayMath.RAY - optimalUsageRatioRay);
    }

    return currentVariableBorrowRateRay;
  }
}
