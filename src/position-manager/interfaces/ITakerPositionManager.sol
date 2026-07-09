// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IPositionManagerIntentBase} from 'src/position-manager/interfaces/IPositionManagerIntentBase.sol';

/// @title ITakerPositionManager
/// @author Aave Labs
/// @notice Interface for position manager handling withdraw permit and borrow permit actions on behalf of users.
/// @dev Allowances in the context of this TakerPositionManager represent how much the spender is allowed to impact
/// the owner position (decreasing supplied amount for the withdraw action, increasing debt amount for the borrow action),
/// and not the amount of assets that the spender will receive from the onBehalfOf action.
interface ITakerPositionManager is IPositionManagerIntentBase {
  /// @notice Structured parameters for withdraw permit intent.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param owner The address of the owner.
  /// @param spender The address of the spender.
  /// @param amount The amount of allowance.
  /// @param nonce The key-prefixed nonce for the signature.
  /// @param deadline The deadline for the intent.
  struct WithdrawPermit {
    address spoke;
    uint256 reserveId;
    address owner;
    address spender;
    uint256 amount;
    uint256 nonce;
    uint256 deadline;
  }

  /// @notice Structured parameters for borrow permit intent.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param owner The address of the owner.
  /// @param spender The address of the spender.
  /// @param amount The amount of allowance.
  /// @param nonce The key-prefixed nonce for the signature.
  /// @param deadline The deadline for the intent.
  struct BorrowPermit {
    address spoke;
    uint256 reserveId;
    address owner;
    address spender;
    uint256 amount;
    uint256 nonce;
    uint256 deadline;
  }

  /// @notice Emitted when the withdraw allowance granted to a spender is updated.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param owner The address of the owner.
  /// @param spender The address of the spender.
  /// @param amount The amount of allowance.
  event WithdrawApproval(
    address indexed spoke,
    uint256 indexed reserveId,
    address indexed owner,
    address spender,
    uint256 amount
  );

  /// @notice Emitted when the borrow allowance granted to a spender is updated.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param owner The address of the owner.
  /// @param spender The address of the spender.
  /// @param amount The amount of allowance.
  event BorrowApproval(
    address indexed spoke,
    uint256 indexed reserveId,
    address indexed owner,
    address spender,
    uint256 amount
  );

  /// @notice Emitted when withdrawing on behalf of a user.
  /// @param spoke The address of the Spoke.
  /// @param caller The transaction initiator, and recipient of the underlying asset being withdrawn.
  /// @param onBehalfOf The owner of the modified position.
  /// @param reserveId The identifier of the reserve.
  /// @param withdrawnShares The amount of supply shares burned.
  /// @param withdrawnAmount The amount of underlying asset withdrawn.
  event WithdrawOnBehalfOf(
    address indexed spoke,
    address indexed caller,
    address indexed onBehalfOf,
    uint256 reserveId,
    uint256 withdrawnShares,
    uint256 withdrawnAmount
  );

  /// @notice Emitted when borrowing on behalf of a user.
  /// @param spoke The address of the Spoke.
  /// @param caller The transaction initiator, and recipient of the underlying asset being borrowed.
  /// @param onBehalfOf The owner of the position on which debt is generated.
  /// @param reserveId The identifier of the reserve.
  /// @param drawnShares The amount of debt shares minted.
  /// @param drawnAmount The amount of underlying asset borrowed.
  event BorrowOnBehalfOf(
    address indexed spoke,
    address indexed caller,
    address indexed onBehalfOf,
    uint256 reserveId,
    uint256 drawnShares,
    uint256 drawnAmount
  );

  /// @notice Thrown when the withdraw allowance is insufficient.
  error InsufficientWithdrawAllowance(uint256 allowance, uint256 required);

  /// @notice Thrown when the borrow allowance is insufficient.
  error InsufficientBorrowAllowance(uint256 allowance, uint256 required);

