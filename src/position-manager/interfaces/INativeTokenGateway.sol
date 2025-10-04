// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IRescuable} from 'src/interfaces/IRescuable.sol';

/// @title INativeTokenGateway
/// @author Aave Labs
/// @notice Abstracts actions to the protocol involving the native token.
/// @dev Must be set as `PositionManager` on the spoke for the user.
interface INativeTokenGateway is IRescuable {
  /// @notice Thrown when the given address is invalid.
  error InvalidAddress();

  /// @notice Thrown when the given amount is invalid.
  error InvalidAmount();

  /// @notice Thrown when the underlying asset is not the wrapped native asset.
  error NotNativeWrappedAsset();

  /// @notice Thrown when the native amount sent does not match the given amount parameter.
  error NativeAmountMismatch();

  /// @notice Thrown when trying to call an unsupported action or sending native assets to this contract directly.
  error UnsupportedAction();

  /// @notice Wraps the native asset and supplies to the Spoke.
  /// @dev Contract must be an active & approved user position manager of the caller.
  /// @param reserveId The identifier of the reserve for the wrapped asset.
  /// @param amount Amount to wrap and supply.
  function supplyNative(uint256 reserveId, uint256 amount) external payable;

  /// @notice Withdraws the wrapped asset from the Spoke and unwraps it back to the native asset.
  /// @dev Contract must be an active & approved user position manager of the caller.
  /// @param reserveId The identifier of the reserve for the wrapped asset.
  /// @param amount Amount to withdraw and unwrap.
  /// @param receiver Address that will receive the unwrapped native asset.
  function withdrawNative(uint256 reserveId, uint256 amount, address receiver) external;

  /// @notice Borrows the wrapped asset from the Spoke and unwraps it back to the native asset.
  /// @dev Contract must be an active & approved user position manager of the caller.
  /// @param reserveId The identifier of the reserve for the wrapped asset.
  /// @param amount Amount to borrow and unwrap.
  /// @param receiver Address that will receive the unwrapped native asset.
  function borrowNative(uint256 reserveId, uint256 amount, address receiver) external;

  /// @notice Wraps the native asset and repays debt on the Spoke.
  /// @dev Contract must be an active & approved user position manager of the caller.
  /// @param reserveId The identifier of the reserve for the wrapped asset.
  /// @param amount Amount to wrap and repay.
  function repayNative(uint256 reserveId, uint256 amount) external payable;

  /// @notice Allows contract to renounce its position manager role for `user`.
  /// @dev Only authorized caller to invoke this method.
  function renouncePositionManagerRole(address user) external;

  /// @notice Returns the address of Native Wrapper.
  function NATIVE_WRAPPER() external view returns (address);

  /// @notice Returns the address of connected Spoke.
  function SPOKE() external view returns (address);
}
