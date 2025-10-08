// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {ReentrancyGuardTransient} from 'src/dependencies/openzeppelin/ReentrancyGuardTransient.sol';
import {Ownable2Step, Ownable} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {Address} from 'src/dependencies/openzeppelin/Address.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {GatewayBase} from 'src/position-manager/GatewayBase.sol';
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
    address spoke_,
    uint256 reserveId_,
    uint256 amount_
  ) external payable nonReentrant onlyRegisteredSpoke(spoke_) {
    _supplyNative(spoke_, reserveId_, amount_, msg.sender, false);
  }

  /// @inheritdoc INativeTokenGateway
  function supplyAndCollateralNative(
    address spoke_,
    uint256 reserveId_,
    uint256 amount_
  ) external payable nonReentrant onlyRegisteredSpoke(spoke_) {
    _supplyNative(spoke_, reserveId_, amount_, msg.sender, true);
  }

  /// @inheritdoc INativeTokenGateway
  function withdrawNative(
    address spoke_,
    uint256 reserveId_,
    uint256 amount_
  ) external onlyRegisteredSpoke(spoke_) {
    ISpoke spoke = ISpoke(spoke_);
    (IERC20 underlying, address hub) = _getReserveData(spoke, reserveId_);
    _validateParams(underlying, amount_);

    uint256 withdrawAmount = MathUtils.min(
      amount_,
      spoke.getUserSuppliedAssets(reserveId_, msg.sender)
    );

    spoke.withdraw(reserveId_, withdrawAmount, msg.sender);
    _nativeWrapper.withdraw(withdrawAmount);
    Address.sendValue(payable(msg.sender), withdrawAmount);
  }

  /// @inheritdoc INativeTokenGateway
  function borrowNative(
    address spoke_,
    uint256 reserveId_,
    uint256 amount_
  ) external onlyRegisteredSpoke(spoke_) {
    ISpoke spoke = ISpoke(spoke_);
    (IERC20 underlying, address hub) = _getReserveData(spoke, reserveId_);
    _validateParams(underlying, amount_);

    spoke.borrow(reserveId_, amount_, msg.sender);
    _nativeWrapper.withdraw(amount_);
    Address.sendValue(payable(msg.sender), amount_);
  }

  /// @inheritdoc INativeTokenGateway
  function repayNative(
    address spoke_,
    uint256 reserveId_,
    uint256 amount_
  ) external payable nonReentrant onlyRegisteredSpoke(spoke_) {
    ISpoke spoke = ISpoke(spoke_);
    (IERC20 underlying, address hub) = _getReserveData(spoke, reserveId_);
    _validateParams(underlying, amount_);
    require(msg.value == amount_, NativeAmountMismatch());

    uint256 userDebtAmount = spoke.getUserTotalDebt(reserveId_, msg.sender);
    uint256 repayAmount = amount_;
    uint256 leftovers;
    if (amount_ > userDebtAmount) {
      leftovers = amount_ - userDebtAmount;
      repayAmount = userDebtAmount;
    }

    _nativeWrapper.deposit{value: repayAmount}();
    _nativeWrapper.forceApprove(hub, repayAmount);
    spoke.repay(reserveId_, repayAmount, msg.sender);

    if (leftovers > 0) {
      Address.sendValue(payable(msg.sender), leftovers);
    }
  }

  /// @inheritdoc INativeTokenGateway
  function NATIVE_WRAPPER() external view returns (address) {
    return address(_nativeWrapper);
  }

  function _validateParams(IERC20 underlying, uint256 amount) internal view {
    require(address(underlying) == address(_nativeWrapper), NotNativeWrappedAsset());
    require(amount > 0, InvalidAmount());
  }

  function _supplyNative(
    address spoke_,
    uint256 reserveId_,
    uint256 amount_,
    address user_,
    bool enableCollateral_
  ) internal {
    ISpoke spoke = ISpoke(spoke_);
    (IERC20 underlying, address hub) = _getReserveData(spoke, reserveId_);
    _validateParams(underlying, amount_);
    require(msg.value == amount_, NativeAmountMismatch());

    _nativeWrapper.deposit{value: amount_}();
    _nativeWrapper.forceApprove(hub, amount_);
    spoke.supply(reserveId_, amount_, user_);

    if (enableCollateral_) {
      spoke.setUsingAsCollateral(reserveId_, true, user_);
    }
  }
}
