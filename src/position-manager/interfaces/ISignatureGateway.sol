// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IMulticall} from 'src/interfaces/IMulticall.sol';
import {IIntentConsumer} from 'src/interfaces/IIntentConsumer.sol';
import {IGatewayBase} from 'src/position-manager/interfaces/IGatewayBase.sol';
import {ISignatureTransfer} from 'lib/permit2/src/interfaces/ISignatureTransfer.sol';

/// @title ISignatureGateway
/// @author Aave Labs
/// @notice Minimal interface for protocol actions involving signed intents.
interface ISignatureGateway is IGatewayBase, IIntentConsumer, IMulticall {
  /// @notice Action type enumeration for batch operations.
  enum ActionType {
    Supply, // 0
    Withdraw, // 1
    Borrow, // 2
    Repay, // 3
    SetUsingAsCollateral, // 4
    UpdateUserRiskPremium, // 5
    UpdateUserDynamicConfig // 6
  }

  /// @notice Parameters for supplying assets.
  /// @param spoke The address of the registered spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount of assets to supply.
  struct SupplyParams {
    address spoke;
    uint256 reserveId;
    uint256 amount;
  }

  /// @notice Parameters for withdrawing assets.
  /// @param spoke The address of the registered spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount of assets to withdraw.
  struct WithdrawParams {
    address spoke;
    uint256 reserveId;
    uint256 amount;
  }

  /// @notice Parameters for borrowing assets.
  /// @param spoke The address of the registered spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount of assets to borrow.
  struct BorrowParams {
    address spoke;
    uint256 reserveId;
    uint256 amount;
  }

  /// @notice Parameters for repaying assets.
  /// @param spoke The address of the registered spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount of assets to repay.
  struct RepayParams {
    address spoke;
    uint256 reserveId;
    uint256 amount;
  }

  /// @notice Parameters for setting collateral usage.
  /// @param spoke The address of the registered spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param useAsCollateral True to enable the reserve as collateral, false to disable it.
  struct SetUsingAsCollateralParams {
    address spoke;
    uint256 reserveId;
    bool useAsCollateral;
  }

  /// @notice Parameters for updating user risk premium.
  /// @param spoke The address of the registered spoke.
  struct UpdateUserRiskPremiumParams {
    address spoke;
  }

  /// @notice Parameters for updating user dynamic config.
  /// @param spoke The address of the registered spoke.
  struct UpdateUserDynamicConfigParams {
    address spoke;
  }

  /// @notice Intent action to supply assets to a reserve.
  /// @param onBehalfOf The address of the user on whose behalf the supply is performed.
  /// @param nonce The key-prefixed nonce for the signature.
  /// @param deadline The deadline for the intent.
  /// @param params The supply parameters.
  struct SupplyAction {
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
    SupplyParams params;
  }

  /// @notice Intent action to withdraw assets from a reserve.
  /// @param onBehalfOf The address of the user on whose behalf the withdraw is performed.
  /// @param nonce The key-prefixed nonce for the signature.
  /// @param deadline The deadline for the intent.
  /// @param params The withdraw parameters.
  struct WithdrawAction {
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
    WithdrawParams params;
  }

  /// @notice Intent action to borrow assets from a reserve.
  /// @param onBehalfOf The address of the user on whose behalf the borrow is performed.
  /// @param nonce The key-prefixed nonce for the signature.
  /// @param deadline The deadline for the intent.
  /// @param params The borrow parameters.
  struct BorrowAction {
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
    BorrowParams params;
  }

  /// @notice Intent action to repay assets to a reserve.
  /// @param onBehalfOf The address of the user on whose behalf the repay is performed.
  /// @param nonce The key-prefixed nonce for the signature.
  /// @param deadline The deadline for the intent.
  /// @param params The repay parameters.
  struct RepayAction {
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
    RepayParams params;
  }

  /// @notice Intent action to enable or disable a reserve as collateral.
  /// @param onBehalfOf The address of the user on whose behalf the action is performed.
  /// @param nonce The key-prefixed nonce for the signature.
  /// @param deadline The deadline for the intent.
  /// @param params The setUsingAsCollateral parameters.
  struct SetUsingAsCollateralAction {
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
    SetUsingAsCollateralParams params;
  }

