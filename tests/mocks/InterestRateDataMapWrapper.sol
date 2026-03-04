// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {PackedInterestRateData} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {InterestRateDataMap} from 'src/hub/libraries/InterestRateDataMap.sol';

contract InterestRateDataMapWrapper {
  using InterestRateDataMap for PackedInterestRateData;

  function create(
    uint16 optimalUsageRatio_,
    uint32 baseVariableBorrowRate_,
    uint32 variableRateSlope1_,
    uint32 variableRateSlope2_
  ) external pure returns (PackedInterestRateData) {
    return
      InterestRateDataMap.create(
        optimalUsageRatio_,
        baseVariableBorrowRate_,
        variableRateSlope1_,
        variableRateSlope2_
      );
  }

  function optimalUsageRatio(PackedInterestRateData data) external pure returns (uint256) {
    return data.optimalUsageRatio();
  }

  function baseVariableBorrowRate(PackedInterestRateData data) external pure returns (uint256) {
    return data.baseVariableBorrowRate();
  }

  function variableRateSlope1(PackedInterestRateData data) external pure returns (uint256) {
    return data.variableRateSlope1();
  }

  function variableRateSlope2(PackedInterestRateData data) external pure returns (uint256) {
    return data.variableRateSlope2();
  }

  function setOptimalUsageRatio(
    PackedInterestRateData data,
    uint256 value
  ) external pure returns (PackedInterestRateData) {
    return data.setOptimalUsageRatio(value);
  }

  function setBaseVariableBorrowRate(
    PackedInterestRateData data,
    uint256 value
  ) external pure returns (PackedInterestRateData) {
    return data.setBaseVariableBorrowRate(value);
  }

  function setVariableRateSlope1(
    PackedInterestRateData data,
    uint256 value
  ) external pure returns (PackedInterestRateData) {
    return data.setVariableRateSlope1(value);
  }

  function setVariableRateSlope2(
    PackedInterestRateData data,
    uint256 value
  ) external pure returns (PackedInterestRateData) {
    return data.setVariableRateSlope2(value);
  }

  function OPTIMAL_USAGE_RATIO_MASK() external pure returns (uint256) {
    return InterestRateDataMap.OPTIMAL_USAGE_RATIO_MASK;
  }

  function BASE_VARIABLE_BORROW_RATE_MASK() external pure returns (uint256) {
    return InterestRateDataMap.BASE_VARIABLE_BORROW_RATE_MASK;
  }

  function VARIABLE_RATE_SLOPE1_MASK() external pure returns (uint256) {
    return InterestRateDataMap.VARIABLE_RATE_SLOPE1_MASK;
  }

  function VARIABLE_RATE_SLOPE2_MASK() external pure returns (uint256) {
    return InterestRateDataMap.VARIABLE_RATE_SLOPE2_MASK;
  }

  function OPTIMAL_USAGE_RATIO_OFFSET() external pure returns (uint256) {
    return InterestRateDataMap.OPTIMAL_USAGE_RATIO_OFFSET;
  }

  function BASE_VARIABLE_BORROW_RATE_OFFSET() external pure returns (uint256) {
    return InterestRateDataMap.BASE_VARIABLE_BORROW_RATE_OFFSET;
  }

  function VARIABLE_RATE_SLOPE1_OFFSET() external pure returns (uint256) {
    return InterestRateDataMap.VARIABLE_RATE_SLOPE1_OFFSET;
  }

  function VARIABLE_RATE_SLOPE2_OFFSET() external pure returns (uint256) {
    return InterestRateDataMap.VARIABLE_RATE_SLOPE2_OFFSET;
  }
}
