// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IMulticall} from 'src/interfaces/IMulticall.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';

interface ITypedSignatureGateway is IMulticall {
  /**
   * @notice Thrown when signature deadline has passed or signer is not `onBehalfOf`.
   */
  error InvalidSignature();

  /**
   * @notice Facilitates supply action on connected SPOKE() with a typed signature from `onBehalfOf`.
   * @param reserveId The identifier of the reserve.
   * @param amount The amount of asset to supply.
   * @param onBehalfOf The address of the user to supply the asset on behalf of.
   * @param deadline The deadline for the signature.
   * @param signature The signed bytes for the action.
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
   * @param reserveId The identifier of the reserve.
   * @param amount The amount of asset to withdraw.
   * @param onBehalfOf The address of the user to withdraw the asset on behalf of.
   * @param deadline The deadline for the signature.
   * @param signature The signed bytes for the action.
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
   * @param reserveId The identifier of the reserve.
   * @param amount The amount of asset to borrow.
   * @param onBehalfOf The address of the user to borrow the asset on behalf of.
   * @param deadline The deadline for the signature.
   * @param signature The signed bytes for the action.
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
   * @param reserveId The identifier of the reserve.
   * @param amount The amount of asset to repay.
   * @param onBehalfOf The address of the user to repay the asset on behalf of.
   * @param deadline The deadline for the signature.
   * @param signature The signed bytes for the action.
   */
  function repayWithSig(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf,
    uint256 deadline,
    bytes calldata signature
  ) external;

  /**
   * @notice Facilitates setting this gateway as user position manager on connected SPOKE() with a typed signature from `user`.
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
   * @notice Forwards permitReserve action on connected SPOKE().
   * @dev Convenience function which is expected to be used with multicall.
   * @param reserveId The identifier of the reserve.
   * @param onBehalfOf The address of the user to permit the reserve on behalf of.
   * @param value The value of the permit.
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
   * @notice Permissionless operation facilitates renounce self as user position manager on connected SPOKE() for specified `user`.
   * @param user The address of the user to renounce self as position manager.
   */
  function renounceSelfAsUserPositionManager(address user) external;

  /**
   * @notice Increments the nonce for the caller. Used to invalidate a nonce.
   */
  function useNonce() external;

  /**
   * @notice Returns the nonce for the given `user`.
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
   * @notice Returns the type hash for the Supply action.
   */
  function SUPPLY_TYPEHASH() external view returns (bytes32);

  /**
   * @notice Returns the type hash for the Withdraw action.
   */
  function WITHDRAW_TYPEHASH() external view returns (bytes32);

  /**
   * @notice Returns the type hash for the Borrow action.
   */
  function BORROW_TYPEHASH() external view returns (bytes32);

  /**
   * @notice Returns the type hash for the Repay action.
   */
  function REPAY_TYPEHASH() external view returns (bytes32);
}
