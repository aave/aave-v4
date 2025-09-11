// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IMulticall} from 'src/interfaces/IMulticall.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';

interface ISignatureGateway is IMulticall {
  /**
   * @notice Thrown when signature deadline has passed or signer is not `onBehalfOf`.
   */
  error InvalidSignature();

  /**
   * @notice Thrown when reserveId does not correspond to a registered reserve.
   */
  error InvalidReserveId();

  /**
   * @notice Facilitates supply action on connected SPOKE() with a typed signature from `onBehalfOf`.
   * @dev Supplied assets are pulled from `onBehalfOf`, prior approval to this gateway is required.
   * @param reserveId The identifier of the reserve.
   * @param amount The amount of asset to supply.
   * @param onBehalfOf The address of the user to supply assets on behalf of.
   * @param deadline The deadline for the signature.
   * @param signature The signed bytes for the intent.
   */
  function supplyWithSig(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf,
    uint256 deadline,
    bytes calldata signature
  ) external;

  /**
   * @notice Facilitates withdraw action on connected SPOKE() with a typed signature from `onBehalfOf`.
   * @dev Providing an amount exceeding the user's current withdrawable balance indicates a request for a maximum withdrawal.
   * @dev Withdrawn assets are pushed to `onBehalfOf`.
   * @param reserveId The identifier of the reserve.
   * @param amount The amount of asset to withdraw.
   * @param onBehalfOf The address of the user to withdraw the asset on behalf of.
   * @param deadline The deadline for the signature.
   * @param signature The signed bytes for the intent.
   */
  function withdrawWithSig(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf,
    uint256 deadline,
    bytes calldata signature
  ) external;

  /**
   * @notice Facilitates borrow action on connected SPOKE() with a typed signature from `onBehalfOf`.
   * @dev Borrowed assets are pushed to `onBehalfOf`.
   * @param reserveId The identifier of the reserve.
   * @param amount The amount of asset to borrow.
   * @param onBehalfOf The address of the user to borrow the asset on behalf of.
   * @param deadline The deadline for the signature.
   * @param signature The signed bytes for the intent.
   */
  function borrowWithSig(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf,
    uint256 deadline,
    bytes calldata signature
  ) external;

  /**
   * @notice Facilitates repay action on connected SPOKE() with a typed signature from `onBehalfOf`.
   * @dev Repay assets are pulled from `onBehalfOf`, prior approval to this gateway is required.
   * @dev Providing an amount greater than the user's current debt indicates a request to repay the maximum possible amount.
   * @param reserveId The identifier of the reserve.
   * @param amount The amount of asset to repay.
   * @param onBehalfOf The address of the user to repay the asset on behalf of.
   * @param deadline The deadline for the signature.
   * @param signature The signed bytes for the intent.
   */
  function repayWithSig(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf,
    uint256 deadline,
    bytes calldata signature
  ) external;

  /**
   * @notice Facilitates setUsingAsCollateral action on connected SPOKE() with a typed signature from `onBehalfOf`.
   * @param reserveId The identifier of the reserve.
   * @param useAsCollateral True if enabling reserve as collateral.
   * @param onBehalfOf The address of the user to set the use as collateral status on behalf of.
   * @param deadline The deadline for the signature.
   * @param signature The signed bytes for the intent.
   */
  function setUsingAsCollateralWithSig(
    uint256 reserveId,
    bool useAsCollateral,
    address onBehalfOf,
    uint256 deadline,
    bytes calldata signature
  ) external;

  /**
   * @notice Facilitates updateUserRiskPremium action on connected SPOKE() with a typed signature from `user`.
   * @param user The address of the user to update the risk premium for.
   * @param deadline The deadline for the signature.
   * @param signature The signed bytes for the intent.
   */
  function updateUserRiskPremiumWithSig(
    address user,
    uint256 deadline,
    bytes calldata signature
  ) external;

  /**
   * @notice Facilitates updateUserDynamicConfig action on connected SPOKE() with a typed signature from `user`.
   * @param user The address of the user to update the dynamic config for.
   * @param deadline The deadline for the signature.
   * @param signature The signed bytes for the intent.
   */
  function updateUserDynamicConfigWithSig(
    address user,
    uint256 deadline,
    bytes calldata signature
  ) external;

  /**
   * @notice Facilitates setting this gateway as user position manager on connected SPOKE()
   * with a typed signature from `user`.
   * @param user The address of the user to set as position manager.
   * @param approve The approval status.
   * @param deadline The deadline for the signature.
   * @param signature The signed bytes for the action.
   */
  function setSelfAsUserPositionManagerWithSig(
    address user,
    bool approve,
    uint256 deadline,
    bytes calldata signature
  ) external;

  /**
   * @notice Allows consuming a permit for the given reserve's underlying asset on connected SPOKE().
   * @dev Spender is this gateway contract.
   * @param reserveId The identifier of the reserve.
   * @param onBehalfOf The address of the user on whose behalf the permit is being used.
   * @param value The amount of the underlying asset to permit.
   * @param deadline The deadline for the permit.
   */
  function permitReserve(
    uint256 reserveId,
    address onBehalfOf,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;

  /**
   * @notice Permissioned operation to renounce self as user position manager on connected SPOKE() for specified `user`.
   */
  function renounceSelfAsUserPositionManager(address user) external;

  /**
   * @notice Increments the nonce for the caller, consuming current nonce.
   */
  function useNonce() external;

  /**
   * @notice Returns the current nonce for the given `user`.
   */
  function nonces(address user) external view returns (uint256);

  /**
   * @notice Returns the address of the connected SPOKE().
   */
  function SPOKE() external view returns (ISpoke);

  /**
   * @notice Returns the EIP712 domain separator.
   */
  function DOMAIN_SEPARATOR() external view returns (bytes32);

  /**
   * @notice Returns the type hash for the Supply intent.
   */
  function SUPPLY_TYPEHASH() external view returns (bytes32);

  /**
   * @notice Returns the type hash for the Withdraw intent.
   */
  function WITHDRAW_TYPEHASH() external view returns (bytes32);

  /**
   * @notice Returns the type hash for the Borrow intent.
   */
  function BORROW_TYPEHASH() external view returns (bytes32);

  /**
   * @notice Returns the type hash for the Repay intent.
   */
  function REPAY_TYPEHASH() external view returns (bytes32);

  /**
   * @notice Returns the type hash for the SetUsingAsCollateral intent.
   */
  function SET_USING_AS_COLLATERAL_TYPEHASH() external view returns (bytes32);

  /**
   * @notice Returns the type hash for the UpdateUserRiskPremium intent.
   */
  function UPDATE_USER_RISK_PREMIUM_TYPEHASH() external view returns (bytes32);

  /**
   * @notice Returns the type hash for the UpdateUserDynamicConfig intent.
   */
  function UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH() external view returns (bytes32);
}
