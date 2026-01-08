// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {AccessManager} from 'src/dependencies/openzeppelin/AccessManager.sol';
import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';
import {IAccessManagerEnumerable} from 'src/access/interfaces/IAccessManagerEnumerable.sol';

/// @title AccessManagerEnumerable
/// @author Aave Labs
/// @notice Extension of AccessManager that tracks role members and their function selectors using EnumerableSet.
contract AccessManagerEnumerable is AccessManager, IAccessManagerEnumerable {
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableSet for EnumerableSet.Bytes32Set;
  using EnumerableSet for EnumerableSet.UintSet;

  /// @dev Set of all role identifiers.
  EnumerableSet.UintSet private _rolesSet;

  /// @dev Set of all admin role identifiers.
  EnumerableSet.UintSet private _adminRolesSet;

  /// @dev Map of role identifiers to their respective member sets.
  mapping(uint64 roleId => EnumerableSet.AddressSet) private _roleMembers;

  /// @dev Map of admin role identifiers to their respective role identifier sets.
  mapping(uint64 roleId => EnumerableSet.UintSet) private _adminOfRoles;

  /// @dev Map of role identifiers to their respective target contract addresses.
  mapping(uint64 roleId => EnumerableSet.AddressSet) private _roleTargets;

  /// @dev Map of target contract addresses and function selectors to their assigned role identifier.
  mapping(address target => mapping(bytes4 selector => uint64 roleId)) private _targetSelectorRoles;

  /// @dev Map of role identifiers and target contract addresses to their respective set of function selectors.
  mapping(uint64 roleId => mapping(address target => EnumerableSet.Bytes32Set))
    private _roleTargetSelectors;

  /// @dev Constructor.
  /// @param initialAdmin_ The address of the initial admin.
  constructor(address initialAdmin_) AccessManager(initialAdmin_) {
    // Track the ADMIN_ROLE by default.
    // (already tracked as a default role via AccessManager constructor)
    _adminRolesSet.add(ADMIN_ROLE);
  }

  /// @inheritdoc IAccessManagerEnumerable
  function getRole(uint256 index) external view returns (uint64) {
    return uint64(_rolesSet.at(index));
  }

  /// @inheritdoc IAccessManagerEnumerable
  function getRoleCount() external view returns (uint256) {
    return _rolesSet.length();
  }

  /// @inheritdoc IAccessManagerEnumerable
  function getRoles(uint256 start, uint256 end) external view returns (uint64[] memory) {
    uint256[] memory listedRoles = _rolesSet.values(start, end);
    uint64[] memory roles;
    assembly ('memory-safe') {
      roles := listedRoles
    }
    return roles;
  }

  /// @inheritdoc IAccessManagerEnumerable
  function getAdminRole(uint256 index) external view returns (uint64) {
    return uint64(_adminRolesSet.at(index));
  }

  /// @inheritdoc IAccessManagerEnumerable
  function getAdminRoleCount() external view returns (uint256) {
    return _adminRolesSet.length();
  }

  /// @inheritdoc IAccessManagerEnumerable
  function getAdminRoles(uint256 start, uint256 end) external view returns (uint64[] memory) {
    uint256[] memory listedAdminRoles = _adminRolesSet.values(start, end);
    uint64[] memory adminRoles;
    assembly ('memory-safe') {
      adminRoles := listedAdminRoles
    }
    return adminRoles;
  }

  /// @inheritdoc IAccessManagerEnumerable
  function getRoleMember(uint64 roleId, uint256 index) external view returns (address) {
    return _roleMembers[roleId].at(index);
  }

  /// @inheritdoc IAccessManagerEnumerable
  function getRoleMemberCount(uint64 roleId) external view returns (uint256) {
    return _roleMembers[roleId].length();
  }

  /// @inheritdoc IAccessManagerEnumerable
  function getRoleMembers(
    uint64 roleId,
    uint256 start,
    uint256 end
  ) external view returns (address[] memory) {
    return _roleMembers[roleId].values(start, end);
  }

  /// @inheritdoc IAccessManagerEnumerable
  function getAdminOfRole(uint64 adminRoleId, uint256 index) external view returns (uint64) {
    return uint64(_adminOfRoles[adminRoleId].at(index));
  }

  /// @inheritdoc IAccessManagerEnumerable
  function getAdminOfRoleCount(uint64 adminRoleId) external view returns (uint256) {
    return _adminOfRoles[adminRoleId].length();
  }

  /// @inheritdoc IAccessManagerEnumerable
  function getAdminOfRoles(
    uint64 adminRoleId,
    uint256 start,
    uint256 end
  ) external view returns (uint64[] memory) {
    uint256[] memory listedRoles = _adminOfRoles[adminRoleId].values(start, end);
    uint64[] memory roles;
    assembly ('memory-safe') {
      roles := listedRoles
    }
    return roles;
  }

  /// @inheritdoc IAccessManagerEnumerable
  function getRoleTarget(uint64 roleId, uint256 index) external view returns (address) {
    return _roleTargets[roleId].at(index);
  }

  /// @inheritdoc IAccessManagerEnumerable
  function getRoleTargetCount(uint64 roleId) external view returns (uint256) {
    return _roleTargets[roleId].length();
  }

  /// @inheritdoc IAccessManagerEnumerable
  function getRoleTargets(
    uint64 roleId,
    uint256 start,
    uint256 end
  ) external view returns (address[] memory) {
    return _roleTargets[roleId].values(start, end);
  }

  /// @inheritdoc IAccessManagerEnumerable
  function getRoleTargetSelector(
    uint64 roleId,
    address target,
    uint256 index
  ) external view returns (bytes4) {
    return bytes4(_roleTargetSelectors[roleId][target].at(index));
  }

  /// @inheritdoc IAccessManagerEnumerable
  function getRoleTargetSelectorCount(
    uint64 roleId,
    address target
  ) external view returns (uint256) {
    return _roleTargetSelectors[roleId][target].length();
  }

  /// @inheritdoc IAccessManagerEnumerable
  function getRoleTargetSelectors(
    uint64 roleId,
    address target,
    uint256 start,
    uint256 end
  ) external view returns (bytes4[] memory) {
    bytes32[] memory targetFunctions = _roleTargetSelectors[roleId][target].values(start, end);
    bytes4[] memory targetFunctionSelectors;
    assembly ('memory-safe') {
      targetFunctionSelectors := targetFunctions
    }
    return targetFunctionSelectors;
  }

  /// @dev Tracks all role identifiers when a new role is created.
  function _trackRole(uint64 roleId) internal {
    _rolesSet.add(uint256(roleId));
  }

  /// @dev Tracks all admin role identifiers when a new admin role is set.
  function _trackAdminRole(uint64 roleId, uint64 oldAdmin, uint64 admin) internal {
    _adminRolesSet.add(uint256(admin));
    _adminOfRoles[oldAdmin].remove(uint256(roleId));
    _adminOfRoles[admin].add(uint256(roleId));
  }

  /// @dev Tracks all members of a role when granted or revoked.
  function _trackRoleMember(uint64 roleId, address account, bool granted) internal {
    if (granted) {
      _roleMembers[roleId].add(account);
    } else {
      _roleMembers[roleId].remove(account);
    }
  }

  /// @dev Tracks all targets where a selector was assigned to a role and selectors.
  function _trackRoleTargetSelector(uint64 roleId, address target, bytes4 selector) internal {
    uint64 oldRoleId = _targetSelectorRoles[target][selector];
    if (oldRoleId == roleId) {
      return;
    }
    if (oldRoleId != ADMIN_ROLE) {
      _roleTargetSelectors[oldRoleId][target].remove(bytes32(selector));
      if (_roleTargetSelectors[oldRoleId][target].length() == 0) {
        _roleTargets[oldRoleId].remove(target);
      }
    }
    if (roleId != ADMIN_ROLE) {
      _roleTargetSelectors[roleId][target].add(bytes32(selector));
      _roleTargets[roleId].add(target);
    }
    _targetSelectorRoles[target][selector] = roleId;
  }

  /// @dev Override AccessManager `_setRoleAdmin` function to track created roles.
  function _setRoleAdmin(uint64 roleId, uint64 admin) internal override {
    uint64 oldAdmin = getRoleAdmin(roleId);

    super._setRoleAdmin(roleId, admin);

    _trackRole(roleId);
    _trackAdminRole(roleId, oldAdmin, admin);
  }

  /// @dev Override AccessManager `_setRoleGuardian` function to track created roles.
  function _setRoleGuardian(uint64 roleId, uint64 guardian) internal override {
    super._setRoleGuardian(roleId, guardian);

    _trackRole(roleId);
  }

  /// @dev Override AccessManager `_grantRole` function to track roles' membership.
  function _grantRole(
    uint64 roleId,
    address account,
    uint32 grantDelay,
    uint32 executionDelay
  ) internal override returns (bool) {
    bool granted = super._grantRole(roleId, account, grantDelay, executionDelay);

    if (granted) {
      _trackRole(roleId);
      _trackRoleMember(roleId, account, granted);
    }

    return granted;
  }

  /// @dev Override AccessManager `_revokeRole` function to remove from tracked roles' membership.
  function _revokeRole(uint64 roleId, address account) internal override returns (bool) {
    bool revoked = super._revokeRole(roleId, account);

    _trackRoleMember(roleId, account, !revoked);

    return revoked;
  }

  /// @dev Override AccessManager `_setTargetFunctionRole` function to track function selectors attributed to roles.
  function _setTargetFunctionRole(
    address target,
    bytes4 selector,
    uint64 roleId
  ) internal override {
    super._setTargetFunctionRole(target, selector, roleId);

    // also track the target under the role (will be added if not already present)
    _trackRoleTargetSelector(roleId, target, selector);
  }
}
