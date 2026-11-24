// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';

/// @title IEligibilityRegistry
/// @author Aave Labs
/// @notice Interface for the registry of an issuer, read by the policy gates of permissioned Spokes.
/// @dev Stores a status and a KYC expiry per account, and the reserve managers of each Spoke reserve.
interface IEligibilityRegistry is IAccessManaged {
  /// @notice Eligibility status of an account.
  /// @dev NONE: never onboarded. ACTIVE: can use the Spoke. OFFBOARDED: can exit but not add risk.
  /// FROZEN: blocked by compliance.
  enum Status {
    NONE,
    ACTIVE,
    OFFBOARDED,
    FROZEN
  }

  /// @notice Stored eligibility of an account.
  /// @param status The stored status.
  /// @param validUntil The KYC expiry timestamp, only used when ACTIVE.
  struct Entry {
    Status status;
    uint40 validUntil;
  }

  /// @notice Emitted when the eligibility of an account is updated.
  /// @param account The account.
  /// @param status The new status.
  /// @param validUntil The KYC expiry timestamp.
  event UpdateEligibility(address indexed account, Status status, uint40 validUntil);

  /// @notice Emitted when the actions of a reserve manager are updated.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param manager The reserve manager.
  /// @param actions The granted action bits (see `AuthKind`).
  event UpdateReserveManager(
    address indexed spoke,
    uint256 indexed reserveId,
    address indexed manager,
    uint8 actions
  );

  /// @notice Thrown when a required address is zero.
  error InvalidAddress();

  /// @notice Thrown when action bits are outside `AuthKind.ALL_ACTIONS`.
  error InvalidActions();

  /// @notice Updates the status and KYC expiry of accounts.
  /// @param accounts The accounts to update.
  /// @param status The new status.
  /// @param validUntil The KYC expiry timestamp, only used when `status` is ACTIVE.
  function updateEligibility(
    address[] calldata accounts,
    Status status,
    uint40 validUntil
  ) external;

  /// @notice Updates the actions an account can perform as reserve manager of a Spoke reserve.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param manager The reserve manager.
  /// @param actions The granted action bits (see `AuthKind`), zero to revoke.
  function updateReserveManager(
    address spoke,
    uint256 reserveId,
    address manager,
    uint8 actions
  ) external;

  /// @notice Returns the effective status of an account.
  /// @dev An ACTIVE account past its KYC expiry returns OFFBOARDED.
  /// @param account The account.
  /// @return The effective status.
  function getStatus(address account) external view returns (Status);

  /// @notice Returns the stored eligibility of an account.
  /// @param account The account.
  /// @return The stored entry.
  function getEntry(address account) external view returns (Entry memory);

  /// @notice Returns the actions an account can perform as reserve manager of a Spoke reserve.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param manager The account.
  /// @return The granted action bits, zero if none.
  function getReserveManagerActions(
    address spoke,
    uint256 reserveId,
    address manager
  ) external view returns (uint8);
}
