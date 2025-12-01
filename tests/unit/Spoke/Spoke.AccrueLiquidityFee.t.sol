// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeAccrueLiquidityFeeTest is SpokeBase {
  using WadRayMath for uint256;
  using PercentageMath for *;
  using SafeCast for uint256;

  function test_accrueLiquidityFee_NoActionTaken() public view {
    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(treasurySpoke)), 0);
    _assertSingleUserProtocolDebt(
      spoke1,
      _daiReserveId(spoke1),
      bob,
      0,
      0,
      'no debt without action'
    );

    _assertHubLiquidity(hub1, _daiReserveId(spoke1), 'spoke1.accrueLiquidityFee');
  }

  /// Supply an asset only, and check no interest accrued.
  function test_accrueLiquidityFee_NoInterest_OnlySupply(uint40 skipTime) public {
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME).toUint40();
    uint256 amount = 1000e18;
    uint256 daiReserveId = _daiReserveId(spoke1);

    vm.recordLogs();
    // Bob supplies through spoke 1
    Utils.supply(spoke1, daiReserveId, bob, amount, bob);
    _assertEventNotEmitted(IHub.MintFeeShares.selector);

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
    assertEq(hub1.getSpokeAddedAssets(daiAssetId, address(treasurySpoke)), 0);

    _assertHubLiquidity(hub1, daiReserveId, 'spoke1.accrueLiquidityFee');
  }

  function test_accrueLiquidityFee_fuzz_BorrowAmountAndSkipTime(
    uint256 borrowAmount,
    uint40 skipTime
  ) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME / 3).toUint40();
    uint256 supplyAmount = borrowAmount * 2;
    uint40 startTime = vm.getBlockTimestamp().toUint40();
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 assetId = spoke1.getReserve(reserveId).assetId;

    // Bob supplies and borrows through spoke 1
    Utils.supplyCollateral(spoke1, reserveId, bob, supplyAmount, bob);
    Utils.borrow(spoke1, reserveId, bob, borrowAmount, bob);

    uint96 drawnRate = hub1.getAssetDrawnRate(assetId).toUint96();
    uint256 initialBaseIndex = hub1.getAsset(assetId).drawnIndex;
    uint256 userRp = _getUserRiskPremium(spoke1, bob);

    // withdraw any treasury fees
    _withdrawLiquidityFees(hub1, assetId, UINT256_MAX);

    // Time passes
    skip(skipTime);

    ISpoke.UserPosition memory bobPosition = spoke1.getUserPosition(reserveId, bob);
    {
      uint256 drawnDebt = _calculateExpectedDrawnDebt(borrowAmount, drawnRate, startTime);
      uint256 expectedPremiumShares = bobPosition.drawnShares.percentMulUp(userRp);
      uint256 expectedPremiumDebt = _calculatePremiumDebt(
        hub1,
        assetId,
        expectedPremiumShares,
        bobPosition.premiumOffsetRay
      );
      _assertSingleUserProtocolDebt(
        spoke1,
        reserveId,
        bob,
        drawnDebt,
        expectedPremiumDebt,
        'after accrual'
      );
    }

    // Alice supplies 1 share to trigger interest accrual
    Utils.supplyCollateral(
      spoke1,
      reserveId,
      alice,
      minimumAssetsPerAddedShare(hub1, assetId),
      alice
    );

    // treasury
    uint256 expectedFeeShares = hub1.previewAddByAssets(
      assetId,
      _calculateExpectedFeesAmount({
        initialDrawnShares: bobPosition.drawnShares,
        initialPremiumShares: bobPosition.premiumShares,
        liquidityFee: _getAssetLiquidityFee(assetId),
        indexDelta: hub1.getAsset(assetId).drawnIndex - initialBaseIndex
      })
    );

    Utils.mintFeeShares(hub1, assetId, ADMIN);
    assertApproxEqAbs(
      hub1.getSpokeAddedShares(assetId, address(treasurySpoke)),
      expectedFeeShares,
      1,
      'treasury shares'
    );

    // now only drawn debt grows
    _updateCollateralRisk(spoke1, reserveId, 0);
    vm.prank(bob);
    spoke1.updateUserRiskPremium(bob);

    // refresh
    initialBaseIndex = hub1.getAsset(assetId).drawnIndex;

    // withdraw any treasury fees
    _withdrawLiquidityFees(hub1, assetId, UINT256_MAX);

    // todo: _updateCollateralRisk, updateLiquidityFee or updateInterestRateStrategy needs reserve update?

    // Time passes
    skip(skipTime);

    // Alice supplies 1 share to trigger interest accrual
    Utils.supply(spoke1, reserveId, alice, minimumAssetsPerAddedShare(hub1, assetId), alice);

    // treasury
    expectedFeeShares = hub1.previewAddByAssets(
      assetId,
      _calculateExpectedFeesAmount({
        initialDrawnShares: bobPosition.drawnShares,
        initialPremiumShares: 0,
        liquidityFee: _getAssetLiquidityFee(assetId),
        indexDelta: hub1.getAsset(assetId).drawnIndex - initialBaseIndex
      })
    );

    Utils.mintFeeShares(hub1, assetId, ADMIN);
    assertApproxEqAbs(
      hub1.getSpokeAddedShares(assetId, address(treasurySpoke)),
      expectedFeeShares,
      1,
      'treasury shares'
    );

    // now no liquidity fee, so no fees
    updateLiquidityFee(hub1, assetId, 0);

    // withdraw any treasury fees
    _withdrawLiquidityFees(hub1, assetId, UINT256_MAX);

    // Time passes
    skip(skipTime);

    // Alice supplies 1 share to trigger interest accrual
    Utils.supply(spoke1, reserveId, alice, minimumAssetsPerAddedShare(hub1, assetId), alice);

    // treasury
    expectedFeeShares = 0;

    Utils.mintFeeShares(hub1, assetId, ADMIN);
    assertApproxEqAbs(
      hub1.getSpokeAddedShares(assetId, address(treasurySpoke)),
      expectedFeeShares,
      1,
      'treasury shares'
    );

    _assertHubLiquidity(hub1, reserveId, 'spoke1.accrueLiquidityFee');
  }

  function test_accrueLiquidityFee_exact() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 assetId = spoke1.getReserve(reserveId).assetId;

    uint24 expectedRp = 10_00;
    _updateCollateralRisk(spoke1, reserveId, expectedRp);
    uint256 liquidityFee = 5_00;
    updateLiquidityFee(hub1, assetId, liquidityFee);

    uint256 borrowAmount = 1000e18;
    uint256 supplyAmount = _calcMinimumCollAmount(spoke1, reserveId, reserveId, borrowAmount);
    uint256 rate = 50_00; // 50.00% base borrow rate
    uint256 expectedDrawnDebtAccrual = 500e18; // 50% of 1000 (drawn debt accrual)
    uint256 expectedDrawnDebt = borrowAmount + expectedDrawnDebtAccrual;
    uint256 expectedPremiumDebt = 50e18; // 10% of 500 (premium on drawn debt)
    uint256 expectedTreasuryFees = 27.5e18; // 5% of 550 (liquidity fee on drawn debt)

    _mockInterestRateBps(rate);

    Utils.supplyCollateral(spoke1, reserveId, alice, supplyAmount, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    skip(365 days);
    Utils.mintFeeShares(hub1, assetId, ADMIN);

    _assertSpokeDebt(
      spoke1,
      reserveId,
      expectedDrawnDebt,
      expectedPremiumDebt,
      'after base and premium debt accrual'
    );
    assertEq(
      hub1.getSpokeAddedShares(assetId, address(treasurySpoke)),
      hub1.previewAddByAssets(assetId, expectedTreasuryFees),
      'treasury fees after base and premium debt accrual'
    );

    // 0% premium
    expectedRp = 0;
    _updateCollateralRisk(spoke1, reserveId, expectedRp);

    vm.prank(alice);
    spoke1.updateUserRiskPremium(alice);

    vm.recordLogs();
    // withdraw any treasury fees to reset counter
    _withdrawLiquidityFees(hub1, assetId, UINT256_MAX);
    _assertEventNotEmitted(IHubBase.Add.selector);
    _assertEventNotEmitted(IHub.MintFeeShares.selector);

    expectedDrawnDebtAccrual = 750e18; // 50% of 1500 (drawn debt accrual)
    expectedDrawnDebt += expectedDrawnDebtAccrual;
    expectedPremiumDebt += 0;
    expectedTreasuryFees = 37.5e18; // 5% of 750 (liquidity fee on drawn debt)

    skip(365 days);
    Utils.mintFeeShares(hub1, assetId, ADMIN);

    _assertSpokeDebt(
      spoke1,
      reserveId,
      expectedDrawnDebt,
      expectedPremiumDebt,
      'after drawn debt accrual'
    );
    assertEq(
      hub1.getSpokeAddedShares(assetId, address(treasurySpoke)),
      hub1.previewAddByAssets(assetId, expectedTreasuryFees),
      'treasury fees after drawn debt accrual'
    );

    // 0.00% liquidity fee
    liquidityFee = 0;
    updateLiquidityFee(hub1, assetId, liquidityFee);

    vm.recordLogs();
    // Bob supplies 1 share to trigger interest accrual with new liquidity fee
    Utils.supply(spoke1, reserveId, bob, minimumAssetsPerAddedShare(hub1, assetId), bob);
    _assertEventNotEmitted(IHub.MintFeeShares.selector);

    vm.recordLogs();
    // withdraw any treasury fees to reset counter
    _withdrawLiquidityFees(hub1, assetId, UINT256_MAX);
    _assertEventNotEmitted(IHubBase.Add.selector);
    _assertEventNotEmitted(IHub.MintFeeShares.selector);

    expectedDrawnDebtAccrual = 1125e18; // 50% of 2250 (drawn debt accrual)
    expectedDrawnDebt += expectedDrawnDebtAccrual;
    expectedPremiumDebt += 0;
    expectedTreasuryFees = 0;

    skip(365 days);
    Utils.mintFeeShares(hub1, assetId, ADMIN);

    _assertSpokeDebt(
      spoke1,
      reserveId,
      expectedDrawnDebt,
      expectedPremiumDebt,
      'after drawn debt accrual'
    );
    assertEq(
      hub1.getSpokeAddedShares(assetId, address(treasurySpoke)),
      hub1.previewAddByAssets(assetId, expectedTreasuryFees),
      'treasury fees after drawn debt accrual'
    );

    _assertHubLiquidity(hub1, reserveId, 'spoke1.accrueLiquidityFee');
  }

  function test_accrueLiquidityFee() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 assetId = spoke1.getReserve(reserveId).assetId;

    uint24 expectedRp = 10_00;
    _updateCollateralRisk(spoke1, reserveId, expectedRp);
    uint256 liquidityFee = 5_00;
    updateLiquidityFee(hub1, assetId, liquidityFee);

    uint256 borrowAmount = 1000e18;
    uint256 supplyAmount = _calcMinimumCollAmount(spoke1, reserveId, reserveId, borrowAmount);
    uint256 rate = 50_00; // 50.00% base borrow rate
    uint256 expectedDrawnDebtAccrual = borrowAmount.percentMulUp(rate);
    uint256 expectedDrawnDebt = borrowAmount + expectedDrawnDebtAccrual;
    uint256 expectedPremiumDebt = expectedDrawnDebtAccrual.percentMulUp(expectedRp);
    uint256 expectedTreasuryFees = (expectedDrawnDebtAccrual + expectedPremiumDebt).percentMulUp(
      liquidityFee
    );

    _mockInterestRateBps(rate);

    Utils.supplyCollateral(spoke1, reserveId, alice, supplyAmount, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    assertEq(_getUserRpStored(spoke1, alice), expectedRp);

    skip(365 days);
    Utils.mintFeeShares(hub1, assetId, ADMIN);

    _assertSpokeDebt(
      spoke1,
      reserveId,
      expectedDrawnDebt,
      expectedPremiumDebt,
      'after base and premium debt accrual'
    );
    assertEq(
      hub1.getSpokeAddedShares(assetId, address(treasurySpoke)),
      hub1.previewAddByAssets(assetId, expectedTreasuryFees),
      'treasury fees after base and premium debt accrual'
    );

    // 0% premium
    expectedRp = 0;
    _updateCollateralRisk(spoke1, reserveId, expectedRp);

    vm.prank(alice);
    spoke1.updateUserRiskPremium(alice);
    assertEq(_getUserRpStored(spoke1, alice), expectedRp);

    vm.recordLogs();
    // withdraw any treasury fees to reset counter
    _withdrawLiquidityFees(hub1, assetId, UINT256_MAX);
    _assertEventNotEmitted(IHubBase.Add.selector);
    _assertEventNotEmitted(IHub.MintFeeShares.selector);

    expectedDrawnDebtAccrual = expectedDrawnDebt.percentMulUp(rate);
    expectedDrawnDebt += expectedDrawnDebtAccrual;
    expectedPremiumDebt += 0;
    expectedTreasuryFees = expectedDrawnDebtAccrual.percentMulUp(liquidityFee);

    skip(365 days);
    Utils.mintFeeShares(hub1, assetId, ADMIN);

    _assertSpokeDebt(
      spoke1,
      reserveId,
      expectedDrawnDebt,
      expectedPremiumDebt,
      'after drawn debt accrual'
    );
    assertEq(
      hub1.getSpokeAddedShares(assetId, address(treasurySpoke)),
      hub1.previewAddByAssets(assetId, expectedTreasuryFees),
      'treasury fees after drawn debt accrual'
    );

    // 0.00% liquidity fee
    liquidityFee = 0;
    updateLiquidityFee(hub1, assetId, liquidityFee);

    vm.recordLogs();
    // Bob supplies 1 share to trigger interest accrual with new liquidity fee
    Utils.supply(spoke1, reserveId, bob, minimumAssetsPerAddedShare(hub1, assetId), bob);
    _assertEventNotEmitted(IHub.MintFeeShares.selector);

    vm.recordLogs();
    // withdraw any treasury fees to reset counter
    _withdrawLiquidityFees(hub1, assetId, UINT256_MAX);
    _assertEventNotEmitted(IHubBase.Add.selector);
    _assertEventNotEmitted(IHub.MintFeeShares.selector);

    expectedDrawnDebtAccrual = expectedDrawnDebt.percentMulUp(rate);
    expectedDrawnDebt += expectedDrawnDebtAccrual;
    expectedPremiumDebt += 0;
    expectedTreasuryFees = 0;

    skip(365 days);

    _assertSpokeDebt(
      spoke1,
      reserveId,
      expectedDrawnDebt,
      expectedPremiumDebt,
      'after drawn debt accrual'
    );
    assertEq(
      hub1.getSpokeAddedShares(assetId, address(treasurySpoke)),
      hub1.previewAddByAssets(assetId, expectedTreasuryFees),
      'treasury fees after drawn debt accrual'
    );

    _assertHubLiquidity(hub1, reserveId, 'spoke1.accrueLiquidityFee');
  }

  // disabling an asset as collateral raises the user’s risk premium, but fees use the old value until the action is executed.
  function test_accrueLiquidityFee_setUsingAsCollateral() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 reserveId2 = _wethReserveId(spoke1);
    uint256 assetId = spoke1.getReserve(reserveId).assetId;

    uint24 expectedRp = 10_00;
    _updateCollateralRisk(spoke1, reserveId, expectedRp);
    // 50.00% premium for second collateral asset
    _updateCollateralRisk(spoke1, reserveId2, 50_00);
    uint256 liquidityFee = 5_00;
    updateLiquidityFee(hub1, assetId, liquidityFee);
    updateLiquidityFee(hub1, spoke1.getReserve(reserveId2).assetId, liquidityFee);

    uint256 borrowAmount = 1000e18;
    // supply way more than needed to cover borrow amount
    uint256 supplyAmount = _calcMinimumCollAmount(spoke1, reserveId, reserveId, borrowAmount) * 2;
    uint256 supplyAmount2 = _calcMinimumCollAmount(spoke1, reserveId2, reserveId, borrowAmount) * 2;
    uint256 rate = 50_00; // 50.00% base borrow rate
    uint256 expectedDrawnDebtAccrual = borrowAmount.percentMulUp(rate);
    uint256 expectedDrawnDebt = borrowAmount + expectedDrawnDebtAccrual;
    uint256 expectedPremiumDebt = expectedDrawnDebtAccrual.percentMulUp(expectedRp);
    uint256 expectedTreasuryFees = (expectedDrawnDebtAccrual + expectedPremiumDebt).percentMulUp(
      liquidityFee
    );

    _mockInterestRateBps(rate);

    Utils.supplyCollateral(spoke1, reserveId, alice, supplyAmount, alice);
    Utils.supplyCollateral(spoke1, reserveId2, alice, supplyAmount2, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    assertEq(_getUserRpStored(spoke1, alice), expectedRp);

    skip(365 days);
    Utils.mintFeeShares(hub1, assetId, ADMIN);

    _assertSpokeDebt(
      spoke1,
      reserveId,
      expectedDrawnDebt,
      expectedPremiumDebt,
      'after base and premium debt accrual'
    );
    assertEq(
      hub1.getSpokeAddedShares(assetId, address(treasurySpoke)),
      hub1.previewAddByAssets(assetId, expectedTreasuryFees),
      'treasury fees'
    );

    // disable second asset as collateral, which increases risk premium
    vm.prank(alice);
    spoke1.setUsingAsCollateral(reserveId, false, alice);
    assertEq(_getUserRpStored(spoke1, alice), 50_00);

    Utils.mintFeeShares(hub1, assetId, ADMIN);

    // no change in treasury fees
    _assertSpokeDebt(
      spoke1,
      reserveId,
      expectedDrawnDebt,
      expectedPremiumDebt,
      'after base and premium debt accrual'
    );
    assertEq(
      hub1.getSpokeAddedShares(assetId, address(treasurySpoke)),
      hub1.previewAddByAssets(assetId, expectedTreasuryFees),
      'treasury fees after base and premium debt accrual'
    );

    _assertHubLiquidity(hub1, reserveId, 'spoke1.accrueLiquidityFee');
  }

  /// 100.00% liquidity fee redirect all liquidity growth to fee receiver and nothing to suppliers
  function test_accrueLiquidityFee_maxLiquidityFee() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 assetId = spoke1.getReserve(reserveId).assetId;

    uint256 liquidityFee = 100_00;
    updateLiquidityFee(hub1, assetId, liquidityFee);

    uint256 borrowAmount = 1000e18;
    uint256 supplyAmount = _calcMinimumCollAmount(spoke1, reserveId, reserveId, borrowAmount);
    uint256 rate = 50_00; // 50.00% base borrow rate
    uint256 expectedDrawnDebtAccrual = borrowAmount.percentMulUp(rate);
    uint256 expectedDrawnDebt = borrowAmount + expectedDrawnDebtAccrual;
    uint256 expectedPremiumDebt = expectedDrawnDebtAccrual.percentMulUp(
      _getCollateralRisk(spoke1, reserveId)
    );
    uint256 expectedTreasuryFees = (expectedDrawnDebtAccrual + expectedPremiumDebt).percentMulUp(
      liquidityFee
    );
    _mockInterestRateBps(rate);

    Utils.supplyCollateral(spoke1, reserveId, alice, supplyAmount, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    skip(365 days);
    Utils.mintFeeShares(hub1, assetId, ADMIN);

    _assertSpokeDebt(
      spoke1,
      reserveId,
      expectedDrawnDebt,
      expectedPremiumDebt,
      'after base and premium debt accrual'
    );
    assertEq(
      hub1.getSpokeAddedShares(assetId, address(treasurySpoke)),
      hub1.previewAddByAssets(assetId, expectedTreasuryFees),
      'treasury fees after base and premium debt accrual'
    );

    assertEq(
      spoke1.getUserSuppliedAssets(reserveId, alice),
      supplyAmount,
      'alice does not earn anything'
    );
    assertEq(
      hub1.getSpokeAddedAssets(assetId, address(treasurySpoke)),
      expectedDrawnDebtAccrual + expectedPremiumDebt,
      'treasury all accumulated interest'
    );

    _assertHubLiquidity(hub1, reserveId, 'spoke1.accrueLiquidityFee');
  }
}
