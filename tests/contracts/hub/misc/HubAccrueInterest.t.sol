// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract HubAccrueInterestTest is Base {
  using SafeCast for uint256;
  using WadRayMath for uint256;

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

    address[3] memory spokes = [address(spoke1), address(spoke2), address(spoke3)];

    for (uint256 x; x < spokes.length; ++x) {
      tokenList.usdx.mint(spokes[x], MAX_SUPPLY_AMOUNT);
      tokenList.dai.mint(spokes[x], MAX_SUPPLY_AMOUNT);
      tokenList.wbtc.mint(spokes[x], MAX_SUPPLY_AMOUNT);
      tokenList.usdy.mint(spokes[x], MAX_SUPPLY_AMOUNT);
      tokenList.usdz.mint(spokes[x], MAX_SUPPLY_AMOUNT);
      deal(address(tokenList.weth), spokes[x], MAX_SUPPLY_AMOUNT);

      vm.startPrank(spokes[x]);
      tokenList.weth.approve(address(hub1), UINT256_MAX);
      tokenList.usdx.approve(address(hub1), UINT256_MAX);
      tokenList.dai.approve(address(hub1), UINT256_MAX);
      tokenList.wbtc.approve(address(hub1), UINT256_MAX);
      tokenList.usdy.approve(address(hub1), UINT256_MAX);
      tokenList.usdz.approve(address(hub1), UINT256_MAX);
      vm.stopPrank();
    }
  }

  /// no interest accrued when no action taken
  function test_accrueInterest_NoActionTaken() public view {
    IHub.Asset memory daiInfo = hub1.getAsset(daiAssetId);
    assertEq(daiInfo.lastUpdateTimestamp, vm.getBlockTimestamp());
    assertEq(daiInfo.drawnIndex, WadRayMath.RAY);
    assertEq(daiInfo.premiumOffsetRay, 0);
    assertEq(hub1.getAddedAssets(daiAssetId), 0);
    assertEq(_getAssetDrawnDebt(hub1, daiAssetId), 0);
  }

  /// no interest accrued with only add
  function test_accrueInterest_NoInterest_OnlyAdd(uint40 elapsed) public {
    elapsed = bound(elapsed, 1, type(uint40).max / 3).toUint40();

    uint256 addAmount = 1000e18;
    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: addAmount,
      user: address(spoke1)
    });

    // Time passes
    skip(elapsed);

    // Spoke 2 does a add to accrue interest
    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: addAmount,
      user: address(spoke2)
    });

    IHub.Asset memory daiInfo = hub1.getAsset(daiAssetId);

    // Timestamp does not update when no interest accrued
    assertEq(daiInfo.lastUpdateTimestamp, vm.getBlockTimestamp(), 'lastUpdateTimestamp');
    assertEq(daiInfo.drawnIndex, WadRayMath.RAY, 'drawnIndex');
    assertEq(hub1.getAddedAssets(daiAssetId), addAmount * 2);
    assertEq(_getAssetDrawnDebt(hub1, daiAssetId), 0);
  }

  /// no interest accrued when no debt after restore
  function test_accrueInterest_NoInterest_NoDebt(uint40 elapsed) public {
    elapsed = bound(elapsed, 1, type(uint40).max / 3).toUint40();

    uint256 addAmount = 1000e18;
    uint256 addAmount2 = 100e18;
    uint40 startTime = vm.getBlockTimestamp().toUint40();
    uint256 borrowAmount = 100e18;

    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: addAmount,
      user: address(spoke1)
    });
    HubActions.draw({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      to: address(spoke1),
      amount: borrowAmount
    });
    uint96 drawnRate = hub1.getAssetDrawnRate(daiAssetId).toUint96();

    // Time passes
    skip(elapsed);

    // Spoke 2 does an add to accrue interest
    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: addAmount2,
      user: address(spoke2)
    });

    IHub.Asset memory daiInfo = hub1.getAsset(daiAssetId);

    (uint256 expectedDrawnIndex1, uint256 expectedDrawnDebt1) = _calculateExpectedDebt(
      daiInfo.drawnShares,
      WadRayMath.RAY,
      drawnRate,
      startTime
    );
    uint256 interest = expectedDrawnDebt1 - borrowAmount;

    assertEq(elapsed, daiInfo.lastUpdateTimestamp - startTime);
    assertEq(daiInfo.drawnIndex, expectedDrawnIndex1, 'drawnIndex');
    assertEq(
      _getAddedAssetsWithFees(hub1, daiAssetId),
      addAmount + addAmount2 + interest,
      'addAmount'
    );
    assertEq(_getAssetDrawnDebt(hub1, daiAssetId), expectedDrawnDebt1, 'drawn');

    startTime = vm.getBlockTimestamp().toUint40();
    drawnRate = hub1.getAssetDrawnRate(daiAssetId).toUint96();

    // calculate expected drawn to restore
    (uint256 expectedDrawnIndex2, uint256 expectedDrawnDebt2) = _calculateExpectedDebt(
      daiInfo.drawnShares,
      expectedDrawnIndex1,
      drawnRate,
      startTime
    );

    // Full repayment, so back to zero debt
    HubActions.restoreDrawn({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      drawnAmount: borrowAmount + interest,
      restorer: address(spoke1)
    });

    assertEq(expectedDrawnIndex2, expectedDrawnIndex1, 'expectedDrawnIndex');
    assertEq(expectedDrawnDebt2, expectedDrawnDebt1, 'expectedDrawnDebt');

    daiInfo = hub1.getAsset(daiAssetId);

    // Timestamp does not update when no interest accrued
    assertEq(daiInfo.lastUpdateTimestamp, vm.getBlockTimestamp(), 'lastUpdateTimestamp');
    assertEq(daiInfo.drawnIndex, expectedDrawnIndex2, 'drawnIndex2');
    assertEq(
      _getAddedAssetsWithFees(hub1, daiAssetId),
      addAmount + addAmount2 + interest,
      'addAmount'
    );
    assertEq(_getAssetDrawnDebt(hub1, daiAssetId), 0, 'drawn');

    // Time passes
    skip(elapsed);

    // Spoke 2 does a add to accrue interest
    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: addAmount2,
      user: address(spoke2)
    });

    daiInfo = hub1.getAsset(daiAssetId);

    assertEq(daiInfo.lastUpdateTimestamp, vm.getBlockTimestamp(), 'lastUpdateTimestamp');
    assertEq(daiInfo.drawnIndex, expectedDrawnIndex2, 'drawnIndex2');
    assertEq(
      _getAddedAssetsWithFees(hub1, daiAssetId),
      addAmount + addAmount2 * 2 + interest,
      'addAmount'
    );
    assertEq(_getAssetDrawnDebt(hub1, daiAssetId), 0, 'drawn');
  }

  /// accrue interest after some time has passed
  function test_accrueInterest_fuzz_BorrowAndWait(uint40 elapsed) public {
    elapsed = bound(elapsed, 1, type(uint40).max / 3).toUint40();

    uint256 addAmount = 1000e18;
    uint256 addAmount2 = 100e18;
    uint40 startTime = vm.getBlockTimestamp().toUint40();
    uint256 borrowAmount = 100e18;
    uint256 initialDrawnIndex = WadRayMath.RAY;

    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: addAmount,
      user: address(spoke1)
    });
    HubActions.draw({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      to: address(spoke1),
      amount: borrowAmount
    });
    uint96 drawnRate = hub1.getAssetDrawnRate(daiAssetId).toUint96();

    // Time passes
    skip(elapsed);

    // Spoke 2 does a add to accrue interest
    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: addAmount2,
      user: address(spoke2)
    });

    IHub.Asset memory daiInfo = hub1.getAsset(daiAssetId);

    (uint256 expectedDrawnIndex, uint256 expectedDrawnDebt) = _calculateExpectedDebt(
      daiInfo.drawnShares,
      initialDrawnIndex,
      drawnRate,
      startTime
    );
    uint256 interest = expectedDrawnDebt - borrowAmount;

    assertEq(elapsed, daiInfo.lastUpdateTimestamp - startTime);
    assertEq(daiInfo.drawnIndex, expectedDrawnIndex, 'drawnIndex');
    assertEq(
      _getAddedAssetsWithFees(hub1, daiAssetId),
      addAmount + addAmount2 + interest,
      'addAmount'
    );
    assertEq(_getAssetDrawnDebt(hub1, daiAssetId), expectedDrawnDebt, 'drawn');
  }

  /// accrue interest on any borrow amount after any time has passed
  function test_accrueInterest_fuzz_BorrowAmountAndElapsed(
    uint256 borrowAmount,
    uint40 elapsed
  ) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    elapsed = bound(elapsed, 1, type(uint40).max / 3).toUint40();

    uint40 startTime = vm.getBlockTimestamp().toUint40();
    uint256 addAmount = borrowAmount * 2;
    uint256 addAmount2 = 100e18;
    uint256 initialDrawnIndex = WadRayMath.RAY;

    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: addAmount,
      user: address(spoke1)
    });
    HubActions.draw({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      to: address(spoke1),
      amount: borrowAmount
    });
    uint96 drawnRate = hub1.getAssetDrawnRate(daiAssetId).toUint96();

    // Time passes
    skip(elapsed);

    // Spoke 2 does a add to accrue interest
    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: addAmount2,
      user: address(spoke2)
    });

    IHub.Asset memory daiInfo = hub1.getAsset(daiAssetId);

    (uint256 expectedDrawnIndex, uint256 expectedDrawnDebt) = _calculateExpectedDebt(
      daiInfo.drawnShares,
      initialDrawnIndex,
      drawnRate,
      startTime
    );
    uint256 interest = expectedDrawnDebt - borrowAmount;

    assertEq(elapsed, daiInfo.lastUpdateTimestamp - startTime);
    assertEq(daiInfo.drawnIndex, expectedDrawnIndex, 'drawnIndex');
    assertEq(
      _getAddedAssetsWithFees(hub1, daiAssetId),
      addAmount + addAmount2 + interest,
      'addAmount'
    );
    assertEq(_getAssetDrawnDebt(hub1, daiAssetId), expectedDrawnDebt, 'drawn');
  }

  /// accrue interest on any borrow amount after a drawn rate change and any time has passed
  function test_accrueInterest_fuzz_BorrowAmountRateAndElapsed(
    uint256 borrowAmount,
    uint256 drawnRate,
    uint40 elapsed
  ) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    drawnRate = bound(drawnRate, 0, MAX_ALLOWED_DRAWN_RATE);
    elapsed = bound(elapsed, 1, MAX_SKIP_TIME / 3).toUint40();
    uint256 initialDrawnIndex = WadRayMath.RAY;
    uint256 addAmount2 = 1000e18;

    Timestamps memory timestamps;
    AssetDataLocal memory assetData;
    Spoke1Amounts memory spoke1Amounts;
    CumulatedInterest memory cumulated;

    spoke1Amounts.add0 = borrowAmount * 2;
    timestamps.t0 = vm.getBlockTimestamp().toUint40();

    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: spoke1Amounts.add0,
      user: address(spoke1)
    });
    HubActions.draw({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      to: address(spoke1),
      amount: borrowAmount
    });

    assetData.t0 = hub1.getAsset(daiAssetId);

    // Time passes
    skip(elapsed);

    // Spoke 2 does a add to accrue interest
    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: addAmount2,
      user: address(spoke2)
    });

    assetData.t1 = hub1.getAsset(daiAssetId);
    timestamps.t1 = vm.getBlockTimestamp().toUint40();
    (uint256 expectedDrawnIndex, uint256 expectedDrawnDebt1) = _calculateExpectedDebt(
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
      _getAddedAssetsWithFees(hub1, daiAssetId),
      spoke1Amounts.add0 + addAmount2 + interest1,
      'addAmount'
    );
    assertEq(_getAssetDrawnDebt(hub1, daiAssetId), expectedDrawnDebt1, 'drawn');

    // Say borrow rate changes
    _mockDrawnRateBps({irStrategy: address(irStrategy), drawnRateBps: drawnRate});
    // Make an action to cache this new borrow rate
    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: addAmount2,
      user: address(spoke2)
    });

    // Time passes
    skip(elapsed);
    timestamps.t2 = vm.getBlockTimestamp().toUint40();

    // Spoke 2 does a add to accrue interest
    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: addAmount2,
      user: address(spoke2)
    });

    assetData.t2 = hub1.getAsset(daiAssetId);
    timestamps.t2 = vm.getBlockTimestamp().toUint40();
    uint256 expectedDrawnDebt2;
    (expectedDrawnIndex, expectedDrawnDebt2) = _calculateExpectedDebt(
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
      _getAddedAssetsWithFees(hub1, daiAssetId),
      spoke1Amounts.add0 + addAmount2 * 3 + interest1 + interest2,
      'addAmount t2'
    );
    assertEq(_getAssetDrawnDebt(hub1, daiAssetId), expectedDrawnDebt2, 'drawn t2');
  }

  function test_getAssetDrawnRate_MatchesStoredAfterAction() public {
    uint256 addAmount = 1000e18;
    uint256 borrowAmount = 100e18;

    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: addAmount,
      user: address(spoke1)
    });
    HubActions.draw({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      to: address(spoke1),
      amount: borrowAmount
    });

    uint256 storedRate = hub1.getAsset(daiAssetId).drawnRate;
    uint256 computedRate = hub1.getAssetDrawnRate(daiAssetId);
    assertEq(storedRate, computedRate);
  }

  function test_getAssetDrawnRate_fuzz_DiffersAfterTimePasses(uint40 elapsed) public {
    elapsed = bound(elapsed, 1, type(uint40).max / 3).toUint40();

    uint256 addAmount = 1000e18;
    uint256 borrowAmount = 100e18;

    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: addAmount,
      user: address(spoke1)
    });
    HubActions.draw({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      to: address(spoke1),
      amount: borrowAmount
    });

    uint256 storedRateBefore = hub1.getAsset(daiAssetId).drawnRate;

    skip(elapsed);

    // Stored rate remains unchanged
    assertEq(hub1.getAsset(daiAssetId).drawnRate, storedRateBefore);

    uint256 computedRate = hub1.getAssetDrawnRate(daiAssetId);
    IHub.Asset memory asset = hub1.getAsset(daiAssetId);
    uint256 currentDrawnIndex = hub1.getAssetDrawnIndex(daiAssetId);
    uint256 currentDrawn = uint256(asset.drawnShares).rayMulUp(currentDrawnIndex);
    uint256 expectedRate = IBasicInterestRateStrategy(asset.irStrategy).calculateInterestRate({
      assetId: daiAssetId,
      liquidity: asset.liquidity,
      drawn: currentDrawn,
      deficit: uint256(asset.deficitRay).fromRayUp(),
      swept: asset.swept
    });
    assertEq(computedRate, expectedRate);
  }
}