  /// @notice Intent action to update the risk premium of a user position.
  /// @param user The address of the user whose risk premium is being updated.
  /// @param nonce The key-prefixed nonce for the signature.
  /// @param deadline The deadline for the intent.
  /// @param params The updateUserRiskPremium parameters.
  struct UpdateUserRiskPremiumAction {
    address user;
    uint256 nonce;
    uint256 deadline;
    UpdateUserRiskPremiumParams params;
  }

  /// @notice Intent action to update the dynamic configuration of a user position.
  /// @param user The address of the user whose dynamic config is being updated.
  /// @param nonce The key-prefixed nonce for the signature.
  /// @param deadline The deadline for the intent.
  /// @param params The updateUserDynamicConfig parameters.
  struct UpdateUserDynamicConfigAction {
    address user;
    uint256 nonce;
    uint256 deadline;
    UpdateUserDynamicConfigParams params;
  }

  /// @notice Facilitates `supply` action on the specified registered `spoke` with a typed signature from `onBehalfOf`.
  /// @dev Supplied assets are pulled from `onBehalfOf`, prior approval to this gateway is required.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param action The structured supply action.
  /// @param signature The signed bytes for the intent.
  /// @return The amount of shares supplied.
  /// @return The amount of assets supplied.
  function supplyWithSig(
    SupplyAction calldata action,
    bytes calldata signature
  ) external returns (uint256, uint256);

  /// @notice Facilitates `withdraw` action on the specified registered `spoke` with a typed signature from `onBehalfOf`.
  /// @dev Providing an amount exceeding the user's current withdrawable balance indicates a request for a maximum withdrawal.
  /// @dev Withdrawn assets are pushed to `onBehalfOf`.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param action The structured withdraw action.
  /// @param signature The signed bytes for the intent.
  /// @return The amount of shares withdrawn.
  /// @return The amount of assets withdrawn.
  function withdrawWithSig(
    WithdrawAction calldata action,
    bytes calldata signature
  ) external returns (uint256, uint256);

  /// @notice Facilitates `borrow` action on the specified registered `spoke` with a typed signature from `onBehalfOf`.
  /// @dev Borrowed assets are pushed to `onBehalfOf`.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param action The structured borrow action.
  /// @param signature The signed bytes for the intent.
  /// @return The amount of shares borrowed.
  /// @return The amount of assets borrowed.
  function borrowWithSig(
    BorrowAction calldata action,
    bytes calldata signature
  ) external returns (uint256, uint256);

  /// @notice Facilitates `repay` action on the specified registered `spoke` with a typed signature from `onBehalfOf`.
  /// @dev Repay assets are pulled from `onBehalfOf`, prior approval to this gateway is required.
  /// @dev Providing an amount greater than the user's current debt indicates a request to repay the maximum possible amount.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param action The structured repay action.
  /// @param signature The signed bytes for the intent.
  /// @return The amount of shares repaid.
  /// @return The amount of assets repaid.
  function repayWithSig(
    RepayAction calldata action,
    bytes calldata signature
  ) external returns (uint256, uint256);

  /// @notice Facilitates `setUsingAsCollateral` action on the specified registered `spoke` with a typed signature from `onBehalfOf`.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param action The structured setUsingAsCollateral action.
  /// @param signature The signed bytes for the intent.
  function setUsingAsCollateralWithSig(
    SetUsingAsCollateralAction calldata action,
    bytes calldata signature
  ) external;

  /// @notice Facilitates `updateUserRiskPremium` action on the specified registered `spoke` with a typed signature from `user`.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param action The structured updateUserRiskPremium action.
  /// @param signature The signed bytes for the intent.
  function updateUserRiskPremiumWithSig(
    UpdateUserRiskPremiumAction calldata action,
    bytes calldata signature
  ) external;

  /// @notice Facilitates `updateUserDynamicConfig` action on the specified registered `spoke` with a typed signature from `user`.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param action The structured updateUserDynamicConfig action.
  /// @param signature The signed bytes for the intent.
  function updateUserDynamicConfigWithSig(
    UpdateUserDynamicConfigAction calldata action,
    bytes calldata signature
  ) external;

