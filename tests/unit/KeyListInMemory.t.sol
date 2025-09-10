// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {KeyValueListInMemory} from 'src/libraries/helpers/KeyValueListInMemory.sol';

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

  function test_fuzz_sortByKey_with_collision(uint256[] memory seed) public pure {
    vm.assume(seed.length > 10);
    uint256[] memory collisionKeys = new uint256[](seed.length / 10);
    for (uint256 i; i < collisionKeys.length; ++i) {
      collisionKeys[i] = seed[i];
    }

    vm.assume(seed.length > 0);
    KeyValueListInMemory.List memory list = KeyValueListInMemory.init(seed.length);
    for (uint256 i; i < seed.length; ++i) {
      list.add(
        i,
        _truncateKey(collisionKeys[seed[i] % collisionKeys.length]),
        _truncateValue(seed[i])
      );
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

  function test_fuzz_get_uninitialized(uint256[] memory seed) public {
    vm.assume(seed.length > 0);
    uint256 fillArrayTill = vm.randomUint(0, seed.length - 1);
    KeyValueListInMemory.List memory list = KeyValueListInMemory.init(seed.length);
    for (uint256 i; i < fillArrayTill; ++i) {
      list.add(i, _truncateKey(seed[i]), _truncateValue(seed[i]));
    }
    for (uint256 i; i < seed.length; ++i) {
      (uint256 key, uint256 value) = list.get(i);
      if (i < fillArrayTill) {
        assertEq(key, _truncateKey(seed[i]));
        assertEq(value, _truncateValue(seed[i]));
      } else {
        assertEq(key, 0);
        assertEq(value, 0);
      }
    }
  }

  function test_fuzz_get_uninitialized_sorted(uint256[] memory seed) public {
    vm.assume(seed.length > 0 && seed.length < 1e2);
    uint256 fillArrayTill = vm.randomUint(0, seed.length - 1);
    KeyValueListInMemory.List memory list = KeyValueListInMemory.init(seed.length);
    for (uint256 i; i < fillArrayTill; ++i) {
      list.add(i, _truncateKey(seed[i]), _truncateValue(seed[i]));
    }
    list.sortByKey();
    for (uint256 i; i < seed.length; ++i) {
      (uint256 key, uint256 value) = list.get(i);
      if (i >= fillArrayTill) {
        assertEq(key, 0);
        assertEq(value, 0);
      }
    }
  }

  function _assertSortedOrder(KeyValueListInMemory.List memory list) internal pure {
    // validate sorted order
    (uint256 prevKey, uint256 prevValue) = list.get(0);
    for (uint256 i = 1; i < list.length(); ++i) {
      (uint256 key, uint256 value) = list.get(i);
      assertLe(prevKey, key);
      if (prevKey == key) {
        assertGe(prevValue, value);
      }
      prevKey = key;
      prevValue = value;
    }
  }

  function _truncateKey(uint256 key) internal pure returns (uint256) {
    return key % KeyValueListInMemory._MAX_KEY;
  }

  function _truncateValue(uint256 value) internal pure returns (uint256) {
    return value % KeyValueListInMemory._MAX_VALUE;
  }
}
