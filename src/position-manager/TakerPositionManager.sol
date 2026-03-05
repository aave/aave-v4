// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {EIP712Hash} from 'src/position-manager/libraries/EIP712Hash.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeBase} from 'src/spoke/interfaces/ISpokeBase.sol';
import {ITakerPositionManager} from 'src/position-manager/interfaces/ITakerPositionManager.sol';
import {PositionManagerBase} from 'src/position-manager/PositionManagerBase.sol';

/// @title TakerPositionManager
/// @author Aave Labs
/// @notice Position manager to handle withdraw permit and borrow permit actions on behalf of users.
contract TakerPositionManager is ITakerPositionManager, PositionManagerBase {
  using SafeERC20 for IERC20;
  using EIP712Hash for *;

  /// @inheritdoc ITakerPositionManager
  bytes32 public constant WITHDRAW_PERMIT_TYPEHASH = EIP712Hash.WITHDRAW_PERMIT_TYPEHASH;

  /// @inheritdoc ITakerPositionManager
  bytes32 public constant BORROW_PERMIT_TYPEHASH = EIP712Hash.BORROW_PERMIT_TYPEHASH;

  /// @dev Map of withdraw allowances based on the spoke, reserveId, owner and spender.
  mapping(address spoke => mapping(uint256 reserveId => mapping(address owner => mapping(address spender => uint256 amount))))
    private _withdrawAllowances;

  /// @dev Map of borrow allowances based on the spoke, reserveId, owner and spender.
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
      newAllowance: amount
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
      newAllowance: params.amount
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
      newAllowance: 0
    });
  }

  /// @inheritdoc ITakerPositionManager
  function withdrawOnBehalfOf(
    address spoke,
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyRegisteredSpoke(spoke) returns (uint256, uint256) {
    ISpoke.Reserve memory reserve = ISpoke(spoke).getReserve(reserveId);
    uint256 currentAllowance = _checkWithdrawAllowance({
      spoke: spoke,
      reserveId: reserveId,
      owner: onBehalfOf,
      spender: msg.sender,
      amount: amount
    });

    uint256 sharesBefore;
    if (currentAllowance != type(uint256).max) {
      sharesBefore = ISpokeBase(spoke).getUserSuppliedShares(reserveId, onBehalfOf);
    }

    (uint256 withdrawnShares, uint256 withdrawnAmount) = ISpokeBase(spoke).withdraw({
      reserveId: reserveId,
      amount: amount,
      onBehalfOf: onBehalfOf
    });

    // Simply decreasing the allowance by the input `amount` is not ideal for shares-based
    // positions. Due to rounding in supply-side SharesMath, the actual decrease in the user's
    // position value can differ slightly from the input `amount`. To handle this, the allowance
    // consumption is based on the before/after delta of `previewAddByShares`, and capped at
    // `currentAllowance` to prevent underflow from rounding.
    if (currentAllowance != type(uint256).max) {
      uint256 sharesAfter = ISpokeBase(spoke).getUserSuppliedShares(reserveId, onBehalfOf);
      uint256 newAllowance = _deductAllowance({
        currentAllowance: currentAllowance,
        correctedAmount: reserve.hub.previewAddByShares(reserve.assetId, sharesBefore) -
          reserve.hub.previewAddByShares(reserve.assetId, sharesAfter)
      });
      _updateWithdrawAllowance({
        spoke: spoke,
        reserveId: reserveId,
        owner: onBehalfOf,
        spender: msg.sender,
        newAllowance: newAllowance
      });
    }
    IERC20(reserve.underlying).safeTransfer(msg.sender, withdrawnAmount);

    return (withdrawnShares, withdrawnAmount);
  }

  /// @inheritdoc ITakerPositionManager
  function borrowOnBehalfOf(
    address spoke,
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyRegisteredSpoke(spoke) returns (uint256, uint256) {
    ISpoke.Reserve memory reserve = ISpoke(spoke).getReserve(reserveId);
    uint256 currentAllowance = _checkBorrowAllowance({
      spoke: spoke,
      reserveId: reserveId,
      owner: onBehalfOf,
      spender: msg.sender,
      amount: amount
    });

    uint256 drawnSharesBefore;
    if (currentAllowance != type(uint256).max) {
      drawnSharesBefore = ISpoke(spoke).getUserPosition(reserveId, onBehalfOf).drawnShares;
    }

    (uint256 borrowedShares, uint256 borrowedAmount) = ISpokeBase(spoke).borrow({
      reserveId: reserveId,
      amount: amount,
      onBehalfOf: onBehalfOf
    });

    // Simply decreasing the allowance by the input `amount` is not ideal for shares-based
    // debt. Due to rounding, the actual increase in the user's debt can differ slightly from
    // the input `amount`. To handle this, the allowance consumption is based on the before/after
    // delta of `previewRestoreByShares`, and capped at `currentAllowance` to prevent underflow
    // from rounding.
    if (currentAllowance != type(uint256).max) {
      uint256 drawnSharesAfter = ISpoke(spoke).getUserPosition(reserveId, onBehalfOf).drawnShares;
      uint256 newAllowance = _deductAllowance({
        currentAllowance: currentAllowance,
        correctedAmount: reserve.hub.previewRestoreByShares(reserve.assetId, drawnSharesAfter) -
          reserve.hub.previewRestoreByShares(reserve.assetId, drawnSharesBefore)
      });
      _updateBorrowAllowance({
        spoke: spoke,
        reserveId: reserveId,
        owner: onBehalfOf,
        spender: msg.sender,
        newAllowance: newAllowance
      });
    }
    IERC20(reserve.underlying).safeTransfer(msg.sender, borrowedAmount);

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
    uint256 newAllowance
  ) internal {
    _borrowAllowances[spoke][reserveId][owner][spender] = newAllowance;
    emit BorrowApproval(spoke, reserveId, owner, spender, newAllowance);
  }

  function _checkWithdrawAllowance(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender,
    uint256 amount
  ) internal view returns (uint256 currentAllowance) {
    currentAllowance = _getWithdrawAllowance({
      spoke: spoke,
      reserveId: reserveId,
      owner: owner,
      spender: spender
    });
    require(currentAllowance >= amount, InsufficientWithdrawAllowance(currentAllowance, amount));
  }

  function _checkBorrowAllowance(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender,
    uint256 amount
  ) internal view returns (uint256 currentAllowance) {
    currentAllowance = _getBorrowAllowance({
      spoke: spoke,
      reserveId: reserveId,
      owner: owner,
      spender: spender
    });
    require(currentAllowance >= amount, InsufficientBorrowAllowance(currentAllowance, amount));
  }

  /// @dev Deducts the corrected amount from the given allowance.
  /// `correctedAmount` may exceed `currentAllowance` by a rounding delta;
  /// consumption is capped at `currentAllowance` to prevent underflow.
  function _deductAllowance(
    uint256 currentAllowance,
    uint256 correctedAmount
  ) internal pure returns (uint256 newAllowance) {
    if (currentAllowance == type(uint256).max) return type(uint256).max;
    uint256 consumption = currentAllowance >= correctedAmount ? correctedAmount : currentAllowance;
    return currentAllowance - consumption;
  }

  function _multicallEnabled() internal pure override returns (bool) {
    return true;
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('TakerPositionManager', '1');
  }
}
