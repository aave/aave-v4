// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IERC20} from '../dependencies/openzeppelin/IERC20.sol';
import {DataTypes} from '../libraries/types/DataTypes.sol';
import {Errors} from '../libraries/helpers/Errors.sol';
import {IDefaultInterestRateStrategy} from '../interfaces/IDefaultInterestRateStrategy.sol';
import {IReserveInterestRateStrategy} from '../interfaces/IReserveInterestRateStrategy.sol';

/**
 * @title DefaultReserveInterestRateStrategy contract
 * @author Aave Labs
 * @notice Default interest rate strategy used by the Aave protocol
 * @dev Strategies are pool-specific: each contract CAN'T be used across different Aave pools
 *   due to the caching of the PoolAddressesProvider and the usage of underlying addresses as
 *   index of the _interestRateData
 */
contract DefaultReserveInterestRateStrategy is IDefaultInterestRateStrategy {
  /// @inheritdoc IDefaultInterestRateStrategy
  address public immutable ADDRESSES_PROVIDER;

  /// @inheritdoc IDefaultInterestRateStrategy
  uint256 public constant MAX_BORROW_RATE = 100_00; // 100% in BPS

  /// @inheritdoc IDefaultInterestRateStrategy
  uint256 public constant MIN_OPTIMAL_POINT = 1_00; // 1% in BPS

  /// @inheritdoc IDefaultInterestRateStrategy
  uint256 public constant MAX_OPTIMAL_POINT = 99_00; // 99% in BPS

  /// @dev Map of reserves address and their interest rate data (reserveAddress => interestRateData)
  mapping(address => InterestRateData) internal _interestRateData;

  /**
   * @dev Constructor.
   * @param provider The address of the PoolAddressesProvider of the associated Aave pool
   */
  constructor(address provider) {
    // require(provider != address(0), Errors.INVALID_ADDRESSES_PROVIDER);
    ADDRESSES_PROVIDER = provider;
  }

  /// @inheritdoc IReserveInterestRateStrategy
  function setInterestRateParams(address reserve, bytes calldata rateData) external {
    _setInterestRateParams(reserve, abi.decode(rateData, (InterestRateData)));
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function setInterestRateParams(address reserve, InterestRateData calldata rateData) external {
    _setInterestRateParams(reserve, rateData);
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getInterestRateDataBps(address reserve) external view returns (InterestRateData memory) {
    return _interestRateData[reserve];
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getOptimalUsageRatio(address reserve) external view returns (uint256) {
    return _interestRateData[reserve].optimalUsageRatio;
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getVariableRateSlope1(address reserve) external view returns (uint256) {
    return _interestRateData[reserve].variableRateSlope1;
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getVariableRateSlope2(address reserve) external view returns (uint256) {
    return _interestRateData[reserve].variableRateSlope2;
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getBaseVariableBorrowRate(address reserve) external view override returns (uint256) {
    return _interestRateData[reserve].baseVariableBorrowRate;
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getMaxVariableBorrowRate(address reserve) external view override returns (uint256) {
    return
      _interestRateData[reserve].baseVariableBorrowRate +
      _interestRateData[reserve].variableRateSlope1 +
      _interestRateData[reserve].variableRateSlope2;
  }

  /// @inheritdoc IReserveInterestRateStrategy
  function calculateInterestRates(
    DataTypes.CalculateInterestRatesParams memory params
  ) external view virtual override returns (uint256) {
    InterestRateData memory rateData = _interestRateData[params.reserve];

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
      // calculates borrowRate and supplyRate
      // total debt / (available liquidity + total debt)
      // This is a measure of how much of the total available liquidity in a reserve is currently being used (borrowed).
      // scaling up for bps

      // utilization rate for borrow and supply
      // usage ratio for borrows is
      // always multiply first and then decide. In terms of rounding we are truncating the value
      // multipling to get percentage
      // TODO: evaluate the rounding

      vars.borrowUsageRatio = (vars.totalDebt * 10000) / vars.availableLiquidityPlusDebt;
      vars.supplyUsageRatio = (vars.totalDebt * 10000) / vars.availableLiquidityPlusDebt;
    } else {
      return (vars.currentVariableBorrowRate);
    }

    if (vars.borrowUsageRatio > rateData.optimalUsageRatio) {
      uint256 excessBorrowUsageRatio = ((vars.borrowUsageRatio - rateData.optimalUsageRatio) *
        10000) / rateData.optimalUsageRatio;

      vars.currentVariableBorrowRate +=
        ((rateData.variableRateSlope1 + rateData.variableRateSlope2) * excessBorrowUsageRatio) /
        10000;

      return vars.currentVariableBorrowRate;
    } else {
      //  base + (current / optimal ) * slope1
      //  2%+( 80% / 60% )×5%
      // base borrow rate + (utilization rate * slope1) / optimal utilization rate
      // All in BPS --> so will receive BPS
      vars.currentVariableBorrowRate +=
        (vars.borrowUsageRatio * rateData.variableRateSlope1) /
        rateData.optimalUsageRatio;
      return (vars.currentVariableBorrowRate);
    }
  }

  /**
   * @dev Doing validations and data update for an asset
   * @param reserve address of the underlying asset of the reserve
   * @param rateData Encoded reserve interest rate data to apply
   */
  function _setInterestRateParams(address reserve, InterestRateData memory rateData) internal {
    require(reserve != address(0), Errors.ZERO_ADDRESS_NOT_VALID);

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

    _interestRateData[reserve] = rateData;
    emit RateDataUpdate(
      reserve,
      rateData.optimalUsageRatio,
      rateData.baseVariableBorrowRate,
      rateData.variableRateSlope1,
      rateData.variableRateSlope2
    );
  }
}
