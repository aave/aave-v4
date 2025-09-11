// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Rescuable} from 'src/misc/Rescuable.sol';

import {ReentrancyGuardTransient} from 'src/dependencies/openzeppelin/ReentrancyGuardTransient.sol';
import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {Address} from 'src/dependencies/openzeppelin/Address.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';

import {DataTypes} from 'src/libraries/types/DataTypes.sol';

import {IWrappedTokenGatewayV4} from 'src/interfaces/IWrappedTokenGatewayV4.sol';
import {INativeWrapper} from 'src/interfaces/INativeWrapper.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';

/**
 * @notice Contract allowing users to approve it as a Position Manager to wrap and unwrap the native asset
 * before interacting with the Spoke.
 */
contract WrappedTokenGatewayV4 is IWrappedTokenGatewayV4, ReentrancyGuardTransient, Rescuable {
  using SafeERC20 for *;

  /// @notice Native Wrapper contract
  INativeWrapper public immutable NATIVE_WRAPPER;
  /// @notice Spoke contract
  ISpoke public immutable SPOKE;

  constructor(address nativeWrapper_, address spoke_, address admin_) Rescuable(admin_) {
    require(nativeWrapper_ != address(0) && spoke_ != address(0), InvalidAddress());
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
  function renouncePositionManagerRole() external payable {
    SPOKE.renouncePositionManagerRole(msg.sender);
  }

  /// @inheritdoc IWrappedTokenGatewayV4
  function renouncePositionManagerRoleForUser(address user) external onlyOwner {
    SPOKE.renouncePositionManagerRole(user);
  }

  /// @inheritdoc IWrappedTokenGatewayV4
  function supplyNative(uint256 reserveId, uint256 amount) external payable nonReentrant {
    (address underlying, address hub) = _getReserveData(reserveId);
    _validateParams(underlying, amount);
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
    (address underlying, ) = _getReserveData(reserveId);
    _validateParams(underlying, amount);
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
    (address underlying, ) = _getReserveData(reserveId);
    _validateParams(underlying, amount);
    require(receiver != address(0), InvalidAddress());

    SPOKE.borrow(reserveId, amount, msg.sender);
    NATIVE_WRAPPER.withdraw(amount);
    Address.sendValue(payable(receiver), amount);
  }

  /// @inheritdoc IWrappedTokenGatewayV4
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
    NATIVE_WRAPPER.safeIncreaseAllowance(hub, amount);
    SPOKE.repay(reserveId, amount, msg.sender);

    if (leftovers > 0) {
      Address.sendValue(payable(msg.sender), leftovers);
    }
  }

  /// @inheritdoc IWrappedTokenGatewayV4
  function setUsingAsCollateral(uint256 reserveId, bool usingAsCollateral) external payable {
    (address underlying, ) = _getReserveData(reserveId);
    require(underlying == address(NATIVE_WRAPPER), InvalidReserveId());
    SPOKE.setUsingAsCollateral(reserveId, usingAsCollateral, msg.sender);
  }

  /**
   * @notice Call multiple functions in the current contract and return the data from all of them if they all succeed.
   * @dev Function was inlined here so it can be payable.
   * @param data The encoded function data for each of the calls to make to this contract.
   * @return results The results from each of the calls passed in via data.
   */
  function multicall(bytes[] calldata data) external payable returns (bytes[] memory) {
    bytes[] memory results = new bytes[](data.length);
    for (uint256 i; i < data.length; ++i) {
      (bool ok, bytes memory res) = address(this).delegatecall(data[i]);

      assembly ('memory-safe') {
        if iszero(ok) {
          revert(add(res, 32), mload(res)) // bubble up first revert
        }
      }

      results[i] = res;
    }
    return results;
  }

  /**
   * @dev Validates the common parameters for all functions.
   **/
  function _validateParams(address underlying, uint256 amount) internal {
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
