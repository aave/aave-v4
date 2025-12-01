// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {KeyValueList} from 'src/spoke/libraries/KeyValueList.sol';

/// forge-config: default.allow_internal_expect_revert = true
contract KeyValueListTest is Test {
  using KeyValueList for KeyValueList.List;

  function test_add_unique() public {
    /// @dev needed for reverts not to block the test
    KeyValueListWrapper wrapper = new KeyValueListWrapper();
    KeyValueList.List memory list = KeyValueList.init(11);

    list = wrapper.add(list, 0, 1, 1);
    list = wrapper.add(list, 1, 100, 1e15);
    list = wrapper.add(list, 2, 100, 5e20);
    list = wrapper.add(list, 3, 5e4, 5e20);
    list = wrapper.add(list, 4, 5e4, 1e12);
    list = wrapper.add(list, 5, 45e6, 2.5e50);
    list = wrapper.add(list, 6, 45e6, 10);

    list = wrapper.add(list, 7, type(uint32).max - 1, 10000000000);

    vm.expectRevert(KeyValueList.MaxDataSizeExceeded.selector);
    wrapper.add(list, 8, type(uint32).max, 10000000000);

    vm.expectRevert(KeyValueList.MaxDataSizeExceeded.selector);
    wrapper.add(list, 8, 45e8, 10000000000);

    vm.expectRevert(KeyValueList.MaxDataSizeExceeded.selector);
    wrapper.add(list, 8, 75e9, 10000000000);

    vm.expectRevert(KeyValueList.MaxDataSizeExceeded.selector);
    wrapper.add(list, 9, 5e6, 2.696e67);

    vm.expectRevert(KeyValueList.MaxDataSizeExceeded.selector);
    wrapper.add(list, 9, 5e6, 5e70);

    vm.expectRevert(KeyValueList.MaxDataSizeExceeded.selector);
    wrapper.add(list, 9, 5e6, 12.5e75);

    vm.expectRevert(KeyValueList.MaxDataSizeExceeded.selector);
    wrapper.add(list, 9, 5e6, type(uint224).max);

    list = wrapper.add(list, 10, 5e6, type(uint224).max - 1);

    uint256 returnedKey;
    uint256 returnedValue;
    (returnedKey, returnedValue) = list.get(0);
    assertEq(returnedKey, 1);
    assertEq(returnedValue, 1);
    (returnedKey, returnedValue) = list.get(1);
    assertEq(returnedKey, 100);
    assertEq(returnedValue, 1e15);
    (returnedKey, returnedValue) = list.get(2);
    assertEq(returnedKey, 100);
    assertEq(returnedValue, 5e20);
    (returnedKey, returnedValue) = list.get(3);
    assertEq(returnedKey, 5e4);
    assertEq(returnedValue, 5e20);
    (returnedKey, returnedValue) = list.get(4);
    assertEq(returnedKey, 5e4);
    assertEq(returnedValue, 1e12);
    (returnedKey, returnedValue) = list.get(5);
    assertEq(returnedKey, 45e6);
    assertEq(returnedValue, 2.5e50);
    (returnedKey, returnedValue) = list.get(6);
    assertEq(returnedKey, 45e6);
    assertEq(returnedValue, 10);
    (returnedKey, returnedValue) = list.get(7);
    assertEq(returnedKey, type(uint32).max - 1);
    assertEq(returnedValue, 10000000000);
    (returnedKey, returnedValue) = list.get(8);
    assertEq(returnedKey, 0);
    assertEq(returnedValue, 0);
    (returnedKey, returnedValue) = list.get(9);
    assertEq(returnedKey, 0);
    assertEq(returnedValue, 0);
    (returnedKey, returnedValue) = list.get(10);
    assertEq(returnedKey, 5e6);
    assertEq(returnedValue, type(uint224).max - 1);
  }

  function test_fuzz_add(uint256 key, uint256 value) public {
    /// @dev needed for reverts not to block the test
    KeyValueListWrapper wrapper = new KeyValueListWrapper();
    KeyValueList.List memory list = KeyValueList.init(5);

    if (key >= KeyValueList._MAX_KEY || value >= KeyValueList._MAX_VALUE) {
      vm.expectRevert(KeyValueList.MaxDataSizeExceeded.selector);
      wrapper.add(list, 0, key, value);
    } else {
      list.add(0, key, value);
    }

    if (key < KeyValueList._MAX_KEY && value < KeyValueList._MAX_VALUE) {
      (uint256 storedKey, uint256 storedValue) = list.get(0);
      assertEq(storedKey, key);
      assertEq(storedValue, value);
    }
  }

  function test_fuzz_add_unique(uint256 seed, uint256 size) public pure {
    size = bound(size, 1, 1e2);
    uint256[] memory keys = _generateRandomUint256Array(size, seed, 1, type(uint32).max - 1);
    uint256[] memory values = _generateRandomUint256Array(size, seed, 1, type(uint224).max - 1);
    KeyValueList.List memory list = KeyValueList.init(keys.length);
    for (uint256 i; i < keys.length; ++i) {
      list.add(i, keys[i], values[i]);
    }
    for (uint256 i; i < keys.length; ++i) {
      (uint256 key, uint256 value) = list.get(i);
      assertEq(key, keys[i]);
      assertEq(value, values[i]);
      // No key should return as 0 unless the set key is 0 or the cell is not initialized
      assertGt(key, 0);
      // No value should return as 0 unless the set value is 0 or the cell is not initialized
      assertGt(value, 0);
    }
  }

  function test_fuzz_sortByKey(uint256[] memory seed) public pure {
    vm.assume(seed.length > 0);
    KeyValueList.List memory list = KeyValueList.init(seed.length);
    for (uint256 i; i < seed.length; ++i) {
      list.add(i, _truncateKey(seed[i]), _truncateValue(seed[i]));
    }
    list.sortByKey();
    _assertSortedOrder(list);
  }

  function test_fuzz_sortByKey_length(uint256 length) public {
    length = bound(length, 1, 1e2);
    KeyValueList.List memory list = KeyValueList.init(length);
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
    KeyValueList.List memory list = KeyValueList.init(seed.length);
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
    KeyValueList.List memory list = KeyValueList.init(seed.length);
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
    KeyValueList.List memory list = KeyValueList.init(seed.length);
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
    KeyValueList.List memory list = KeyValueList.init(seed.length);
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

  function _assertSortedOrder(KeyValueList.List memory list) internal pure {
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
    return key % KeyValueList._MAX_KEY;
  }

  function _truncateValue(uint256 value) internal pure returns (uint256) {
    return value % KeyValueList._MAX_VALUE;
  }

  function _generateRandomUint256Array(
    uint256 size,
    uint256 seed,
    uint256 lowerBound,
    uint256 upperBound
  ) internal pure returns (uint256[] memory) {
    seed = seed % 1e77;
    if (size == 0) return new uint256[](0);
    uint256[] memory result = new uint256[](size);
    for (uint256 i; i < size; ++i) {
      result[i] =
        (uint256((keccak256(abi.encode(seed + i)))) % (upperBound - lowerBound + 1)) +
        lowerBound;
    }
    return result;
  }
}

contract KeyValueListWrapper {
  using KeyValueList for KeyValueList.List;

  function add(
    KeyValueList.List memory list,
    uint256 idx,
    uint256 key,
    uint256 value
  ) external pure returns (KeyValueList.List memory returnList) {
    returnList = list;
    returnList.add(idx, key, value);
    return returnList;
  }
}
