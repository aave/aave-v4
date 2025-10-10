// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {ReentrancyGuardTransient} from 'src/dependencies/openzeppelin/ReentrancyGuardTransient.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {Address} from 'src/dependencies/openzeppelin/Address.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {GatewayBase} from 'src/position-manager/GatewayBase.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {INativeWrapper} from 'src/position-manager/interfaces/INativeWrapper.sol';
import {INativeTokenGateway} from 'src/position-manager/interfaces/INativeTokenGateway.sol';

/// @title NativeTokenGateway
/// @author Aave Labs
/// @notice Gateway to interact with a spoke using the native coin of a chain.
/// @dev Contract must be an active & approved user position manager in order to execute spoke actions on a user's behalf.
contract NativeTokenGateway is INativeTokenGateway, ReentrancyGuardTransient, GatewayBase {
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
    address spokeAddress,
    uint256 reserveId,
    uint256 amount
  ) external payable nonReentrant onlyRegisteredSpoke(spokeAddress) {
    require(msg.value == amount, NativeAmountMismatch());
    _supplyNative(spokeAddress, reserveId, msg.sender, amount);
  }

  /// @inheritdoc INativeTokenGateway
  function supplyAsCollateralNative(
    address spokeAddress,
    uint256 reserveId,
    uint256 amount
  ) external payable nonReentrant onlyRegisteredSpoke(spokeAddress) {
    require(msg.value == amount, NativeAmountMismatch());
    _supplyNative(spokeAddress, reserveId, msg.sender, amount);
    ISpoke(spokeAddress).setUsingAsCollateral(reserveId, true, msg.sender);
  }

  /// @inheritdoc INativeTokenGateway
  function withdrawNative(
    address spokeAddress,
    uint256 reserveId,
    uint256 amount
  ) external onlyRegisteredSpoke(spokeAddress) {
    ISpoke spoke = ISpoke(spokeAddress);
    (IERC20 underlying,) = _getReserveData(spoke, reserveId);
    _validateParams(underlying, amount);

    uint256 withdrawAmount = MathUtils.min(
      amount,
      spoke.getUserSuppliedAssets(reserveId, msg.sender)
    );

    spoke.withdraw(reserveId, withdrawAmount, msg.sender);
    _nativeWrapper.withdraw(withdrawAmount);
    Address.sendValue(payable(msg.sender), withdrawAmount);
  }

  /// @inheritdoc INativeTokenGateway
  function borrowNative(
    address spokeAddress,
    uint256 reserveId,
    uint256 amount
  ) external onlyRegisteredSpoke(spokeAddress) {
    ISpoke spoke = ISpoke(spokeAddress);
    (IERC20 underlying,) = _getReserveData(spoke, reserveId);
    _validateParams(underlying, amount);

    spoke.borrow(reserveId, amount, msg.sender);
    _nativeWrapper.withdraw(amount);
    Address.sendValue(payable(msg.sender), amount);
  }

  /// @inheritdoc INativeTokenGateway
  function repayNative(
    address spokeAddress,
    uint256 reserveId,
    uint256 amount
  ) external payable nonReentrant onlyRegisteredSpoke(spokeAddress) {
    require(msg.value == amount, NativeAmountMismatch());
    ISpoke spoke = ISpoke(spokeAddress);
    (IERC20 underlying, address hub) = _getReserveData(spoke, reserveId);
    _validateParams(underlying, amount);

    uint256 userDebtAmount = spoke.getUserTotalDebt(reserveId, msg.sender);
    uint256 repayAmount = amount;
    uint256 leftovers;
    if (amount > userDebtAmount) {
      leftovers = amount - userDebtAmount;
      repayAmount = userDebtAmount;
    }

    _nativeWrapper.deposit{value: repayAmount}();
    _nativeWrapper.forceApprove(hub, repayAmount);
    spoke.repay(reserveId, repayAmount, msg.sender);

    if (leftovers > 0) {
      Address.sendValue(payable(msg.sender), leftovers);
    }
  }

  /// @inheritdoc INativeTokenGateway
  function NATIVE_WRAPPER() external view returns (address) {
    return address(_nativeWrapper);
  }

  function _supplyNative(
    address spokeAddress,
    uint256 reserveId,
    address user,
    uint256 amount
  ) internal {
    ISpoke spoke = ISpoke(spokeAddress);
    (IERC20 underlying, address hub) = _getReserveData(spoke, reserveId);
    _validateParams(underlying, amount);

    _nativeWrapper.deposit{value: amount}();
    _nativeWrapper.forceApprove(hub, amount);
    spoke.supply(reserveId, amount, user);
  }

  function _validateParams(IERC20 underlying, uint256 amount) internal view {
    require(address(underlying) == address(_nativeWrapper), NotNativeWrappedAsset());
    require(amount > 0, InvalidAmount());
  }
}
