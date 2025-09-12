// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {INativeWrapper} from 'src/interfaces/INativeWrapper.sol';
import {IRescuable} from 'src/interfaces/IRescuable.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';

interface INativeTokenGateway is IRescuable {
  error InvalidAddress();
  error InvalidAmount();
  error InvalidReserveId();
  error NativeAmountMismatch();
  error NativeTransferFailed();
  error FallbackForbidden();
  error ReceiveNotAllowed();

  /**
   * @notice Wraps the native asset and supply in the Spoke.
   * @param reserveId Reserve Id for the wrapped asset.
   * @param amount Amount to wrap and supply.
   **/
  function supplyNative(uint256 reserveId, uint256 amount) external payable;

  /**
   * @notice Withdraws the wrapped asset from the Spoke and unwraps it back to the native asset.
   * @param reserveId Reserve Id for the wrapped asset.
   * @param amount Amount to withdraw and unwrap.
   * @param receiver Address that will receive the unwrapped native asset.
   **/
  function withdrawNative(uint256 reserveId, uint256 amount, address receiver) external;

  /**
   * @notice Borrows the wrapped asset from the Spoke and unwraps it back to the native asset.
   * @param reserveId Reserve Id for the wrapped asset.
   * @param amount Amount to borrow and unwrap.
   * @param receiver Address that will receive the unwrapped native asset.
   **/
  function borrowNative(uint256 reserveId, uint256 amount, address receiver) external;

  /**
   * @notice Wraps the native asset and repay debt on the Spoke.
   * @param reserveId Reserve Id for the wrapped asset.
   * @param amount Amount to wrap and repay.
   **/
  function repayNative(uint256 reserveId, uint256 amount) external payable;

  /**
   * @notice Renounces the positionManager approval given by an user.
   * @param user The address of the user.
   */
  function renouncePositionManagerRole(address user) external;

  /// @notice Native Wrapper contract
  function NATIVE_WRAPPER() external view returns (INativeWrapper);

  /// @notice Spoke contract
  function SPOKE() external view returns (ISpoke);
}
