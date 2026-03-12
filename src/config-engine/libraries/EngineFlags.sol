// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

/// @title EngineFlags
/// @author Aave Labs
/// @notice Sentinel values for partial updates in config engine structs.
library EngineFlags {
  /// @dev Thrown when toBool receives a value other than 0 or 1.
  error InvalidBoolValue(uint256 value);

  /// @dev Sentinel value to keep the current uint value.
  uint256 internal constant KEEP_CURRENT = type(uint256).max - 1;
  /// @dev Sentinel address to keep the current address value.
  address internal constant KEEP_CURRENT_ADDRESS = address(type(uint160).max);
  /// @dev Sentinel value to keep the current uint64 value.
  uint64 internal constant KEEP_CURRENT_UINT64 = type(uint64).max - 1;
  /// @dev Sentinel value to keep the current uint32 value.
  uint32 internal constant KEEP_CURRENT_UINT32 = type(uint32).max - 1;
  /// @dev Sentinel value to keep the current uint16 value.
  uint16 internal constant KEEP_CURRENT_UINT16 = type(uint16).max - 1;

  /// @dev Convenience constant representing an enabled boolean flag (1).
  uint256 internal constant ENABLED = 1;
  /// @dev Convenience constant representing a disabled boolean flag (0).
  uint256 internal constant DISABLED = 0;

  /// @notice Converts a uint256 flag (0 or 1) to a bool.
  /// @dev Reverts on any other value than the expected constants.
  /// @param flag The uint256 flag to convert (must be 0 or 1).
  /// @return The boolean representation of the flag.
  function toBool(uint256 flag) internal pure returns (bool) {
    require(flag == ENABLED || flag == DISABLED, InvalidBoolValue(flag));
    return flag == ENABLED;
  }

  /// @notice Converts a bool to uint256 (false = DISABLED, true = ENABLED).
  /// @param value The bool value to convert.
  /// @return The uint256 representation of the value.
  function fromBool(bool value) internal pure returns (uint256) {
    return value ? ENABLED : DISABLED;
  }
}
