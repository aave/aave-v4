// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';

/// @title INativeTokenGateway
/// @author Aave Labs
/// @notice Abstracts actions to the protocol involving the native token.
/// @dev Must be set as `PositionManager` on the Spoke for the user.
interface INativeTokenGateway is IPositionManagerBase {
  /// @notice Thrown when the underlying asset is not the wrapped native asset.
  error NotNativeWrappedAsset();

  /// @notice Thrown when the native amount sent does not match the given amount parameter.
  error NativeAmountMismatch();

  /// @notice Wraps the native asset and supplies to a specified registered Spoke.
  /// @dev Contract must be an active and approved user position manager of the caller.
  /// @param spoke The address of the registered Spoke.
  /// @param reserveId The identifier of the reserve for the wrapped asset.
  /// @param amount Amount to wrap and supply.
  /// @return The amount of shares supplied.
  /// @return The amount of assets supplied.
  function supplyNative(
    address spoke,
    uint256 reserveId,
    uint256 amount
  ) external payable returns (uint256, uint256);

  /// @notice Wraps the native asset, supplies to a specified registered Spoke and sets it as collateral.
  /// @dev Contract must be an active and approved user position manager of the caller.
  /// @param spoke The address of the registered Spoke.
  /// @param reserveId The identifier of the reserve for the wrapped asset.
  /// @param amount Amount to wrap and supply.
  /// @return The amount of shares supplied.
  /// @return The amount of assets supplied.
  function supplyAsCollateralNative(
    address spoke,
    uint256 reserveId,
    uint256 amount
  ) external payable returns (uint256, uint256);

  /// @notice Withdraws the wrapped asset from a specified registered Spoke and unwraps it back to the native asset.
  /// @dev Contract must be an active and approved user position manager of the caller.
  /// @dev The withdrawn amount may be lower than requested if the user has insufficient supplied assets.
  /// @param spoke The address of the registered Spoke.
  /// @param reserveId The identifier of the reserve for the wrapped asset.
  /// @param amount Amount to withdraw and unwrap.
  /// @return The amount of shares withdrawn.
  /// @return The amount of assets withdrawn.
  function withdrawNative(
    address spoke,
    uint256 reserveId,
    uint256 amount
  ) external returns (uint256, uint256);

  /// @notice Borrows the wrapped asset from a specified registered Spoke and unwraps it back to the native asset.
  /// @dev Contract must be an active and approved user position manager of the caller.
  /// @param spoke The address of the registered Spoke.
  /// @param reserveId The identifier of the reserve for the wrapped asset.
  /// @param amount Amount to borrow and unwrap.
  /// @return The amount of shares borrowed.
  /// @return The amount of assets borrowed.
  function borrowNative(
    address spoke,
    uint256 reserveId,
    uint256 amount
  ) external returns (uint256, uint256);

  /// @notice Wraps the native asset and repays debt on a specified registered Spoke.
  /// @dev It refunds any excess funds sent beyond the required debt repayment.
  /// @dev Contract must be an active and approved user position manager of the caller.
  /// @param spoke The address of the registered Spoke.
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
  function NATIVE_TOKEN_WRAPPER() external view returns (address);
}
