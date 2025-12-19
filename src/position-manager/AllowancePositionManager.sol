// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {SignatureChecker} from 'src/dependencies/openzeppelin/SignatureChecker.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {SlotDerivation} from 'src/dependencies/openzeppelin/SlotDerivation.sol';
import {TransientSlot} from 'src/dependencies/openzeppelin/TransientSlot.sol';
import {EIP712} from 'src/dependencies/solady/EIP712.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {NoncesKeyed} from 'src/utils/NoncesKeyed.sol';
import {EIP712Hash, EIP712Types} from 'src/position-manager/libraries/EIP712Hash.sol';
import {PositionManagerBase} from 'src/position-manager/PositionManagerBase.sol';
import {ISpokeBase} from 'src/spoke/interfaces/ISpokeBase.sol';
import {IAllowancePositionManager} from 'src/position-manager/interfaces/IAllowancePositionManager.sol';

/// @title AllowancePositionManager
/// @author Aave Labs
/// @notice Position manager to handle withdraw permit, credit delegation and borrow actions on behalf of users.
contract AllowancePositionManager is
  IAllowancePositionManager,
  PositionManagerBase,
  NoncesKeyed,
  EIP712
{
  using SafeERC20 for IERC20;
  using MathUtils for uint256;
  using SlotDerivation for bytes32;
  using TransientSlot for *;
  using EIP712Hash for *;

  /// @notice Slot for the temporary withdraw allowances.
  /// @dev keccak256(abi.encode(uint256(keccak256("aave.transient.WITHDRAW_ALLOWANCES")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant _TEMPORARY_WITHDRAW_ALLOWANCES_SLOT =
    0x4b5553e643854b1bacc0d454fec49da235a0faac2caff4f059541ccf9f154700;

  /// @notice Slot for the temporary credit delegations.
  /// @dev keccak256(abi.encode(uint256(keccak256("aave.transient.CREDIT_DELEGATIONS")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant _TEMPORARY_CREDIT_DELEGATIONS_SLOT =
    0x5aa827cbd079fec1557555542f5232f82e413903ea6ea8e935f719e23b7c4a00;

  mapping(address spoke => mapping(uint256 reserveId => mapping(address owner => mapping(address spender => uint256 amount))))
    private _withdrawAllowances;

  mapping(address spoke => mapping(uint256 reserveId => mapping(address owner => mapping(address spender => uint256 amount))))
    private _creditDelegations;

  /// @dev Constructor.
  /// @param initialOwner_ The address of the initial owner.
  constructor(address initialOwner_) PositionManagerBase(initialOwner_) {}

  /// @inheritdoc IAllowancePositionManager
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

  /// @inheritdoc IAllowancePositionManager
  function approveWithdrawWithSig(
    EIP712Types.WithdrawPermit calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    require(block.timestamp <= params.deadline, InvalidSignature());
    bytes32 digest = _hashTypedData(params.hash());
    require(
      SignatureChecker.isValidSignatureNow(params.owner, digest, signature),
      InvalidSignature()
    );
    _useCheckedNonce(params.owner, params.nonce);

    _updateWithdrawAllowance({
      spoke: params.spoke,
      reserveId: params.reserveId,
      owner: params.owner,
      spender: params.spender,
      newAllowance: params.amount
    });
  }

  /// @inheritdoc IAllowancePositionManager
  function temporaryApproveWithdraw(
    address spoke,
    uint256 reserveId,
    address spender,
    uint256 amount
  ) external onlyRegisteredSpoke(spoke) {
    _temporaryWithdrawAllowancesSlot({
      spoke: spoke,
      reserveId: reserveId,
      owner: msg.sender,
      spender: spender
    }).tstore(amount);
  }

  /// @inheritdoc IAllowancePositionManager
  function delegateCredit(
    address spoke,
    uint256 reserveId,
    address spender,
    uint256 amount
  ) external onlyRegisteredSpoke(spoke) {
    _updateCreditDelegation({
      spoke: spoke,
      reserveId: reserveId,
      owner: msg.sender,
      spender: spender,
      newCreditDelegation: amount
    });
  }

  /// @inheritdoc IAllowancePositionManager
  function delegateCreditWithSig(
    EIP712Types.CreditDelegation calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    require(block.timestamp <= params.deadline, InvalidSignature());
    bytes32 digest = _hashTypedData(params.hash());
    require(
      SignatureChecker.isValidSignatureNow(params.owner, digest, signature),
      InvalidSignature()
    );
    _useCheckedNonce(params.owner, params.nonce);

    _updateCreditDelegation({
      spoke: params.spoke,
      reserveId: params.reserveId,
      owner: params.owner,
      spender: params.spender,
      newCreditDelegation: params.amount
    });
  }

  /// @inheritdoc IAllowancePositionManager
  function temporaryDelegateCredit(
    address spoke,
    uint256 reserveId,
    address spender,
    uint256 amount
  ) external onlyRegisteredSpoke(spoke) {
    _temporaryDelegateCreditsSlot({
      spoke: spoke,
      reserveId: reserveId,
      owner: msg.sender,
      spender: spender
    }).tstore(amount);
  }

  /// @inheritdoc IAllowancePositionManager
  function renounceWithdrawAllowance(
    address spoke,
    uint256 reserveId,
    address owner
  ) external onlyRegisteredSpoke(spoke) {
    if (_withdrawAllowances[spoke][reserveId][owner][msg.sender] == 0) {
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

  /// @inheritdoc IAllowancePositionManager
  function renounceCreditDelegation(
    address spoke,
    uint256 reserveId,
    address owner
  ) external onlyRegisteredSpoke(spoke) {
    if (_creditDelegations[spoke][reserveId][owner][msg.sender] == 0) {
      return;
    }
    _updateCreditDelegation({
      spoke: spoke,
      reserveId: reserveId,
      owner: owner,
      spender: msg.sender,
      newCreditDelegation: 0
    });
  }

  /// @inheritdoc IAllowancePositionManager
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

    (uint256 withdrawnShares, uint256 withdrawnAmount) = ISpokeBase(spoke).withdraw(
      reserveId,
      amount,
      onBehalfOf
    );
    asset.safeTransfer(msg.sender, withdrawnAmount);

    return (withdrawnShares, withdrawnAmount);
  }

  /// @inheritdoc IAllowancePositionManager
  function borrowOnBehalfOf(
    address spoke,
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyRegisteredSpoke(spoke) returns (uint256, uint256) {
    IERC20 asset = IERC20(_getReserveUnderlying(spoke, reserveId));
    _spendCreditDelegation({
      spoke: spoke,
      reserveId: reserveId,
      owner: onBehalfOf,
      spender: msg.sender,
      amount: amount
    });

    (uint256 borrowedShares, uint256 borrowedAmount) = ISpokeBase(spoke).borrow(
      reserveId,
      amount,
      onBehalfOf
    );
    asset.safeTransfer(msg.sender, borrowedAmount);

    return (borrowedShares, borrowedAmount);
  }

  /// @inheritdoc IAllowancePositionManager
  function withdrawAllowance(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender
  ) external view returns (uint256) {
    return _withdrawAllowances[spoke][reserveId][owner][spender];
  }

  /// @inheritdoc IAllowancePositionManager
  function creditDelegation(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender
  ) external view returns (uint256) {
    return _creditDelegations[spoke][reserveId][owner][spender];
  }

  /// @inheritdoc IAllowancePositionManager
  function DOMAIN_SEPARATOR() external view returns (bytes32) {
    return _domainSeparator();
  }

  /// @inheritdoc IAllowancePositionManager
  function WITHDRAW_PERMIT_TYPEHASH() external pure returns (bytes32) {
    return EIP712Hash.WITHDRAW_PERMIT_TYPEHASH;
  }

  /// @inheritdoc IAllowancePositionManager
  function CREDIT_DELEGATION_TYPEHASH() external pure returns (bytes32) {
    return EIP712Hash.CREDIT_DELEGATION_TYPEHASH;
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

  function _updateCreditDelegation(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender,
    uint256 newCreditDelegation
  ) internal {
    _creditDelegations[spoke][reserveId][owner][spender] = newCreditDelegation;
    emit CreditDelegation(spoke, reserveId, owner, spender, newCreditDelegation);
  }

  /// @dev Temporary allowance takes precedence over stored allowance, and does not cumulate.
  function _spendWithdrawAllowance(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender,
    uint256 amount
  ) internal {
    uint256 temporaryAllowance = _temporaryWithdrawAllowancesSlot({
      spoke: spoke,
      reserveId: reserveId,
      owner: owner,
      spender: spender
    }).tload();
    if (temporaryAllowance > 0) {
      require(
        temporaryAllowance >= amount,
        InsufficientTemporaryWithdrawAllowance(temporaryAllowance, amount)
      );
      if (temporaryAllowance != type(uint256).max) {
        _temporaryWithdrawAllowancesSlot({
          spoke: spoke,
          reserveId: reserveId,
          owner: owner,
          spender: spender
        }).tstore(temporaryAllowance.uncheckedSub(amount));
      }
    } else {
      uint256 allowance = _withdrawAllowances[spoke][reserveId][owner][spender];
      require(allowance >= amount, InsufficientWithdrawAllowance(allowance, amount));
      if (allowance != type(uint256).max) {
        _withdrawAllowances[spoke][reserveId][owner][spender] = allowance.uncheckedSub(amount);
      }
    }
  }

  /// @dev Temporary allowance takes precedence over stored allowance, and does not cumulate.
  function _spendCreditDelegation(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender,
    uint256 amount
  ) internal {
    uint256 temporaryAllowance = _temporaryDelegateCreditsSlot({
      spoke: spoke,
      reserveId: reserveId,
      owner: owner,
      spender: spender
    }).tload();
    if (temporaryAllowance > 0) {
      require(
        temporaryAllowance >= amount,
        InsufficientTemporaryCreditDelegation(temporaryAllowance, amount)
      );
      if (temporaryAllowance != type(uint256).max) {
        _temporaryDelegateCreditsSlot({
          spoke: spoke,
          reserveId: reserveId,
          owner: owner,
          spender: spender
        }).tstore(temporaryAllowance.uncheckedSub(amount));
      }
    } else {
      uint256 allowance = _creditDelegations[spoke][reserveId][owner][spender];
      require(allowance >= amount, InsufficientCreditDelegation(allowance, amount));
      if (allowance != type(uint256).max) {
        _creditDelegations[spoke][reserveId][owner][spender] = allowance.uncheckedSub(amount);
      }
    }
  }

  function _temporaryWithdrawAllowancesSlot(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender
  ) internal pure returns (TransientSlot.Uint256Slot) {
    return
      _TEMPORARY_WITHDRAW_ALLOWANCES_SLOT
        .deriveMapping(spoke)
        .deriveMapping(reserveId)
        .deriveMapping(owner)
        .deriveMapping(spender)
        .asUint256();
  }

  function _temporaryDelegateCreditsSlot(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender
  ) internal pure returns (TransientSlot.Uint256Slot) {
    return
      _TEMPORARY_CREDIT_DELEGATIONS_SLOT
        .deriveMapping(spoke)
        .deriveMapping(reserveId)
        .deriveMapping(owner)
        .deriveMapping(spender)
        .asUint256();
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('AllowancePositionManager', '1');
  }
}
