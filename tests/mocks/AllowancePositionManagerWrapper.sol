// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {TransientSlot} from 'src/dependencies/openzeppelin/TransientSlot.sol';
import {AllowancePositionManager} from 'src/position-manager/AllowancePositionManager.sol';

contract AllowancePositionManagerWrapper is AllowancePositionManager {
  using TransientSlot for *;

  constructor(address spoke_) AllowancePositionManager(spoke_) {}

  function temporaryWithdrawAllowance(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender
  ) external view returns (uint256) {
    return
      _temporaryWithdrawAllowancesSlot({
        spoke: spoke,
        reserveId: reserveId,
        owner: owner,
        spender: spender
      }).tload();
  }

  function temporaryCreditDelegation(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender
  ) external view returns (uint256) {
    return
      _temporaryDelegateCreditsSlot({
        spoke: spoke,
        reserveId: reserveId,
        owner: owner,
        spender: spender
      }).tload();
  }
}
