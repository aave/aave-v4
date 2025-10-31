// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';
import {AccessManagerEnumerable} from 'src/access/AccessManagerEnumerable.sol';

contract AccessManagerEnumerableTest is Test {
  using EnumerableSet for EnumerableSet.AddressSet;

  address internal ADMIN = makeAddr('ADMIN');

  AccessManagerEnumerable internal accessManagerEnumerable;

  EnumerableSet.AddressSet members;

  function setUp() public virtual {
    accessManagerEnumerable = new AccessManagerEnumerable(ADMIN);
  }

  function test_grantRole() public {
    uint64 roleId = 1;
    address user1 = makeAddr('user1');
    address user2 = makeAddr('user2');

    vm.startPrank(ADMIN);
    accessManagerEnumerable.labelRole(roleId, 'test_role');
    accessManagerEnumerable.setGrantDelay(roleId, 0);

    accessManagerEnumerable.grantRole(roleId, user1, 0);
    assertEq(accessManagerEnumerable.getRoleMember(roleId, 0), user1);
    assertEq(accessManagerEnumerable.getRoleMemberCount(roleId), 1);
    address[] memory roleMembers = accessManagerEnumerable.getRoleMembers(roleId);
    assertEq(roleMembers.length, 1);
    assertEq(roleMembers[0], user1);

    accessManagerEnumerable.grantRole(roleId, user2, 0);
    assertEq(accessManagerEnumerable.getRoleMember(roleId, 1), user2);
    assertEq(accessManagerEnumerable.getRoleMemberCount(roleId), 2);
    roleMembers = accessManagerEnumerable.getRoleMembers(roleId);
    assertEq(roleMembers.length, 2);
    assertEq(roleMembers[0], user1);
    assertEq(roleMembers[1], user2);
    vm.stopPrank();
  }

  function test_grantRole_fuzz(uint64 roleId, uint256 membersCount) public {
    membersCount = bound(membersCount, 1, 10);
    vm.assume(
      roleId != accessManagerEnumerable.PUBLIC_ROLE() &&
        roleId != accessManagerEnumerable.ADMIN_ROLE()
    );

    vm.startPrank(ADMIN);
    accessManagerEnumerable.labelRole(roleId, 'test_role');
    accessManagerEnumerable.setGrantDelay(roleId, 0);

    for (uint256 i = 0; i < membersCount; i++) {
      address member;
      while (member == address(0) || members.contains(member)) {
        member = vm.randomAddress();
      }
      members.add(member);
      accessManagerEnumerable.grantRole(roleId, member, 0);
    }
    vm.stopPrank();

    address[] memory roleMembers = accessManagerEnumerable.getRoleMembers(roleId);
    assertEq(accessManagerEnumerable.getRoleMemberCount(roleId), membersCount);
    assertEq(roleMembers.length, membersCount);

    for (uint256 i = 0; i < membersCount; i++) {
      assertEq(roleMembers[i], members.at(i));
      assertEq(accessManagerEnumerable.getRoleMember(roleId, i), members.at(i));
    }
  }

  function test_revokeRole() public {
    uint64 roleId = 1;
    address user1 = makeAddr('user1');
    address user2 = makeAddr('user2');
    address user3 = makeAddr('user3');

    vm.startPrank(ADMIN);
    accessManagerEnumerable.labelRole(roleId, 'test_role');
    accessManagerEnumerable.setGrantDelay(roleId, 0);
    accessManagerEnumerable.grantRole(roleId, user1, 0);
    accessManagerEnumerable.grantRole(roleId, user2, 0);
    accessManagerEnumerable.grantRole(roleId, user3, 0);

    assertEq(accessManagerEnumerable.getRoleMemberCount(roleId), 3);

    accessManagerEnumerable.revokeRole(roleId, user2);
    vm.stopPrank();

    assertEq(accessManagerEnumerable.getRoleMemberCount(roleId), 2);
    assertEq(accessManagerEnumerable.getRoleMember(roleId, 0), user1);
    assertEq(accessManagerEnumerable.getRoleMember(roleId, 1), user3);
    address[] memory roleMembers = accessManagerEnumerable.getRoleMembers(roleId);
    assertEq(roleMembers.length, 2);
    assertEq(roleMembers[0], user1);
    assertEq(roleMembers[1], user3);
  }

  function test_setTargetFunctionRole() public {
    uint64 roleId = 1;
    address target = makeAddr('target');
    bytes4 selector1 = bytes4(keccak256('functionOne()'));
    bytes4 selector2 = bytes4(keccak256('functionTwo()'));
    bytes4 selector3 = bytes4(keccak256('functionThree()'));

    bytes4[] memory selectors = new bytes4[](3);
    selectors[0] = selector1;
    selectors[1] = selector2;
    selectors[2] = selector3;

    vm.startPrank(ADMIN);
    accessManagerEnumerable.labelRole(roleId, 'test_role');

    accessManagerEnumerable.setTargetFunctionRole(target, selectors, roleId);
    vm.stopPrank();

    assertEq(accessManagerEnumerable.getRoleSelectorCount(roleId), 3);
    assertEq(accessManagerEnumerable.getRoleSelector(roleId, 0), selector1);
    assertEq(accessManagerEnumerable.getRoleSelector(roleId, 1), selector2);
    assertEq(accessManagerEnumerable.getRoleSelector(roleId, 2), selector3);
    bytes4[] memory roleSelectors = accessManagerEnumerable.getRoleSelectors(roleId);
    assertEq(roleSelectors.length, 3);
    assertEq(roleSelectors[0], selector1);
    assertEq(roleSelectors[1], selector2);
    assertEq(roleSelectors[2], selector3);
  }

  function test_setTargetFunctionRole_withReplace() public {
    uint64 roleId = 1;
    uint64 roleId2 = 2;
    address target = makeAddr('target');
    bytes4 selector1 = bytes4(keccak256('functionOne()'));
    bytes4 selector2 = bytes4(keccak256('functionTwo()'));
    bytes4 selector3 = bytes4(keccak256('functionThree()'));

    bytes4[] memory selectors = new bytes4[](3);
    selectors[0] = selector1;
    selectors[1] = selector2;
    selectors[2] = selector3;
    bytes4[] memory updatedSelectors = new bytes4[](1);
    updatedSelectors[0] = selector2;

    vm.startPrank(ADMIN);
    accessManagerEnumerable.labelRole(roleId, 'test_role');
    accessManagerEnumerable.labelRole(roleId2, 'test_role_2');

    accessManagerEnumerable.setTargetFunctionRole(target, selectors, roleId);

    assertEq(accessManagerEnumerable.getRoleSelectorCount(roleId), 3);
    assertEq(accessManagerEnumerable.getRoleSelector(roleId, 0), selector1);
    assertEq(accessManagerEnumerable.getRoleSelector(roleId, 1), selector2);
    assertEq(accessManagerEnumerable.getRoleSelector(roleId, 2), selector3);
    bytes4[] memory roleSelectors = accessManagerEnumerable.getRoleSelectors(roleId);
    assertEq(roleSelectors.length, 3);
    assertEq(roleSelectors[0], selector1);
    assertEq(roleSelectors[1], selector2);
    assertEq(roleSelectors[2], selector3);

    accessManagerEnumerable.setTargetFunctionRole(target, updatedSelectors, roleId2);
    vm.stopPrank();

    assertEq(accessManagerEnumerable.getRoleSelectorCount(roleId), 2);
    assertEq(accessManagerEnumerable.getRoleSelectorCount(roleId2), 1);
    assertEq(accessManagerEnumerable.getRoleSelector(roleId, 0), selector1);
    assertEq(accessManagerEnumerable.getRoleSelector(roleId, 1), selector3);
    assertEq(accessManagerEnumerable.getRoleSelector(roleId2, 0), selector2);
    bytes4[] memory roleSelectors1 = accessManagerEnumerable.getRoleSelectors(roleId);
    bytes4[] memory roleSelectors2 = accessManagerEnumerable.getRoleSelectors(roleId2);
    assertEq(roleSelectors1.length, 2);
    assertEq(roleSelectors2.length, 1);
    assertEq(roleSelectors1[0], selector1);
    assertEq(roleSelectors1[1], selector3);
    assertEq(roleSelectors2[0], selector2);
  }
}
