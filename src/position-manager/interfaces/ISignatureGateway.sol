// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IMulticall} from 'src/interfaces/IMulticall.sol';
import {IIntentConsumer} from 'src/interfaces/IIntentConsumer.sol';
import {IGatewayBase} from 'src/position-manager/interfaces/IGatewayBase.sol';

/// @title ISignatureGateway
/// @author Aave Labs
/// @notice Minimal interface for protocol actions involving signed intents.
interface ISignatureGateway is IGatewayBase, IIntentConsumer, IMulticall {
  /// @notice Intent data to supply assets to a reserve.
  /// @param spoke The address of the registered spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount of assets to supply.
  /// @param onBehalfOf The address of the user on whose behalf the supply is performed.
  /// @param nonce The key-prefixed nonce for the signature.
  /// @param deadline The deadline for the intent.
  struct Supply {
    address spoke;
    uint256 reserveId;
    uint256 amount;
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
  }

  /// @notice Intent data to withdraw assets from a reserve.
  /// @param spoke The address of the registered spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount of assets to withdraw.
  /// @param onBehalfOf The address of the user on whose behalf the withdraw is performed.
  /// @param nonce The key-prefixed nonce for the signature.
  /// @param deadline The deadline for the intent.
  struct Withdraw {
    address spoke;
    uint256 reserveId;
    uint256 amount;
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
  }

  /// @notice Intent data to borrow assets from a reserve.
  /// @param spoke The address of the registered spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount of assets to borrow.
  /// @param onBehalfOf The address of the user on whose behalf the borrow is performed.
  /// @param nonce The key-prefixed nonce for the signature.
  /// @param deadline The deadline for the intent.
  struct Borrow {
    address spoke;
    uint256 reserveId;
    uint256 amount;
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
  }

  /// @notice Intent data to repay assets to a reserve.
  /// @param spoke The address of the registered spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount of assets to repay.
  /// @param onBehalfOf The address of the user on whose behalf the repay is performed.
  /// @param nonce The key-prefixed nonce for the signature.
  /// @param deadline The deadline for the intent.
  struct Repay {
    address spoke;
    uint256 reserveId;
    uint256 amount;
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
  }

  /// @notice Intent data to enable or disable a reserve as collateral.
  /// @param spoke The address of the registered spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param useAsCollateral True to enable the reserve as collateral, false to disable it.
  /// @param onBehalfOf The address of the user on whose behalf the action is performed.
  /// @param nonce The key-prefixed nonce for the signature.
  /// @param deadline The deadline for the intent.
  struct SetUsingAsCollateral {
    address spoke;
    uint256 reserveId;
    bool useAsCollateral;
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
  }

  /// @notice Intent data to update the risk premium of a user position.
  /// @param spoke The address of the registered spoke.
  /// @param user The address of the user whose risk premium is being updated.
  /// @param nonce The key-prefixed nonce for the signature.
  /// @param deadline The deadline for the intent.
  struct UpdateUserRiskPremium {
    address spoke;
    address user;
    uint256 nonce;
    uint256 deadline;
  }

  /// @notice Intent data to update the dynamic configuration of a user position.
  /// @param spoke The address of the registered spoke.
  /// @param user The address of the user whose dynamic config is being updated.
  /// @param nonce The key-prefixed nonce for the signature.
  /// @param deadline The deadline for the intent.
  struct UpdateUserDynamicConfig {
    address spoke;
    address user;
    uint256 nonce;
    uint256 deadline;
  }

  /// @notice Facilitates `supply` action on the specified registered `spoke` with a typed signature from `onBehalfOf`.
  /// @dev Supplied assets are pulled from `onBehalfOf`, prior approval to this gateway is required.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param params The structured supply parameters.
  /// @param signature The signed bytes for the intent.
  /// @return The amount of shares supplied.
  /// @return The amount of assets supplied.
  function supplyWithSig(
    Supply calldata params,
    bytes calldata signature
  ) external returns (uint256, uint256);

  /// @notice Facilitates `withdraw` action on the specified registered `spoke` with a typed signature from `onBehalfOf`.
  /// @dev Providing an amount exceeding the user's current withdrawable balance indicates a request for a maximum withdrawal.
  /// @dev Withdrawn assets are pushed to `onBehalfOf`.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param params The structured withdraw parameters.
  /// @param signature The signed bytes for the intent.
  /// @return The amount of shares withdrawn.
  /// @return The amount of assets withdrawn.
  function withdrawWithSig(
    Withdraw calldata params,
    bytes calldata signature
  ) external returns (uint256, uint256);

  /// @notice Facilitates `borrow` action on the specified registered `spoke` with a typed signature from `onBehalfOf`.
  /// @dev Borrowed assets are pushed to `onBehalfOf`.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param params The structured borrow parameters.
  /// @param signature The signed bytes for the intent.
  /// @return The amount of shares borrowed.
  /// @return The amount of assets borrowed.
  function borrowWithSig(
    Borrow calldata params,
    bytes calldata signature
  ) external returns (uint256, uint256);

  /// @notice Facilitates `repay` action on the specified registered `spoke` with a typed signature from `onBehalfOf`.
  /// @dev Repay assets are pulled from `onBehalfOf`, prior approval to this gateway is required.
  /// @dev Providing an amount greater than the user's current debt indicates a request to repay the maximum possible amount.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param params The structured repay parameters.
  /// @param signature The signed bytes for the intent.
  /// @return The amount of shares repaid.
  /// @return The amount of assets repaid.
  function repayWithSig(
    Repay calldata params,
    bytes calldata signature
  ) external returns (uint256, uint256);

  /// @notice Facilitates `setUsingAsCollateral` action on the specified registered `spoke` with a typed signature from `onBehalfOf`.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param params The structured setUsingAsCollateral parameters.
  /// @param signature The signed bytes for the intent.
  function setUsingAsCollateralWithSig(
    SetUsingAsCollateral calldata params,
    bytes calldata signature
  ) external;

  /// @notice Facilitates `updateUserRiskPremium` action on the specified registered `spoke` with a typed signature from `user`.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param params The structured updateUserRiskPremium parameters.
  /// @param signature The signed bytes for the intent.
  function updateUserRiskPremiumWithSig(
    UpdateUserRiskPremium calldata params,
    bytes calldata signature
  ) external;

  /// @notice Facilitates `updateUserDynamicConfig` action on the specified registered `spoke` with a typed signature from `user`.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param params The structured updateUserDynamicConfig parameters.
  /// @param signature The signed bytes for the intent.
  function updateUserDynamicConfigWithSig(
    UpdateUserDynamicConfig calldata params,
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

  /// @notice Returns the type hash for the Supply intent.
  function SUPPLY_TYPEHASH() external view returns (bytes32);

  /// @notice Returns the type hash for the Withdraw intent.
  function WITHDRAW_TYPEHASH() external view returns (bytes32);

  /// @notice Returns the type hash for the Borrow intent.
  function BORROW_TYPEHASH() external view returns (bytes32);

  /// @notice Returns the type hash for the Repay intent.
  function REPAY_TYPEHASH() external view returns (bytes32);

  /// @notice Returns the type hash for the SetUsingAsCollateral intent.
  function SET_USING_AS_COLLATERAL_TYPEHASH() external view returns (bytes32);

  /// @notice Returns the type hash for the UpdateUserRiskPremium intent.
  function UPDATE_USER_RISK_PREMIUM_TYPEHASH() external view returns (bytes32);

  /// @notice Returns the type hash for the UpdateUserDynamicConfig intent.
  function UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH() external view returns (bytes32);
}
