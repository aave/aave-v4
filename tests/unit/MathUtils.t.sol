// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';

/// forge-config: default.allow_internal_expect_revert = true
contract MathUtilsWeightedAverage is Test {
  using WadRayMath for uint256;

  using EnumerableSet for EnumerableSet.UintSet;
  EnumerableSet.UintSet internal toRemoveSet;

  struct Bound {
    uint256 maxValue;
    uint256 maxWeight;
    uint256 maxIterations;
    // additional added precision multiplier only to value to reduce rounding precision loss
    uint256 precision;
  }
  Bound[] internal bounds;

  function setUp() public {
    bounds.push(
      Bound({maxValue: 1e4, maxWeight: 1e30, maxIterations: 1e9, precision: WadRayMath.RAY})
    );

    _validateBounds();
  }

  function test_fuzz_WeightedAverageAdd(uint256[] memory numbers) public {
    for (uint256 i; i < bounds.length; ++i) {
      (uint256[] memory values, uint256[] memory weights) = _boundAndSplitArray(numbers, bounds[i]);
      _runWeightedAverageAdd({values: values, weights: weights, precision: bounds[i].precision});
    }
  }

  function test_fuzz_WeightedAverageRemoveSingle(
    uint256[] memory numbers,
    uint256 toRemoveIndex
  ) public {
    uint256[] memory toRemoveIndexes = new uint256[](1);
    toRemoveIndexes[0] = toRemoveIndex;
    for (uint256 i; i < bounds.length; ++i) {
      (uint256[] memory values, uint256[] memory weights) = _boundAndSplitArray(numbers, bounds[i]);
      // populates `toRemoveSet` in storage (not persisted between runs)
      _toSet(toRemoveIndexes, _min(values.length, bounds[i].maxIterations));
      _runWeightedAverageRemove({values: values, weights: weights, precision: bounds[i].precision});
    }
  }

  function test_fuzz_WeightedAverageRemoveMultiple(
    uint256[] memory numbers,
    uint256[] memory toRemoveIndexes
  ) public {
    for (uint256 i; i < bounds.length; ++i) {
      (uint256[] memory values, uint256[] memory weights) = _boundAndSplitArray(numbers, bounds[i]);
      // populates `toRemoveSet` in storage (not persisted between runs)
      _toSet(toRemoveIndexes, _min(values.length, bounds[i].maxIterations));
      _runWeightedAverageRemove({values: values, weights: weights, precision: bounds[i].precision});
    }
  }

  function test_fuzz_WeightedAverageRemoveMultiplePotentiallyAll(
    uint256[] memory numbers,
    uint256[] memory toRemoveIndexes
  ) public {
    for (uint256 i; i < bounds.length; ++i) {
      (uint256[] memory values, uint256[] memory weights) = _boundAndSplitArray(numbers, bounds[i]);
      // populates `toRemoveSet` in storage (not persisted between runs)
      _toSetWithoutDuplicates(toRemoveIndexes, _min(values.length, bounds[i].maxIterations));
      _runWeightedAverageRemove({values: values, weights: weights, precision: bounds[i].precision});
    }
  }

  function test_fuzz_Revert_WeightedAverageRemoveInvalidWeightedValue(
    uint256[] memory numbers
  ) public {
    for (uint256 i; i < bounds.length; ++i) {
      (uint256[] memory values, uint256[] memory weights) = _boundAndSplitArray(numbers, bounds[i]);
      _runWeightedAverageRemoveInvalidWeightedValue({
        values: values,
        weights: weights,
        precision: bounds[i].precision
      });
    }
  }

  function test_fuzz_WeightedAverageRemoveAlternateValues(uint256[] memory numbers) public {
    for (uint256 i; i < bounds.length; ++i) {
      (uint256[] memory values, uint256[] memory weights) = _boundAndSplitArray(numbers, bounds[i]);
      _runWeightedAverageRemoveAlternateValues({
        values: values,
        weights: weights,
        precision: bounds[i].precision
      });
    }
  }

  function test_min_fuzz(uint256 a, uint256 b) public {
    uint256 expectedMin = _min(a, b);
    uint256 min = MathUtils.min(a, b);
    assertEq(min, expectedMin, 'min');
  }

  function _runWeightedAverageRemoveInvalidWeightedValue(
    uint256[] memory values,
    uint256[] memory weights,
    uint256 precision
  ) internal {
    (uint256 currentWeightedAvg, uint256 currentSumWeights) = _runWeightedAverageAdd(
      values,
      weights,
      precision
    );

    for (uint256 i; i < values.length; ++i) {
      uint256 maxValue;
      uint256 maxWeight;
      for (uint256 j = i; j < values.length; ++j) {
        maxValue = _max(maxValue, values[j]);
        maxWeight = _max(maxWeight, weights[j]);
      }

      vm.expectRevert();
      MathUtils.subtractFromWeightedAverage(
        currentWeightedAvg,
        currentSumWeights,
        maxValue + 1,
        maxWeight + 1
      );

      (currentWeightedAvg, currentSumWeights) = MathUtils.subtractFromWeightedAverage(
        currentWeightedAvg,
        currentSumWeights,
        values[i],
        weights[i]
      );
    }
  }

  function _runWeightedAverageRemoveAlternateValues(
    uint256[] memory values,
    uint256[] memory weights,
    uint256 precision
  ) internal {
    _resetToRemoveSet();
    uint256 length;
    assertEq((length = values.length), weights.length);
    uint256 currentSumWeights;
    uint256 currentWeightedAvg;

    uint256 calcWeightedAvg;
    uint256 calcSumWeights;

    uint256 counter;
    // roughly every 10 iterations, we remove a value
    uint256 interval = vm.randomUint() % 10;

    for (uint256 i; i < length; ++i) {
      if (i > 0 && ++counter == interval) {
        // remove a random value added so far
        uint256 toRemoveIndex = _getRandomUnseenInRange(i);
        toRemoveSet.add(toRemoveIndex);

        uint256 newValue = values[toRemoveIndex];
        uint256 newWeight = weights[toRemoveIndex];

        (currentWeightedAvg, currentSumWeights) = MathUtils.subtractFromWeightedAverage(
          currentWeightedAvg,
          currentSumWeights,
          newValue,
          newWeight
        );

        calcWeightedAvg -= (newValue / precision) * newWeight;
        calcSumWeights -= newWeight;

        assertEq(currentSumWeights, calcSumWeights);
        if (calcSumWeights != 0) {
          assertApproxEqAbs(
            (currentWeightedAvg / precision),
            (calcWeightedAvg / calcSumWeights),
            1
          );
        }
      }

      uint256 value = values[i];
      uint256 weight = weights[i];

      calcWeightedAvg += (value / precision) * weight;
      calcSumWeights += weight;

      (currentWeightedAvg, currentSumWeights) = MathUtils.addToWeightedAverage(
        currentWeightedAvg,
        currentSumWeights,
        value,
        weight
      );
    }
    if (calcSumWeights != 0) {
      calcWeightedAvg /= calcSumWeights;
    }

    assertEq(currentSumWeights, calcSumWeights);
    assertApproxEqAbs((currentWeightedAvg / precision), calcWeightedAvg, 1);
  }

  function _runWeightedAverageAdd(
    uint256[] memory values,
    uint256[] memory weights,
    uint256 precision
  ) public pure returns (uint256, uint256) {
    uint256 length;
    assertEq((length = values.length), weights.length);
    uint256 currentSumWeights;
    uint256 currentWeightedAvg;

    uint256 calcWeightedAvg;
    uint256 calcSumWeights;

    for (uint256 i; i < length; ++i) {
      uint256 value = values[i];
      uint256 weight = weights[i];

      calcWeightedAvg += (value / precision) * weight;
      calcSumWeights += weight;

      (currentWeightedAvg, currentSumWeights) = MathUtils.addToWeightedAverage(
        currentWeightedAvg,
        currentSumWeights,
        value,
        weight
      );
    }
    if (calcSumWeights != 0) {
      calcWeightedAvg /= calcSumWeights;
    }

    assertEq(currentSumWeights, calcSumWeights);
    assertApproxEqAbs((currentWeightedAvg / precision), calcWeightedAvg, 1);

    return (currentWeightedAvg, currentSumWeights);
  }

  function _runWeightedAverageRemove(
    uint256[] memory values,
    uint256[] memory weights,
    uint256 precision
  ) public {
    uint256 length;
    assertEq((length = values.length), weights.length);

    (uint256 currentWeightedAvg, uint256 currentSumWeights) = _runWeightedAverageAdd(
      values,
      weights,
      precision
    );

    uint256 calcWeightedAvg;
    uint256 calcSumWeights;

    for (uint256 i; i < values.length; ++i) {
      if (!toRemoveSet.contains(i)) {
        calcWeightedAvg += (values[i] / precision) * weights[i];
        calcSumWeights += weights[i];
      }
    }

    if (calcSumWeights != 0) {
      calcWeightedAvg /= calcSumWeights;
    }

    for (uint256 i; i < toRemoveSet.length(); ++i) {
      uint256 newValue = values[toRemoveSet.at(i)];
      uint256 newWeight = weights[toRemoveSet.at(i)];

      // overflow not possible
      if (currentWeightedAvg * currentSumWeights < (newValue * newWeight)) {
        vm.expectRevert();
        MathUtils.subtractFromWeightedAverage(
          currentWeightedAvg,
          currentSumWeights,
          newValue,
          newWeight
        );
      } else {
        (currentWeightedAvg, currentSumWeights) = MathUtils.subtractFromWeightedAverage(
          currentWeightedAvg,
          currentSumWeights,
          newValue,
          newWeight
        );
      }
    }

    assertEq(currentSumWeights, calcSumWeights);
    assertApproxEqAbs(currentWeightedAvg / precision, calcWeightedAvg, 1);
  }

  function _boundAndSplitArray(
    uint256[] memory _numbers,
    Bound memory _bound
  ) internal returns (uint256[] memory, uint256[] memory) {
    // bound.maxIterations is not assumed for performance
    uint256 length = _min(_numbers.length, _bound.maxIterations);
    vm.assume(length > 0);
    uint256[] memory values = new uint256[](length);
    uint256[] memory weights = new uint256[](length);

    // truncate, don't randomize `value` to retain fuzzer's heuristics
    for (uint256 i; i < length; ++i) {
      // add precision before
      values[i] = (_numbers[i] % _bound.maxValue) * _bound.precision;
      // add decimal randomization
      values[i] += (vm.randomUint() % _bound.precision);
      // add pseudo-randomization to `weight`
      weights[i] = (_numbers[i] ^ vm.randomUint()) % _bound.maxWeight;
    }

    // loop over & free memory
    delete _numbers;

    return (values, weights);
  }

  // @dev populates `toRemoveSet` in storage (not persisted between runs)
  function _toSet(uint256[] memory _toRemoveIndexes, uint256 count) internal {
    _resetToRemoveSet();
    assertEq(toRemoveSet.length(), 0);
    for (uint256 i; i < _toRemoveIndexes.length; ++i) {
      toRemoveSet.add(_toRemoveIndexes[i] % count);
    }
  }

  // @dev populates `toRemoveSet` in storage (not persisted between runs) while avoiding duplicate entries,
  // can potentially fill entire domain (of useful indexes)
  function _toSetWithoutDuplicates(uint256[] memory _toRemoveIndexes, uint256 _bound) internal {
    _resetToRemoveSet();
    assertEq(toRemoveSet.length(), 0);
    for (uint256 i; i < _min(_toRemoveIndexes.length, _bound); ++i) {
      while (!toRemoveSet.add(_toRemoveIndexes[i] % _bound)) {
        unchecked {
          _toRemoveIndexes[i]++;
        }
      }
    }
  }

  function _validateBounds() internal view {
    for (uint256 i; i < bounds.length; ++i) {
      Bound memory bound = bounds[i];
      assertLt(
        (bound.maxValue * bound.precision) * bound.maxWeight * bound.maxIterations,
        UINT256_MAX,
        'overflow'
      );
      assertLt(bound.maxWeight, bound.maxValue * bound.precision, 'precision');
    }
  }

  function _resetToRemoveSet() internal {
    uint256[] memory values = toRemoveSet.values();
    for (uint256 i; i < values.length; ++i) {
      toRemoveSet.remove(values[i]);
    }
  }

  function _getRandomUnseenInRange(uint256 limit) internal returns (uint256) {
    uint256 random;
    do {
      random = vm.randomUint() % limit;
    } while (toRemoveSet.contains(random));
    return random;
  }

  function _min(uint256 a, uint256 b) private pure returns (uint256) {
    return a < b ? a : b;
  }

  function _max(uint256 a, uint256 b) private pure returns (uint256) {
    return a > b ? a : b;
  }
}
