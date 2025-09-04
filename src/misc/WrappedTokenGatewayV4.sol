// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Multicall} from 'src/misc/Multicall.sol';

import {Ownable2Step, Ownable} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {Address} from 'src/dependencies/openzeppelin/Address.sol';
import {ReentrancyGuardTransient} from 'src/dependencies/openzeppelin/ReentrancyGuardTransient.sol';

import {IWETH} from 'src/dependencies/weth/IWETH.sol';

import {DataTypes} from 'src/libraries/types/DataTypes.sol';

import {IWrappedTokenGatewayV4} from 'src/interfaces/IWrappedTokenGatewayV4.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';

contract WrappedTokenGatewayV4 is
  IWrappedTokenGatewayV4,
  Multicall,
  ReentrancyGuardTransient,
  Ownable2Step
{
  using SafeERC20 for *;

  IWETH public immutable WETH;
  ISpoke public immutable SPOKE;

  constructor(address weth_, address spoke_, address admin_) Ownable(admin_) {
    WETH = IWETH(payable(weth_));
    SPOKE = ISpoke(spoke_);
  }

  function setUserPositionManagerWithSig(
    address user,
    bool approve,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    SPOKE.setUserPositionManagerWithSig(address(this), user, approve, deadline, v, r, s);
  }

  function renouncePositionManagerRole() external {
    SPOKE.renouncePositionManagerRole(msg.sender);
  }

  function supplyNative(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external payable nonReentrant {
    _validateParams(reserveId, amount, onBehalfOf, msg.sender);
    require(msg.value == amount, NativeAmountMismatch());

    WETH.deposit{value: amount}();
    WETH.safeIncreaseAllowance(_getReserveHub(reserveId), amount);
    SPOKE.supply(reserveId, amount, onBehalfOf);
  }

  function withdrawNative(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external nonReentrant {
    _validateParams(reserveId, amount, onBehalfOf, msg.sender);

    uint256 userSuppliedAmount = SPOKE.getUserSuppliedAmount(reserveId, onBehalfOf);
    if (amount == type(uint256).max) {
      amount = userSuppliedAmount;
    }

    SPOKE.withdraw(reserveId, amount, onBehalfOf);
    WETH.withdraw(amount);
    Address.sendValue(payable(onBehalfOf), amount);
  }

  function borrowNative(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external nonReentrant {
    _validateParams(reserveId, amount, onBehalfOf, msg.sender);

    SPOKE.borrow(reserveId, amount, onBehalfOf);
    WETH.withdraw(amount);
    Address.sendValue(payable(onBehalfOf), amount);
  }

  function repayNative(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external payable nonReentrant {
    _validateParams(reserveId, amount, onBehalfOf, msg.sender);
    require(msg.value == amount, NativeAmountMismatch());

    uint256 userDebtAmount = SPOKE.getUserTotalDebt(reserveId, onBehalfOf);
    uint256 leftovers;
    if (amount > userDebtAmount) {
      leftovers = amount - userDebtAmount;
      amount = userDebtAmount;
    }

    WETH.deposit{value: amount}();
    WETH.safeIncreaseAllowance(_getReserveHub(reserveId), amount);
    SPOKE.repay(reserveId, amount, onBehalfOf);

    if (leftovers > 0) {
      Address.sendValue(payable(msg.sender), leftovers);
    }
  }

  function _validateParams(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf,
    address caller
  ) internal {
    require(amount > 0, AmountNull());
    require(onBehalfOf != address(0), AddressZero());
    require(caller == onBehalfOf, InvalidCaller());
    require(_getReserveAsset(reserveId) == address(WETH), InvalidReserveId());
  }

  function _getReserveAsset(uint256 reserveId) internal view returns (address) {
    return SPOKE.getReserve(reserveId).underlying;
  }

  function _getReserveHub(uint256 reserveId) internal view returns (address) {
    return address(SPOKE.getReserve(reserveId).hub);
  }

  function recoverToken(address token, address to) external onlyOwner {
    IERC20(token).safeTransfer(to, IERC20(token).balanceOf(address(this)));
  }

  function recoverNative(address to, uint256 amount) external onlyOwner {
    Address.sendValue(payable(to), amount);
  }

  /**
   * @dev Only WETH contract is allowed to do native transfer here. Prevent other addresses to send native assets to this contract.
   */
  receive() external payable {
    require(msg.sender == address(WETH), ReceiveNotAllowed());
  }

  /**
   * @dev Revert fallback calls
   */
  fallback() external payable {
    revert FallbackForbidden();
  }
}
