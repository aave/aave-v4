// SPDX-License-Identifier: MIT
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
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2); // within collateralization
    rate = bound(rate, 1, MAX_BORROW_RATE);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    uint256 assetId = spoke1.getReserve(reserveId).assetId;

    updateLiquidityFee(hub1, assetId, MAX_LIQUIDITY_FEE);

    uint256 supplyAmount = _calcMinimumCollAmount(spoke1, reserveId, reserveId, borrowAmount);
    _mockInterestRateBps(rate);

    Utils.supplyCollateral(spoke1, reserveId, alice, supplyAmount, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    skip(skipTime);

    (, uint256 premiumDebt) = spoke1.getUserDebt(reserveId, alice);
    assertGt(premiumDebt, 0);

    assertApproxEqAbs(
      spoke1.getUserSuppliedAmount(reserveId, alice),
      supplyAmount,
      3,
      'alice does not earn anything'
    );
    assertApproxEqAbs(
      hub1.getSpokeAddedAmount(assetId, address(treasurySpoke)),
      spoke1.getUserTotalDebt(reserveId, alice) - borrowAmount,
      3,
      'fees == total user accrued'
    );
    assertApproxEqAbs(
      hub1.getSpokeAddedAmount(assetId, address(treasurySpoke)),
      hub1.getSpokeTotalOwed(assetId, address(spoke1)) - borrowAmount,
      3,
      'fees == total spoke accrued'
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
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 4); // within collateralization
    borrowAmount2 = bound(borrowAmount2, 1, MAX_SUPPLY_AMOUNT / 4); // within collateralization
    rate = bound(rate, 1, MAX_BORROW_RATE);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    uint256 assetId = spoke1.getReserve(reserveId).assetId;

    updateLiquidityFee(hub1, spoke1.getReserve(reserveId).assetId, MAX_LIQUIDITY_FEE);

    uint256 supplyAmount = _calcMinimumCollAmount(spoke1, reserveId, reserveId, borrowAmount);
    uint256 supplyAmount2 = _calcMinimumCollAmount(spoke1, reserveId, reserveId, borrowAmount2);
    _mockInterestRateBps(rate);

    Utils.supplyCollateral(spoke1, reserveId, alice, supplyAmount, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    Utils.supplyCollateral(spoke1, reserveId, bob, supplyAmount2, bob);
    Utils.borrow(spoke1, reserveId, bob, borrowAmount2, bob);

    skip(skipTime);

    assertApproxEqAbs(
      spoke1.getUserSuppliedAmount(reserveId, alice),
      supplyAmount,
      3,
      'alice does not earn anything'
    );
    assertApproxEqAbs(
      spoke1.getUserSuppliedAmount(reserveId, bob),
      supplyAmount2,
      3,
      'bob does not earn anything'
    );

    uint256 totalAccruedToTreasury = hub1.getSpokeAddedAmount(assetId, address(treasurySpoke));
    assertLe(
      totalAccruedToTreasury,
      spoke1.getUserTotalDebt(reserveId, alice) -
        borrowAmount +
        spoke1.getUserTotalDebt(reserveId, bob) -
        borrowAmount2,
      'treasury accrued <= total accrued'
    );
    assertApproxEqAbs(
      totalAccruedToTreasury,
      hub1.getSpokeTotalOwed(assetId, address(spoke1)) - borrowAmount - borrowAmount2,
      3,
      'fees == total spoke accrued'
    );
  }

  function test_accrueLiquidityFee_maxLiquidityFee_multi_user() public {
    uint256 reserveId = _randomReserveId(spoke1);
    uint256 assetId = spoke1.getReserve(reserveId).assetId;
    updateLiquidityFee(hub1, assetId, MAX_LIQUIDITY_FEE);

    uint256 totalBorrowed;
    uint256 count = vm.randomUint(10, 1000);
    for (uint256 i; i < count; ++i) {
      address user = makeUser(i);
      uint256 borrowAmount = vm.randomUint(1, MAX_SUPPLY_AMOUNT / count);
      _backedBorrow(spoke1, user, reserveId, reserveId, borrowAmount);
      totalBorrowed += borrowAmount;
    }

    skip(vm.randomUint(1, MAX_SKIP_TIME));

    uint256 totalRepaid;
    for (uint256 i; i < count; ++i) {
      address user = makeUser(i); // deterministic operation
      uint256 debt = spoke1.getUserTotalDebt(reserveId, user);
      deal(spoke1, reserveId, user, debt);
      Utils.repay(spoke1, reserveId, user, debt, user);
      totalRepaid += debt;
    }

    assertEq(hub1.getSpokeTotalOwed(assetId, address(spoke1)), 0, 'all debt should be repaid');
    uint256 feesAccruedToTreasury = hub1.getSpokeAddedAmount(assetId, address(treasurySpoke));
    assertLe(feesAccruedToTreasury, totalRepaid - totalBorrowed, 'fees <= accrued');
    assertApproxEqRel(feesAccruedToTreasury, totalRepaid - totalBorrowed, 0.0000001e18); // 0.00001%
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

    uint256 totalBorrowed;
    uint256 count = vm.randomUint(10, 1000);
    for (uint256 i; i < count; ++i) {
      address user = makeUser(i);
      uint256 borrowAmount = vm.randomUint(1, MAX_SUPPLY_AMOUNT / count);
      ISpoke spoke = spokes[i % spokes.length]; // to deterministically pick random spoke
      uint256 reserveId = _reserveId(spoke, assetId);
      _backedBorrow(spoke, user, reserveId, reserveId, borrowAmount);
      totalBorrowed += borrowAmount;
    }

    skip(vm.randomUint(1, MAX_SKIP_TIME));

    uint256 totalRepaid;
    for (uint256 i; i < count; ++i) {
      address user = makeUser(i); // deterministic operation
      ISpoke spoke = spokes[i % spokes.length]; // deterministic operation
      uint256 reserveId = _reserveId(spoke, assetId);
      uint256 debt = spoke.getUserTotalDebt(reserveId, user);
      deal(spoke, reserveId, user, debt);
      Utils.repay(spoke, reserveId, user, debt, user);
      totalRepaid += debt;
    }

    uint256 feesAccruedToTreasury = hub1.getSpokeAddedAmount(assetId, address(treasurySpoke));
    assertLe(feesAccruedToTreasury, totalRepaid - totalBorrowed, 'fees <= accrued');
    assertApproxEqRel(feesAccruedToTreasury, totalRepaid - totalBorrowed, 0.0000001e18); // 0.00001%
  }
}
