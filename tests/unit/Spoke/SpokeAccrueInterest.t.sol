// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
import {Spoke} from 'src/contracts/Spoke.sol';
import {LiquidityHub} from 'src/contracts/LiquidityHub.sol';

contract SpokeAccrueInterestTest is SpokeBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  function test_accrueInterest_NoActionTaken() public {
    DataTypes.Reserve memory wethInfo = getReserveInfo(spoke1, spokeInfo[spoke1].weth.reserveId);
    assertEq(wethInfo.lastUpdateTimestamp, 0);
    assertEq(wethInfo.baseDebt, 0);
    assertEq(wethInfo.outstandingPremium, 0);
    assertEq(wethInfo.riskPremium, 0);
  }

  function test_accrueInterest_OnlySupply(uint40 elapsed) public {
    uint256 amount = 1000e18;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

    // Bob supplies through spoke 1
    Utils.spokeSupply(spoke1, wethReserveId, bob, amount, bob);

    uint256 lastUpdate = vm.getBlockTimestamp();

    // Time passes
    skip(elapsed);

    DataTypes.Reserve memory wethInfo = getReserveInfo(spoke1, wethReserveId);

    // Timestamp doesn't update when no interest accrued
    assertEq(wethInfo.lastUpdateTimestamp, lastUpdate, 'lastUpdateTimestamp');
    assertEq(wethInfo.baseDebt, 0, 'baseDebt');
    assertEq(wethInfo.outstandingPremium, 0, 'outstandingPremium');
  }

  function test_accrueInterest_BorrowAndWait() public {
    uint256 amount = 1000e18;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;
    uint256 startTime = vm.getBlockTimestamp();

    // Bob supplies and borrows through spoke 1
    Utils.spokeSupply(spoke1, wethReserveId, bob, amount * 2, bob);
    Utils.spokeBorrow(spoke1, wethReserveId, bob, amount, bob);

    uint256 baseBorrowRate = hub.getBaseInterestRate(wethAssetId);
    uint256 lastUpdate = vm.getBlockTimestamp();

    // 1 year passes
    skip(365 days);

    DataTypes.Reserve memory wethReserveInfo = getReserveInfo(spoke1, wethReserveId);
    DataTypes.Asset memory wethAssetInfo = getAssetInfo(wethAssetId);

    uint256 totalBase = MathUtils.calculateLinearInterest(baseBorrowRate, uint40(startTime)).rayMul(
      amount
    );

    // Spoke checks
    assertEq(wethReserveInfo.lastUpdateTimestamp, lastUpdate, 'lastUpdateTimestamp');
    assertEq(wethReserveInfo.baseDebt, totalBase, 'baseDebt');
    assertEq(wethReserveInfo.outstandingPremium, 0, 'outstandingPremium');

    // LH checks
    assertEq(wethAssetInfo.baseDebt, totalBase, 'asset base debt');
    assertEq(wethAssetInfo.riskPremium, 0);
    assertEq(wethAssetInfo.outstandingPremium, 0);
    assertEq(wethAssetInfo.lastUpdateTimestamp, lastUpdate);
  }

  function test_accrueInterest_fuzz_BorrowAmountAndElapsed(
    uint256 borrowAmount,
    uint40 elapsed
  ) public {
    borrowAmount = bound(borrowAmount, 1, 1e30);
    uint256 supplyAmount = borrowAmount * 2;
    uint256 startTime = vm.getBlockTimestamp();
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;
    deal(address(tokenList.weth), bob, supplyAmount + 1e18);

    // Bob supplies and borrows through spoke 1
    Utils.spokeSupply(spoke1, wethReserveId, bob, supplyAmount, bob);
    Utils.spokeBorrow(spoke1, wethReserveId, bob, borrowAmount, bob);

    uint256 baseBorrowRate = hub.getBaseInterestRate(wethAssetId);
    uint256 lastUpdate = vm.getBlockTimestamp();

    // Time passes
    skip(elapsed);

    DataTypes.Reserve memory wethReserveInfo = getReserveInfo(spoke1, wethReserveId);
    DataTypes.Asset memory wethAssetInfo = getAssetInfo(wethAssetId);

    uint256 totalBase = MathUtils.calculateLinearInterest(baseBorrowRate, uint40(startTime)).rayMul(
      borrowAmount
    );

    // Spoke checks
    assertEq(wethReserveInfo.lastUpdateTimestamp, lastUpdate, 'lastUpdateTimestamp');
    assertEq(wethReserveInfo.baseDebt, totalBase, 'baseDebt');
    assertEq(wethReserveInfo.outstandingPremium, 0, 'outstandingPremium');

    // LH checks
    assertEq(wethAssetInfo.baseDebt, totalBase);
    assertEq(wethAssetInfo.riskPremium, 0);
    assertEq(wethAssetInfo.outstandingPremium, 0);
    assertEq(wethAssetInfo.lastUpdateTimestamp, lastUpdate);
  }

  // TODO: test_accrueInterest_TenPercentRP
  // TODO: test_accrueInterest_fuzz_RPBorrowAndElapsed
  // TODO: test_accrueInterest_fuzz_ChangingBorrowRate
}
