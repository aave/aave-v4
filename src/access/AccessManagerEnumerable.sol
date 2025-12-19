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

  /// @dev Map of role identifiers to their respective member sets.
  mapping(uint64 roleId => EnumerableSet.AddressSet) private _roleMembers;

  /// @dev Map of role identifiers to their respective target contract addresses.
  mapping(uint64 roleId => EnumerableSet.AddressSet) private _roleTargets;

  /// @dev Map of target contract addresses to their current role identifiers.
  mapping(address target => uint64 roleId) private _targetRoles;

  /// @dev Map of role identifiers and target contract addresses to their respective set of function selectors.
  mapping(uint64 roleId => mapping(address target => EnumerableSet.Bytes32Set))
    private _roleTargetFunctions;

  /// @dev Constructor.
  /// @param initialAdmin_ The address of the initial admin.
  constructor(address initialAdmin_) AccessManager(initialAdmin_) {}

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
  function getRoleTargetFunction(
    uint64 roleId,
    address target,
    uint256 index
  ) external view returns (bytes4) {
    return bytes4(_roleTargetFunctions[roleId][target].at(index));
  }

  /// @inheritdoc IAccessManagerEnumerable
  function getRoleTargetFunctionCount(
    uint64 roleId,
    address target
  ) external view returns (uint256) {
    return _roleTargetFunctions[roleId][target].length();
  }

  /// @inheritdoc IAccessManagerEnumerable
  function getRoleTargetFunctions(
    uint64 roleId,
    address target,
    uint256 start,
    uint256 end
  ) external view returns (bytes4[] memory) {
    bytes32[] memory targetFunctions = _roleTargetFunctions[roleId][target].values(start, end);
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

  /// @dev Tracks all targets where a selector was assigned to a role.
  function _trackRoleTarget(uint64 roleId, address target) internal {
    uint64 oldRole = _targetRoles[target];
    if (oldRole == roleId) {
      return;
    }
    if (oldRole != ADMIN_ROLE && _roleTargetFunctions[oldRole][target].length() == 0) {
      _roleTargets[oldRole].remove(target);
    }
    if (roleId != ADMIN_ROLE) {
      _roleTargets[roleId].add(target);
    }
    _targetRoles[target] = roleId;
  }

  /// @dev Override AccessManager `_setRoleAdmin` function to track created roles.
  function _setRoleAdmin(uint64 roleId, uint64 admin) internal override {
    _trackRole(roleId);
    super._setRoleAdmin(roleId, admin);
  }

  /// @dev Override AccessManager `_setRoleGuardian` function to track created roles.
  function _setRoleGuardian(uint64 roleId, uint64 guardian) internal override {
    _trackRole(roleId);
    super._setRoleGuardian(roleId, guardian);
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
      _roleMembers[roleId].add(account);
    }
    return granted;
  }

  /// @dev Override AccessManager `_revokeRole` function to remove from tracked roles' membership.
  function _revokeRole(uint64 roleId, address account) internal override returns (bool) {
    bool revoked = super._revokeRole(roleId, account);
    if (revoked) {
      _roleMembers[roleId].remove(account);
    }
    return revoked;
  }

  /// @dev Override AccessManager `_setTargetFunctionRole` function to track function selectors attributed to roles.
  function _setTargetFunctionRole(
    address target,
    bytes4 selector,
    uint64 roleId
  ) internal override {
    uint64 oldRoleId = getTargetFunctionRole(target, selector);
    super._setTargetFunctionRole(target, selector, roleId);
    if (oldRoleId != ADMIN_ROLE) {
      _roleTargetFunctions[oldRoleId][target].remove(bytes32(selector));
    }
    if (roleId != ADMIN_ROLE) {
      _roleTargetFunctions[roleId][target].add(bytes32(selector));
    }
    // also track the target under the role (will be added if not already present)
    _trackRoleTarget(roleId, target);
  }
}
