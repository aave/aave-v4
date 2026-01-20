// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

/// @title EIP712Types library
/// @author Aave Labs
/// @notice Defines type structs used in EIP712-typed signatures.
/// @dev Consolidated types to generate JsonBindings.sol using `forge bind-json` for vm.eip712* cheat-codes.
library EIP712Types {
  /// @dev Spoke Intents
  struct SetUserPositionManagers {
    address user;
    PositionManagerUpdate[] updates;
    uint256 nonce;
    uint256 deadline;
  }

  struct PositionManagerUpdate {
    address positionManager;
    bool approve;
  }

  struct Permit {
    address owner;
    address spender;
    uint256 value;
    uint256 nonce;
    uint256 deadline;
  }

  /// @dev SignatureGateway Params (nested in Actions)
  struct SupplyParams {
    address spoke;
    uint256 reserveId;
    uint256 amount;
  }

  struct WithdrawParams {
    address spoke;
    uint256 reserveId;
    uint256 amount;
  }

  struct BorrowParams {
    address spoke;
    uint256 reserveId;
    uint256 amount;
  }

  struct RepayParams {
    address spoke;
    uint256 reserveId;
    uint256 amount;
  }

  struct SetUsingAsCollateralParams {
    address spoke;
    uint256 reserveId;
    bool useAsCollateral;
  }

  struct UpdateUserRiskPremiumParams {
    address spoke;
  }

  struct UpdateUserDynamicConfigParams {
    address spoke;
  }

  /// @dev SignatureGateway Actions (contain nested Params)
  struct SupplyAction {
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
    SupplyParams params;
  }

  struct WithdrawAction {
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
    WithdrawParams params;
  }

  struct BorrowAction {
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
    BorrowParams params;
  }

  struct RepayAction {
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
    RepayParams params;
  }

  struct SetUsingAsCollateralAction {
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
    SetUsingAsCollateralParams params;
  }

  struct UpdateUserRiskPremiumAction {
    address user;
    uint256 nonce;
    uint256 deadline;
    UpdateUserRiskPremiumParams params;
  }

  struct UpdateUserDynamicConfigAction {
    address user;
    uint256 nonce;
    uint256 deadline;
    UpdateUserDynamicConfigParams params;
  }

  /// @dev Permit2 types for witness transfer
  struct TokenPermissions {
    address token;
    uint256 amount;
  }

  struct PermitWitnessTransferFromSupplyAction {
    TokenPermissions permitted;
    address spender;
    uint256 nonce;
    uint256 deadline;
    SupplyAction witness;
  }

  struct PermitWitnessTransferFromRepayAction {
    TokenPermissions permitted;
    address spender;
    uint256 nonce;
    uint256 deadline;
    RepayAction witness;
  }
}
