// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {ReentrancyGuardTransient} from 'src/dependencies/openzeppelin/ReentrancyGuardTransient.sol';
import {Ownable2Step, Ownable} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {Address} from 'src/dependencies/openzeppelin/Address.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';

import {DataTypes} from 'src/libraries/types/DataTypes.sol';

import {IWrappedTokenGatewayV4} from 'src/interfaces/IWrappedTokenGatewayV4.sol';
import {INativeWrapper} from 'src/interfaces/INativeWrapper.sol';
import {Multicall} from 'src/misc/Multicall.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';

/**
 * @notice Contract allowing users to approve it as a Position Manager to wrap and unwrap the native asset
 * before interacting with the Spoke.
 */
contract WrappedTokenGatewayV4 is
  IWrappedTokenGatewayV4,
  Multicall,
  ReentrancyGuardTransient,
  Ownable2Step
{
  using SafeERC20 for *;

  /// @notice Native Wrapper contract
  INativeWrapper public immutable NATIVE_WRAPPER;
  /// @notice Spoke contract
  ISpoke public immutable SPOKE;

  constructor(address nativeWrapper_, address spoke_, address admin_) Ownable(admin_) {
    NATIVE_WRAPPER = INativeWrapper(payable(nativeWrapper_));
    SPOKE = ISpoke(spoke_);
  }

  /// @inheritdoc IWrappedTokenGatewayV4
  function setUserPositionManagerWithSig(
    address user,
    bool approve,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external payable {
    SPOKE.setUserPositionManagerWithSig(address(this), user, approve, deadline, v, r, s);
  }

  /// @inheritdoc IWrappedTokenGatewayV4
  function renouncePositionManagerRole(address user) external payable {
    SPOKE.renouncePositionManagerRole(user);
  }

  /// @inheritdoc IWrappedTokenGatewayV4
  function supplyNative(uint256 reserveId, uint256 amount) external payable nonReentrant {
    (address reserveAsset, address hub) = _getReserveData(reserveId);
    _validateParams(reserveAsset, amount);
    require(msg.value == amount, NativeAmountMismatch());

    NATIVE_WRAPPER.deposit{value: amount}();
    NATIVE_WRAPPER.safeIncreaseAllowance(hub, amount);
    SPOKE.supply(reserveId, amount, msg.sender);
  }

  /// @inheritdoc IWrappedTokenGatewayV4
  function withdrawNative(
    uint256 reserveId,
    uint256 amount,
    address receiver
  ) external payable nonReentrant {
    (address reserveAsset, ) = _getReserveData(reserveId);
    _validateParams(reserveAsset, amount);
    require(receiver != address(0), InvalidAddress());

    uint256 userSuppliedAmount = SPOKE.getUserSuppliedAmount(reserveId, msg.sender);
    if (amount == type(uint256).max) {
      amount = userSuppliedAmount;
    }

    SPOKE.withdraw(reserveId, amount, msg.sender);
    NATIVE_WRAPPER.withdraw(amount);
    Address.sendValue(payable(receiver), amount);
  }

  /// @inheritdoc IWrappedTokenGatewayV4
  function borrowNative(
    uint256 reserveId,
    uint256 amount,
    address receiver
  ) external payable nonReentrant {
    (address reserveAsset, ) = _getReserveData(reserveId);
    _validateParams(reserveAsset, amount);
    require(receiver != address(0), InvalidAddress());

    SPOKE.borrow(reserveId, amount, msg.sender);
    NATIVE_WRAPPER.withdraw(amount);
    Address.sendValue(payable(receiver), amount);
  }

  /// @inheritdoc IWrappedTokenGatewayV4
  function repayNative(uint256 reserveId, uint256 amount) external payable nonReentrant {
    (address reserveAsset, address hub) = _getReserveData(reserveId);
    _validateParams(reserveAsset, amount);
    require(msg.value == amount, NativeAmountMismatch());

    uint256 userDebtAmount = SPOKE.getUserTotalDebt(reserveId, msg.sender);
    uint256 leftovers;
    if (amount > userDebtAmount) {
      leftovers = amount - userDebtAmount;
      amount = userDebtAmount;
    }

    NATIVE_WRAPPER.deposit{value: amount}();
    NATIVE_WRAPPER.safeIncreaseAllowance(hub, amount);
    SPOKE.repay(reserveId, amount, msg.sender);

    if (leftovers > 0) {
      Address.sendValue(payable(msg.sender), leftovers);
    }
  }

  /**
   * @dev Validates the common parameters for all functions.
   **/
  function _validateParams(address reserveAsset, uint256 amount) internal {
    require(amount > 0, InvalidAmount());
    require(reserveAsset == address(NATIVE_WRAPPER), InvalidReserveId());
  }

  /**
   * @dev Fetches the wanted data for the Reserve from the Spoke.
   **/
  function _getReserveData(uint256 reserveId) internal view returns (address, address) {
    DataTypes.Reserve memory reserveData = SPOKE.getReserve(reserveId);
    return (reserveData.underlying, address(reserveData.hub));
  }

  /**
   * @notice Recovers ERC20 tokens sent to this contract.
   * @param token Address of the ERC20 token to recover.
   * @param to Address to send the recovered tokens to.
   **/
  function recoverToken(address token, address to) external onlyOwner {
    IERC20(token).safeTransfer(to, IERC20(token).balanceOf(address(this)));
  }

  /**
   * @notice Recovers native asset left in this contract.
   * @param to Address to send the recovered native asset to.
   * @param amount Amount of native asset to recover.
   **/
  function recoverNative(address to, uint256 amount) external onlyOwner {
    Address.sendValue(payable(to), amount);
  }

  /**
   * @dev Only NATIVE_WRAPPER contract is allowed to do native transfer here. Prevent other addresses to send native assets to this contract.
   */
  receive() external payable {
    require(msg.sender == address(NATIVE_WRAPPER), ReceiveNotAllowed());
  }

  /**
   * @dev Revert fallback calls
   */
  fallback() external payable {
    revert FallbackForbidden();
  }
}
