// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {AccessManagerEnumerable} from 'src/access/AccessManagerEnumerable.sol';
import {IBorrowerEligibility} from 'src/access/interfaces/IBorrowerEligibility.sol';
import {AccessManager, IAccessManager} from 'src/dependencies/openzeppelin/AccessManager.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title PermissionedBorrowingAccessManager
/// @author Aave Labs
/// @notice POC access manager that authorizes borrowing through an external eligibility provider.
/// @dev The access manager cannot inspect call arguments, so eligibility applies to the caller rather than
/// the `onBehalfOf` account passed to `ISpoke.borrow`.
contract PermissionedBorrowingAccessManager is AccessManagerEnumerable {
  /// @notice Thrown when an invalid address is supplied to the constructor.
  error InvalidAddress();

  /// @notice The Spoke whose borrow entry point is permissioned.
  address public immutable SPOKE;

  /// @notice The external provider used to determine borrower eligibility.
  IBorrowerEligibility public immutable BORROWER_ELIGIBILITY;

  /// @param initialAdmin_ The initial access manager admin.
  /// @param spoke_ The Spoke whose `borrow` selector receives programmatic authorization.
  /// @param borrowerEligibility_ The external borrower eligibility provider.
  constructor(
    address initialAdmin_,
    address spoke_,
    address borrowerEligibility_
  ) AccessManagerEnumerable(initialAdmin_) {
    require(spoke_ != address(0) && borrowerEligibility_ != address(0), InvalidAddress());
    SPOKE = spoke_;
    BORROWER_ELIGIBILITY = IBorrowerEligibility(borrowerEligibility_);
  }

  /// @notice Returns whether `caller` can call `selector` on `target`.
  /// @dev Ordinary role-based access and scheduled operations take precedence. The eligibility fallback only
  /// applies to direct calls to the configured Spoke's `borrow` function.
  function canCall(
    address caller,
    address target,
    bytes4 selector
  ) public view override(AccessManager, IAccessManager) returns (bool immediate, uint32 delay) {
    (immediate, delay) = super.canCall(caller, target, selector);
    if (immediate || delay > 0) {
      return (immediate, delay);
    }

    // Do not let the eligibility fallback bypass target closure or AccessManager execution checks.
    if (isTargetClosed(target) || caller == address(this)) {
      return (false, 0);
    }

    if (target == SPOKE && selector == ISpoke.borrow.selector) {
      return (BORROWER_ELIGIBILITY.isBorrowerEligible(caller), 0);
    }

    return (false, 0);
  }
}
