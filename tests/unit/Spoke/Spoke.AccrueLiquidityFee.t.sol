// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeAccrueLiquidityFeeTest is SpokeBase {
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  function test_accrueLiquidityFee_NoActionTaken() public view {
    assertEq(hub.getSpokeSuppliedShares(daiAssetId, address(treasurySpoke)), 0);
    _assertSingleUserProtocolDebt(
      spoke1,
      _daiReserveId(spoke1),
      bob,
      0,
      0,
      'no debt without action'
    );
  }

  /// Supply an asset only, and check no interest accrued.
  function test_accrueLiquidityFee_NoInterest_OnlySupply(uint40 skipTime) public {
    skipTime = uint40(bound(skipTime, 0, MAX_SKIP_TIME));
    uint256 amount = 1000e18;
    uint256 daiReserveId = _daiReserveId(spoke1);

    vm.recordLogs();
    // Bob supplies through spoke 1
    Utils.supply(spoke1, daiReserveId, bob, amount, bob);
    _assertEventNotEmitted(ILiquidityHub.AccrueFees.selector);

    // Skip time
    skip(skipTime);

    _assertSingleUserProtocolDebt(
      spoke1,
      daiReserveId,
      bob,
      0,
      0,
      'after supply, no interest accrued'
    );

    // treasury
    assertEq(hub.getSpokeSuppliedAmount(daiAssetId, address(treasurySpoke)), 0);
  }

  function test_accrueLiquidityFee_fuzz_BorrowAmountAndSkipTime(
    uint256 borrowAmount,
    uint40 skipTime
  ) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    skipTime = uint40(bound(skipTime, 0, MAX_SKIP_TIME / 3));
    uint256 supplyAmount = borrowAmount * 2;
    uint40 startTime = uint40(vm.getBlockTimestamp());
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 assetId = spoke1.getReserve(reserveId).assetId;

    // Bob supplies and borrows through spoke 1
    Utils.supplyCollateral(spoke1, reserveId, bob, supplyAmount, bob);
    Utils.borrow(spoke1, reserveId, bob, borrowAmount, bob);

    uint256 baseBorrowRate = hub.getBaseInterestRate(assetId);
    uint256 initialBaseIndex = hub.getAsset(assetId).baseDebtIndex;
    uint256 userRp = spoke1.getUserRiskPremium(bob);

    // withdraw any treasury fees
    withdrawLiquidityFees(assetId, type(uint256).max);

    // Time passes
    skip(skipTime);

    DataTypes.UserPosition memory bobPosition = spoke1.getUserPosition(reserveId, bob);
    {
      uint256 baseDebt = _calculateExpectedBaseDebt(borrowAmount, baseBorrowRate, startTime);
      uint256 expectedPremiumDrawnShares = bobPosition.baseDrawnShares.percentMulUp(userRp);
      uint256 expectedPremiumDebt = hub.convertToDrawnAssets(assetId, expectedPremiumDrawnShares) -
        bobPosition.premiumOffset +
        bobPosition.realizedPremium;

      _assertSingleUserProtocolDebt(
        spoke1,
        reserveId,
        bob,
        baseDebt,
        expectedPremiumDebt,
        'after accrual'
      );
    }

    // Alice supplies 1 share to trigger interest accrual
    Utils.supplyCollateral(spoke1, reserveId, alice, minimumAssetsPerSuppliedShare(assetId), alice);

    // treasury
    uint256 expectedFeeShares = hub.convertToSuppliedShares(
      assetId,
      _calculateExpectedFeesAmount({
        initialDrawnShares: bobPosition.baseDrawnShares,
        initialPremiumShares: bobPosition.premiumDrawnShares,
        liquidityFee: _getLiquidityFee(assetId),
        indexDelta: hub.getAsset(assetId).baseDebtIndex - initialBaseIndex
      })
    );

    assertApproxEqAbs(
      hub.getSpokeSuppliedShares(assetId, address(treasurySpoke)),
      expectedFeeShares,
      1,
      'treasury shares'
    );

    // now only base debt grows
    updateCollateralRisk(spoke1, reserveId, 0);
    vm.prank(bob);
    spoke1.updateUserRiskPremium(bob);

    // refresh
    initialBaseIndex = hub.getAsset(assetId).baseDebtIndex;

    // withdraw any treasury fees
    withdrawLiquidityFees(assetId, type(uint256).max);

    // todo: updateCollateralRisk, updateLiquidityFee or updateInterestRateStrategy needs reserve update?

    // Time passes
    skip(skipTime);

    // Alice supplies 1 share to trigger interest accrual
    Utils.supply(spoke1, reserveId, alice, minimumAssetsPerSuppliedShare(assetId), alice);

    // treasury
    expectedFeeShares = hub.convertToSuppliedShares(
      assetId,
      _calculateExpectedFeesAmount({
        initialDrawnShares: bobPosition.baseDrawnShares,
        initialPremiumShares: 0,
        liquidityFee: _getLiquidityFee(assetId),
        indexDelta: hub.getAsset(assetId).baseDebtIndex - initialBaseIndex
      })
    );

    assertApproxEqAbs(
      hub.getSpokeSuppliedShares(assetId, address(treasurySpoke)),
      expectedFeeShares,
      1,
      'treasury shares'
    );

    // now no liquidity fee, so no fees
    updateLiquidityFee(hub, assetId, 0);

    // withdraw any treasury fees
    withdrawLiquidityFees(assetId, type(uint256).max);

    // Time passes
    skip(skipTime);

    // Alice supplies 1 share to trigger interest accrual
    Utils.supply(spoke1, reserveId, alice, minimumAssetsPerSuppliedShare(assetId), alice);

    // treasury
    expectedFeeShares = 0;

    assertApproxEqAbs(
      hub.getSpokeSuppliedShares(assetId, address(treasurySpoke)),
      expectedFeeShares,
      1,
      'treasury shares'
    );
  }

  function test_accrueLiquidityFee_exact() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 assetId = spoke1.getReserve(reserveId).assetId;

    uint256 expectedRp = 10_00;
    updateCollateralRisk(spoke1, reserveId, expectedRp);
    uint256 liquidityFee = 5_00;
    updateLiquidityFee(hub, assetId, liquidityFee);

    uint256 borrowAmount = 1000e18;
    uint256 supplyAmount = _calcMinimumCollAmount(spoke1, reserveId, reserveId, borrowAmount);
    uint256 rate = 50_00; // 50.00% base borrow rate
    uint256 expectedBaseDebtAccrual = 500e18; // 50% of 1000 (base debt accrual)
    uint256 expectedBaseDebt = borrowAmount + expectedBaseDebtAccrual;
    uint256 expectedPremiumDebt = 50e18; // 10% of 500 (premium on base debt)
    uint256 expectedTreasuryFees = 27.5e18; // 5% of 550 (liquidity fee on base debt)

    _mockInterestRateBps(rate);

    Utils.supplyCollateral(spoke1, reserveId, alice, supplyAmount, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    skip(365 days);

    _assertSpokeDebt(
      spoke1,
      reserveId,
      expectedBaseDebt,
      expectedPremiumDebt,
      'after base and premium debt accrual'
    );
    assertEq(
      hub.getSpokeSuppliedShares(assetId, address(treasurySpoke)),
      hub.convertToSuppliedShares(assetId, expectedTreasuryFees),
      'treasury fees after base and premium debt accrual'
    );

    // 0% premium
    expectedRp = 0;
    updateCollateralRisk(spoke1, reserveId, expectedRp);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.AccrueFees(
      assetId,
      hub.convertToSuppliedShares(assetId, expectedTreasuryFees)
    );
    vm.prank(alice);
    spoke1.updateUserRiskPremium(alice);

    vm.recordLogs();
    // withdraw any treasury fees to reset counter
    withdrawLiquidityFees(assetId, type(uint256).max);
    _assertEventNotEmitted(ILiquidityHub.Add.selector);
    _assertEventNotEmitted(ILiquidityHub.AccrueFees.selector);

    expectedBaseDebtAccrual = 750e18; // 50% of 1500 (base debt accrual)
    expectedBaseDebt += expectedBaseDebtAccrual;
    expectedPremiumDebt += 0;
    expectedTreasuryFees = 37.5e18; // 5% of 750 (liquidity fee on base debt)

    skip(365 days);

    _assertSpokeDebt(
      spoke1,
      reserveId,
      expectedBaseDebt,
      expectedPremiumDebt,
      'after base debt accrual'
    );
    assertEq(
      hub.getSpokeSuppliedShares(assetId, address(treasurySpoke)),
      hub.convertToSuppliedShares(assetId, expectedTreasuryFees),
      'treasury fees after base debt accrual'
    );

    vm.expectEmit(address(hub));
    emit ILiquidityHub.AccrueFees(
      assetId,
      hub.convertToSuppliedShares(assetId, expectedTreasuryFees)
    );

    // 0.00% liquidity fee
    liquidityFee = 0;
    updateLiquidityFee(hub, assetId, liquidityFee);

    vm.recordLogs();
    // Bob supplies 1 share to trigger interest accrual with new liquidity fee
    Utils.supply(spoke1, reserveId, bob, minimumAssetsPerSuppliedShare(assetId), bob);
    _assertEventNotEmitted(ILiquidityHub.AccrueFees.selector);

    vm.recordLogs();
    // withdraw any treasury fees to reset counter
    withdrawLiquidityFees(assetId, type(uint256).max);
    _assertEventNotEmitted(ILiquidityHub.Add.selector);
    _assertEventNotEmitted(ILiquidityHub.AccrueFees.selector);

    expectedBaseDebtAccrual = 1125e18; // 50% of 2250 (base debt accrual)
    expectedBaseDebt += expectedBaseDebtAccrual;
    expectedPremiumDebt += 0;
    expectedTreasuryFees = 0;

    skip(365 days);

    _assertSpokeDebt(
      spoke1,
      reserveId,
      expectedBaseDebt,
      expectedPremiumDebt,
      'after base debt accrual'
    );
    assertEq(
      hub.getSpokeSuppliedShares(assetId, address(treasurySpoke)),
      hub.convertToSuppliedShares(assetId, expectedTreasuryFees),
      'treasury fees after base debt accrual'
    );
  }

  function test_accrueLiquidityFee() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 assetId = spoke1.getReserve(reserveId).assetId;

    uint256 expectedRp = 10_00;
    updateCollateralRisk(spoke1, reserveId, expectedRp);
    uint256 liquidityFee = 5_00;
    updateLiquidityFee(hub, assetId, liquidityFee);

    uint256 borrowAmount = 1000e18;
    uint256 supplyAmount = _calcMinimumCollAmount(spoke1, reserveId, reserveId, borrowAmount);
    uint256 rate = 50_00; // 50.00% base borrow rate
    uint256 expectedBaseDebtAccrual = borrowAmount.percentMulUp(rate);
    uint256 expectedBaseDebt = borrowAmount + expectedBaseDebtAccrual;
    uint256 expectedPremiumDebt = expectedBaseDebtAccrual.percentMulUp(expectedRp);
    uint256 expectedTreasuryFees = (expectedBaseDebtAccrual + expectedPremiumDebt).percentMulUp(
      liquidityFee
    );

    _mockInterestRateBps(rate);

    Utils.supplyCollateral(spoke1, reserveId, alice, supplyAmount, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    assertEq(_getUserRpStored(spoke1, reserveId, alice), expectedRp);

    skip(365 days);

    _assertSpokeDebt(
      spoke1,
      reserveId,
      expectedBaseDebt,
      expectedPremiumDebt,
      'after base and premium debt accrual'
    );
    assertEq(
      hub.getSpokeSuppliedShares(assetId, address(treasurySpoke)),
      hub.convertToSuppliedShares(assetId, expectedTreasuryFees),
      'treasury fees after base and premium debt accrual'
    );

    // 0% premium
    expectedRp = 0;
    updateCollateralRisk(spoke1, reserveId, expectedRp);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.AccrueFees(
      assetId,
      hub.convertToSuppliedShares(assetId, expectedTreasuryFees)
    );

    vm.prank(alice);
    spoke1.updateUserRiskPremium(alice);
    assertEq(_getUserRpStored(spoke1, reserveId, alice), expectedRp);

    vm.recordLogs();
    // withdraw any treasury fees to reset counter
    withdrawLiquidityFees(assetId, type(uint256).max);
    _assertEventNotEmitted(ILiquidityHub.Add.selector);
    _assertEventNotEmitted(ILiquidityHub.AccrueFees.selector);

    expectedBaseDebtAccrual = expectedBaseDebt.percentMulUp(rate);
    expectedBaseDebt += expectedBaseDebtAccrual;
    expectedPremiumDebt += 0;
    expectedTreasuryFees = expectedBaseDebtAccrual.percentMulUp(liquidityFee);

    skip(365 days);

    _assertSpokeDebt(
      spoke1,
      reserveId,
      expectedBaseDebt,
      expectedPremiumDebt,
      'after base debt accrual'
    );
    assertEq(
      hub.getSpokeSuppliedShares(assetId, address(treasurySpoke)),
      hub.convertToSuppliedShares(assetId, expectedTreasuryFees),
      'treasury fees after base debt accrual'
    );

    vm.expectEmit(address(hub));
    emit ILiquidityHub.AccrueFees(
      assetId,
      hub.convertToSuppliedShares(assetId, expectedTreasuryFees)
    );

    // 0.00% liquidity fee
    liquidityFee = 0;
    updateLiquidityFee(hub, assetId, liquidityFee);

    vm.recordLogs();
    // Bob supplies 1 share to trigger interest accrual with new liquidity fee
    Utils.supply(spoke1, reserveId, bob, minimumAssetsPerSuppliedShare(assetId), bob);
    _assertEventNotEmitted(ILiquidityHub.AccrueFees.selector);

    vm.recordLogs();
    // withdraw any treasury fees to reset counter
    withdrawLiquidityFees(assetId, type(uint256).max);
    _assertEventNotEmitted(ILiquidityHub.Add.selector);
    _assertEventNotEmitted(ILiquidityHub.AccrueFees.selector);

    expectedBaseDebtAccrual = expectedBaseDebt.percentMulUp(rate);
    expectedBaseDebt += expectedBaseDebtAccrual;
    expectedPremiumDebt += 0;
    expectedTreasuryFees = 0;

    skip(365 days);

    _assertSpokeDebt(
      spoke1,
      reserveId,
      expectedBaseDebt,
      expectedPremiumDebt,
      'after base debt accrual'
    );
    assertEq(
      hub.getSpokeSuppliedShares(assetId, address(treasurySpoke)),
      hub.convertToSuppliedShares(assetId, expectedTreasuryFees),
      'treasury fees after base debt accrual'
    );
  }

  // todo: check treasury fees shares only grow
  // todo: check setAsCollateral does impact treasury fees shares

  // disabling an asset as collateral raises the user’s risk premium, but fees use the old value until the action is executed.
  function test_accrueLiquidityFee_setUsingAsCollateral() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 reserveId2 = _wethReserveId(spoke1);
    uint256 assetId = spoke1.getReserve(reserveId).assetId;

    uint256 expectedRp = 10_00;
    updateCollateralRisk(spoke1, reserveId, expectedRp);
    // 50.00% premium for second collateral asset
    updateCollateralRisk(spoke1, reserveId2, 50_00);
    uint256 liquidityFee = 5_00;
    updateLiquidityFee(hub, assetId, liquidityFee);
    updateLiquidityFee(hub, spoke1.getReserve(reserveId2).assetId, liquidityFee);

    uint256 borrowAmount = 1000e18;
    // supply way more than needed to cover borrow amount
    uint256 supplyAmount = _calcMinimumCollAmount(spoke1, reserveId, reserveId, borrowAmount) * 2;
    uint256 supplyAmount2 = _calcMinimumCollAmount(spoke1, reserveId2, reserveId, borrowAmount) * 2;
    uint256 rate = 50_00; // 50.00% base borrow rate
    uint256 expectedBaseDebtAccrual = borrowAmount.percentMulUp(rate);
    uint256 expectedBaseDebt = borrowAmount + expectedBaseDebtAccrual;
    uint256 expectedPremiumDebt = expectedBaseDebtAccrual.percentMulUp(expectedRp);
    uint256 expectedTreasuryFees = (expectedBaseDebtAccrual + expectedPremiumDebt).percentMulUp(
      liquidityFee
    );

    _mockInterestRateBps(rate);

    Utils.supplyCollateral(spoke1, reserveId, alice, supplyAmount, alice);
    Utils.supplyCollateral(spoke1, reserveId2, alice, supplyAmount2, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    assertEq(_getUserRpStored(spoke1, reserveId, alice), expectedRp);

    skip(365 days);

    _assertSpokeDebt(
      spoke1,
      reserveId,
      expectedBaseDebt,
      expectedPremiumDebt,
      'after base and premium debt accrual'
    );
    assertEq(
      hub.getSpokeSuppliedShares(assetId, address(treasurySpoke)),
      hub.convertToSuppliedShares(assetId, expectedTreasuryFees),
      'treasury fees'
    );

    // disable second asset as collateral, which increases risk premium
    vm.prank(alice);
    spoke1.setUsingAsCollateral(reserveId, false, alice);
    assertEq(_getUserRpStored(spoke1, reserveId, alice), 50_00);

    // no change in treasury fees
    _assertSpokeDebt(
      spoke1,
      reserveId,
      expectedBaseDebt,
      expectedPremiumDebt,
      'after base and premium debt accrual'
    );
    assertEq(
      hub.getSpokeSuppliedShares(assetId, address(treasurySpoke)),
      hub.convertToSuppliedShares(assetId, expectedTreasuryFees),
      'treasury fees after base and premium debt accrual'
    );
  }

  /// 100.00% liquidity fee redirect all liquidity growth to fee receiver and nothing to suppliers
  function test_accrueLiquidityFee_maxLiquidityFee() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 assetId = spoke1.getReserve(reserveId).assetId;

    uint256 liquidityFee = 100_00;
    updateLiquidityFee(hub, assetId, liquidityFee);

    uint256 borrowAmount = 1000e18;
    uint256 supplyAmount = _calcMinimumCollAmount(spoke1, reserveId, reserveId, borrowAmount);
    uint256 rate = 50_00; // 50.00% base borrow rate
    uint256 expectedBaseDebtAccrual = borrowAmount.percentMulUp(rate);
    uint256 expectedBaseDebt = borrowAmount + expectedBaseDebtAccrual;
    uint256 expectedPremiumDebt = expectedBaseDebtAccrual.percentMulUp(
      _getCollateralRisk(spoke1, reserveId)
    );
    uint256 expectedTreasuryFees = (expectedBaseDebtAccrual + expectedPremiumDebt).percentMulUp(
      liquidityFee
    );
    _mockInterestRateBps(rate);

    Utils.supplyCollateral(spoke1, reserveId, alice, supplyAmount, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    skip(365 days);

    _assertSpokeDebt(
      spoke1,
      reserveId,
      expectedBaseDebt,
      expectedPremiumDebt,
      'after base and premium debt accrual'
    );
    assertEq(
      hub.getSpokeSuppliedShares(assetId, address(treasurySpoke)),
      hub.convertToSuppliedShares(assetId, expectedTreasuryFees),
      'treasury fees after base and premium debt accrual'
    );

    assertEq(
      spoke1.getUserSuppliedAmount(reserveId, alice),
      supplyAmount,
      'alice does not earn anything'
    );
    assertEq(
      hub.getSpokeSuppliedAmount(assetId, address(treasurySpoke)),
      expectedBaseDebtAccrual + expectedPremiumDebt,
      'treasury all accumulated interest'
    );
  }
}
