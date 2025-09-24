// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Arrays} from 'src/dependencies/openzeppelin/Arrays.sol';

/**
 * @title KeyValueList Library
 * @author Aave Labs
 * @notice Library to pack key-value pairs in a list.
 * @dev The `sortByKey` helper sorts by ascending order of the `key` & in case of collision by descending order of the `value`.
 * @dev This is achieved by sorting the packed `key-value` pair in descending order, but storing the invert of the `key` (ie `_MAX_KEY - key`).
 * @dev Uninitialized keys are returned as (key: 0, value: 0) and are placed at the end of the list after sorting.
 */
library KeyValueList {
  /**
   * @notice Thrown upon adding an element with a key or value exceeding the maximum allowed.
   */
  error MaxDataSizeExceeded();

  struct List {
    uint256[] _inner;
  }

  uint256 internal constant _KEY_BITS = 32;
  uint256 internal constant _VALUE_BITS = 224;
  uint256 internal constant _MAX_KEY = (1 << _KEY_BITS) - 1;
  uint256 internal constant _MAX_VALUE = (1 << _VALUE_BITS) - 1;
  uint256 internal constant _KEY_SHIFT = 256 - _KEY_BITS;

  /**
   * @notice Initializes a new KeyValueList.
   * @param size The desired size of the list.
   * @return A new List with the specified size.
   */
  function init(uint256 size) internal pure returns (List memory) {
    return List(new uint256[](size));
  }

  /**
   * @notice Returns the length of the list.
   * @param self The List instance.
   * @return The length of the list.
   */
  function length(List memory self) internal pure returns (uint256) {
    return self._inner.length;
  }

  /**
   * @notice Adds a key-value pair at the specified index.
   * @param self The List instance.
   * @param idx The index at which to add the key-value pair.
   * @param key The key to add (must be <= 2^32 - 1).
   * @param value The value to add (must be <= 2^224 - 1).
   */
  function add(List memory self, uint256 idx, uint256 key, uint256 value) internal pure {
    require(key <= _MAX_KEY && value <= _MAX_VALUE, MaxDataSizeExceeded());
    self._inner[idx] = pack(key, value);
  }

  /**
   * @notice Retrieves the key-value pair at the specified index.
   * @dev Uninitialized keys are returned as (key: 0, value: 0).
   * @param self The List instance.
   * @param idx The index from which to retrieve the key-value pair.
   */
  function get(List memory self, uint256 idx) internal pure returns (uint256, uint256) {
    return unpack(self._inner[idx]);
  }

  /**
   * @notice Sorts the list in-place by ascending order of the `key`.
   * @dev Since `key` is in the MSB, we can sort by the key by sorting the array in descending order
   * (so the keys are in ascending order when unpacking, due to inversion when packing).
   * @dev In case of collision, values are sorted in descending order.
   * @dev All uninitialized keys are placed at the end of the list after sorting.
   * @param self The List instance.
   */
  function sortByKey(List memory self) internal pure {
    Arrays.sort(self._inner, gtComparator);
  }

  /**
   * @notice Packs a key-value pair into a single uint256.
   * @dev key, value < ceiling checks are expected to be done before packing
   * @param key The key to pack.
   * @param value The value to pack.
   * @return The packed key-value pair as a single uint256.
   */
  function pack(uint256 key, uint256 value) internal pure returns (uint256) {
    return ((_MAX_KEY - key) << _KEY_SHIFT) | value;
  }

  /**
   * @notice Unpacks the key from a previously packed uint256 containing key and value.
   * @param data The packed key-value pair as a single uint256.
   * @return The unpacked key.
   */
  function unpackKey(uint256 data) internal pure returns (uint256) {
    return _MAX_KEY - (data >> _KEY_SHIFT);
  }

  /**
   * @notice Unpacks the value from a previously packed uint256 containing key and value.
   * @param data The packed key-value pair as a single uint256.
   * @return The unpacked value.
   */
  function unpackValue(uint256 data) internal pure returns (uint256) {
    return data & ((1 << _KEY_SHIFT) - 1);
  }

  /**
   * @notice Unpacks both the key and value from a previously packed uint256 containing key and value.
   * @dev Uninitialized keys are returned as (key: 0, value: 0).
   * @param data The packed key-value pair as a single uint256.
   * @return The unpacked key.
   * @return The unpacked value.
   */
  function unpack(uint256 data) internal pure returns (uint256, uint256) {
    if (data == 0) return (0, 0);
    return (unpackKey(data), unpackValue(data));
  }

  /**
   * @notice Comparator function for sorting in descending order.
   * @param a The first value to compare.
   * @param b The second value to compare.
   * @return True if `a` is greater than `b`, false otherwise.
   */
  function gtComparator(uint256 a, uint256 b) internal pure returns (bool) {
    return a > b;
  }
}
