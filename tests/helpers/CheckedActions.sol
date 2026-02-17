// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke, ISpokeBase} from 'src/spoke/interfaces/ISpoke.sol';
import {Utils} from 'tests/Utils.sol';
import {SnapshotHelpers} from 'tests/helpers/SnapshotHelpers.sol';

/// @title CheckedActions
/// @notice Composite helpers that encapsulate setup-act-assert for common operations.
/// Each helper snapshots state, executes the action, and asserts basic invariants.
abstract contract CheckedActions is SnapshotHelpers {
  struct CheckedSupplyParams {
    ISpoke spoke;
    uint256 reserveId;
    address user;
    uint256 amount;
    address onBehalfOf;
  }

  struct CheckedSupplyResult {
    UserSnapshot userBefore;
    UserSnapshot userAfter;
    ReserveSnapshot reserveBefore;
    ReserveSnapshot reserveAfter;
  }

  struct CheckedWithdrawParams {
    ISpoke spoke;
    uint256 reserveId;
    address user;
    uint256 amount;
    address onBehalfOf;
  }

  struct CheckedWithdrawResult {
    UserSnapshot userBefore;
    UserSnapshot userAfter;
    ReserveSnapshot reserveBefore;
    ReserveSnapshot reserveAfter;
  }

  struct CheckedBorrowParams {
    ISpoke spoke;
    uint256 reserveId;
    address user;
    uint256 amount;
    address onBehalfOf;
  }

  struct CheckedBorrowResult {
    UserSnapshot userBefore;
    UserSnapshot userAfter;
    ReserveSnapshot reserveBefore;
    ReserveSnapshot reserveAfter;
  }

  struct CheckedRepayParams {
    ISpoke spoke;
    uint256 reserveId;
    address user;
    uint256 amount;
    address onBehalfOf;
  }

  struct CheckedRepayResult {
    uint256 baseRestored;
    uint256 premiumRestored;
    UserSnapshot userBefore;
    UserSnapshot userAfter;
    ReserveSnapshot reserveBefore;
    ReserveSnapshot reserveAfter;
  }

  function _checkedSupply(
    CheckedSupplyParams memory params
  ) internal returns (CheckedSupplyResult memory result) {
    result.userBefore = _snapshotUser(params.spoke, params.reserveId, params.onBehalfOf);
    result.reserveBefore = _snapshotReserve(params.spoke, params.reserveId);

    Utils.supply(params.spoke, params.reserveId, params.user, params.amount, params.onBehalfOf);

    result.userAfter = _snapshotUser(params.spoke, params.reserveId, params.onBehalfOf);
    result.reserveAfter = _snapshotReserve(params.spoke, params.reserveId);

    // Basic invariants
    assertGe(
      result.userAfter.suppliedShares,
      result.userBefore.suppliedShares,
      'checkedSupply: shares should increase'
    );
    assertGe(
      result.reserveAfter.totalSuppliedAmount,
      result.reserveBefore.totalSuppliedAmount,
      'checkedSupply: reserve supply should increase'
    );
  }

  function _checkedWithdraw(
    CheckedWithdrawParams memory params
  ) internal returns (CheckedWithdrawResult memory result) {
    result.userBefore = _snapshotUser(params.spoke, params.reserveId, params.onBehalfOf);
    result.reserveBefore = _snapshotReserve(params.spoke, params.reserveId);

    Utils.withdraw(params.spoke, params.reserveId, params.user, params.amount, params.onBehalfOf);

    result.userAfter = _snapshotUser(params.spoke, params.reserveId, params.onBehalfOf);
    result.reserveAfter = _snapshotReserve(params.spoke, params.reserveId);

    // Basic invariants
    assertLe(
      result.userAfter.suppliedShares,
      result.userBefore.suppliedShares,
      'checkedWithdraw: shares should decrease'
    );
    assertLe(
      result.reserveAfter.totalSuppliedAmount,
      result.reserveBefore.totalSuppliedAmount,
      'checkedWithdraw: reserve supply should decrease'
    );
  }

  function _checkedBorrow(
    CheckedBorrowParams memory params
  ) internal returns (CheckedBorrowResult memory result) {
    result.userBefore = _snapshotUser(params.spoke, params.reserveId, params.onBehalfOf);
    result.reserveBefore = _snapshotReserve(params.spoke, params.reserveId);

    Utils.borrow(params.spoke, params.reserveId, params.user, params.amount, params.onBehalfOf);

    result.userAfter = _snapshotUser(params.spoke, params.reserveId, params.onBehalfOf);
    result.reserveAfter = _snapshotReserve(params.spoke, params.reserveId);

    // Basic invariants
    assertGe(
      result.userAfter.totalDebt,
      result.userBefore.totalDebt,
      'checkedBorrow: user debt should increase'
    );
    assertGe(
      result.reserveAfter.totalDebt,
      result.reserveBefore.totalDebt,
      'checkedBorrow: reserve debt should increase'
    );
  }

  function _checkedRepay(
    CheckedRepayParams memory params
  ) internal returns (CheckedRepayResult memory result) {
    result.userBefore = _snapshotUser(params.spoke, params.reserveId, params.onBehalfOf);
    result.reserveBefore = _snapshotReserve(params.spoke, params.reserveId);

    (result.baseRestored, result.premiumRestored) = _calculateExactRestoreAmount(
      params.spoke,
      params.reserveId,
      params.onBehalfOf,
      params.amount
    );

    Utils.repay(params.spoke, params.reserveId, params.user, params.amount, params.onBehalfOf);

    result.userAfter = _snapshotUser(params.spoke, params.reserveId, params.onBehalfOf);
    result.reserveAfter = _snapshotReserve(params.spoke, params.reserveId);

    // Basic invariants
    assertLe(
      result.userAfter.totalDebt,
      result.userBefore.totalDebt,
      'checkedRepay: user debt should decrease'
    );
    assertLe(
      result.reserveAfter.totalDebt,
      result.reserveBefore.totalDebt,
      'checkedRepay: reserve debt should decrease'
    );
  }
}
