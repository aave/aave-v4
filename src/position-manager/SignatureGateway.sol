// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {SignatureChecker} from 'src/dependencies/openzeppelin/SignatureChecker.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20Permit} from 'src/dependencies/openzeppelin/IERC20Permit.sol';
import {EIP712} from 'src/dependencies/solady/EIP712.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {NoncesKeyed} from 'src/utils/NoncesKeyed.sol';
import {Multicall} from 'src/utils/Multicall.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {EIP712Hash, EIP712Types} from 'src/position-manager/libraries/EIP712Hash.sol';
import {GatewayBase} from 'src/position-manager/GatewayBase.sol';
import {ISignatureGateway} from 'src/position-manager/interfaces/ISignatureGateway.sol';

/// @title SignatureGateway
/// @author Aave Labs
/// @notice Gateway to consume EIP-712 typed intents for spoke actions on behalf of a user.
/// @dev Contract must be an active & approved user position manager to execute spoke actions on user's behalf.
/// @dev Uses keyed-nonces where each key's namespace nonce is consumed sequentially. Intents bundled through
/// multicall can be executed independently in order of signed nonce & deadline; does not guarantee batch atomicity.
contract SignatureGateway is ISignatureGateway, GatewayBase, NoncesKeyed, Multicall, EIP712 {
  using SafeERC20 for IERC20;
  using EIP712Hash for *;

  /// @dev Constructor.
  /// @param initialOwner_ The address of the initial owner.
  constructor(address initialOwner_) GatewayBase(initialOwner_) {}

  /// @inheritdoc ISignatureGateway
  function supplyWithSig(
    EIP712Types.Supply calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    require(block.timestamp <= params.deadline, InvalidSignature());
    address spoke = params.spoke;
    uint256 reserveId = params.reserveId;
    address user = params.onBehalfOf;
    bytes32 hash = _hashTypedData(params.hash());
    require(SignatureChecker.isValidSignatureNow(user, hash, signature), InvalidSignature());
    _useCheckedNonce(user, params.nonce);

    (address underlying, address hub) = _getReserveData(spoke, reserveId);
    IERC20(underlying).safeTransferFrom(user, address(this), params.amount);
    IERC20(underlying).forceApprove(hub, params.amount);

    ISpoke(spoke).supply(reserveId, params.amount, user);
  }

  /// @inheritdoc ISignatureGateway
  function withdrawWithSig(
    EIP712Types.Withdraw calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    require(block.timestamp <= params.deadline, InvalidSignature());
    address spoke = params.spoke;
    uint256 reserveId = params.reserveId;
    address user = params.onBehalfOf;
    bytes32 hash = _hashTypedData(params.hash());
    require(SignatureChecker.isValidSignatureNow(user, hash, signature), InvalidSignature());
    _useCheckedNonce(user, params.nonce);

    (address underlying, ) = _getReserveData(spoke, reserveId);
    uint256 withdrawAmount = MathUtils.min(
      params.amount,
      ISpoke(spoke).getUserSuppliedAssets(reserveId, user)
    );

    ISpoke(spoke).withdraw(reserveId, withdrawAmount, user);
    IERC20(underlying).safeTransfer(user, withdrawAmount);
  }

  /// @inheritdoc ISignatureGateway
  function borrowWithSig(
    EIP712Types.Borrow calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    require(block.timestamp <= params.deadline, InvalidSignature());
    address spoke = params.spoke;
    uint256 reserveId = params.reserveId;
    address user = params.onBehalfOf;
    bytes32 hash = _hashTypedData(params.hash());
    require(SignatureChecker.isValidSignatureNow(user, hash, signature), InvalidSignature());
    _useCheckedNonce(user, params.nonce);

    (address underlying, ) = _getReserveData(spoke, reserveId);

    ISpoke(spoke).borrow(reserveId, params.amount, user);
    IERC20(underlying).safeTransfer(user, params.amount);
  }

  /// @inheritdoc ISignatureGateway
  function repayWithSig(
    EIP712Types.Repay calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    require(block.timestamp <= params.deadline, InvalidSignature());
    address spoke = params.spoke;
    uint256 reserveId = params.reserveId;
    address user = params.onBehalfOf;
    bytes32 hash = _hashTypedData(params.hash());
    require(SignatureChecker.isValidSignatureNow(user, hash, signature), InvalidSignature());
    _useCheckedNonce(user, params.nonce);

    (address underlying, address hub) = _getReserveData(spoke, reserveId);
    uint256 repayAmount = MathUtils.min(
      params.amount,
      ISpoke(spoke).getUserTotalDebt(reserveId, user)
    );

    IERC20(underlying).safeTransferFrom(user, address(this), repayAmount);
    IERC20(underlying).forceApprove(hub, repayAmount);

    ISpoke(spoke).repay(reserveId, repayAmount, user);
  }

  /// @inheritdoc ISignatureGateway
  function setUsingAsCollateralWithSig(
    EIP712Types.SetUsingAsCollateral calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    require(block.timestamp <= params.deadline, InvalidSignature());
    address user = params.onBehalfOf;
    bytes32 hash = _hashTypedData(params.hash());
    require(SignatureChecker.isValidSignatureNow(user, hash, signature), InvalidSignature());
    _useCheckedNonce(user, params.nonce);

    ISpoke(params.spoke).setUsingAsCollateral(params.reserveId, params.useAsCollateral, user);
  }

  /// @inheritdoc ISignatureGateway
  function updateUserRiskPremiumWithSig(
    EIP712Types.UpdateUserRiskPremium calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    require(block.timestamp <= params.deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(params.hash());
    require(SignatureChecker.isValidSignatureNow(params.user, hash, signature), InvalidSignature());
    _useCheckedNonce(params.user, params.nonce);

    ISpoke(params.spoke).updateUserRiskPremium(params.user);
  }

  /// @inheritdoc ISignatureGateway
  function updateUserDynamicConfigWithSig(
    EIP712Types.UpdateUserDynamicConfig calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    require(block.timestamp <= params.deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(params.hash());
    require(SignatureChecker.isValidSignatureNow(params.user, hash, signature), InvalidSignature());
    _useCheckedNonce(params.user, params.nonce);

    ISpoke(params.spoke).updateUserDynamicConfig(params.user);
  }

  /// @inheritdoc ISignatureGateway
  function setSelfAsUserPositionManagerWithSig(
    address spoke,
    EIP712Types.SetUserPositionManager calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(spoke) {
    try
      ISpoke(spoke).setUserPositionManagerWithSig(
        address(this),
        params.user,
        params.approve,
        params.nonce,
        params.deadline,
        signature
      )
    {} catch {}
  }

  /// @inheritdoc ISignatureGateway
  function permitReserve(
    address spoke,
    uint256 reserveId,
    address onBehalfOf,
    uint256 value,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external onlyRegisteredSpoke(spoke) {
    (address underlying, ) = _getReserveData(spoke, reserveId);
    try
      IERC20Permit(underlying).permit({
        owner: onBehalfOf,
        spender: address(this),
        value: value,
        deadline: deadline,
        v: permitV,
        r: permitR,
        s: permitS
      })
    {} catch {}
  }

  /// @inheritdoc ISignatureGateway
  function DOMAIN_SEPARATOR() external view returns (bytes32) {
    return _domainSeparator();
  }

  /// @inheritdoc ISignatureGateway
  function SUPPLY_TYPEHASH() external pure returns (bytes32) {
    return EIP712Hash.SUPPLY_TYPEHASH;
  }

  /// @inheritdoc ISignatureGateway
  function WITHDRAW_TYPEHASH() external pure returns (bytes32) {
    return EIP712Hash.WITHDRAW_TYPEHASH;
  }

  /// @inheritdoc ISignatureGateway
  function BORROW_TYPEHASH() external pure returns (bytes32) {
    return EIP712Hash.BORROW_TYPEHASH;
  }

  /// @inheritdoc ISignatureGateway
  function REPAY_TYPEHASH() external pure returns (bytes32) {
    return EIP712Hash.REPAY_TYPEHASH;
  }

  /// @inheritdoc ISignatureGateway
  function SET_USING_AS_COLLATERAL_TYPEHASH() external pure returns (bytes32) {
    return EIP712Hash.SET_USING_AS_COLLATERAL_TYPEHASH;
  }

  /// @inheritdoc ISignatureGateway
  function UPDATE_USER_RISK_PREMIUM_TYPEHASH() external pure returns (bytes32) {
    return EIP712Hash.UPDATE_USER_RISK_PREMIUM_TYPEHASH;
  }

  /// @inheritdoc ISignatureGateway
  function UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH() external pure returns (bytes32) {
    return EIP712Hash.UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH;
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('SignatureGateway', '1');
  }
}
