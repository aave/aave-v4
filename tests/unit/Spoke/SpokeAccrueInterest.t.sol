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

  function test_accrueInterest_NoActionTaken() public {
    DataTypes.Reserve memory daiInfo = getReserveInfo(spoke1, spokeInfo[spoke1].dai.reserveId);
    assertEq(daiInfo.baseDrawnShares, 0, 'baseDrawnShares');
    assertEq(daiInfo.premiumDrawnShares, 0, 'premiumDrawnShares');
    assertEq(daiInfo.premiumOffset, 0, 'premiumOffset');
    assertEq(daiInfo.realizedPremium, 0, 'realizedPremium');
  }

  /// Supply an asset only, and check no interest accrued.
  function test_accrueInterest_OnlySupply(uint40 skipTime) public {
    skipTime = uint40(bound(skipTime, 0, MAX_SKIP_TIME));
    uint256 amount = 1000e18;
    uint256 daiReserveId = _daiReserveId(spoke1);

    // Bob supplies through spoke 1
    Utils.supply(spoke1, daiReserveId, bob, amount, bob);

    uint256 lastUpdate = vm.getBlockTimestamp();

    DataTypes.Reserve memory daiInfo = getReserveInfo(spoke1, daiReserveId);

    assertEq(daiInfo.baseDrawnShares, 0, 'baseDrawnShares');
    assertEq(daiInfo.premiumDrawnShares, 0, 'premiumDrawnShares');
    assertEq(daiInfo.premiumOffset, 0, 'premiumOffset');
    assertEq(daiInfo.realizedPremium, 0, 'realizedPremium');
  }

  function test_accrueInterest_BorrowAndWait() public {
    uint256 amount = 1000e18;
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 startTime = vm.getBlockTimestamp();

    // Bob supplies and borrows through spoke 1
    Utils.supplyCollateral(spoke1, daiReserveId, bob, amount * 2, bob);
    Utils.borrow(spoke1, daiReserveId, bob, amount, bob);

    uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);
    uint256 lastUpdate = vm.getBlockTimestamp();
    uint256 userRp = spoke1.getUserRiskPremium(bob);

    // 1 year passes
    skip(365 days);

    DataTypes.Reserve memory daiReserveInfo = getReserveInfo(spoke1, daiReserveId);
    DataTypes.Asset memory daiAssetInfo = getAssetInfo(daiAssetId);

    uint256 totalBase = MathUtils.calculateLinearInterest(baseBorrowRate, uint40(startTime)).rayMul(
      amount
    );
    uint256 expectedPremiumDrawnShares = daiReserveInfo.baseDrawnShares.percentMul(userRp);
    uint256 expectedPremiumDebt = hub.convertToDrawnAssets(daiAssetId, expectedPremiumDrawnShares);

    // Spoke checks
    assertEq(
      hub.convertToDrawnAssets(daiAssetId, daiReserveInfo.baseDrawnShares),
      totalBase,
      'base debt after accrual'
    );
    assertEq(
      hub.convertToDrawnAssets(daiAssetId, daiReserveInfo.premiumDrawnShares),
      expectedPremiumDebt,
      'premium debt after accrual'
    );

    // LH checks
    assertEq(
      hub.convertToDrawnAssets(daiAssetId, daiAssetInfo.baseDrawnShares),
      totalBase,
      'asset base debt after accrual'
    );
    assertEq(
      hub.convertToDrawnAssets(daiAssetId, daiAssetInfo.premiumDrawnShares),
      expectedPremiumDebt,
      'asset premium debt after accrual'
    );
  }

  function test_accrueInterest_fuzz_BorrowAndWait(uint40 skipTime) public {
    skipTime = uint40(bound(skipTime, 0, MAX_SKIP_TIME));
    uint256 amount = 1000e18;
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 startTime = vm.getBlockTimestamp();

    // Bob supplies and borrows through spoke 1
    Utils.supplyCollateral(spoke1, daiReserveId, bob, amount * 2, bob);
    Utils.borrow(spoke1, daiReserveId, bob, amount, bob);

    uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);
    uint256 lastUpdate = vm.getBlockTimestamp();
    uint256 userRp = spoke1.getUserRiskPremium(bob);

    // Time passes
    skip(skipTime);

    DataTypes.Reserve memory daiReserveInfo = getReserveInfo(spoke1, daiReserveId);
    DataTypes.Asset memory daiAssetInfo = getAssetInfo(daiAssetId);

    uint256 totalBase = MathUtils.calculateLinearInterest(baseBorrowRate, uint40(startTime)).rayMul(
      amount
    );
    uint256 expectedPremiumDrawnShares = daiReserveInfo.baseDrawnShares.percentMul(userRp);
    uint256 expectedPremiumDebt = hub.convertToDrawnAssets(daiAssetId, expectedPremiumDrawnShares);

    // Spoke checks
    assertApproxEqAbs(
      hub.convertToDrawnAssets(daiAssetId, daiReserveInfo.baseDrawnShares),
      totalBase,
      1,
      'base debt after accrual'
    );
    assertEq(
      hub.convertToDrawnAssets(daiAssetId, daiReserveInfo.premiumDrawnShares),
      expectedPremiumDebt,
      'premium debt after accrual'
    );

    // LH checks
    assertApproxEqAbs(
      hub.convertToDrawnAssets(daiAssetId, daiAssetInfo.baseDrawnShares),
      totalBase,
      1,
      'asset base debt after accrual'
    );
    assertEq(
      hub.convertToDrawnAssets(daiAssetId, daiAssetInfo.premiumDrawnShares),
      expectedPremiumDebt,
      'asset premium debt after accrual'
    );
  }

  function test_accrueInterest_fuzz_BorrowAmountAndskipTime(
    uint256 borrowAmount,
    uint40 skipTime
  ) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    skipTime = uint40(bound(skipTime, 0, MAX_SKIP_TIME));
    uint256 supplyAmount = borrowAmount * 2;
    uint256 startTime = vm.getBlockTimestamp();
    uint256 daiReserveId = _daiReserveId(spoke1);

    // Bob supplies and borrows through spoke 1
    Utils.supplyCollateral(spoke1, daiReserveId, bob, supplyAmount, bob);
    Utils.borrow(spoke1, daiReserveId, bob, borrowAmount, bob);

    uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);
    uint256 lastUpdate = vm.getBlockTimestamp();
    uint256 userRp = spoke1.getUserRiskPremium(bob);

    // Time passes
    skip(skipTime);

    DataTypes.Reserve memory daiReserveInfo = getReserveInfo(spoke1, daiReserveId);
    DataTypes.Asset memory daiAssetInfo = getAssetInfo(daiAssetId);

    uint256 totalBase = MathUtils.calculateLinearInterest(baseBorrowRate, uint40(startTime)).rayMul(
      borrowAmount
    );
    uint256 expectedPremiumDrawnShares = daiReserveInfo.baseDrawnShares.percentMul(userRp);
    uint256 expectedPremiumDebt = hub.convertToDrawnAssets(daiAssetId, expectedPremiumDrawnShares);

    // Spoke checks
    assertApproxEqAbs(
      hub.convertToDrawnAssets(daiAssetId, daiReserveInfo.baseDrawnShares),
      totalBase,
      1,
      'base debt after accrual'
    );
    assertEq(
      hub.convertToDrawnAssets(daiAssetId, daiReserveInfo.premiumDrawnShares),
      expectedPremiumDebt,
      'premium debt after accrual'
    );

    // LH checks
    assertApproxEqAbs(
      hub.convertToDrawnAssets(daiAssetId, daiAssetInfo.baseDrawnShares),
      totalBase,
      1,
      'asset base debt after accrual'
    );
    assertEq(
      hub.convertToDrawnAssets(daiAssetId, daiAssetInfo.premiumDrawnShares),
      expectedPremiumDebt,
      'asset premium debt after accrual'
    );
  }

  function test_accrueInterest_TenPercentRp(uint256 borrowAmount, uint40 skipTime) public {
    borrowAmount = bound(borrowAmount, 1e6, MAX_SUPPLY_AMOUNT / 2);
    skipTime = uint40(bound(skipTime, 0, MAX_SKIP_TIME));
    uint256 supplyAmount = borrowAmount * 2;
    uint256 startTime = vm.getBlockTimestamp();
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    // Set liquidity premium of usdx on spoke1 to 10%
    updateLiquidityPremium(spoke1, usdxReserveId, 10_00);
    assertEq(10_00, spoke1.getLiquidityPremium(usdxReserveId), 'usdx liquidity premium');

    // Bob supply usdx
    Utils.supplyCollateral(spoke1, usdxReserveId, bob, supplyAmount, bob);

    // Bob borrows usdx
    Utils.borrow(spoke1, usdxReserveId, bob, borrowAmount, bob);

    // User risk premium should be 10%
    uint256 riskPremium = spoke1.getUserRiskPremium(bob);
    assertEq(riskPremium, 10_00, 'user risk premium');
    uint256 baseBorrowRate = hub.getBaseInterestRate(usdxAssetId);

    skip(skipTime);

    DataTypes.Reserve memory usdxReserveInfo = getReserveInfo(spoke1, usdxReserveId);

    uint256 expectedBaseDebt = MathUtils
      .calculateLinearInterest(baseBorrowRate, uint40(startTime))
      .rayMul(borrowAmount);
    uint256 expectedPremiumDrawnShares = usdxReserveInfo.baseDrawnShares.percentMul(riskPremium);
    uint256 expectedPremiumDebt = hub.convertToDrawnAssets(usdxAssetId, expectedPremiumDrawnShares);

    _checkDebts(spoke1, usdxReserveId, bob, expectedBaseDebt, expectedPremiumDebt, 'after accrual');
  }

  /*
  // Fuzz a mix of borrowed and supplied assets for bob, check his RP, ensure correct interest accrual
  function test_accrueInterest_fuzz_RPBorrowAndskipTime(
    TestAmounts memory amounts,
    uint40 skipTime
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
      _getValueInBaseCurrency(amounts.daiSupplyAmount, daiAssetId) +
        _getValueInBaseCurrency(amounts.wethSupplyAmount, wethAssetId) +
        _getValueInBaseCurrency(amounts.usdxSupplyAmount, usdxAssetId) +
        _getValueInBaseCurrency(amounts.wbtcSupplyAmount, wbtcAssetId) >=
        2 *
          (_getValueInBaseCurrency(amounts.daiBorrowAmount, daiAssetId) +
            _getValueInBaseCurrency(amounts.wethBorrowAmount, wethAssetId) +
            _getValueInBaseCurrency(amounts.usdxBorrowAmount, usdxAssetId) +
            _getValueInBaseCurrency(amounts.wbtcBorrowAmount, wbtcAssetId))
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
    assertEq(bobRp, _calculateExpectedUserRP(bob, spoke1), 'user risk premium Before');

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
    skip(skipTime);

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

    expectedBaseDebt = MathUtils
      .calculateLinearInterest(rates.usdxBaseBorrowRate, uint40(startTime))
      .rayMul(amounts.usdxBorrowAmount);
    expectedPremium = (expectedBaseDebt - amounts.usdxBorrowAmount).percentMul(bobRp);
    _checkDebtAndRP(
      bob,
      spoke1,
      usdxReserveId,
      usdxAssetId,
      expectedBaseDebt,
      expectedPremium,
      bobRp
    );

    expectedBaseDebt = MathUtils
      .calculateLinearInterest(rates.wbtcBaseBorrowRate, uint40(startTime))
      .rayMul(amounts.wbtcBorrowAmount);
    expectedPremium = (expectedBaseDebt - amounts.wbtcBorrowAmount).percentMul(bobRp);
    _checkDebtAndRP(
      bob,
      spoke1,
      wbtcReserveId,
      wbtcAssetId,
      expectedBaseDebt,
      expectedPremium,
      bobRp
    );
  }

  // TODO: test_accrueInterest_fuzz_ChangingBorrowRate

  // TODO: Second accrual after an action - which should update the user rp
  function test_accrueInterest_fuzz_RPBorrowAndskipTime_twoActions(
    TestAmounts memory amounts,
    uint40 skipTime
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
      _getValueInBaseCurrency(amounts.daiSupplyAmount, daiAssetId) +
        _getValueInBaseCurrency(amounts.wethSupplyAmount, wethAssetId) +
        _getValueInBaseCurrency(amounts.usdxSupplyAmount, usdxAssetId) +
        _getValueInBaseCurrency(amounts.wbtcSupplyAmount, wbtcAssetId) >=
        2 *
          (_getValueInBaseCurrency(amounts.daiBorrowAmount, daiAssetId) +
            _getValueInBaseCurrency(amounts.wethBorrowAmount, wethAssetId) +
            _getValueInBaseCurrency(amounts.usdxBorrowAmount, usdxAssetId) +
            _getValueInBaseCurrency(amounts.wbtcBorrowAmount, wbtcAssetId))
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
      Utils.spokeSupply(spoke1, wethReserveId, bob, amounts.wethSupplyAmount, bob);
      setUsingAsCollateral(spoke1, bob, wethReserveId, true);
    }

    // Bob supply usdx on spoke 1
    uint256 usdxReserveId = spokeInfo[spoke1].usdx.reserveId;
    if (amounts.usdxSupplyAmount > 0) {
      Utils.spokeSupply(spoke1, usdxReserveId, bob, amounts.usdxSupplyAmount, bob);
      setUsingAsCollateral(spoke1, bob, usdxReserveId, true);
    }

    // Bob supply wbtc on spoke 1
    uint256 wbtcReserveId = spokeInfo[spoke1].wbtc.reserveId;
    if (amounts.wbtcSupplyAmount > 0) {
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
    assertEq(bobRp, _calculateExpectedUserRP(bob, spoke1), 'user risk premium Before');

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
    skip(skipTime);

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

    expectedBaseDebt = MathUtils
      .calculateLinearInterest(rates.usdxBaseBorrowRate, uint40(startTime))
      .rayMul(amounts.usdxBorrowAmount);
    expectedPremium = (expectedBaseDebt - amounts.usdxBorrowAmount).percentMul(bobRp);
    _checkDebtAndRP(
      bob,
      spoke1,
      usdxReserveId,
      usdxAssetId,
      expectedBaseDebt,
      expectedPremium,
      bobRp
    );

    expectedBaseDebt = MathUtils
      .calculateLinearInterest(rates.wbtcBaseBorrowRate, uint40(startTime))
      .rayMul(amounts.wbtcBorrowAmount);
    expectedPremium = (expectedBaseDebt - amounts.wbtcBorrowAmount).percentMul(bobRp);
    _checkDebtAndRP(
      bob,
      spoke1,
      wbtcReserveId,
      wbtcAssetId,
      expectedBaseDebt,
      expectedPremium,
      bobRp
    );

    // Bob draws more dai to trigger accrual
    Utils.spokeBorrow(spoke1, daiReserveId, bob, 1, bob);

    // Refresh debt values
    Debts memory debts;
    (debts.bobDaiBaseDebt, debts.bobDaiPremiumDebt) = spoke1.getUserDebt(daiReserveId, bob);
    (debts.bobWethBaseDebt, debts.bobWethPremiumDebt) = spoke1.getUserDebt(wethReserveId, bob);
    (debts.bobUsdxBaseDebt, debts.bobUsdxPremiumDebt) = spoke1.getUserDebt(usdxReserveId, bob);
    (debts.bobWbtcBaseDebt, debts.bobWbtcPremiumDebt) = spoke1.getUserDebt(wbtcReserveId, bob);

    // Refresh base borrow rates
    rates.daiBaseBorrowRate = hub.getBaseInterestRate(daiAssetId);
    rates.wethBaseBorrowRate = hub.getBaseInterestRate(wethAssetId);
    rates.usdxBaseBorrowRate = hub.getBaseInterestRate(usdxAssetId);
    rates.wbtcBaseBorrowRate = hub.getBaseInterestRate(wbtcAssetId);

    // Check Bob's risk premium
    bobRp = spoke1.getUserRiskPremium(bob);
    //assertEq(bobRp, _calculateExpectedUserRP(bob, spoke1), 'user risk premium after first accrual');

    // TODO: Skip time for accrual, and then check that the interest accrual is correct for all assets at user, reserve, spoke, and asset level
  }
  */

  /*
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
    // User rp does not update until the next action
    uint256 userRp = spoke.getLastUsedUserRiskPremium(user);

    assertEq(userPosition.baseDebt, expectedBaseDebt, 'user base debt');
    assertEq(userPosition.outstandingPremium, expectedPremium, 'user outstanding premium');
    assertEq(userRp, expectedRiskPremium, 'user risk premium');

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
  */

  // TODO: test_accrueInterest_TenPercentRP
  // TODO: test_accrueInterest_fuzz_RPBorrowAndskipTime
  // TODO: test_accrueInterest_fuzz_ChangingBorrowRate
}
