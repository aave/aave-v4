// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Arrays} from 'src/dependencies/openzeppelin/Arrays.sol';

/**
 * @notice Library to pack key-value pairs in a list.
 * @dev The `sortByKey` helper sorts by ascending order of the `key` & in case of collision by descending order of the `value`.
 * This is achieved by sorting the packed `key-value` pair in descending order, but storing the invert of the `key` (ie `_MAX_KEY - key`).
 * Uninitialized keys are returned as (key: 0, value: 0) and are placed at the end of the list after sorting.
 */
library KeyValueList {
  error MaxDataSizeExceeded();

  struct List {
    uint256[] _inner;
  }

  uint256 internal constant _KEY_BITS = 32;
  uint256 internal constant _VALUE_BITS = 224;
  uint256 internal constant _MAX_KEY = (1 << _KEY_BITS) - 1;
  uint256 internal constant _MAX_VALUE = (1 << _VALUE_BITS) - 1;
  uint256 internal constant _KEY_SHIFT = 256 - _KEY_BITS;

  function init(uint256 size) internal pure returns (List memory) {
    return List(new uint256[](size));
  }

  function length(List memory self) internal pure returns (uint256) {
    return self._inner.length;
  }

  function add(List memory self, uint256 idx, uint256 key, uint256 value) internal pure {
    require(key <= _MAX_KEY && value <= _MAX_VALUE, MaxDataSizeExceeded());
    self._inner[idx] = pack(key, value);
  }

  /// @dev Uninitialized keys are returned as (key: 0, value: 0).
  function get(List memory self, uint256 idx) internal pure returns (uint256, uint256) {
    return unpack(self._inner[idx]);
  }

  /**
   * @dev Since `key` is in the MSB, we can sort by the key by sorting the array in descending order
   * (so the keys are in ascending order when unpacking, due to inversion when packing),
   * and using value in descending order in case of collision,
   * and all uninitialized keys are placed at the end of the list after sorting.
   */
  function sortByKey(List memory self) internal pure {
    Arrays.sort(self._inner, gtComparator);
  }

  /// @dev key, value < ceiling checks are expected to be done before packing
  function pack(uint256 key, uint256 value) internal pure returns (uint256) {
    return ((_MAX_KEY - key) << _KEY_SHIFT) | value;
  }

  function unpackKey(uint256 data) internal pure returns (uint256) {
    return _MAX_KEY - (data >> _KEY_SHIFT);
  }

  function unpackValue(uint256 data) internal pure returns (uint256) {
    return data & ((1 << _KEY_SHIFT) - 1);
  }

  function unpack(uint256 data) internal pure returns (uint256, uint256) {
    // @dev no need to unpack data that was never initialized
    if (data == 0) return (0, 0);
    return (unpackKey(data), unpackValue(data));
  }

  function gtComparator(uint256 a, uint256 b) internal pure returns (bool) {
    return a > b;
  }
}
