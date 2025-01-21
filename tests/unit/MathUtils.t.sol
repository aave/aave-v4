// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';

contract MathUtilsTest is BaseTest {
  using WadRayMath for uint256;

  struct Set {
    uint256[] keys;
    mapping(uint256 key => bool seen) contains;
  }
  Set internal toRemoveSet;

  /// forge-config: ci.fuzz.runs = 10000
  function test_fuzz_WeightedAverageAdd(uint256[] memory numbers) public {
    // base case limits, type(uint128).max ~ 1e38
    _runWeightedAverageAdd(numbers, 1e38, 100_00);
    _runWeightedAverageAdd(numbers, 1e48, 100_00);
  }

  /// forge-config: ci.fuzz.runs = 10000
  function test_fuzz_WeightedAverageRemoveMultiple(
    uint256[] memory numbers,
    uint256[] memory toRemoveIndexes
  ) public {
    // base case limits, type(uint128).max ~ 1e38
    _runWeightedAverageRemove(numbers, toRemoveIndexes, 1e38, 100_00);
    _runWeightedAverageRemove(numbers, toRemoveIndexes, 1e48, 100_00);
  }

  /// forge-config: ci.fuzz.runs = 10000
  function test_fuzz_WeightedAverageRemoveSingle(
    uint256[] memory numbers,
    uint256 toRemoveIndex
  ) public {
    uint256[] memory toRemoveIndexes = new uint256[](1);
    toRemoveIndexes[0] = toRemoveIndex;
    // base case limits, type(uint128).max ~ 1e38
    _runWeightedAverageRemove(numbers, toRemoveIndexes, 1e38, 100_00);
    _runWeightedAverageRemove(numbers, toRemoveIndexes, 1e48, 100_00);
  }

  function test_fuzz_Revert_WeightedAverageRemoveInvalidWeightedValue(
    uint256[] memory numbers
  ) public {
    (uint256 currentWeightedAvgRad, uint256 currentSumWeights) = _runWeightedAverageAdd(
      numbers,
      1e48,
      100_00
    );

    for (uint256 i; i < numbers.length; ++i) {
      uint256 maxNumber;
      uint256 maxWeight;
      for (uint256 j = i; j < numbers.length; ++j) {
        maxNumber = _max(maxNumber, numbers[j] % 1e48);
        maxWeight = _max(maxWeight, numbers[j] % 100_00);
      }

      vm.expectRevert();
      MathUtils.subtractFromWeightedAverage(
        currentWeightedAvgRad,
        currentSumWeights,
        maxNumber + 1,
        maxWeight + 1
      );

      uint256 number = numbers[i] % 1e48;
      uint256 weight = numbers[i] % 100_00;

      (currentWeightedAvgRad, currentSumWeights) = MathUtils.subtractFromWeightedAverage(
        currentWeightedAvgRad,
        currentSumWeights,
        number,
        weight
      );
    }
  }

  function _runWeightedAverageAdd(
    uint256[] memory numbers,
    uint256 maxNumber,
    uint256 maxWeight
  ) public returns (uint256, uint256) {
    vm.assume(numbers.length > 0);

    uint256 currentSumWeights;
    uint256 currentWeightedAvgRad;

    uint256 calcWeightedAvg;
    uint256 calcSumWeights;
    uint256 number;
    uint256 weight;

    for (uint256 i; i < numbers.length; ++i) {
      // truncate
      number = (numbers[i] % maxNumber).toRad(); // add precision before
      weight = numbers[i] % maxWeight;

      calcWeightedAvg += number * weight;
      calcSumWeights += weight;

      (currentWeightedAvgRad, currentSumWeights) = MathUtils.addToWeightedAverage(
        currentWeightedAvgRad,
        currentSumWeights,
        number,
        weight
      );
    }
    if (calcSumWeights != 0) {
      calcWeightedAvg /= calcSumWeights;
    }

    assertApproxEqAbs(currentWeightedAvgRad.fromRad(), calcWeightedAvg.fromRad(), 1);
    assertEq(currentSumWeights, calcSumWeights);

    return (currentWeightedAvgRad, currentSumWeights);
  }

  function _runWeightedAverageRemove(
    uint256[] memory numbers,
    uint256[] memory toRemoveIndexes,
    uint256 maxNumber,
    uint256 maxWeight
  ) public {
    vm.assume(numbers.length > 1);

    for (uint256 i; i < _min(numbers.length, toRemoveIndexes.length); ++i) {
      uint256 key = bound(toRemoveIndexes[i], 0, numbers.length - 1);
      if (!toRemoveSet.contains[key]) {
        // toRemoveSet is not persisted between runs
        toRemoveSet.keys.push(key);
        toRemoveSet.contains[key] = true;
      }
    }

    uint256 currentSumWeights;
    uint256 currentWeightedAvgRad;

    uint256 calcWeightedAvg;
    uint256 calcSumWeights;

    for (uint256 i; i < numbers.length; ++i) {
      // truncate
      uint256 number = (numbers[i] % maxNumber).toRad(); // add precision before
      uint256 weight = numbers[i] % maxWeight;

      if (!toRemoveSet.contains[i]) {
        calcWeightedAvg += number * weight;
        calcSumWeights += weight;
      }

      (currentWeightedAvgRad, currentSumWeights) = MathUtils.addToWeightedAverage(
        currentWeightedAvgRad,
        currentSumWeights,
        number,
        weight
      );
    }

    if (calcSumWeights != 0) {
      calcWeightedAvg /= calcSumWeights;
    }

    for (uint256 i; i < toRemoveSet.keys.length; ++i) {
      uint256 newValue = (numbers[toRemoveSet.keys[i]] % maxNumber).toRad(); // add precision before
      uint256 newValueWeight = numbers[toRemoveSet.keys[i]] % maxWeight;

      // overflow not possible
      if (currentWeightedAvgRad * currentSumWeights < (newValue * newValueWeight).toRad()) {
        vm.expectRevert();
        MathUtils.subtractFromWeightedAverage(
          currentWeightedAvgRad,
          currentSumWeights,
          newValue,
          newValueWeight
        );
      } else {
        (currentWeightedAvgRad, currentSumWeights) = MathUtils.subtractFromWeightedAverage(
          currentWeightedAvgRad,
          currentSumWeights,
          newValue,
          newValueWeight
        );
      }
    }

    assertApproxEqAbs(currentWeightedAvgRad.fromRad(), calcWeightedAvg.fromRad(), 2);
    assertEq(currentSumWeights, calcSumWeights);
  }

  function _min(uint256 a, uint256 b) private pure returns (uint256) {
    return a < b ? a : b;
  }

  function _max(uint256 a, uint256 b) private pure returns (uint256) {
    return a > b ? a : b;
  }
}
