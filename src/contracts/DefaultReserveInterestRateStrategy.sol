// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {WadRayMath} from './WadRayMath.sol';
import {DataTypes} from '../libraries/types/DataTypes.sol';
import {Errors} from '../libraries/helpers/Errors.sol';
import {IDefaultInterestRateStrategy} from '../interfaces/IDefaultInterestRateStrategy.sol';
import {IReserveInterestRateStrategy} from '../interfaces/IReserveInterestRateStrategy.sol';
import {WadRayMath} from './WadRayMath.sol';

// TODO: update this contract to based on DefaultReserveInterestRateStrategyV2 in aave-v3-origin

/**
 * @title DefaultReserveInterestRateStrategy contract
 * @author Aave Labs
 * @notice Default interest rate strategy used by the Aave protocol
 * @dev Strategies are pool-specific: each contract CAN'T be used across different Aave pools
 *   due to the caching of the PoolAddressesProvider and the usage of underlying addresses as
 *   index of the _interestRateData
 */
contract DefaultReserveInterestRateStrategy is IDefaultInterestRateStrategy {
  using WadRayMath for uint256;

  /// @inheritdoc IDefaultInterestRateStrategy
  address public immutable ADDRESSES_PROVIDER;

  /// @inheritdoc IDefaultInterestRateStrategy
  uint256 public constant MAX_BORROW_RATE = 1000_00; // 1000.00% in BPS

  /// @inheritdoc IDefaultInterestRateStrategy
  uint256 public constant MIN_OPTIMAL_POINT = 1_00; // 1.00% in BPS

  /// @inheritdoc IDefaultInterestRateStrategy
  uint256 public constant MAX_OPTIMAL_POINT = 99_00; // 99.00% in BPS

  /// @dev Map of assetId and their interest rate data (reserveAddress => interestRateData)
  mapping(uint256 => InterestRateData) internal _interestRateData;

  /**
   * @dev Constructor.
   * @param provider The address of the PoolAddressesProvider of the associated Aave pool
   */
  constructor(address provider) {
    // TODO: require(provider != address(0), Errors.INVALID_ADDRESSES_PROVIDER);
    ADDRESSES_PROVIDER = provider;
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function setInterestRateParams(uint256 assetId, InterestRateData calldata rateData) external {
    // TODO: Auth
    // TODO: resolve assetId, currently preventing it from being 0, but it can be equal 0 in LH
    // require(assetId != 0, Errors.INVALID_ASSET_ID);

    require(
      rateData.optimalUsageRatio <= MAX_OPTIMAL_POINT &&
        rateData.optimalUsageRatio >= MIN_OPTIMAL_POINT,
      Errors.INVALID_OPTIMAL_USAGE_RATIO
    );

    require(
      rateData.variableRateSlope1 <= rateData.variableRateSlope2,
      Errors.SLOPE_2_MUST_BE_GTE_SLOPE_1
    );

    // The maximum rate should not be above certain threshold
    require(
      uint256(rateData.baseVariableBorrowRate) +
        uint256(rateData.variableRateSlope1) +
        uint256(rateData.variableRateSlope2) <=
        MAX_BORROW_RATE,
      Errors.INVALID_MAX_RATE
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
  function getVariableRateSlope1(uint256 assetId) external view returns (uint256) {
    return _interestRateData[assetId].variableRateSlope1;
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getVariableRateSlope2(uint256 assetId) external view returns (uint256) {
    return _interestRateData[assetId].variableRateSlope2;
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getBaseVariableBorrowRate(uint256 assetId) external view override returns (uint256) {
    return _interestRateData[assetId].baseVariableBorrowRate;
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getMaxVariableBorrowRate(uint256 assetId) external view override returns (uint256) {
    return
      _interestRateData[assetId].baseVariableBorrowRate +
      _interestRateData[assetId].variableRateSlope1 +
      _interestRateData[assetId].variableRateSlope2;
  }

  /// @inheritdoc IReserveInterestRateStrategy
  function calculateInterestRates(
    DataTypes.CalculateInterestRatesParams memory params
  ) external view virtual override returns (uint256) {
    InterestRateData memory rateData = _interestRateData[params.assetId];

    // TODO need to ensure require(rateData.optimalUsageRatio != 0, Errors.INVALID_OPTIMAL_USAGE_RATIO);
    // because division by 0 occurs in the following code potentially

    // @note This is a short circuit to allow mintable assets (ex. GHO), which by definition cannot be supplied
    // and thus do not use virtual underlying balances.
    if (!params.usingVirtualBalance) {
      return (rateData.baseVariableBorrowRate);
    }

    CalcInterestRatesLocalVars memory vars;

    vars.totalDebt = params.totalDebt;

    vars.currentLiquidityRate = 0;
    vars.currentVariableBorrowRate = rateData.baseVariableBorrowRate;

    if (vars.totalDebt != 0) {
      vars.availableLiquidity =
        params.virtualUnderlyingBalance +
        params.liquidityAdded -
        params.liquidityTaken;

      vars.availableLiquidityPlusDebt = vars.availableLiquidity + vars.totalDebt;
      vars.borrowUsageRatio = (vars.totalDebt * 10000) / vars.availableLiquidityPlusDebt;
    } else {
      return uint256(vars.currentVariableBorrowRate).bpsToRay();
    }

    if (vars.borrowUsageRatio > rateData.optimalUsageRatio) {
      uint256 excessBorrowUsageRatio = ((vars.borrowUsageRatio - rateData.optimalUsageRatio) *
        10000) / rateData.optimalUsageRatio;

      vars.currentVariableBorrowRate +=
        ((rateData.variableRateSlope1 + rateData.variableRateSlope2) * excessBorrowUsageRatio) /
        10000;

      return uint256(vars.currentVariableBorrowRate).bpsToRay();
    } else {
      vars.currentVariableBorrowRate +=
        (vars.borrowUsageRatio * rateData.variableRateSlope1) /
        rateData.optimalUsageRatio;
      return uint256(vars.currentVariableBorrowRate).bpsToRay();
    }
  }
}
