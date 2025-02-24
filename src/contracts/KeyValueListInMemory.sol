// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Arrays} from 'src/dependencies/openzeppelin/Arrays.sol';

// todo: optimize by packing, keep pre-sorted
library KeyValueListInMemory {
  struct List {
    uint256[] _inner;
  }

  function init(uint256 length) internal pure returns (List memory) {
    return List(new uint256[](length));
  }

  function add(List memory self, uint256 idx, uint256 key, uint256 value) internal pure {
    self._inner[idx] = pack(key, value);
  }

  function get(List memory self, uint256 idx) internal pure returns (uint256, uint256) {
    return unpack(self._inner[idx]);
  }

  function sortByValue(List memory self) internal pure {
    Arrays.sort(self._inner, valueComparator);
  }

  // @dev key, value < uint(128).max checks are omitted
  function pack(uint256 key, uint256 value) internal pure returns (uint256) {
    return (key << 128) | value;
  }

  function unpackValue(uint256 data) internal pure returns (uint256) {
    return data & ((1 << 128) - 1);
  }

  function unpack(uint256 data) internal pure returns (uint256, uint256) {
    return (data >> 128, unpackValue(data));
  }

  function valueComparator(uint256 a, uint256 b) internal pure returns (bool) {
    return unpackValue(a) < unpackValue(b);
  }
}
