// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';

/// @title IAccessManagerEnumerable
/// @author Aave Labs
/// @notice Interface for AccessManagerEnumerable extension.
interface IAccessManagerEnumerable is IAccessManager {
  /// @notice Returns the identifier of the role at a specified index.
  /// @dev `PUBLIC_ROLE` and `ADMIN_ROLE` are not accessible via any index.
  /// @param index The index in the role list.
  /// @return The identifier of the role.
  function getRole(uint256 index) external view returns (uint64);

  /// @notice Returns the total number of existing roles.
  /// @dev `PUBLIC_ROLE` and `ADMIN_ROLE` are not included in the role count.
  /// @return The number of roles.
  function getRoleCount() external view returns (uint256);

  /// @notice Returns the list of role identifiers between the specified indexes.
  /// @dev `PUBLIC_ROLE` and `ADMIN_ROLE` are not accessible via any index.
  /// @param start The starting index for the role list.
  /// @param end The ending index for the role list.
  /// @return The list of role identifiers.
  function getRoles(uint256 start, uint256 end) external view returns (uint64[] memory);

  /// @notice Returns the identifier of the admin role at a specified index.
  /// @dev `ADMIN_ROLE` is not accessible via any index.
  /// @param index The index in the admin role list.
  /// @return The identifier of the admin role.
  function getAdminRole(uint256 index) external view returns (uint64);

  /// @notice Returns the total number of existing admin roles.
  /// @dev `ADMIN_ROLE` is not included in the admin role count.
  /// @return The number of admin roles.
  function getAdminRoleCount() external view returns (uint256);

  /// @notice Returns the list of admin role identifiers between the specified indexes.
  /// @dev `ADMIN_ROLE` is not accessible via any index.
  /// @param start The starting index for the admin role list.
  /// @param end The ending index for the admin role list.
  /// @return The list of admin role identifiers.
  function getAdminRoles(uint256 start, uint256 end) external view returns (uint64[] memory);

  /// @notice Returns the address of the role member at a specified index.
  /// @param roleId The identifier of the role.
  /// @param index The index in the role member list.
  /// @return The address of the role member.
  function getRoleMember(uint64 roleId, uint256 index) external view returns (address);

  /// @notice Returns the number of members for a specified role.
  /// @param roleId The identifier of the role.
  /// @return The number of members for the role.
  function getRoleMemberCount(uint64 roleId) external view returns (uint256);

  /// @notice Returns the list of members for a specified role between the specified indexes.
  /// @param roleId The identifier of the role.
  /// @param start The starting index for the member list.
  /// @param end The ending index for the member list.
  /// @return The list of members for the role.
  function getRoleMembers(
    uint64 roleId,
    uint256 start,
    uint256 end
  ) external view returns (address[] memory);

  /// @notice Returns the identifier of the role managed by the given admin role at a specified index.
  /// @dev Roles managed by the `ADMIN_ROLE` are not accessible.
  /// @param adminRoleId The identifier of the admin role.
  /// @param index The index in the list of roles managed by the admin role.
  /// @return The identifier of the role.
  function getRoleOfAdminRole(uint64 adminRoleId, uint256 index) external view returns (uint64);

  /// @notice Returns the number of roles managed by a specified admin role.
  /// @dev Roles managed by the `ADMIN_ROLE` are not accessible.
  /// @param adminRoleId The identifier of the admin role.
  /// @return The number of roles managed by the admin role.
  function getRoleOfAdminRoleCount(uint64 adminRoleId) external view returns (uint256);

  /// @notice Returns the list of role identifiers managed by the given admin role between the specified indexes.
  /// @dev Roles managed by the `ADMIN_ROLE` are not accessible.
  /// @param adminRoleId The identifier of the admin role.
  /// @param start The starting index in the list of roles managed by the admin role.
  /// @param end The ending index in the list of roles managed by the admin role.
  /// @return The list of role identifiers managed by the given admin role.
  function getRolesOfAdminRole(
    uint64 adminRoleId,
    uint256 start,
    uint256 end
  ) external view returns (uint64[] memory);

  /// @notice Returns the address of the target contract for a specified role and index.
  /// @dev Target contracts assigned to `ADMIN_ROLE` are not accessible.
  /// @param roleId The identifier of the role.
  /// @param index The index in the role target list.
  /// @return The address of the target contract.
  function getRoleTarget(uint64 roleId, uint256 index) external view returns (address);

  /// @notice Returns the number of target contracts for a specified role.
  /// @dev Target contracts assigned to `ADMIN_ROLE` are not accessible.
  /// @param roleId The identifier of the role.
  /// @return The number of target contracts for the role.
  function getRoleTargetCount(uint64 roleId) external view returns (uint256);

  /// @notice Returns the list of target contracts for a specified role between the specified indexes.
  /// @dev Target contracts assigned to `ADMIN_ROLE` are not accessible.
  /// @param roleId The identifier of the role.
  /// @param start The starting index for the role target list.
  /// @param end The ending index for the role target list.
  /// @return The list of target contracts for the role.
  function getRoleTargets(
    uint64 roleId,
    uint256 start,
    uint256 end
  ) external view returns (address[] memory);

  /// @notice Returns the function selector assigned to a given role at the specified index.
  /// @dev Target selectors assigned to `ADMIN_ROLE` are not accessible.
  /// @param roleId The identifier of the role.
  /// @param target The address of the target contract.
  /// @param index The index in the role member list.
  /// @return The selector at the index.
  function getRoleTargetSelector(
    uint64 roleId,
    address target,
    uint256 index
  ) external view returns (bytes4);

  /// @notice Returns the number of function selectors assigned to the given role.
  /// @dev Target selectors assigned to `ADMIN_ROLE` are not accessible.
  /// @param roleId The identifier of the role.
  /// @param target The address of the target contract.
  /// @return The number of selectors assigned to the role.
  function getRoleTargetSelectorCount(
    uint64 roleId,
    address target
  ) external view returns (uint256);

  /// @notice Returns the list of function selectors assigned to the given role between the specified indexes.
  /// @dev Target selectors assigned to `ADMIN_ROLE` are not accessible.
  /// @param roleId The identifier of the role.
  /// @param target The address of the target contract.
  /// @param start The starting index for the selector list.
  /// @param end The ending index for the selector list.
  /// @return The list of selectors assigned to the role.
  function getRoleTargetSelectors(
    uint64 roleId,
    address target,
    uint256 start,
    uint256 end
  ) external view returns (bytes4[] memory);
}
