// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title IBorrowerEligibility
/// @author Aave Labs
/// @notice Interface for a provider of permissioned-borrowing eligibility.
interface IBorrowerEligibility {
  /// @notice Returns whether `account` is eligible to borrow.
  function isEligible(address account) external view returns (bool);
}
