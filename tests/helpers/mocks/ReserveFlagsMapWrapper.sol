// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {ReserveFlags, ReserveFlagsMap} from 'src/spoke/libraries/ReserveFlagsMap.sol';

contract ReserveFlagsMapWrapper {
  using ReserveFlagsMap for ReserveFlags;

  function create(
    bool initPaused,
    bool initFrozen,
    bool initBorrowable,
    bool initReceiveSharesEnabled
  ) external pure returns (ReserveFlags) {
    return
      ReserveFlagsMap.create({
        initPaused: initPaused,
        initFrozen: initFrozen,
        initBorrowable: initBorrowable,
        initReceiveSharesEnabled: initReceiveSharesEnabled
      });
  }

  function setPaused(ReserveFlags flags, bool status) external pure returns (ReserveFlags) {
    return ReserveFlagsMap.setPaused(flags, status);
  }

  function setFrozen(ReserveFlags flags, bool status) external pure returns (ReserveFlags) {
    return ReserveFlagsMap.setFrozen(flags, status);
  }

  function setBorrowable(ReserveFlags flags, bool status) external pure returns (ReserveFlags) {
    return ReserveFlagsMap.setBorrowable(flags, status);
  }

  function setReceiveSharesEnabled(
    ReserveFlags flags,
    bool status
  ) external pure returns (ReserveFlags) {
    return ReserveFlagsMap.setReceiveSharesEnabled(flags, status);
  }

  function paused(ReserveFlags flags) external pure returns (bool) {
    return ReserveFlagsMap.paused(flags);
  }

  function frozen(ReserveFlags flags) external pure returns (bool) {
    return ReserveFlagsMap.frozen(flags);
  }

  function borrowable(ReserveFlags flags) external pure returns (bool) {
    return ReserveFlagsMap.borrowable(flags);
  }

  function receiveSharesEnabled(ReserveFlags flags) external pure returns (bool) {
    return ReserveFlagsMap.receiveSharesEnabled(flags);
  }

  function PAUSED_MASK() external pure returns (uint8) {
    return ReserveFlagsMap.PAUSED_MASK;
  }

  function FROZEN_MASK() external pure returns (uint8) {
    return ReserveFlagsMap.FROZEN_MASK;
  }

  function BORROWABLE_MASK() external pure returns (uint8) {
    return ReserveFlagsMap.BORROWABLE_MASK;
  }

  function RECEIVE_SHARES_ENABLED_MASK() external pure returns (uint8) {
    return ReserveFlagsMap.RECEIVE_SHARES_ENABLED_MASK;
  }
}
