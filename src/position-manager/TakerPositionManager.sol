// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {EIP712Hash} from 'src/position-manager/libraries/EIP712Hash.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ITakerPositionManager} from 'src/position-manager/interfaces/ITakerPositionManager.sol';
import {PositionManagerBase} from 'src/position-manager/PositionManagerBase.sol';

/// @title TakerPositionManager
/// @author Aave Labs
/// @notice Position manager to handle withdraw permit and borrow permit actions on behalf of users.
contract TakerPositionManager is ITakerPositionManager, PositionManagerBase {
  using SafeERC20 for IERC20;
  using MathUtils for uint256;
  using EIP712Hash for *;

  /// @inheritdoc ITakerPositionManager
  bytes32 public constant WITHDRAW_PERMIT_TYPEHASH = EIP712Hash.WITHDRAW_PERMIT_TYPEHASH;

  /// @inheritdoc ITakerPositionManager
  bytes32 public constant BORROW_PERMIT_TYPEHASH = EIP712Hash.BORROW_PERMIT_TYPEHASH;

  /// @dev Map of withdraw allowances based on the Spoke, reserveId, owner and spender.
  mapping(address spoke => mapping(uint256 reserveId => mapping(address owner => mapping(address spender => uint256 amount))))
    private _withdrawAllowances;

  /// @dev Map of borrow allowances based on the Spoke, reserveId, owner and spender.
  mapping(address spoke => mapping(uint256 reserveId => mapping(address owner => mapping(address spender => uint256 amount))))
    private _borrowAllowances;

  /// @dev Constructor.
  /// @param initialOwner_ The address of the initial owner.
  constructor(address initialOwner_) PositionManagerBase(initialOwner_) {}

  /// @inheritdoc ITakerPositionManager
  function approveWithdraw(
    address spoke,
    uint256 reserveId,
    address spender,
    uint256 amount
  ) external onlyRegisteredSpoke(spoke) {
    _updateWithdrawAllowance({
      spoke: spoke,
      reserveId: reserveId,
      owner: msg.sender,
      spender: spender,
      newAllowance: amount
    });
  }

  /// @inheritdoc ITakerPositionManager
  function approveWithdrawWithSig(
    WithdrawPermit calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    _verifyAndConsumeIntent({
      signer: params.owner,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });

    _updateWithdrawAllowance({
      spoke: params.spoke,
      reserveId: params.reserveId,
      owner: params.owner,
      spender: params.spender,
      newAllowance: params.amount
    });
  }

  /// @inheritdoc ITakerPositionManager
  function approveBorrow(
    address spoke,
    uint256 reserveId,
    address spender,
    uint256 amount
  ) external onlyRegisteredSpoke(spoke) {
    _updateBorrowAllowance({
      spoke: spoke,
      reserveId: reserveId,
      owner: msg.sender,
      spender: spender,
      newCreditDelegation: amount
    });
  }

  /// @inheritdoc ITakerPositionManager
  function approveBorrowWithSig(
    BorrowPermit calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    _verifyAndConsumeIntent({
      signer: params.owner,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });

    _updateBorrowAllowance({
      spoke: params.spoke,
      reserveId: params.reserveId,
      owner: params.owner,
      spender: params.spender,
      newCreditDelegation: params.amount
    });
  }

  /// @inheritdoc ITakerPositionManager
  function renounceWithdrawAllowance(
    address spoke,
    uint256 reserveId,
    address owner
  ) external onlyRegisteredSpoke(spoke) {
    if (
      _getWithdrawAllowance({
        spoke: spoke,
        reserveId: reserveId,
        owner: owner,
        spender: msg.sender
      }) == 0
    ) {
      return;
    }
    _updateWithdrawAllowance({
      spoke: spoke,
      reserveId: reserveId,
      owner: owner,
      spender: msg.sender,
      newAllowance: 0
    });
  }

  /// @inheritdoc ITakerPositionManager
  function renounceBorrowAllowance(
    address spoke,
    uint256 reserveId,
    address owner
  ) external onlyRegisteredSpoke(spoke) {
    if (
      _getBorrowAllowance({
        spoke: spoke,
        reserveId: reserveId,
        owner: owner,
        spender: msg.sender
      }) == 0
    ) {
      return;
    }
    _updateBorrowAllowance({
      spoke: spoke,
      reserveId: reserveId,
      owner: owner,
      spender: msg.sender,
      newCreditDelegation: 0
    });
  }

  /// @inheritdoc ITakerPositionManager
  function withdrawOnBehalfOf(
    address spoke,
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyRegisteredSpoke(spoke) returns (uint256, uint256) {
    IERC20 asset = IERC20(_getReserveUnderlying(spoke, reserveId));
    _spendWithdrawAllowance({
      spoke: spoke,
      reserveId: reserveId,
      owner: onBehalfOf,
      spender: msg.sender,
      amount: amount
    });

    (uint256 withdrawnShares, uint256 withdrawnAmount) = ISpoke(spoke).withdraw(
      reserveId,
      amount,
      onBehalfOf
    );
    asset.safeTransfer(msg.sender, withdrawnAmount);

    return (withdrawnShares, withdrawnAmount);
  }

  /// @inheritdoc ITakerPositionManager
  function borrowOnBehalfOf(
    address spoke,
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyRegisteredSpoke(spoke) returns (uint256, uint256) {
    IERC20 asset = IERC20(_getReserveUnderlying(spoke, reserveId));
    _spendBorrowAllowance({
      spoke: spoke,
      reserveId: reserveId,
      owner: onBehalfOf,
      spender: msg.sender,
      amount: amount
    });

    (uint256 borrowedShares, uint256 borrowedAmount) = ISpoke(spoke).borrow(
      reserveId,
      amount,
      onBehalfOf
    );
    asset.safeTransfer(msg.sender, borrowedAmount);

    return (borrowedShares, borrowedAmount);
  }

  /// @inheritdoc ITakerPositionManager
  function withdrawAllowance(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender
  ) external view returns (uint256) {
    return
      _getWithdrawAllowance({spoke: spoke, reserveId: reserveId, owner: owner, spender: spender});
  }

  /// @inheritdoc ITakerPositionManager
  function borrowAllowance(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender
  ) external view returns (uint256) {
    return
      _getBorrowAllowance({spoke: spoke, reserveId: reserveId, owner: owner, spender: spender});
  }

  function _getWithdrawAllowance(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender
  ) internal view returns (uint256) {
    return _withdrawAllowances[spoke][reserveId][owner][spender];
  }

  function _getBorrowAllowance(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender
  ) internal view returns (uint256) {
    return _borrowAllowances[spoke][reserveId][owner][spender];
  }

  function _updateWithdrawAllowance(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender,
    uint256 newAllowance
  ) internal {
    _withdrawAllowances[spoke][reserveId][owner][spender] = newAllowance;
    emit WithdrawApproval(spoke, reserveId, owner, spender, newAllowance);
  }

  function _updateBorrowAllowance(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender,
    uint256 newCreditDelegation
  ) internal {
    _borrowAllowances[spoke][reserveId][owner][spender] = newCreditDelegation;
    emit BorrowApproval(spoke, reserveId, owner, spender, newCreditDelegation);
  }

  function _spendWithdrawAllowance(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender,
    uint256 amount
  ) internal {
    uint256 currentAllowance = _getWithdrawAllowance({
      spoke: spoke,
      reserveId: reserveId,
      owner: owner,
      spender: spender
    });
    require(currentAllowance >= amount, InsufficientWithdrawAllowance(currentAllowance, amount));
    if (currentAllowance != type(uint256).max) {
      _updateWithdrawAllowance({
        spoke: spoke,
        reserveId: reserveId,
        owner: owner,
        spender: spender,
        newAllowance: currentAllowance.uncheckedSub(amount)
      });
    }
  }

  function _spendBorrowAllowance(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender,
    uint256 amount
  ) internal {
    uint256 currentAllowance = _getBorrowAllowance({
      spoke: spoke,
      reserveId: reserveId,
      owner: owner,
      spender: spender
    });
    require(currentAllowance >= amount, InsufficientBorrowAllowance(currentAllowance, amount));
    if (currentAllowance != type(uint256).max) {
      _updateBorrowAllowance({
        spoke: spoke,
        reserveId: reserveId,
        owner: owner,
        spender: spender,
        newCreditDelegation: currentAllowance.uncheckedSub(amount)
      });
    }
  }

  function _multicallEnabled() internal pure override returns (bool) {
    return true;
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('TakerPositionManager', '1');
  }
}
