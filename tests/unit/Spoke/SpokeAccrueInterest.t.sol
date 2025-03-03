// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';
import {Spoke} from 'src/contracts/Spoke.sol';
import {LiquidityHub} from 'src/contracts/LiquidityHub.sol';

contract SpokeAccrueInterestTest is Base {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  uint256 public constant MAX_BPS = 999_99;

  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

  function test_accrueInterest_NoActionTaken() public {
    DataTypes.Reserve memory daiInfo = getReserveInfo(spoke1, spokeInfo[spoke1].dai.reserveId);
    assertEq(daiInfo.lastUpdateTimestamp, 0);
    assertEq(daiInfo.baseDebt, 0);
    assertEq(daiInfo.outstandingPremium, 0);
    assertEq(daiInfo.riskPremium, 0);
  }

  function test_accrueInterest_OnlySupply(uint40 elapsed) public {
    uint256 amount = 1000e18;
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;

    // Bob supplies through spoke 1
    Utils.spokeSupply(spoke1, daiReserveId, bob, amount, bob);

    uint256 lastUpdate = vm.getBlockTimestamp();

    // Time passes
    skip(elapsed);

    DataTypes.Reserve memory daiInfo = getReserveInfo(spoke1, daiReserveId);

    // Timestamp doesn't update when no interest accrued
    assertEq(daiInfo.lastUpdateTimestamp, lastUpdate, 'lastUpdateTimestamp');
    assertEq(daiInfo.baseDebt, 0, 'baseDebt');
    assertEq(daiInfo.outstandingPremium, 0, 'outstandingPremium');
  }

  function test_accrueInterest_BorrowAndWait() public {
    uint256 amount = 1000e18;
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 startTime = vm.getBlockTimestamp();

    // Bob supplies and borrows through spoke 1
    Utils.spokeSupply(spoke1, daiReserveId, bob, amount * 2, bob);
    Utils.spokeBorrow(spoke1, daiReserveId, bob, amount, bob);

    uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);
    uint256 lastUpdate = vm.getBlockTimestamp();

    // 1 year passes
    skip(365 days);

    DataTypes.Reserve memory daiReserveInfo = getReserveInfo(spoke1, daiReserveId);
    DataTypes.Asset memory daiAssetInfo = getAssetInfo(daiAssetId);

    uint256 totalBase = MathUtils.calculateLinearInterest(baseBorrowRate, uint40(startTime)).rayMul(
      amount
    );

    // Spoke checks
    assertEq(daiReserveInfo.lastUpdateTimestamp, lastUpdate, 'lastUpdateTimestamp');
    assertEq(daiReserveInfo.baseDebt, totalBase, 'baseDebt');
    assertEq(daiReserveInfo.outstandingPremium, 0, 'outstandingPremium');

    // LH checks
    assertEq(daiAssetInfo.baseDebt, totalBase, 'asset base debt');
    assertEq(daiAssetInfo.riskPremium, 0);
    assertEq(daiAssetInfo.outstandingPremium, 0);
    assertEq(daiAssetInfo.lastUpdateTimestamp, lastUpdate);
  }

  function test_accrueInterest_fuzz_BorrowAndWait(uint40 elapsed) public {
    uint256 amount = 1000e18;
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 startTime = vm.getBlockTimestamp();

    // Bob supplies and borrows through spoke 1
    Utils.spokeSupply(spoke1, daiReserveId, bob, amount * 2, bob);
    Utils.spokeBorrow(spoke1, daiReserveId, bob, amount, bob);

    uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);
    uint256 lastUpdate = vm.getBlockTimestamp();

    // Time passes
    skip(elapsed);

    DataTypes.Reserve memory daiReserveInfo = getReserveInfo(spoke1, daiReserveId);
    DataTypes.Asset memory daiAssetInfo = getAssetInfo(daiAssetId);

    uint256 totalBase = MathUtils.calculateLinearInterest(baseBorrowRate, uint40(startTime)).rayMul(
      amount
    );

    // Spoke checks
    assertEq(daiReserveInfo.lastUpdateTimestamp, lastUpdate, 'lastUpdateTimestamp');
    assertEq(daiReserveInfo.baseDebt, totalBase, 'baseDebt');
    assertEq(daiReserveInfo.outstandingPremium, 0, 'outstandingPremium');

    // LH checks
    assertEq(daiAssetInfo.baseDebt, totalBase);
    assertEq(daiAssetInfo.riskPremium, 0);
    assertEq(daiAssetInfo.outstandingPremium, 0);
    assertEq(daiAssetInfo.lastUpdateTimestamp, lastUpdate);
  }

  function test_accrueInterest_fuzz_BorrowAmountAndElapsed(
    uint256 borrowAmount,
    uint40 elapsed
  ) public {
    borrowAmount = bound(borrowAmount, 1, 1e30);
    uint256 supplyAmount = borrowAmount * 2;
    uint256 startTime = vm.getBlockTimestamp();
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    deal(address(tokenList.dai), bob, supplyAmount + 1e18);

    // Bob supplies and borrows through spoke 1
    Utils.spokeSupply(spoke1, daiReserveId, bob, supplyAmount, bob);
    Utils.spokeBorrow(spoke1, daiReserveId, bob, borrowAmount, bob);

    uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);
    uint256 lastUpdate = vm.getBlockTimestamp();

    // Time passes
    skip(elapsed);

    DataTypes.Reserve memory daiReserveInfo = getReserveInfo(spoke1, daiReserveId);
    DataTypes.Asset memory daiAssetInfo = getAssetInfo(daiAssetId);

    uint256 totalBase = MathUtils.calculateLinearInterest(baseBorrowRate, uint40(startTime)).rayMul(
      borrowAmount
    );

    // Spoke checks
    assertEq(daiReserveInfo.lastUpdateTimestamp, lastUpdate, 'lastUpdateTimestamp');
    assertEq(daiReserveInfo.baseDebt, totalBase, 'baseDebt');
    assertEq(daiReserveInfo.outstandingPremium, 0, 'outstandingPremium');

    // LH checks
    assertEq(daiAssetInfo.baseDebt, totalBase);
    assertEq(daiAssetInfo.riskPremium, 0);
    assertEq(daiAssetInfo.outstandingPremium, 0);
    assertEq(daiAssetInfo.lastUpdateTimestamp, lastUpdate);
  }

  // TODO: test_accrueInterest_TenPercentRP
  // TODO: test_accrueInterest_fuzz_RPBorrowAndElapsed
  // TODO: test_accrueInterest_fuzz_ChangingBorrowRate
}
