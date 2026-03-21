// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

/// @title ISpokeHandler
/// @notice Interface for the SpokeHandler
interface ISpokeHandler {
  function supply(uint256 amount, uint8 i, uint8 j, uint8 k) external;
  function withdraw(uint256 amount, uint8 i, uint8 j, uint8 k) external;
  function borrow(uint256 amount, uint8 i, uint8 j, uint8 k) external;
  function repay(uint256 amount, uint8 i, uint8 j, uint8 k) external;
  function liquidationCall(
    uint256 debtToCover,
    bool receiveShares,
    uint8 i,
    uint8 j,
    uint8 k,
    uint8 l
  ) external;
  function setUsingAsCollateral(bool usingAsCollateral, uint8 i, uint8 j) external;
  function updateUserRiskPremium(uint8 i) external;
  function updateUserDynamicConfig(uint8 i) external;
  function setUserPositionManager(bool approve, uint8 i, uint8 j) external;
}
