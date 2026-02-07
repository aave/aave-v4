// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeAccrueLiquidityFeeEdgeCasesTest is SpokeBase {
  uint256 public constant MAX_LIQUIDITY_FEE = 100_00;

  /// @dev Max liquidity fee with premium debt accrual
  function test_accrueLiquidityFee_maxLiquidityFee_with_premium() public {
    test_accrueLiquidityFee_fuzz_maxLiquidityFee_with_premium({
      reserveId: _daiReserveId(spoke1),
      borrowAmount: 500e18,
      skipTime: 400 days,
      rate: 50_00
    });
  }

  /// @dev Fuzz - max liquidity fee with premium debt accrual
  function test_accrueLiquidityFee_fuzz_maxLiquidityFee_with_premium(
    uint256 reserveId,
    uint256 borrowAmount,
    uint256 skipTime,
    uint256 rate
  ) public {
    rate = bound(rate, 1, MAX_BORROW_RATE);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    uint256 assetId = spoke1.getReserve(reserveId).assetId;

    borrowAmount = bound(borrowAmount, 1, _calculateMaxSupplyAmount(spoke1, reserveId) / 2); // within collateralization

    updateLiquidityFee(hub1, assetId, MAX_LIQUIDITY_FEE);

    uint256 supplyAmount = _calcMinimumCollAmount(spoke1, reserveId, reserveId, borrowAmount);
    _mockInterestRateBps(rate);

    Utils.supplyCollateral(spoke1, reserveId, alice, supplyAmount, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    skip(skipTime);

    // fees accrued before mintFeeShares
    uint256 accruedFees = hub1.getAssetAccruedFees(assetId);

    Utils.mintFeeShares(hub1, assetId, ADMIN);

    (, uint256 premiumDebt) = spoke1.getUserDebt(reserveId, alice);
    assertGt(premiumDebt, 0);

    // With 100% fee, LPs should not earn anything
    assertApproxEqAbs(
      spoke1.getUserSuppliedAssets(reserveId, alice),
      supplyAmount,
      3,
      'alice does not earn anything'
    );

    // getSpokeTotalOwed uses drawn + premium (each fromRayUp),
    // fee calculation uses aggregatedOwed (single fromRayUp on sum).
    // Since fromRayUp(a) + fromRayUp(b) >= fromRayUp(a+b), expectedFees >= accruedFees
    uint256 expectedFees = hub1.getSpokeTotalOwed(assetId, address(spoke1)) - borrowAmount;
    assertGe(expectedFees, accruedFees, 'spoke owed >= accrued fees');
    assertApproxEqAbs(accruedFees, expectedFees, 1, 'fees == total spoke accrued');

    // Treasury share value should approximately equal fees (with share conversion rounding)
    assertApproxEqAbs(
      hub1.getSpokeAddedAssets(assetId, address(treasurySpoke)),
      accruedFees,
      3,
      'treasury shares == accrued fees'
    );
  }

  /// @dev Fuzz - max liquidity fee with premium debt accrual for multiple users
  function test_accrueLiquidityFee_fuzz_maxLiquidityFee_with_premium_multiple_users(
    uint256 reserveId,
    uint256 borrowAmount,
    uint256 borrowAmount2,
    uint256 skipTime,
    uint256 rate
  ) public {
    rate = bound(rate, 1, MAX_BORROW_RATE);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    uint256 assetId = spoke1.getReserve(reserveId).assetId;
    borrowAmount = bound(borrowAmount, 1, _calculateMaxSupplyAmount(spoke1, reserveId) / 4); // within collateralization
    borrowAmount2 = bound(borrowAmount2, 1, _calculateMaxSupplyAmount(spoke1, reserveId) / 4); // within collateralization

    updateLiquidityFee(hub1, spoke1.getReserve(reserveId).assetId, MAX_LIQUIDITY_FEE);

    uint256 supplyAmount = _calcMinimumCollAmount(spoke1, reserveId, reserveId, borrowAmount);
    uint256 supplyAmount2 = _calcMinimumCollAmount(spoke1, reserveId, reserveId, borrowAmount2);
    _mockInterestRateBps(rate);

    Utils.supplyCollateral(spoke1, reserveId, alice, supplyAmount, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    Utils.supplyCollateral(spoke1, reserveId, bob, supplyAmount2, bob);
    Utils.borrow(spoke1, reserveId, bob, borrowAmount2, bob);

    skip(skipTime);

    // fees accrued before mintFeeShares
    uint256 accruedFees = hub1.getAssetAccruedFees(assetId);

    Utils.mintFeeShares(hub1, assetId, ADMIN);

    // With 100% fee, LPs should not earn anything
    assertApproxEqAbs(
      spoke1.getUserSuppliedAssets(reserveId, alice),
      supplyAmount,
      3,
      'alice does not earn anything'
    );
    assertApproxEqAbs(
      spoke1.getUserSuppliedAssets(reserveId, bob),
      supplyAmount2,
      3,
      'bob does not earn anything'
    );

    // getSpokeTotalOwed uses drawn + premium (each fromRayUp),
    // fee calculation uses aggregatedOwed (single fromRayUp on sum).
    // Since fromRayUp(a) + fromRayUp(b) >= fromRayUp(a+b), expectedFees >= accruedFees
    uint256 expectedFees = hub1.getSpokeTotalOwed(assetId, address(spoke1)) -
      borrowAmount -
      borrowAmount2;
    assertGe(expectedFees, accruedFees, 'spoke owed >= accrued fees');
    assertApproxEqAbs(accruedFees, expectedFees, 1, 'fees == total spoke accrued');

    // Treasury share value should approximately equal fees (with share conversion rounding)
    assertApproxEqAbs(
      hub1.getSpokeAddedAssets(assetId, address(treasurySpoke)),
      accruedFees,
      3,
      'treasury shares == accrued fees'
    );
  }

  function test_accrueLiquidityFee_maxLiquidityFee_multi_user() public {
    uint256 reserveId = _randomReserveId(spoke1);
    uint256 assetId = spoke1.getReserve(reserveId).assetId;
    updateLiquidityFee(hub1, assetId, MAX_LIQUIDITY_FEE);

    uint256 count = vm.randomUint(10, 1000);
    for (uint256 i; i < count; ++i) {
      address user = makeUser(i);
      uint256 borrowAmount = vm.randomUint(1, _calculateMaxSupplyAmount(spoke1, reserveId) / count);
      _backedBorrow(spoke1, user, reserveId, reserveId, borrowAmount);
    }

    skip(vm.randomUint(1, MAX_SKIP_TIME));

    for (uint256 i; i < count; ++i) {
      address user = makeUser(i); // deterministic operation
      Utils.repay(spoke1, reserveId, user, 1, user); // accrue interest & realize premium

      uint256 feesAccrued = hub1.getAssetAccruedFees(assetId);
      uint256 actualFeesAccrued = _getExpectedFeeReceiverAddedAssets(hub1, assetId);

      // With 100% fee, actualFeesAccrued = getSpokeAddedAssets(treasury) + feesAccrued >= feesAccrued
      assertGe(actualFeesAccrued, feesAccrued, 'actual fees >= expected fees');

      skip(vm.randomUint(0, MAX_SKIP_TIME / count));
    }
  }

  function test_accrueLiquidityFee_maxLiquidityFee_multi_spoke() public {
    uint256 assetId = daiAssetId; // on all spokes
    uint256 spokeCount = hub1.getSpokeCount(assetId);
    updateLiquidityFee(hub1, assetId, MAX_LIQUIDITY_FEE);
    // build spoke list excluding treasury spoke
    ISpoke[] memory spokes = new ISpoke[](spokeCount - 1);
    uint256 spokeIndex;
    for (uint256 i; i < spokeCount; ++i) {
      if (hub1.getSpokeAddress(assetId, i) != address(treasurySpoke)) {
        spokes[spokeIndex++] = ISpoke(hub1.getSpokeAddress(assetId, i));
      }
    }

    uint256 count = vm.randomUint(10, 1000);
    for (uint256 i; i < count; ++i) {
      address user = makeUser(i);
      uint256 borrowAmount = vm.randomUint(1, MAX_SUPPLY_AMOUNT / count);
      ISpoke spoke = spokes[i % spokes.length]; // to deterministically pick random spoke
      uint256 reserveId = _reserveId(spoke, assetId);
      _backedBorrow(spoke, user, reserveId, reserveId, borrowAmount);
    }

    skip(vm.randomUint(1, MAX_SKIP_TIME));

    for (uint256 i; i < count; ++i) {
      address user = makeUser(i); // deterministic operation
      ISpoke spoke = spokes[i % spokes.length]; // deterministic operation
      uint256 reserveId = _reserveId(spoke, assetId);
      Utils.repay(spoke, reserveId, user, 1, user); // accrue interest & realize premium

      uint256 feesAccrued = hub1.getAssetAccruedFees(assetId);
      uint256 actualFeesAccrued = _getExpectedFeeReceiverAddedAssets(hub1, assetId);

      // With 100% fee, actualFeesAccrued = getSpokeAddedAssets(treasury) + feesAccrued >= feesAccrued
      assertGe(actualFeesAccrued, feesAccrued, 'actual fees >= expected fees');

      skip(vm.randomUint(0, MAX_SKIP_TIME / count));
    }
  }
}
