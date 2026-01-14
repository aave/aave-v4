// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20Permit} from 'src/dependencies/openzeppelin/IERC20Permit.sol';
import {EIP712Hash} from 'src/position-manager/libraries/EIP712Hash.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {GatewayBase} from 'src/position-manager/GatewayBase.sol';
import {IntentConsumer} from 'src/utils/IntentConsumer.sol';
import {Multicall} from 'src/utils/Multicall.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISignatureGateway} from 'src/position-manager/interfaces/ISignatureGateway.sol';

/// @title SignatureGateway
/// @author Aave Labs
/// @notice Gateway to consume EIP-712 typed intents for spoke actions on behalf of a user.
/// @dev Contract must be an active & approved user position manager to execute spoke actions on user's behalf.
/// @dev Uses keyed-nonces where each key's namespace nonce is consumed sequentially. Intents bundled through
/// multicall can be executed independently in order of signed nonce & deadline; does not guarantee batch atomicity.
contract SignatureGateway is ISignatureGateway, GatewayBase, IntentConsumer, Multicall {
  using SafeERC20 for IERC20;
  using EIP712Hash for *;

  /// @dev Constructor.
  /// @param initialOwner_ The address of the initial owner.
  constructor(address initialOwner_) GatewayBase(initialOwner_) {}

  /// @inheritdoc ISignatureGateway
  function supplyWithSig(
    Supply calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) returns (uint256, uint256) {
    address spoke = params.spoke;
    uint256 reserveId = params.reserveId;
    address user = params.onBehalfOf;
    _verifyAndConsumeIntent({
      signer: user,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });

    IERC20 underlying = IERC20(_getReserveUnderlying(spoke, reserveId));
    underlying.safeTransferFrom(user, address(this), params.amount);
    underlying.forceApprove(spoke, params.amount);

    return ISpoke(spoke).supply(reserveId, params.amount, user);
  }

  /// @inheritdoc ISignatureGateway
  function withdrawWithSig(
    Withdraw calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) returns (uint256, uint256) {
    require(block.timestamp <= params.deadline, InvalidSignature());
    address spoke = params.spoke;
    uint256 reserveId = params.reserveId;
    address user = params.onBehalfOf;
    _verifyAndConsumeIntent({
      signer: user,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });

    IERC20 underlying = IERC20(_getReserveUnderlying(spoke, reserveId));
    (uint256 withdrawnShares, uint256 withdrawnAmount) = ISpoke(spoke).withdraw(
      reserveId,
      params.amount,
      user
    );
    underlying.safeTransfer(user, withdrawnAmount);

    return (withdrawnShares, withdrawnAmount);
  }

  /// @inheritdoc ISignatureGateway
  function borrowWithSig(
    Borrow calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) returns (uint256, uint256) {
    require(block.timestamp <= params.deadline, InvalidSignature());
    address spoke = params.spoke;
    uint256 reserveId = params.reserveId;
    address user = params.onBehalfOf;
    _verifyAndConsumeIntent({
      signer: user,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });

    IERC20 underlying = IERC20(_getReserveUnderlying(spoke, reserveId));
    (uint256 borrowedShares, uint256 borrowedAmount) = ISpoke(spoke).borrow(
      reserveId,
      params.amount,
      user
    );
    underlying.safeTransfer(user, borrowedAmount);

    return (borrowedShares, borrowedAmount);
  }

  /// @inheritdoc ISignatureGateway
  function repayWithSig(
    Repay calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) returns (uint256, uint256) {
    require(block.timestamp <= params.deadline, InvalidSignature());
    address spoke = params.spoke;
    uint256 reserveId = params.reserveId;
    address user = params.onBehalfOf;
    _verifyAndConsumeIntent({
      signer: user,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });

    IERC20 underlying = IERC20(_getReserveUnderlying(spoke, reserveId));
    uint256 repayAmount = MathUtils.min(
      params.amount,
      ISpoke(spoke).getUserTotalDebt(reserveId, user)
    );

    underlying.safeTransferFrom(user, address(this), repayAmount);
    underlying.forceApprove(spoke, repayAmount);

    return ISpoke(spoke).repay(reserveId, repayAmount, user);
  }

  /// @inheritdoc ISignatureGateway
  function setUsingAsCollateralWithSig(
    SetUsingAsCollateral calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    address user = params.onBehalfOf;
    _verifyAndConsumeIntent({
      signer: user,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });

    ISpoke(params.spoke).setUsingAsCollateral(params.reserveId, params.useAsCollateral, user);
  }

  /// @inheritdoc ISignatureGateway
  function updateUserRiskPremiumWithSig(
    UpdateUserRiskPremium calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    _verifyAndConsumeIntent({
      signer: params.user,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });

    ISpoke(params.spoke).updateUserRiskPremium(params.user);
  }

  /// @inheritdoc ISignatureGateway
  function updateUserDynamicConfigWithSig(
    UpdateUserDynamicConfig calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    _verifyAndConsumeIntent({
      signer: params.user,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });

    ISpoke(params.spoke).updateUserDynamicConfig(params.user);
  }

  /// @inheritdoc ISignatureGateway
  function setSelfAsUserPositionManagerWithSig(
    address spoke,
    address user,
    bool approve,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external onlyRegisteredSpoke(spoke) {
    try
      ISpoke(spoke).setUserPositionManagerWithSig({
        positionManager: address(this),
        user: user,
        approve: approve,
        nonce: nonce,
        deadline: deadline,
        signature: signature
      })
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
    address underlying = _getReserveUnderlying(spoke, reserveId);
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
