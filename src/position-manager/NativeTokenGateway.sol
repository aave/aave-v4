// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {ReentrancyGuardTransient} from 'src/dependencies/openzeppelin/ReentrancyGuardTransient.sol';
import {Address} from 'src/dependencies/openzeppelin/Address.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {INativeWrapper} from 'src/position-manager/interfaces/INativeWrapper.sol';
import {INativeTokenGateway} from 'src/position-manager/interfaces/INativeTokenGateway.sol';
import {PositionManagerBase} from 'src/position-manager/PositionManagerBase.sol';

/// @title NativeTokenGateway
/// @author Aave Labs
/// @notice Gateway to interact with a spoke using the native coin of a chain.
contract NativeTokenGateway is INativeTokenGateway, PositionManagerBase, ReentrancyGuardTransient {
  using SafeERC20 for IERC20;

  /// @inheritdoc INativeTokenGateway
  address public immutable NATIVE_TOKEN_WRAPPER;

  /// @dev Constructor.
  /// @param nativeTokenWrapper_ The address of the native token wrapper contract.
  /// @param initialOwner_ The address of the initial owner.
  constructor(
    address nativeTokenWrapper_,
    address initialOwner_
  ) PositionManagerBase(initialOwner_) {
    require(nativeTokenWrapper_ != address(0), InvalidAddress());
    NATIVE_TOKEN_WRAPPER = nativeTokenWrapper_;
  }

  /// @dev Checks only 'nativeWrapper' can transfer native tokens.
  receive() external payable {
    require(msg.sender == NATIVE_TOKEN_WRAPPER, UnsupportedAction());
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
  ) external nonReentrant onlyRegisteredSpoke(spoke) returns (uint256, uint256) {
    address underlying = _getReserveUnderlying(spoke, reserveId);
    _validateParams(underlying, amount);

    (uint256 withdrawnShares, uint256 withdrawnAmount) = ISpoke(spoke).withdraw(
      reserveId,
      amount,
      msg.sender
    );
    INativeWrapper(NATIVE_TOKEN_WRAPPER).withdraw(withdrawnAmount);
    Address.sendValue(payable(msg.sender), withdrawnAmount);

    return (withdrawnShares, withdrawnAmount);
  }

  /// @inheritdoc INativeTokenGateway
  function borrowNative(
    address spoke,
    uint256 reserveId,
    uint256 amount
  ) external nonReentrant onlyRegisteredSpoke(spoke) returns (uint256, uint256) {
    address underlying = _getReserveUnderlying(spoke, reserveId);
    _validateParams(underlying, amount);

    (uint256 borrowedShares, uint256 borrowedAmount) = ISpoke(spoke).borrow(
      reserveId,
      amount,
      msg.sender
    );
    INativeWrapper(NATIVE_TOKEN_WRAPPER).withdraw(borrowedAmount);
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

    INativeWrapper(NATIVE_TOKEN_WRAPPER).deposit{value: repayAmount}();
    IERC20(NATIVE_TOKEN_WRAPPER).forceApprove(spoke, repayAmount);
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

  /// @dev `msg.value` verification must be done before calling this.
  function _supplyNative(
    address spoke,
    uint256 reserveId,
    address user,
    uint256 amount
  ) internal returns (uint256, uint256) {
    address underlying = _getReserveUnderlying(spoke, reserveId);
    _validateParams(underlying, amount);

    INativeWrapper(NATIVE_TOKEN_WRAPPER).deposit{value: amount}();
    IERC20(NATIVE_TOKEN_WRAPPER).forceApprove(spoke, amount);
    return ISpoke(spoke).supply(reserveId, amount, user);
  }

  function _validateParams(address underlying, uint256 amount) internal view {
    require(NATIVE_TOKEN_WRAPPER == underlying, NotNativeWrappedAsset());
    require(amount > 0, InvalidAmount());
  }

  /// @dev Multicall is disabled to prevent msg.value reuse across delegatecalls.
  function _multicallEnabled() internal pure override returns (bool) {
    return false;
  }
}
