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
    assertEq(
      totalAssetsAfter,
      totalAssetsBefore + totalInterest,
      'total added assets = initial + all interest'
    );

    uint256 bobAssetsAfter = hub1.previewRemoveByShares(daiAssetId, bobShares);
    assertGe(bobAssetsAfter, bobAssetsBefore, 'bob assets increased');
    assertLe(accruedFees, totalInterest, 'fees do not exceed total interest');

    {
      assertEq(
        totalInterest,
        totalAssetsAfter - totalAssetsBefore,
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

  /// @dev 50% fee, 1 year skip
  function test_accrual_exact_50pctFee_1year() public {
    test_accrual_fuzz_basicAccrual(1000e18, 500e18, 50_00, 365 days);
  }

  /// @dev 10% fee, 30 days skip
  function test_accrual_exact_10pctFee_30days() public {
    test_accrual_fuzz_basicAccrual(2000e18, 800e18, 10_00, 30 days);
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

  /// @dev Tests fee accrual with small amounts, where growth is at most 1 wei
  function test_accrual_fuzz_smallAmounts(uint256 initialDrawnDebt) public {
    initialDrawnDebt = bound(initialDrawnDebt, 1, 10);

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: 100,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: initialDrawnDebt,
      skipTime: 365 days
    });

    uint256 drawnDebt = getAssetDrawnDebt(daiAssetId);
    uint256 totalInterest = drawnDebt - initialDrawnDebt;
    uint256 liquidityFee = hub1.getAsset(daiAssetId).liquidityFee;

    // With such small amounts, interest is at most 1 wei and fees round to 0
    assertLe(totalInterest, 1);
    assertEq(_getFeeReceiverAddedAssets(hub1, daiAssetId), 0);
    assertApproxEqAbs(drawnDebt, initialDrawnDebt, 1);
    assertEq(totalInterest.percentMulDown(liquidityFee), 0);
    assertEq(_calcUnrealizedFees(hub1, daiAssetId), 0);
  }

  /// @dev Tests fee accrual with swept, deficit, and drawn
  function test_accrual_combinedScenario_exactNumbers() public {
    // Setup: 1000 supply, 10% fee, 100 swept, 400 drawn, 30 deficit
    updateLiquidityFee(hub1, daiAssetId, 10_00);

    address reinvestmentController = vm.randomAddress();
    updateAssetReinvestmentController(hub1, daiAssetId, reinvestmentController);

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: 1000e18,
      user: bob
    });

    uint256 swept = 100e18;
    vm.prank(reinvestmentController);
    hub1.sweep(daiAssetId, swept);

    _drawLiquidityFromSpoke({
      spoke: address(spoke1),
      assetId: daiAssetId,
      reserveId: _daiReserveId(spoke1),
      amount: 400e18,
      skipTime: 180 days
    });

    uint256 reportedDeficit = 30e18;
    uint256 preReportIndex = hub1.getAssetDrawnIndex(daiAssetId);
    uint256 preReportDrawnShares = hub1.getAssetDrawnShares(daiAssetId);

    vm.prank(address(spoke1));
    hub1.reportDeficit(daiAssetId, reportedDeficit, ZERO_PREMIUM_DELTA);

    uint256 deficitShares = hub1.previewRestoreByAssets(daiAssetId, reportedDeficit);
    uint256 expectedDeficitRay = deficitShares * preReportIndex;
    uint256 expectedDrawnShares = preReportDrawnShares - deficitShares;

    skip(180 days);

    // Fee receiver value = unrealized fees (no minted shares yet typically)
    // Note: _drawLiquidityFromSpoke also triggers accrue which mints fee shares
    uint256 accruedFees = _getFeeReceiverAddedAssets(hub1, daiAssetId);
    assertGt(accruedFees, 0);

    IHub.Asset memory asset = hub1.getAsset(daiAssetId);
    assertEq(asset.swept, swept);
    assertApproxEqAbs(asset.deficitRay, expectedDeficitRay, 1);
    assertEq(asset.drawnShares, expectedDrawnShares);
  }

  /// @dev Fuzz test with swept, deficit, and drawn
  function test_fuzz_accrual_combinedScenario(
    uint256 supplyAmount,
    uint256 sweepAmount,
    uint256 borrowAmount,
    uint256 deficitAmount,
    uint256 liquidityFee,
    uint256 timeSkip
  ) public {
    supplyAmount = bound(supplyAmount, 100e18, MAX_SUPPLY_AMOUNT / 2);
    sweepAmount = bound(sweepAmount, 0, supplyAmount / 4);
    borrowAmount = bound(borrowAmount, 1e18, (supplyAmount - sweepAmount) / 2);
    deficitAmount = bound(deficitAmount, 0, borrowAmount / 10);
    liquidityFee = bound(liquidityFee, 1, PercentageMath.PERCENTAGE_FACTOR);
    timeSkip = bound(timeSkip, 1 days, MAX_SKIP_TIME / 2);

    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    address reinvestmentController = vm.randomAddress();
    updateAssetReinvestmentController(hub1, daiAssetId, reinvestmentController);

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: supplyAmount,
      user: bob
    });

    // Sweep if amount > 0
    if (sweepAmount > 0) {
      vm.prank(reinvestmentController);
      hub1.sweep(daiAssetId, sweepAmount);
    }

    _drawLiquidityFromSpoke({
      spoke: address(spoke1),
      assetId: daiAssetId,
      reserveId: _daiReserveId(spoke1),
      amount: borrowAmount,
      skipTime: timeSkip
    });

    // Report deficit if amount > 0
    if (deficitAmount > 0) {
      vm.prank(address(spoke1));
      hub1.reportDeficit(daiAssetId, deficitAmount, ZERO_PREMIUM_DELTA);
    }

    skip(timeSkip);

    // Fee receiver gets fees - verify it's positive with fees enabled
    uint256 accruedFees = _getFeeReceiverAddedAssets(hub1, daiAssetId);
    // With liquidityFee >= 1 and time passed, there should be some fees
    if (liquidityFee > 0 && timeSkip > 0) {
      assertGt(accruedFees, 0);
    }
  }

  /// @dev Verifies fees >= protocol cut over multiple iterations
  function test_accrual_accountingInvariant() public {
    uint256 liquidityFee = 20_00;
    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT,
      user: bob
    });

    uint256 lastSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);

    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: bob,
      caller: address(spoke1),
      amount: BORROW_AMOUNT
    });

    for (uint256 i = 0; i < 5; i++) {
      (uint256 debtBefore, ) = hub1.getAssetOwed(daiAssetId);
      skip(322 days);
      (uint256 debtAfter, ) = hub1.getAssetOwed(daiAssetId);
      uint256 interestGrowth = debtAfter - debtBefore;
      uint256 protocolCut = interestGrowth.percentMulDown(liquidityFee);
      uint256 unrealizedFees = _calcUnrealizedFees(hub1, daiAssetId);

      assertGe(unrealizedFees, protocolCut);

      // Trigger accrual to convert unrealized -> realized fees (minted as shares to fee receiver)
      Utils.add({
        hub: hub1,
        assetId: daiAssetId,
        caller: address(spoke1),
        amount: 1e18,
        user: alice
      });

      // In the new fee system, fees are tracked via fee receiver shares
      uint256 feeReceiverShares = _getFeeReceiverAddedShares(hub1, daiAssetId);
      assertGt(feeReceiverShares, 0);

      uint256 currentSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);
      _checkSupplyRateIncreasing(lastSharePrice, currentSharePrice, 'share price');
      lastSharePrice = currentSharePrice;
    }
  }

  /// @dev Tests 90% fee gives 90% to treasury and 10% to suppliers
  function test_accrual_90_10_split() public {
    updateLiquidityFee(hub1, daiAssetId, 90_00);

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT,
      user: bob
    });
    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: bob,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT
    });

    skip(365 days);

    (uint256 drawnDebtAfter, ) = hub1.getAssetOwed(daiAssetId);
    uint256 totalDelta = drawnDebtAfter - SUPPLY_AMOUNT;
    uint256 expectedProtocolCut = totalDelta.percentMulDown(90_00);

    // Fee receiver value = unrealized fees (no minted shares yet)
    uint256 accruedFees = _getFeeReceiverAddedAssets(hub1, daiAssetId);

    assertApproxEqAbs(accruedFees, expectedProtocolCut, 3);

    // Supplier yield = total added assets - initial supply - fee portion
    // Note: getAddedAssets includes all interest, we need to subtract fees
    uint256 totalAddedAssets = hub1.getAddedAssets(daiAssetId);
    uint256 supplierYield = totalAddedAssets - SUPPLY_AMOUNT - accruedFees;
    assertApproxEqAbs(supplierYield, totalDelta.percentMulDown(10_00), 3);

    assertApproxEqAbs(accruedFees + supplierYield, totalDelta, 3);
  }

  /// @dev Verifies exact fee formula: first accrual fees = protocolCut when no prior fees
  function test_fuzz_accrual_firstAccrual_matches_protocolCut(
    uint256 supplyAmount,
    uint256 borrowAmount,
    uint256 liquidityFee,
    uint256 skipTime
  ) public {
    supplyAmount = bound(supplyAmount, 2, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, supplyAmount);
    liquidityFee = bound(liquidityFee, 1, PercentageMath.PERCENTAGE_FACTOR);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    Utils.add({
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

    // Initially no fee shares exist
    uint256 initialFeeReceiverShares = _getFeeReceiverAddedShares(hub1, daiAssetId);
    assertEq(initialFeeReceiverShares, 0);

    skip(skipTime);

    (uint256 drawnDebtAfter, ) = hub1.getAssetOwed(daiAssetId);
    uint256 delta = drawnDebtAfter - borrowAmount;
    uint256 expectedProtocolCut = delta.percentMulDown(liquidityFee);
    uint256 accruedFees = _getFeeReceiverAddedAssets(hub1, daiAssetId);

    // First accrual with no prior fees: fees = protocolCut approximately
    assertApproxEqAbs(accruedFees, expectedProtocolCut, 5);

    // Supplier yield = total added assets - initial supply - fee portion
    uint256 totalAddedAssets = hub1.getAddedAssets(daiAssetId);
    uint256 supplierYield = totalAddedAssets - supplyAmount - accruedFees;
    uint256 expectedSupplierYield = delta - expectedProtocolCut;
    assertApproxEqAbs(supplierYield, expectedSupplierYield, 5);

    assertApproxEqAbs(accruedFees + supplierYield, delta, 5);
  }

  /// @dev Tests fee accrual pattern with prior accrued fees
  function test_accrual_fuzz_withPriorRealizedFees(uint256 liquidityFee, uint256 skipTime) public {
    liquidityFee = bound(liquidityFee, 1, PercentageMath.PERCENTAGE_FACTOR);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT,
      user: bob
    });
    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: bob,
      caller: address(spoke1),
      amount: BORROW_AMOUNT
    });

    skip(skipTime);

    // Trigger first accrual - mints fee shares to fee receiver
    Utils.add({hub: hub1, assetId: daiAssetId, caller: address(spoke1), amount: 1e18, user: alice});

    // Fee receiver should now have shares (the "realized" fees are now shares)
    uint256 feeReceiverSharesAfterFirst = _getFeeReceiverAddedShares(hub1, daiAssetId);
    assertGt(feeReceiverSharesAfterFirst, 0);

    (uint256 drawnDebtBefore, ) = hub1.getAssetOwed(daiAssetId);
    IHub.Asset memory assetBefore = hub1.getAsset(daiAssetId);
    uint256 totalAssetsBefore = _calcSuppliersTotalAddedAssets(assetBefore);

    skip(skipTime / 2);

    (uint256 drawnDebtAfter, ) = hub1.getAssetOwed(daiAssetId);
    uint256 delta = drawnDebtAfter - drawnDebtBefore;
    uint256 protocolCut = delta.percentMulDown(liquidityFee);
    uint256 interest = delta - protocolCut;

    // Fee receiver assets value should grow proportionally with other suppliers
    uint256 feeReceiverValueBefore = hub1.previewRemoveByShares(
      daiAssetId,
      feeReceiverSharesAfterFirst
    );
    uint256 expectedInterestForFees = interest.mulDivUp(
      feeReceiverValueBefore,
      totalAssetsBefore + SharesMath.VIRTUAL_ASSETS
    );

    uint256 totalFeeReceiverAssets = _getFeeReceiverAddedAssets(hub1, daiAssetId);
    uint256 currentUnrealizedFees = _calcUnrealizedFees(hub1, daiAssetId);

    // Total fee receiver value = prior shares value + new unrealized fees (with tolerance for rounding)
    assertApproxEqAbs(totalFeeReceiverAssets, feeReceiverValueBefore + currentUnrealizedFees, 5);

    if (interest == 0 || feeReceiverValueBefore == 0) {
      assertEq(expectedInterestForFees, 0);
    } else {
      assertGe(expectedInterestForFees, 1);
    }

    uint256 interestForSuppliers = interest - expectedInterestForFees;
    assertApproxEqAbs(protocolCut + expectedInterestForFees + interestForSuppliers, delta, 1);
  }

  /// @dev When user assets equal treasury's fee shares, both should earn interest at same rate
  function test_accrual_interestDistributedByAssetProportion() public {
    updateLiquidityFee(hub1, daiAssetId, 10_00);

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT,
      user: bob
    });
    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: bob,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT
    });

    skip(365 days);

    Utils.add({hub: hub1, assetId: daiAssetId, caller: address(spoke1), amount: 1e18, user: alice});
    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);

    uint256 treasuryShares = _getFeeReceiverAddedShares(hub1, daiAssetId);
    uint256 treasuryAssetsBefore = hub1.previewRemoveByShares(daiAssetId, treasuryShares);
    assertGt(treasuryAssetsBefore, 0);

    Utils.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: carol,
      amount: treasuryAssetsBefore,
      onBehalfOf: carol
    });

    uint256 carolAssetsBefore = spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), carol);
    assertApproxEqAbs(carolAssetsBefore, treasuryAssetsBefore, 1);

    skip(180 days);

    uint256 carolAssetsAfter = spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), carol);

    // Get treasury assets (minted shares only, not unrealized)
    uint256 treasurySharesAfter = _getFeeReceiverAddedShares(hub1, daiAssetId);
    uint256 treasuryAssetsAfter = hub1.previewRemoveByShares(daiAssetId, treasurySharesAfter);

    uint256 carolGrowth = carolAssetsAfter - carolAssetsBefore;
    uint256 treasuryGrowth = treasuryAssetsAfter - treasuryAssetsBefore;

    assertGt(carolGrowth, 0);
    assertGt(treasuryGrowth, 0);
    // Treasury and Carol start with same assets and shares, so growth should be equal
    // But treasury also gets new unrealized fees, so treasury growth >= carol growth
    assertGe(treasuryGrowth, carolGrowth);
  }

  /// @dev Tests multiple borrow/repay cycles, verifies share price increases each cycle
  function test_accrual_repeatedCycles() public {
    updateLiquidityFee(hub1, daiAssetId, 50_00);

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT,
      user: bob
    });

    uint256 lastSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);

    for (uint256 cycle = 0; cycle < 3; cycle++) {
      Utils.draw({
        hub: hub1,
        assetId: daiAssetId,
        to: bob,
        caller: address(spoke1),
        amount: BORROW_AMOUNT
      });

      skip(120 days);

      (uint256 totalOwed, ) = hub1.getAssetOwed(daiAssetId);
      Utils.restoreDrawn({
        hub: hub1,
        assetId: daiAssetId,
        caller: address(spoke1),
        drawnAmount: totalOwed,
        restorer: bob
      });

      uint256 currentSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);
      _checkSupplyRateIncreasing(lastSharePrice, currentSharePrice, 'share price');
      lastSharePrice = currentSharePrice;
    }

    uint256 finalFeeReceiverAssets = _getFeeReceiverAddedAssets(hub1, daiAssetId);
    uint256 feeReceiverShares = _getFeeReceiverAddedShares(hub1, daiAssetId);
    uint256 feeReceiverShareValue = hub1.previewRemoveByShares(daiAssetId, feeReceiverShares);
    uint256 unrealizedFees = _calcUnrealizedFees(hub1, daiAssetId);

    // Fee receiver total assets = share value + unrealized fees
    assertApproxEqAbs(finalFeeReceiverAssets, feeReceiverShareValue + unrealizedFees, 3);
    assertGt(finalFeeReceiverAssets, 0);
  }

  /// @dev Fuzz: Share price growth bounded by debt growth, minting doesn't cause sharp jump
  function test_fuzz_accrual_gradualSharePriceGrowth(
    uint256 supplyAmount,
    uint256 borrowAmount,
    uint256 liquidityFee,
    uint256 timeSkip
  ) public {
    supplyAmount = bound(supplyAmount, 1e18, MAX_SUPPLY_AMOUNT / 2);
    borrowAmount = bound(borrowAmount, 1, supplyAmount / 2);
    liquidityFee = bound(liquidityFee, 1, PercentageMath.PERCENTAGE_FACTOR);
    timeSkip = bound(timeSkip, 1 days, MAX_SKIP_TIME);

    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    Utils.add({
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

    uint256 lastSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);
    (uint256 lastDebt, ) = hub1.getAssetOwed(daiAssetId);

    // Each period: share price growth should not exceed debt growth
    uint256 skipPerPeriod = timeSkip / 12;
    for (uint256 i = 0; i < 12; ++i) {
      skip(skipPerPeriod);
      uint256 currentSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);
      (uint256 currentDebt, ) = hub1.getAssetOwed(daiAssetId);

      _checkSupplyRateIncreasing(lastSharePrice, currentSharePrice, 'share price');

      uint256 debtGrowthBps = (currentDebt - lastDebt).mulDivDown(
        PercentageMath.PERCENTAGE_FACTOR,
        lastDebt
      );
      uint256 sharePriceGrowthBps = (currentSharePrice - lastSharePrice).mulDivDown(
        PercentageMath.PERCENTAGE_FACTOR,
        lastSharePrice
      );
      assertLe(sharePriceGrowthBps, debtGrowthBps);

      // Accrue occasionally to test share price growth while fees are earning interest
      if (i % 4 == 3) {
        Utils.add({
          hub: hub1,
          assetId: daiAssetId,
          caller: address(spoke1),
          amount: 1e18,
          user: alice
        });
      }

      lastSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);
      (lastDebt, ) = hub1.getAssetOwed(daiAssetId);
    }

    // Minting should not cause sharp jump
    uint256 preMintSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);
    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);
    uint256 postMintSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);

    assertApproxEqAbs(
      postMintSharePrice,
      preMintSharePrice,
      minimumAssetsPerAddedShare(hub1, daiAssetId)
    );
    assertEq(_calcUnrealizedFees(hub1, daiAssetId), 0);
  }

  /// @dev Fuzz test ensuring fees never exceed total interest accrued
  function test_fuzz_accrual_feesNeverExceedInterest(
    uint256 supplyAmount,
    uint256 borrowAmount,
    uint256 liquidityFee,
    uint256 timeSkip
  ) public {
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, supplyAmount);
    liquidityFee = bound(liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR);
    timeSkip = bound(timeSkip, 1 days, MAX_SKIP_TIME);

    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: supplyAmount,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: borrowAmount,
      skipTime: timeSkip
    });

    uint256 accruedFees = _getFeeReceiverAddedAssets(hub1, daiAssetId);
    (uint256 drawnDebt, ) = hub1.getAssetOwed(daiAssetId);
    uint256 totalInterest = drawnDebt - borrowAmount;

    // Fees should never exceed total interest
    assertLe(accruedFees, totalInterest + 3); // tolerance for rounding

    if (liquidityFee == 0) assertEq(accruedFees, 0);
    if (liquidityFee == PercentageMath.PERCENTAGE_FACTOR && totalInterest > 0) {
      // With 100% fee, all interest goes to protocol
      assertApproxEqAbs(accruedFees, totalInterest, 3);
    }
  }

  /// @dev Fuzz test verifying zero fee rate directs all interest to suppliers
  function test_fuzz_zeroFeeAllToSuppliers(uint256 supplyAmount, uint256 borrowAmount) public {
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, supplyAmount);

    updateLiquidityFee(hub1, daiAssetId, 0);

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: supplyAmount,
      user: bob
    });
    uint256 initialTotalAssets = hub1.getAddedAssets(daiAssetId);

    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: bob,
      caller: address(spoke1),
      amount: borrowAmount
    });
    skip(365 days);

    uint256 accruedFees = _getFeeReceiverAddedAssets(hub1, daiAssetId);
    (uint256 drawnDebt, ) = hub1.getAssetOwed(daiAssetId);
    uint256 totalInterest = drawnDebt - borrowAmount;
    uint256 finalTotalAssets = hub1.getAddedAssets(daiAssetId);

    assertEq(accruedFees, 0);
    assertEq(accruedFees, _calcUnrealizedFees(hub1, daiAssetId));
    assertEq(finalTotalAssets - initialTotalAssets, totalInterest);
  }

  /// @dev Fuzz test verifying 100% fee rate directs all interest to treasury
  function test_fuzz_maxFeeAllToTreasury(uint256 supplyAmount, uint256 borrowAmount) public {
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, supplyAmount);

    updateLiquidityFee(hub1, daiAssetId, PercentageMath.PERCENTAGE_FACTOR);

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: supplyAmount,
      user: bob
    });
    uint256 initialSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);

    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: bob,
      caller: address(spoke1),
      amount: borrowAmount
    });
    skip(365 days);

    uint256 accruedFees = _getFeeReceiverAddedAssets(hub1, daiAssetId);
    (uint256 drawnDebt, ) = hub1.getAssetOwed(daiAssetId);
    uint256 totalInterest = drawnDebt - borrowAmount;
    uint256 finalSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);

    assertEq(accruedFees, totalInterest);
    assertEq(accruedFees, _calcUnrealizedFees(hub1, daiAssetId));
    assertEq(finalSharePrice, initialSharePrice);

    // All fees go to protocol and none to suppliers, no interest on realizedFees to distribute
    uint256 protocolCut = totalInterest.percentMulDown(PercentageMath.PERCENTAGE_FACTOR);
    assertEq(accruedFees, protocolCut);

    uint256 supplierYield = hub1.getAddedAssets(daiAssetId) - supplyAmount;
    assertEq(supplierYield, accruedFees); // all supplier yield goes to treasury spoke
  }

  /// @dev Fuzz: Users earn same interest per share regardless of liquidityFee
  function test_fuzz_interestIndependentOfLiquidityFee(
    uint256 supplyAmount,
    uint256 borrowAmount,
    uint256 liquidityFee,
    uint256 timeSkipFirst,
    uint256 newSupplyAmount,
    uint256 timeSkipSecond
  ) public {
    supplyAmount = bound(supplyAmount, 1e18, MAX_SUPPLY_AMOUNT / 2);
    borrowAmount = bound(borrowAmount, 1, supplyAmount / 2);
    liquidityFee = bound(liquidityFee, 1, PercentageMath.PERCENTAGE_FACTOR / 2);
    timeSkipFirst = bound(timeSkipFirst, 1 days, MAX_SKIP_TIME / 2);
    newSupplyAmount = bound(newSupplyAmount, 1e18, MAX_SUPPLY_AMOUNT / 2);
    timeSkipSecond = bound(timeSkipSecond, 1 days, MAX_SKIP_TIME / 2);

    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    Utils.add({
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

    skip(timeSkipFirst);
    uint256 accruedFeeShares = _calcUnrealizedFeeShares(hub1, daiAssetId);

    // Alice joins when realizedFees may be large
    uint256 bobSharesBefore = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: newSupplyAmount,
      user: alice
    });
    uint256 aliceShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1)) - bobSharesBefore;
    uint256 feeReceiverAddedShares = _getFeeReceiverAddedShares(hub1, daiAssetId);

    assertEq(feeReceiverAddedShares, accruedFeeShares, 'fee receiver added shares');
    assertEq(_calcUnrealizedFeeShares(hub1, daiAssetId), 0);
    assertEq(_calcUnrealizedFees(hub1, daiAssetId), 0);

    // double the liquidity fee
    updateLiquidityFee(hub1, daiAssetId, liquidityFee * 2);

    // Carol joins when liquidity fee is doubled
    uint256 sharesBeforeCarol = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: newSupplyAmount,
      user: carol
    });
    uint256 carolShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1)) - sharesBeforeCarol;

    // Same supply should yield same shares
    assertEq(aliceShares, carolShares);

    uint256 aliceValueBefore = hub1.previewRemoveByShares(daiAssetId, aliceShares);
    uint256 carolValueBefore = hub1.previewRemoveByShares(daiAssetId, carolShares);

    skip(timeSkipSecond);
    accruedFeeShares = _calcUnrealizedFeeShares(hub1, daiAssetId);

    uint256 aliceGrowth = hub1.previewRemoveByShares(daiAssetId, aliceShares) - aliceValueBefore;
    uint256 carolGrowth = hub1.previewRemoveByShares(daiAssetId, carolShares) - carolValueBefore;

    // Both should earn same interest (same shares = same growth)
    assertEq(aliceGrowth, carolGrowth);
    assertEq(
      _getFeeReceiverAddedShares(hub1, daiAssetId) - feeReceiverAddedShares,
      accruedFeeShares,
      'accrued fee shares from second time skip'
    );
  }
}
