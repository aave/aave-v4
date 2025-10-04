// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {Arrays} from 'src/dependencies/openzeppelin/Arrays.sol';

/// @title KeyValueList Library
/// @author Aave Labs
/// @notice Library to pack key-value pairs in a list.
/// @dev The `sortByKey` helper sorts by ascending order of the `key` & in case of collision by descending order of the `value`.
/// @dev This is achieved by sorting the packed `key-value` pair in descending order, but storing the invert of the `key` (ie `_MAX_KEY - key`).
/// @dev Uninitialized keys are returned as (key: 0, value: 0) and are placed at the end of the list after sorting.
library KeyValueList {
  /// @notice Thrown when adding a key which can't be stored in `_KEY_BITS` or value in `_VALUE_BITS`.
  error MaxDataSizeExceeded();

  struct List {
    uint256[] _inner;
  }

  uint256 internal constant _KEY_BITS = 32;
  uint256 internal constant _VALUE_BITS = 224;
  uint256 internal constant _MAX_KEY = (1 << _KEY_BITS) - 1;
  uint256 internal constant _MAX_VALUE = (1 << _VALUE_BITS) - 1;
  uint256 internal constant _KEY_SHIFT = 256 - _KEY_BITS;

  /// @notice Allocates memory for a KeyValue list of `size` elements.
  function init(uint256 size) internal pure returns (List memory) {
    return List(new uint256[](size));
  }

  /// @notice Returns the length of the list.
  function length(List memory self) internal pure returns (uint256) {
    return self._inner.length;
  }

  /// @notice Inserts packed `key`, `value` at `idx`. Reverts if data exceeds maximum allowed size.
  function add(List memory self, uint256 idx, uint256 key, uint256 value) internal pure {
    require(key <= _MAX_KEY && value <= _MAX_VALUE, MaxDataSizeExceeded());
    self._inner[idx] = pack(key, value);
  }

  /// @notice Returns the key-value pair at the given index.
  /// @dev Uninitialized keys are returned as (key: 0, value: 0).
  function get(List memory self, uint256 idx) internal pure returns (uint256, uint256) {
    return unpack(self._inner[idx]);
  }

  /// @notice Sorts the list in-place by ascending order of `key`, and descending order of `value` on collision.
  /// @dev All uninitialized keys are placed at the end of the list after sorting.
  /// @dev Since `key` is in the MSB, we can sort by the key by sorting the array in descending order
  /// (so the keys are in ascending order when unpacking, due to the inversion when packed).
  function sortByKey(List memory self) internal pure {
    Arrays.sort(self._inner, gtComparator);
  }

  /// @notice Packs a given `key`, `value` pair into a single word.
  /// @dev Bound checks are expected to be done before packing.
  function pack(uint256 key, uint256 value) internal pure returns (uint256) {
    return ((_MAX_KEY - key) << _KEY_SHIFT) | value;
  }

  /// @notice Unpacks `key` from a previously packed word containing `key` and `value`.
  /// @dev The key is stored in the most significant bits of the word.
  function unpackKey(uint256 data) internal pure returns (uint256) {
    return _MAX_KEY - (data >> _KEY_SHIFT);
  }

  /// @notice Unpacks `value` from a previously packed word containing `key` and `value`.
  /// @dev The value is stored in the least significant bits of the word.
  function unpackValue(uint256 data) internal pure returns (uint256) {
    return data & ((1 << _KEY_SHIFT) - 1);
  }

  /// @notice Unpacks both `key` and `value` from a previously packed word containing `key` and `value`.
  /// @dev Uninitialized keys are returned as (key: 0, value: 0).
  /// @param data The packed word containing `key` and `value`.
  function unpack(uint256 data) internal pure returns (uint256, uint256) {
    if (data == 0) return (0, 0);
    return (unpackKey(data), unpackValue(data));
  }

  /// @notice Comparator function performing greater-than comparison.
  /// @return True if `a` is greater than `b`, false otherwise.
  function gtComparator(uint256 a, uint256 b) internal pure returns (bool) {
    return a > b;
  }
}
