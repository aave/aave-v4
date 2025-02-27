// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {KeyValueListInMemory} from 'src/contracts/KeyValueListInMemory.sol';

contract KeyValueListInMemoryTest is Test {
  using KeyValueListInMemory for KeyValueListInMemory.List;

  function test_fuzz_sortByKey(uint256[] memory seed) public pure {
    vm.assume(seed.length > 0);
    KeyValueListInMemory.List memory list = KeyValueListInMemory.init(seed.length);
    for (uint256 i = 0; i < seed.length; ++i) {
      list.add(i, _truncateKey(seed[i]), _truncateValue(seed[i]));
    }
    list.sortByKey();
    // validate sorted order
    (uint256 prevKey, ) = list.get(0);
    for (uint256 i = 1; i < seed.length; ++i) {
      (uint256 key, ) = list.get(i);
      assertLe(prevKey, key);
      prevKey = key;
    }
  }

  function test_fuzz_sortByKey_length(uint256 length) public {
    length = bound(length, 1, 1e2);
    KeyValueListInMemory.List memory list = KeyValueListInMemory.init(length);
    for (uint256 i = 0; i < length; ++i) {
      list.add(i, _truncateKey(vm.randomUint()), _truncateValue(vm.randomUint()));
    }
    list.sortByKey();
    // validate sorted order
    (uint256 prevKey, ) = list.get(0);
    for (uint256 i = 1; i < length; ++i) {
      (uint256 key, ) = list.get(i);
      assertLe(prevKey, key);
      prevKey = key;
    }
  }

  function _truncateKey(uint256 key) internal pure returns (uint256) {
    return key % (1 << KeyValueListInMemory._MAX_BIT_SIZE);
  }
  function _truncateValue(uint256 value) internal pure returns (uint256) {
    return value % (1 << KeyValueListInMemory._MAX_BIT_SIZE);
  }
}
