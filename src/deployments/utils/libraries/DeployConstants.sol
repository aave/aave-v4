// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

/// @title DeployConstants
/// @notice Protocol constants used by the deployment engine.
library DeployConstants {
  /// @dev Default oracle decimals for AaveOracle instances.
  uint8 public constant ORACLE_DECIMALS = 8;

  /// @dev Default max user reserves limit per spoke.
  uint16 public constant MAX_ALLOWED_USER_RESERVES_LIMIT = type(uint16).max;
}
