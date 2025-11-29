// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {ReentrancyGuardTransient} from 'src/dependencies/openzeppelin/ReentrancyGuardTransient.sol';
import {Address} from 'src/dependencies/openzeppelin/Address.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {GatewayBase} from 'src/position-manager/GatewayBase.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {INativeWrapper} from 'src/position-manager/interfaces/INativeWrapper.sol';
import {INativeTokenGateway} from 'src/position-manager/interfaces/INativeTokenGateway.sol';

/// @title NativeTokenGateway
/// @author Aave Labs
/// @notice Gateway to interact with a spoke using the native coin of a chain.
/// @dev Contract must be an active & approved user position manager in order to execute spoke actions on a user's behalf.
contract NativeTokenGateway is INativeTokenGateway, GatewayBase, ReentrancyGuardTransient {
  using SafeERC20 for *;

  INativeWrapper internal immutable _nativeWrapper;

  /// @dev Constructor.
  /// @param nativeWrapper_ The address of the native wrapper contract.
  /// @param initialOwner_ The address of the initial owner.
  constructor(address nativeWrapper_, address initialOwner_) GatewayBase(initialOwner_) {
    require(nativeWrapper_ != address(0), InvalidAddress());
    _nativeWrapper = INativeWrapper(payable(nativeWrapper_));
  }

  /// @dev Checks only 'nativeWrapper' can transfer native tokens.
  receive() external payable {
    require(msg.sender == address(_nativeWrapper), UnsupportedAction());
  }

  /// @dev Unsupported fallback function.
  fallback() external payable {
    revert UnsupportedAction();
  }

  /// @inheritdoc INativeTokenGateway
  function supplyNative(
    address spoke,
    uint256 reserveId,
    uint256 amount
  ) external payable nonReentrant onlyRegisteredSpoke(spoke) returns (uint256, uint256) {
    require(msg.value == amount, NativeAmountMismatch());
    return _supplyNative(spoke, reserveId, msg.sender, amount);
  }

  /// @inheritdoc INativeTokenGateway
  function supplyAsCollateralNative(
    address spoke,
    uint256 reserveId,
    uint256 amount
  ) external payable nonReentrant onlyRegisteredSpoke(spoke) returns (uint256, uint256) {
    require(msg.value == amount, NativeAmountMismatch());
    (uint256 suppliedShares, uint256 suppliedAmount) = _supplyNative(
      spoke,
      reserveId,
      msg.sender,
      amount
    );
    ISpoke(spoke).setUsingAsCollateral(reserveId, true, msg.sender);

    return (suppliedShares, suppliedAmount);
  }

  /// @inheritdoc INativeTokenGateway
  function withdrawNative(
    address spoke,
    uint256 reserveId,
    uint256 amount
  ) external onlyRegisteredSpoke(spoke) returns (uint256, uint256) {
    address underlying = _getReserveUnderlying(spoke, reserveId);
    _validateParams(underlying, amount);

    (uint256 withdrawnShares, uint256 withdrawnAmount) = ISpoke(spoke).withdraw(
      reserveId,
      amount,
      msg.sender
    );
    _nativeWrapper.withdraw(withdrawnAmount);
    Address.sendValue(payable(msg.sender), withdrawnAmount);

    return (withdrawnShares, withdrawnAmount);
  }

  /// @inheritdoc INativeTokenGateway
  function borrowNative(
    address spoke,
    uint256 reserveId,
    uint256 amount
  ) external onlyRegisteredSpoke(spoke) returns (uint256, uint256) {
    address underlying = _getReserveUnderlying(spoke, reserveId);
    _validateParams(underlying, amount);

    (uint256 borrowedShares, uint256 borrowedAmount) = ISpoke(spoke).borrow(
      reserveId,
      amount,
      msg.sender
    );
    _nativeWrapper.withdraw(borrowedAmount);
    Address.sendValue(payable(msg.sender), borrowedAmount);

    return (borrowedShares, borrowedAmount);
  }

  /// @inheritdoc INativeTokenGateway
  function repayNative(
    address spoke,
    uint256 reserveId,
    uint256 amount
  ) external payable nonReentrant onlyRegisteredSpoke(spoke) returns (uint256, uint256) {
    require(msg.value == amount, NativeAmountMismatch());
    address underlying = _getReserveUnderlying(spoke, reserveId);
    _validateParams(underlying, amount);

    uint256 userTotalDebt = ISpoke(spoke).getUserTotalDebt(reserveId, msg.sender);
    uint256 repayAmount = amount;
    uint256 leftovers;
    if (amount > userTotalDebt) {
      leftovers = amount - userTotalDebt;
      repayAmount = userTotalDebt;
    }

    _nativeWrapper.deposit{value: repayAmount}();
    _nativeWrapper.forceApprove(spoke, repayAmount);
    (uint256 repaidShares, uint256 repaidAmount) = ISpoke(spoke).repay(
      reserveId,
      repayAmount,
      msg.sender
    );

    if (leftovers > 0) {
      Address.sendValue(payable(msg.sender), leftovers);
    }

    return (repaidShares, repaidAmount);
  }

  /// @inheritdoc INativeTokenGateway
  function NATIVE_WRAPPER() external view returns (address) {
    return address(_nativeWrapper);
  }

  /// @dev `msg.value` verification must be done before calling this.
  function _supplyNative(
    address spoke,
    uint256 reserveId,
    address user,
    uint256 amount
  ) internal returns (uint256, uint256) {
    address underlying = _getReserveUnderlying(spoke, reserveId);
    _validateParams(underlying, amount);

    _nativeWrapper.deposit{value: amount}();
    _nativeWrapper.forceApprove(spoke, amount);
    return ISpoke(spoke).supply(reserveId, amount, user);
  }

  function _validateParams(address underlying, uint256 amount) internal view {
    require(address(_nativeWrapper) == underlying, NotNativeWrappedAsset());
    require(amount > 0, InvalidAmount());
  }
}
