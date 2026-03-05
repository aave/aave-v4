// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/position-manager/TakerPositionManager/TakerPositionManager.Base.t.sol';

contract WithdrawAllowanceSimTest is TakerPositionManagerBaseTest {
  function test_withdrawAllowanceMethods_fuzz(
    uint256 supplyAmount,
    uint256 withdrawAmount,
    uint256 timeSkip
  ) public {
    supplyAmount = bound(supplyAmount, 100e18, mintAmount_DAI / 2);
    withdrawAmount = bound(withdrawAmount, 1, supplyAmount / 2);
    timeSkip = bound(timeSkip, 0, 365 days);

    uint256 reserveId = _daiReserveId(spoke1);

    // Alice and Bob supply collateral
    Utils.supplyCollateral(spoke1, reserveId, alice, supplyAmount, alice);
    Utils.supplyCollateral(spoke1, reserveId, bob, supplyAmount, bob);

    // Bob borrows a small amount to create initial debt (so interest accrues on non-zero base)
    uint256 seedBorrow = withdrawAmount / 2;
    if (seedBorrow > 0) {
      Utils.borrow(spoke1, reserveId, bob, seedBorrow, bob);
    }

    // Skip time to accrue interest so addedIndex != RAY
    skip(timeSkip);

    // Alice approves bob to withdraw on her behalf
    vm.prank(alice);
    positionManager.approveWithdraw(address(spoke1), reserveId, bob, withdrawAmount * 10);

    // Snapshot before
    uint256 sharesBefore = spoke1.getUserSuppliedShares(reserveId, alice);

    // Bob withdraws on behalf of alice
    vm.prank(bob);
    (uint256 withdrawnShares, uint256 withdrawnAmount) = positionManager.withdrawOnBehalfOf(
      address(spoke1),
      reserveId,
      withdrawAmount,
      alice
    );

    // Snapshot after
    uint256 sharesAfter = spoke1.getUserSuppliedShares(reserveId, alice);

    // Method A: direct conversion of withdrawnShares to assets (round up)
    uint256 methodA = hub1.previewAddByShares(daiAssetId, withdrawnShares);

    // Method B: before/after delta
    uint256 assetsBefore = hub1.previewAddByShares(daiAssetId, sharesBefore);
    uint256 assetsAfter = hub1.previewAddByShares(daiAssetId, sharesAfter);
    uint256 methodB = assetsBefore - assetsAfter;

    // Log all values
    console.log('--- WithdrawAllowanceSim ---');
    console.log('withdrawnAmount (passthrough):', withdrawnAmount);
    console.log('withdrawnShares:', withdrawnShares);
    console.log('methodA (shares->assets):', methodA);
    console.log('methodB (delta):', methodB);
    console.log('sharesBefore:', sharesBefore);
    console.log('sharesAfter:', sharesAfter);
    console.log('methodA - methodB:', methodA - methodB);
    console.log('methodB >= withdrawnAmount:', methodB >= withdrawnAmount);
    if (methodB >= withdrawnAmount) {
      console.log('methodB - withdrawnAmount:', methodB - withdrawnAmount);
    } else {
      console.log('withdrawnAmount - methodB:', withdrawnAmount - methodB);
    }

    // Core relationship assertions
    assertGe(methodA, methodB, 'methodA < methodB: ceiling of part must >= delta of ceilings');
    assertGe(methodA, withdrawnAmount, 'methodA < withdrawnAmount');
    assertGe(
      methodB,
      withdrawnAmount,
      'methodB < withdrawnAmount: delta should >= actual withdrawn'
    );

    // Bounded divergence
    assertApproxEqAbs(methodA, methodB, 1, 'methodA ~= methodB');
  }
}
