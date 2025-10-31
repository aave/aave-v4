// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

/// @title IAccessManagerEnumerable
/// @author Aave Labs
/// @notice Interface for AccessManagerEnumerable extension.
interface IAccessManagerEnumerable {
  /// @notice Returns the address of the role member at a given index.
  /// @param roleId The role identifier.
  /// @param index The index in the role member list.
  /// @return The address of the role member.
  function getRoleMember(uint64 roleId, uint256 index) external view returns (address);

  /// @notice Returns the number of members for a given role.
  /// @param roleId The role identifier.
  /// @return The number of members for the role.
  function getRoleMemberCount(uint64 roleId) external view returns (uint256);

  /// @notice Returns the list of members for a given role.
  /// @param roleId The role identifier.
  /// @return The list of members for the role.
  function getRoleMembers(uint64 roleId) external view returns (address[] memory);
}
