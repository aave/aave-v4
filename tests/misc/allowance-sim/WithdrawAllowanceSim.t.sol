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

    Utils.supplyCollateral(spoke1, reserveId, alice, supplyAmount, alice);
    Utils.supplyCollateral(spoke1, reserveId, bob, supplyAmount, bob);
    uint256 seedBorrow = withdrawAmount / 2;
    if (seedBorrow > 0) {
      Utils.borrow(spoke1, reserveId, bob, seedBorrow, bob);
    }

    skip(timeSkip);

    vm.prank(alice);
    positionManager.approveWithdraw(address(spoke1), reserveId, bob, withdrawAmount * 10);

    uint256 assetsBefore = hub1.previewAddByShares(
      daiAssetId,
      spoke1.getUserSuppliedShares(reserveId, alice)
    );
    uint256 assetsBefore2 = ISpokeBase(spoke1).getUserSuppliedAssets(reserveId, alice);

    // Method D : convert input amount to shares then back to amount
    uint256 methodD = hub1.previewAddByShares(
      daiAssetId,
      hub1.previewAddByAssets(daiAssetId, withdrawAmount)
    );

    vm.prank(bob);
    (uint256 withdrawnShares, uint256 withdrawnAmount) = positionManager.withdrawOnBehalfOf(
      address(spoke1),
      reserveId,
      withdrawAmount,
      alice
    );

    // Method A: direct conversion of withdrawnShares to assets (round up)
    uint256 methodA = hub1.previewAddByShares(daiAssetId, withdrawnShares);

    // Method B: before/after shares delta
    uint256 assetsAfter = hub1.previewAddByShares(
      daiAssetId,
      spoke1.getUserSuppliedShares(reserveId, alice)
    );
    uint256 methodB = assetsBefore - assetsAfter;

    // Method C: before/after assets delta in user position
    uint256 methodC = assetsBefore2 - ISpokeBase(spoke1).getUserSuppliedAssets(reserveId, alice);

    // Core relationship assertions
    assertGe(methodA, methodB, 'methodA < methodB: ceiling of part must >= delta of ceilings');
    assertGe(methodB, methodC, 'methodB < methodC: delta of ceilings must >= delta of actual');
    assertGe(methodA, methodC, 'methodA < methodC: ceiling of part must >= delta of actual');
    assertGe(methodA, methodD, 'methodA < methodD: ceiling of part must >= ceiling of whole');
    assertGe(methodB, methodD, 'methodB < methodD: delta of ceilings must >= ceiling of whole');
    assertGe(methodC, methodD, 'methodC < methodD: delta of actual must >= ceiling of whole');

    assertGe(methodA, withdrawnAmount, 'methodA < withdrawnAmount');
    assertGe(
      methodB,
      withdrawnAmount,
      'methodB < withdrawnAmount: delta should >= actual withdrawn'
    );
    assertGe(
      methodC,
      withdrawnAmount,
      'methodC < withdrawnAmount: delta of actual should >= actual withdrawn'
    );
    assertGe(
      methodD,
      withdrawnAmount,
      'methodD < withdrawnAmount: ceiling of whole should >= actual withdrawn'
    );

    // Bounded divergence
    assertApproxEqAbs(methodA, methodB, 2, 'methodA ~= methodB');
    assertApproxEqAbs(methodA, methodC, 2, 'methodA ~= methodC');
    assertApproxEqAbs(methodB, methodC, 1, 'methodB ~= methodC');
    assertApproxEqAbs(methodA, methodD, 2, 'methodA ~= methodD');
    assertApproxEqAbs(methodB, methodD, 1, 'methodB ~= methodD');
    assertApproxEqAbs(methodC, methodD, 1, 'methodC ~= methodD');
  }
}
