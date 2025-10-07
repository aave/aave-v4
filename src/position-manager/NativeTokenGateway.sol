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
    address spoke,
    uint256 reserveId,
    uint256 amount
  ) external payable nonReentrant {
    _supplyNative(spoke, reserveId, amount, msg.sender, false);
  }

  /// @inheritdoc INativeTokenGateway
  function supplyAndCollateralNative(
    address spoke,
    uint256 reserveId,
    uint256 amount
  ) external payable nonReentrant {
    _supplyNative(spoke, reserveId, amount, msg.sender, true);
  }

  /// @inheritdoc INativeTokenGateway
  function withdrawNative(address spoke, uint256 reserveId, uint256 amount) external {
    _validateParams(spoke, amount);
    ISpoke _spoke = ISpoke(spoke);
    (IERC20 underlying, address hub) = _getReserveData(_spoke, reserveId);
    _validateUnderlying(underlying);

    uint256 withdrawAmount = MathUtils.min(
      amount,
      _spoke.getUserSuppliedAssets(reserveId, msg.sender)
    );

    _spoke.withdraw(reserveId, withdrawAmount, msg.sender);
    _nativeWrapper.withdraw(withdrawAmount);
    Address.sendValue(payable(msg.sender), withdrawAmount);
  }

  /// @inheritdoc INativeTokenGateway
  function borrowNative(address spoke, uint256 reserveId, uint256 amount) external {
    _validateParams(spoke, amount);
    ISpoke _spoke = ISpoke(spoke);
    (IERC20 underlying, address hub) = _getReserveData(_spoke, reserveId);
    _validateUnderlying(underlying);

    _spoke.borrow(reserveId, amount, msg.sender);
    _nativeWrapper.withdraw(amount);
    Address.sendValue(payable(msg.sender), amount);
  }

  /// @inheritdoc INativeTokenGateway
  function repayNative(
    address spoke,
    uint256 reserveId,
    uint256 amount
  ) external payable nonReentrant {
    _validateParams(spoke, amount);
    ISpoke _spoke = ISpoke(spoke);
    (IERC20 underlying, address hub) = _getReserveData(_spoke, reserveId);
    _validateUnderlying(underlying);
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

  function _validateParams(address spoke, uint256 amount) internal view {
    _validateSpoke(spoke);
    require(amount > 0, InvalidAmount());
  }

  function _validateUnderlying(IERC20 underlying) internal view {
    require(address(underlying) == address(_nativeWrapper), NotNativeWrappedAsset());
  }

  /// @return The underlying asset for `reserveId` on the given spoke.
  /// @return The corresponding hub address.
  function _getReserveData(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (IERC20, address) {
    ISpoke.Reserve memory reserveData = spoke.getReserve(reserveId);
    return (IERC20(reserveData.underlying), address(reserveData.hub));
  }

  function _supplyNative(
    address spoke,
    uint256 reserveId,
    uint256 amount,
    address user,
    bool enableCollateral
  ) internal {
    _validateParams(spoke, amount);
    ISpoke _spoke = ISpoke(spoke);
    (IERC20 underlying, address hub) = _getReserveData(_spoke, reserveId);
    _validateUnderlying(underlying);
    require(msg.value == amount, NativeAmountMismatch());

    _nativeWrapper.deposit{value: amount}();
    _nativeWrapper.forceApprove(hub, amount);
    _spoke.supply(reserveId, amount, user);

    if (enableCollateral) {
      _spoke.setUsingAsCollateral(reserveId, true, user);
    }
  }
}
