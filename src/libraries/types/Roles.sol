// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

/// @title Roles library
/// @author Aave Labs
/// @notice Defines the different roles used by the protocol.
library Roles {
  uint64 public constant DEFAULT_ADMIN_ROLE = 0;
  uint64 public constant HUB_ADMIN_ROLE = 1;
  uint64 public constant SPOKE_ADMIN_ROLE = 2;
  uint64 public constant USER_POSITION_UPDATER_ROLE = 3;
}
