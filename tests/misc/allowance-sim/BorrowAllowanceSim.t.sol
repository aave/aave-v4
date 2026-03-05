// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/position-manager/TakerPositionManager/TakerPositionManager.Base.t.sol';

contract BorrowAllowanceSimTest is TakerPositionManagerBaseTest {
  function test_borrowAllowanceMethods_fuzz(
    uint256 supplyAmount,
    uint256 borrowAmount,
    uint256 timeSkip
  ) public {
    supplyAmount = bound(supplyAmount, 100e18, mintAmount_DAI / 2);
    borrowAmount = bound(borrowAmount, 1, supplyAmount / 2);
    timeSkip = bound(timeSkip, 0, 365 days);

    uint256 reserveId = _daiReserveId(spoke1);

    // Alice and Bob supply collateral
    Utils.supplyCollateral(spoke1, reserveId, alice, supplyAmount, alice);
    Utils.supplyCollateral(spoke1, reserveId, bob, supplyAmount, bob);

    // Bob borrows a small amount to create initial debt (so interest accrues on non-zero base)
    uint256 seedBorrow = borrowAmount / 2;
    if (seedBorrow > 0) {
      Utils.borrow(spoke1, reserveId, bob, seedBorrow, bob);
    }

    // Skip time to accrue interest so drawnIndex != RAY
    skip(timeSkip);

    // Alice approves bob to borrow on her behalf
    vm.prank(alice);
    positionManager.approveBorrow(address(spoke1), reserveId, bob, borrowAmount * 10);

    // Snapshot before
    uint256 sharesBefore = spoke1.getUserPosition(reserveId, alice).drawnShares;
    uint256 drawnIndexBefore = hub1.getAssetDrawnIndex(daiAssetId);

    // Bob borrows on behalf of alice
    vm.prank(bob);
    (uint256 borrowedShares, uint256 borrowedAmount) = positionManager.borrowOnBehalfOf(
      address(spoke1),
      reserveId,
      borrowAmount,
      alice
    );

    // Snapshot after
    uint256 sharesAfter = spoke1.getUserPosition(reserveId, alice).drawnShares;

    // Method A: direct conversion of borrowedShares to assets (round up)
    uint256 methodA = hub1.previewRestoreByShares(daiAssetId, borrowedShares);

    // Method B: before/after delta
    uint256 assetsBefore = hub1.previewRestoreByShares(daiAssetId, sharesBefore);
    uint256 assetsAfter = hub1.previewRestoreByShares(daiAssetId, sharesAfter);
    uint256 methodB = assetsAfter - assetsBefore;

    // Log all values
    console.log('--- BorrowAllowanceSim ---');
    console.log('borrowedAmount (passthrough):', borrowedAmount);
    console.log('borrowedShares:', borrowedShares);
    console.log('methodA (shares->assets):', methodA);
    console.log('methodB (delta):', methodB);
    console.log('drawnIndex before:', drawnIndexBefore);
    console.log('sharesBefore:', sharesBefore);
    console.log('sharesAfter:', sharesAfter);
    console.log('methodA == borrowedAmount:', methodA == borrowedAmount);
    console.log('methodB == borrowedAmount:', methodB == borrowedAmount);

    // Assert: methodA should equal methodB (ray-based math is exact)
    assertEq(methodA, methodB, 'methodA != methodB');

    // Relationship assertions (matching withdraw sim pattern)
    assertGe(methodA, methodB, 'methodA < methodB');
    assertGe(methodA, borrowedAmount, 'methodA < borrowedAmount');
    assertGe(methodB, borrowedAmount, 'methodB < borrowedAmount');
  }
}
