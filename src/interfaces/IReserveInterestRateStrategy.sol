// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {DataTypes} from '../libraries/types/DataTypes.sol';

/**
 * @title IReserveInterestRateStrategy
 * @author Aave Labs
 * @notice Basic interface for any rate strategy used by the Aave protocol
 */
interface IReserveInterestRateStrategy {
  /**
   * @notice Calculates the interest rate depending on the reserve's state and configurations
   * @param params The parameters needed to calculate interest rate
   * @return variableBorrowRate The variable borrow rate expressed in ray
   */
  function calculateInterestRate(
    DataTypes.CalculateInterestRateParams memory params
  ) external view returns (uint256);
}
