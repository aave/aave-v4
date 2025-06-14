// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {IDefaultInterestRateStrategy} from 'src/interfaces/IDefaultInterestRateStrategy.sol';
import {IAssetInterestRateStrategy} from 'src/interfaces/IAssetInterestRateStrategy.sol';

/**
 * @title DefaultAssetInterestRateStrategy contract
 * @author Aave Labs
 * @notice Default interest rate strategy used by the Aave protocol
 * @dev Strategies are pool-specific: each contract CAN'T be used across different Aave pools
 *   due to the caching of the PoolAddressesProvider and the usage of underlying addresses as
 *   index of the _interestRateData
 */
contract DefaultAssetInterestRateStrategy is IDefaultInterestRateStrategy {
  using WadRayMath for uint16;
  using WadRayMath for uint32;
  using WadRayMath for uint256;

  /// @inheritdoc IDefaultInterestRateStrategy
  uint256 public constant MAX_BORROW_RATE = 1000_00; // 1000.00% in BPS

  /// @inheritdoc IDefaultInterestRateStrategy
  uint256 public constant MIN_OPTIMAL_RATIO = 1_00; // 1.00% in BPS

  /// @inheritdoc IDefaultInterestRateStrategy
  uint256 public constant MAX_OPTIMAL_RATIO = 99_00; // 99.00% in BPS

  /// @dev Map of assetId and their interest rate data (assetId => interestRateData)
  mapping(uint256 => InterestRateData) internal _interestRateData;

  /**
   * @dev Constructor.
   */
  constructor() {
    /// TODO: Access Control; Store authorized address to set interest rate data
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function setInterestRateData(uint256 assetId, InterestRateData calldata rateData) external {
    /// TODO: Access Control; Only authorized address can set interest rate data

    require(
      MIN_OPTIMAL_RATIO <= rateData.optimalUsageRatio &&
        rateData.optimalUsageRatio <= MAX_OPTIMAL_RATIO,
      INVALID_OPTIMAL_USAGE_RATIO()
    );

    require(
      rateData.variableRateSlope1 <= rateData.variableRateSlope2,
      SLOPE_2_MUST_BE_GTE_SLOPE_1()
    );

    // The maximum rate should not be above certain threshold
    require(
      rateData.baseVariableBorrowRate + rateData.variableRateSlope1 + rateData.variableRateSlope2 <=
        MAX_BORROW_RATE,
      INVALID_MAX_RATE()
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

  /// @inheritdoc IDefaultInterestRateStrategy
  function getInterestRateData(uint256 assetId) external view returns (InterestRateData memory) {
    return _interestRateData[assetId];
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getOptimalUsageRatio(uint256 assetId) external view returns (uint256) {
    return _interestRateData[assetId].optimalUsageRatio;
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getBaseVariableBorrowRate(uint256 assetId) external view override returns (uint256) {
    return _interestRateData[assetId].baseVariableBorrowRate;
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getVariableRateSlope1(uint256 assetId) external view returns (uint256) {
    return _interestRateData[assetId].variableRateSlope1;
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getVariableRateSlope2(uint256 assetId) external view returns (uint256) {
    return _interestRateData[assetId].variableRateSlope2;
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getMaxVariableBorrowRate(uint256 assetId) external view override returns (uint256) {
    return
      _interestRateData[assetId].baseVariableBorrowRate +
      _interestRateData[assetId].variableRateSlope1 +
      _interestRateData[assetId].variableRateSlope2;
  }

  /// @inheritdoc IAssetInterestRateStrategy
  function calculateInterestRate(
    uint256 assetId,
    uint256 totalDebt,
    uint256 availableLiquidity
  ) external view virtual override returns (uint256) {
    InterestRateData memory rateData = _interestRateData[assetId];
    require(rateData.optimalUsageRatio != 0, INTEREST_RATE_DATA_NOT_SET(assetId));

    uint256 currentVariableBorrowRateRay = rateData.baseVariableBorrowRate.bpsToRay();
    if (totalDebt == 0) {
      return currentVariableBorrowRateRay;
    }

    uint256 usageRatioRay = totalDebt.rayDiv(availableLiquidity + totalDebt);
    uint256 optimalUsageRatioRay = rateData.optimalUsageRatio.bpsToRay();

    if (usageRatioRay <= optimalUsageRatioRay) {
      currentVariableBorrowRateRay += rateData
        .variableRateSlope1
        .bpsToRay()
        .rayMul(usageRatioRay)
        .rayDiv(optimalUsageRatioRay);
    } else {
      currentVariableBorrowRateRay += rateData.variableRateSlope1.bpsToRay();

      currentVariableBorrowRateRay += rateData
        .variableRateSlope2
        .bpsToRay()
        .rayMul(usageRatioRay - optimalUsageRatioRay)
        .rayDiv(WadRayMath.RAY - optimalUsageRatioRay);
    }

    return currentVariableBorrowRateRay;
  }
}
