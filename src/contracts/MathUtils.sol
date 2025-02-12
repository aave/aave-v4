// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {WadRayMath} from './WadRayMath.sol';

/**
 * @title MathUtils library
 * @author Aave
 * @notice Provides functions to perform linear and compounded interest calculations
 */
library MathUtils {
  using WadRayMath for uint256;

  /// @dev Ignoring leap years
  uint256 internal constant SECONDS_PER_YEAR = 365 days;

  /**
   * @dev Function to calculate the interest accumulated using a linear interest rate formula
   * @param rate The interest rate, in ray
   * @param lastUpdateTimestamp The timestamp of the last update of the interest
   * @return The interest rate linearly accumulated during the timeDelta, in ray
   */
  function calculateLinearInterest(
    uint256 rate,
    uint40 lastUpdateTimestamp
  ) internal view returns (uint256) {
    //solium-disable-next-line
    uint256 result = rate * (block.timestamp - uint256(lastUpdateTimestamp));
    unchecked {
      result = result / SECONDS_PER_YEAR;
    }

    return WadRayMath.RAY + result;
  }

  /**
   * @dev Function to calculate the interest using a compounded interest rate formula
   * To avoid expensive exponentiation, the calculation is performed using a binomial approximation:
   *
   *  (1+x)^n = 1+n*x+[n/2*(n-1)]*x^2+[n/6*(n-1)*(n-2)*x^3...
   *
   * The approximation slightly underpays liquidity providers and undercharges borrowers, with the advantage of great
   * gas cost reductions. The whitepaper contains reference to the approximation and a table showing the margin of
   * error per different time periods
   *
   * @param rate The interest rate, in ray
   * @param lastUpdateTimestamp The timestamp of the last update of the interest
   * @return The interest rate compounded during the timeDelta, in ray
   */
  function calculateCompoundedInterest(
    uint256 rate,
    uint40 lastUpdateTimestamp,
    uint256 currentTimestamp
  ) internal pure returns (uint256) {
    //solium-disable-next-line
    uint256 exp = currentTimestamp - uint256(lastUpdateTimestamp);

    if (exp == 0) {
      return WadRayMath.RAY;
    }

    uint256 expMinusOne;
    uint256 expMinusTwo;
    uint256 basePowerTwo;
    uint256 basePowerThree;
    unchecked {
      expMinusOne = exp - 1;

      expMinusTwo = exp > 2 ? exp - 2 : 0;

      basePowerTwo = rate.rayMul(rate) / (SECONDS_PER_YEAR * SECONDS_PER_YEAR);
      basePowerThree = basePowerTwo.rayMul(rate) / SECONDS_PER_YEAR;
    }

    uint256 secondTerm = exp * expMinusOne * basePowerTwo;
    unchecked {
      secondTerm /= 2;
    }
    uint256 thirdTerm = exp * expMinusOne * expMinusTwo * basePowerThree;
    unchecked {
      thirdTerm /= 6;
    }

    return WadRayMath.RAY + (rate * exp) / SECONDS_PER_YEAR + secondTerm + thirdTerm;
  }

  /**
   * @dev Calculates the compounded interest between the timestamp of the last update and the current block timestamp
   * @param rate The interest rate (in ray)
   * @param lastUpdateTimestamp The timestamp from which the interest accumulation needs to be calculated
   * @return The interest rate compounded between lastUpdateTimestamp and current block timestamp, in ray
   */
  function calculateCompoundedInterest(
    uint256 rate,
    uint40 lastUpdateTimestamp
  ) internal view returns (uint256) {
    return calculateCompoundedInterest(rate, lastUpdateTimestamp, block.timestamp);
  }

  /**
   * @notice Calculates the new weighted average given a current weighted average, the sum of the weights subtracted with a new value, weight
   * @param currentWeightedAvgRad The base weighted average (in Rad)
   * @param currentSumWeights The base sum of weights
   * @param newValue The new value to add or subtract
   * @param newValueWeight The weight of the new value
   * @return newWeightedAvgRad The weighted average after the operation (in Rad)
   * @return newSumWeights The sum of weights after operation, cannot be less than 0
   */
  function addToWeightedAverage(
    uint256 currentWeightedAvgRad,
    uint256 currentSumWeights,
    uint256 newValue,
    uint256 newValueWeight
  ) internal pure returns (uint256, uint256) {
    // newWeightedAvgRad, newSumWeights

    if (newValueWeight == 0) {
      return (currentWeightedAvgRad, currentSumWeights);
    }
    // this is the first time we add, radify new average
    if (currentSumWeights == 0) {
      return (newValue.toRad(), newValueWeight);
    }

    uint256 newSumWeights = currentSumWeights + newValueWeight;
    uint256 newWeightedAvgRad = (currentWeightedAvgRad *
      currentSumWeights +
      (newValue * newValueWeight).toRad()) / newSumWeights; // newSumWeights cannot be zero when execution reaches here

    return (newWeightedAvgRad, newSumWeights);
  }

  /**
   * @notice Calculates the new weighted average given a current weighted average, the sum of the weights added with a new value, weight
   * @param currentWeightedAvgRad The base weighted average (in Rad)
   * @param currentSumWeights The base sum of weights
   * @param newValue The new value to add or subtract
   * @param newValueWeight The weight of the new value
   * @return newWeightedAvgRad The weighted average after the operation (in Rad)
   * @return newSumWeights The sum of weights after operation, cannot be less than 0
   * @dev Reverts when newValueWeight is greater than currentSumWeights
   * @dev Reverts when the newWeightedValue (weight * value) is greater than currentWeightedSum (currentSumWeights * currentWeightedAvg)
   */
  function subtractFromWeightedAverage(
    uint256 currentWeightedAvgRad,
    uint256 currentSumWeights,
    uint256 newValue,
    uint256 newValueWeight
  ) internal pure returns (uint256, uint256) {
    // newWeightedAvgRad, newSumWeights
    if (newValueWeight == 0) return (currentWeightedAvgRad, currentSumWeights);

    if (currentSumWeights == newValueWeight) return (0, 0); // no change
    if (currentSumWeights < newValueWeight) revert();

    uint256 newWeightedValueRad = (newValue * newValueWeight).toRad();
    uint256 currentWeightedSumRad = currentWeightedAvgRad * currentSumWeights;

    if (currentWeightedSumRad < newWeightedValueRad) revert();

    uint256 newSumWeights = currentSumWeights - newValueWeight;
    uint256 newWeightedAvgRad = (currentWeightedSumRad - newWeightedValueRad) / newSumWeights;

    return (newWeightedAvgRad, newSumWeights);
  }
}
