// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Rescuable} from 'src/misc/Rescuable.sol';

import {ReentrancyGuardTransient} from 'src/dependencies/openzeppelin/ReentrancyGuardTransient.sol';
import {Ownable2Step, Ownable} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {Address} from 'src/dependencies/openzeppelin/Address.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';

import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';

import {INativeTokenGateway} from 'src/interfaces/INativeTokenGateway.sol';
import {INativeWrapper} from 'src/interfaces/INativeWrapper.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';

/**
 * @notice Contract allowing users to approve it as a Position Manager to wrap and unwrap the native asset
 * before interacting with the Spoke.
 */
contract NativeTokenGateway is
  INativeTokenGateway,
  ReentrancyGuardTransient,
  Rescuable,
  Ownable2Step
{
  using SafeERC20 for *;

  /// @notice Native Wrapper contract
  INativeWrapper public immutable NATIVE_WRAPPER;
  /// @notice Spoke contract
  ISpoke public immutable SPOKE;

  constructor(address nativeWrapper_, address spoke_, address admin_) Ownable(admin_) {
    require(nativeWrapper_ != address(0) && spoke_ != address(0), InvalidAddress());
    NATIVE_WRAPPER = INativeWrapper(payable(nativeWrapper_));
    SPOKE = ISpoke(spoke_);
  }

  /// @inheritdoc INativeTokenGateway
  function renouncePositionManagerRole(address user) external onlyOwner {
    SPOKE.renouncePositionManagerRole(user);
  }

  /// @inheritdoc INativeTokenGateway
  function supplyNative(uint256 reserveId, uint256 amount) external payable nonReentrant {
    (address underlying, address hub) = _getReserveData(reserveId);
    _validateParams(underlying, amount);
    require(msg.value == amount, NativeAmountMismatch());

    NATIVE_WRAPPER.deposit{value: amount}();
    NATIVE_WRAPPER.forceApprove(hub, amount);
    SPOKE.supply(reserveId, amount, msg.sender);
  }

  /// @inheritdoc INativeTokenGateway
  function withdrawNative(uint256 reserveId, uint256 amount, address receiver) external {
    (address underlying, ) = _getReserveData(reserveId);
    _validateParams(underlying, amount);
    require(receiver != address(0), InvalidAddress());

    amount = MathUtils.min(SPOKE.getUserSuppliedAmount(reserveId, msg.sender), amount);

    SPOKE.withdraw(reserveId, amount, msg.sender);
    NATIVE_WRAPPER.withdraw(amount);
    Address.sendValue(payable(receiver), amount);
  }

  /// @inheritdoc INativeTokenGateway
  function borrowNative(uint256 reserveId, uint256 amount, address receiver) external {
    (address underlying, ) = _getReserveData(reserveId);
    _validateParams(underlying, amount);
    require(receiver != address(0), InvalidAddress());

    SPOKE.borrow(reserveId, amount, msg.sender);
    NATIVE_WRAPPER.withdraw(amount);
    Address.sendValue(payable(receiver), amount);
  }

  /// @inheritdoc INativeTokenGateway
  function repayNative(uint256 reserveId, uint256 amount) external payable nonReentrant {
    (address underlying, address hub) = _getReserveData(reserveId);
    _validateParams(underlying, amount);
    require(msg.value == amount, NativeAmountMismatch());

    uint256 userDebtAmount = SPOKE.getUserTotalDebt(reserveId, msg.sender);
    uint256 leftovers;
    if (amount > userDebtAmount) {
      leftovers = amount - userDebtAmount;
      amount = userDebtAmount;
    }

    NATIVE_WRAPPER.deposit{value: amount}();
    NATIVE_WRAPPER.forceApprove(hub, amount);
    SPOKE.repay(reserveId, amount, msg.sender);

    if (leftovers > 0) {
      Address.sendValue(payable(msg.sender), leftovers);
    }
  }

  /// @inheritdoc Rescuable
  function rescueGuardian() public view override returns (address) {
    return owner();
  }

  /**
   * @dev Validates the common parameters for all functions.
   **/
  function _validateParams(address underlying, uint256 amount) internal view {
    require(underlying == address(NATIVE_WRAPPER), InvalidReserveId());
    require(amount > 0, InvalidAmount());
  }

  /**
   * @dev Fetches the wanted data for the Reserve from the Spoke.
   **/
  function _getReserveData(uint256 reserveId) internal view returns (address, address) {
    DataTypes.Reserve memory reserveData = SPOKE.getReserve(reserveId);
    return (reserveData.underlying, address(reserveData.hub));
  }

  /**
   * @dev Only NATIVE_WRAPPER contract is allowed to do native transfer here. Prevent other addresses from sending native assets to this contract.
   */
  receive() external payable {
    require(msg.sender == address(NATIVE_WRAPPER), ReceiveNotAllowed());
  }

  /**
   * @dev Revert fallback calls.
   */
  fallback() external payable {
    revert FallbackForbidden();
  }
}