  /// @notice Approves a spender to withdraw assets from the specified reserve on behalf of the owner.
  /// @dev Using `type(uint256).max` as the amount results in an infinite approval, so the allowance is never decreased.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param spender The address of the spender to receive the allowance.
  /// @param amount The amount of allowance.
  function approveWithdraw(
    address spoke,
    uint256 reserveId,
    address spender,
    uint256 amount
  ) external;

  /// @notice Approves a spender to withdraw assets from the specified reserve on behalf of the owner using an EIP712-typed intent.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @dev Using `type(uint256).max` as the amount results in an infinite approval, so the allowance is never decreased.
  /// @param params The structured WithdrawPermit parameters.
  /// @param signature The EIP712-compliant signature bytes.
  function approveWithdrawWithSig(
    WithdrawPermit calldata params,
    bytes calldata signature
  ) external;

  /// @notice Approves a spender to borrow assets from the specified reserve on behalf of the owner.
  /// @dev Using `type(uint256).max` as the amount results in an infinite approval, so the allowance is never decreased.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param spender The address of the spender to receive the allowance.
  /// @param amount The amount of allowance.
  function approveBorrow(
    address spoke,
    uint256 reserveId,
    address spender,
    uint256 amount
  ) external;

  /// @notice Approves a spender to borrow assets from the specified reserve on behalf of the owner using an EIP712-typed intent.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @dev Using `type(uint256).max` as the amount results in an infinite approval, so the allowance is never decreased.
  /// @param params The structured BorrowPermit parameters.
  /// @param signature The EIP712-compliant signature bytes.
  function approveBorrowWithSig(BorrowPermit calldata params, bytes calldata signature) external;

  /// @notice Renounces the withdraw allowance given by the owner.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param owner The address of the owner.
  function renounceWithdrawAllowance(address spoke, uint256 reserveId, address owner) external;

  /// @notice Renounces the borrow allowance given by the owner.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param owner The address of the owner.
  function renounceBorrowAllowance(address spoke, uint256 reserveId, address owner) external;

  /// @notice Executes a withdraw on behalf of a user.
  /// @dev The caller must have sufficient withdraw allowance from `onBehalfOf`.
  /// @dev The caller receives the withdrawn assets.
  /// @dev Contract must be an active and approved user position manager of `onBehalfOf`.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount to withdraw.
  /// @param onBehalfOf The address of the user to withdraw on behalf of.
  /// @return The amount of shares withdrawn.
  /// @return The amount of assets withdrawn.
  function withdrawOnBehalfOf(
    address spoke,
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256);

  /// @notice Executes a borrow on behalf of a user.
  /// @dev The caller must have sufficient borrow allowance from `onBehalfOf`.
  /// @dev The caller receives the borrowed assets.
  /// @dev Contract must be an active and approved user position manager of `onBehalfOf`.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount to borrow.
  /// @param onBehalfOf The address of the user to borrow on behalf of.
  /// @return The amount of shares borrowed.
  /// @return The amount of assets borrowed.
  function borrowOnBehalfOf(
    address spoke,
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256);

  /// @notice Returns the withdraw allowance for a spender on behalf of an owner.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param owner The address of the owner.
  /// @param spender The address of the spender.
  /// @return The amount of withdraw allowance.
  function withdrawAllowance(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender
  ) external view returns (uint256);

  /// @notice Returns the borrow allowance for a spender on behalf of an owner.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param owner The address of the owner.
  /// @param spender The address of the spender.
  /// @return The amount of borrow allowance.
  function borrowAllowance(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender
  ) external view returns (uint256);

  /// @notice Returns the type hash for the WithdrawPermit intent.
  function WITHDRAW_PERMIT_TYPEHASH() external view returns (bytes32);

  /// @notice Returns the type hash for the BorrowPermit intent.
  function BORROW_PERMIT_TYPEHASH() external view returns (bytes32);
}
