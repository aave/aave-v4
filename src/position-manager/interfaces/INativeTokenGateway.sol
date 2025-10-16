// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IGatewayBase} from 'src/position-manager/interfaces/IGatewayBase.sol';

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
  function supplyNative(address spoke, uint256 reserveId, uint256 amount) external payable;

  /// @notice Wraps the native asset,supplies to a specified registered `spoke` and sets it as collateral.
  /// @dev Contract must be an active & approved user position manager of the caller.
  /// @param spoke The address of the registered `spoke`.
  /// @param reserveId The identifier of the reserve for the wrapped asset.
  /// @param amount Amount to wrap and supply.
  function supplyAsCollateralNative(
    address spoke,
    uint256 reserveId,
    uint256 amount
  ) external payable;

  /// @notice Withdraws the wrapped asset from a specified registered `spoke` and unwraps it back to the native asset.
  /// @dev Contract must be an active & approved user position manager of the caller.
  /// @param spoke The address of the registered `spoke`.
  /// @param reserveId The identifier of the reserve for the wrapped asset.
  /// @param amount Amount to withdraw and unwrap.
  function withdrawNative(address spoke, uint256 reserveId, uint256 amount) external;

  /// @notice Borrows the wrapped asset from a specified registered `spoke` and unwraps it back to the native asset.
  /// @dev Contract must be an active & approved user position manager of the caller.
  /// @param spoke The address of the registered `spoke`.
  /// @param reserveId The identifier of the reserve for the wrapped asset.
  /// @param amount Amount to borrow and unwrap.
  function borrowNative(address spoke, uint256 reserveId, uint256 amount) external;

  /// @notice Wraps the native asset and repays debt on a specified registered `spoke`.
  /// @dev It refunds any excess funds sent beyond the required debt repayment.
  /// @dev Contract must be an active & approved user position manager of the caller.
  /// @param spoke The address of the registered `spoke`.
  /// @param reserveId The identifier of the reserve for the wrapped asset.
  /// @param amount Amount to wrap and repay.
  function repayNative(address spoke, uint256 reserveId, uint256 amount) external payable;

  /// @notice Returns the address of Native Wrapper.
  function NATIVE_WRAPPER() external view returns (address);
}
