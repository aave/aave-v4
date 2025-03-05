// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
import {Spoke} from 'src/contracts/Spoke.sol';
import {LiquidityHub} from 'src/contracts/LiquidityHub.sol';

contract SpokeAccrueInterestTest is SpokeBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  uint256 public constant MAX_BPS = 999_99;

  struct TestAmounts {
    uint256 daiSupplyAmount;
    uint256 wethSupplyAmount;
    uint256 usdxSupplyAmount;
    uint256 wbtcSupplyAmount;
    uint256 daiBorrowAmount;
    uint256 wethBorrowAmount;
    uint256 usdxBorrowAmount;
    uint256 wbtcBorrowAmount;
  }

  struct Rates {
    uint256 daiBaseBorrowRate;
    uint256 wethBaseBorrowRate;
    uint256 usdxBaseBorrowRate;
    uint256 wbtcBaseBorrowRate;
  }

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
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    uint256 supplyAmount = borrowAmount * 2;
    uint256 startTime = vm.getBlockTimestamp();
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;

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

  function test_accrueInterest_TenPercentRp(uint256 borrowAmount, uint40 elapsed) public {
    borrowAmount = bound(borrowAmount, 1e6, MAX_SUPPLY_AMOUNT / 2);
    uint256 supplyAmount = borrowAmount * 2;
    uint256 startTime = vm.getBlockTimestamp();

    // Bob supply usdx on spoke 3 (10% RP)
    uint256 usdxReserveId = spokeInfo[spoke3].usdx.reserveId;
    Utils.spokeSupply(spoke3, usdxReserveId, bob, supplyAmount, bob);
    setUsingAsCollateral(spoke3, bob, usdxReserveId, true);

    // Bob borrows usdx from spoke 3
    Utils.spokeBorrow(spoke3, usdxReserveId, bob, borrowAmount, bob);

    // Risk premium should be 10%
    uint256 riskPremium = spoke3.getUserRiskPremium(bob);
    assertEq(riskPremium, 10_00, 'user risk premium');
    uint256 baseBorrowRate = hub.getBaseInterestRate(usdxAssetId);

    skip(elapsed);

    uint256 expectedTotalBase = MathUtils
      .calculateLinearInterest(baseBorrowRate, uint40(startTime))
      .rayMul(borrowAmount);
    uint256 expectedPremium = (expectedTotalBase - borrowAmount).percentMul(riskPremium);

    DataTypes.UserPosition memory userPosition = getUserInfo(spoke3, bob, usdxReserveId);

    assertEq(userPosition.baseDebt, expectedTotalBase, 'user base debt');
    assertEq(userPosition.outstandingPremium, expectedPremium, 'user outstanding premium');
    assertEq(userPosition.riskPremium, riskPremium, 'user risk premium');

    DataTypes.Reserve memory reserveInfo = getReserveInfo(spoke3, usdxReserveId);

    assertEq(reserveInfo.baseDebt, expectedTotalBase, 'reserve base debt');
    assertEq(reserveInfo.outstandingPremium, expectedPremium, 'reserve outstanding premium');
    assertEq(reserveInfo.riskPremium, riskPremium, 'reserve risk premium');

    DataTypes.SpokeData memory spokeInfo = getSpokeInfo(usdxAssetId, address(spoke3));

    assertEq(spokeInfo.baseDebt, expectedTotalBase, 'spoke base debt');
    assertEq(spokeInfo.outstandingPremium, expectedPremium, 'spoke outstanding premium');
    assertEq(spokeInfo.riskPremium, riskPremium, 'spoke risk premium');

    DataTypes.Asset memory assetInfo = getAssetInfo(usdxAssetId);

    assertEq(assetInfo.baseDebt, expectedTotalBase, 'asset base debt');
    assertEq(assetInfo.outstandingPremium, expectedPremium, 'asset outstanding premium');
    assertEq(assetInfo.riskPremium, riskPremium, 'asset risk premium');
  }

  // TODO: test_accrueInterest_fuzz_RPBorrowAndElapsed
  // Fuzz a mix of borrowed and supplied assets for bob, check his RP, ensure correct interest accrual
  function test_accrueInterest_fuzz_RPBorrowAndElapsed(
    TestAmounts memory amounts,
    uint40 elapsed
  ) public {
    amounts.daiSupplyAmount = bound(amounts.daiSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    amounts.wethSupplyAmount = bound(amounts.wethSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    amounts.usdxSupplyAmount = bound(amounts.usdxSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    amounts.wbtcSupplyAmount = bound(amounts.wbtcSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    amounts.daiBorrowAmount = bound(amounts.daiBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);
    amounts.wethBorrowAmount = bound(amounts.wethBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);
    amounts.usdxBorrowAmount = bound(amounts.usdxBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);
    amounts.wbtcBorrowAmount = bound(amounts.wbtcBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);

    // Ensure bob does not draw more than half his normalized supply value
    vm.assume(
      _normalizedValue(amounts.daiSupplyAmount, daiAssetId) +
        _normalizedValue(amounts.wethSupplyAmount, wethAssetId) +
        _normalizedValue(amounts.usdxSupplyAmount, usdxAssetId) +
        _normalizedValue(amounts.wbtcSupplyAmount, wbtcAssetId) >=
        2 *
          (_normalizedValue(amounts.daiBorrowAmount, daiAssetId) +
            _normalizedValue(amounts.wethBorrowAmount, wethAssetId) +
            _normalizedValue(amounts.usdxBorrowAmount, usdxAssetId) +
            _normalizedValue(amounts.wbtcBorrowAmount, wbtcAssetId))
    );

    uint256 startTime = vm.getBlockTimestamp();

    // Bob supply dai on spoke 1
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    if (amounts.daiSupplyAmount > 0) {
      Utils.spokeSupply(spoke1, daiReserveId, bob, amounts.daiSupplyAmount, bob);
      setUsingAsCollateral(spoke1, bob, daiReserveId, true);
    }

    // Bob supply weth on spoke 1
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;
    if (amounts.wethSupplyAmount > 0) {
      deal(address(tokenList.weth), bob, amounts.wethSupplyAmount);
      Utils.spokeSupply(spoke1, wethReserveId, bob, amounts.wethSupplyAmount, bob);
      setUsingAsCollateral(spoke1, bob, wethReserveId, true);
    }

    // Bob supply usdx on spoke 1
    uint256 usdxReserveId = spokeInfo[spoke1].usdx.reserveId;
    if (amounts.usdxSupplyAmount > 0) {
      deal(address(tokenList.usdx), bob, amounts.usdxSupplyAmount);
      Utils.spokeSupply(spoke1, usdxReserveId, bob, amounts.usdxSupplyAmount, bob);
      setUsingAsCollateral(spoke1, bob, usdxReserveId, true);
    }

    // Bob supply wbtc on spoke 1
    uint256 wbtcReserveId = spokeInfo[spoke1].wbtc.reserveId;
    if (amounts.wbtcSupplyAmount > 0) {
      deal(address(tokenList.wbtc), bob, amounts.wbtcSupplyAmount);
      Utils.spokeSupply(spoke1, wbtcReserveId, bob, amounts.wbtcSupplyAmount, bob);
      setUsingAsCollateral(spoke1, bob, wbtcReserveId, true);
    }

    // Alice supplies the remainder of the assets
    if (amounts.daiSupplyAmount < MAX_SUPPLY_AMOUNT) {
      Utils.spokeSupply(
        spoke1,
        daiReserveId,
        alice,
        MAX_SUPPLY_AMOUNT - amounts.daiSupplyAmount,
        alice
      );
    }
    if (amounts.wethSupplyAmount < MAX_SUPPLY_AMOUNT) {
      Utils.spokeSupply(
        spoke1,
        wethReserveId,
        alice,
        MAX_SUPPLY_AMOUNT - amounts.wethSupplyAmount,
        alice
      );
    }
    if (amounts.usdxSupplyAmount < MAX_SUPPLY_AMOUNT) {
      Utils.spokeSupply(
        spoke1,
        usdxReserveId,
        alice,
        MAX_SUPPLY_AMOUNT - amounts.usdxSupplyAmount,
        alice
      );
    }
    if (amounts.wbtcSupplyAmount < MAX_SUPPLY_AMOUNT) {
      Utils.spokeSupply(
        spoke1,
        wbtcReserveId,
        alice,
        MAX_SUPPLY_AMOUNT - amounts.wbtcSupplyAmount,
        alice
      );
    }

    // Bob borrows dai from spoke 1
    if (amounts.daiBorrowAmount > 0) {
      Utils.spokeBorrow(spoke1, daiReserveId, bob, amounts.daiBorrowAmount, bob);
    }

    // Bob borrows weth from spoke 1
    if (amounts.wethBorrowAmount > 0) {
      Utils.spokeBorrow(spoke1, wethReserveId, bob, amounts.wethBorrowAmount, bob);
    }

    // Bob borrows usdx from spoke 1
    if (amounts.usdxBorrowAmount > 0) {
      Utils.spokeBorrow(spoke1, usdxReserveId, bob, amounts.usdxBorrowAmount, bob);
    }

    // Bob borrows wbtc from spoke 1
    if (amounts.wbtcBorrowAmount > 0) {
      Utils.spokeBorrow(spoke1, wbtcReserveId, bob, amounts.wbtcBorrowAmount, bob);
    }

    // Check Bob's risk premium
    uint256 bobRp = spoke1.getUserRiskPremium(bob);
    assertEq(bobRp, _calculateExpectedUserRP(bob, spoke1), 'user risk premium');

    // Check Bob's base debt and outstanding premium for all assets at user, reserve, spoke, and asset level
    _checkDebtAndRP(bob, spoke1, daiReserveId, daiAssetId, amounts.daiBorrowAmount, 0, bobRp);
    _checkDebtAndRP(bob, spoke1, wethReserveId, wethAssetId, amounts.wethBorrowAmount, 0, bobRp);
    _checkDebtAndRP(bob, spoke1, usdxReserveId, usdxAssetId, amounts.usdxBorrowAmount, 0, bobRp);
    _checkDebtAndRP(bob, spoke1, wbtcReserveId, wbtcAssetId, amounts.wbtcBorrowAmount, 0, bobRp);

    // Store base borrow rates
    Rates memory rates;
    rates.daiBaseBorrowRate = hub.getBaseInterestRate(daiAssetId);
    rates.wethBaseBorrowRate = hub.getBaseInterestRate(wethAssetId);
    rates.usdxBaseBorrowRate = hub.getBaseInterestRate(usdxAssetId);
    rates.wbtcBaseBorrowRate = hub.getBaseInterestRate(wbtcAssetId);

    // Skip time to accrue interest
    skip(elapsed);

    // Check that the interest accrual is correct for all assets at user, reserve, spoke, and asset level
    uint256 expectedBaseDebt = MathUtils
      .calculateLinearInterest(rates.daiBaseBorrowRate, uint40(startTime))
      .rayMul(amounts.daiBorrowAmount);
    uint256 expectedPremium = (expectedBaseDebt - amounts.daiBorrowAmount).percentMul(bobRp);
    _checkDebtAndRP(
      bob,
      spoke1,
      daiReserveId,
      daiAssetId,
      expectedBaseDebt,
      expectedPremium,
      bobRp
    );

    /*
    expectedBaseDebt = MathUtils
      .calculateLinearInterest(rates.wethBaseBorrowRate, uint40(startTime))
      .rayMul(amounts.wethBorrowAmount);
    expectedPremium = (expectedBaseDebt - amounts.wethBorrowAmount).percentMul(bobRp);
    _checkDebtAndRP(
      bob,
      spoke1,
      wethReserveId,
      wethAssetId,
      expectedBaseDebt,
      expectedPremium,
      bobRp
    );
    */
  }

  // TODO: test_accrueInterest_fuzz_ChangingBorrowRate

  function _checkDebtAndRP(
    address user,
    ISpoke spoke,
    uint256 reserveId,
    uint256 assetId,
    uint256 expectedBaseDebt,
    uint256 expectedPremium,
    uint256 expectedRiskPremium
  ) internal {
    DataTypes.UserPosition memory userPosition = getUserInfo(spoke, user, reserveId);

    assertEq(userPosition.baseDebt, expectedBaseDebt, 'user base debt');
    assertEq(userPosition.outstandingPremium, expectedPremium, 'user outstanding premium');
    assertEq(userPosition.riskPremium, expectedRiskPremium, 'user risk premium');

    DataTypes.Reserve memory reserveInfo = getReserveInfo(spoke, reserveId);

    assertEq(reserveInfo.baseDebt, expectedBaseDebt, 'reserve base debt');
    assertEq(reserveInfo.outstandingPremium, expectedPremium, 'reserve outstanding premium');
    if (expectedBaseDebt > 0) {
      assertEq(reserveInfo.riskPremium, expectedRiskPremium, 'reserve risk premium');
    } else {
      assertEq(reserveInfo.riskPremium, 0, 'reserve risk premium');
    }

    DataTypes.SpokeData memory spokeInfo = getSpokeInfo(assetId, address(spoke));

    assertEq(spokeInfo.baseDebt, expectedBaseDebt, 'spoke base debt');
    assertEq(spokeInfo.outstandingPremium, expectedPremium, 'spoke outstanding premium');
    if (expectedBaseDebt > 0) {
      assertEq(spokeInfo.riskPremium, expectedRiskPremium, 'spoke risk premium');
    } else {
      assertEq(spokeInfo.riskPremium, 0, 'spoke risk premium');
    }

    DataTypes.Asset memory assetInfo = getAssetInfo(assetId);

    assertEq(assetInfo.baseDebt, expectedBaseDebt, 'asset base debt');
    assertEq(assetInfo.outstandingPremium, expectedPremium, 'asset outstanding premium');
    if (expectedBaseDebt > 0) {
      assertEq(assetInfo.riskPremium, expectedRiskPremium, 'asset risk premium');
    } else {
      assertEq(assetInfo.riskPremium, 0, 'asset risk premium');
    }
  }
}