  /// @notice Facilitates setting this gateway as user position manager on the specified registered `spoke`
  /// with a typed signature from `user`.
  /// @dev The signature is consumed on the the specified registered `spoke`.
  /// @dev The given data is passed to the `spoke` for the signature to be verified.
  /// @param spoke The address of the registered spoke.
  /// @param user The address of the user on whose behalf this gateway can act.
  /// @param approve True to approve the gateway, false to revoke approval.
  /// @param nonce The key-prefixed nonce for the signature.
  /// @param deadline The deadline for the intent.
  /// @param signature The signed bytes for the intent.
  function setSelfAsUserPositionManagerWithSig(
    address spoke,
    address user,
    bool approve,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external;

  /// @notice Facilitates consuming a permit for the given reserve's underlying asset on the specified registered `spoke`.
  /// @dev The given data is passed to the underlying asset for the signature to be verified.
  /// @dev Spender is this gateway contract.
  /// @param spoke The address of the spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param onBehalfOf The address of the user on whose behalf the permit is being used.
  /// @param value The amount of the underlying asset to permit.
  /// @param deadline The deadline for the permit.
  function permitReserve(
    address spoke,
    uint256 reserveId,
    address onBehalfOf,
    uint256 value,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external;

  /// @notice Facilitates `supply` action using Permit2's permitWitnessTransferFrom.
  /// @dev User must have approved Permit2 to spend their tokens.
  /// @dev The SupplyAction struct is used as the witness data in the Permit2 signature.
  /// @param permit The Permit2 transfer data signed over by the user.
  /// @param action The structured supply action (used as witness).
  /// @param signature The Permit2 signature.
  /// @return The amount of shares supplied.
  /// @return The amount of assets supplied.
  function supplyWithPermit2(
    ISignatureTransfer.PermitTransferFrom calldata permit,
    SupplyAction calldata action,
    bytes calldata signature
  ) external returns (uint256, uint256);

  /// @notice Facilitates `repay` action using Permit2's permitWitnessTransferFrom.
  /// @dev User must have approved Permit2 to spend their tokens.
  /// @dev The RepayAction struct is used as the witness data in the Permit2 signature.
  /// @dev Providing an amount greater than the user's current debt indicates a request to repay the maximum possible amount.
  /// @param permit The Permit2 transfer data signed over by the user.
  /// @param action The structured repay action (used as witness).
  /// @param signature The Permit2 signature.
  /// @return The amount of shares repaid.
  /// @return The amount of assets repaid.
  function repayWithPermit2(
    ISignatureTransfer.PermitTransferFrom calldata permit,
    RepayAction calldata action,
    bytes calldata signature
  ) external returns (uint256, uint256);

  /// @notice Executes a batch of actions with a single signature.
  /// @dev The batch type string is constructed dynamically based on the action types.
  /// @dev All actions in the batch are executed for the same `onBehalfOf` address.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param actionTypes Array of action types (ActionType enum values).
  /// @param actionData Array of ABI-encoded action params structs corresponding to each action type.
  /// @param onBehalfOf The address of the user on whose behalf all actions are performed.
  /// @param nonce The key-prefixed nonce for the batch signature.
  /// @param deadline The deadline for the batch intent.
  /// @param signature The signed bytes for the batch intent.
  function executeBatchWithSig(
    uint8[] memory actionTypes,
    bytes[] memory actionData,
    address onBehalfOf,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external;

  /// @notice Returns the type hash for the SupplyAction intent.
  function SUPPLY_TYPEHASH() external view returns (bytes32);

  /// @notice Returns the type hash for the WithdrawAction intent.
  function WITHDRAW_TYPEHASH() external view returns (bytes32);

  /// @notice Returns the type hash for the BorrowAction intent.
  function BORROW_TYPEHASH() external view returns (bytes32);

  /// @notice Returns the type hash for the RepayAction intent.
  function REPAY_TYPEHASH() external view returns (bytes32);

  /// @notice Returns the type hash for the SetUsingAsCollateralAction intent.
  function SET_USING_AS_COLLATERAL_TYPEHASH() external view returns (bytes32);

  /// @notice Returns the type hash for the UpdateUserRiskPremiumAction intent.
  function UPDATE_USER_RISK_PREMIUM_TYPEHASH() external view returns (bytes32);

  /// @notice Returns the type hash for the UpdateUserDynamicConfigAction intent.
  function UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH() external view returns (bytes32);

  /// @notice Returns the EIP-712 witness type string for SupplyAction used with Permit2.
  function SUPPLY_PERMIT2_WITNESS_TYPE_STRING() external view returns (string memory);

  /// @notice Returns the EIP-712 witness type string for RepayAction used with Permit2.
  function REPAY_PERMIT2_WITNESS_TYPE_STRING() external view returns (string memory);

  /// @notice Returns the canonical Permit2 contract address.
  function PERMIT2() external view returns (address);
}
