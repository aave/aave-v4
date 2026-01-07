// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';
import {AccessManagerEnumerable} from 'src/access/AccessManagerEnumerable.sol';

contract AccessManagerEnumerableTest is Test {
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableSet for EnumerableSet.UintSet;

  address internal ADMIN = makeAddr('ADMIN');

  uint64 constant ADMIN_ROLE = 0;
  uint64 constant GUARDIAN_ROLE_1 = 111111111;
  uint64 constant GUARDIAN_ROLE_2 = 222222222;

  AccessManagerEnumerable internal accessManagerEnumerable;

  EnumerableSet.AddressSet members;
  EnumerableSet.UintSet internalRoles;

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
    address[] memory roleMembers = accessManagerEnumerable.getRoleMembers(
      roleId,
      0,
      accessManagerEnumerable.getRoleMemberCount(roleId)
    );
    assertEq(roleMembers.length, 1);
    assertEq(roleMembers[0], user1);

    assertEq(accessManagerEnumerable.getRole(1), roleId);
    assertEq(accessManagerEnumerable.getRoleCount(), 2);
    uint64[] memory roles = accessManagerEnumerable.getRoles(0, 2);
    assertEq(roles.length, 2);
    assertEq(roles[1], roleId);

    accessManagerEnumerable.grantRole(roleId, user2, 0);
    assertEq(accessManagerEnumerable.getRoleMember(roleId, 1), user2);
    assertEq(accessManagerEnumerable.getRoleMemberCount(roleId), 2);
    roleMembers = accessManagerEnumerable.getRoleMembers(
      roleId,
      0,
      accessManagerEnumerable.getRoleMemberCount(roleId)
    );
    assertEq(roleMembers.length, 2);
    assertEq(roleMembers[0], user1);
    assertEq(roleMembers[1], user2);

    assertEq(accessManagerEnumerable.getRole(1), roleId);
    assertEq(accessManagerEnumerable.getRoleCount(), 2);
    roles = accessManagerEnumerable.getRoles(0, 2);
    assertEq(roles.length, 2);
    assertEq(roles[1], roleId);
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

    address[] memory roleMembers = accessManagerEnumerable.getRoleMembers(
      roleId,
      0,
      accessManagerEnumerable.getRoleMemberCount(roleId)
    );
    assertEq(accessManagerEnumerable.getRoleMemberCount(roleId), membersCount);
    assertEq(roleMembers.length, membersCount);

    for (uint256 i = 0; i < membersCount; i++) {
      assertEq(roleMembers[i], members.at(i));
      assertEq(accessManagerEnumerable.getRoleMember(roleId, i), members.at(i));
    }

    assertEq(accessManagerEnumerable.getRole(1), roleId);
    assertEq(accessManagerEnumerable.getRoleCount(), 2);
    uint64[] memory roles = accessManagerEnumerable.getRoles(0, 2);
    assertEq(roles.length, 2);
    assertEq(roles[1], roleId);
  }

  function test_setRoleAdmin_trackRoles() public {
    assertLe(accessManagerEnumerable.getRoleCount(), 1);
    assertEq(accessManagerEnumerable.getRole(0), ADMIN_ROLE);

    vm.startPrank(ADMIN);
    accessManagerEnumerable.setRoleAdmin(GUARDIAN_ROLE_1, ADMIN_ROLE);
    accessManagerEnumerable.setRoleAdmin(GUARDIAN_ROLE_2, ADMIN_ROLE);
    vm.stopPrank();

    uint64[] memory roleList = accessManagerEnumerable.getRoles(0, 3);
    assertLe(accessManagerEnumerable.getRoleCount(), 3);
    assertEq(roleList.length, 3);
    assertEq(roleList[0], ADMIN_ROLE);
    assertEq(roleList[1], GUARDIAN_ROLE_1);
    assertEq(roleList[2], GUARDIAN_ROLE_2);
    assertEq(accessManagerEnumerable.getRole(0), ADMIN_ROLE);
    assertEq(accessManagerEnumerable.getRole(1), GUARDIAN_ROLE_1);
    assertEq(accessManagerEnumerable.getRole(2), GUARDIAN_ROLE_2);
  }

  function test_setRoleGuardian_trackRoles() public {
    uint64 new_role_1 = 111;
    uint64 new_role_2 = 222;
    uint64 new_role_3 = 333;
    assertLe(accessManagerEnumerable.getRoleCount(), 1);
    assertEq(accessManagerEnumerable.getRole(0), ADMIN_ROLE);

    vm.startPrank(ADMIN);
    accessManagerEnumerable.setRoleGuardian(new_role_1, GUARDIAN_ROLE_1);
    accessManagerEnumerable.setRoleGuardian(new_role_2, GUARDIAN_ROLE_2);
    accessManagerEnumerable.setRoleGuardian(new_role_3, GUARDIAN_ROLE_1);
    vm.stopPrank();

    uint64[] memory roleList = accessManagerEnumerable.getRoles(0, 4);
    assertLe(accessManagerEnumerable.getRoleCount(), 4);
    assertEq(roleList.length, 4);
    assertEq(roleList[0], ADMIN_ROLE);
    assertEq(roleList[1], new_role_1);
    assertEq(roleList[2], new_role_2);
    assertEq(roleList[3], new_role_3);
    assertEq(accessManagerEnumerable.getRole(0), ADMIN_ROLE);
    assertEq(accessManagerEnumerable.getRole(1), new_role_1);
    assertEq(accessManagerEnumerable.getRole(2), new_role_2);
    assertEq(accessManagerEnumerable.getRole(3), new_role_3);
  }

  function test_setRoleAdmin_fuzz_trackRoles_multipleRoles(uint256 rolesCount) public {
    rolesCount = bound(rolesCount, 1, 15);
    uint256 expectedTotalRoleCount = rolesCount + 1; // +1 for ADMIN_ROLE

    vm.startPrank(ADMIN);

    for (uint256 i = 0; i < rolesCount; i++) {
      uint64 roleId = _getRandomRoleId();
      if (!internalRoles.contains(roleId)) {
        internalRoles.add(roleId);
      }
      accessManagerEnumerable.setRoleAdmin(roleId, ADMIN_ROLE);
    }
    vm.stopPrank();

    uint64[] memory roleList = accessManagerEnumerable.getRoles(
      0,
      accessManagerEnumerable.getRoleCount()
    );
    assertLe(accessManagerEnumerable.getRoleCount(), expectedTotalRoleCount);
    assertEq(roleList.length, expectedTotalRoleCount);

    assertEq(roleList[0], ADMIN_ROLE);
    assertEq(accessManagerEnumerable.getRole(0), ADMIN_ROLE);
    for (uint256 i = 1; i < rolesCount; i++) {
      assertEq(roleList[i], internalRoles.at(i - 1));
      assertEq(accessManagerEnumerable.getRole(i), internalRoles.at(i - 1));
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
    address[] memory roleMembers = accessManagerEnumerable.getRoleMembers(
      roleId,
      0,
      accessManagerEnumerable.getRoleMemberCount(roleId)
    );
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

    assertEq(accessManagerEnumerable.getRoleTargetSelectorCount(roleId, target), 3);
    assertEq(accessManagerEnumerable.getRoleTargetSelector(roleId, target, 0), selector1);
    assertEq(accessManagerEnumerable.getRoleTargetSelector(roleId, target, 1), selector2);
    assertEq(accessManagerEnumerable.getRoleTargetSelector(roleId, target, 2), selector3);
    bytes4[] memory roleSelectors = accessManagerEnumerable.getRoleTargetSelectors(
      roleId,
      target,
      0,
      accessManagerEnumerable.getRoleTargetSelectorCount(roleId, target)
    );
    assertEq(roleSelectors.length, 3);
    assertEq(roleSelectors[0], selector1);
    assertEq(roleSelectors[1], selector2);
    assertEq(roleSelectors[2], selector3);

    assertEq(accessManagerEnumerable.getRoleTargetCount(roleId), 1);
    assertEq(accessManagerEnumerable.getRoleTarget(roleId, 0), target);
    address[] memory roleTargets = accessManagerEnumerable.getRoleTargets(
      roleId,
      0,
      accessManagerEnumerable.getRoleTargetCount(roleId)
    );
    assertEq(roleTargets.length, 1);
    assertEq(roleTargets[0], target);
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

    assertEq(accessManagerEnumerable.getRoleTargetSelectorCount(roleId, target), 3);
    assertEq(accessManagerEnumerable.getRoleTargetSelector(roleId, target, 0), selector1);
    assertEq(accessManagerEnumerable.getRoleTargetSelector(roleId, target, 1), selector2);
    assertEq(accessManagerEnumerable.getRoleTargetSelector(roleId, target, 2), selector3);
    bytes4[] memory roleSelectors = accessManagerEnumerable.getRoleTargetSelectors(
      roleId,
      target,
      0,
      3
    );
    assertEq(roleSelectors.length, 3);
    assertEq(roleSelectors[0], selector1);
    assertEq(roleSelectors[1], selector2);
    assertEq(roleSelectors[2], selector3);

    assertEq(accessManagerEnumerable.getRoleTargetCount(roleId), 1);
    assertEq(accessManagerEnumerable.getRoleTarget(roleId, 0), target);
    address[] memory roleTargets = accessManagerEnumerable.getRoleTargets(
      roleId,
      0,
      accessManagerEnumerable.getRoleTargetCount(roleId)
    );
    assertEq(roleTargets.length, 1);
    assertEq(roleTargets[0], target);

    accessManagerEnumerable.setTargetFunctionRole(target, updatedSelectors, roleId2);
    vm.stopPrank();

    assertEq(accessManagerEnumerable.getRoleTargetSelectorCount(roleId, target), 2);
    assertEq(accessManagerEnumerable.getRoleTargetSelectorCount(roleId2, target), 1);
    assertEq(accessManagerEnumerable.getRoleTargetSelector(roleId, target, 0), selector1);
    assertEq(accessManagerEnumerable.getRoleTargetSelector(roleId, target, 1), selector3);
    assertEq(accessManagerEnumerable.getRoleTargetSelector(roleId2, target, 0), selector2);
    {
      bytes4[] memory roleSelectors1 = accessManagerEnumerable.getRoleTargetSelectors(
        roleId,
        target,
        0,
        3
      );
      bytes4[] memory roleSelectors2 = accessManagerEnumerable.getRoleTargetSelectors(
        roleId2,
        target,
        0,
        3
      );
      assertEq(roleSelectors1.length, 2);
      assertEq(roleSelectors2.length, 1);
      assertEq(roleSelectors1[0], selector1);
      assertEq(roleSelectors1[1], selector3);
      assertEq(roleSelectors2[0], selector2);
    }

    assertEq(accessManagerEnumerable.getRoleTargetCount(roleId), 1);
    assertEq(accessManagerEnumerable.getRoleTarget(roleId, 0), target);
    roleTargets = accessManagerEnumerable.getRoleTargets(
      roleId,
      0,
      accessManagerEnumerable.getRoleTargetCount(roleId)
    );
    assertEq(roleTargets.length, 1);
    assertEq(roleTargets[0], target);
  }

  function test_setTargetFunctionRole_multipleTargets() public {
    uint64 roleId = 1;
    address target1 = makeAddr('target1');
    address target2 = makeAddr('target2');
    address target3 = makeAddr('target3');
    bytes4 selector1 = bytes4(keccak256('functionOne()'));
    bytes4 selector2 = bytes4(keccak256('functionTwo()'));
    bytes4 selector3 = bytes4(keccak256('functionThree()'));

    address[] memory targets = new address[](3);
    targets[0] = target1;
    targets[1] = target2;
    targets[2] = target3;

    bytes4[] memory selectors = new bytes4[](3);
    selectors[0] = selector1;
    selectors[1] = selector2;
    selectors[2] = selector3;

    vm.startPrank(ADMIN);
    accessManagerEnumerable.setTargetFunctionRole(target1, selectors, roleId);
    accessManagerEnumerable.setTargetFunctionRole(target2, selectors, roleId);
    accessManagerEnumerable.setTargetFunctionRole(target3, selectors, roleId);
    vm.stopPrank();

    assertEq(accessManagerEnumerable.getRoleTargetCount(roleId), 3);
    assertEq(accessManagerEnumerable.getRoleTarget(roleId, 0), target1);
    assertEq(accessManagerEnumerable.getRoleTarget(roleId, 1), target2);
    assertEq(accessManagerEnumerable.getRoleTarget(roleId, 2), target3);
    address[] memory roleTargets = accessManagerEnumerable.getRoleTargets(
      roleId,
      0,
      accessManagerEnumerable.getRoleTargetCount(roleId)
    );
    assertEq(roleTargets.length, 3);
    assertEq(roleTargets[0], target1);
    assertEq(roleTargets[1], target2);
    assertEq(roleTargets[2], target3);
  }

  function test_setTargetFunctionRole_removeTarget() public {
    uint64 roleId = 1;
    uint64 otherRoleId = 2;
    address target1 = makeAddr('target1');
    address target2 = makeAddr('target2');
    address target3 = makeAddr('target3');
    bytes4 selector1 = bytes4(keccak256('functionOne()'));
    bytes4 selector2 = bytes4(keccak256('functionTwo()'));

    address[] memory targets = new address[](3);
    targets[0] = target1;
    targets[1] = target2;
    targets[2] = target3;

    bytes4[] memory selectors = new bytes4[](2);
    selectors[0] = selector1;
    selectors[1] = selector2;

    vm.startPrank(ADMIN);
    accessManagerEnumerable.setTargetFunctionRole(target1, selectors, roleId);
    accessManagerEnumerable.setTargetFunctionRole(target2, selectors, roleId);
    accessManagerEnumerable.setTargetFunctionRole(target3, selectors, roleId);
    vm.stopPrank();

    assertEq(accessManagerEnumerable.getRoleTargetCount(roleId), 3);
    assertEq(accessManagerEnumerable.getRoleTarget(roleId, 0), target1);
    assertEq(accessManagerEnumerable.getRoleTarget(roleId, 1), target2);
    assertEq(accessManagerEnumerable.getRoleTarget(roleId, 2), target3);
    address[] memory roleTargets = accessManagerEnumerable.getRoleTargets(
      roleId,
      0,
      accessManagerEnumerable.getRoleTargetCount(roleId)
    );
    assertEq(roleTargets.length, 3);
    assertEq(roleTargets[0], target1);
    assertEq(roleTargets[1], target2);
    assertEq(roleTargets[2], target3);

    vm.startPrank(ADMIN);
    accessManagerEnumerable.setTargetFunctionRole(target2, selectors, otherRoleId);
    vm.stopPrank();

    assertEq(accessManagerEnumerable.getRoleTargetCount(roleId), 2);
    assertEq(accessManagerEnumerable.getRoleTarget(roleId, 0), target1);
    assertEq(accessManagerEnumerable.getRoleTarget(roleId, 1), target3);
    roleTargets = accessManagerEnumerable.getRoleTargets(
      roleId,
      0,
      accessManagerEnumerable.getRoleTargetCount(roleId)
    );
    assertEq(roleTargets.length, 2);
    assertEq(roleTargets[0], target1);
    assertEq(roleTargets[1], target3);
  }

  function test_setTargetFunctionRole_skipAddToAdminRole() public {
    uint64 roleId = accessManagerEnumerable.ADMIN_ROLE();
    address target = makeAddr('target');
    bytes4 selector = bytes4(keccak256('function()'));

    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = selector;

    vm.prank(ADMIN);
    accessManagerEnumerable.setTargetFunctionRole(target, selectors, roleId);

    // should not track selectors for ADMIN_ROLE
    assertEq(accessManagerEnumerable.getRoleTargetSelectorCount(roleId, target), 0);
  }

  function test_getRoleMembers_fuzz(uint256 startIndex, uint256 endIndex) public {
    startIndex = bound(startIndex, 0, 14);
    endIndex = bound(endIndex, startIndex + 1, 15);
    uint64 roleId = 1;

    vm.startPrank(ADMIN);
    accessManagerEnumerable.labelRole(roleId, 'test_role');
    accessManagerEnumerable.setGrantDelay(roleId, 0);

    for (uint256 i = 0; i < 15; i++) {
      address member;
      while (member == address(0) || members.contains(member)) {
        member = vm.randomAddress();
      }
      members.add(member);
      accessManagerEnumerable.grantRole(roleId, member, 0);
    }
    vm.stopPrank();

    address[] memory roleMembers = accessManagerEnumerable.getRoleMembers(
      roleId,
      startIndex,
      endIndex
    );
    assertEq(roleMembers.length, endIndex - startIndex);
    for (uint256 i = startIndex; i < endIndex; i++) {
      assertEq(roleMembers[i - startIndex], members.at(i));
    }
  }

  function test_getRoleTargetSelectors_fuzz(uint256 startIndex, uint256 endIndex) public {
    startIndex = bound(startIndex, 0, 14);
    endIndex = bound(endIndex, startIndex + 1, 15);
    uint64 roleId = 1;
    address target = makeAddr('target');

    bytes4[] memory selectors = new bytes4[](15);
    for (uint256 i = 0; i < 15; i++) {
      selectors[i] = bytes4(keccak256(abi.encodePacked('function', i, '()')));
    }

    vm.startPrank(ADMIN);
    accessManagerEnumerable.labelRole(roleId, 'test_role');

    accessManagerEnumerable.setTargetFunctionRole(target, selectors, roleId);
    vm.stopPrank();

    bytes4[] memory roleSelectors = accessManagerEnumerable.getRoleTargetSelectors(
      roleId,
      target,
      startIndex,
      endIndex
    );
    assertEq(roleSelectors.length, endIndex - startIndex);
    for (uint256 i = startIndex; i < endIndex; i++) {
      assertEq(roleSelectors[i - startIndex], selectors[i]);
    }

    assertEq(accessManagerEnumerable.getRoleTargetCount(roleId), 1);
    assertEq(accessManagerEnumerable.getRoleTarget(roleId, 0), target);
    address[] memory roleTargets = accessManagerEnumerable.getRoleTargets(
      roleId,
      0,
      accessManagerEnumerable.getRoleTargetCount(roleId)
    );
    assertEq(roleTargets.length, 1);
    assertEq(roleTargets[0], target);
  }

  function _getRandomRoleId() internal returns (uint64) {
    uint256 roleId = vm.randomUint(1, type(uint64).max - 1);
    return uint64(roleId);
  }
}
