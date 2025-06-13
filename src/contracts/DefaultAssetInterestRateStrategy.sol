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
  using WadRayMath for uint256;

  /// @inheritdoc IDefaultInterestRateStrategy
  address public immutable ADDRESSES_PROVIDER;

  /// @inheritdoc IDefaultInterestRateStrategy
  uint32 public constant MAX_BORROW_RATE = 1000_00; // 1000.00% in BPS

  /// @inheritdoc IDefaultInterestRateStrategy
  uint16 public constant MIN_OPTIMAL_POINT = 1_00; // 1.00% in BPS

  /// @inheritdoc IDefaultInterestRateStrategy
  uint16 public constant MAX_OPTIMAL_POINT = 99_00; // 99.00% in BPS

  /// @dev Map of assetId and their interest rate data (assetId => interestRateData)
  mapping(uint256 => InterestRateData) internal _interestRateData;

  /**
   * @dev Constructor.
   * @param provider The address of the PoolAddressesProvider of the associated Aave pool
   */
  constructor(address provider) {
    require(provider != address(0), INVALID_ADDRESSES_PROVIDER());
    ADDRESSES_PROVIDER = provider;
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function setInterestRateParams(uint256 assetId, InterestRateData calldata rateData) external {
    // TODO: Access Control

    require(
      MIN_OPTIMAL_POINT <= rateData.optimalUsageRatio &&
        rateData.optimalUsageRatio <= MAX_OPTIMAL_POINT,
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
  function getOptimalUsageRatio(uint256 assetId) external view returns (uint16) {
    return _interestRateData[assetId].optimalUsageRatio;
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getVariableRateSlope1(uint256 assetId) external view returns (uint32) {
    return _interestRateData[assetId].variableRateSlope1;
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getVariableRateSlope2(uint256 assetId) external view returns (uint32) {
    return _interestRateData[assetId].variableRateSlope2;
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getBaseVariableBorrowRate(uint256 assetId) external view override returns (uint32) {
    return _interestRateData[assetId].baseVariableBorrowRate;
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getMaxVariableBorrowRate(uint256 assetId) external view override returns (uint32) {
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
    require(rateData.optimalUsageRatio != 0, INTEREST_RATE_DATA_NOT_SET());

    uint256 currentVariableBorrowRateRay = _bpsToRay(rateData.baseVariableBorrowRate);
    if (totalDebt == 0) {
      return currentVariableBorrowRateRay;
    }

    uint256 borrowUsageRatioRay = totalDebt.rayDiv(availableLiquidity + totalDebt);
    uint256 optimalUsageRatioRay = _bpsToRay(rateData.optimalUsageRatio);

    if (borrowUsageRatioRay <= optimalUsageRatioRay) {
      currentVariableBorrowRateRay += _bpsToRay(rateData.variableRateSlope1)
        .rayMul(borrowUsageRatioRay)
        .rayDiv(optimalUsageRatioRay);
    } else {
      currentVariableBorrowRateRay += _bpsToRay(rateData.variableRateSlope1);

      currentVariableBorrowRateRay += _bpsToRay(rateData.variableRateSlope2)
        .rayMul(borrowUsageRatioRay - optimalUsageRatioRay)
        .rayDiv(WadRayMath.RAY - optimalUsageRatioRay);
    }

    return currentVariableBorrowRateRay;
  }

  function _bpsToRay(uint32 bps) internal pure returns (uint256) {
    return uint256(bps).bpsToRay();
  }
}
