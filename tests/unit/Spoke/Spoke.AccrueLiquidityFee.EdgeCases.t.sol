// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeAccrueLiquidityFeeEdgeCasesTest is SpokeBase {
  uint256 public constant MAX_LIQUIDITY_FEE = 100_00;

  function test_accrueLiquidityFee_fuzz_maxLiquidityFee_with_premium() public {
    test_accrueLiquidityFee_fuzz_maxLiquidityFee_with_premium({
      reserveId: _daiReserveId(spoke1),
      supplyAmount: 1000e18,
      borrowAmount: 500e18,
      skipTime: 400 days,
      rate: 50_00
    });
  }

  function test_accrueLiquidityFee_fuzz_maxLiquidityFee_with_premium(
    uint256 reserveId,
    uint256 supplyAmount,
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

    (uint256 baseDebt, uint256 premiumDebt) = spoke1.getUserDebt(reserveId, alice);
    assertGt(premiumDebt, 0);

    assertEq(
      spoke1.getUserSuppliedAmount(reserveId, alice),
      supplyAmount,
      'alice does not earn anything'
    );
    assertEq(
      hub.getSpokeSuppliedAmount(assetId, address(treasurySpoke)),
      spoke1.getUserTotalDebt(reserveId, alice) - borrowAmount,
      'treasury accrued matches total accrued'
    );
  }
}
