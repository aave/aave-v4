// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

contract HubAccrueInterestTest is Base {
  struct Timestamps {
    uint40 t0;
    uint40 t1;
    uint40 t2;
    uint40 t3;
    uint40 t4;
  }

  struct AssetDataLocal {
    DataTypes.Asset t0;
    DataTypes.Asset t1;
    DataTypes.Asset t2;
    DataTypes.Asset t3;
    DataTypes.Asset t4;
  }

  struct CumulatedInterest {
    uint256 t1;
    uint256 t2;
    uint256 t3;
    uint256 t4;
  }

  struct Spoke1Amounts {
    uint256 draw0;
    uint256 draw1;
    uint256 draw2;
    uint256 draw3;
    uint256 draw4;
    uint256 add0;
    uint256 add1;
    uint256 add2;
    uint256 add3;
    uint256 add4;
  }

  function setUp() public override {
    super.setUp();
    initEnvironment();
    spokeMintAndApprove();
  }

  /// no interest accrued when no action taken
  function test_accrueInterest_NoActionTaken() public view {
    DataTypes.Asset memory daiInfo = hub1.getAsset(daiAssetId);
    assertEq(daiInfo.lastUpdateTimestamp, vm.getBlockTimestamp());
    assertEq(daiInfo.drawnIndex, WadRayMath.RAY);
    assertEq(daiInfo.realizedPremium, 0);
    assertEq(hub1.getAssetAddedAmount(daiAssetId), 0);
    assertEq(getAssetDrawnDebt(daiAssetId), 0);
  }

  /// no interest accrued with only add
  function test_accrueInterest_NoInterest_OnlyAdd(uint40 elapsed) public {
    elapsed = uint40(bound(elapsed, 1, type(uint40).max / 3));

    uint256 addAmount = 1000e18;
    Utils.add(hub1, daiAssetId, address(spoke1), addAmount, address(spoke1));

    // Time passes
    skip(elapsed);

    // Spoke 2 does a add to accrue interest
    Utils.add(hub1, daiAssetId, address(spoke2), addAmount, address(spoke2));

    DataTypes.Asset memory daiInfo = hub1.getAsset(daiAssetId);

    // Timestamp does not update when no interest accrued
    assertEq(daiInfo.lastUpdateTimestamp, vm.getBlockTimestamp(), 'lastUpdateTimestamp');
    assertEq(daiInfo.drawnIndex, WadRayMath.RAY, 'drawnIndex');
    assertEq(hub1.getAssetAddedAmount(daiAssetId), addAmount * 2);
    assertEq(getAssetDrawnDebt(daiAssetId), 0);
  }

  /// no interest accrued when no debt after restore
  function test_accrueInterest_NoInterest_NoDebt(uint40 elapsed) public {
    elapsed = uint40(bound(elapsed, 1, type(uint40).max / 3));

    uint256 addAmount = 1000e18;
    uint256 addAmount2 = 100e18;
    uint256 startTime = vm.getBlockTimestamp();
    uint256 borrowAmount = 100e18;
    uint256 initialDrawnIndex = WadRayMath.RAY;

    Utils.add(hub1, daiAssetId, address(spoke1), addAmount, address(spoke1));
    Utils.draw(hub1, daiAssetId, address(spoke1), address(spoke1), borrowAmount);
    uint256 drawnRate = hub1.getAssetDrawnRate(daiAssetId);

    // Time passes
    skip(elapsed);

    // Spoke 2 does a add to accrue interest
    Utils.add(hub1, daiAssetId, address(spoke2), addAmount2, address(spoke2));

    DataTypes.Asset memory daiInfo = hub1.getAsset(daiAssetId);

    (uint256 expectedDrawnIndex1, uint256 expectedDrawnDebt1) = calculateExpectedDebt(
      daiInfo.drawnShares,
      initialDrawnIndex,
      drawnRate,
      uint40(startTime)
    );
    uint256 interest = expectedDrawnDebt1 - borrowAmount;

    assertEq(elapsed, daiInfo.lastUpdateTimestamp - startTime);
    assertEq(daiInfo.drawnIndex, expectedDrawnIndex1, 'drawnIndex');
    assertEq(hub1.getAssetAddedAmount(daiAssetId), addAmount + addAmount2 + interest, 'addAmount');
    assertEq(getAssetDrawnDebt(daiAssetId), expectedDrawnDebt1, 'drawn');

    startTime = vm.getBlockTimestamp();
    drawnRate = hub1.getAssetDrawnRate(daiAssetId);

    // calculate expected drawn to restore
    (uint256 expectedDrawnIndex2, uint256 expectedDrawnDebt2) = calculateExpectedDebt(
      daiInfo.drawnShares,
      expectedDrawnIndex1,
      drawnRate,
      uint40(startTime)
    );

    // Full repayment, so back to zero debt
    Utils.restoreBase(hub1, daiAssetId, address(spoke1), borrowAmount + interest, address(spoke1));

    assertEq(expectedDrawnIndex2, expectedDrawnIndex1, 'expectedDrawnIndex');
    assertEq(expectedDrawnDebt2, expectedDrawnDebt1, 'expectedDrawnDebt');

    daiInfo = hub1.getAsset(daiAssetId);

    // Timestamp does not update when no interest accrued
    assertEq(daiInfo.lastUpdateTimestamp, vm.getBlockTimestamp(), 'lastUpdateTimestamp');
    assertEq(daiInfo.drawnIndex, expectedDrawnIndex2, 'drawnIndex2');
    assertEq(hub1.getAssetAddedAmount(daiAssetId), addAmount + addAmount2 + interest, 'addAmount');
    assertEq(getAssetDrawnDebt(daiAssetId), 0, 'drawn');

    // Time passes
    skip(elapsed);

    // Spoke 2 does a add to accrue interest
    Utils.add(hub1, daiAssetId, address(spoke2), addAmount2, address(spoke2));

    daiInfo = hub1.getAsset(daiAssetId);

    assertEq(daiInfo.lastUpdateTimestamp, vm.getBlockTimestamp(), 'lastUpdateTimestamp');
    assertEq(daiInfo.drawnIndex, expectedDrawnIndex2, 'drawnIndex2');
    assertEq(
      hub1.getAssetAddedAmount(daiAssetId),
      addAmount + addAmount2 * 2 + interest,
      'addAmount'
    );
    assertEq(getAssetDrawnDebt(daiAssetId), 0, 'drawn');
  }

  /// accrue interest after some time has passed
  function test_accrueInterest_fuzz_BorrowAndWait(uint40 elapsed) public {
    elapsed = uint40(bound(elapsed, 1, type(uint40).max / 3));

    uint256 addAmount = 1000e18;
    uint256 addAmount2 = 100e18;
    uint256 startTime = vm.getBlockTimestamp();
    uint256 borrowAmount = 100e18;
    uint256 initialDrawnIndex = WadRayMath.RAY;

    Utils.add(hub1, daiAssetId, address(spoke1), addAmount, address(spoke1));
    Utils.draw(hub1, daiAssetId, address(spoke1), address(spoke1), borrowAmount);
    uint256 drawnRate = hub1.getAssetDrawnRate(daiAssetId);

    // Time passes
    skip(elapsed);

    // Spoke 2 does a add to accrue interest
    Utils.add(hub1, daiAssetId, address(spoke2), addAmount2, address(spoke2));

    DataTypes.Asset memory daiInfo = hub1.getAsset(daiAssetId);

    (uint256 expectedDrawnIndex, uint256 expectedDrawnDebt) = calculateExpectedDebt(
      daiInfo.drawnShares,
      initialDrawnIndex,
      drawnRate,
      uint40(startTime)
    );
    uint256 interest = expectedDrawnDebt - borrowAmount;

    assertEq(elapsed, daiInfo.lastUpdateTimestamp - startTime);
    assertEq(daiInfo.drawnIndex, expectedDrawnIndex, 'drawnIndex');
    assertEq(hub1.getAssetAddedAmount(daiAssetId), addAmount + addAmount2 + interest, 'addAmount');
    assertEq(getAssetDrawnDebt(daiAssetId), expectedDrawnDebt, 'drawn');
  }

  /// accrue interest on any borrow amount after any time has passed
  function test_accrueInterest_fuzz_BorrowAmountAndElapsed(
    uint256 borrowAmount,
    uint40 elapsed
  ) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    elapsed = uint40(bound(elapsed, 1, type(uint40).max / 3));

    uint256 startTime = vm.getBlockTimestamp();
    uint256 addAmount = borrowAmount * 2;
    uint256 addAmount2 = 100e18;
    uint256 initialDrawnIndex = WadRayMath.RAY;

    Utils.add(hub1, daiAssetId, address(spoke1), addAmount, address(spoke1));
    Utils.draw(hub1, daiAssetId, address(spoke1), address(spoke1), borrowAmount);
    uint256 drawnRate = hub1.getAssetDrawnRate(daiAssetId);

    // Time passes
    skip(elapsed);

    // Spoke 2 does a add to accrue interest
    Utils.add(hub1, daiAssetId, address(spoke2), addAmount2, address(spoke2));

    DataTypes.Asset memory daiInfo = hub1.getAsset(daiAssetId);

    (uint256 expectedDrawnIndex, uint256 expectedDrawnDebt) = calculateExpectedDebt(
      daiInfo.drawnShares,
      initialDrawnIndex,
      drawnRate,
      uint40(startTime)
    );
    uint256 interest = expectedDrawnDebt - borrowAmount;

    assertEq(elapsed, daiInfo.lastUpdateTimestamp - startTime);
    assertEq(daiInfo.drawnIndex, expectedDrawnIndex, 'drawnIndex');
    assertEq(hub1.getAssetAddedAmount(daiAssetId), addAmount + addAmount2 + interest, 'addAmount');
    assertEq(getAssetDrawnDebt(daiAssetId), expectedDrawnDebt, 'drawn');
  }

  function test_accrueInterest_TenPercentRP(uint256 borrowAmount, uint40 elapsed) public {
    vm.skip(true, 'move to hub premium debt tests');
    // borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);

    // uint256 startTime = vm.getBlockTimestamp();
    // uint256 addAmount = borrowAmount * 2;
    // uint256 initialDrawnIndex = WadRayMath.RAY;
    // uint32 riskPremium = 10_00;

    // Utils.add(hub1, daiAssetId, address(spoke1), addAmount, address(spoke1), address(spoke1));
    // Utils.draw(hub1, daiAssetId, address(spoke1), address(spoke1), borrowAmount, address(spoke1));
    // // refresh risk premium
    // uint256 drawnRate = hub1.getAssetDrawnRate(daiAssetId);

    // // Time passes
    // skip(elapsed);

    // // Spoke 2 does a add to accrue interest
    // Utils.add(hub1, daiAssetId, address(spoke2), 1000e18, address(spoke2), address(spoke2));

    // DataTypes.Asset memory daiInfo = hub1.getAsset(daiAssetId);

    // uint256 expectedDrawnIndex = _calculateExpectedDrawnIndex(
    //   initialDrawnIndex,
    //   drawnRate,
    //   uint40(startTime)
    // );

    // assertEq(daiInfo.lastUpdateTimestamp - startTime, elapsed);
    // assertEq(daiInfo.drawnIndex, expectedDrawnIndex, 'drawnIndex');
    // assertEq(daiInfo.riskPremium.derayify(), riskPremium); // todo: getRiskPremium
    // assertEq(
    //   daiInfo.realizedPremium,
    //   (totalBase - borrowAmount).percentMul(riskPremium),
    //   'realizedPremium'
    // );
  }

  function test_accrueInterest_fuzz_RPBorrowAndElapsed(
    uint256 borrowAmount,
    uint40 elapsed,
    uint32 riskPremium
  ) public {
    vm.skip(true, 'move to hub premium debt tests');

    //     borrowAmount = bound(borrowAmount, 1, 1e30);
    //     riskPremium %= MAX_RISK_PREMIUM_BPS;
    //     uint256 addAmount = borrowAmount * 2;
    //     uint256 startTime = vm.getBlockTimestamp();

    //     vm.startPrank(address(spoke1));
    //     hub1.add(daiAssetId, addAmount, 0, address(spoke1));
    //     hub1.draw(daiAssetId, borrowAmount, riskPremium, address(spoke1));
    //     uint256 drawnRate = hub1.getAssetDrawnRate(daiAssetId);
    //     vm.stopPrank();

    //     // Time passes
    //     skip(elapsed);

    //     // Spoke 2 does a add to accrue interest
    //     Utils.add(hub1, daiAssetId, address(spoke2), 1000e18, 0, address(spoke2), address(spoke2));

    //     DataTypes.Asset memory daiInfo = hub1.getAsset(daiAssetId);

    //     uint256 totalBase = MathUtils.calculateLinearInterest(drawnRate, uint40(startTime)).rayMul(
    //       borrowAmount
    //     );

    //     assertEq(daiInfo.lastUpdateTimestamp - startTime, elapsed);
    //     assertEq(daiInfo.drawn, totalBase);
    //     assertEq(daiInfo.riskPremium.derayify(), riskPremium);
    //     assertEq(daiInfo.realizedPremium, (totalBase - borrowAmount).percentMul(riskPremium));
  }

  /// accrue interest on any borrow amount after a borrow rate change and any time has passed
  function test_accrueInterest_fuzz_BorrowAmountRateAndElapsed(
    uint256 borrowAmount,
    uint256 borrowRate,
    uint40 elapsed
  ) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    borrowRate = bound(borrowRate, 0, MAX_BORROW_RATE);
    elapsed = uint40(bound(elapsed, 1, type(uint40).max / 3));
    uint256 initialDrawnIndex = WadRayMath.RAY;
    uint256 addAmount2 = 1000e18;

    Timestamps memory timestamps;
    AssetDataLocal memory assetData;
    Spoke1Amounts memory spoke1Amounts;
    CumulatedInterest memory cumulated;

    spoke1Amounts.add0 = borrowAmount * 2;
    timestamps.t0 = uint40(vm.getBlockTimestamp());

    Utils.add(hub1, daiAssetId, address(spoke1), spoke1Amounts.add0, address(spoke1));
    Utils.draw(hub1, daiAssetId, address(spoke1), address(spoke1), borrowAmount);

    assetData.t0 = hub1.getAsset(daiAssetId);

    // Time passes
    skip(elapsed);

    // Spoke 2 does a add to accrue interest
    Utils.add(hub1, daiAssetId, address(spoke2), addAmount2, address(spoke2));

    assetData.t1 = hub1.getAsset(daiAssetId);
    timestamps.t1 = uint40(vm.getBlockTimestamp());
    (uint256 expectedDrawnIndex, uint256 expectedDrawnDebt1) = calculateExpectedDebt(
      assetData.t0.drawnShares,
      initialDrawnIndex,
      assetData.t0.drawnRate,
      timestamps.t0
    );
    cumulated.t1 = expectedDrawnIndex;
    uint256 interest1 = expectedDrawnDebt1 - borrowAmount;

    assertEq(assetData.t1.lastUpdateTimestamp - timestamps.t0, elapsed, 'elapsed');
    assertEq(assetData.t1.drawnIndex, cumulated.t1, 'drawnIndex');
    assertEq(
      hub1.getAssetAddedAmount(daiAssetId),
      spoke1Amounts.add0 + addAmount2 + interest1,
      'addAmount'
    );
    assertEq(getAssetDrawnDebt(daiAssetId), expectedDrawnDebt1, 'drawn');

    // Say borrow rate changes
    _mockInterestRateBps(borrowRate);
    // Make an action to cache this new borrow rate
    Utils.add(hub1, daiAssetId, address(spoke2), addAmount2, address(spoke2));

    // Time passes
    skip(elapsed);
    timestamps.t2 = uint40(vm.getBlockTimestamp());

    // Spoke 2 does a add to accrue interest
    Utils.add(hub1, daiAssetId, address(spoke2), addAmount2, address(spoke2));

    assetData.t2 = hub1.getAsset(daiAssetId);
    timestamps.t2 = uint40(vm.getBlockTimestamp());
    uint256 expectedDrawnDebt2;
    (expectedDrawnIndex, expectedDrawnDebt2) = calculateExpectedDebt(
      assetData.t0.drawnShares,
      cumulated.t1,
      assetData.t2.drawnRate,
      timestamps.t1
    );
    cumulated.t2 = expectedDrawnIndex;
    uint256 interest2 = expectedDrawnDebt2 - expectedDrawnDebt1;

    assertEq(assetData.t2.lastUpdateTimestamp - timestamps.t1, elapsed, 'elapsed');
    assertEq(assetData.t2.drawnIndex, cumulated.t2, 'drawnIndex t2');
    assertEq(
      hub1.getAssetAddedAmount(daiAssetId),
      spoke1Amounts.add0 + addAmount2 * 3 + interest1 + interest2,
      'addAmount t2'
    );
    assertEq(getAssetDrawnDebt(daiAssetId), expectedDrawnDebt2, 'drawn t2');
  }
}
