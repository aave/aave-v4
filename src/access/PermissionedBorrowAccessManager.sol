// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {AccessManagerEnumerable} from 'src/access/AccessManagerEnumerable.sol';
import {IBorrowerEligibility} from 'src/access/interfaces/IBorrowerEligibility.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title PermissionedBorrowAccessManager
/// @author Aave Labs
/// @notice Contextual access manager that restricts borrowing to eligible position owners.
/// @dev Non-borrow position actions retain the Spoke's standard position-manager authorization.
/// Explicit AccessManager roles can authorize callers before this custom policy is evaluated.
contract PermissionedBorrowAccessManager is AccessManagerEnumerable {
  /// @notice The Spoke controlled by this access manager.
  ISpoke public immutable SPOKE;

  /// @notice The provider used to determine borrower eligibility.
  IBorrowerEligibility public immutable BORROWER_ELIGIBILITY;

  /// @dev Constructor.
  /// @param initialAdmin_ The address of the initial admin.
  /// @param spoke_ The Spoke controlled by this access manager.
  /// @param borrowerEligibility_ The provider used to determine borrower eligibility.
  constructor(
    address initialAdmin_,
    ISpoke spoke_,
    IBorrowerEligibility borrowerEligibility_
  ) AccessManagerEnumerable(initialAdmin_) {
    require(address(spoke_) != address(0), ISpoke.InvalidAddress());
    require(address(borrowerEligibility_) != address(0), ISpoke.InvalidAddress());
    SPOKE = spoke_;
    BORROWER_ELIGIBILITY = borrowerEligibility_;
  }

  /// @dev Extends the default position-manager policy with borrower eligibility.
  function _isPositionActionAllowed(
    address caller,
    address target,
    bytes calldata data
  ) internal view override returns (bool handled, bool allowed) {
    if (target != address(SPOKE)) return super._isPositionActionAllowed(caller, target, data);

    (bool valid, address onBehalfOf) = _decodePositionAction(data);
    if (!valid) return (true, false);

    (, allowed) = super._isPositionActionAllowed(caller, target, data);
    if (!allowed) return (true, false);

    allowed = bytes4(data) != ISpoke.borrow.selector || BORROWER_ELIGIBILITY.isEligible(onBehalfOf);
    return (true, allowed);
  }
}
