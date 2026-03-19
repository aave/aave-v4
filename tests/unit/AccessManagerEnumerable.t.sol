// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';
import {
  AccessManagerEnumerable,
  IAccessManagerEnumerable
} from 'src/access/AccessManagerEnumerable.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';

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

    assertTrue(accessManagerEnumerable.isRole(roleId));
    assertFalse(accessManagerEnumerable.isRole(999));
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

    assertTrue(accessManagerEnumerable.isRole(GUARDIAN_ROLE_1));
    assertTrue(accessManagerEnumerable.isRole(GUARDIAN_ROLE_2));
    assertTrue(accessManagerEnumerable.isAdminRole(GUARDIAN_ADMIN_ROLE));
    assertFalse(accessManagerEnumerable.isAdminRole(ADMIN_ROLE));
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

    assertTrue(accessManagerEnumerable.isAdminRole(NEW_ADMIN_ROLE));
    assertTrue(accessManagerEnumerable.isAdminRole(NEW_ADMIN_ROLE_2));
    assertFalse(accessManagerEnumerable.isAdminRole(ADMIN_ROLE));
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
    assertEq(accessManagerEnumerable.getRoleCount(), 0);

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

    assertTrue(accessManagerEnumerable.isRole(newRole1));
    assertTrue(accessManagerEnumerable.isRole(newRole2));
    assertTrue(accessManagerEnumerable.isRole(newRole3));
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

    assertEq(accessManagerEnumerable.getRoleCount(), 0);

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

    assertEq(accessManagerEnumerable.getRoleOfTargetSelector(target, selector1), roleId);
    assertEq(accessManagerEnumerable.getRoleOfTargetSelector(target, selector2), roleId);
    assertEq(accessManagerEnumerable.getRoleOfTargetSelector(target, selector3), roleId);

    assertEq(accessManagerEnumerable.getRoleTargetCount(roleId), 1);
    assertEq(accessManagerEnumerable.getRoleTarget(roleId, 0), target);
    address[] memory roleTargets = accessManagerEnumerable.getRoleTargets(
      roleId,
      0,
      accessManagerEnumerable.getRoleTargetCount(roleId)
    );
    assertEq(roleTargets.length, 1);
    assertEq(roleTargets[0], target);

    uint64[] memory roleList = accessManagerEnumerable.getRoles(0, 1);
    assertEq(accessManagerEnumerable.getRoleCount(), 1);
    assertEq(roleList.length, 1);
    assertEq(roleList[0], roleId);
    assertEq(accessManagerEnumerable.getRole(0), roleId);

    assertTrue(accessManagerEnumerable.isRole(roleId));
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

    assertEq(accessManagerEnumerable.getRoleCount(), 0);

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

    assertEq(accessManagerEnumerable.getRoleOfTargetSelector(target, selector1), roleId);
    assertEq(accessManagerEnumerable.getRoleOfTargetSelector(target, selector2), roleId2);
    assertEq(accessManagerEnumerable.getRoleOfTargetSelector(target, selector3), roleId);

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

    uint64[] memory roleList = accessManagerEnumerable.getRoles(0, 2);
    assertEq(accessManagerEnumerable.getRoleCount(), 2);
    assertEq(roleList.length, 2);
    assertEq(roleList[0], roleId);
    assertEq(roleList[1], roleId2);
    assertEq(accessManagerEnumerable.getRole(0), roleId);
    assertEq(accessManagerEnumerable.getRole(1), roleId2);
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

    assertEq(accessManagerEnumerable.getRoleCount(), 0);

    vm.startPrank(ADMIN);
    accessManagerEnumerable.setTargetFunctionRole(target1, selectors, roleId);
    accessManagerEnumerable.setTargetFunctionRole(target2, selectors, roleId);
    accessManagerEnumerable.setTargetFunctionRole(target3, selectors, roleId);
    vm.stopPrank();

    for (uint256 i = 0; i < 3; i++) {
      assertEq(accessManagerEnumerable.getRoleOfTargetSelector(targets[i], selector1), roleId);
      assertEq(accessManagerEnumerable.getRoleOfTargetSelector(targets[i], selector2), roleId);
      assertEq(accessManagerEnumerable.getRoleOfTargetSelector(targets[i], selector3), roleId);
    }

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

    uint64[] memory roleList = accessManagerEnumerable.getRoles(0, 1);
    assertEq(accessManagerEnumerable.getRoleCount(), 1);
    assertEq(roleList.length, 1);
    assertEq(roleList[0], roleId);
    assertEq(accessManagerEnumerable.getRole(0), roleId);
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

    assertEq(accessManagerEnumerable.getRoleOfTargetSelector(target1, selector1), roleId);
    assertEq(accessManagerEnumerable.getRoleOfTargetSelector(target1, selector2), roleId);
    assertEq(accessManagerEnumerable.getRoleOfTargetSelector(target2, selector1), otherRoleId);
    assertEq(accessManagerEnumerable.getRoleOfTargetSelector(target2, selector2), otherRoleId);
    assertEq(accessManagerEnumerable.getRoleOfTargetSelector(target3, selector1), roleId);
    assertEq(accessManagerEnumerable.getRoleOfTargetSelector(target3, selector2), roleId);

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

    uint64[] memory roleList = accessManagerEnumerable.getRoles(0, 2);
    assertEq(accessManagerEnumerable.getRoleCount(), 2);
    assertEq(roleList.length, 2);
    assertEq(roleList[0], roleId);
    assertEq(roleList[1], otherRoleId);
    assertEq(accessManagerEnumerable.getRole(0), roleId);
    assertEq(accessManagerEnumerable.getRole(1), otherRoleId);
  }

  function test_setTargetFunctionRole_skipAddToAdminRole() public {
    uint64 roleId = accessManagerEnumerable.ADMIN_ROLE();
    address target = makeAddr('target');
    bytes4 selector = bytes4(keccak256('function()'));

    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = selector;

    vm.prank(ADMIN);
    accessManagerEnumerable.setTargetFunctionRole(target, selectors, roleId);

    assertEq(accessManagerEnumerable.getRoleOfTargetSelector(target, selector), roleId);

    // should not track selectors for ADMIN_ROLE
    assertEq(accessManagerEnumerable.getRoleTargetSelectorCount(roleId, target), 0);
    assertEq(accessManagerEnumerable.getRoleCount(), 0);
    assertFalse(accessManagerEnumerable.isRole(roleId));
  }

  function test_setTargetFunctionRole_skipAddPublicRole() public {
    uint64 roleId = accessManagerEnumerable.PUBLIC_ROLE();
    address target = makeAddr('target');
    bytes4 selector = bytes4(keccak256('function()'));

    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = selector;

    vm.prank(ADMIN);
    accessManagerEnumerable.setTargetFunctionRole(target, selectors, roleId);

    assertEq(accessManagerEnumerable.getRoleOfTargetSelector(target, selector), roleId);

    // should track selectors for PUBLIC_ROLE but not track PUBLIC_ROLE itself
    assertEq(accessManagerEnumerable.getRoleTargetSelectorCount(roleId, target), 1);
    assertEq(accessManagerEnumerable.getRoleCount(), 0);
    assertFalse(accessManagerEnumerable.isRole(roleId));
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

    for (uint256 i = 0; i < 15; i++) {
      assertEq(accessManagerEnumerable.getRoleOfTargetSelector(target, selectors[i]), roleId);
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

  function test_labelRole_trackLabels() public {
    uint64 roleId1 = 1;
    uint64 roleId2 = 2;

    assertEq(accessManagerEnumerable.getRoleLabelCount(), 0);

    vm.startPrank(ADMIN);
    accessManagerEnumerable.labelRole(roleId1, 'POOL_ADMIN');
    accessManagerEnumerable.labelRole(roleId2, 'EMERGENCY_ADMIN');
    vm.stopPrank();

    assertEq(accessManagerEnumerable.getRoleLabelCount(), 2);

    assertEq(accessManagerEnumerable.getRoleLabel(0), 'POOL_ADMIN');
    assertEq(accessManagerEnumerable.getRoleLabel(1), 'EMERGENCY_ADMIN');

    string[] memory labels = accessManagerEnumerable.getRoleLabels(0, 2);
    assertEq(labels.length, 2);
    assertEq(labels[0], 'POOL_ADMIN');
    assertEq(labels[1], 'EMERGENCY_ADMIN');

    assertEq(accessManagerEnumerable.getLabelOfRole(roleId1), 'POOL_ADMIN');
    assertEq(accessManagerEnumerable.getLabelOfRole(roleId2), 'EMERGENCY_ADMIN');

    assertEq(accessManagerEnumerable.getRoleOfLabel('POOL_ADMIN'), roleId1);
    assertEq(accessManagerEnumerable.getRoleOfLabel('EMERGENCY_ADMIN'), roleId2);
  }

  function test_labelRole_relabel() public {
    uint64 roleId = 1;

    vm.startPrank(ADMIN);
    accessManagerEnumerable.labelRole(roleId, 'OLD_LABEL');

    assertEq(accessManagerEnumerable.getRoleLabelCount(), 1);
    assertEq(accessManagerEnumerable.getLabelOfRole(roleId), 'OLD_LABEL');
    assertEq(accessManagerEnumerable.getRoleOfLabel('OLD_LABEL'), roleId);

    // Must unlabel first, then set new label
    accessManagerEnumerable.labelRole(roleId, '');
    accessManagerEnumerable.labelRole(roleId, 'NEW_LABEL');
    vm.stopPrank();

    assertEq(accessManagerEnumerable.getRoleLabelCount(), 1);
    assertEq(accessManagerEnumerable.getRoleLabel(0), 'NEW_LABEL');
    assertEq(accessManagerEnumerable.getLabelOfRole(roleId), 'NEW_LABEL');
    assertEq(accessManagerEnumerable.getRoleOfLabel('NEW_LABEL'), roleId);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManagerEnumerable.AccessManagerUnregisteredLabel.selector,
        'OLD_LABEL'
      )
    );
    accessManagerEnumerable.getRoleOfLabel('OLD_LABEL');
  }

  function test_labelRole_revertsWithAlreadyLabeledRole() public {
    uint64 roleId = 1;

    vm.startPrank(ADMIN);
    accessManagerEnumerable.labelRole(roleId, 'EXISTING_LABEL');

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManagerEnumerable.AccessManagerRoleAlreadyLabeled.selector,
        roleId
      )
    );
    accessManagerEnumerable.labelRole(roleId, 'NEW_LABEL');
    vm.stopPrank();
  }

  function test_labelRole_removeLabelOnUnlabeledRole_revertsWithUnlabeledRole() public {
    uint64 roleId = 1;

    vm.prank(ADMIN);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManagerEnumerable.AccessManagerUnlabeledRole.selector, roleId)
    );
    accessManagerEnumerable.labelRole(roleId, '');
  }

  function test_getLabelOfRole_revertsForUnlabeledRole() public {
    uint64 roleId = 99;

    vm.expectRevert(
      abi.encodeWithSelector(IAccessManagerEnumerable.AccessManagerUnlabeledRole.selector, roleId)
    );
    accessManagerEnumerable.getLabelOfRole(roleId);
  }

  function test_labelRole_tracksUntrackedRole() public {
    uint64 roleId = 99;
    assertEq(accessManagerEnumerable.getRoleCount(), 0);

    vm.prank(ADMIN);
    accessManagerEnumerable.labelRole(roleId, 'SOME_LABEL');

    assertEq(accessManagerEnumerable.getLabelOfRole(roleId), 'SOME_LABEL');
    assertEq(accessManagerEnumerable.getRoleOfLabel('SOME_LABEL'), roleId);
    assertEq(accessManagerEnumerable.getRoleCount(), 1);
  }

  function test_labelRole_tracksAlreadyTrackedRole_noDuplicate() public {
    uint64 roleId = 99;

    vm.startPrank(ADMIN);
    // Track role via setRoleAdmin first
    accessManagerEnumerable.setRoleAdmin(roleId, ADMIN_ROLE);
    assertEq(accessManagerEnumerable.getRoleCount(), 1);

    // Labeling the same role should not duplicate it
    accessManagerEnumerable.labelRole(roleId, 'SOME_LABEL');
    assertEq(accessManagerEnumerable.getRoleCount(), 1);

    assertEq(accessManagerEnumerable.getLabelOfRole(roleId), 'SOME_LABEL');
    assertEq(accessManagerEnumerable.getRoleOfLabel('SOME_LABEL'), roleId);
    vm.stopPrank();
  }

  function test_labelRole_relabelTrackedRole_noDuplicate() public {
    uint64 roleId = 99;

    vm.startPrank(ADMIN);
    accessManagerEnumerable.setRoleAdmin(roleId, ADMIN_ROLE);
    accessManagerEnumerable.labelRole(roleId, 'OLD_LABEL');
    assertEq(accessManagerEnumerable.getRoleCount(), 1);

    // Two-step relabel should not duplicate the role
    accessManagerEnumerable.labelRole(roleId, '');
    accessManagerEnumerable.labelRole(roleId, 'NEW_LABEL');
    assertEq(accessManagerEnumerable.getRoleCount(), 1);

    assertEq(accessManagerEnumerable.getLabelOfRole(roleId), 'NEW_LABEL');
    assertEq(accessManagerEnumerable.getRoleOfLabel('NEW_LABEL'), roleId);
    vm.stopPrank();
  }

  function test_getLabelRole_revertsWithUnregisteredLabel() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManagerEnumerable.AccessManagerUnregisteredLabel.selector,
        'NONEXISTENT'
      )
    );
    accessManagerEnumerable.getRoleOfLabel('NONEXISTENT');
  }

  function test_labelRole_revertsWithDuplicateLabel() public {
    uint64 roleId1 = 1;
    uint64 roleId2 = 2;

    vm.startPrank(ADMIN);
    accessManagerEnumerable.labelRole(roleId1, 'SHARED_LABEL');

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManagerEnumerable.AccessManagerLabelAlreadyUsed.selector,
        'SHARED_LABEL',
        roleId1
      )
    );
    accessManagerEnumerable.labelRole(roleId2, 'SHARED_LABEL');
    vm.stopPrank();
  }

  function test_labelRole_revertsWithAlreadyLabeledRole_evenIfLabelAlsoUsed() public {
    uint64 roleId1 = 1;
    uint64 roleId2 = 2;

    vm.startPrank(ADMIN);
    accessManagerEnumerable.labelRole(roleId1, 'LABEL_A');
    accessManagerEnumerable.labelRole(roleId2, 'LABEL_B');

    // Both conditions true: roleId2 already labeled AND 'LABEL_A' already used.
    // Should revert with AccessManagerRoleAlreadyLabeled (checked first).
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManagerEnumerable.AccessManagerRoleAlreadyLabeled.selector,
        roleId2
      )
    );
    accessManagerEnumerable.labelRole(roleId2, 'LABEL_A');
    vm.stopPrank();
  }

  function test_labelRole_removeLabel() public {
    uint64 roleId = 1;

    vm.startPrank(ADMIN);
    accessManagerEnumerable.labelRole(roleId, 'MY_LABEL');

    assertEq(accessManagerEnumerable.getRoleLabelCount(), 1);
    assertEq(accessManagerEnumerable.getLabelOfRole(roleId), 'MY_LABEL');
    assertEq(accessManagerEnumerable.getRoleOfLabel('MY_LABEL'), roleId);

    // Remove label by passing empty string
    accessManagerEnumerable.labelRole(roleId, '');
    vm.stopPrank();

    assertEq(accessManagerEnumerable.getRoleLabelCount(), 0);

    vm.expectRevert(
      abi.encodeWithSelector(IAccessManagerEnumerable.AccessManagerUnlabeledRole.selector, roleId)
    );
    accessManagerEnumerable.getLabelOfRole(roleId);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManagerEnumerable.AccessManagerUnregisteredLabel.selector,
        'MY_LABEL'
      )
    );
    accessManagerEnumerable.getRoleOfLabel('MY_LABEL');
  }

  function test_isLabelAssigned() public {
    uint64 roleId = 1;

    assertFalse(accessManagerEnumerable.isLabelAssigned('POOL_ADMIN'));

    vm.prank(ADMIN);
    accessManagerEnumerable.labelRole(roleId, 'POOL_ADMIN');

    assertTrue(accessManagerEnumerable.isLabelAssigned('POOL_ADMIN'));
    assertFalse(accessManagerEnumerable.isLabelAssigned('NONEXISTENT'));
  }

  function test_isLabelAssigned_afterRemoval() public {
    uint64 roleId = 1;

    vm.startPrank(ADMIN);
    accessManagerEnumerable.labelRole(roleId, 'MY_LABEL');
    assertTrue(accessManagerEnumerable.isLabelAssigned('MY_LABEL'));

    accessManagerEnumerable.labelRole(roleId, '');
    vm.stopPrank();

    assertFalse(accessManagerEnumerable.isLabelAssigned('MY_LABEL'));
  }

  function test_isLabelAssigned_afterRelabel() public {
    uint64 roleId = 1;

    vm.startPrank(ADMIN);
    accessManagerEnumerable.labelRole(roleId, 'OLD_LABEL');
    assertTrue(accessManagerEnumerable.isLabelAssigned('OLD_LABEL'));

    accessManagerEnumerable.labelRole(roleId, '');
    accessManagerEnumerable.labelRole(roleId, 'NEW_LABEL');
    vm.stopPrank();

    assertFalse(accessManagerEnumerable.isLabelAssigned('OLD_LABEL'));
    assertTrue(accessManagerEnumerable.isLabelAssigned('NEW_LABEL'));
  }

  function test_isRoleLabeled() public {
    uint64 roleId = 1;

    assertFalse(accessManagerEnumerable.isRoleLabeled(roleId));

    vm.prank(ADMIN);
    accessManagerEnumerable.labelRole(roleId, 'POOL_ADMIN');

    assertTrue(accessManagerEnumerable.isRoleLabeled(roleId));
    assertFalse(accessManagerEnumerable.isRoleLabeled(99));
  }

  function test_isRoleLabeled_afterRemoval() public {
    uint64 roleId = 1;

    vm.startPrank(ADMIN);
    accessManagerEnumerable.labelRole(roleId, 'MY_LABEL');
    assertTrue(accessManagerEnumerable.isRoleLabeled(roleId));

    accessManagerEnumerable.labelRole(roleId, '');
    vm.stopPrank();

    assertFalse(accessManagerEnumerable.isRoleLabeled(roleId));
  }

  function test_isRoleLabeled_afterRelabel() public {
    uint64 roleId = 1;

    vm.startPrank(ADMIN);
    accessManagerEnumerable.labelRole(roleId, 'OLD_LABEL');
    assertTrue(accessManagerEnumerable.isRoleLabeled(roleId));

    accessManagerEnumerable.labelRole(roleId, '');
    assertFalse(accessManagerEnumerable.isRoleLabeled(roleId));

    accessManagerEnumerable.labelRole(roleId, 'NEW_LABEL');
    vm.stopPrank();

    assertTrue(accessManagerEnumerable.isRoleLabeled(roleId));
  }

  function test_labelRole_onlyAuthorized_revertsWithUnauthorizedAccount() public {
    uint64 roleId = 1;

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManager.AccessManagerUnauthorizedAccount.selector,
        address(this),
        ADMIN_ROLE
      )
    );
    accessManagerEnumerable.labelRole(roleId, 'MY_LABEL');
  }

  function test_getRoleOfTargetSelector() public {
    uint64 roleId1 = 1;
    uint64 roleId2 = 2;
    address target = makeAddr('target');
    bytes4 selector1 = bytes4(keccak256('functionOne()'));
    bytes4 selector2 = bytes4(keccak256('functionTwo()'));
    bytes4 selectorUnassigned = bytes4(keccak256('functionUnassigned()'));

    bytes4[] memory selectors1 = new bytes4[](1);
    selectors1[0] = selector1;
    bytes4[] memory selectors2 = new bytes4[](1);
    selectors2[0] = selector2;

    vm.startPrank(ADMIN);
    accessManagerEnumerable.setTargetFunctionRole(target, selectors1, roleId1);
    accessManagerEnumerable.setTargetFunctionRole(target, selectors2, roleId2);
    vm.stopPrank();

    assertEq(accessManagerEnumerable.getRoleOfTargetSelector(target, selector1), roleId1);
    assertEq(accessManagerEnumerable.getRoleOfTargetSelector(target, selector2), roleId2);
    assertEq(
      accessManagerEnumerable.getRoleOfTargetSelector(target, selectorUnassigned),
      ADMIN_ROLE
    );
  }

  function test_getRoleOfTargetSelector_afterReassignment() public {
    uint64 roleA = 1;
    uint64 roleB = 2;
    address target = makeAddr('target');
    bytes4 selector = bytes4(keccak256('function()'));

    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = selector;

    vm.startPrank(ADMIN);
    accessManagerEnumerable.setTargetFunctionRole(target, selectors, roleA);
    assertEq(accessManagerEnumerable.getRoleOfTargetSelector(target, selector), roleA);

    accessManagerEnumerable.setTargetFunctionRole(target, selectors, roleB);
    vm.stopPrank();

    assertEq(accessManagerEnumerable.getRoleOfTargetSelector(target, selector), roleB);
  }

  function test_getLabelOfRole_revertsForAdminRole() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManagerEnumerable.AccessManagerUnlabeledRole.selector,
        ADMIN_ROLE
      )
    );
    accessManagerEnumerable.getLabelOfRole(ADMIN_ROLE);
  }

  function test_getLabelOfRole_revertsForPublicRole() public {
    uint64 publicRole = type(uint64).max;
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManagerEnumerable.AccessManagerUnlabeledRole.selector,
        publicRole
      )
    );
    accessManagerEnumerable.getLabelOfRole(publicRole);
  }

  function test_isRole() public {
    uint64 roleId = 42;

    assertFalse(accessManagerEnumerable.isRole(roleId));

    vm.prank(ADMIN);
    accessManagerEnumerable.setRoleAdmin(roleId, NEW_ADMIN_ROLE);

    assertTrue(accessManagerEnumerable.isRole(roleId));
    assertFalse(accessManagerEnumerable.isRole(999));
  }

  function test_isRole_excludesAdminAndPublicRole() public {
    address target = makeAddr('target');
    bytes4 selector = bytes4(keccak256('function()'));
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = selector;

    vm.startPrank(ADMIN);
    accessManagerEnumerable.setTargetFunctionRole(
      target,
      selectors,
      accessManagerEnumerable.ADMIN_ROLE()
    );
    assertFalse(accessManagerEnumerable.isRole(accessManagerEnumerable.ADMIN_ROLE()));

    accessManagerEnumerable.setTargetFunctionRole(
      target,
      selectors,
      accessManagerEnumerable.PUBLIC_ROLE()
    );
    assertFalse(accessManagerEnumerable.isRole(accessManagerEnumerable.PUBLIC_ROLE()));
    vm.stopPrank();
  }

  function test_isRole_afterLabel() public {
    uint64 roleId = 42;

    assertFalse(accessManagerEnumerable.isRole(roleId));

    vm.prank(ADMIN);
    accessManagerEnumerable.labelRole(roleId, 'SOME_ROLE');

    assertTrue(accessManagerEnumerable.isRole(roleId));
  }

  function test_isAdminRole() public {
    uint64 adminRoleId = NEW_ADMIN_ROLE;

    assertFalse(accessManagerEnumerable.isAdminRole(adminRoleId));

    vm.prank(ADMIN);
    accessManagerEnumerable.setRoleAdmin(GUARDIAN_ROLE_1, adminRoleId);

    assertTrue(accessManagerEnumerable.isAdminRole(adminRoleId));
    assertFalse(accessManagerEnumerable.isAdminRole(999));
  }

  function test_isAdminRole_excludesAdminRole() public {
    vm.prank(ADMIN);
    accessManagerEnumerable.setRoleAdmin(GUARDIAN_ROLE_1, ADMIN_ROLE);

    assertFalse(accessManagerEnumerable.isAdminRole(ADMIN_ROLE));
  }

  function test_isAdminRole_multipleRoles() public {
    vm.startPrank(ADMIN);
    accessManagerEnumerable.setRoleAdmin(GUARDIAN_ROLE_1, NEW_ADMIN_ROLE);
    accessManagerEnumerable.setRoleAdmin(GUARDIAN_ROLE_2, NEW_ADMIN_ROLE);
    vm.stopPrank();

    assertTrue(accessManagerEnumerable.isAdminRole(NEW_ADMIN_ROLE));

    vm.prank(ADMIN);
    accessManagerEnumerable.setRoleAdmin(GUARDIAN_ROLE_1, NEW_ADMIN_ROLE_2);

    assertTrue(accessManagerEnumerable.isAdminRole(NEW_ADMIN_ROLE));
    assertTrue(accessManagerEnumerable.isAdminRole(NEW_ADMIN_ROLE_2));
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
