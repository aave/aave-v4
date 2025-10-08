// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IRescuable} from 'src/interfaces/IRescuable.sol';

/// @title IGatewayBase
/// @author Aave Labs
/// @notice Minimal interface for base gateway functionalities.
interface IGatewayBase is IRescuable {
  /// @notice Emitted when a spoke is registered or deregistered.
  event SpokeRegistered(address indexed spoke, bool active);

  /// @notice Thrown when the specified address is invalid.
  error InvalidAddress();

  /// @notice Thrown when the specified amount is invalid.
  error InvalidAmount();

  /// @notice Thrown when the specified spoke is not registered.
  error SpokeNotRegistered();

  /// @notice Allows contract to renounce its position manager role for `user`.
  /// @dev Only authorized caller to invoke this method.
  /// @param spoke The address of the registered `spoke`.
  /// @param user The address of the user to renounce the position manager role for.
  function renouncePositionManagerRole(address spoke, address user) external;

  /// @notice Permissioned operation to register or deregister a spoke.
  /// @dev Only owner to invoke this method.
  /// @param spoke The address of the `spoke`.
  /// @param active `true` to register, `false` to deregister.
  function registerSpoke(address spoke, bool active) external;

  /// @notice Returns whether the specified spoke is registered.
  /// @param spoke The address of the `spoke`.
  /// @return `true` if the spoke is registered, `false` otherwise.
  function isSpokeRegistered(address spoke) external view returns (bool);
}
