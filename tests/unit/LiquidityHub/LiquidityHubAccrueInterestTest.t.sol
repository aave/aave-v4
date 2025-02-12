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
    assertEq(daiInfo.lastUpdateTimestamp, startTime);
    assertEq(daiInfo.baseDebt, 0);
    assertEq(daiInfo.riskPremiumRad, 0);
    assertEq(daiInfo.outstandingPremium, 0);
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
    uint256 supplyAmount = borrowAmount * 2;
    uint256 startTime = vm.getBlockTimestamp();
    uint256 lastUpdate = startTime;

    vm.startPrank(address(spoke1));
    hub.supply(daiAssetId, supplyAmount, 0, address(spoke1));
    hub.draw(daiAssetId, borrowAmount, riskPremium, address(spoke1));
    uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);
    vm.stopPrank();

    // Time passes
    skip(elapsed);

    // Spoke 2 does a supply to accrue interest
    Utils.supply(hub, daiAssetId, address(spoke2), 1000e18, 0, address(spoke2), address(spoke2));

    // Spoke 1's debt individually has not yet accrued, even though total debt has accrued
    assertEq(hub.getSpoke(daiAssetId, address(spoke1)).baseDebt, borrowAmount);

    Asset memory daiInfo = hub.getAsset(daiAssetId);

    uint256 totalBase = MathUtils
      .calculateLinearInterest(baseBorrowRate, uint40(lastUpdate))
      .rayMul(borrowAmount);

    assertEq(daiInfo.lastUpdateTimestamp - lastUpdate, elapsed);
    assertEq(daiInfo.baseDebt, totalBase);
    assertEq(daiInfo.riskPremiumRad, riskPremium);
    assertEq(daiInfo.outstandingPremium, (totalBase - borrowAmount).radMul(riskPremium));

    // Say borrow rate changes
    baseBorrowRate *= 2;
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(baseBorrowRate)
    );
    // Make an action to cache this new borrow rate
    Utils.supply(hub, daiAssetId, address(spoke2), 1000e18, 0, address(spoke2), address(spoke2));

    lastUpdate = vm.getBlockTimestamp();
    // Time passes
    skip(elapsed);

    // Spoke 2 does a supply to accrue interest
    Utils.supply(hub, daiAssetId, address(spoke2), 1000e18, 0, address(spoke2), address(spoke2));

    // Spoke 1's debt individually has not yet accrued, even though total debt has accrued
    assertEq(hub.getSpoke(daiAssetId, address(spoke1)).baseDebt, borrowAmount);

    totalBase += totalBase.rayMul(
      MathUtils.calculateLinearInterest(baseBorrowRate, uint40(lastUpdate)) - WadRayMath.RAY
    );

    daiInfo = hub.getAsset(daiAssetId);

    assertEq(elapsed * 2, vm.getBlockTimestamp() - startTime);
    assertEq(daiInfo.baseDebt, totalBase);
    assertEq(daiInfo.riskPremiumRad, riskPremium);
    assertApproxEqAbs(
      daiInfo.outstandingPremium,
      (totalBase - borrowAmount).radMul(riskPremium),
      1
    );
  }
}
