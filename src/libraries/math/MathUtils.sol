// SPDX-License-Identifier: MIT
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
   * @dev Function to calculate the interest accumulated using a linear interest rate formula.
   * @param rate The interest rate, in ray.
   * @param lastUpdateTimestamp The timestamp of the last update of the interest.
   * @return The interest rate linearly accumulated during the timeDelta, in ray.
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
   * @notice Calculates the new weighted average given a current weighted average, the sum of the weights subtracted with a new value, weight.
   * @dev Add precision to weighted average & new value before calling this method.
   * @param currentWeightedAvg The base weighted average.
   * @param currentSumWeights The base sum of weights.
   * @param newValue The new value to add or subtract.
   * @param newValueWeight The weight of the new value.
   * @return newWeightedAvg The weighted average after the operation.
   * @return newSumWeights The sum of weights after operation, cannot be less than 0.
   */
  function addToWeightedAverage(
    uint256 currentWeightedAvg,
    uint256 currentSumWeights,
    uint256 newValue,
    uint256 newValueWeight
  ) internal pure returns (uint256, uint256) {
    // newWeightedAvg, newSumWeights

    if (newValueWeight == 0) {
      return (currentWeightedAvg, currentSumWeights);
    }
    if (currentSumWeights == 0) {
      return (newValue, newValueWeight);
    }

    uint256 newSumWeights = currentSumWeights + newValueWeight;
    uint256 newWeightedAvg = ((currentWeightedAvg * currentSumWeights) +
      (newValue * newValueWeight)) / newSumWeights; // newSumWeights cannot be zero when execution reaches here

    return (newWeightedAvg, newSumWeights);
  }

  /**
   * @notice Calculates the new weighted average given a current weighted average, the sum of the weights added with a new value, weight.
   * @dev Add precision to weighted average & new value before calling this method.
   * @param currentWeightedAvg The base weighted average.
   * @param currentSumWeights The base sum of weights.
   * @param newValue The new value to add or subtract.
   * @param newValueWeight The weight of the new value.
   * @return newWeightedAvg The weighted average after the operation.
   * @return newSumWeights The sum of weights after operation, cannot be less than 0.
   * @dev Reverts when newValueWeight is greater than currentSumWeights.
   * @dev Reverts when the newWeightedValue (weight * value) is greater than currentWeightedSum (currentSumWeights * currentWeightedAvg).
   */
  function subtractFromWeightedAverage(
    uint256 currentWeightedAvg,
    uint256 currentSumWeights,
    uint256 newValue,
    uint256 newValueWeight
  ) internal pure returns (uint256, uint256) {
    // newWeightedAvg, newSumWeights
    if (newValueWeight == 0) return (currentWeightedAvg, currentSumWeights);

    if (currentSumWeights == newValueWeight) return (0, 0); // no change
    if (currentSumWeights < newValueWeight) revert();

    uint256 newWeightedValue = newValue * newValueWeight;
    uint256 currentWeightedSum = currentWeightedAvg * currentSumWeights;

    if (currentWeightedSum < newWeightedValue) revert();

    uint256 newSumWeights = currentSumWeights - newValueWeight;
    uint256 newWeightedAvg = (currentWeightedSum - newWeightedValue) / newSumWeights;

    return (newWeightedAvg, newSumWeights);
  }

  /**
   * @notice Returns the minimum of two values.
   * @param a The first value to compare.
   * @param b The second value to compare.
   * @return result The minimum of the two values.
   */
  function min(uint256 a, uint256 b) internal pure returns (uint256 result) {
    assembly {
      result := xor(b, mul(xor(a, b), lt(a, b)))
    }
  }
}
