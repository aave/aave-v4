// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {Test} from 'forge-std/Test.sol';

interface IPR5240Multicall {
  function multicall(bytes[] calldata data) external returns (bytes[] memory);
  function labelRole(uint64 roleId, string calldata label) external;
}

contract PR5240DomainTest is Test {
  function test_accessManagerDynamicResults() public {
    address target = vm.deployCode('AccessManagerEnumerable.vy:AccessManagerEnumerable', abi.encode(address(this)));
    bytes[] memory calls = new bytes[](3);
    string[] memory labels = new string[](3);
    labels[0] = 'a';
    labels[1] = 'abcdefghijklmnopqrstuvwxyz0123456';
    labels[2] = string(new bytes(128));
    for (uint64 i; i < 3; ++i) {
      IPR5240Multicall(target).labelRole(i + 1, labels[i]);
      calls[i] = abi.encodeWithSignature('getLabelOfRole(uint64)', i + 1);
    }
    bytes[] memory results = IPR5240Multicall(target).multicall(calls);
    assertEq(results.length, 3);
    for (uint256 i; i < 3; ++i) assertEq(results[i], abi.encode(labels[i]));
  }

  function test_accessManager65Calls() public {
    address target = vm.deployCode('AccessManagerEnumerable.vy:AccessManagerEnumerable', abi.encode(address(this)));
    bytes[] memory calls = new bytes[](65);
    for (uint256 i; i < calls.length; ++i) calls[i] = abi.encodeWithSignature('getRoleCount()');
    bytes[] memory results = IPR5240Multicall(target).multicall(calls);
    assertEq(results.length, calls.length);
    for (uint256 i; i < results.length; ++i) assertEq(abi.decode(results[i], (uint256)), 0);
  }

  function test_positionManager5CallsAndEmpty() public {
    address target = vm.deployCode('GiverPositionManager.vy:GiverPositionManager', abi.encode(address(this)));
    bytes[] memory calls = new bytes[](5);
    for (uint256 i; i < calls.length; ++i) calls[i] = abi.encodeWithSignature('owner()');
    bytes[] memory results = IPR5240Multicall(target).multicall(calls);
    assertEq(results.length, calls.length);
    for (uint256 i; i < results.length; ++i) assertEq(abi.decode(results[i], (address)), address(this));
    assertEq(IPR5240Multicall(target).multicall(new bytes[](0)).length, 0);
  }
}
