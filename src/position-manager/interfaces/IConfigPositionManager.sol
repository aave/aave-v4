// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';

type ConfigPermissions is uint8;

/// @title IConfigPositionManager
/// @author Aave Labs
/// @notice Interface for position manager handling user configuration actions on behalf of an user.
interface IConfigPositionManager is IPositionManagerBase {
  /// @notice Struct to hold the config permission values.
  /// @dev canSetUsingAsCollateral Whether the delegatee can set using as collateral on behalf of the user.
  /// @dev canUpdateUserRiskPremium Whether the delegatee can update user risk premium on behalf of the user.
  /// @dev canUpdateUserDynamicConfig Whether the delegatee can update user dynamic config on behalf of the user.
  struct ConfigPermissionValues {
    bool canSetUsingAsCollateral;
    bool canUpdateUserRiskPremium;
    bool canUpdateUserDynamicConfig;
  }

  /// @notice Emitted when a global config permission is updated.
  /// @param spoke The address of the Spoke.
  /// @param delegator The address of the delegator.
  /// @param delegatee The address of the delegatee.
  /// @param permissions The new config permissions.
  event ConfigPermissionsUpdated(
    address indexed spoke,
    address indexed delegator,
    address indexed delegatee,
    ConfigPermissions permissions
  );

  /// @notice Thrown when the delegatee of a function was not given permission by the user.
  error DelegateeNotAllowed();

  /// @notice Sets the global permission for a delegatee.
  /// @param spoke The address of the Spoke.
  /// @param delegatee The address of the delegatee.
  /// @param permission The new permission status.
  function setGlobalPermission(address spoke, address delegatee, bool permission) external;

  /// @notice Sets the using as collateral permission for a delegatee.
  /// @param spoke The address of the Spoke.
  /// @param delegatee The address of the delegatee.
  /// @param permission The new permission status.
  function setCanUpdateUsingAsCollateralPermission(
    address spoke,
    address delegatee,
    bool permission
  ) external;

  /// @notice Sets the user risk premium permission for a delegatee.
  /// @param spoke The address of the Spoke.
  /// @param delegatee The address of the delegatee.
  /// @param permission The new permission status.
  function setCanUpdateUserRiskPremiumPermission(
    address spoke,
    address delegatee,
    bool permission
  ) external;

  /// @notice Sets the user dynamic config permission for a delegatee.
  /// @param spoke The address of the Spoke.
  /// @param delegatee The address of the delegatee.
  /// @param permission The new permission status.
  function setCanUpdateUserDynamicConfigPermission(
    address spoke,
    address delegatee,
    bool permission
  ) external;

  /// @notice Renounces the global permission given by the delegator.
  /// @param spoke The address of the Spoke.
  /// @param delegator The address of the delegator.
  function renounceGlobalPermission(address spoke, address delegator) external;

  /// @notice Renounces the using as collateral permission given by the delegator.
  /// @param spoke The address of the Spoke.
  /// @param delegator The address of the delegator.
  function renounceCanUpdateUsingAsCollateralPermission(address spoke, address delegator) external;

  /// @notice Renounces the user risk premium permission given by the delegator.
  /// @param spoke The address of the Spoke.
  /// @param delegator The address of the delegator.
  function renounceCanUpdateUserRiskPremiumPermission(address spoke, address delegator) external;

  /// @notice Renounces the user dynamic config permission given by the delegator.
  /// @param spoke The address of the Spoke.
  /// @param delegator The address of the delegator.
  function renounceCanUpdateUserDynamicConfigPermission(address spoke, address delegator) external;

  /// @notice Sets the using as collateral status on behalf of a user for a specified reserve.
  /// @dev The `msg.sender` must be the delegatee to perform this action on behalf of the user.
  /// @dev Contract must be an active and approved user position manager of `onBehalfOf`.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The id of the reserve.
  /// @param usingAsCollateral The new using as collateral status.
  /// @param onBehalfOf The address of the user.
  function setUsingAsCollateralOnBehalfOf(
    address spoke,
    uint256 reserveId,
    bool usingAsCollateral,
    address onBehalfOf
  ) external;

  /// @notice Updates the user risk premium on behalf of a user.
  /// @dev The `msg.sender` must be the delegatee to perform this action on behalf of the user.
  /// @dev Contract must be an active and approved user position manager of `onBehalfOf`.
  /// @param spoke The address of the Spoke.
  /// @param onBehalfOf The address of the user.
  function updateUserRiskPremiumOnBehalfOf(address spoke, address onBehalfOf) external;

  /// @notice Updates the user dynamic config on behalf of a user.
  /// @dev The `msg.sender` must be the delegatee to perform this action on behalf of the user.
  /// @dev Contract must be an active and approved user position manager of `onBehalfOf`.
  /// @param spoke The address of the Spoke.
  /// @param onBehalfOf The address of the user.
  function updateUserDynamicConfigOnBehalfOf(address spoke, address onBehalfOf) external;

  /// @notice Returns the config permissions for a delegatee on behalf of a user.
  /// @param spoke The address of the Spoke.
  /// @param delegatee The address of the delegatee.
  /// @param onBehalfOf The address of the user.
  /// @return The ConfigPermissionValues for the delegatee on behalf of the user.
  function getConfigPermissions(
    address spoke,
    address delegatee,
    address onBehalfOf
  ) external view returns (ConfigPermissionValues memory);
}
