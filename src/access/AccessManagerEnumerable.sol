// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {AccessManager} from 'src/dependencies/openzeppelin/AccessManager.sol';
import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';
import {IAccessManagerEnumerable} from 'src/access/interfaces/IAccessManagerEnumerable.sol';

/// @title AccessManagerEnumerable
/// @author Aave Labs
/// @notice Extension of AccessManager that tracks role members using EnumerableSet.
contract AccessManagerEnumerable is AccessManager, IAccessManagerEnumerable {
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableSet for EnumerableSet.Bytes32Set;

  /// @dev Mapping from roleId to set of role members.
  mapping(uint64 roleId => EnumerableSet.AddressSet) private _roleMembers;

  /// @dev Mapping from roleId to set configured function selectors.
  mapping(uint64 roleId => EnumerableSet.Bytes32Set) private _roleSelectors;

  constructor(address initialAdmin_) AccessManager(initialAdmin_) {}

  /// @inheritdoc IAccessManagerEnumerable
  function getRoleMember(uint64 roleId, uint256 index) external view returns (address) {
    return _roleMembers[roleId].at(index);
  }

  /// @inheritdoc IAccessManagerEnumerable
  function getRoleMemberCount(uint64 roleId) external view returns (uint256) {
    return _roleMembers[roleId].length();
  }

  /// @inheritdoc IAccessManagerEnumerable
  function getRoleMembers(uint64 roleId) external view returns (address[] memory) {
    return _roleMembers[roleId].values();
  }

  /// @inheritdoc IAccessManagerEnumerable
  function getRoleSelector(uint64 roleId, uint256 index) external view returns (bytes4) {
    return bytes4(_roleSelectors[roleId].at(index));
  }

  /// @inheritdoc IAccessManagerEnumerable
  function getRoleSelectorCount(uint64 roleId) external view returns (uint256) {
    return _roleSelectors[roleId].length();
  }

  /// @inheritdoc IAccessManagerEnumerable
  function getRoleSelectors(uint64 roleId) external view returns (bytes4[] memory ret) {
    bytes32[] memory rawSelectors = _roleSelectors[roleId].values();
    assembly ('memory-safe') {
      ret := rawSelectors
    }
  }

  /// @dev Override AccessManager:_grantRole to track role members.
  function _grantRole(
    uint64 roleId,
    address account,
    uint32 grantDelay,
    uint32 executionDelay
  ) internal override returns (bool) {
    bool granted = super._grantRole(roleId, account, grantDelay, executionDelay);
    if (granted) {
      _roleMembers[roleId].add(account);
    }
    return granted;
  }

  /// @dev Override AccessManager:_grantRole to remove from tracked role members.
  function _revokeRole(uint64 roleId, address account) internal override returns (bool) {
    bool revoked = super._revokeRole(roleId, account);
    if (revoked) {
      _roleMembers[roleId].remove(account);
    }
    return revoked;
  }

  /// @dev Override AccessManager:_setTargetFunctionRole to track selectors attributed to roles.
  function _setTargetFunctionRole(
    address target,
    bytes4 selector,
    uint64 roleId
  ) internal override {
    uint64 oldRoleId = getTargetFunctionRole(target, selector);
    if (oldRoleId != PUBLIC_ROLE) {
      _roleSelectors[oldRoleId].remove(bytes32(selector));
    }
    super._setTargetFunctionRole(target, selector, roleId);
    if (roleId != PUBLIC_ROLE) {
      _roleSelectors[roleId].add(bytes32(selector));
    }
  }
}
