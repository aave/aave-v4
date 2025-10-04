// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {ReentrancyGuardTransient} from 'src/dependencies/openzeppelin/ReentrancyGuardTransient.sol';
import {Ownable2Step, Ownable} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {Address} from 'src/dependencies/openzeppelin/Address.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {Rescuable} from 'src/utils/Rescuable.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {INativeWrapper} from 'src/position-manager/interfaces/INativeWrapper.sol';
import {INativeTokenGateway} from 'src/position-manager/interfaces/INativeTokenGateway.sol';

/// @title NativeTokenGateway
/// @author Aave Labs
/// @notice Gateway to interact with a spoke using the native coin of a chain.
/// @dev Contract must be an active & approved user position manager in order to execute spoke actions on a user's behalf.
contract NativeTokenGateway is
  INativeTokenGateway,
  ReentrancyGuardTransient,
  Rescuable,
  Ownable2Step
{
  using SafeERC20 for *;

  INativeWrapper internal immutable _nativeWrapper;
  ISpoke internal immutable _spoke;

  /// @dev Constructor.
  /// @param nativeWrapper_ The address of the native wrapper contract.
  /// @param spoke_ The address of the connected spoke.
  /// @param initialOwner_ The address of the initial owner.
  constructor(
    address nativeWrapper_,
    address spoke_,
    address initialOwner_
  ) Ownable(initialOwner_) {
    require(nativeWrapper_ != address(0) && spoke_ != address(0), InvalidAddress());
    _nativeWrapper = INativeWrapper(payable(nativeWrapper_));
    _spoke = ISpoke(spoke_);
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
  function renouncePositionManagerRole(address user) external onlyOwner {
    _spoke.renouncePositionManagerRole(user);
  }

  /// @inheritdoc INativeTokenGateway
  function supplyNative(uint256 reserveId, uint256 amount) external payable nonReentrant {
    (IERC20 underlying, address hub) = _getReserveData(reserveId);
    _validateParams(underlying, amount);
    require(msg.value == amount, NativeAmountMismatch());

    _nativeWrapper.deposit{value: amount}();
    _nativeWrapper.forceApprove(hub, amount);
    _spoke.supply(reserveId, amount, msg.sender);
  }

  /// @inheritdoc INativeTokenGateway
  function withdrawNative(uint256 reserveId, uint256 amount, address receiver) external {
    (IERC20 underlying, ) = _getReserveData(reserveId);
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
    (IERC20 underlying, ) = _getReserveData(reserveId);
    _validateParams(underlying, amount);
    require(receiver != address(0), InvalidAddress());

    _spoke.borrow(reserveId, amount, msg.sender);
    _nativeWrapper.withdraw(amount);
    Address.sendValue(payable(receiver), amount);
  }

  /// @inheritdoc INativeTokenGateway
  function repayNative(uint256 reserveId, uint256 amount) external payable nonReentrant {
    (IERC20 underlying, address hub) = _getReserveData(reserveId);
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

  /// @dev RescueGuardian is the owner of the contract.
  function _rescueGuardian() internal view override returns (address) {
    return owner();
  }

  function _validateParams(IERC20 underlying, uint256 amount) internal view {
    require(address(underlying) == address(_nativeWrapper), InvalidReserveId());
    require(amount > 0, InvalidAmount());
  }

  /// @return The underlying asset for `reserveId` on connected spoke.
  /// @return The corresponding hub address.
  function _getReserveData(uint256 reserveId) internal view returns (IERC20, address) {
    ISpoke.Reserve memory reserveData = _spoke.getReserve(reserveId);
    return (IERC20(reserveData.underlying), address(reserveData.hub));
  }
}
