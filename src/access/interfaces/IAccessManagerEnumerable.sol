// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';

/// @title IAccessManagerEnumerable
/// @author Aave Labs
/// @notice Interface for AccessManagerEnumerable extension.
interface IAccessManagerEnumerable is IAccessManager {
  /// @notice Returns the address of the role member at a specified index.
  /// @param roleId The identifier of the role.
  /// @param index The index in the role member list.
  /// @return The address of the role member.
  function getRoleMember(uint64 roleId, uint256 index) external view returns (address);

  /// @notice Returns the number of members for a specified role.
  /// @param roleId The identifier of the role.
  /// @return The number of members for the role.
  function getRoleMemberCount(uint64 roleId) external view returns (uint256);

  /// @notice Returns the list of members for a specified role.
  /// @param roleId The identifier of the role.
  /// @param start The starting index for the member list.
  /// @param end The ending index for the member list.
  /// @return The list of members for the role.
  function getRoleMembers(
    uint64 roleId,
    uint256 start,
    uint256 end
  ) external view returns (address[] memory);

  /// @notice Returns the function selector assigned to a given role at the specified index.
  /// @param roleId The identifier of the role.
  /// @param target The address of the target contract.
  /// @param index The index in the role member list.
  /// @return The selector at the index.
  function getRoleTargetFunction(
    uint64 roleId,
    address target,
    uint256 index
  ) external view returns (bytes4);

  /// @notice Returns the number of function selectors assigned to the given role.
  /// @param roleId The identifier of the role.
  /// @param target The address of the target contract.
  /// @return The number of selectors assigned to the role.
  function getRoleTargetFunctionCount(
    uint64 roleId,
    address target
  ) external view returns (uint256);

  /// @notice Returns the list of function selectors assigned to the given role between the specified indexes.
  /// @param roleId The identifier of the role.
  /// @param target The address of the target contract.
  /// @param start The starting index for the selector list.
  /// @param end The ending index for the selector list.
  /// @return The list of selectors assigned to the role.
  function getRoleTargetFunctions(
    uint64 roleId,
    address target,
    uint256 start,
    uint256 end
  ) external view returns (bytes4[] memory);
}
