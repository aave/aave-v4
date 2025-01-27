// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';
import {SpokeData} from 'src/contracts/LiquidityHub.sol';
import {Asset} from 'src/contracts/LiquidityHub.sol';

contract LiquidityHubInterestRateTest is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  uint256 public daiAssetId = 2;
  uint256 public constant maxBps = 999_99;

  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

  function test_getInterestRate_NoActionTaken() public {
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    assertEq(borrowRate, 0);
  }

  function test_getInterestRate_Supply() public {
    deal(address(tokenList.dai), address(spoke1), 1000e18);

    vm.startPrank(address(spoke1));
    SpokeData memory test = hub.getSpoke(daiAssetId, address(spoke1));
    tokenList.dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    // No change to risk premium, so borrow rate is just the base rate
    assertEq(_getBaseBorrowRate(daiAssetId), _getBorrowRate(daiAssetId));
    vm.stopPrank();
  }

  function test_getInterestRate_Borrow() public {
    // Spoke 1's first borrow should adjust the overall borrow rate with a risk premium of 10%
    uint256 newRiskPremium = uint256(10_00).bpsToRad();
    deal(address(tokenList.dai), address(spoke1), 1000e18);
    vm.startPrank(address(spoke1));
    tokenList.dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), 100e18, newRiskPremium);
    vm.stopPrank();
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium.radToRay().rayMul(baseBorrowRate)));
  }

  function test_getInterestRate_fuzz_Borrow(uint256 newRiskPremium) public {
    newRiskPremium = bound(newRiskPremium, 0, maxBps.bpsToRad());
    // Spoke 1's first borrow should set the overall borrow rate
    deal(address(tokenList.dai), address(spoke1), 1000e18);
    vm.startPrank(address(spoke1));
    tokenList.dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), 100e18, newRiskPremium);
    vm.stopPrank();
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium.radToRay().rayMul(baseBorrowRate)));
  }

  function test_getInterestRate_BorrowAndSupply() public {
    uint256 newRiskPremium = uint256(10_00).bpsToRad();
    deal(address(tokenList.dai), address(spoke1), 2000e18);
    vm.startPrank(address(spoke1));
    tokenList.dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), 100e18, newRiskPremium);
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium.radToRay().rayMul(baseBorrowRate)));

    // Now if we supply again, passing same risk premium, RP doesn't update
    tokenList.dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, newRiskPremium, address(spoke1));
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium.radToRay().rayMul(baseBorrowRate)));
    vm.stopPrank();
  }

  function test_getInterestRate_fuzz_BorrowAndSupply(uint256 newRiskPremium) public {
    newRiskPremium = bound(newRiskPremium, 0, maxBps.bpsToRad());
    deal(address(tokenList.dai), address(spoke1), 2000e18);
    vm.startPrank(address(spoke1));
    tokenList.dai.approve(address(hub), 2000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), 100e18, newRiskPremium);
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium.radToRay().rayMul(baseBorrowRate)));

    // Now if we supply again, passing same risk premium, RP doesn't update
    hub.supply(daiAssetId, 1000e18, newRiskPremium, address(spoke1));
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium.radToRay().rayMul(baseBorrowRate)));
    vm.stopPrank();
  }

  function test_getInterestRate_BorrowTwice() public {
    uint256 newRiskPremium = uint256(10_00).bpsToRad();
    deal(address(tokenList.dai), address(spoke1), 1000e18);
    vm.startPrank(address(spoke1));
    tokenList.dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), 100e18, newRiskPremium);
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium.radToRay().rayMul(baseBorrowRate)));

    // New risk premium from same spoke should replace avg risk premium
    uint256 newRiskPremium2 = uint256(20_00).bpsToRad();
    hub.draw(daiAssetId, address(spoke1), 100e18, newRiskPremium2);
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium2.radToRay().rayMul(baseBorrowRate)));
    vm.stopPrank();
  }

  function test_getInterestRate_fuzz_BorrowTwice(uint256 newRiskPremium) public {
    newRiskPremium = bound(newRiskPremium, 0, maxBps.bpsToRad());
    uint256 firstRiskPremium = uint256(10_00).bpsToRad();
    deal(address(tokenList.dai), address(spoke1), 1000e18);
    vm.startPrank(address(spoke1));
    tokenList.dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), 100e18, firstRiskPremium);
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (firstRiskPremium.radToRay().rayMul(baseBorrowRate)));

    // New risk premium from same spoke should replace avg risk premium
    hub.draw(daiAssetId, address(spoke1), 100e18, newRiskPremium);
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium.radToRay().rayMul(baseBorrowRate)));
    vm.stopPrank();
  }

  function test_getInterestRate_DrawTwoSpokes() public {
    uint256 rpSpoke1 = uint256(10_00).bpsToRad();
    uint256 rpSpoke2 = uint256(20_00).bpsToRad();
    deal(address(tokenList.dai), address(spoke1), 5000e18);
    vm.startPrank(address(spoke1));
    tokenList.dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), 100e18, rpSpoke1);
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (rpSpoke1.radToRay().rayMul(baseBorrowRate)));
    vm.stopPrank();

    // Next spoke risk premium should be averaged with the first
    deal(address(tokenList.dai), address(spoke2), 1000e18);
    vm.startPrank(address(spoke2));
    tokenList.dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke2));
    hub.draw(daiAssetId, address(spoke2), 100e18, rpSpoke2);
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(
      borrowRate,
      baseBorrowRate +
        ((rpSpoke1 + rpSpoke2).radToRay().rayMul(baseBorrowRate)).rayDiv(2 * WadRayMath.RAY)
    );
    vm.stopPrank();
  }

  function test_getInterestRate_fuzz_DrawTwoSpokes(uint256 rpSpoke1, uint256 rpSpoke2) public {
    rpSpoke1 = bound(rpSpoke1, 0, maxBps.bpsToRad());
    rpSpoke2 = bound(rpSpoke2, 0, maxBps.bpsToRad());
    rpSpoke1 = rpSpoke1.bpsToRad();
    rpSpoke2 = rpSpoke2.bpsToRad();
    deal(address(tokenList.dai), address(spoke1), 5000e18);
    vm.startPrank(address(spoke1));
    tokenList.dai.approve(address(hub), 5000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), 100e18, rpSpoke1);
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (rpSpoke1.radToRay().rayMul(baseBorrowRate)));
    vm.stopPrank();

    // Next spoke risk premium should be averaged with the first
    deal(address(tokenList.dai), address(spoke2), 5000e18);
    vm.startPrank(address(spoke2));
    tokenList.dai.approve(address(hub), 5000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke2));
    hub.draw(daiAssetId, address(spoke2), 100e18, rpSpoke2);
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(
      borrowRate,
      baseBorrowRate +
        (((rpSpoke1 + rpSpoke2).radToRay().rayMul(baseBorrowRate)).rayDiv(2 * WadRayMath.RAY))
    );
    vm.stopPrank();
  }

  function test_getInterestRate_DrawTwoSpokesDiffWeights() public {
    uint256 rpSpoke1 = uint256(10_00).bpsToRad();
    uint256 rpSpoke2 = uint256(20_00).bpsToRad();
    uint256 drawSpoke1 = 100e18;
    uint256 drawSpoke2 = 200e18;
    deal(address(tokenList.dai), address(spoke1), 5000e18);
    vm.startPrank(address(spoke1));
    tokenList.dai.approve(address(hub), 5000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), drawSpoke1, rpSpoke1);
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (rpSpoke1.radToRay().rayMul(baseBorrowRate)));
    vm.stopPrank();

    // Next spoke risk premium should be averaged with the first
    deal(address(tokenList.dai), address(spoke2), 5000e18);
    vm.startPrank(address(spoke2));
    tokenList.dai.approve(address(hub), 5000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke2));
    hub.draw(daiAssetId, address(spoke2), drawSpoke2, rpSpoke2);
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    uint256 calcRp = (rpSpoke1 * drawSpoke1 + rpSpoke2 * drawSpoke2) / (drawSpoke1 + drawSpoke2);
    assertEq(borrowRate, baseBorrowRate + (calcRp.radToRay().rayMul(baseBorrowRate)));
    vm.stopPrank();
  }

  function test_getInterestRate_fuzz_DrawTwoSpokesDiffWeights(
    uint256 rpSpoke1,
    uint256 drawSpoke1,
    uint256 supplySpoke1,
    uint256 rpSpoke2,
    uint256 drawSpoke2,
    uint256 supplySpoke2
  ) public {
    rpSpoke1 = bound(rpSpoke1, 0, maxBps.bpsToRad());
    supplySpoke1 = bound(supplySpoke1, 2, 1e60);
    drawSpoke1 = bound(drawSpoke1, 1, supplySpoke1 / 2);

    rpSpoke2 = bound(rpSpoke2, 0, maxBps.bpsToRad());
    supplySpoke2 = bound(supplySpoke2, 2, 1e60);
    drawSpoke2 = bound(drawSpoke2, 1, supplySpoke2 / 2);

    deal(address(tokenList.dai), address(spoke1), supplySpoke1);
    deal(address(tokenList.dai), address(spoke2), supplySpoke2);

    vm.startPrank(address(spoke1));
    tokenList.dai.approve(address(hub), supplySpoke1);
    hub.supply(daiAssetId, supplySpoke1, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), drawSpoke1, rpSpoke1);
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (rpSpoke1.radToRay().rayMul(baseBorrowRate)));
    vm.stopPrank();

    // Next spoke risk premium should be averaged with the first
    vm.startPrank(address(spoke2));
    tokenList.dai.approve(address(hub), supplySpoke2);
    hub.supply(daiAssetId, supplySpoke2, 0, address(spoke2));
    hub.draw(daiAssetId, address(spoke2), drawSpoke2, rpSpoke2);
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    uint256 calcRp = (rpSpoke1 * drawSpoke1 + rpSpoke2 * drawSpoke2) / (drawSpoke1 + drawSpoke2);
    assertEq(borrowRate, baseBorrowRate + (calcRp.radToRay().rayMul(baseBorrowRate)));
    vm.stopPrank();
  }

  function test_getInterestRate_fuzz_DrawThreeSpokesDiffWeights(
    uint256 rpSpoke1,
    uint256 drawSpoke1,
    uint256 rpSpoke2,
    uint256 drawSpoke2,
    uint256 rpSpoke3,
    uint256 drawSpoke3
  ) public {
    rpSpoke1 = bound(rpSpoke1, 0, maxBps.bpsToRad());
    drawSpoke1 = bound(drawSpoke1, 1, 1e40);

    rpSpoke2 = bound(rpSpoke2, 0, maxBps.bpsToRad());
    drawSpoke2 = bound(drawSpoke2, 1, 1e40);

    rpSpoke3 = bound(rpSpoke3, 0, maxBps.bpsToRad());
    drawSpoke3 = bound(drawSpoke3, 1, 1e40);

    deal(address(tokenList.dai), address(spoke1), 2e40);
    deal(address(tokenList.dai), address(spoke2), 2e40);
    deal(address(tokenList.dai), address(spoke3), 2e40);

    vm.startPrank(address(spoke1));
    tokenList.dai.approve(address(hub), 2e40);
    hub.supply(daiAssetId, 2e40, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), drawSpoke1, rpSpoke1);
    vm.stopPrank();

    vm.startPrank(address(spoke2));
    tokenList.dai.approve(address(hub), 2e40);
    hub.supply(daiAssetId, 2e40, 0, address(spoke2));
    hub.draw(daiAssetId, address(spoke2), drawSpoke2, rpSpoke2);
    vm.stopPrank();

    vm.startPrank(address(spoke3));
    tokenList.dai.approve(address(hub), 2e40);
    hub.supply(daiAssetId, 2e40, 0, address(spoke3));
    hub.draw(daiAssetId, address(spoke3), drawSpoke3, rpSpoke3);
    vm.stopPrank();

    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    uint256 newRp = hub.getAsset(daiAssetId).riskPremiumRad;
    assertEq(borrowRate, baseBorrowRate + (newRp.radToRay().rayMul(baseBorrowRate)));
  }

  // TODO: Test via calling functions on spokes - after spoke side is implemented

  function _getBaseBorrowRate(uint256 assetId) internal view returns (uint256) {
    return hub.getBaseInterestRate(assetId);
  }

  function _getBorrowRate(uint256 assetId) internal view returns (uint256) {
    return hub.getInterestRate(assetId);
  }
}

