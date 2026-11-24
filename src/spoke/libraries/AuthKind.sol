// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title AuthKind
/// @author Aave Labs
/// @notice How the caller of a position action on a permissioned Spoke is authorized, and the
/// actions a reserve manager can be granted.
library AuthKind {
  /// @dev The caller is the position owner.
  uint8 internal constant OWNER = 1;
  /// @dev The caller is a position manager approved by the owner.
  uint8 internal constant POSITION_MANAGER = 2;
  /// @dev The caller is a reserve manager of the reserve in the call.
  uint8 internal constant RESERVE_MANAGER = 3;

  /// @dev Reserve manager action bits. Borrow has no bit, so it can never be granted.
  uint8 internal constant ACTION_SUPPLY = 1;
  uint8 internal constant ACTION_WITHDRAW = 2;
  uint8 internal constant ACTION_REPAY = 4;
  uint8 internal constant ACTION_SET_COLLATERAL = 8;
  uint8 internal constant ALL_ACTIONS = 15;
}
