// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {ExtSloadWrapper, ExtSload} from 'tests/mocks/ExtSloadWrapper.sol';

contract ExtSloadTest is Test {
  ExtSloadWrapper internal w;

  function setUp() public {
    w = new ExtSloadWrapper();
  }

  function test_extSload(bytes32) public {
    vm.setArbitraryStorage(address(w));
    bytes32 slot = bytes32(vm.randomUint());
    assertEq(w.extSload(slot), vm.load(address(w), slot));
  }

  function test_extSloads(uint256 count) public {
    count = bound(count, 0, 1024); // for performance
    vm.setArbitraryStorage(address(w));

    bytes32[] memory slots = new bytes32[](count);
    for (uint256 i; i < count; ++i) {
      slots[i] = bytes32(vm.randomUint());
    }

    bytes32[] memory values = w.extSloads(slots);
    assertEq(values.length, count);
    for (uint256 i; i < count; ++i) {
      assertEq(values[i], vm.load(address(w), slots[i]));
    }
  }

  function test_extSloads(uint256 count, bytes memory dirty) public {
    count = bound(count, 0, 1024); // for performance

    bytes32[] memory slots = new bytes32[](count);
    bytes32[] memory values = new bytes32[](count);
    for (uint256 i; i < count; ++i) {
      slots[i] = bytes32(vm.randomUint());
      values[i] = bytes32(vm.randomUint());
      vm.store(address(w), slots[i], values[i]);
    }

    bytes memory malformed = bytes.concat(abi.encodeCall(ExtSload.extSloads, (slots)), dirty);
    (bool ok, bytes memory ret) = address(w).staticcall(malformed);

    assertTrue(ok);
    assertEq(ret, abi.encode(values));
  }
}
