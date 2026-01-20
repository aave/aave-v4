// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20Permit} from 'src/dependencies/openzeppelin/IERC20Permit.sol';
import {EIP712Hash} from 'src/position-manager/libraries/EIP712Hash.sol';
import {BatchEIP712} from 'src/position-manager/libraries/BatchEIP712.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {GatewayBase} from 'src/position-manager/GatewayBase.sol';
import {IntentConsumer} from 'src/utils/IntentConsumer.sol';
import {Multicall} from 'src/utils/Multicall.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISignatureGateway} from 'src/position-manager/interfaces/ISignatureGateway.sol';
import {ISignatureTransfer} from 'lib/permit2/src/interfaces/ISignatureTransfer.sol';

/// @title SignatureGateway
/// @author Aave Labs
/// @notice Gateway to consume EIP-712 typed intents for spoke actions on behalf of a user.
/// @dev Contract must be an active & approved user position manager to execute spoke actions on user's behalf.
/// @dev Uses keyed-nonces where each key's namespace nonce is consumed sequentially. Intents bundled through
/// multicall can be executed independently in order of signed nonce & deadline; does not guarantee batch atomicity.
contract SignatureGateway is ISignatureGateway, GatewayBase, IntentConsumer, Multicall {
  using SafeERC20 for IERC20;
  using EIP712Hash for *;

  /// @inheritdoc ISignatureGateway
  string public constant SUPPLY_PERMIT2_WITNESS_TYPE_STRING =
    'SupplyAction witness)SupplyAction(address onBehalfOf,uint256 nonce,uint256 deadline,SupplyParams params)SupplyParams(address spoke,uint256 reserveId,uint256 amount)TokenPermissions(address token,uint256 amount)';

  /// @inheritdoc ISignatureGateway
  string public constant REPAY_PERMIT2_WITNESS_TYPE_STRING =
    'RepayAction witness)RepayAction(address onBehalfOf,uint256 nonce,uint256 deadline,RepayParams params)RepayParams(address spoke,uint256 reserveId,uint256 amount)TokenPermissions(address token,uint256 amount)';

  /// @inheritdoc ISignatureGateway
  bytes32 public constant SUPPLY_TYPEHASH = EIP712Hash.SUPPLY_TYPEHASH;

  /// @inheritdoc ISignatureGateway
  bytes32 public constant WITHDRAW_TYPEHASH = EIP712Hash.WITHDRAW_TYPEHASH;

  /// @inheritdoc ISignatureGateway
  bytes32 public constant BORROW_TYPEHASH = EIP712Hash.BORROW_TYPEHASH;

  /// @inheritdoc ISignatureGateway
  bytes32 public constant REPAY_TYPEHASH = EIP712Hash.REPAY_TYPEHASH;

  /// @inheritdoc ISignatureGateway
  bytes32 public constant SET_USING_AS_COLLATERAL_TYPEHASH =
    EIP712Hash.SET_USING_AS_COLLATERAL_TYPEHASH;

  /// @inheritdoc ISignatureGateway
  bytes32 public constant UPDATE_USER_RISK_PREMIUM_TYPEHASH =
    EIP712Hash.UPDATE_USER_RISK_PREMIUM_TYPEHASH;

  /// @inheritdoc ISignatureGateway
  bytes32 public constant UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH =
    EIP712Hash.UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH;

  /// @inheritdoc ISignatureGateway
  address public immutable PERMIT2;

  /// @dev Constructor.
  /// @param initialOwner_ The address of the initial owner.
  /// @param permit2_ The address of the Permit2 contract.
  constructor(address initialOwner_, address permit2_) GatewayBase(initialOwner_) {
    require(permit2_ != address(0), InvalidAddress());
    PERMIT2 = permit2_;
  }

  /// @inheritdoc ISignatureGateway
  function supplyWithSig(
    SupplyAction calldata action,
    bytes calldata signature
  ) external onlyRegisteredSpoke(action.params.spoke) returns (uint256, uint256) {
    address user = action.onBehalfOf;
    _verifyAndConsumeIntent({
      signer: user,
      intentHash: action.hash(),
      nonce: action.nonce,
      deadline: action.deadline,
      signature: signature
    });

    return _executeSupply(action.params, user);
  }

  /// @inheritdoc ISignatureGateway
  function withdrawWithSig(
    WithdrawAction calldata action,
    bytes calldata signature
  ) external onlyRegisteredSpoke(action.params.spoke) returns (uint256, uint256) {
    address user = action.onBehalfOf;
    _verifyAndConsumeIntent({
      signer: user,
      intentHash: action.hash(),
      nonce: action.nonce,
      deadline: action.deadline,
      signature: signature
    });

    return _executeWithdraw(action.params, user);
  }

  /// @inheritdoc ISignatureGateway
  function borrowWithSig(
    BorrowAction calldata action,
    bytes calldata signature
  ) external onlyRegisteredSpoke(action.params.spoke) returns (uint256, uint256) {
    address user = action.onBehalfOf;
    _verifyAndConsumeIntent({
      signer: user,
      intentHash: action.hash(),
      nonce: action.nonce,
      deadline: action.deadline,
      signature: signature
    });

    return _executeBorrow(action.params, user);
  }

  /// @inheritdoc ISignatureGateway
  function repayWithSig(
    RepayAction calldata action,
    bytes calldata signature
  ) external onlyRegisteredSpoke(action.params.spoke) returns (uint256, uint256) {
    address user = action.onBehalfOf;
    _verifyAndConsumeIntent({
      signer: user,
      intentHash: action.hash(),
      nonce: action.nonce,
      deadline: action.deadline,
      signature: signature
    });

    return _executeRepay(action.params, user);
  }

  /// @inheritdoc ISignatureGateway
  function setUsingAsCollateralWithSig(
    SetUsingAsCollateralAction calldata action,
    bytes calldata signature
  ) external onlyRegisteredSpoke(action.params.spoke) {
    address user = action.onBehalfOf;
    _verifyAndConsumeIntent({
      signer: user,
      intentHash: action.hash(),
      nonce: action.nonce,
      deadline: action.deadline,
      signature: signature
    });

    _executeSetUsingAsCollateral(action.params, user);
  }

  /// @inheritdoc ISignatureGateway
  function updateUserRiskPremiumWithSig(
    UpdateUserRiskPremiumAction calldata action,
    bytes calldata signature
  ) external onlyRegisteredSpoke(action.params.spoke) {
    _verifyAndConsumeIntent({
      signer: action.user,
      intentHash: action.hash(),
      nonce: action.nonce,
      deadline: action.deadline,
      signature: signature
    });

    _executeUpdateUserRiskPremium(action.params, action.user);
  }

  /// @inheritdoc ISignatureGateway
  function updateUserDynamicConfigWithSig(
    UpdateUserDynamicConfigAction calldata action,
    bytes calldata signature
  ) external onlyRegisteredSpoke(action.params.spoke) {
    _verifyAndConsumeIntent({
      signer: action.user,
      intentHash: action.hash(),
      nonce: action.nonce,
      deadline: action.deadline,
      signature: signature
    });

    _executeUpdateUserDynamicConfig(action.params, action.user);
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
    ISpoke.PositionManagerUpdate[] memory updates = new ISpoke.PositionManagerUpdate[](1);
    updates[0] = ISpoke.PositionManagerUpdate({positionManager: address(this), approve: approve});
    try
      ISpoke(spoke).setUserPositionManagersWithSig(
        ISpoke.SetUserPositionManagers({
          user: user,
          updates: updates,
          nonce: nonce,
          deadline: deadline
        }),
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
  function supplyWithPermit2(
    ISignatureTransfer.PermitTransferFrom calldata permit,
    SupplyAction calldata action,
    bytes calldata signature
  ) external onlyRegisteredSpoke(action.params.spoke) returns (uint256, uint256) {
    require(block.timestamp <= action.deadline, InvalidSignature());
    _useCheckedNonce(action.onBehalfOf, action.nonce);

    ISignatureTransfer(PERMIT2).permitWitnessTransferFrom(
      permit,
      ISignatureTransfer.SignatureTransferDetails(address(this), action.params.amount),
      action.onBehalfOf,
      action.hash(),
      SUPPLY_PERMIT2_WITNESS_TYPE_STRING,
      signature
    );

    address underlying = _getReserveUnderlying(action.params.spoke, action.params.reserveId);
    IERC20(underlying).forceApprove(action.params.spoke, action.params.amount);

    return
      ISpoke(action.params.spoke).supply(
        action.params.reserveId,
        action.params.amount,
        action.onBehalfOf
      );
  }

  /// @inheritdoc ISignatureGateway
  function repayWithPermit2(
    ISignatureTransfer.PermitTransferFrom calldata permit,
    RepayAction calldata action,
    bytes calldata signature
  ) external onlyRegisteredSpoke(action.params.spoke) returns (uint256, uint256) {
    require(block.timestamp <= action.deadline, InvalidSignature());
    _useCheckedNonce(action.onBehalfOf, action.nonce);

    uint256 repayAmount = MathUtils.min(
      action.params.amount,
      ISpoke(action.params.spoke).getUserTotalDebt(action.params.reserveId, action.onBehalfOf)
    );

    ISignatureTransfer(PERMIT2).permitWitnessTransferFrom(
      permit,
      ISignatureTransfer.SignatureTransferDetails(address(this), repayAmount),
      action.onBehalfOf,
      action.hash(),
      REPAY_PERMIT2_WITNESS_TYPE_STRING,
      signature
    );

    address underlying = _getReserveUnderlying(action.params.spoke, action.params.reserveId);
    IERC20(underlying).forceApprove(action.params.spoke, repayAmount);

    return
      ISpoke(action.params.spoke).repay(action.params.reserveId, repayAmount, action.onBehalfOf);
  }

  /// @inheritdoc ISignatureGateway
  function executeBatchWithSig(
    uint8[] memory actionTypes,
    bytes[] memory actionData,
    address onBehalfOf,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external {
    uint256 len = actionTypes.length;
    require(len == actionData.length, LengthMismatch());
    require(len > 0 && len <= 10, InvalidBatchSize());

    bytes32 structHash = BatchEIP712.hashBatch(
      actionTypes,
      actionData,
      onBehalfOf,
      nonce,
      deadline
    );
    _verifyAndConsumeIntent({
      signer: onBehalfOf,
      intentHash: structHash,
      nonce: nonce,
      deadline: deadline,
      signature: signature
    });

    for (uint256 i = 0; i < len; i++) {
      _executeBatchAction(actionTypes[i], actionData[i], onBehalfOf);
    }
  }

  function _executeBatchAction(
    uint8 actionType,
    bytes memory actionData,
    address onBehalfOf
  ) internal {
    if (actionType == uint8(ActionType.Supply)) {
      SupplyParams memory params = abi.decode(actionData, (SupplyParams));
      _isSpokeValid(params.spoke);
      _executeSupply(params, onBehalfOf);
    } else if (actionType == uint8(ActionType.Withdraw)) {
      WithdrawParams memory params = abi.decode(actionData, (WithdrawParams));
      _isSpokeValid(params.spoke);
      _executeWithdraw(params, onBehalfOf);
    } else if (actionType == uint8(ActionType.Borrow)) {
      BorrowParams memory params = abi.decode(actionData, (BorrowParams));
      _isSpokeValid(params.spoke);
      _executeBorrow(params, onBehalfOf);
    } else if (actionType == uint8(ActionType.Repay)) {
      RepayParams memory params = abi.decode(actionData, (RepayParams));
      _isSpokeValid(params.spoke);
      _executeRepay(params, onBehalfOf);
    } else if (actionType == uint8(ActionType.SetUsingAsCollateral)) {
      SetUsingAsCollateralParams memory params = abi.decode(
        actionData,
        (SetUsingAsCollateralParams)
      );
      _isSpokeValid(params.spoke);
      _executeSetUsingAsCollateral(params, onBehalfOf);
    } else if (actionType == uint8(ActionType.UpdateUserRiskPremium)) {
      UpdateUserRiskPremiumParams memory params = abi.decode(
        actionData,
        (UpdateUserRiskPremiumParams)
      );
      _isSpokeValid(params.spoke);
      _executeUpdateUserRiskPremium(params, onBehalfOf);
    } else if (actionType == uint8(ActionType.UpdateUserDynamicConfig)) {
      UpdateUserDynamicConfigParams memory params = abi.decode(
        actionData,
        (UpdateUserDynamicConfigParams)
      );
      _isSpokeValid(params.spoke);
      _executeUpdateUserDynamicConfig(params, onBehalfOf);
    } else {
      revert InvalidActionType();
    }
  }

  function _executeSupply(
    SupplyParams memory params,
    address onBehalfOf
  ) internal returns (uint256, uint256) {
    IERC20 underlying = IERC20(_getReserveUnderlying(params.spoke, params.reserveId));
    underlying.safeTransferFrom(onBehalfOf, address(this), params.amount);
    underlying.forceApprove(params.spoke, params.amount);

    return ISpoke(params.spoke).supply(params.reserveId, params.amount, onBehalfOf);
  }

  function _executeWithdraw(
    WithdrawParams memory params,
    address onBehalfOf
  ) internal returns (uint256, uint256) {
    IERC20 underlying = IERC20(_getReserveUnderlying(params.spoke, params.reserveId));
    (uint256 withdrawnShares, uint256 withdrawnAmount) = ISpoke(params.spoke).withdraw(
      params.reserveId,
      params.amount,
      onBehalfOf
    );
    underlying.safeTransfer(onBehalfOf, withdrawnAmount);

    return (withdrawnShares, withdrawnAmount);
  }

  function _executeBorrow(
    BorrowParams memory params,
    address onBehalfOf
  ) internal returns (uint256, uint256) {
    IERC20 underlying = IERC20(_getReserveUnderlying(params.spoke, params.reserveId));
    (uint256 borrowedShares, uint256 borrowedAmount) = ISpoke(params.spoke).borrow(
      params.reserveId,
      params.amount,
      onBehalfOf
    );
    underlying.safeTransfer(onBehalfOf, borrowedAmount);

    return (borrowedShares, borrowedAmount);
  }

  function _executeRepay(
    RepayParams memory params,
    address onBehalfOf
  ) internal returns (uint256, uint256) {
    IERC20 underlying = IERC20(_getReserveUnderlying(params.spoke, params.reserveId));
    uint256 repayAmount = MathUtils.min(
      params.amount,
      ISpoke(params.spoke).getUserTotalDebt(params.reserveId, onBehalfOf)
    );

    underlying.safeTransferFrom(onBehalfOf, address(this), repayAmount);
    underlying.forceApprove(params.spoke, repayAmount);

    return ISpoke(params.spoke).repay(params.reserveId, repayAmount, onBehalfOf);
  }

  function _executeSetUsingAsCollateral(
    SetUsingAsCollateralParams memory params,
    address onBehalfOf
  ) internal {
    ISpoke(params.spoke).setUsingAsCollateral(params.reserveId, params.useAsCollateral, onBehalfOf);
  }

  function _executeUpdateUserRiskPremium(
    UpdateUserRiskPremiumParams memory params,
    address onBehalfOf
  ) internal {
    ISpoke(params.spoke).updateUserRiskPremium(onBehalfOf);
  }

  function _executeUpdateUserDynamicConfig(
    UpdateUserDynamicConfigParams memory params,
    address onBehalfOf
  ) internal {
    ISpoke(params.spoke).updateUserDynamicConfig(onBehalfOf);
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('SignatureGateway', '1');
  }
}
