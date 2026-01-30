// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubAccruedFeesTest is HubBase {
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  uint256 constant SUPPLY_AMOUNT = 1000e18;
  uint256 constant BORROW_AMOUNT = 500e18;

  function test_unrealizedFees_fuzz_basicAccrual(uint256 liquidityFee, uint256 skipTime) public {
    liquidityFee = bound(liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR);
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

    uint256 totalAssetsBefore = hub1.getAddedAssets(daiAssetId);

    skip(skipTime);

    (uint256 drawnDebt, ) = hub1.getAssetOwed(daiAssetId);
    uint256 totalInterest = drawnDebt - BORROW_AMOUNT;
    uint256 accruedFees = hub1.getAssetAccruedFees(daiAssetId);
    uint256 expectedAccruedFees = _calcUnrealizedFees(hub1, daiAssetId);

    assertEq(accruedFees, expectedAccruedFees);

    uint256 supplierInterest = totalInterest - accruedFees;
    uint256 totalAssetsAfter = hub1.getAddedAssets(daiAssetId);
    assertEq(totalAssetsAfter, totalAssetsBefore + supplierInterest);
  }

  /// @dev Verifies protocol cut rounds to 0 when interest is tiny, all goes to suppliers
  function test_unrealizedFees_roundsToZero() public {
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
    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);
    uint256 finalSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);

    assertEq(delta.percentMulDown(liquidityFee), 0);
    assertEq(accruedFees, 0);
    assertEq(hub1.getAssetAccruedFees(daiAssetId), 0);
    assertGt(delta, 0);
    assertGt(finalSharePrice, initialSharePrice);
  }

  function test_unrealizedFees_feesEarnInterest() public {
    updateLiquidityFee(hub1, daiAssetId, 50_00);

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

    skip(180 days);
    uint256 fees1 = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);
    assertGt(fees1, 0);

    uint256 expectedFees = _calcUnrealizedFees(hub1, daiAssetId);
    assertEq(hub1.getAssetAccruedFees(daiAssetId), expectedFees);

    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);
    assertEq(hub1.getAsset(daiAssetId).realizedFees, 0);

    skip(180 days);

    assertGt(_getExpectedFeeReceiverAddedAssets(hub1, daiAssetId), 0);

    expectedFees = _calcUnrealizedFees(hub1, daiAssetId);
    assertEq(hub1.getAssetAccruedFees(daiAssetId), expectedFees);
  }

  /// @dev Tests fee accrual with small amounts, where growth is 1 wei
  function test_unrealizedFees_fuzz_smallAmounts(uint256 initialDrawnDebt) public {
    initialDrawnDebt = bound(initialDrawnDebt, 1, 10);
    uint256 initialDrawnIndex = hub1.getAssetDrawnIndex(daiAssetId);
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

    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);
    uint256 drawnDebt = getAssetDrawnDebt(daiAssetId);
    uint256 totalInterest = drawnDebt - initialDrawnDebt;

    // growth is 1 wei at most
    assertLe(totalInterest, 1);

    uint256 drawnIndex = hub1.getAssetDrawnIndex(daiAssetId);
    uint256 liquidityFee = hub1.getAssetConfig(daiAssetId).liquidityFee;

    uint256 expectedTotalInterest = drawnIndex.rayMulUp(initialDrawnDebt) -
      initialDrawnIndex.rayMulUp(initialDrawnDebt);

    assertEq(expectedTotalInterest, totalInterest);
    assertEq(drawnDebt, initialDrawnDebt + expectedTotalInterest);
    assertEq(accruedFees, totalInterest.percentMulDown(liquidityFee));
  }

  /// @dev Tests fee accrual with swept, deficit, and drawn
  function test_unrealizedFees_combinedScenario_exactNumbers() public {
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

    uint256 realizedFees = hub1.getAsset(daiAssetId).realizedFees;
    uint256 expectedAccruedFees = realizedFees + _calcUnrealizedFees(hub1, daiAssetId);
    uint256 accruedFees = hub1.getAssetAccruedFees(daiAssetId);

    assertEq(accruedFees, expectedAccruedFees);
    assertGt(accruedFees, 0);

    IHub.Asset memory asset = hub1.getAsset(daiAssetId);
    assertEq(asset.swept, swept);
    assertEq(asset.deficitRay, expectedDeficitRay);
    assertEq(asset.drawnShares, expectedDrawnShares);
  }

  /// @dev Fuzz test with swept, deficit, and drawn
  function testFuzz_unrealizedFees_combinedScenario(
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

    uint256 realizedFees = hub1.getAsset(daiAssetId).realizedFees;
    uint256 expectedAccruedFees = realizedFees + _calcUnrealizedFees(hub1, daiAssetId);
    uint256 accruedFees = hub1.getAssetAccruedFees(daiAssetId);
    assertEq(accruedFees, expectedAccruedFees);
  }

  /// @dev Verifies fees >= protocol cut and share price increases
  function test_unrealizedFees_accountingInvariant() public {
    updateLiquidityFee(hub1, daiAssetId, 20_00);

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT,
      user: bob
    });
    uint256 initialSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);

    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: bob,
      caller: address(spoke1),
      amount: BORROW_AMOUNT
    });
    skip(365 days);

    (uint256 drawnDebt, ) = hub1.getAssetOwed(daiAssetId);
    uint256 totalDelta = drawnDebt - BORROW_AMOUNT;
    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);
    uint256 expectedAccruedFees = _calcUnrealizedFees(hub1, daiAssetId);
    assertEq(accruedFees, expectedAccruedFees);

    uint256 protocolCut = (totalDelta * 20_00) / 100_00;
    assertGe(accruedFees, protocolCut);
    assertGt(hub1.previewAddByShares(daiAssetId, 1e18), initialSharePrice);
  }

  /// @dev Tests 90% fee with 100% utilization, verifies 90/10 split between fees and suppliers
  function test_unrealizedFees_highFeeFullUtilization() public {
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

    uint256 sharePriceBefore = hub1.previewAddByShares(daiAssetId, 1e18);
    skip(365 days);

    (uint256 drawnDebtAfter, ) = hub1.getAssetOwed(daiAssetId);
    uint256 totalDelta = drawnDebtAfter - SUPPLY_AMOUNT;
    uint256 expectedProtocolCut = (totalDelta * 90_00) / 100_00;
    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);

    assertEq(accruedFees, _calcUnrealizedFees(hub1, daiAssetId));
    assertEq(accruedFees, expectedProtocolCut);
    assertEq(accruedFees, (totalDelta * 90) / 100);

    uint256 supplierYield = hub1.getAddedAssets(daiAssetId) - SUPPLY_AMOUNT;
    assertEq(supplierYield, (totalDelta * 10) / 100);
    assertEq(accruedFees + supplierYield, totalDelta);
    assertGt(hub1.previewAddByShares(daiAssetId, 1e18), sharePriceBefore);

    uint256 supplierAssetsBefore = hub1.previewRemoveByShares(
      daiAssetId,
      hub1.getSpokeAddedShares(daiAssetId, address(spoke1))
    );
    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);
    uint256 supplierAssetsAfter = hub1.previewRemoveByShares(
      daiAssetId,
      hub1.getSpokeAddedShares(daiAssetId, address(spoke1))
    );
    assertEq(supplierAssetsAfter, supplierAssetsBefore);
  }

  /// @dev Tests 5 years of fee accumulation, verifies fees grow and mint doesn't dilute suppliers
  function test_unrealizedFees_longTermAccumulation() public {
    updateLiquidityFee(hub1, daiAssetId, 50_00);

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

    uint256 lastSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);
    uint256 cumulativeProtocolCut = 0;

    for (uint256 year = 0; year < 5; year++) {
      (uint256 debtBefore, ) = hub1.getAssetOwed(daiAssetId);
      skip(365 days);
      (uint256 debtAfter, ) = hub1.getAssetOwed(daiAssetId);
      cumulativeProtocolCut += ((debtAfter - debtBefore) * 50_00) / 100_00;

      uint256 currentSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);
      assertGt(currentSharePrice, lastSharePrice);
      lastSharePrice = currentSharePrice;
    }

    uint256 finalFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId) +
      hub1.getAsset(daiAssetId).realizedFees;
    assertEq(
      _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId),
      _calcUnrealizedFees(hub1, daiAssetId)
    );
    assertGe(finalFees, cumulativeProtocolCut);

    uint256 supplierSharesBefore = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    uint256 sharePriceBefore = hub1.previewAddByShares(daiAssetId, 1e18);
    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(spoke1)), supplierSharesBefore);
    assertEq(hub1.previewAddByShares(daiAssetId, 1e18), sharePriceBefore);
  }

  /// @dev Verifies exact fee formula: first accrual fees = protocolCut when no prior fees
  function test_unrealizedFees_preciseCalculation() public {
    uint256 liquidityFee = 20_00;
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

    assertEq(hub1.getAsset(daiAssetId).realizedFees, 0);
    skip(322 days);

    (uint256 drawnDebtAfter, ) = hub1.getAssetOwed(daiAssetId);
    uint256 delta = drawnDebtAfter - BORROW_AMOUNT;
    uint256 expectedProtocolCut = delta.percentMulDown(liquidityFee);
    uint256 interest = delta - expectedProtocolCut;
    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);
    assertEq(accruedFees, _calcUnrealizedFees(hub1, daiAssetId));

    // First accrual with no prior fees: fees = protocolCut exactly
    assertEq(accruedFees, expectedProtocolCut);
    uint256 supplierYield = hub1.getAddedAssets(daiAssetId) - SUPPLY_AMOUNT;
    assertEq(supplierYield, interest);
    assertEq(accruedFees + supplierYield, delta);
    assertEq(supplierYield, delta.percentMulUp(PercentageMath.PERCENTAGE_FACTOR - liquidityFee));
  }

  /// @dev Tests interestForFees calculation when realizedFees > 0 from prior accrual
  function test_unrealizedFees_withPriorRealizedFees() public {
    updateLiquidityFee(hub1, daiAssetId, 20_00);

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

    skip(180 days);
    Utils.add({hub: hub1, assetId: daiAssetId, caller: address(spoke1), amount: 1e18, user: alice});

    uint256 realizedFeesAfterFirst = hub1.getAsset(daiAssetId).realizedFees;
    assertGt(realizedFeesAfterFirst, 0);

    (uint256 drawnDebtBefore, ) = hub1.getAssetOwed(daiAssetId);
    IHub.Asset memory assetBefore = hub1.getAsset(daiAssetId);
    uint256 totalAssetsBefore = _calcTotalAddedAssets(assetBefore);

    skip(180 days);

    (uint256 drawnDebtAfter, ) = hub1.getAssetOwed(daiAssetId);
    uint256 delta = drawnDebtAfter - drawnDebtBefore;
    uint256 protocolCut = (delta * 20_00) / 100_00;
    uint256 interest = delta - protocolCut;
    uint256 expectedInterestForFees = (interest * realizedFeesAfterFirst) /
      (totalAssetsBefore + SharesMath.VIRTUAL_ASSETS);
    uint256 expectedNewUnrealizedFees = protocolCut + expectedInterestForFees;

    uint256 totalAccruedFees = hub1.getAssetAccruedFees(daiAssetId);
    assertEq(totalAccruedFees - realizedFeesAfterFirst, _calcUnrealizedFees(hub1, daiAssetId));

    assertEq(totalAccruedFees, realizedFeesAfterFirst + expectedNewUnrealizedFees);
    assertGt(expectedInterestForFees, 0);

    uint256 interestForSuppliers = interest - expectedInterestForFees;
    assertEq(totalAccruedFees - realizedFeesAfterFirst, expectedNewUnrealizedFees);
    assertEq(protocolCut + expectedInterestForFees + interestForSuppliers, delta);
  }

  /// @dev When user assets equal treasury's fee shares, both should earn interest at same rate
  function test_unrealizedFees_equalAssetsEqualGrowth() public {
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

    uint256 treasuryShares = hub1.getSpokeAddedShares(daiAssetId, address(treasurySpoke));
    uint256 treasuryAssetsBefore = hub1.previewRemoveByShares(daiAssetId, treasuryShares);
    assertGt(treasuryAssetsBefore, 0);

    uint256 bobShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: treasuryAssetsBefore,
      user: carol
    });

    uint256 carolShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1)) - bobShares;
    uint256 carolAssetsBefore = hub1.previewRemoveByShares(daiAssetId, carolShares);
    assertApproxEqAbs(carolAssetsBefore, treasuryAssetsBefore, 2);

    skip(180 days);

    uint256 carolAssetsAfter = hub1.previewRemoveByShares(daiAssetId, carolShares);
    uint256 treasuryAssetsAfter = hub1.previewRemoveByShares(daiAssetId, treasuryShares);

    uint256 carolGrowth = carolAssetsAfter - carolAssetsBefore;
    uint256 treasuryGrowth = treasuryAssetsAfter - treasuryAssetsBefore;

    assertGt(carolGrowth, 0);
    assertGt(treasuryGrowth, 0);
    assertEq(carolGrowth, treasuryGrowth);
    assertEq(
      hub1.getAssetAccruedFees(daiAssetId) - hub1.getAsset(daiAssetId).realizedFees,
      _calcUnrealizedFees(hub1, daiAssetId)
    );
  }

  /// @dev Verifies minting fee shares mid-period doesn't affect supplier's position value
  function test_unrealizedFees_mintTimingEquivalence() public {
    updateLiquidityFee(hub1, daiAssetId, 50_00);

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

    skip(180 days);

    uint256 supplierShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    uint256 supplierAssetsBeforeMint = hub1.previewRemoveByShares(daiAssetId, supplierShares);

    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);

    uint256 supplierAssetsAfterMint = hub1.previewRemoveByShares(daiAssetId, supplierShares);
    assertApproxEqAbs(supplierAssetsAfterMint, supplierAssetsBeforeMint, 1);
    assertEq(hub1.getAssetAccruedFees(daiAssetId) - hub1.getAsset(daiAssetId).realizedFees, 0);
    assertEq(_calcUnrealizedFees(hub1, daiAssetId), 0);

    skip(180 days);
    assertGt(hub1.previewRemoveByShares(daiAssetId, supplierShares), supplierAssetsAfterMint);
  }

  /// @dev Verifies new supplier gets fair share price after large fee accumulation
  function test_unrealizedFees_newSupplierAfterFeeAccumulation() public {
    updateLiquidityFee(hub1, daiAssetId, 50_00);

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

    skip(365 days);

    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);
    assertEq(accruedFees, _calcUnrealizedFees(hub1, daiAssetId));
    assertGt(accruedFees, 0);

    uint256 sharePriceBefore = hub1.previewAddByShares(daiAssetId, 1e18);
    uint256 bobShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    uint256 bobValueBefore = hub1.previewRemoveByShares(daiAssetId, bobShares);

    uint256 aliceSupply = 500e18;
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: aliceSupply,
      user: alice
    });

    uint256 aliceShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1)) - bobShares;
    uint256 aliceRedeemable = hub1.previewRemoveByShares(daiAssetId, aliceShares);
    assertApproxEqAbs(aliceRedeemable, aliceSupply, 1);

    uint256 bobValueAfter = hub1.previewRemoveByShares(daiAssetId, bobShares);
    assertApproxEqAbs(bobValueAfter, bobValueBefore, 1);
    assertApproxEqAbs(hub1.previewAddByShares(daiAssetId, 1e18), sharePriceBefore, 1);

    skip(180 days);

    (uint256 drawnDebt, ) = hub1.getAssetOwed(daiAssetId);
    assertGt(drawnDebt, BORROW_AMOUNT);

    uint256 bobFinalValue = hub1.previewRemoveByShares(daiAssetId, bobShares);
    uint256 aliceFinalValue = hub1.previewRemoveByShares(daiAssetId, aliceShares);
    assertGt(bobFinalValue, bobValueAfter);
    assertGt(aliceFinalValue, aliceRedeemable);
  }

  /// @dev Tests 90% fee with 100% utilization over 3 years, verifies mint doesn't dilute
  function test_unrealizedFees_extremeFeeAccumulation() public {
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

    uint256 initialSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);
    skip(3 * 365 days);

    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);
    uint256 realizedFees = hub1.getAsset(daiAssetId).realizedFees;
    uint256 totalFees = accruedFees + realizedFees;

    assertGt(totalFees, SUPPLY_AMOUNT / 4);
    assertEq(accruedFees, _calcUnrealizedFees(hub1, daiAssetId));

    assertGt(hub1.previewAddByShares(daiAssetId, 1e18), initialSharePrice);

    uint256 supplierSharesBefore = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    uint256 supplierValueBefore = hub1.previewRemoveByShares(daiAssetId, supplierSharesBefore);

    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(spoke1)), supplierSharesBefore);
    assertEq(hub1.previewRemoveByShares(daiAssetId, supplierSharesBefore), supplierValueBefore);
  }

  /// @dev Tests multiple borrow/repay cycles, verifies share price increases each cycle
  function test_unrealizedFees_repeatedCycles() public {
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
      assertGt(currentSharePrice, lastSharePrice);
      lastSharePrice = currentSharePrice;
    }

    uint256 finalAccruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);
    assertEq(
      finalAccruedFees - hub1.getAsset(daiAssetId).realizedFees,
      _calcUnrealizedFees(hub1, daiAssetId)
    );
    assertGt(finalAccruedFees, 0);
  }

  /// @dev Fuzz: Share price growth bounded by debt growth, minting doesn't cause sharp jump
  function testFuzz_unrealizedFees_gradualSharePriceGrowth(
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
    for (uint256 i = 0; i < 12; i++) {
      skip(skipPerPeriod);
      uint256 currentSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);
      (uint256 currentDebt, ) = hub1.getAssetOwed(daiAssetId);

      assertGe(currentSharePrice, lastSharePrice);

      uint256 debtGrowthBps = ((currentDebt - lastDebt) * PercentageMath.PERCENTAGE_FACTOR) /
        lastDebt;
      uint256 sharePriceGrowthBps = ((currentSharePrice - lastSharePrice) *
        PercentageMath.PERCENTAGE_FACTOR) / lastSharePrice;
      assertLe(sharePriceGrowthBps, debtGrowthBps);

      lastSharePrice = currentSharePrice;
      lastDebt = currentDebt;
    }

    // Minting should not cause sharp jump
    uint256 preMintSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);
    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);
    uint256 postMintSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);

    assertApproxEqAbs(postMintSharePrice, preMintSharePrice, 2);
    assertEq(_calcUnrealizedFees(hub1, daiAssetId), 0);
  }

  function testFuzz_unrealizedFees_feesNeverExceedInterest(
    uint256 supplyAmount,
    uint256 borrowAmount,
    uint256 liquidityFee,
    uint256 timeSkip
  ) public {
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, supplyAmount);
    liquidityFee = bound(liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR);
    timeSkip = bound(timeSkip, 1 days, 5 * 365 days);

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

    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);
    (uint256 drawnDebt, ) = hub1.getAssetOwed(daiAssetId);
    uint256 totalInterest = drawnDebt - borrowAmount;
    assertEq(accruedFees, _calcUnrealizedFees(hub1, daiAssetId));

    assertLe(accruedFees, totalInterest);
    if (liquidityFee == 0) assertEq(accruedFees, 0);
    if (liquidityFee == PercentageMath.PERCENTAGE_FACTOR && totalInterest > 0)
      assertEq(accruedFees, totalInterest);
  }

  function testFuzz_unrealizedFees_sharePriceNeverDecreases(
    uint256 supplyAmount,
    uint256 borrowAmount,
    uint256 liquidityFee
  ) public {
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, supplyAmount);
    liquidityFee = bound(liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR);

    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: supplyAmount,
      user: bob
    });
    uint256 lastSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);

    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: bob,
      caller: address(spoke1),
      amount: borrowAmount
    });

    for (uint256 i = 0; i < 5; i++) {
      skip(30 days);
      uint256 currentSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);
      assertGe(currentSharePrice, lastSharePrice);
      lastSharePrice = currentSharePrice;
      assertEq(
        _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId),
        _calcUnrealizedFees(hub1, daiAssetId)
      );
    }
  }

  function testFuzz_unrealizedFees_mintPreservesSupplierValue(
    uint256 supplyAmount,
    uint256 borrowAmount,
    uint256 liquidityFee,
    uint256 timeSkip
  ) public {
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, supplyAmount);
    liquidityFee = bound(liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR);
    timeSkip = bound(timeSkip, 1 days, 5 * 365 days);

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
    skip(timeSkip);

    uint256 supplierShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    uint256 supplierValueBefore = hub1.previewRemoveByShares(daiAssetId, supplierShares);

    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);

    uint256 supplierValueAfter = hub1.previewRemoveByShares(daiAssetId, supplierShares);
    assertApproxEqAbs(supplierValueAfter, supplierValueBefore, 2);
    assertEq(_calcUnrealizedFees(hub1, daiAssetId), 0);
  }

  function testFuzz_unrealizedFees_conservationOfValue(
    uint256 supplyAmount,
    uint256 borrowAmount,
    uint256 liquidityFee
  ) public {
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, supplyAmount);
    liquidityFee = bound(liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR);

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
    skip(365 days);

    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);
    assertEq(accruedFees, _calcUnrealizedFees(hub1, daiAssetId));

    uint256 supplierYield = hub1.getAddedAssets(daiAssetId) - supplyAmount;
    (uint256 drawnDebt, ) = hub1.getAssetOwed(daiAssetId);
    uint256 totalInterest = drawnDebt - borrowAmount;

    assertApproxEqAbs(accruedFees + supplierYield, totalInterest, 2);
  }

  function testFuzz_unrealizedFees_zeroFeeAllToSuppliers(
    uint256 supplyAmount,
    uint256 borrowAmount
  ) public {
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

    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);
    (uint256 drawnDebt, ) = hub1.getAssetOwed(daiAssetId);
    uint256 totalInterest = drawnDebt - borrowAmount;
    uint256 finalTotalAssets = hub1.getAddedAssets(daiAssetId);

    assertEq(accruedFees, 0);
    assertEq(accruedFees, _calcUnrealizedFees(hub1, daiAssetId));
    assertEq(finalTotalAssets - initialTotalAssets, totalInterest);
  }

  function testFuzz_unrealizedFees_maxFeeAllToTreasury(
    uint256 supplyAmount,
    uint256 borrowAmount
  ) public {
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

    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);
    (uint256 drawnDebt, ) = hub1.getAssetOwed(daiAssetId);
    uint256 totalInterest = drawnDebt - borrowAmount;
    uint256 finalSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);

    assertEq(accruedFees, totalInterest);
    assertEq(accruedFees, _calcUnrealizedFees(hub1, daiAssetId));
    assertEq(finalSharePrice, initialSharePrice);
  }

  function testFuzz_unrealizedFees_feeSplitProportional(
    uint256 supplyAmount,
    uint256 borrowAmount,
    uint256 liquidityFee
  ) public {
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, supplyAmount);
    liquidityFee = bound(liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR);

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
    skip(365 days);

    (uint256 drawnDebt, ) = hub1.getAssetOwed(daiAssetId);
    uint256 totalDelta = drawnDebt - borrowAmount;
    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);

    uint256 expectedProtocolCut = (totalDelta * liquidityFee) / PercentageMath.PERCENTAGE_FACTOR;
    assertEq(accruedFees, expectedProtocolCut);
    assertEq(accruedFees, _calcUnrealizedFees(hub1, daiAssetId));
  }

  function testFuzz_unrealizedFees_multiPeriodAccrual(
    uint256 supplyAmount,
    uint256 borrowAmount,
    uint256 liquidityFee,
    uint8 periods
  ) public {
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, supplyAmount);
    liquidityFee = bound(liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR);
    periods = uint8(bound(periods, 2, 10));

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

    uint256 lastFees = 0;
    uint256 lastSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);

    for (uint256 i = 0; i < periods; i++) {
      skip(90 days);

      uint256 currentFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);
      assertEq(currentFees, _calcUnrealizedFees(hub1, daiAssetId));

      uint256 currentSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);

      assertGe(currentFees, lastFees);
      assertGe(currentSharePrice, lastSharePrice);

      lastFees = currentFees;
      lastSharePrice = currentSharePrice;
    }
  }

  /// @dev Fuzz: Users earn same interest per share regardless of realizedFees size
  function testFuzz_unrealizedFees_interestIndependentOfFeeSize(
    uint256 supplyAmount,
    uint256 borrowAmount,
    uint256 liquidityFee,
    uint256 timeSkipFirst,
    uint256 newSupplyAmount,
    uint256 timeSkipSecond
  ) public {
    supplyAmount = bound(supplyAmount, 1e18, MAX_SUPPLY_AMOUNT / 2);
    borrowAmount = bound(borrowAmount, 1, supplyAmount / 2);
    liquidityFee = bound(liquidityFee, 1, PercentageMath.PERCENTAGE_FACTOR);
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

    // Mint fee shares to reset realizedFees
    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);
    assertEq(_calcUnrealizedFees(hub1, daiAssetId), 0);

    // Carol joins when realizedFees are zero
    uint256 sharesBeforeCarol = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: newSupplyAmount,
      user: carol
    });
    uint256 carolShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1)) - sharesBeforeCarol;

    // Same supply should yield same shares (within rounding)
    assertApproxEqAbs(aliceShares, carolShares, 2);

    uint256 aliceValueBefore = hub1.previewRemoveByShares(daiAssetId, aliceShares);
    uint256 carolValueBefore = hub1.previewRemoveByShares(daiAssetId, carolShares);

    skip(timeSkipSecond);

    uint256 aliceGrowth = hub1.previewRemoveByShares(daiAssetId, aliceShares) - aliceValueBefore;
    uint256 carolGrowth = hub1.previewRemoveByShares(daiAssetId, carolShares) - carolValueBefore;

    // Both should earn same interest (same shares = same growth)
    assertApproxEqAbs(aliceGrowth, carolGrowth, 2);
  }
}
