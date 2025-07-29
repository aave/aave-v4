// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

contract LiquidityHubAccrueInterestTest is Base {
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
    uint256 supply0;
    uint256 supply1;
    uint256 supply2;
    uint256 supply3;
    uint256 supply4;
  }

  function setUp() public override {
    super.setUp();
    initEnvironment();
    spokeMintAndApprove();
  }

  /// no interest accrued when no action taken
  function test_accrueInterest_NoActionTaken() public view {
    DataTypes.Asset memory daiInfo = hub.getAsset(daiAssetId);
    assertEq(daiInfo.lastUpdateTimestamp, vm.getBlockTimestamp());
    assertEq(daiInfo.baseDebtIndex, WadRayMath.RAY);
    assertEq(daiInfo.realizedPremium, 0);
    assertEq(hub.getAssetSuppliedAmount(daiAssetId), 0);
    assertEq(getAssetBaseDebt(daiAssetId), 0);
  }

  /// no interest accrued with only supply
  function test_accrueInterest_NoInterest_OnlySupply(uint40 elapsed) public {
    elapsed = uint40(bound(elapsed, 1, type(uint40).max / 3));

    uint256 supplyAmount = 1000e18;
    Utils.add(hub, daiAssetId, address(spoke1), supplyAmount, address(spoke1));

    // Time passes
    skip(elapsed);

    // Spoke 2 does a supply to accrue interest
    Utils.add(hub, daiAssetId, address(spoke2), supplyAmount, address(spoke2));

    DataTypes.Asset memory daiInfo = hub.getAsset(daiAssetId);

    // Timestamp does not update when no interest accrued
    assertEq(daiInfo.lastUpdateTimestamp, vm.getBlockTimestamp(), 'lastUpdateTimestamp');
    assertEq(daiInfo.baseDebtIndex, WadRayMath.RAY, 'baseDebtIndex');
    assertEq(hub.getAssetSuppliedAmount(daiAssetId), supplyAmount * 2);
    assertEq(getAssetBaseDebt(daiAssetId), 0);
  }

  /// no interest accrued when no debt after repay
  function test_accrueInterest_NoInterest_NoDebt(uint40 elapsed) public {
    elapsed = uint40(bound(elapsed, 1, type(uint40).max / 3));

    uint256 supplyAmount = 1000e18;
    uint256 supplyAmount2 = 100e18;
    uint256 startTime = vm.getBlockTimestamp();
    uint256 borrowAmount = 100e18;
    uint256 initialDebtIndex = WadRayMath.RAY;

    Utils.add(hub, daiAssetId, address(spoke1), supplyAmount, address(spoke1));
    Utils.draw(hub, daiAssetId, address(spoke1), address(spoke1), borrowAmount);
    uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);

    // Time passes
    skip(elapsed);

    // Spoke 2 does a supply to accrue interest
    Utils.add(hub, daiAssetId, address(spoke2), supplyAmount2, address(spoke2));

    DataTypes.Asset memory daiInfo = hub.getAsset(daiAssetId);

    (uint256 expectedDebtIndex1, uint256 expectedBaseDebt1) = calculateExpectedDebt(
      daiInfo.baseDrawnShares,
      initialDebtIndex,
      baseBorrowRate,
      uint40(startTime)
    );
    uint256 interest = expectedBaseDebt1 - borrowAmount;

    assertEq(elapsed, daiInfo.lastUpdateTimestamp - startTime);
    assertEq(daiInfo.baseDebtIndex, expectedDebtIndex1, 'baseDebtIndex');
    assertEq(
      hub.getAssetSuppliedAmount(daiAssetId),
      supplyAmount + supplyAmount2 + interest,
      'supplyAmount'
    );
    assertEq(getAssetBaseDebt(daiAssetId), expectedBaseDebt1, 'baseDebt');

    startTime = vm.getBlockTimestamp();
    baseBorrowRate = hub.getBaseInterestRate(daiAssetId);

    // calculate expected debt to repay
    (uint256 expectedDebtIndex2, uint256 expectedBaseDebt2) = calculateExpectedDebt(
      daiInfo.baseDrawnShares,
      expectedDebtIndex1,
      baseBorrowRate,
      uint40(startTime)
    );

    // Full repayment, so back to zero debt
    Utils.restore(hub, daiAssetId, address(spoke1), borrowAmount + interest, 0, address(spoke1));

    assertEq(expectedDebtIndex2, expectedDebtIndex1, 'expectedDebtIndex');
    assertEq(expectedBaseDebt2, expectedBaseDebt1, 'expectedBaseDebt');

    daiInfo = hub.getAsset(daiAssetId);

    // Timestamp does not update when no interest accrued
    assertEq(daiInfo.lastUpdateTimestamp, vm.getBlockTimestamp(), 'lastUpdateTimestamp');
    assertEq(daiInfo.baseDebtIndex, expectedDebtIndex2, 'baseDebtIndex2');
    assertEq(
      hub.getAssetSuppliedAmount(daiAssetId),
      supplyAmount + supplyAmount2 + interest,
      'supplyAmount'
    );
    assertEq(getAssetBaseDebt(daiAssetId), 0, 'baseDebt');

    // Time passes
    skip(elapsed);

    // Spoke 2 does a supply to accrue interest
    Utils.add(hub, daiAssetId, address(spoke2), supplyAmount2, address(spoke2));

    daiInfo = hub.getAsset(daiAssetId);

    assertEq(daiInfo.lastUpdateTimestamp, vm.getBlockTimestamp(), 'lastUpdateTimestamp');
    assertEq(daiInfo.baseDebtIndex, expectedDebtIndex2, 'baseDebtIndex2');
    assertEq(
      hub.getAssetSuppliedAmount(daiAssetId),
      supplyAmount + supplyAmount2 * 2 + interest,
      'supplyAmount'
    );
    assertEq(getAssetBaseDebt(daiAssetId), 0, 'baseDebt');
  }

  /// accrue interest after some time has passed
  function test_accrueInterest_fuzz_BorrowAndWait(uint40 elapsed) public {
    elapsed = uint40(bound(elapsed, 1, type(uint40).max / 3));

    uint256 supplyAmount = 1000e18;
    uint256 supplyAmount2 = 100e18;
    uint256 startTime = vm.getBlockTimestamp();
    uint256 borrowAmount = 100e18;
    uint256 initialDebtIndex = WadRayMath.RAY;

    Utils.add(hub, daiAssetId, address(spoke1), supplyAmount, address(spoke1));
    Utils.draw(hub, daiAssetId, address(spoke1), address(spoke1), borrowAmount);
    uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);

    // Time passes
    skip(elapsed);

    // Spoke 2 does a supply to accrue interest
    Utils.add(hub, daiAssetId, address(spoke2), supplyAmount2, address(spoke2));

    DataTypes.Asset memory daiInfo = hub.getAsset(daiAssetId);

    (uint256 expectedDebtIndex, uint256 expectedBaseDebt) = calculateExpectedDebt(
      daiInfo.baseDrawnShares,
      initialDebtIndex,
      baseBorrowRate,
      uint40(startTime)
    );
    uint256 interest = expectedBaseDebt - borrowAmount;

    assertEq(elapsed, daiInfo.lastUpdateTimestamp - startTime);
    assertEq(daiInfo.baseDebtIndex, expectedDebtIndex, 'baseDebtIndex');
    assertEq(
      hub.getAssetSuppliedAmount(daiAssetId),
      supplyAmount + supplyAmount2 + interest,
      'supplyAmount'
    );
    assertEq(getAssetBaseDebt(daiAssetId), expectedBaseDebt, 'baseDebt');
  }

  /// accrue interest on any borrow amount after any time has passed
  function test_accrueInterest_fuzz_BorrowAmountAndElapsed(
    uint256 borrowAmount,
    uint40 elapsed
  ) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    elapsed = uint40(bound(elapsed, 1, type(uint40).max / 3));

    uint256 startTime = vm.getBlockTimestamp();
    uint256 supplyAmount = borrowAmount * 2;
    uint256 supplyAmount2 = 100e18;
    uint256 initialDebtIndex = WadRayMath.RAY;

    Utils.add(hub, daiAssetId, address(spoke1), supplyAmount, address(spoke1));
    Utils.draw(hub, daiAssetId, address(spoke1), address(spoke1), borrowAmount);
    uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);

    // Time passes
    skip(elapsed);

    // Spoke 2 does a supply to accrue interest
    Utils.add(hub, daiAssetId, address(spoke2), supplyAmount2, address(spoke2));

    DataTypes.Asset memory daiInfo = hub.getAsset(daiAssetId);

    (uint256 expectedDebtIndex, uint256 expectedBaseDebt) = calculateExpectedDebt(
      daiInfo.baseDrawnShares,
      initialDebtIndex,
      baseBorrowRate,
      uint40(startTime)
    );
    uint256 interest = expectedBaseDebt - borrowAmount;

    assertEq(elapsed, daiInfo.lastUpdateTimestamp - startTime);
    assertEq(daiInfo.baseDebtIndex, expectedDebtIndex, 'baseDebtIndex');
    assertEq(
      hub.getAssetSuppliedAmount(daiAssetId),
      supplyAmount + supplyAmount2 + interest,
      'supplyAmount'
    );
    assertEq(getAssetBaseDebt(daiAssetId), expectedBaseDebt, 'baseDebt');
  }

  function test_accrueInterest_TenPercentRP(uint256 borrowAmount, uint40 elapsed) public {
    vm.skip(true, 'move to hub premium debt tests');
    // borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);

    // uint256 startTime = vm.getBlockTimestamp();
    // uint256 supplyAmount = borrowAmount * 2;
    // uint256 initialDebtIndex = WadRayMath.RAY;
    // uint32 riskPremium = 10_00;

    // Utils.add(hub, daiAssetId, address(spoke1), supplyAmount, address(spoke1), address(spoke1));
    // Utils.draw(hub, daiAssetId, address(spoke1), address(spoke1), borrowAmount, address(spoke1));
    // // refresh risk premium
    // uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);

    // // Time passes
    // skip(elapsed);

    // // Spoke 2 does a supply to accrue interest
    // Utils.add(hub, daiAssetId, address(spoke2), 1000e18, address(spoke2), address(spoke2));

    // DataTypes.Asset memory daiInfo = hub.getAsset(daiAssetId);

    // uint256 expectedDebtIndex = _calculateExpectedDebtIndex(
    //   initialDebtIndex,
    //   baseBorrowRate,
    //   uint40(startTime)
    // );

    // assertEq(daiInfo.lastUpdateTimestamp - startTime, elapsed);
    // assertEq(daiInfo.baseDebtIndex, expectedDebtIndex, 'baseDebtIndex');
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
    //     uint256 supplyAmount = borrowAmount * 2;
    //     uint256 startTime = vm.getBlockTimestamp();

    //     vm.startPrank(address(spoke1));
    //     hub.supply(daiAssetId, supplyAmount, 0, address(spoke1));
    //     hub.draw(daiAssetId, borrowAmount, riskPremium, address(spoke1));
    //     uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);
    //     vm.stopPrank();

    //     // Time passes
    //     skip(elapsed);

    //     // Spoke 2 does a supply to accrue interest
    //     Utils.add(hub, daiAssetId, address(spoke2), 1000e18, 0, address(spoke2), address(spoke2));

    //     DataTypes.Asset memory daiInfo = hub.getAsset(daiAssetId);

    //     uint256 totalBase = MathUtils.calculateLinearInterest(baseBorrowRate, uint40(startTime)).rayMul(
    //       borrowAmount
    //     );

    //     assertEq(daiInfo.lastUpdateTimestamp - startTime, elapsed);
    //     assertEq(daiInfo.baseDebt, totalBase);
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
    uint256 initialDebtIndex = WadRayMath.RAY;
    uint256 supplyAmount2 = 1000e18;

    Timestamps memory timestamps;
    AssetDataLocal memory assetData;
    Spoke1Amounts memory spoke1Amounts;
    CumulatedInterest memory cumulated;

    spoke1Amounts.supply0 = borrowAmount * 2;
    timestamps.t0 = uint40(vm.getBlockTimestamp());

    Utils.add(hub, daiAssetId, address(spoke1), spoke1Amounts.supply0, address(spoke1));
    Utils.draw(hub, daiAssetId, address(spoke1), address(spoke1), borrowAmount);

    assetData.t0 = hub.getAsset(daiAssetId);

    // Time passes
    skip(elapsed);

    // Spoke 2 does a supply to accrue interest
    Utils.add(hub, daiAssetId, address(spoke2), supplyAmount2, address(spoke2));

    assetData.t1 = hub.getAsset(daiAssetId);
    timestamps.t1 = uint40(vm.getBlockTimestamp());
    (uint256 expectedDebtIndex, uint256 expectedBaseDebt1) = calculateExpectedDebt(
      assetData.t0.baseDrawnShares,
      initialDebtIndex,
      assetData.t0.baseBorrowRate,
      timestamps.t0
    );
    cumulated.t1 = expectedDebtIndex;
    uint256 interest1 = expectedBaseDebt1 - borrowAmount;

    assertEq(assetData.t1.lastUpdateTimestamp - timestamps.t0, elapsed, 'elapsed');
    assertEq(assetData.t1.baseDebtIndex, cumulated.t1, 'baseDebtIndex');
    assertEq(
      hub.getAssetSuppliedAmount(daiAssetId),
      spoke1Amounts.supply0 + supplyAmount2 + interest1,
      'supplyAmount'
    );
    assertEq(getAssetBaseDebt(daiAssetId), expectedBaseDebt1, 'baseDebt');

    // Say borrow rate changes
    _mockInterestRateBps(borrowRate);
    // Make an action to cache this new borrow rate
    Utils.add(hub, daiAssetId, address(spoke2), supplyAmount2, address(spoke2));

    // Time passes
    skip(elapsed);
    timestamps.t2 = uint40(vm.getBlockTimestamp());

    // Spoke 2 does a supply to accrue interest
    Utils.add(hub, daiAssetId, address(spoke2), supplyAmount2, address(spoke2));

    assetData.t2 = hub.getAsset(daiAssetId);
    timestamps.t2 = uint40(vm.getBlockTimestamp());
    uint256 expectedBaseDebt2;
    (expectedDebtIndex, expectedBaseDebt2) = calculateExpectedDebt(
      assetData.t0.baseDrawnShares,
      cumulated.t1,
      assetData.t2.baseBorrowRate,
      timestamps.t1
    );
    cumulated.t2 = expectedDebtIndex;
    uint256 interest2 = expectedBaseDebt2 - expectedBaseDebt1;

    assertEq(assetData.t2.lastUpdateTimestamp - timestamps.t1, elapsed, 'elapsed');
    assertEq(assetData.t2.baseDebtIndex, cumulated.t2, 'baseDebtIndex t2');
    assertEq(
      hub.getAssetSuppliedAmount(daiAssetId),
      spoke1Amounts.supply0 + supplyAmount2 * 3 + interest1 + interest2,
      'supplyAmount t2'
    );
    assertEq(getAssetBaseDebt(daiAssetId), expectedBaseDebt2, 'baseDebt t2');
  }
}
