// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {LibSort} from 'src/dependencies/solady/LibSort.sol';

library KeyValueListInMemory {
  error MaxKeySizeExceeded(uint256);
  error MaxValueSizeExceeded(uint256);

  uint256 internal constant _MAX_KEY_BITS = 32;
  uint256 internal constant _MAX_VALUE_BITS = 224;

  uint256 internal constant _MAX_KEY = type(uint32).max;
  uint256 internal constant _MAX_VALUE = type(uint224).max;

  // since KEY_BITS < VALUE_BITS & we want to pack KEY in the msb
  uint256 internal constant _KEY_SHIFT = 256 - _MAX_KEY_BITS;

  struct List {
    uint256[] _inner;
  }

  function init(uint256 size) internal pure returns (List memory) {
    // opt: cheaper to allocate memory w/o zeroing out: https://github.com/Vectorized/solady/blob/main/src/utils/DynamicArrayLib.sol#L34-L42
    return List(new uint256[](size));
  }

  function length(List memory self) internal pure returns (uint256) {
    return self._inner.length;
  }

  function add(List memory self, uint256 idx, uint256 key, uint256 value) internal pure {
    require(key <= _MAX_KEY, MaxKeySizeExceeded(key));
    require(value <= _MAX_VALUE, MaxValueSizeExceeded(value));
    self._inner[idx] = pack(key, value);
  }

  function get(List memory self, uint256 idx) internal pure returns (uint256, uint256) {
    return unpack(self._inner[idx]);
  }

  function sortByKey(List memory self) internal pure {
    // @dev since `key` is in the MSB, we can sort by the key by sorting the array
    LibSort.insertionSort(self._inner);
  }

  // @dev key, value < ceiling checks are expected to be done before packing
  function pack(uint256 key, uint256 value) internal pure returns (uint256) {
    return (key << _KEY_SHIFT) | ((~value) & _MAX_VALUE);
  }

  function unpackKey(uint256 data) internal pure returns (uint256) {
    return data >> _KEY_SHIFT;
  }

  function unpackValue(uint256 data) internal pure returns (uint256) {
    return (~data) & ((1 << _KEY_SHIFT) - 1);
  }

  function unpack(uint256 data) internal pure returns (uint256, uint256) {
    // @dev no need to unpack data that was never packed
    if(data == 0) return(0,0);
    return (unpackKey(data), unpackValue(data));
  }
}
