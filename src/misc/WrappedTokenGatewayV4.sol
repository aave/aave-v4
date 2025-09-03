// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AccessManaged} from 'src/dependencies/openzeppelin/AccessManaged.sol';
import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';

import {ReentrancyGuard} from 'src/dependencies/solady/ReentrancyGuard.sol';

import {WETH9} from 'src/dependencies/weth/WETH9.sol';

import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {IWrappedTokenGatewayV4} from 'src/interfaces/IWrappedTokenGatewayV4.sol';
import {ISpoke, ISpokeBase} from 'src/interfaces/ISpoke.sol';
import {Multicall} from 'src/misc/Multicall.sol';

contract WrappedTokenGatewayV4 is
  IWrappedTokenGatewayV4,
  Multicall,
  ReentrancyGuard,
  AccessManaged
{
  using SafeERC20 for IERC20;

  WETH9 public immutable WRAPPED_ASSET;

  constructor(address nativeAsset_, address authority_) AccessManaged(authority_) {
    WRAPPED_ASSET = WETH9(payable(nativeAsset_));
  }

  function setUserPositionManagerWithSig(
    address spoke,
    address user,
    bool approve,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    require(spoke != address(0) && user != address(0), AddressZero());
    ISpoke(spoke).setUserPositionManagerWithSig(address(this), user, approve, deadline, v, r, s);
  }

  function supplyNative(
    address spoke,
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external payable nonReentrant {
    _verifyParameters(spoke, reserveId, amount, onBehalfOf);

    if (msg.value != amount) revert NativeAmountMismatch();

    _wrapNative(amount);
    IERC20(address(WRAPPED_ASSET)).safeIncreaseAllowance(spoke, amount);
    ISpokeBase(spoke).supply(reserveId, amount, onBehalfOf);
  }

  function withdrawNative(
    address spoke,
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external nonReentrant {
    _verifyParameters(spoke, reserveId, amount, onBehalfOf);

    uint256 userSuppliedAmount = ISpoke(spoke).getUserSuppliedAmount(reserveId, onBehalfOf);
    if (amount == type(uint256).max) {
      amount = userSuppliedAmount;
    }

    ISpokeBase(spoke).withdraw(reserveId, amount, onBehalfOf);
    _unwrapNative(amount);
    _transferNative(onBehalfOf, amount);
  }

  function borrowNative(
    address spoke,
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external nonReentrant {
    _verifyParameters(spoke, reserveId, amount, onBehalfOf);

    ISpokeBase(spoke).borrow(reserveId, amount, onBehalfOf);
    _unwrapNative(amount);
    _transferNative(onBehalfOf, amount);
  }

  function repayNative(
    address spoke,
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external payable nonReentrant {
    _verifyParameters(spoke, reserveId, amount, onBehalfOf);
    if (msg.value != amount) revert NativeAmountMismatch();

    uint256 userDebtAmount = ISpoke(spoke).getUserTotalDebt(reserveId, onBehalfOf);
    uint256 leftovers;
    if (amount > userDebtAmount) {
      leftovers = amount - userDebtAmount;
      amount = userDebtAmount;
    }

    _wrapNative(amount);
    IERC20(address(WRAPPED_ASSET)).safeIncreaseAllowance(spoke, amount);
    ISpokeBase(spoke).repay(reserveId, amount, onBehalfOf);

    if (leftovers > 0) {
      _transferNative(msg.sender, leftovers);
    }
  }

  function _verifyParameters(
    address spoke,
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) internal {
    require(amount > 0, AmountNull());
    require(spoke != address(0) && onBehalfOf != address(0), AddressZero());
    require(_getReserveAsset(spoke, reserveId) == address(WRAPPED_ASSET), InvalidReserveId());
  }

  function _getReserveAsset(address spoke, uint256 reserveId) internal view returns (address) {
    return ISpoke(spoke).getReserve(reserveId).underlying;
  }

  function _wrapNative(uint256 amount) internal {
    WRAPPED_ASSET.deposit{value: amount}();
  }

  function _unwrapNative(uint256 amount) internal {
    WRAPPED_ASSET.withdraw(amount);
  }

  function _transferNative(address to, uint256 amount) internal {
    /// @solidity memory-safe-assembly
    assembly {
      // Transfer the ETH and check if it succeeded or not.
      if iszero(call(gas(), caller(), amount, codesize(), 0x00, codesize(), 0x00)) {
        mstore(0x00, 0xf4b3b1bc) // `NativeTransferFailed()`.
        revert(0x1c, 0x04)
      }
    }
  }

  function recoverToken(address token, address to) external restricted {
    IERC20(token).safeTransfer(to, IERC20(token).balanceOf(address(this)));
  }

  function recoverNative(address to, uint256 amount) external restricted {
    _transferNative(to, amount);
  }

  /**
   * @dev Only WRAPPED_ASSET contract is allowed to do native transfer here. Prevent other addresses to send native assets to this contract.
   */
  receive() external payable {
    require(msg.sender == address(WRAPPED_ASSET), ReceiveNotAllowed());
  }

  /**
   * @dev Revert fallback calls
   */
  fallback() external payable {
    revert FallbackForbidden();
  }
}
