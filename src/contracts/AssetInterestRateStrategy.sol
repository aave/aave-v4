// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {IAssetInterestRateStrategy, IBasicInterestRateStrategy} from 'src/interfaces/IAssetInterestRateStrategy.sol';

/**
 * @title AssetInterestRateStrategy contract
 * @author Aave Labs
 * @notice Asset interest rate strategy used by the Aave protocol
 * @dev Strategies are hub-specific, due to the usage of asset id as index of the _interestRateData.
 */
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

  /// @dev Map of assetId and their interest rate data (assetId => interestRateData)
  mapping(uint256 assetId => InterestRateData data) internal _interestRateData;

  /**
   * @dev Constructor.
   */
  constructor(address hub_) {
    HUB = hub_;
  }

  /// @inheritdoc IAssetInterestRateStrategy
  function setInterestRateData(uint256 assetId, bytes calldata data) external {
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

    _interestRateData[assetId] = rateData;

    emit RateDataUpdate(
      assetId,
      rateData.optimalUsageRatio,
      rateData.baseVariableBorrowRate,
      rateData.variableRateSlope1,
      rateData.variableRateSlope2
    );
  }

  /// @inheritdoc IAssetInterestRateStrategy
  function getInterestRateData(uint256 assetId) external view returns (InterestRateData memory) {
    return _interestRateData[assetId];
  }

  /// @inheritdoc IAssetInterestRateStrategy
  function getOptimalUsageRatio(uint256 assetId) external view returns (uint256) {
    return _interestRateData[assetId].optimalUsageRatio;
  }

  /// @inheritdoc IAssetInterestRateStrategy
  function getBaseVariableBorrowRate(uint256 assetId) external view override returns (uint256) {
    return _interestRateData[assetId].baseVariableBorrowRate;
  }

  /// @inheritdoc IAssetInterestRateStrategy
  function getVariableRateSlope1(uint256 assetId) external view returns (uint256) {
    return _interestRateData[assetId].variableRateSlope1;
  }

  /// @inheritdoc IAssetInterestRateStrategy
  function getVariableRateSlope2(uint256 assetId) external view returns (uint256) {
    return _interestRateData[assetId].variableRateSlope2;
  }

  /// @inheritdoc IAssetInterestRateStrategy
  function getMaxVariableBorrowRate(uint256 assetId) external view override returns (uint256) {
    return
      _interestRateData[assetId].baseVariableBorrowRate +
      _interestRateData[assetId].variableRateSlope1 +
      _interestRateData[assetId].variableRateSlope2;
  }

  /// @inheritdoc IBasicInterestRateStrategy
  function calculateInterestRate(
    uint256 assetId,
    uint256 liquidity,
    uint256 drawn,
    uint256 premium // unused
  ) external view virtual override returns (uint256) {
    InterestRateData memory rateData = _interestRateData[assetId];
    require(rateData.optimalUsageRatio != 0, InterestRateDataNotSet(assetId));

    uint256 currentVariableBorrowRateRay = rateData.baseVariableBorrowRate.bpsToRay();
    if (drawn == 0) {
      return currentVariableBorrowRateRay;
    }

    uint256 usageRatioRay = drawn.rayDivUp(liquidity + drawn);
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
