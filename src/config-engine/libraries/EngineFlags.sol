// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title EngineFlags
/// @author Aave Labs
/// @notice Sentinel values for partial updates in config engine structs.
library EngineFlags {
  /// @dev Thrown when toBool receives a value other than 0 or 1.
  error InvalidBoolValue(uint256 value);

  /// @dev Sentinel value to keep the current uint value.
  /// Strongly assumes that the value `type(uint256).max - 256` will never be used, which seems reasonable.
  uint256 internal constant KEEP_CURRENT = type(uint256).max - 256;
  /// @dev Sentinel address to keep the current address value.
  address internal constant KEEP_CURRENT_ADDRESS = address(type(uint160).max);
  /// @dev Sentinel value to keep the current uint64 value.
  /// Strongly assumes that the value `type(uint64).max - 64` will never be used, which seems reasonable.
  uint64 internal constant KEEP_CURRENT_UINT64 = type(uint64).max - 64;
  /// @dev Sentinel value to keep the current uint32 value.
  /// Strongly assumes that the value `type(uint32).max - 32` will never be used, which seems reasonable.
  uint32 internal constant KEEP_CURRENT_UINT32 = type(uint32).max - 32;
  /// @dev Sentinel value to keep the current uint16 value.
  /// Strongly assumes that the value `type(uint16).max - 16` will never be used, which seems reasonable.
  uint16 internal constant KEEP_CURRENT_UINT16 = type(uint16).max - 16;

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
