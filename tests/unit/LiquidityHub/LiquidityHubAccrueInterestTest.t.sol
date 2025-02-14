// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/BaseTest.t.sol';
import {SpokeData} from 'src/contracts/LiquidityHub.sol';
import {Asset} from 'src/contracts/LiquidityHub.sol';
import {Utils} from 'tests/Utils.t.sol';

contract LiquidityHubAccrueInterestTest is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  uint256 public constant MAX_BPS = 999_99;

  struct SpokeDataLocal {
    SpokeData t0;
    SpokeData t1;
    SpokeData t2;
    SpokeData t3;
    SpokeData t4;
  }

  struct Spoke4Amounts {
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

  struct Timestamps {
    uint40 t0;
    uint40 t1;
    uint40 t2;
    uint40 t3;
    uint40 t4;
  }

  struct Spoke1DataLocal {
    SpokeData t0;
    SpokeData t1;
    SpokeData t2;
    SpokeData t3;
    SpokeData t4;
  }

  struct Spoke2DataLocal {
    SpokeData t0;
    SpokeData t1;
    SpokeData t2;
    SpokeData t3;
    SpokeData t4;
  }

  struct AssetDataLocal {
    Asset t0;
    Asset t1;
    Asset t2;
    Asset t3;
    Asset t4;
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

  struct Spoke2Amounts {
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

  function test_accrueInterest_NoActionTaken() public {
    Asset memory daiInfo = hub.getAsset(daiAssetId);
    assertEq(daiInfo.lastUpdateTimestamp, vm.getBlockTimestamp());
    assertEq(daiInfo.baseDebt, 0);
    assertEq(daiInfo.outstandingPremium, 0);
    assertEq(daiInfo.riskPremiumRad, 0);
  }

  function test_accrueInterest_OnlySupply(uint40 elapsed) public {
    uint256 startTime = vm.getBlockTimestamp();

    Utils.supply(hub, daiAssetId, address(spoke1), 1000e18, 0, address(spoke1), address(spoke1));

    // Time passes
    skip(elapsed);

    // Spoke 2 does a supply to accrue interest
    Utils.supply(hub, daiAssetId, address(spoke2), 1000e18, 0, address(spoke2), address(spoke2));

    Asset memory daiInfo = hub.getAsset(daiAssetId);

    // Timestamp doesn't update when no interest accrued
    assertEq(daiInfo.lastUpdateTimestamp, vm.getBlockTimestamp(), 'lastUpdateTimestamp');
    assertEq(daiInfo.baseDebt, 0, 'baseDebt');
    assertEq(daiInfo.riskPremiumRad, 0, 'riskPremiumRad');
    assertEq(daiInfo.outstandingPremium, 0, 'outstandingPremium');
  }

  function test_accrueInterest_fuzz_BorrowAndWait(uint40 elapsed) public {
    uint256 startTime = vm.getBlockTimestamp();
    uint256 initialDebt = 100e18;

    Utils.supply(hub, daiAssetId, address(spoke1), 1000e18, 0, address(spoke1), address(spoke1));
    Utils.draw(hub, daiAssetId, address(spoke1), address(spoke1), initialDebt, 0, address(spoke1));
    uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);

    // Time passes
    skip(elapsed);

    // Spoke 2 does a supply to accrue interest
    Utils.supply(hub, daiAssetId, address(spoke2), 1000e18, 0, address(spoke2), address(spoke2));

    Asset memory daiInfo = hub.getAsset(daiAssetId);

    uint256 totalBase = MathUtils.calculateLinearInterest(baseBorrowRate, uint40(startTime)).rayMul(
      initialDebt
    );

    assertEq(elapsed, daiInfo.lastUpdateTimestamp - startTime);
    assertEq(daiInfo.baseDebt, totalBase);
    assertEq(daiInfo.riskPremiumRad, 0);
    assertEq(daiInfo.outstandingPremium, 0);
  }

  function test_accrueInterest_fuzz_BorrowAmountAndElapsed(
    uint256 borrowAmount,
    uint40 elapsed
  ) public {
    borrowAmount = bound(borrowAmount, 1, 1e30);
    uint256 supplyAmount = borrowAmount * 2;
    uint256 startTime = vm.getBlockTimestamp();

    Utils.supply(
      hub,
      daiAssetId,
      address(spoke1),
      supplyAmount,
      0,
      address(spoke1),
      address(spoke1)
    );
    Utils.draw(hub, daiAssetId, address(spoke1), address(spoke1), borrowAmount, 0, address(spoke1));
    uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);

    // Time passes
    skip(elapsed);

    // Spoke 2 does a supply to accrue interest
    Utils.supply(hub, daiAssetId, address(spoke2), 1000e18, 0, address(spoke2), address(spoke2));

    Asset memory daiInfo = hub.getAsset(daiAssetId);

    uint256 totalBase = MathUtils.calculateLinearInterest(baseBorrowRate, uint40(startTime)).rayMul(
      borrowAmount
    );

    assertEq(elapsed, daiInfo.lastUpdateTimestamp - startTime);
    assertEq(daiInfo.baseDebt, totalBase);
    assertEq(daiInfo.riskPremiumRad, 0);
    assertEq(daiInfo.outstandingPremium, 0);
  }

  function test_accrueInterest_TenPercentRP(uint256 borrowAmount, uint40 elapsed) public {
    borrowAmount = bound(borrowAmount, 1, 1e30);
    uint256 riskPremium = uint256(10_00).bpsToRad();
    uint256 supplyAmount = borrowAmount * 2;
    uint256 startTime = vm.getBlockTimestamp();

    vm.startPrank(address(spoke1));
    hub.supply(daiAssetId, supplyAmount, 0, address(spoke1));
    hub.draw(daiAssetId, borrowAmount, riskPremium, address(spoke1));
    uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);
    vm.stopPrank();

    // Time passes
    skip(elapsed);

    // Spoke 2 does a supply to accrue interest
    Utils.supply(hub, daiAssetId, address(spoke2), 1000e18, 0, address(spoke2), address(spoke2));

    Asset memory daiInfo = hub.getAsset(daiAssetId);

    uint256 totalBase = MathUtils.calculateLinearInterest(baseBorrowRate, uint40(startTime)).rayMul(
      borrowAmount
    );

    assertEq(daiInfo.lastUpdateTimestamp - startTime, elapsed);
    assertEq(daiInfo.baseDebt, totalBase);
    assertEq(daiInfo.riskPremiumRad, riskPremium);
    assertEq(daiInfo.outstandingPremium, (totalBase - borrowAmount).radMul(riskPremium));
  }

  function test_accrueInterest_fuzz_RPBorrowAndElapsed(
    uint256 borrowAmount,
    uint40 elapsed,
    uint256 riskPremium
  ) public {
    borrowAmount = bound(borrowAmount, 1, 1e30);
    riskPremium = bound(riskPremium, 0, MAX_BPS.bpsToRad());
    uint256 supplyAmount = borrowAmount * 2;
    uint256 startTime = vm.getBlockTimestamp();

    vm.startPrank(address(spoke1));
    hub.supply(daiAssetId, supplyAmount, 0, address(spoke1));
    hub.draw(daiAssetId, borrowAmount, riskPremium, address(spoke1));
    uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);
    vm.stopPrank();

    // Time passes
    skip(elapsed);

    // Spoke 2 does a supply to accrue interest
    Utils.supply(hub, daiAssetId, address(spoke2), 1000e18, 0, address(spoke2), address(spoke2));

    Asset memory daiInfo = hub.getAsset(daiAssetId);

    uint256 totalBase = MathUtils.calculateLinearInterest(baseBorrowRate, uint40(startTime)).rayMul(
      borrowAmount
    );

    assertEq(daiInfo.lastUpdateTimestamp - startTime, elapsed);
    assertEq(daiInfo.baseDebt, totalBase);
    assertEq(daiInfo.riskPremiumRad, riskPremium);
    assertEq(daiInfo.outstandingPremium, (totalBase - borrowAmount).radMul(riskPremium));
  }

  function test_accrueInterest_fuzz_ChangingBorrowRate(
    uint256 borrowAmount,
    uint40 elapsed,
    uint256 riskPremium
  ) public {
    elapsed = uint40(bound(elapsed, 1, type(uint40).max / 3));
    borrowAmount = bound(borrowAmount, 1, 1e30);
    riskPremium = bound(riskPremium, 0, MAX_BPS.bpsToRad());

    Timestamps memory timestamps;
    AssetDataLocal memory assetData;
    Spoke1DataLocal memory spokeData;
    Spoke1Amounts memory spoke1Amounts;
    Spoke2Amounts memory spoke2Amounts;
    CumulatedInterest memory cumulated;

    spoke1Amounts.supply0 = borrowAmount * 2;
    timestamps.t0 = uint40(vm.getBlockTimestamp());

    vm.startPrank(address(spoke1));
    hub.supply(daiAssetId, spoke1Amounts.supply0, 0, address(spoke1));
    hub.draw(daiAssetId, borrowAmount, riskPremium, address(spoke1));
    vm.stopPrank();

    assetData.t0 = hub.getAsset(daiAssetId);

    // Time passes
    skip(elapsed);
    timestamps.t1 = uint40(vm.getBlockTimestamp());
    cumulated.t1 = MathUtils.calculateLinearInterest(assetData.t0.baseBorrowRate, timestamps.t0);

    // Spoke 2 does a supply to accrue interest
    Utils.supply(hub, daiAssetId, address(spoke2), 1000e18, 0, address(spoke2), address(spoke2));

    // Spoke 1's debt individually has not yet accrued, even though total debt has accrued
    assertEq(hub.getSpoke(daiAssetId, address(spoke1)).baseDebt, borrowAmount);

    assetData.t1 = hub.getAsset(daiAssetId);

    uint256 totalBase = borrowAmount
      .rayMul(cumulated.t1.rayMul(assetData.t0.baseBorrowIndex))
      .rayDiv(assetData.t0.baseBorrowIndex);

    assertEq(assetData.t1.lastUpdateTimestamp - timestamps.t0, elapsed, 'elapsed');
    assertEq(assetData.t1.baseDebt, totalBase, 'baseDebt');
    assertEq(assetData.t1.riskPremiumRad, riskPremium, 'riskPremiumRad');
    assertEq(
      assetData.t1.outstandingPremium,
      (totalBase - borrowAmount).radMul(riskPremium),
      'outstandingPremium'
    );

    // Say borrow rate changes
    uint256 baseBorrowRate = 2 * assetData.t1.baseBorrowRate;
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(baseBorrowRate)
    );
    // Make an action to cache this new borrow rate
    Utils.supply(hub, daiAssetId, address(spoke2), 1000e18, 0, address(spoke2), address(spoke2));

    assetData.t1 = hub.getAsset(daiAssetId);

    // Time passes
    skip(elapsed);
    timestamps.t2 = uint40(vm.getBlockTimestamp());

    // Spoke 2 does a supply to accrue interest
    Utils.supply(hub, daiAssetId, address(spoke2), 1000e18, 0, address(spoke2), address(spoke2));

    // Spoke 1's debt individually has not yet accrued, even though total debt has accrued
    assertEq(hub.getSpoke(daiAssetId, address(spoke1)).baseDebt, borrowAmount);

    assetData.t2 = hub.getAsset(daiAssetId);
    cumulated.t2 = MathUtils.calculateLinearInterest(assetData.t2.baseBorrowRate, timestamps.t1);

    totalBase = totalBase.rayMul(cumulated.t2.rayMul(assetData.t1.baseBorrowIndex)).rayDiv(
      assetData.t1.baseBorrowIndex
    );

    assertEq(elapsed * 2, vm.getBlockTimestamp() - timestamps.t0, 'elapsed');
    assertApproxEqAbs(totalBase, assetData.t2.baseDebt, 1, 'baseDebt');
    assertEq(assetData.t2.riskPremiumRad, riskPremium, 'riskPremiumRad');
    assertApproxEqAbs(
      (totalBase - borrowAmount).radMul(riskPremium),
      assetData.t2.outstandingPremium,
      1,
      'outstandingPremium'
    );
  }
}
