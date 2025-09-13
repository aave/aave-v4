// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Rescuable} from 'src/misc/Rescuable.sol';

import {ReentrancyGuardTransient} from 'src/dependencies/openzeppelin/ReentrancyGuardTransient.sol';
import {Ownable2Step, Ownable} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {Address} from 'src/dependencies/openzeppelin/Address.sol';

import {MathUtils} from 'src/libraries/math/MathUtils.sol';

import {INativeTokenGateway} from 'src/interfaces/INativeTokenGateway.sol';
import {INativeWrapper} from 'src/interfaces/INativeWrapper.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';

/**
 * @title NativeTokenGateway
 * @author Aave Labs
 * @notice Gateway to interact with the spoke using the native coin of a chain.
 * @dev This contract needs to be an active & approved user position manager in order execute spoke actions on user's behalf.
 */
contract NativeTokenGateway is
  INativeTokenGateway,
  ReentrancyGuardTransient,
  Rescuable,
  Ownable2Step
{
  using SafeERC20 for *;

  INativeWrapper internal immutable _nativeWrapper;
  ISpoke internal immutable _spoke;

  constructor(
    address nativeWrapper_,
    address spoke_,
    address initialOwner_
  ) Ownable(initialOwner_) {
    require(nativeWrapper_ != address(0) && spoke_ != address(0), InvalidAddress());
    _nativeWrapper = INativeWrapper(payable(nativeWrapper_));
    _spoke = ISpoke(spoke_);
  }

  /// @inheritdoc INativeTokenGateway
  function renouncePositionManagerRole(address user) external onlyOwner {
    _spoke.renouncePositionManagerRole(user);
  }

  /// @inheritdoc INativeTokenGateway
  function supplyNative(uint256 reserveId, uint256 amount) external payable nonReentrant {
    (address underlying, address hub) = _getReserveData(reserveId);
    _validateParams(underlying, amount);
    require(msg.value == amount, NativeAmountMismatch());

    _nativeWrapper.deposit{value: amount}();
    _nativeWrapper.forceApprove(hub, amount);
    _spoke.supply(reserveId, amount, msg.sender);
  }

  /// @inheritdoc INativeTokenGateway
  function withdrawNative(uint256 reserveId, uint256 amount, address receiver) external {
    (address underlying, ) = _getReserveData(reserveId);
    _validateParams(underlying, amount);
    require(receiver != address(0), InvalidAddress());

    uint256 withdrawAmount = MathUtils.min(
      amount,
      _spoke.getUserSuppliedAssets(reserveId, msg.sender)
    );

    _spoke.withdraw(reserveId, withdrawAmount, msg.sender);
    _nativeWrapper.withdraw(withdrawAmount);
    Address.sendValue(payable(receiver), withdrawAmount);
  }

  /// @inheritdoc INativeTokenGateway
  function borrowNative(uint256 reserveId, uint256 amount, address receiver) external {
    (address underlying, ) = _getReserveData(reserveId);
    _validateParams(underlying, amount);
    require(receiver != address(0), InvalidAddress());

    _spoke.borrow(reserveId, amount, msg.sender);
    _nativeWrapper.withdraw(amount);
    Address.sendValue(payable(receiver), amount);
  }

  /// @inheritdoc INativeTokenGateway
  function repayNative(uint256 reserveId, uint256 amount) external payable nonReentrant {
    (address underlying, address hub) = _getReserveData(reserveId);
    _validateParams(underlying, amount);
    require(msg.value == amount, NativeAmountMismatch());

    uint256 userDebtAmount = _spoke.getUserTotalDebt(reserveId, msg.sender);
    uint256 repayAmount = amount;
    uint256 leftovers;
    if (amount > userDebtAmount) {
      leftovers = amount - userDebtAmount;
      repayAmount = userDebtAmount;
    }

    _nativeWrapper.deposit{value: repayAmount}();
    _nativeWrapper.forceApprove(hub, repayAmount);
    _spoke.repay(reserveId, repayAmount, msg.sender);

    if (leftovers > 0) {
      Address.sendValue(payable(msg.sender), leftovers);
    }
  }

  /// @inheritdoc INativeTokenGateway
  function NATIVE_WRAPPER() external view returns (address) {
    return address(_nativeWrapper);
  }

  /// @inheritdoc INativeTokenGateway
  function SPOKE() external view returns (address) {
    return address(_spoke);
  }

  function _rescueGuardian() internal view override returns (address) {
    return owner();
  }

  function _validateParams(address underlying, uint256 amount) internal view {
    require(underlying == address(_nativeWrapper), InvalidReserveId());
    require(amount > 0, InvalidAmount());
  }

  function _getReserveData(uint256 reserveId) internal view returns (address, address) {
    ISpoke.Reserve memory reserveData = _spoke.getReserve(reserveId);
    return (reserveData.underlying, address(reserveData.hub));
  }

  receive() external payable {
    require(msg.sender == address(_nativeWrapper), UnsupportedAction());
  }

  fallback() external payable {
    revert UnsupportedAction();
  }
}
