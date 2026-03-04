// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {
  PackedInterestRateData,
  IAssetInterestRateStrategy
} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';

/// @title InterestRateDataMap Library
/// @author Aave Labs
/// @notice Implements the bitmap logic to pack/unpack PackedInterestRateData fields into a uint256.
library InterestRateDataMap {
  using SafeCast for uint256;
  /// @dev Mask for the `optimalUsageRatio` field (uint16).
  uint256 internal constant OPTIMAL_USAGE_RATIO_MASK = 0xFFFF;
  /// @dev Mask for the `baseVariableBorrowRate` field (uint32).
  uint256 internal constant BASE_VARIABLE_BORROW_RATE_MASK = 0xFFFFFFFF;
  /// @dev Mask for the `variableRateSlope1` field (uint32).
  uint256 internal constant VARIABLE_RATE_SLOPE1_MASK = 0xFFFFFFFF;
  /// @dev Mask for the `variableRateSlope2` field (uint32).
  uint256 internal constant VARIABLE_RATE_SLOPE2_MASK = 0xFFFFFFFF;

  /// @dev Bit offset for the `optimalUsageRatio` field.
  uint256 internal constant OPTIMAL_USAGE_RATIO_OFFSET = 0;
  /// @dev Bit offset for the `baseVariableBorrowRate` field.
  uint256 internal constant BASE_VARIABLE_BORROW_RATE_OFFSET = 16;
  /// @dev Bit offset for the `variableRateSlope1` field.
  uint256 internal constant VARIABLE_RATE_SLOPE1_OFFSET = 48;
  /// @dev Bit offset for the `variableRateSlope2` field.
  uint256 internal constant VARIABLE_RATE_SLOPE2_OFFSET = 80;

  /// @notice Creates an PackedInterestRateData from the individual fields.
  /// @param optimalUsageRatio_ The optimal usage ratio, in BPS.
  /// @param baseVariableBorrowRate_ The base variable borrow rate, in BPS.
  /// @param variableRateSlope1_ The slope before the kink point, in BPS.
  /// @param variableRateSlope2_ The slope after the kink point, in BPS.
  /// @return The packed PackedInterestRateData.
  function create(
    uint16 optimalUsageRatio_,
    uint32 baseVariableBorrowRate_,
    uint32 variableRateSlope1_,
    uint32 variableRateSlope2_
  ) internal pure returns (PackedInterestRateData) {
    uint256 packed = uint256(optimalUsageRatio_);
    packed |= uint256(baseVariableBorrowRate_) << BASE_VARIABLE_BORROW_RATE_OFFSET;
    packed |= uint256(variableRateSlope1_) << VARIABLE_RATE_SLOPE1_OFFSET;
    packed |= uint256(variableRateSlope2_) << VARIABLE_RATE_SLOPE2_OFFSET;
    return PackedInterestRateData.wrap(packed);
  }

  /// @notice Packs an InterestRateData struct into a PackedInterestRateData.
  /// @param input The struct to pack.
  /// @return The packed representation.
  function pack(
    IAssetInterestRateStrategy.InterestRateData memory input
  ) internal pure returns (PackedInterestRateData) {
    return
      create(
        input.optimalUsageRatio,
        input.baseVariableBorrowRate,
        input.variableRateSlope1,
        input.variableRateSlope2
      );
  }

  /// @notice Unpacks a PackedInterestRateData into an InterestRateData struct.
  /// @param data The packed data to unpack.
  /// @return The unpacked struct.
  function toStruct(
    PackedInterestRateData data
  ) internal pure returns (IAssetInterestRateStrategy.InterestRateData memory) {
    return
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: uint16(optimalUsageRatio(data)),
        baseVariableBorrowRate: uint32(baseVariableBorrowRate(data)),
        variableRateSlope1: uint32(variableRateSlope1(data)),
        variableRateSlope2: uint32(variableRateSlope2(data))
      });
  }

  /// @notice Returns the `optimalUsageRatio` field.
  /// @param data The packed PackedInterestRateData.
  /// @return The optimal usage ratio, in BPS.
  function optimalUsageRatio(PackedInterestRateData data) internal pure returns (uint256) {
    return _getField(data, OPTIMAL_USAGE_RATIO_MASK, OPTIMAL_USAGE_RATIO_OFFSET);
  }

  /// @notice Returns the `baseVariableBorrowRate` field.
  /// @param data The packed PackedInterestRateData.
  /// @return The base variable borrow rate, in BPS.
  function baseVariableBorrowRate(PackedInterestRateData data) internal pure returns (uint256) {
    return _getField(data, BASE_VARIABLE_BORROW_RATE_MASK, BASE_VARIABLE_BORROW_RATE_OFFSET);
  }

  /// @notice Returns the `variableRateSlope1` field.
  /// @param data The packed PackedInterestRateData.
  /// @return The variable rate slope 1, in BPS.
  function variableRateSlope1(PackedInterestRateData data) internal pure returns (uint256) {
    return _getField(data, VARIABLE_RATE_SLOPE1_MASK, VARIABLE_RATE_SLOPE1_OFFSET);
  }

  /// @notice Returns the `variableRateSlope2` field.
  /// @param data The packed PackedInterestRateData.
  /// @return The variable rate slope 2, in BPS.
  function variableRateSlope2(PackedInterestRateData data) internal pure returns (uint256) {
    return _getField(data, VARIABLE_RATE_SLOPE2_MASK, VARIABLE_RATE_SLOPE2_OFFSET);
  }

  /// @notice Sets the `optimalUsageRatio` field.
  /// @param data The current PackedInterestRateData.
  /// @param value The new optimal usage ratio.
  /// @return The updated PackedInterestRateData.
  function setOptimalUsageRatio(
    PackedInterestRateData data,
    uint256 value
  ) internal pure returns (PackedInterestRateData) {
    return
      PackedInterestRateData.wrap(
        _setField(data, OPTIMAL_USAGE_RATIO_MASK, OPTIMAL_USAGE_RATIO_OFFSET, value.toUint16())
      );
  }

  /// @notice Sets the `baseVariableBorrowRate` field.
  /// @param data The current PackedInterestRateData.
  /// @param value The new base variable borrow rate.
  /// @return The updated PackedInterestRateData.
  function setBaseVariableBorrowRate(
    PackedInterestRateData data,
    uint256 value
  ) internal pure returns (PackedInterestRateData) {
    return
      PackedInterestRateData.wrap(
        _setField(
          data,
          BASE_VARIABLE_BORROW_RATE_MASK,
          BASE_VARIABLE_BORROW_RATE_OFFSET,
          value.toUint32()
        )
      );
  }

  /// @notice Sets the `variableRateSlope1` field.
  /// @param data The current PackedInterestRateData.
  /// @param value The new variable rate slope 1.
  /// @return The updated PackedInterestRateData.
  function setVariableRateSlope1(
    PackedInterestRateData data,
    uint256 value
  ) internal pure returns (PackedInterestRateData) {
    return
      PackedInterestRateData.wrap(
        _setField(data, VARIABLE_RATE_SLOPE1_MASK, VARIABLE_RATE_SLOPE1_OFFSET, value.toUint32())
      );
  }

  /// @notice Sets the `variableRateSlope2` field.
  /// @param data The current PackedInterestRateData.
  /// @param value The new variable rate slope 2.
  /// @return The updated PackedInterestRateData.
  function setVariableRateSlope2(
    PackedInterestRateData data,
    uint256 value
  ) internal pure returns (PackedInterestRateData) {
    return
      PackedInterestRateData.wrap(
        _setField(data, VARIABLE_RATE_SLOPE2_MASK, VARIABLE_RATE_SLOPE2_OFFSET, value.toUint32())
      );
  }

  /// @notice Extracts a field from packed data.
  function _getField(
    PackedInterestRateData data,
    uint256 mask,
    uint256 offset
  ) private pure returns (uint256) {
    return (PackedInterestRateData.unwrap(data) >> offset) & mask;
  }

  /// @notice Sets a field in packed data.
  function _setField(
    PackedInterestRateData data,
    uint256 mask,
    uint256 offset,
    uint256 value
  ) private pure returns (uint256) {
    uint256 raw = PackedInterestRateData.unwrap(data);
    return (raw & ~(mask << offset)) | ((value & mask) << offset);
  }
}
