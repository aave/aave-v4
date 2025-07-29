// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeAccrueLiquidityFeeEdgeCasesTest is SpokeBase {
  uint256 public constant MAX_LIQUIDITY_FEE = 100_00;

  /// @dev Max liquidity fee with premium debt accrual
  function test_accrueLiquidityFee_fuzz_maxLiquidityFee_with_premium() public {
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

    updateLiquidityFee(hub, assetId, MAX_LIQUIDITY_FEE);

    uint256 supplyAmount = _calcMinimumCollAmount(spoke1, reserveId, reserveId, borrowAmount);
    _mockInterestRateBps(rate);

    Utils.supplyCollateral(spoke1, reserveId, alice, supplyAmount, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    skip(skipTime);

    (, uint256 premiumDebt) = spoke1.getUserDebt(reserveId, alice);
    assertGt(premiumDebt, 0);

    assertEq(
      spoke1.getUserSuppliedAmount(reserveId, alice),
      supplyAmount,
      'alice does not earn anything'
    );
    assertEq(
      hub.getSpokeSuppliedAmount(assetId, address(treasurySpoke)),
      spoke1.getUserTotalDebt(reserveId, alice) - borrowAmount,
      'fees == total user accrued'
    );
    assertEq(
      hub.getSpokeSuppliedAmount(assetId, address(treasurySpoke)),
      hub.getSpokeTotalDebt(assetId, address(spoke1)) - borrowAmount,
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

    updateLiquidityFee(hub, spoke1.getReserve(reserveId).assetId, MAX_LIQUIDITY_FEE);

    uint256 supplyAmount = _calcMinimumCollAmount(spoke1, reserveId, reserveId, borrowAmount);
    uint256 supplyAmount2 = _calcMinimumCollAmount(spoke1, reserveId, reserveId, borrowAmount2);
    _mockInterestRateBps(rate);

    Utils.supplyCollateral(spoke1, reserveId, alice, supplyAmount, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    Utils.supplyCollateral(spoke1, reserveId, bob, supplyAmount2, bob);
    Utils.borrow(spoke1, reserveId, bob, borrowAmount2, bob);

    skip(skipTime);

    {
      (, uint256 premiumDebt) = spoke1.getUserDebt(reserveId, alice);
      assertGt(premiumDebt, 0);
      (, premiumDebt) = spoke1.getUserDebt(reserveId, bob);
      assertGt(premiumDebt, 0);
    }

    assertEq(
      spoke1.getUserSuppliedAmount(reserveId, alice),
      supplyAmount,
      'alice does not earn anything'
    );
    assertEq(
      spoke1.getUserSuppliedAmount(reserveId, bob),
      supplyAmount2,
      'bob does not earn anything'
    );

    uint256 totalAccruedToTreasury = hub.getSpokeSuppliedAmount(assetId, address(treasurySpoke));
    assertLe(
      totalAccruedToTreasury,
      spoke1.getUserTotalDebt(reserveId, alice) -
        borrowAmount +
        spoke1.getUserTotalDebt(reserveId, bob) -
        borrowAmount2,
      'treasury accrued <= total accrued'
    );
    assertEq(
      totalAccruedToTreasury,
      hub.getSpokeTotalDebt(assetId, address(spoke1)) - borrowAmount - borrowAmount2,
      'fees == total spoke accrued'
    );
  }
}
