// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubAccrueInterestTest is HubBase {
  using SafeCast for uint256;

  struct Timestamps {
    uint40 t0;
    uint40 t1;
    uint40 t2;
    uint40 t3;
    uint40 t4;
  }

  struct AssetDataLocal {
    IHub.Asset t0;
    IHub.Asset t1;
    IHub.Asset t2;
    IHub.Asset t3;
    IHub.Asset t4;
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
    spokeMintAndApprove();
  }

  /// no interest accrued when no action taken
  function test_accrueInterest_NoActionTaken() public view {
    IHub.Asset memory daiInfo = hub1.getAsset(daiAssetId);
    assertEq(daiInfo.lastUpdateTimestamp, vm.getBlockTimestamp());
    assertEq(daiInfo.drawnIndex, WadRayMath.RAY);
    assertEq(daiInfo.premiumOffsetRay, 0);
    assertEq(hub1.getAddedAssets(daiAssetId), 0);
    assertEq(getAssetDrawnDebt(daiAssetId), 0);
  }

  /// no interest accrued with only add
  function test_accrueInterest_NoInterest_OnlyAdd(uint40 elapsed) public {
    elapsed = bound(elapsed, 1, type(uint40).max / 3).toUint40();

    uint256 addAmount = 1000e18;
    Utils.add(hub1, daiAssetId, address(spoke1), addAmount, address(spoke1));

    // Time passes
    skip(elapsed);

    // Spoke 2 does a add to accrue interest
    Utils.add(hub1, daiAssetId, address(spoke2), addAmount, address(spoke2));

    IHub.Asset memory daiInfo = hub1.getAsset(daiAssetId);

    // Timestamp does not update when no interest accrued
    assertEq(daiInfo.lastUpdateTimestamp, vm.getBlockTimestamp(), 'lastUpdateTimestamp');
    assertEq(daiInfo.drawnIndex, WadRayMath.RAY, 'drawnIndex');
    assertEq(hub1.getAddedAssets(daiAssetId), addAmount * 2);
    assertEq(getAssetDrawnDebt(daiAssetId), 0);
  }

  /// no interest accrued when no debt after restore
  function test_accrueInterest_NoInterest_NoDebt(uint40 elapsed) public {
    elapsed = bound(elapsed, 1, type(uint40).max / 3).toUint40();
    _testNoInterestNoDebt(elapsed, 1000e18, 100e18, 100e18);
  }

  function _testNoInterestNoDebt(
    uint40 elapsed,
    uint256 addAmount,
    uint256 addAmount2,
    uint256 borrowAmount
  ) internal {
    uint256 interest;
    uint256 dust1;
    uint256 expectedDrawnIndex1;

    // Phase 1: Add, draw, skip, add (triggers accrual)
    {
      uint40 startTime = vm.getBlockTimestamp().toUint40();
      Utils.add(hub1, daiAssetId, address(spoke1), addAmount, address(spoke1));
      Utils.draw(hub1, daiAssetId, address(spoke1), address(spoke1), borrowAmount);
      uint96 drawnRate = hub1.getAssetDrawnRate(daiAssetId).toUint96();

      skip(elapsed);
      uint256 addedSharesBefore = hub1.getAsset(daiAssetId).addedShares;
      Utils.add(hub1, daiAssetId, address(spoke2), addAmount2, address(spoke2));

      IHub.Asset memory asset = hub1.getAsset(daiAssetId);
      uint256 expectedDebt;
      (expectedDrawnIndex1, expectedDebt) = calculateExpectedDebt(
        asset.drawnShares,
        WadRayMath.RAY,
        drawnRate,
        startTime
      );
      interest = expectedDebt - borrowAmount;

      assertEq(elapsed, asset.lastUpdateTimestamp - startTime);
      assertEq(asset.drawnIndex, expectedDrawnIndex1, 'drawnIndex');

      // At time of accrual, spoke2 hasn't added yet - totalAssets = addAmount + interest (not + addAmount2)
      uint256 totalForFee = addAmount + interest;
      dust1 = _calculateExpectedDust(hub1, daiAssetId, interest, totalForFee, addedSharesBefore);
      uint256 totalAfterAdd = addAmount + addAmount2 + interest;
      assertEq(hub1.getAddedAssets(daiAssetId), totalAfterAdd - dust1, 'addAmount');
      assertEq(getAssetDrawnDebt(daiAssetId), expectedDebt, 'drawn');
    }

    // Phase 2: Full repayment
    Utils.restoreDrawn(hub1, daiAssetId, address(spoke1), borrowAmount + interest, address(spoke1));
    assertEq(hub1.getAsset(daiAssetId).drawnIndex, expectedDrawnIndex1, 'drawnIndex2');
    assertEq(
      hub1.getAddedAssets(daiAssetId),
      addAmount + addAmount2 + interest - dust1,
      'addAmount'
    );
    assertEq(getAssetDrawnDebt(daiAssetId), 0, 'drawn');

    // Phase 3: Time passes, another add (no new interest since debt is 0)
    skip(elapsed);
    Utils.add(hub1, daiAssetId, address(spoke2), addAmount2, address(spoke2));

    assertEq(hub1.getAsset(daiAssetId).drawnIndex, expectedDrawnIndex1, 'drawnIndex2');
    assertEq(
      hub1.getAddedAssets(daiAssetId),
      addAmount + addAmount2 * 2 + interest - dust1,
      'addAmount'
    );
    assertEq(getAssetDrawnDebt(daiAssetId), 0, 'drawn');
  }

  /// accrue interest after some time has passed
  function test_accrueInterest_fuzz_BorrowAndWait(uint40 elapsed) public {
    elapsed = bound(elapsed, 1, type(uint40).max / 3).toUint40();

    uint256 addAmount = 1000e18;
    uint256 addAmount2 = 100e18;
    uint256 borrowAmount = 100e18;

    uint40 startTime = vm.getBlockTimestamp().toUint40();
    Utils.add(hub1, daiAssetId, address(spoke1), addAmount, address(spoke1));
    Utils.draw(hub1, daiAssetId, address(spoke1), address(spoke1), borrowAmount);
    uint96 drawnRate = hub1.getAssetDrawnRate(daiAssetId).toUint96();

    skip(elapsed);

    // Store addedShares BEFORE the add that triggers accrual
    uint256 addedSharesBeforeAccrual = hub1.getAsset(daiAssetId).addedShares;

    Utils.add(hub1, daiAssetId, address(spoke2), addAmount2, address(spoke2));

    IHub.Asset memory daiInfo = hub1.getAsset(daiAssetId);
    (uint256 expectedDrawnIndex, uint256 expectedDrawnDebt) = calculateExpectedDebt(
      daiInfo.drawnShares,
      WadRayMath.RAY,
      drawnRate,
      startTime
    );

    assertEq(elapsed, daiInfo.lastUpdateTimestamp - startTime);
    assertEq(daiInfo.drawnIndex, expectedDrawnIndex, 'drawnIndex');
    assertEq(getAssetDrawnDebt(daiAssetId), expectedDrawnDebt, 'drawn');

    // Calculate and verify total added assets accounting for dust
    // At time of accrual, spoke2 hasn't added yet - totalAssets = addAmount + interest (not + addAmount2)
    uint256 interest = expectedDrawnDebt - borrowAmount;
    uint256 totalForFee = addAmount + interest;
    uint256 dust = _calculateExpectedDust(
      hub1,
      daiAssetId,
      interest,
      totalForFee,
      addedSharesBeforeAccrual
    );
    uint256 totalAfterAdd = addAmount + addAmount2 + interest;
    assertEq(hub1.getAddedAssets(daiAssetId), totalAfterAdd - dust, 'addAmount');
  }

  /// accrue interest on any borrow amount after any time has passed
  function test_accrueInterest_fuzz_BorrowAmountAndElapsed(
    uint256 borrowAmount,
    uint40 elapsed
  ) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    elapsed = bound(elapsed, 1, type(uint40).max / 3).toUint40();

    uint256 addAmount = borrowAmount * 2;
    uint256 addAmount2 = 100e18;

    uint40 startTime = vm.getBlockTimestamp().toUint40();
    Utils.add(hub1, daiAssetId, address(spoke1), addAmount, address(spoke1));
    Utils.draw(hub1, daiAssetId, address(spoke1), address(spoke1), borrowAmount);
    uint96 drawnRate = hub1.getAssetDrawnRate(daiAssetId).toUint96();

    skip(elapsed);

    // Store addedShares BEFORE the add that triggers accrual
    uint256 addedSharesBeforeAccrual = hub1.getAsset(daiAssetId).addedShares;

    Utils.add(hub1, daiAssetId, address(spoke2), addAmount2, address(spoke2));

    IHub.Asset memory daiInfo = hub1.getAsset(daiAssetId);
    (uint256 expectedDrawnIndex, uint256 expectedDrawnDebt) = calculateExpectedDebt(
      daiInfo.drawnShares,
      WadRayMath.RAY,
      drawnRate,
      startTime
    );

    assertEq(elapsed, daiInfo.lastUpdateTimestamp - startTime);
    assertEq(daiInfo.drawnIndex, expectedDrawnIndex, 'drawnIndex');
    assertEq(getAssetDrawnDebt(daiAssetId), expectedDrawnDebt, 'drawn');

    // Calculate and verify total added assets accounting for dust
    // At time of accrual, spoke2 hasn't added yet - totalAssets = addAmount + interest (not + addAmount2)
    uint256 interest = expectedDrawnDebt - borrowAmount;
    uint256 totalForFee = addAmount + interest;
    uint256 dust = _calculateExpectedDust(
      hub1,
      daiAssetId,
      interest,
      totalForFee,
      addedSharesBeforeAccrual
    );
    uint256 totalAfterAdd = addAmount + addAmount2 + interest;
    assertEq(hub1.getAddedAssets(daiAssetId), totalAfterAdd - dust, 'addAmount');
  }

  struct AccrualTestState {
    uint256 add0;
    uint256 addAmount2;
    uint256 interest1;
    uint256 dust1;
    uint256 drawnIndex1;
    uint256 expectedDrawnDebt1;
  }

  /// accrue interest on any borrow amount after a borrow rate change and any time has passed
  function test_accrueInterest_fuzz_BorrowAmountRateAndElapsed(
    uint256 borrowAmount,
    uint256 borrowRate,
    uint40 elapsed
  ) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    borrowRate = bound(borrowRate, 0, MAX_BORROW_RATE);
    elapsed = bound(elapsed, 1, MAX_SKIP_TIME / 3).toUint40();

    AccrualTestState memory s;
    s.addAmount2 = 1000e18;
    s.add0 = borrowAmount * 2;

    // Phase 1: Initial setup and first accrual
    _runPhase1(s, borrowAmount, elapsed);

    // Phase 2: Rate change and second accrual
    _runPhase2(s, borrowRate, elapsed);
  }

  function _runPhase1(AccrualTestState memory s, uint256 borrowAmount, uint40 elapsed) internal {
    uint40 t0 = vm.getBlockTimestamp().toUint40();
    Utils.add(hub1, daiAssetId, address(spoke1), s.add0, address(spoke1));
    Utils.draw(hub1, daiAssetId, address(spoke1), address(spoke1), borrowAmount);

    IHub.Asset memory asset0 = hub1.getAsset(daiAssetId);

    skip(elapsed);

    // Store addedShares BEFORE the add that triggers accrual
    uint256 addedSharesBeforeAccrual = hub1.getAsset(daiAssetId).addedShares;

    Utils.add(hub1, daiAssetId, address(spoke2), s.addAmount2, address(spoke2));

    IHub.Asset memory asset1 = hub1.getAsset(daiAssetId);
    (s.drawnIndex1, s.expectedDrawnDebt1) = calculateExpectedDebt(
      asset0.drawnShares,
      WadRayMath.RAY,
      asset0.drawnRate,
      t0
    );
    s.interest1 = s.expectedDrawnDebt1 - borrowAmount;

    assertEq(asset1.lastUpdateTimestamp - t0, elapsed, 'elapsed');
    assertEq(asset1.drawnIndex, s.drawnIndex1, 'drawnIndex');

    // Fee calculation uses addedShares at the START of accrue(), before feeShares are added
    // At time of accrual, spoke2 hasn't added yet - totalAssets = s.add0 + interest (not + addAmount2)
    s.dust1 = _calculateExpectedDust(
      hub1,
      daiAssetId,
      s.interest1,
      s.add0 + s.interest1,
      addedSharesBeforeAccrual
    );
    assertEq(
      hub1.getAddedAssets(daiAssetId),
      s.add0 + s.addAmount2 + s.interest1 - s.dust1,
      'addAmount'
    );
    assertEq(getAssetDrawnDebt(daiAssetId), s.expectedDrawnDebt1, 'drawn');
  }

  function _runPhase2(AccrualTestState memory s, uint256 borrowRate, uint40 elapsed) internal {
    _mockInterestRateBps(borrowRate);
    Utils.add(hub1, daiAssetId, address(spoke2), s.addAmount2, address(spoke2));

    uint40 t1 = vm.getBlockTimestamp().toUint40();
    skip(elapsed);

    // Store addedShares BEFORE the add that triggers accrual
    uint256 addedSharesBeforeAccrual = hub1.getAsset(daiAssetId).addedShares;

    Utils.add(hub1, daiAssetId, address(spoke2), s.addAmount2, address(spoke2));

    IHub.Asset memory asset2 = hub1.getAsset(daiAssetId);
    (uint256 drawnIndex2, uint256 expectedDrawnDebt2) = calculateExpectedDebt(
      asset2.drawnShares,
      s.drawnIndex1,
      asset2.drawnRate,
      t1
    );
    uint256 interest2 = expectedDrawnDebt2 - s.expectedDrawnDebt1;

    assertEq(asset2.lastUpdateTimestamp - t1, elapsed, 'elapsed');
    assertEq(asset2.drawnIndex, drawnIndex2, 'drawnIndex t2');

    // At time of accrual, the new add from spoke2 hasn't happened yet
    // totalAssets = s.add0 + 2*addAmount2 (from phase1 + rate change add) + interest1 + interest2
    uint256 totalForFee = s.add0 + s.addAmount2 * 2 + s.interest1 + interest2;
    uint256 dust2 = _calculateCumulativeDust(
      interest2,
      s.dust1,
      totalForFee,
      addedSharesBeforeAccrual,
      asset2.liquidityFee
    );
    uint256 totalAfterAdd = s.add0 + s.addAmount2 * 3 + s.interest1 + interest2;
    assertEq(hub1.getAddedAssets(daiAssetId), totalAfterAdd - dust2, 'addAmount t2');
    assertEq(getAssetDrawnDebt(daiAssetId), expectedDrawnDebt2, 'drawn t2');
  }
}
