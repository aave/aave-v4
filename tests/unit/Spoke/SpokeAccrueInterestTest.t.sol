// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/BaseTest.t.sol';
import {Spoke} from 'src/contracts/Spoke.sol';
import {LiquidityHub} from 'src/contracts/LiquidityHub.sol';

contract SpokeAccrueInterestTest is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  uint256 public constant MAX_BPS = 999_99;

  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

  function test_accrueInterest_NoActionTaken() public {
    Spoke.Reserve memory daiInfo = spoke1.getReserve(spokeInfo[spoke1].dai.reserveId);
    assertEq(daiInfo.lastUpdateTimestamp, 0);
    assertEq(daiInfo.baseDebt, 0);
    assertEq(daiInfo.outstandingPremium, 0);
    assertEq(daiInfo.riskPremiumRad, 0);
  }

  function test_accrueInterest_OnlySupply(uint40 elapsed) public {
    uint256 amount = 1000e18;

    // Bob supplies through spoke 1
    Utils.spokeSupply(spoke1, spokeInfo[spoke1].dai.reserveId, bob, amount, bob);

    // Time passes
    skip(elapsed);

    // Alice does a supply through same spoke to accrue interest
    Utils.spokeSupply(spoke1, spokeInfo[spoke1].dai.reserveId, alice, amount, alice);

    Spoke.Reserve memory daiInfo = spoke1.getReserve(spokeInfo[spoke1].dai.reserveId);

    // Timestamp doesn't update when no interest accrued
    assertEq(daiInfo.lastUpdateTimestamp, vm.getBlockTimestamp(), 'lastUpdateTimestamp');
    assertEq(daiInfo.baseDebt, 0, 'baseDebt');
    assertEq(daiInfo.riskPremiumRad, 0, 'riskPremiumRad');
    assertEq(daiInfo.outstandingPremium, 0, 'outstandingPremium');
  }

  function test_accrueInterest_BorrowAndWait() public {
    uint256 amount = 1000e18;
    uint256 startTime = vm.getBlockTimestamp();

    // Bob supplies and borrows through spoke 1
    Utils.spokeSupply(spoke1, spokeInfo[spoke1].dai.reserveId, bob, amount * 2, bob);
    Utils.spokeBorrow(spoke1, spokeInfo[spoke1].dai.reserveId, bob, amount, bob);

    uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);

    // 1 year passes
    skip(365 days);

    // Bob does a supply through same spoke to accrue interest
    Utils.spokeSupply(spoke1, spokeInfo[spoke1].dai.reserveId, bob, 1e18, bob);

    Spoke.Reserve memory daiInfo = spoke1.getReserve(spokeInfo[spoke1].dai.reserveId);
    Asset memory daiAssetInfo = hub.getAsset(daiAssetId);

    uint256 totalBase = MathUtils.calculateLinearInterest(baseBorrowRate, uint40(startTime)).rayMul(
      amount
    );

    // Spoke checks
    assertEq(daiInfo.lastUpdateTimestamp, vm.getBlockTimestamp(), 'lastUpdateTimestamp');
    assertEq(daiInfo.baseDebt, totalBase, 'baseDebt');
    assertEq(daiInfo.riskPremiumRad, 0, 'riskPremiumRad');
    assertEq(daiInfo.outstandingPremium, 0, 'outstandingPremium');

    // LH checks
    assertEq(daiAssetInfo.baseDebt, totalBase);
    assertEq(daiAssetInfo.riskPremiumRad, 0);
    assertEq(daiAssetInfo.outstandingPremium, 0);
    assertEq(daiAssetInfo.lastUpdateTimestamp, vm.getBlockTimestamp());
  }

  function test_accrueInterest_fuzz_BorrowAndWait(uint40 elapsed) public {
    uint256 amount = 1000e18;
    uint256 startTime = vm.getBlockTimestamp();

    // Bob supplies and borrows through spoke 1
    Utils.spokeSupply(spoke1, spokeInfo[spoke1].dai.reserveId, bob, amount * 2, bob);
    Utils.spokeBorrow(spoke1, spokeInfo[spoke1].dai.reserveId, bob, amount, bob);

    uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);

    // Time passes
    skip(elapsed);

    // Bob does a supply through same spoke to accrue interest
    Utils.spokeSupply(spoke1, spokeInfo[spoke1].dai.reserveId, bob, 1e18, bob);

    Spoke.Reserve memory daiInfo = spoke1.getReserve(spokeInfo[spoke1].dai.reserveId);
    Asset memory daiAssetInfo = hub.getAsset(daiAssetId);

    uint256 totalBase = MathUtils.calculateLinearInterest(baseBorrowRate, uint40(startTime)).rayMul(
      amount
    );

    // Spoke checks
    assertEq(daiInfo.lastUpdateTimestamp, vm.getBlockTimestamp(), 'lastUpdateTimestamp');
    assertEq(daiInfo.baseDebt, totalBase, 'baseDebt');
    assertEq(daiInfo.riskPremiumRad, 0, 'riskPremiumRad');
    assertEq(daiInfo.outstandingPremium, 0, 'outstandingPremium');

    // LH checks
    assertEq(daiAssetInfo.baseDebt, totalBase);
    assertEq(daiAssetInfo.riskPremiumRad, 0);
    assertEq(daiAssetInfo.outstandingPremium, 0);
    assertEq(daiAssetInfo.lastUpdateTimestamp, vm.getBlockTimestamp());
  }

  function test_accrueInterest_fuzz_BorrowAmountAndElapsed(
    uint256 borrowAmount,
    uint40 elapsed
  ) public {
    borrowAmount = bound(borrowAmount, 1, 1e30);
    uint256 supplyAmount = borrowAmount * 2;
    uint256 startTime = vm.getBlockTimestamp();
    deal(address(tokenList.dai), bob, supplyAmount + 1e18);

    // Bob supplies and borrows through spoke 1
    Utils.spokeSupply(spoke1, spokeInfo[spoke1].dai.reserveId, bob, supplyAmount, bob);
    Utils.spokeBorrow(spoke1, spokeInfo[spoke1].dai.reserveId, bob, borrowAmount, bob);

    uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);

    // Time passes
    skip(elapsed);

    // Bob does a supply through same spoke to accrue interest
    Utils.spokeSupply(spoke1, spokeInfo[spoke1].dai.reserveId, bob, 1e18, bob);

    Spoke.Reserve memory daiInfo = spoke1.getReserve(spokeInfo[spoke1].dai.reserveId);
    Asset memory daiAssetInfo = hub.getAsset(daiAssetId);

    uint256 totalBase = MathUtils.calculateLinearInterest(baseBorrowRate, uint40(startTime)).rayMul(
      borrowAmount
    );

    // Spoke checks
    assertEq(daiInfo.lastUpdateTimestamp, vm.getBlockTimestamp(), 'lastUpdateTimestamp');
    assertEq(daiInfo.baseDebt, totalBase, 'baseDebt');
    assertEq(daiInfo.riskPremiumRad, 0, 'riskPremiumRad');
    assertEq(daiInfo.outstandingPremium, 0, 'outstandingPremium');

    // LH checks
    assertEq(daiAssetInfo.baseDebt, totalBase);
    assertEq(daiAssetInfo.riskPremiumRad, 0);
    assertEq(daiAssetInfo.outstandingPremium, 0);
    assertEq(daiAssetInfo.lastUpdateTimestamp, vm.getBlockTimestamp());
  }

  // TODO: test_accrueInterest_TenPercentRP
  // TODO: test_accrueInterest_fuzz_RPBorrowAndElapsed
  // TODO: test_accrueInterest_fuzz_ChangingBorrowRate
}
