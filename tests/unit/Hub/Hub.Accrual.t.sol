// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubAccrualTest is HubBase {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using MathUtils for uint256;

  uint256 constant SUPPLY_AMOUNT = 1000e18;
  uint256 constant BORROW_AMOUNT = 500e18;

  /// @dev Fuzz test for basic fee accrual with varying supply, borrow, fee, and time
  function test_accrual_fuzz_basicAccrual(
    uint256 supplyAmount,
    uint256 borrowAmount,
    uint256 liquidityFee,
    uint256 skipTime
  ) public {
    supplyAmount = bound(supplyAmount, 2, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, supplyAmount / 2);
    liquidityFee = bound(liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    uint256 bobShares = Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: supplyAmount,
      user: bob
    });
    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: bob,
      caller: address(spoke1),
      amount: borrowAmount
    });

    uint256 totalAssetsBefore = hub1.getAddedAssets(daiAssetId);
    uint256 bobAssetsBefore = hub1.previewRemoveByShares(daiAssetId, bobShares);
    assertEq(bobAssetsBefore, supplyAmount);

    uint256 treasuryAssetsBefore = _getFeeReceiverAddedAssets(hub1, daiAssetId);
    assertEq(treasuryAssetsBefore, 0);

    uint96 drawnRate = hub1.getAsset(daiAssetId).drawnRate;
    uint40 startTime = uint40(block.timestamp);

    skip(skipTime);

    uint256 totalInterest;
    uint256 accruedFees;
    uint256 expectedTotalInterest;
    {
      uint256 expectedTotalDebt = _calculateExpectedTotalDebt(
        borrowAmount,
        drawnRate,
        startTime,
        0
      );
      expectedTotalInterest = expectedTotalDebt - borrowAmount;
      uint256 totalDebt = hub1.getAssetTotalOwed(daiAssetId);
      totalInterest = totalDebt - borrowAmount;
      assertEq(totalInterest, expectedTotalInterest);

      accruedFees = _getFeeReceiverAddedAssets(hub1, daiAssetId);
    }

    uint256 totalAssetsAfter = hub1.getAddedAssets(daiAssetId);
    assertApproxEqAbs(
      totalAssetsAfter,
      totalAssetsBefore + totalInterest,
      1,
      'total added assets = initial + all interest'
    );

    uint256 bobAssetsAfter = hub1.previewRemoveByShares(daiAssetId, bobShares);
    assertGe(bobAssetsAfter, bobAssetsBefore, 'bob assets increased');
    assertLe(accruedFees, totalInterest, 'fees do not exceed total interest');

    {
      assertApproxEqAbs(
        totalInterest,
        totalAssetsAfter - totalAssetsBefore,
        1,
        'total growth in supply matches total growth in debt'
      );

      assertApproxEqAbs(
        _getFeeReceiverAddedAssets(hub1, daiAssetId),
        expectedTotalInterest.percentMulDown(liquidityFee),
        2,
        'treasury spoke assets match expected fee split'
      );

      uint256 supplierInterest = totalInterest - accruedFees;
      uint256 expectedBobGrowth = supplierInterest.mulDivDown(
        bobShares,
        bobShares + SharesMath.VIRTUAL_SHARES
      );
      assertApproxEqAbs(
        bobAssetsAfter - bobAssetsBefore,
        expectedBobGrowth,
        1,
        'bob growth (supplier) matches expected fee split'
      );
    }
  }

  /// @dev Verifies protocol cut rounds to 0 when interest is tiny, all goes to suppliers
  function test_accrual_roundsToZero() public {
    uint256 liquidityFee = 1_00; // 1%
    uint256 drawnAmount = 100;

    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    Utils.add({hub: hub1, assetId: daiAssetId, caller: address(spoke1), amount: 1000, user: bob});

    uint256 initialSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);

    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: bob,
      caller: address(spoke1),
      amount: drawnAmount
    });

    skip(1 hours);

    (uint256 drawnDebt, ) = hub1.getAssetOwed(daiAssetId);
    uint256 delta = drawnDebt - drawnAmount;
    uint256 accruedFees = _getFeeReceiverAddedAssets(hub1, daiAssetId);
    uint256 finalSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);

    assertEq(delta.percentMulDown(liquidityFee), 0);
    assertEq(accruedFees, 0);
    assertEq(_calcUnrealizedFees(hub1, daiAssetId), 0);
    assertGt(delta, 0);
    _checkSupplyRateIncreasing(initialSharePrice, finalSharePrice, 'share price');
  }

  /// @dev Tests that when fees round to 0 shares, they accumulate in realizedFees, until they exceed 1 share.
  function test_accrual_realizedFeesAccumulation() public {
    uint256 liquidityFee = 50_00;
    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    // Inflate share price
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: 1000e18,
      user: bob
    });
    Utils.draw({hub: hub1, assetId: daiAssetId, to: bob, caller: address(spoke1), amount: 500e18});

    skip(5 * 365 days);
    Utils.add({hub: hub1, assetId: daiAssetId, caller: address(spoke1), amount: 1e18, user: bob});

    (uint256 currentDebt, ) = hub1.getAssetOwed(daiAssetId);
    Utils.restoreDrawn({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      drawnAmount: currentDebt,
      restorer: bob
    });

    // Debt is cleared and share price inflated
    (uint256 debtAfterRepay, ) = hub1.getAssetOwed(daiAssetId);
    assertEq(debtAfterRepay, 0, 'debt is 0');
    uint256 sharePrice = hub1.previewAddByShares(daiAssetId, 1e18);
    assertGt(sharePrice, 1e18, 'share price > 1');

    // Small accrual where feeShares round to 0
    Utils.draw({hub: hub1, assetId: daiAssetId, to: bob, caller: address(spoke1), amount: 1e8});

    uint256 treasurySharesBefore = _getFeeReceiverAddedShares(hub1, daiAssetId);

    skip(25 seconds);
    Utils.add({hub: hub1, assetId: daiAssetId, caller: address(spoke1), amount: 1e15, user: bob});

    IHub.Asset memory assetAfterFirst = hub1.getAsset(daiAssetId);
    assertGt(assetAfterFirst.realizedFees, 0, 'realizedFees accumulated');
    assertEq(
      _getFeeReceiverAddedShares(hub1, daiAssetId),
      treasurySharesBefore,
      'no new fee shares'
    );

    // Second accrual causes realizedFees to become greater than 1 share, minting fee shares, and resetting realizedFees
    skip(1 days);
    Utils.add({hub: hub1, assetId: daiAssetId, caller: address(spoke1), amount: 1e15, user: bob});

    uint256 treasurySharesAfterSecond = _getFeeReceiverAddedShares(hub1, daiAssetId);
    assertGt(treasurySharesAfterSecond, treasurySharesBefore, 'shares minted');
    IHub.Asset memory assetAfterSecond = hub1.getAsset(daiAssetId);
    assertEq(assetAfterSecond.realizedFees, 0, 'realizedFees reset');
  }

  /// @dev Tests that when fees exceed 1 share worth, the fractional remainder is donated to suppliers.
  /// @dev If feeAmount = 1.2 shares worth, mint 1 share, remainder (0.2) goes to suppliers.
  function test_accrual_fractionalFeeRemainderDonatedToSuppliers() public {
    uint256 liquidityFee = 50_00;
    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    // Inflate share price
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: 1000e18,
      user: bob
    });
    Utils.draw({hub: hub1, assetId: daiAssetId, to: bob, caller: address(spoke1), amount: 500e18});

    skip(5 * 365 days);
    Utils.add({hub: hub1, assetId: daiAssetId, caller: address(spoke1), amount: 1e18, user: bob});

    (uint256 currentDebt, ) = hub1.getAssetOwed(daiAssetId);
    Utils.restoreDrawn({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      drawnAmount: currentDebt,
      restorer: bob
    });

    // Accrue interest
    Utils.draw({hub: hub1, assetId: daiAssetId, to: bob, caller: address(spoke1), amount: 1e8});

    uint256 treasurySharesBefore = _getFeeReceiverAddedShares(hub1, daiAssetId);
    uint256 totalAddedAssetsBefore = hub1.getAddedAssets(daiAssetId);

    skip(45 seconds);

    uint256 expectedFeeAmount = _calcUnrealizedFees(hub1, daiAssetId);
    assertGt(expectedFeeAmount, 0, 'has unrealized fees');

    // Expected fee amount is not perfect share amount
    uint256 expectedMintedShares = hub1.previewAddByAssets(daiAssetId, expectedFeeAmount);
    uint256 expectedMintedAssets = hub1.previewRemoveByShares(daiAssetId, expectedMintedShares);
    assertLt(expectedMintedAssets, expectedFeeAmount, 'fee not perfect share amount');

    // Trigger accrual
    Utils.add({hub: hub1, assetId: daiAssetId, caller: address(spoke1), amount: 1e15, user: bob});

    uint256 treasurySharesAfter = _getFeeReceiverAddedShares(hub1, daiAssetId);
    uint256 sharesMinted = treasurySharesAfter - treasurySharesBefore;

    // Perfect fee share amount was minted, but rest of fees were donated
    assertGt(sharesMinted, 0, 'fee shares minted');
    IHub.Asset memory assetAfter = hub1.getAsset(daiAssetId);
    assertEq(assetAfter.realizedFees, 0, 'realizedFees reset');

    // Total added assets increased appropriately (about twice expectedFeeAmount since liquidityFee = 50%)
    uint256 totalAddedAssetsAfter = hub1.getAddedAssets(daiAssetId);
    // Account for the 1e15 that bob just added
    uint256 totalAddedAssetsIncrease = totalAddedAssetsAfter - totalAddedAssetsBefore - 1e15;
    assertApproxEqAbs(
      totalAddedAssetsIncrease,
      expectedFeeAmount * 2,
      1,
      'total added assets increased correctly'
    );
  }
}
