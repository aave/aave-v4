// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {PackedInterestRateData} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {InterestRateDataMapWrapper} from 'tests/mocks/InterestRateDataMapWrapper.sol';

contract InterestRateDataMapTests is Test {
  uint256 internal constant OPTIMAL_USAGE_RATIO_MASK = 0xFFFF;
  uint256 internal constant BASE_VARIABLE_BORROW_RATE_MASK = 0xFFFFFFFF;
  uint256 internal constant VARIABLE_RATE_SLOPE1_MASK = 0xFFFFFFFF;
  uint256 internal constant VARIABLE_RATE_SLOPE2_MASK = 0xFFFFFFFF;

  uint256 internal constant OPTIMAL_USAGE_RATIO_OFFSET = 0;
  uint256 internal constant BASE_VARIABLE_BORROW_RATE_OFFSET = 16;
  uint256 internal constant VARIABLE_RATE_SLOPE1_OFFSET = 48;
  uint256 internal constant VARIABLE_RATE_SLOPE2_OFFSET = 80;

  /// @dev All valid bits combined.
  uint256 internal constant ALL_FIELDS_MASK =
    (OPTIMAL_USAGE_RATIO_MASK << OPTIMAL_USAGE_RATIO_OFFSET) |
      (BASE_VARIABLE_BORROW_RATE_MASK << BASE_VARIABLE_BORROW_RATE_OFFSET) |
      (VARIABLE_RATE_SLOPE1_MASK << VARIABLE_RATE_SLOPE1_OFFSET) |
      (VARIABLE_RATE_SLOPE2_MASK << VARIABLE_RATE_SLOPE2_OFFSET);

  InterestRateDataMapWrapper internal w;

  function setUp() public {
    w = new InterestRateDataMapWrapper();
  }

  function test_constants() public view {
    assertEq(w.OPTIMAL_USAGE_RATIO_MASK(), OPTIMAL_USAGE_RATIO_MASK);
    assertEq(w.BASE_VARIABLE_BORROW_RATE_MASK(), BASE_VARIABLE_BORROW_RATE_MASK);
    assertEq(w.VARIABLE_RATE_SLOPE1_MASK(), VARIABLE_RATE_SLOPE1_MASK);
    assertEq(w.VARIABLE_RATE_SLOPE2_MASK(), VARIABLE_RATE_SLOPE2_MASK);
    assertEq(w.OPTIMAL_USAGE_RATIO_OFFSET(), OPTIMAL_USAGE_RATIO_OFFSET);
    assertEq(w.BASE_VARIABLE_BORROW_RATE_OFFSET(), BASE_VARIABLE_BORROW_RATE_OFFSET);
    assertEq(w.VARIABLE_RATE_SLOPE1_OFFSET(), VARIABLE_RATE_SLOPE1_OFFSET);
    assertEq(w.VARIABLE_RATE_SLOPE2_OFFSET(), VARIABLE_RATE_SLOPE2_OFFSET);
  }

  function test_create_fuzz(
    uint16 optimalUsageRatio,
    uint32 baseVariableBorrowRate,
    uint32 variableRateSlope1,
    uint32 variableRateSlope2
  ) public view {
    PackedInterestRateData data = w.create(
      optimalUsageRatio,
      baseVariableBorrowRate,
      variableRateSlope1,
      variableRateSlope2
    );

    assertEq(w.optimalUsageRatio(data), optimalUsageRatio);
    assertEq(w.baseVariableBorrowRate(data), baseVariableBorrowRate);
    assertEq(w.variableRateSlope1(data), variableRateSlope1);
    assertEq(w.variableRateSlope2(data), variableRateSlope2);
  }

  function test_set_fields() public view {
    PackedInterestRateData data;
    assertEq(w.optimalUsageRatio(data), 0);
    assertEq(w.baseVariableBorrowRate(data), 0);
    assertEq(w.variableRateSlope1(data), 0);
    assertEq(w.variableRateSlope2(data), 0);

    data = w.setOptimalUsageRatio(data, 80_00);
    assertEq(w.optimalUsageRatio(data), 80_00);
    assertEq(w.baseVariableBorrowRate(data), 0);
    assertEq(w.variableRateSlope1(data), 0);
    assertEq(w.variableRateSlope2(data), 0);

    data = w.setBaseVariableBorrowRate(data, 2_00);
    assertEq(w.optimalUsageRatio(data), 80_00);
    assertEq(w.baseVariableBorrowRate(data), 2_00);
    assertEq(w.variableRateSlope1(data), 0);
    assertEq(w.variableRateSlope2(data), 0);

    data = w.setVariableRateSlope1(data, 4_00);
    assertEq(w.optimalUsageRatio(data), 80_00);
    assertEq(w.baseVariableBorrowRate(data), 2_00);
    assertEq(w.variableRateSlope1(data), 4_00);
    assertEq(w.variableRateSlope2(data), 0);

    data = w.setVariableRateSlope2(data, 75_00);
    assertEq(w.optimalUsageRatio(data), 80_00);
    assertEq(w.baseVariableBorrowRate(data), 2_00);
    assertEq(w.variableRateSlope1(data), 4_00);
    assertEq(w.variableRateSlope2(data), 75_00);

    // Overwrite individual fields without affecting others
    data = w.setVariableRateSlope1(data, 10_00);
    assertEq(w.optimalUsageRatio(data), 80_00);
    assertEq(w.baseVariableBorrowRate(data), 2_00);
    assertEq(w.variableRateSlope1(data), 10_00);
    assertEq(w.variableRateSlope2(data), 75_00);

    data = w.setOptimalUsageRatio(data, 50_00);
    assertEq(w.optimalUsageRatio(data), 50_00);
    assertEq(w.baseVariableBorrowRate(data), 2_00);
    assertEq(w.variableRateSlope1(data), 10_00);
    assertEq(w.variableRateSlope2(data), 75_00);
  }

  function test_setOptimalUsageRatio_fuzz(uint256 rawPacked) public view {
    PackedInterestRateData data = _sanitize(rawPacked);
    uint256 expectedRaw = PackedInterestRateData.unwrap(data);

    uint256 newValue = 90_00;
    expectedRaw =
      (expectedRaw & ~(OPTIMAL_USAGE_RATIO_MASK << OPTIMAL_USAGE_RATIO_OFFSET)) |
      (newValue << OPTIMAL_USAGE_RATIO_OFFSET);

    data = w.setOptimalUsageRatio(data, newValue);

    assertEq(w.optimalUsageRatio(data), newValue);
    assertEq(PackedInterestRateData.unwrap(data), expectedRaw);
  }

  function test_setBaseVariableBorrowRate_fuzz(uint256 rawPacked) public view {
    PackedInterestRateData data = _sanitize(rawPacked);
    uint256 expectedRaw = PackedInterestRateData.unwrap(data);

    uint256 newValue = 5_00;
    expectedRaw =
      (expectedRaw & ~(BASE_VARIABLE_BORROW_RATE_MASK << BASE_VARIABLE_BORROW_RATE_OFFSET)) |
      (newValue << BASE_VARIABLE_BORROW_RATE_OFFSET);

    data = w.setBaseVariableBorrowRate(data, newValue);

    assertEq(w.baseVariableBorrowRate(data), newValue);
    assertEq(PackedInterestRateData.unwrap(data), expectedRaw);
  }

  function test_setVariableRateSlope1_fuzz(uint256 rawPacked) public view {
    PackedInterestRateData data = _sanitize(rawPacked);
    uint256 expectedRaw = PackedInterestRateData.unwrap(data);

    uint256 newValue = 12_00;
    expectedRaw =
      (expectedRaw & ~(VARIABLE_RATE_SLOPE1_MASK << VARIABLE_RATE_SLOPE1_OFFSET)) |
      (newValue << VARIABLE_RATE_SLOPE1_OFFSET);

    data = w.setVariableRateSlope1(data, newValue);

    assertEq(w.variableRateSlope1(data), newValue);
    assertEq(PackedInterestRateData.unwrap(data), expectedRaw);
  }

  function test_setVariableRateSlope2_fuzz(uint256 rawPacked) public view {
    PackedInterestRateData data = _sanitize(rawPacked);
    uint256 expectedRaw = PackedInterestRateData.unwrap(data);

    uint256 newValue = 300_00;
    expectedRaw =
      (expectedRaw & ~(VARIABLE_RATE_SLOPE2_MASK << VARIABLE_RATE_SLOPE2_OFFSET)) |
      (newValue << VARIABLE_RATE_SLOPE2_OFFSET);

    data = w.setVariableRateSlope2(data, newValue);

    assertEq(w.variableRateSlope2(data), newValue);
    assertEq(PackedInterestRateData.unwrap(data), expectedRaw);
  }

  /// @dev Sanitizes raw packed value by masking out irrelevant bits.
  function _sanitize(uint256 rawPacked) internal pure returns (PackedInterestRateData) {
    return PackedInterestRateData.wrap(rawPacked & ALL_FIELDS_MASK);
  }
}
