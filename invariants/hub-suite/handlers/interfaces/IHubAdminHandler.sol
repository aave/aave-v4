// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

/// @title IHubAdminHandler
/// @notice Interface for the HubAdminHandler — targets hub-level admin operations
///         that are not spoke-restricted: liquidity reinvestment (sweep/reclaim)
///         and fee share minting (mintFeeShares).
interface IHubAdminHandler {
  function sweep(uint256 amount, uint8 i, uint8 j) external;

  function reclaim(uint256 amount, uint8 i, uint8 j) external;

  function mintFeeShares(uint8 i, uint8 j) external;
}
