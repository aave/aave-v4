// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IGatewayBase} from 'src/position-manager/interfaces/IGatewayBase.sol';
import {INativeWrapper} from 'src/position-manager/interfaces/INativeWrapper.sol';

/// @title INativeTokenGateway
/// @author Aave Labs
/// @notice Abstracts actions to the protocol involving the native token.
/// @dev Must be set as `PositionManager` on the spoke for the user.
interface INativeTokenGateway is IGatewayBase {
  /// @notice Thrown when the underlying asset is not the wrapped native asset.
  error NotNativeWrappedAsset();

  /// @notice Thrown when the native amount sent does not match the given amount parameter.
  error NativeAmountMismatch();

  /// @notice Thrown when trying to call an unsupported action or sending native assets to this contract directly.
  error UnsupportedAction();

  /// @notice Wraps the native asset and supplies to a specified registered `spoke`.
  /// @dev Contract must be an active & approved user position manager of the caller.
  /// @param spoke The address of the registered `spoke`.
  /// @param reserveId The identifier of the reserve for the wrapped asset.
  /// @param amount Amount to wrap and supply.
  /// @return The amount of shares supplied.
  /// @return The amount of assets supplied.
  function supplyNative(
    address spoke,
    uint256 reserveId,
    uint256 amount
  ) external payable returns (uint256, uint256);

  /// @notice Wraps the native asset,supplies to a specified registered `spoke` and sets it as collateral.
  /// @dev Contract must be an active & approved user position manager of the caller.
  /// @param spoke The address of the registered `spoke`.
  /// @param reserveId The identifier of the reserve for the wrapped asset.
  /// @param amount Amount to wrap and supply.
  /// @return The amount of shares supplied.
  /// @return The amount of assets supplied.
  function supplyAsCollateralNative(
    address spoke,
    uint256 reserveId,
    uint256 amount
  ) external payable returns (uint256, uint256);

  /// @notice Withdraws the wrapped asset from a specified registered `spoke` and unwraps it back to the native asset.
  /// @dev Contract must be an active & approved user position manager of the caller.
  /// @param spoke The address of the registered `spoke`.
  /// @param reserveId The identifier of the reserve for the wrapped asset.
  /// @param amount Amount to withdraw and unwrap.
  /// @return The amount of shares withdrawn.
  /// @return The amount of assets withdrawn.
  function withdrawNative(
    address spoke,
    uint256 reserveId,
    uint256 amount
  ) external returns (uint256, uint256);

  /// @notice Borrows the wrapped asset from a specified registered `spoke` and unwraps it back to the native asset.
  /// @dev Contract must be an active & approved user position manager of the caller.
  /// @param spoke The address of the registered `spoke`.
  /// @param reserveId The identifier of the reserve for the wrapped asset.
  /// @param amount Amount to borrow and unwrap.
  /// @return The amount of shares borrowed.
  /// @return The amount of assets borrowed.
  function borrowNative(
    address spoke,
    uint256 reserveId,
    uint256 amount
  ) external returns (uint256, uint256);

  /// @notice Wraps the native asset and repays debt on a specified registered `spoke`.
  /// @dev It refunds any excess funds sent beyond the required debt repayment.
  /// @dev Contract must be an active & approved user position manager of the caller.
  /// @param spoke The address of the registered `spoke`.
  /// @param reserveId The identifier of the reserve for the wrapped asset.
  /// @param amount Amount to wrap and repay.
  /// @return The amount of shares repaid.
  /// @return The amount of assets repaid.
  function repayNative(
    address spoke,
    uint256 reserveId,
    uint256 amount
  ) external payable returns (uint256, uint256);

  /// @notice Returns the address of the Native Wrapper.
  function NATIVE_WRAPPER() external view returns (address);
}
