// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {SpokeActions} from 'tests/helpers/spoke/SpokeActions.sol';
import {MathHelpers} from 'tests/helpers/spoke/MathHelpers.sol';

/// @title CheckedActions
/// @notice Composite helpers that encapsulate setup-act-assert for common operations.
/// Each helper snapshots state, executes the action, and asserts basic invariants.
abstract contract CheckedActions is MathHelpers {
  struct CheckedSupplyParams {
    ISpoke spoke;
    uint256 reserveId;
    address user;
    uint256 amount;
    address onBehalfOf;
  }

  struct CheckedSupplyResult {
    uint256 shares;
    uint256 amount;
    UserSnapshot callerBefore;
    UserSnapshot callerAfter;
    UserSnapshot ownerBefore;
    UserSnapshot ownerAfter;
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
    uint256 shares;
    uint256 amount;
    UserSnapshot callerBefore;
    UserSnapshot callerAfter;
    UserSnapshot ownerBefore;
    UserSnapshot ownerAfter;
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
    uint256 shares;
    uint256 amount;
    UserSnapshot callerBefore;
    UserSnapshot callerAfter;
    UserSnapshot ownerBefore;
    UserSnapshot ownerAfter;
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
    uint256 shares;
    uint256 amount;
    uint256 baseRestored;
    uint256 premiumRestored;
    UserSnapshot callerBefore;
    UserSnapshot callerAfter;
    UserSnapshot ownerBefore;
    UserSnapshot ownerAfter;
    ReserveSnapshot reserveBefore;
    ReserveSnapshot reserveAfter;
  }

  struct CheckedSupplyCollateralParams {
    ISpoke spoke;
    uint256 reserveId;
    address user;
    uint256 amount;
    address onBehalfOf;
  }

  function _checkedSupply(
    CheckedSupplyParams memory params
  ) internal returns (CheckedSupplyResult memory result) {
    result.callerBefore = _snapshotUser(params.spoke, params.reserveId, params.user);
    result.ownerBefore = _snapshotUser(params.spoke, params.reserveId, params.onBehalfOf);
    result.reserveBefore = _snapshotReserve(params.spoke, params.reserveId);

    vm.prank(params.user);
    (result.shares, result.amount) = params.spoke.supply(
      params.reserveId,
      params.amount,
      params.onBehalfOf
    );

    result.callerAfter = _snapshotUser(params.spoke, params.reserveId, params.user);
    result.ownerAfter = _snapshotUser(params.spoke, params.reserveId, params.onBehalfOf);
    result.reserveAfter = _snapshotReserve(params.spoke, params.reserveId);

    // Basic invariants
    assertGe(
      result.ownerAfter.suppliedShares,
      result.ownerBefore.suppliedShares,
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
    result.callerBefore = _snapshotUser(params.spoke, params.reserveId, params.user);
    result.ownerBefore = _snapshotUser(params.spoke, params.reserveId, params.onBehalfOf);
    result.reserveBefore = _snapshotReserve(params.spoke, params.reserveId);

    vm.prank(params.user);
    (result.shares, result.amount) = params.spoke.withdraw(
      params.reserveId,
      params.amount,
      params.onBehalfOf
    );

    result.callerAfter = _snapshotUser(params.spoke, params.reserveId, params.user);
    result.ownerAfter = _snapshotUser(params.spoke, params.reserveId, params.onBehalfOf);
    result.reserveAfter = _snapshotReserve(params.spoke, params.reserveId);

    // Basic invariants
    assertLe(
      result.ownerAfter.suppliedShares,
      result.ownerBefore.suppliedShares,
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
    result.callerBefore = _snapshotUser(params.spoke, params.reserveId, params.user);
    result.ownerBefore = _snapshotUser(params.spoke, params.reserveId, params.onBehalfOf);
    result.reserveBefore = _snapshotReserve(params.spoke, params.reserveId);

    vm.prank(params.user);
    (result.shares, result.amount) = params.spoke.borrow(
      params.reserveId,
      params.amount,
      params.onBehalfOf
    );

    result.callerAfter = _snapshotUser(params.spoke, params.reserveId, params.user);
    result.ownerAfter = _snapshotUser(params.spoke, params.reserveId, params.onBehalfOf);
    result.reserveAfter = _snapshotReserve(params.spoke, params.reserveId);

    // Basic invariants
    assertGe(
      result.ownerAfter.totalDebt,
      result.ownerBefore.totalDebt,
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
    result.callerBefore = _snapshotUser(params.spoke, params.reserveId, params.user);
    result.ownerBefore = _snapshotUser(params.spoke, params.reserveId, params.onBehalfOf);
    result.reserveBefore = _snapshotReserve(params.spoke, params.reserveId);

    (result.baseRestored, result.premiumRestored) = _calculateExactRestoreAmount(
      params.spoke,
      params.reserveId,
      params.onBehalfOf,
      params.amount
    );

    vm.prank(params.user);
    (result.shares, result.amount) = params.spoke.repay(
      params.reserveId,
      params.amount,
      params.onBehalfOf
    );

    result.callerAfter = _snapshotUser(params.spoke, params.reserveId, params.user);
    result.ownerAfter = _snapshotUser(params.spoke, params.reserveId, params.onBehalfOf);
    result.reserveAfter = _snapshotReserve(params.spoke, params.reserveId);

    // Basic invariants
    assertLe(
      result.ownerAfter.totalDebt,
      result.ownerBefore.totalDebt,
      'checkedRepay: user debt should decrease'
    );
    assertLe(
      result.reserveAfter.totalDebt,
      result.reserveBefore.totalDebt,
      'checkedRepay: reserve debt should decrease'
    );
  }

  function _checkedSupplyCollateral(
    CheckedSupplyCollateralParams memory params
  ) internal returns (CheckedSupplyResult memory result) {
    result = _checkedSupply(
      CheckedSupplyParams({
        spoke: params.spoke,
        reserveId: params.reserveId,
        user: params.user,
        amount: params.amount,
        onBehalfOf: params.onBehalfOf
      })
    );
    SpokeActions.setUsingAsCollateral({
      spoke: params.spoke,
      reserveId: params.reserveId,
      caller: params.user,
      usingAsCollateral: true,
      onBehalfOf: params.onBehalfOf
    });
  }
}
