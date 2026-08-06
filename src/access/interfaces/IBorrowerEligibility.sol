// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title IBorrowerEligibility
/// @author Aave Labs
/// @notice Interface for checking whether an account is eligible to borrow.
interface IBorrowerEligibility {
  /// @notice Returns whether `borrower` is eligible to call a permissioned borrow entry point.
  function isBorrowerEligible(address borrower) external view returns (bool);
}
