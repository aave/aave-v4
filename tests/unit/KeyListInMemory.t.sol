// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {KeyValueListInMemory} from 'src/contracts/KeyValueListInMemory.sol';

contract KeyValueListInMemoryTest is Test {
  using KeyValueListInMemory for KeyValueListInMemory.List;

  function test_fuzz_sortByKey(uint256[] memory seed) public pure {
    vm.assume(seed.length > 0);
    KeyValueListInMemory.List memory list = KeyValueListInMemory.init(seed.length);
    for (uint256 i; i < seed.length; ++i) {
      list.add(i, _truncateKey(seed[i]), _truncateValue(seed[i]));
    }
    list.sortByKey();
    _assertSortedOrder(list);
  }

  function test_fuzz_sortByKey_length(uint256 length) public {
    length = bound(length, 1, 1e2);
    KeyValueListInMemory.List memory list = KeyValueListInMemory.init(length);
    for (uint256 i; i < length; ++i) {
      list.add(i, _truncateKey(vm.randomUint()), _truncateValue(vm.randomUint()));
    }
    list.sortByKey();
    _assertSortedOrder(list);
  }

  function test_fuzz_get(uint256[] memory seed) public pure {
    vm.assume(seed.length > 0);
    KeyValueListInMemory.List memory list = KeyValueListInMemory.init(seed.length);
    for (uint256 i; i < seed.length; ++i) {
      list.add(i, _truncateKey(seed[i]), _truncateValue(seed[i]));
    }
    for (uint256 i; i < seed.length; ++i) {
      (uint256 key, uint256 value) = list.get(i);
      assertEq(key, _truncateKey(seed[i]));
      assertEq(value, _truncateValue(seed[i]));
    }
  }

  function _assertSortedOrder(KeyValueListInMemory.List memory list) internal pure {
    // validate sorted order
    (uint256 prevKey, ) = list.get(0);
    for (uint256 i = 1; i < list.length(); ++i) {
      (uint256 key, ) = list.get(i);
      assertLe(prevKey, key);
      prevKey = key;
    }
  }

  function _truncateKey(uint256 key) internal pure returns (uint256) {
    return key % KeyValueListInMemory._KEY_MASK;
  }
  function _truncateValue(uint256 value) internal pure returns (uint256) {
    return value % KeyValueListInMemory._VALUE_MASK;
  }
}
