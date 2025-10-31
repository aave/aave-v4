// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {AccessManagerEnumerable} from 'src/access/AccessManagerEnumerable.sol';

contract AccessManagerEnumerableTest is Test {
  address internal ADMIN = makeAddr('ADMIN');

  AccessManagerEnumerable internal accessManagerEnumerable;

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
  }

  function test_grantRole_fuzz(uint64 roleId, address[] memory members) public {
    vm.assume(members.length > 0 && members.length <= 10);
    vm.assume(
      roleId != accessManagerEnumerable.PUBLIC_ROLE() &&
        roleId != accessManagerEnumerable.ADMIN_ROLE()
    );

    vm.startPrank(ADMIN);
    accessManagerEnumerable.labelRole(roleId, 'test_role');
    accessManagerEnumerable.setGrantDelay(roleId, 0);

    uint256 membersLength = members.length;
    for (uint256 i = 0; i < membersLength; i++) {
      address member = members[i];
      vm.assume(member != address(0));
      accessManagerEnumerable.grantRole(roleId, member, 0);
    }

    address[] memory roleMembers = accessManagerEnumerable.getRoleMembers(roleId);
    assertEq(accessManagerEnumerable.getRoleMemberCount(roleId), membersLength);
    assertEq(roleMembers.length, membersLength);

    for (uint256 i = 0; i < membersLength; i++) {
      assertEq(roleMembers[i], members[i]);
      assertEq(accessManagerEnumerable.getRoleMember(roleId, i), members[i]);
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

    assertEq(accessManagerEnumerable.getRoleMemberCount(roleId), 2);
    assertEq(accessManagerEnumerable.getRoleMember(roleId, 0), user1);
    assertEq(accessManagerEnumerable.getRoleMember(roleId, 1), user3);
    address[] memory roleMembers = accessManagerEnumerable.getRoleMembers(roleId);
    assertEq(roleMembers.length, 2);
    assertEq(roleMembers[0], user1);
    assertEq(roleMembers[1], user3);
  }
}
