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

  // Defult Roles :
  uint64 constant ADMIN_ROLE = 0;

  // Custom Roles :
  uint64 constant NEW_ADMIN_ROLE = 1;
  uint64 constant NEW_ADMIN_ROLE_2 = 2;
  uint64 constant GUARDIAN_ADMIN_ROLE = 3;
  uint64 constant GUARDIAN_ROLE_1 = 111111111;
  uint64 constant GUARDIAN_ROLE_2 = 222222222;

  AccessManagerEnumerable internal accessManagerEnumerable;

  EnumerableSet.AddressSet members;
  EnumerableSet.UintSet internalRoles;
  EnumerableSet.UintSet internalAdminRoles;
  mapping(uint64 => EnumerableSet.UintSet) internalAdminOfRoles;

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

    assertEq(accessManagerEnumerable.getRole(0), roleId);
    assertEq(accessManagerEnumerable.getRoleCount(), 1);
    uint64[] memory roles = accessManagerEnumerable.getRoles(0, 2);
    assertEq(roles.length, 1);
    assertEq(roles[0], roleId);

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

    assertEq(accessManagerEnumerable.getRole(0), roleId);
    assertEq(accessManagerEnumerable.getRoleCount(), 1);
    roles = accessManagerEnumerable.getRoles(0, 1);
    assertEq(roles.length, 1);
    assertEq(roles[0], roleId);
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

    assertEq(accessManagerEnumerable.getRole(0), roleId);
    assertEq(accessManagerEnumerable.getRoleCount(), 1);
    uint64[] memory roles = accessManagerEnumerable.getRoles(0, 1);
    assertEq(roles.length, 1);
    assertEq(roles[0], roleId);
  }

  function test_setRoleAdmin_trackRolesAndTrackAdminRoles() public {
    assertEq(accessManagerEnumerable.getRoleCount(), 0);
    assertEq(accessManagerEnumerable.getAdminRoleCount(), 0);

    vm.startPrank(ADMIN);
    accessManagerEnumerable.setRoleAdmin(GUARDIAN_ROLE_1, GUARDIAN_ADMIN_ROLE);
    accessManagerEnumerable.setRoleAdmin(GUARDIAN_ROLE_2, GUARDIAN_ADMIN_ROLE);
    vm.stopPrank();

    uint64[] memory roleList = accessManagerEnumerable.getRoles(0, 2);
    assertEq(accessManagerEnumerable.getRoleCount(), 2);
    assertEq(roleList.length, 2);
    assertEq(roleList[0], GUARDIAN_ROLE_1);
    assertEq(roleList[1], GUARDIAN_ROLE_2);
    assertEq(accessManagerEnumerable.getRole(0), GUARDIAN_ROLE_1);
    assertEq(accessManagerEnumerable.getRole(1), GUARDIAN_ROLE_2);

    uint64[] memory adminRoleList = accessManagerEnumerable.getAdminRoles(0, 1);
    assertEq(accessManagerEnumerable.getAdminRoleCount(), 1);
    assertEq(adminRoleList.length, 1);
    assertEq(adminRoleList[0], GUARDIAN_ADMIN_ROLE);
    assertEq(accessManagerEnumerable.getAdminRole(0), GUARDIAN_ADMIN_ROLE);
    assertEq(accessManagerEnumerable.getRoleOfAdminRole(GUARDIAN_ADMIN_ROLE, 0), GUARDIAN_ROLE_1);
    assertEq(accessManagerEnumerable.getRoleOfAdminRole(GUARDIAN_ADMIN_ROLE, 1), GUARDIAN_ROLE_2);
  }

  function test_setRoleAdmin_trackAdminRoles() public {
    uint64 newRole1 = 111;
    uint64 newRole2 = 222;

    assertEq(accessManagerEnumerable.getAdminRoleCount(), 0);

    vm.startPrank(ADMIN);
    accessManagerEnumerable.setRoleAdmin(GUARDIAN_ROLE_1, NEW_ADMIN_ROLE);
    accessManagerEnumerable.setRoleAdmin(GUARDIAN_ROLE_2, ADMIN_ROLE);
    accessManagerEnumerable.setRoleAdmin(newRole1, NEW_ADMIN_ROLE);
    accessManagerEnumerable.setRoleAdmin(newRole2, NEW_ADMIN_ROLE_2);
    vm.stopPrank();

    uint64[] memory adminRoleList = accessManagerEnumerable.getAdminRoles(0, 2);
    assertEq(accessManagerEnumerable.getAdminRoleCount(), 2);
    assertEq(adminRoleList.length, 2);
    assertEq(adminRoleList[0], NEW_ADMIN_ROLE);
    assertEq(adminRoleList[1], NEW_ADMIN_ROLE_2);
    assertEq(accessManagerEnumerable.getAdminRole(0), NEW_ADMIN_ROLE);
    assertEq(accessManagerEnumerable.getAdminRole(1), NEW_ADMIN_ROLE_2);
  }

  function test_setRoleAdmin_trackAdminOfRoles() public {
    uint64 newRole1 = 111;
    uint64 newRole2 = 222;
    uint64 newRole3 = 333;

    assertEq(accessManagerEnumerable.getAdminRoleCount(), 0);

    vm.startPrank(ADMIN);
    accessManagerEnumerable.setRoleAdmin(GUARDIAN_ROLE_1, ADMIN_ROLE);
    accessManagerEnumerable.setRoleAdmin(GUARDIAN_ROLE_2, ADMIN_ROLE);
    accessManagerEnumerable.setRoleAdmin(newRole1, NEW_ADMIN_ROLE);
    accessManagerEnumerable.setRoleAdmin(newRole2, NEW_ADMIN_ROLE);
    accessManagerEnumerable.setRoleAdmin(newRole3, NEW_ADMIN_ROLE);
    vm.stopPrank();

    uint64[] memory adminRoleList = accessManagerEnumerable.getAdminRoles(0, 1);
    assertEq(accessManagerEnumerable.getAdminRoleCount(), 1);
    assertEq(adminRoleList.length, 1);
    assertEq(adminRoleList[0], NEW_ADMIN_ROLE);
    assertEq(accessManagerEnumerable.getAdminRole(0), NEW_ADMIN_ROLE);

    uint64[] memory adminOfRolesList = accessManagerEnumerable.getRolesOfAdminRole(
      NEW_ADMIN_ROLE,
      0,
      accessManagerEnumerable.getRoleOfAdminRoleCount(NEW_ADMIN_ROLE)
    );
    assertEq(accessManagerEnumerable.getRoleOfAdminRoleCount(NEW_ADMIN_ROLE), 3);
    assertEq(adminOfRolesList.length, 3);
    assertEq(adminOfRolesList[0], newRole1);
    assertEq(adminOfRolesList[1], newRole2);
    assertEq(adminOfRolesList[2], newRole3);
    assertEq(accessManagerEnumerable.getRoleOfAdminRole(NEW_ADMIN_ROLE, 0), newRole1);
    assertEq(accessManagerEnumerable.getRoleOfAdminRole(NEW_ADMIN_ROLE, 1), newRole2);
    assertEq(accessManagerEnumerable.getRoleOfAdminRole(NEW_ADMIN_ROLE, 2), newRole3);

    // should not track ADMIN_ROLE
    adminOfRolesList = accessManagerEnumerable.getRolesOfAdminRole(
      ADMIN_ROLE,
      0,
      accessManagerEnumerable.getRoleOfAdminRoleCount(ADMIN_ROLE)
    );
    assertEq(accessManagerEnumerable.getRoleOfAdminRoleCount(ADMIN_ROLE), 0);
    assertEq(adminOfRolesList.length, 0);
  }

  function test_setRoleAdmin_trackAdminOfRoles_changeAdminRole() public {
    uint64 newRole1 = 111;
    uint64 newRole2 = 222;
    uint64 newRole3 = 333;

    assertEq(accessManagerEnumerable.getAdminRoleCount(), 0);

    vm.startPrank(ADMIN);
    accessManagerEnumerable.setRoleAdmin(GUARDIAN_ROLE_1, ADMIN_ROLE);
    accessManagerEnumerable.setRoleAdmin(GUARDIAN_ROLE_2, ADMIN_ROLE);
    accessManagerEnumerable.setRoleAdmin(newRole1, NEW_ADMIN_ROLE);
    accessManagerEnumerable.setRoleAdmin(newRole2, NEW_ADMIN_ROLE);
    accessManagerEnumerable.setRoleAdmin(newRole3, NEW_ADMIN_ROLE);
    vm.stopPrank();

    uint64[] memory adminRoleList = accessManagerEnumerable.getAdminRoles(0, 1);
    assertEq(accessManagerEnumerable.getAdminRoleCount(), 1);
    assertEq(adminRoleList.length, 1);
    assertEq(adminRoleList[0], NEW_ADMIN_ROLE);
    assertEq(accessManagerEnumerable.getAdminRole(0), NEW_ADMIN_ROLE);

    uint64[] memory adminOfRolesList = accessManagerEnumerable.getRolesOfAdminRole(
      NEW_ADMIN_ROLE,
      0,
      accessManagerEnumerable.getRoleOfAdminRoleCount(NEW_ADMIN_ROLE)
    );
    assertEq(accessManagerEnumerable.getRoleOfAdminRoleCount(NEW_ADMIN_ROLE), 3);
    assertEq(adminOfRolesList.length, 3);
    assertEq(adminOfRolesList[0], newRole1);
    assertEq(adminOfRolesList[1], newRole2);
    assertEq(adminOfRolesList[2], newRole3);
    assertEq(accessManagerEnumerable.getRoleOfAdminRole(NEW_ADMIN_ROLE, 0), newRole1);
    assertEq(accessManagerEnumerable.getRoleOfAdminRole(NEW_ADMIN_ROLE, 1), newRole2);
    assertEq(accessManagerEnumerable.getRoleOfAdminRole(NEW_ADMIN_ROLE, 2), newRole3);

    // should not track ADMIN_ROLE
    adminOfRolesList = accessManagerEnumerable.getRolesOfAdminRole(
      ADMIN_ROLE,
      0,
      accessManagerEnumerable.getRoleOfAdminRoleCount(ADMIN_ROLE)
    );
    assertEq(accessManagerEnumerable.getRoleOfAdminRoleCount(ADMIN_ROLE), 0);
    assertEq(adminOfRolesList.length, 0);

    vm.startPrank(ADMIN);
    accessManagerEnumerable.setRoleAdmin(newRole2, ADMIN_ROLE);
    vm.stopPrank();

    adminRoleList = accessManagerEnumerable.getAdminRoles(0, 1);
    assertEq(accessManagerEnumerable.getAdminRoleCount(), 1);
    assertEq(adminRoleList.length, 1);
    assertEq(adminRoleList[0], NEW_ADMIN_ROLE);
    assertEq(accessManagerEnumerable.getAdminRole(0), NEW_ADMIN_ROLE);

    adminOfRolesList = accessManagerEnumerable.getRolesOfAdminRole(
      NEW_ADMIN_ROLE,
      0,
      accessManagerEnumerable.getRoleOfAdminRoleCount(NEW_ADMIN_ROLE)
    );
    assertEq(accessManagerEnumerable.getRoleOfAdminRoleCount(NEW_ADMIN_ROLE), 2);
    assertEq(adminOfRolesList.length, 2);
    assertEq(adminOfRolesList[0], newRole1);
    assertEq(adminOfRolesList[1], newRole3);
    assertEq(accessManagerEnumerable.getRoleOfAdminRole(NEW_ADMIN_ROLE, 0), newRole1);
    assertEq(accessManagerEnumerable.getRoleOfAdminRole(NEW_ADMIN_ROLE, 1), newRole3);

    // should not track ADMIN_ROLE
    adminOfRolesList = accessManagerEnumerable.getRolesOfAdminRole(
      ADMIN_ROLE,
      0,
      accessManagerEnumerable.getRoleOfAdminRoleCount(ADMIN_ROLE)
    );
    assertEq(accessManagerEnumerable.getRoleOfAdminRoleCount(ADMIN_ROLE), 0);
    assertEq(adminOfRolesList.length, 0);
  }

  function test_setRoleGuardian_trackRoles() public {
    uint64 newRole1 = 111;
    uint64 newRole2 = 222;
    uint64 newRole3 = 333;
    assertEq(accessManagerEnumerable.getAdminRoleCount(), 0);

    vm.startPrank(ADMIN);
    accessManagerEnumerable.setRoleGuardian(newRole1, GUARDIAN_ROLE_1);
    accessManagerEnumerable.setRoleGuardian(newRole2, GUARDIAN_ROLE_2);
    accessManagerEnumerable.setRoleGuardian(newRole3, GUARDIAN_ROLE_1);
    vm.stopPrank();

    uint64[] memory roleList = accessManagerEnumerable.getRoles(0, 3);
    assertEq(accessManagerEnumerable.getRoleCount(), 3);
    assertEq(roleList.length, 3);
    assertEq(roleList[0], newRole1);
    assertEq(roleList[1], newRole2);
    assertEq(roleList[2], newRole3);
    assertEq(accessManagerEnumerable.getRole(0), newRole1);
    assertEq(accessManagerEnumerable.getRole(1), newRole2);
    assertEq(accessManagerEnumerable.getRole(2), newRole3);
  }

  function test_setRoleAdmin_fuzz_trackRolesAndTrackAdminRoles_multipleRoles(
    uint256 rolesCount
  ) public {
    rolesCount = bound(rolesCount, 1, 15);

    vm.startPrank(ADMIN);

    for (uint256 i = 0; i < rolesCount; i++) {
      uint64 roleId = _getRandomRoleId();
      internalRoles.add(roleId);
      internalAdminOfRoles[NEW_ADMIN_ROLE].add(uint256(roleId));
      accessManagerEnumerable.setRoleAdmin(roleId, NEW_ADMIN_ROLE);
    }
    vm.stopPrank();

    uint64[] memory roleList = accessManagerEnumerable.getRoles(
      0,
      accessManagerEnumerable.getRoleCount()
    );
    assertEq(accessManagerEnumerable.getRoleCount(), rolesCount);
    assertEq(roleList.length, rolesCount);

    for (uint256 i = 0; i < rolesCount; i++) {
      assertEq(roleList[i], internalRoles.at(i));
      assertEq(accessManagerEnumerable.getRole(i), internalRoles.at(i));
    }

    uint64[] memory adminOfRolesList = accessManagerEnumerable.getRolesOfAdminRole(
      NEW_ADMIN_ROLE,
      0,
      accessManagerEnumerable.getRoleOfAdminRoleCount(NEW_ADMIN_ROLE)
    );
    assertEq(
      accessManagerEnumerable.getRoleOfAdminRoleCount(NEW_ADMIN_ROLE),
      internalAdminOfRoles[NEW_ADMIN_ROLE].length()
    );
    assertEq(adminOfRolesList.length, internalAdminOfRoles[NEW_ADMIN_ROLE].length());
    for (uint256 i = 0; i < internalAdminOfRoles[NEW_ADMIN_ROLE].length(); i++) {
      assertEq(adminOfRolesList[i], uint64(internalAdminOfRoles[NEW_ADMIN_ROLE].at(i)));
      assertEq(
        accessManagerEnumerable.getRoleOfAdminRole(NEW_ADMIN_ROLE, i),
        uint64(internalAdminOfRoles[NEW_ADMIN_ROLE].at(i))
      );
    }
  }

  function test_setRoleAdmin_fuzz_trackAdminRoles_multipleRoles_multipleAdmins(
    uint256 rolesCount
  ) public {
    rolesCount = bound(rolesCount, 1, 15);

    vm.startPrank(ADMIN);

    for (uint256 i = 0; i < rolesCount; i++) {
      uint64 roleId = _getRandomRoleId();
      uint64 adminRoleId = _getRandomAdminRoleId();
      internalRoles.add(roleId);
      if (adminRoleId != ADMIN_ROLE) {
        internalAdminRoles.add(adminRoleId);
        internalAdminOfRoles[adminRoleId].add(uint256(roleId));
      }
      accessManagerEnumerable.setRoleAdmin(roleId, adminRoleId);
    }
    vm.stopPrank();

    uint64[] memory roleList = accessManagerEnumerable.getRoles(
      0,
      accessManagerEnumerable.getRoleCount()
    );
    assertEq(accessManagerEnumerable.getRoleCount(), rolesCount);
    assertEq(roleList.length, rolesCount);

    for (uint256 i = 0; i < rolesCount; i++) {
      assertEq(roleList[i], internalRoles.at(i));
      assertEq(accessManagerEnumerable.getRole(i), internalRoles.at(i));
    }

    uint64[] memory adminRoleList = accessManagerEnumerable.getAdminRoles(
      0,
      accessManagerEnumerable.getAdminRoleCount()
    );
    assertEq(accessManagerEnumerable.getAdminRoleCount(), internalAdminRoles.length());
    assertEq(adminRoleList.length, internalAdminRoles.length());

    for (uint256 i = 0; i < internalAdminRoles.length(); i++) {
      uint64 adminRoleId = uint64(internalAdminRoles.at(i));
      assertEq(adminRoleList[i], adminRoleId);
      assertEq(accessManagerEnumerable.getAdminRole(i), adminRoleId);

      uint64[] memory adminOfRolesList = accessManagerEnumerable.getRolesOfAdminRole(
        adminRoleId,
        0,
        accessManagerEnumerable.getRoleOfAdminRoleCount(adminRoleId)
      );
      assertEq(
        accessManagerEnumerable.getRoleOfAdminRoleCount(adminRoleId),
        internalAdminOfRoles[adminRoleId].length()
      );
      assertEq(adminOfRolesList.length, internalAdminOfRoles[adminRoleId].length());
      for (uint256 j = 0; j < internalAdminOfRoles[adminRoleId].length(); j++) {
        assertEq(adminOfRolesList[j], uint64(internalAdminOfRoles[adminRoleId].at(j)));
        assertEq(
          accessManagerEnumerable.getRoleOfAdminRole(adminRoleId, j),
          uint64(internalAdminOfRoles[adminRoleId].at(j))
        );
      }
    }

    // should not track ADMIN_ROLE
    assertEq(accessManagerEnumerable.getRoleOfAdminRoleCount(ADMIN_ROLE), 0);
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

  function test_renounceRole() public {
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
    vm.stopPrank();

    assertEq(accessManagerEnumerable.getRoleMemberCount(roleId), 3);

    vm.prank(user2);
    accessManagerEnumerable.renounceRole(roleId, user2);

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

  function test_revokeRole_shouldNotTrack() public {
    uint64 roleId = 1;
    address user1 = makeAddr('user1');

    (bool isMember, ) = accessManagerEnumerable.hasRole(roleId, user1);
    assertFalse(isMember);
    assertEq(accessManagerEnumerable.getRoleMemberCount(roleId), 0);

    vm.prank(ADMIN);
    accessManagerEnumerable.revokeRole(roleId, user1);

    assertEq(accessManagerEnumerable.getRoleMemberCount(roleId), 0);
    assertEq(accessManagerEnumerable.getRoleMembers(roleId, 0, 1).length, 0);

    (isMember, ) = accessManagerEnumerable.hasRole(roleId, user1);
    assertFalse(isMember);
  }

  function test_renounceRole_shouldNotTrack() public {
    uint64 roleId = 1;
    address user1 = makeAddr('user1');

    (bool isMember, ) = accessManagerEnumerable.hasRole(roleId, user1);
    assertFalse(isMember);
    assertEq(accessManagerEnumerable.getRoleMemberCount(roleId), 0);

    vm.prank(user1);
    accessManagerEnumerable.renounceRole(roleId, user1);

    assertEq(accessManagerEnumerable.getRoleMemberCount(roleId), 0);
    assertEq(accessManagerEnumerable.getRoleMembers(roleId, 0, 1).length, 0);

    (isMember, ) = accessManagerEnumerable.hasRole(roleId, user1);
    assertFalse(isMember);
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

  function _getRandomAdminRoleId() internal returns (uint64) {
    uint256 adminRoleId = vm.randomUint(0, 4);
    return uint64(adminRoleId);
  }

  function _getRandomRoleId() internal returns (uint64) {
    uint256 roleId = vm.randomUint(5, type(uint64).max - 1);
    return uint64(roleId);
  }
}
