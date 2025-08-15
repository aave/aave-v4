// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

type ReserveFlags is uint8;

import {DataTypes} from 'src/libraries/types/DataTypes.sol';

library ReserveFlagsLib {
  using ReserveFlagsLib for ReserveFlags;

  uint8 constant PAUSED_MASK = 1 << 0;
  uint8 constant FROZEN_MASK = 1 << 1;
  uint8 constant BORROWABLE_MASK = 1 << 2;

  function get(
    ReserveFlags flags
  ) internal pure returns (bool paused, bool frozen, bool borrowable) {
    return (isPaused(flags), isFrozen(flags), isBorrowable(flags));
  }

  function isPaused(ReserveFlags flags) internal pure returns (bool) {
    return (ReserveFlags.unwrap(flags) & PAUSED_MASK) != 0;
  }

  function isFrozen(ReserveFlags flags) internal pure returns (bool) {
    return (ReserveFlags.unwrap(flags) & FROZEN_MASK) != 0;
  }

  function isBorrowable(ReserveFlags flags) internal pure returns (bool) {
    return (ReserveFlags.unwrap(flags) & BORROWABLE_MASK) != 0;
  }

  function toReserveFlags(
    DataTypes.ReserveConfig memory config
  ) internal pure returns (ReserveFlags) {
    return
      ReserveFlags.wrap(
        (config.paused ? PAUSED_MASK : 0) |
          (config.frozen ? FROZEN_MASK : 0) |
          (config.borrowable ? BORROWABLE_MASK : 0)
      );
  }
}
