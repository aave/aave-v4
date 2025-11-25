// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

type ReserveFlags is uint8;

using ReserveFlagsLib for ReserveFlags global;

/// @title ReserveFlags Library
/// @author Aave Labs
/// @notice Packs all boolean flags of a Reserve as a single uint8.
library ReserveFlagsLib {
  /// @dev Mask for the `paused` flag.
  uint8 internal constant PAUSED_MASK = 0x001;
  /// @dev Mask for the `frozen` flag.
  uint8 internal constant FROZEN_MASK = 0x002;
  /// @dev Mask for the `borrowable` flag.
  uint8 internal constant BORROWABLE_MASK = 0x004;
  /// @dev Mask for the `canReceiveShares` flag.
  uint8 internal constant CAN_RECEIVE_SHARES_MASK = 0x008;

  /// @notice Initializes the ReserveFlags with the given values.
  /// @param _paused The `pause` flag status.
  /// @param _frozen The `frozen` flag status.
  /// @param _borrowable The `borrowable` flag status.
  /// @param _canReceiveShares The `canReceiveShares` flag status.
  /// @return The initialized ReserveFlags.
  function initFlags(
    bool _paused,
    bool _frozen,
    bool _borrowable,
    bool _canReceiveShares
  ) internal pure returns (ReserveFlags) {
    uint8 flags = 0;
    flags = _setFlag(flags, PAUSED_MASK, _paused);
    flags = _setFlag(flags, FROZEN_MASK, _frozen);
    flags = _setFlag(flags, BORROWABLE_MASK, _borrowable);
    flags = _setFlag(flags, CAN_RECEIVE_SHARES_MASK, _canReceiveShares);
    return ReserveFlags.wrap(flags);
  }

  /// @notice Sets the new status for the 'paused' flag.
  /// @param flags The current ReserveFlags.
  /// @param status The new status for the 'paused' flag.
  /// @return The updated ReserveFlags.
  function setPaused(ReserveFlags flags, bool status) internal pure returns (ReserveFlags) {
    return ReserveFlags.wrap(_setFlag(ReserveFlags.unwrap(flags), PAUSED_MASK, status));
  }

  /// @notice Sets the new status for the 'frozen' flag.
  /// @param flags The current ReserveFlags.
  /// @param status The new status for the 'frozen' flag.
  /// @return The updated ReserveFlags.
  function setFrozen(ReserveFlags flags, bool status) internal pure returns (ReserveFlags) {
    return ReserveFlags.wrap(_setFlag(ReserveFlags.unwrap(flags), FROZEN_MASK, status));
  }

  /// @notice Sets the new status for the 'borrowable' flag.
  /// @param flags The current ReserveFlags.
  /// @param status The new status for the 'borrowable' flag.
  /// @return The updated ReserveFlags.
  function setBorrowable(ReserveFlags flags, bool status) internal pure returns (ReserveFlags) {
    return ReserveFlags.wrap(_setFlag(ReserveFlags.unwrap(flags), BORROWABLE_MASK, status));
  }

  /// @notice Sets the new status for the 'canReceiveShares' flag.
  /// @param flags The current ReserveFlags.
  /// @param status The new status for the 'canReceiveShares' flag.
  /// @return The updated ReserveFlags.
  function setCanReceiveShares(
    ReserveFlags flags,
    bool status
  ) internal pure returns (ReserveFlags) {
    return ReserveFlags.wrap(_setFlag(ReserveFlags.unwrap(flags), CAN_RECEIVE_SHARES_MASK, status));
  }

  /// @notice Returns the 'paused' flag status.
  /// @param flags The current ReserveFlags.
  /// @return True if the flag is set.
  function paused(ReserveFlags flags) internal pure returns (bool) {
    return (ReserveFlags.unwrap(flags) & PAUSED_MASK) != 0;
  }

  /// @notice Returns the 'frozen' flag status.
  /// @param flags The current ReserveFlags.
  /// @return True if the flag is set.
  function frozen(ReserveFlags flags) internal pure returns (bool) {
    return (ReserveFlags.unwrap(flags) & FROZEN_MASK) != 0;
  }

  /// @notice Returns the 'borrowable' flag status.
  /// @param flags The current ReserveFlags.
  /// @return True if the flag is set.
  function borrowable(ReserveFlags flags) internal pure returns (bool) {
    return (ReserveFlags.unwrap(flags) & BORROWABLE_MASK) != 0;
  }

  /// @notice Returns the 'canReceiveShares' flag status.
  /// @param flags The current ReserveFlags.
  /// @return True if the flag is set.
  function canReceiveShares(ReserveFlags flags) internal pure returns (bool) {
    return (ReserveFlags.unwrap(flags) & CAN_RECEIVE_SHARES_MASK) != 0;
  }

  /// @notice Sets the new status for the given flag.
  function _setFlag(uint8 flags, uint8 mask, bool status) internal pure returns (uint8) {
    return status ? flags | mask : flags & ~mask;
  }
}
