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
    DataTypes.Reserve memory daiInfo = spoke1.getReserve(spokeInfo[spoke1].dai.reserveId);
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

    // Time passes
    skip(elapsed);

    // Alice does a supply through same spoke to accrue interest
    Utils.spokeSupply(spoke1, daiReserveId, alice, amount, alice);

    DataTypes.Reserve memory daiInfo = spoke1.getReserve(daiReserveId);

    // Timestamp doesn't update when no interest accrued
    assertEq(
      spoke1.getReserveLastUpdate(daiReserveId),
      vm.getBlockTimestamp(),
      'lastUpdateTimestamp'
    );
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

    // 1 year passes
    skip(365 days);

    // Bob does a supply through same spoke to accrue interest
    Utils.spokeSupply(spoke1, daiReserveId, bob, 1e18, bob);

    (uint256 reserveBaseDebt, uint256 reserveOutstandingPremium) = spoke1.getReserveDebt(
      daiReserveId
    );
    uint256 reserveLastUpdate = spoke1.getReserveLastUpdate(daiReserveId);

    (uint256 assetBaseDebt, uint256 assetOutstandingPremium) = hub.getAssetDebt(daiAssetId);
    uint256 assetLastUpdate = hub.getAssetLastUpdate(daiAssetId);
    uint256 assetRiskPremium = hub.getAssetRiskPremium(daiAssetId);

    uint256 totalBase = MathUtils.calculateLinearInterest(baseBorrowRate, uint40(startTime)).rayMul(
      amount
    );

    // Spoke checks
    assertEq(reserveLastUpdate, vm.getBlockTimestamp(), 'lastUpdateTimestamp');
    assertEq(reserveBaseDebt, totalBase, 'baseDebt');
    assertEq(reserveOutstandingPremium, 0, 'outstandingPremium');

    // LH checks
    assertEq(assetBaseDebt, totalBase);
    assertEq(assetRiskPremium, 0);
    assertEq(assetOutstandingPremium, 0);
    assertEq(assetLastUpdate, vm.getBlockTimestamp());
  }

  function test_accrueInterest_fuzz_BorrowAndWait(uint40 elapsed) public {
    uint256 amount = 1000e18;
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 startTime = vm.getBlockTimestamp();

    // Bob supplies and borrows through spoke 1
    Utils.spokeSupply(spoke1, daiReserveId, bob, amount * 2, bob);
    Utils.spokeBorrow(spoke1, daiReserveId, bob, amount, bob);

    uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);

    // Time passes
    skip(elapsed);

    // Bob does a supply through same spoke to accrue interest
    Utils.spokeSupply(spoke1, daiReserveId, bob, 1e18, bob);

    (uint256 reserveBaseDebt, uint256 reserveOutstandingPremium) = spoke1.getReserveDebt(
      daiReserveId
    );
    uint256 reserveLastUpdate = spoke1.getReserveLastUpdate(daiReserveId);

    (uint256 assetBaseDebt, uint256 assetOutstandingPremium) = hub.getAssetDebt(daiAssetId);
    uint256 assetLastUpdate = hub.getAssetLastUpdate(daiAssetId);
    uint256 assetRiskPremium = hub.getAssetRiskPremium(daiAssetId);

    uint256 totalBase = MathUtils.calculateLinearInterest(baseBorrowRate, uint40(startTime)).rayMul(
      amount
    );

    // Spoke checks
    assertEq(reserveLastUpdate, vm.getBlockTimestamp(), 'lastUpdateTimestamp');
    assertEq(reserveBaseDebt, totalBase, 'baseDebt');
    assertEq(reserveOutstandingPremium, 0, 'outstandingPremium');

    // LH checks
    assertEq(assetBaseDebt, totalBase);
    assertEq(assetRiskPremium, 0);
    assertEq(assetOutstandingPremium, 0);
    assertEq(assetLastUpdate, vm.getBlockTimestamp());
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

    // Time passes
    skip(elapsed);

    // Bob does a supply through same spoke to accrue interest
    Utils.spokeSupply(spoke1, daiReserveId, bob, 1e18, bob);

    (uint256 reserveBaseDebt, uint256 reserveOutstandingPremium) = spoke1.getReserveDebt(
      daiReserveId
    );
    uint256 reserveLastUpdate = spoke1.getReserveLastUpdate(daiReserveId);

    (uint256 assetBaseDebt, uint256 assetOutstandingPremium) = hub.getAssetDebt(daiAssetId);
    uint256 assetLastUpdate = hub.getAssetLastUpdate(daiAssetId);
    uint256 assetRiskPremium = hub.getAssetRiskPremium(daiAssetId);

    uint256 totalBase = MathUtils.calculateLinearInterest(baseBorrowRate, uint40(startTime)).rayMul(
      borrowAmount
    );

    // Spoke checks
    assertEq(reserveLastUpdate, vm.getBlockTimestamp(), 'lastUpdateTimestamp');
    assertEq(reserveBaseDebt, totalBase, 'baseDebt');
    assertEq(reserveOutstandingPremium, 0, 'outstandingPremium');

    // LH checks
    assertEq(assetBaseDebt, totalBase);
    assertEq(assetRiskPremium, 0);
    assertEq(assetOutstandingPremium, 0);
    assertEq(assetLastUpdate, vm.getBlockTimestamp());
  }

  // TODO: test_accrueInterest_TenPercentRP
  // TODO: test_accrueInterest_fuzz_RPBorrowAndElapsed
  // TODO: test_accrueInterest_fuzz_ChangingBorrowRate
}
