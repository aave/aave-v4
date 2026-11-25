// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title IPolicyGate
/// @author Aave Labs
/// @notice Interface for the policy gate of a permissioned Spoke, which decides eligibility and can only restrict.
interface IPolicyGate {
  /// @notice Returns whether a call on the Spoke is allowed for eligibility purposes.
  /// @dev Called by the Spoke on position actions, after it has authorized the caller, and on every `liquidationCall`.
  /// @dev For `liquidationCall`, `caller` and `user` are the liquidator and `auth` is `AuthKind.OWNER`.
  /// @param caller The transaction initiator on the Spoke.
  /// @param user The owner of the position being modified.
  /// @param data The full calldata of the Spoke call.
  /// @param auth How the caller is authorized (see `AuthKind`).
  /// @return True if the call is allowed.
  function isEligible(
    address caller,
    address user,
    bytes calldata data,
    uint8 auth
  ) external view returns (bool);

  /// @notice Returns whether an account can perform a call on the calling Spoke as reserve manager,
  /// on the position of any user.
  /// @dev Called by the Spoke when the caller is neither the owner nor an approved position manager.
  /// The Spoke never lets a reserve manager borrow, whatever this returns.
  /// @param account The account.
  /// @param data The full calldata of the Spoke call.
  /// @return True if `account` is allowed to perform the call as reserve manager.
  function isReserveManagerAllowed(
    address account,
    bytes calldata data
  ) external view returns (bool);
}