contract LiquidityHubAccrueInterestTest is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  uint256 public daiAssetId = 2;
  uint256 public constant maxBps = 999_99;

  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

  function test_accrueInterest_NoActionTaken() public {
    Asset memory daiInfo = hub.getAsset(daiAssetId);
    uint256 baseDebt = daiInfo.baseDebt;
    uint256 riskPremium = daiInfo.riskPremiumRad;
    uint256 outstandingPremium = daiInfo.outstandingPremium;
    uint256 lastUpdateTimestamp = daiInfo.lastUpdateTimestamp;
    uint256 elapsed = vm.getBlockTimestamp() - lastUpdateTimestamp;
    assertEq(elapsed, 0);
    assertEq(baseDebt, 0);
    assertEq(outstandingPremium, 0);
    assertEq(riskPremium, 0);
  }

  function test_accrueInterest_OnlySupply(uint40 elapsed) public {
    uint256 startTime = vm.getBlockTimestamp();

    deal(address(tokenList.dai), address(spoke1), 1000e18);
    vm.startPrank(address(spoke1));
    tokenList.dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    vm.stopPrank();

    // Time passes
    skip(elapsed);

    // Spoke 2 does a supply to accrue interest
    deal(address(tokenList.dai), address(spoke2), 1000e18);
    vm.startPrank(address(spoke2));
    tokenList.dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke2));
    vm.stopPrank();

    Asset memory daiInfo = hub.getAsset(daiAssetId);
    uint256 baseDebt = daiInfo.baseDebt;
    uint256 outstandingPremium = daiInfo.outstandingPremium;
    uint256 riskPremium = daiInfo.riskPremiumRad;
    uint256 lastUpdateTimestamp = daiInfo.lastUpdateTimestamp;

    // Timestamp doesn't update when no interest accrued
    assertEq(0, lastUpdateTimestamp - startTime);
    assertEq(baseDebt, 0);
    assertEq(riskPremium, 0);
    assertEq(outstandingPremium, 0);
  }

  function test_accrueInterest_fuzz_BorrowAndWait(uint40 elapsed) public {
    uint256 startTime = vm.getBlockTimestamp();
    uint256 initialDebt = 100e18;

    deal(address(tokenList.dai), address(spoke1), 1000e18);
    vm.startPrank(address(spoke1));
    tokenList.dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), initialDebt, 0);
    uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);
    vm.stopPrank();

    // Time passes
    skip(elapsed);

    // Spoke 2 does a supply to accrue interest
    deal(address(tokenList.dai), address(spoke2), 1000e18);
    vm.startPrank(address(spoke2));
    tokenList.dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke2));
    vm.stopPrank();

    Asset memory daiInfo = hub.getAsset(daiAssetId);
    uint256 baseDebt = daiInfo.baseDebt;
    uint256 outstandingPremium = daiInfo.outstandingPremium;
    uint256 riskPremium = daiInfo.riskPremiumRad;
    uint256 lastUpdateTimestamp = daiInfo.lastUpdateTimestamp;

    uint256 accruedBase = MathUtils
      .calculateLinearInterest(baseBorrowRate, uint40(startTime))
      .rayMul(initialDebt);

    assertEq(elapsed, lastUpdateTimestamp - startTime);
    assertEq(baseDebt, accruedBase);
    assertEq(riskPremium, 0);
    assertEq(outstandingPremium, 0);
  }

  function test_accrueInterest_fuzz_BorrowAmountAndElapsed(
    uint256 borrowAmount,
    uint40 elapsed
  ) public {
    borrowAmount = bound(borrowAmount, 1, 1e30);
    uint256 supplyAmount = borrowAmount * 2;
    uint256 startTime = vm.getBlockTimestamp();

    deal(address(tokenList.dai), address(spoke1), supplyAmount);
    vm.startPrank(address(spoke1));
    tokenList.dai.approve(address(hub), supplyAmount);
    hub.supply(daiAssetId, supplyAmount, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), borrowAmount, 0);
    uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);
    vm.stopPrank();

    // Time passes
    skip(elapsed);

    // Spoke 2 does a supply to accrue interest
    deal(address(tokenList.dai), address(spoke2), 1000e18);
    vm.startPrank(address(spoke2));
    tokenList.dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke2));
    vm.stopPrank();

    Asset memory daiInfo = hub.getAsset(daiAssetId);
    uint256 baseDebt = daiInfo.baseDebt;
    uint256 outstandingPremium = daiInfo.outstandingPremium;
    uint256 riskPremium = daiInfo.riskPremiumRad;
    uint256 lastUpdateTimestamp = daiInfo.lastUpdateTimestamp;

    uint256 totalBase = MathUtils.calculateLinearInterest(baseBorrowRate, uint40(startTime)).rayMul(
      borrowAmount
    );

    assertEq(elapsed, lastUpdateTimestamp - startTime);
    assertEq(baseDebt, totalBase);
    assertEq(riskPremium, 0);
    assertEq(outstandingPremium, 0);
  }

  function test_accrueInterest_TenPercentRP(uint256 borrowAmount, uint40 elapsed) public {
    borrowAmount = bound(borrowAmount, 1, 1e30);
    uint256 riskPremium = uint256(10_00).bpsToRad();
    uint256 supplyAmount = borrowAmount * 2;
    uint256 startTime = vm.getBlockTimestamp();

    deal(address(tokenList.dai), address(spoke1), supplyAmount);
    vm.startPrank(address(spoke1));
    tokenList.dai.approve(address(hub), supplyAmount);
    hub.supply(daiAssetId, supplyAmount, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), borrowAmount, riskPremium);
    uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);
    vm.stopPrank();

    // Time passes
    skip(elapsed);

    // Spoke 2 does a supply to accrue interest
    deal(address(tokenList.dai), address(spoke2), 1000e18);
    vm.startPrank(address(spoke2));
    tokenList.dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke2));
    vm.stopPrank();

    Asset memory daiInfo = hub.getAsset(daiAssetId);
    uint256 baseDebt = daiInfo.baseDebt;
    uint256 outstandingPremium = daiInfo.outstandingPremium;
    uint256 avgRiskPremium = daiInfo.riskPremiumRad;
    uint256 lastUpdateTimestamp = daiInfo.lastUpdateTimestamp;

    uint256 totalBase = MathUtils.calculateLinearInterest(baseBorrowRate, uint40(startTime)).rayMul(
      borrowAmount
    );

    assertEq(elapsed, lastUpdateTimestamp - startTime);
    assertEq(baseDebt, totalBase);
    assertEq(avgRiskPremium, riskPremium);
    assertEq(outstandingPremium, (totalBase - borrowAmount).radMul(riskPremium));
  }

  function test_accrueInterest_fuzz_RPBorrowAndElapsed(
    uint256 borrowAmount,
    uint40 elapsed,
    uint256 riskPremium
  ) public {
    borrowAmount = bound(borrowAmount, 1, 1e30);
    riskPremium = bound(riskPremium, 0, maxBps.bpsToRad());
    uint256 supplyAmount = borrowAmount * 2;
    uint256 startTime = vm.getBlockTimestamp();

    deal(address(tokenList.dai), address(spoke1), supplyAmount);
    vm.startPrank(address(spoke1));
    tokenList.dai.approve(address(hub), supplyAmount);
    hub.supply(daiAssetId, supplyAmount, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), borrowAmount, riskPremium);
    uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);
    vm.stopPrank();

    // Time passes
    skip(elapsed);

    // Spoke 2 does a supply to accrue interest
    deal(address(tokenList.dai), address(spoke2), 1000e18);
    vm.startPrank(address(spoke2));
    tokenList.dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke2));
    vm.stopPrank();

    Asset memory daiInfo = hub.getAsset(daiAssetId);
    uint256 baseDebt = daiInfo.baseDebt;
    uint256 outstandingPremium = daiInfo.outstandingPremium;
    uint256 avgRiskPremium = daiInfo.riskPremiumRad;
    uint256 lastUpdateTimestamp = daiInfo.lastUpdateTimestamp;

    uint256 totalBase = MathUtils.calculateLinearInterest(baseBorrowRate, uint40(startTime)).rayMul(
      borrowAmount
    );

    assertEq(elapsed, lastUpdateTimestamp - startTime);
    assertEq(baseDebt, totalBase);
    assertEq(avgRiskPremium, riskPremium);
    assertEq(outstandingPremium, (totalBase - borrowAmount).radMul(riskPremium));
  }

  function test_accrueInterest_fuzz_ChangingBorrowRate(
    uint256 borrowAmount,
    uint40 elapsed,
    uint256 riskPremium
  ) public {
    elapsed = uint40(bound(elapsed, 1, type(uint40).max / 3));
    borrowAmount = bound(borrowAmount, 1, 1e30);
    riskPremium = bound(riskPremium, 0, maxBps.bpsToRad());
    uint256 supplyAmount = borrowAmount * 2;
    uint256 startTime = vm.getBlockTimestamp();

    deal(address(tokenList.dai), address(spoke1), supplyAmount);
    vm.startPrank(address(spoke1));
    tokenList.dai.approve(address(hub), supplyAmount);
    hub.supply(daiAssetId, supplyAmount, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), borrowAmount, riskPremium);
    uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);
    vm.stopPrank();

    // Time passes
    skip(elapsed);

    // Spoke 2 does a supply to accrue interest
    deal(address(tokenList.dai), address(spoke2), 1000e18);
    vm.startPrank(address(spoke2));
    tokenList.dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke2));
    vm.stopPrank();

    // Spoke 1's debt individually has not yet accrued, even though total debt has accrued
    assertEq(hub.getSpoke(daiAssetId, address(spoke1)).baseDebt, borrowAmount);

    Asset memory daiInfo = hub.getAsset(daiAssetId);
    uint256 baseDebt = daiInfo.baseDebt;
    uint256 outstandingPremium = daiInfo.outstandingPremium;
    uint256 avgRiskPremium = daiInfo.riskPremiumRad;
    uint256 lastUpdateTimestamp = daiInfo.lastUpdateTimestamp;
    uint40 firstAccrual = uint40(lastUpdateTimestamp);

    uint256 totalBase = MathUtils.calculateLinearInterest(baseBorrowRate, uint40(startTime)).rayMul(
      borrowAmount
    );

    assertEq(elapsed, lastUpdateTimestamp - startTime);
    assertEq(baseDebt, totalBase);
    assertEq(avgRiskPremium, riskPremium);
    assertEq(outstandingPremium, (totalBase - borrowAmount).radMul(riskPremium));

    // Say borrow rate changes
    baseBorrowRate *= 2;
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(baseBorrowRate)
    );

    // Time passes
    skip(elapsed);

    // Spoke 2 does a supply to accrue interest
    deal(address(tokenList.dai), address(spoke2), 1000e18);
    vm.startPrank(address(spoke2));
    tokenList.dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke2));
    vm.stopPrank();

    // Spoke 1's debt individually has not yet accrued, even though total debt has accrued
    assertEq(hub.getSpoke(daiAssetId, address(spoke1)).baseDebt, borrowAmount);

    daiInfo = hub.getAsset(daiAssetId);
    baseDebt = daiInfo.baseDebt;
    outstandingPremium = daiInfo.outstandingPremium;
    avgRiskPremium = daiInfo.riskPremiumRad;
    lastUpdateTimestamp = daiInfo.lastUpdateTimestamp;

    uint256 cumulated = MathUtils.calculateLinearInterest(
      baseBorrowRate,
      uint40(startTime + elapsed)
    );
    totalBase = cumulated.rayMul(totalBase);

    assertEq(elapsed * 2, lastUpdateTimestamp - startTime);
    //assertEq(baseDebt, totalBase);
    //assertEq(avgRiskPremium, riskPremium);
    //assertEq(outstandingPremium, (totalBase - borrowAmount).radMul(riskPremium));
  }
}
