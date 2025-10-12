// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';

/// @title INativeWrapper interface
/// @author Aave Labs
/// @notice Minimal interface for interacting with a wrapped native token contract.
interface INativeWrapper is IERC20 {
  /// @notice Deposit native currency and receive wrapped tokens.
  function deposit() external payable;

  /// @notice Withdraw native currency by burning wrapped tokens.
  /// @param amount The amount of wrapped tokens to burn for native currency.
  function withdraw(uint256 amount) external;
}
