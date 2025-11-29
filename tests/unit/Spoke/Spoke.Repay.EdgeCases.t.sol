// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeRepayEdgeCaseTest is SpokeBase {
  using PercentageMath for uint256;

  /// repay partial premium, base & full debt, with no interest accrual (no time pass)
  /// supply ex rate can increase while debt ex rate should remain the same
  /// this is due to donation on available liquidity
  function test_fuzz_repay_effect_on_ex_rates(uint256 daiBorrowAmount, uint256 skipTime) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 10);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      daiBorrowAmount
    );

    // Bob supply weth as collateral
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    // Alice supply dai such that usage ratio after bob borrows is ~45%, borrow rate ~7.5%
    Utils.supply(
      spoke1,
      _daiReserveId(spoke1),
      alice,
      daiBorrowAmount.percentDivDown(45_00),
      alice
    );
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);
    skip(skipTime); // initial increase in index, no time passes for subsequent checks

    Debts memory bobDebt = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    uint256 addExRateBefore = getAddExRate(daiAssetId);
    uint256 debtExRateBefore = getDebtExRate(daiAssetId);

    // repay partial premium debt
    vm.assume(bobDebt.premiumDebt > 1);
    uint256 daiRepayAmount = vm.randomUint(1, bobDebt.premiumDebt - 1);

    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      bobDebt.drawnDebt,
      bobDebt.premiumDebt,
      daiRepayAmount,
      daiAssetId
    );

    IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
      spoke1,
      bob,
      _daiReserveId(spoke1),
      daiRepayAmount
    );

    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Repay(
      _daiReserveId(spoke1),
      bob,
      bob,
      0,
      baseRestored + premiumRestored,
      expectedPremiumDelta
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = spoke1.repay(
      _daiReserveId(spoke1),
      daiRepayAmount,
      bob
    );

    assertEq(returnValues.amount, daiRepayAmount);
    assertEq(returnValues.shares, 0);

    _checkSupplyRateIncreasing(
      addExRateBefore,
      getAddExRate(daiAssetId),
      'after partial premium debt repay'
    );
    _checkDebtRateConstant(
      debtExRateBefore,
      getDebtExRate(daiAssetId),
      'after partial premium debt repay'
    );

    bobDebt = getUserDebt(spoke1, bob, _daiReserveId(spoke1));

    // repay partial drawn debt
    daiRepayAmount = bobDebt.premiumDebt + bound(vm.randomUint(), 1, bobDebt.drawnDebt - 1);
    addExRateBefore = getAddExRate(daiAssetId);
    debtExRateBefore = getDebtExRate(daiAssetId);

    Utils.repay(spoke1, _daiReserveId(spoke1), bob, daiRepayAmount, bob);

    _checkSupplyRateIncreasing(
      addExRateBefore,
      getAddExRate(daiAssetId),
      'after partial drawn debt repay'
    );
    _checkDebtRateConstant(
      debtExRateBefore,
      getDebtExRate(daiAssetId),
      'after partial drawn debt repay'
    );

    addExRateBefore = getAddExRate(daiAssetId);
    debtExRateBefore = getDebtExRate(daiAssetId);

    Utils.repay(spoke1, _daiReserveId(spoke1), bob, UINT256_MAX, bob);

    _checkSupplyRateIncreasing(
      addExRateBefore,
      getAddExRate(daiAssetId),
      'after partial full debt repay'
    );
    _checkDebtRateConstant(debtExRateBefore, getDebtExRate(daiAssetId), 'after full debt repay');
  }

  function test_repay_supply_ex_rate_decr() public {
    // inflate ex rate to 1.5
    _mockInterestRateBps(50_00);
    _updateCollateralRisk(spoke1, _daiReserveId(spoke1), 0);
    _updateCollateralRisk(spoke1, _wethReserveId(spoke1), 0);
    updateLiquidityFee(hub1, daiAssetId, 0);

    // enough coll
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), alice, 1e18, alice);
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, 1e18, bob);
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), carol, 1e18, carol);

    _openSupplyPosition(spoke1, _daiReserveId(spoke1), 20e18);
    // carol borrows to inflate ex rate
    vm.prank(carol);
    spoke1.borrow(_daiReserveId(spoke1), 20e18, carol);

    skip(365 days);

    // inflated to 1.5
    uint256 addExRateBefore = getAddExRate(daiAssetId);
    uint256 exchangeRateBefore = hub1.previewRemoveByShares(daiAssetId, MAX_SUPPLY_AMOUNT);
    assertApproxEqAbs(exchangeRateBefore, 1.5e30, 0.0000001e30);

    _openSupplyPosition(spoke1, _daiReserveId(spoke1), 30);

    // 30% rp
    _updateCollateralRisk(spoke1, _wethReserveId(spoke1), 30_00);

    vm.prank(alice);
    spoke1.borrow(_daiReserveId(spoke1), 15, alice);
    vm.prank(bob);
    spoke1.borrow(_daiReserveId(spoke1), 15, bob);

    _checkSupplyRateIncreasing(addExRateBefore, getAddExRate(daiAssetId), 'after borrows');
    addExRateBefore = getAddExRate(daiAssetId);

    // alice repays full
    Utils.repay(spoke1, _daiReserveId(spoke1), alice, UINT256_MAX, alice);

    _checkSupplyRateIncreasing(addExRateBefore, getAddExRate(daiAssetId), 'after alice full repay');
  }

  function test_repay_supply_ex_rate_decr_skip_time() public {
    // inflate ex rate to 1.5
    _mockInterestRateBps(50_00);
    _updateCollateralRisk(spoke1, _daiReserveId(spoke1), 0);
    _updateCollateralRisk(spoke1, _wethReserveId(spoke1), 0);
    updateLiquidityFee(hub1, daiAssetId, 0);

    // enough coll
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), alice, 1e18, alice);
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, 1e18, bob);
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), carol, 1e18, carol);

    _openSupplyPosition(spoke1, _daiReserveId(spoke1), 20e18);
    vm.prank(carol);
    spoke1.borrow(_daiReserveId(spoke1), 20e18, carol);

    skip(365 days);

    // inflated to 1.5
    uint256 exchangeRateBefore = hub1.previewRemoveByShares(daiAssetId, MAX_SUPPLY_AMOUNT);
    assertApproxEqAbs(exchangeRateBefore, 1.5e30, 0.0000001e30);

    _openSupplyPosition(spoke1, _daiReserveId(spoke1), 30e18);

    // 30% rp
    _updateCollateralRisk(spoke1, _wethReserveId(spoke1), 30_00);

    vm.prank(alice);
    spoke1.borrow(_daiReserveId(spoke1), 15, alice);
    vm.prank(bob);
    spoke1.borrow(_daiReserveId(spoke1), 15, bob);

    uint256 exchangeRateAfter = hub1.previewRemoveByShares(daiAssetId, MAX_SUPPLY_AMOUNT);
    assertGt(exchangeRateAfter, exchangeRateBefore);
    exchangeRateBefore = exchangeRateAfter;

    skip(1);

    // alice repays full
    Utils.repay(spoke1, _daiReserveId(spoke1), alice, UINT256_MAX, alice);

    exchangeRateAfter = hub1.previewRemoveByShares(daiAssetId, MAX_SUPPLY_AMOUNT);
    assertGt(exchangeRateAfter, exchangeRateBefore, 'supply rate decreased');
  }

  function test_repay_less_than_share() public {
    // update collateral risk to zero
    _updateCollateralRisk(spoke1, _wethReserveId(spoke1), 0);

    // Accrue interest and ensure it's less than 1 share and pay it off
    uint256 daiSupplyAmount = 1000e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = 100e18;

    // Bob supplies WETH as collateral
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);

    // Alice supplies DAI
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrows DAI
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    ISpoke.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    ISpoke.UserPosition memory bobWethDataBefore = getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    Debts memory bobDaiDebtBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiDebtBefore.totalDebt, daiBorrowAmount, 'Initial bob dai debt');
    assertEq(
      bobWethDataBefore.suppliedShares,
      hub1.previewAddByAssets(wethAssetId, wethSupplyAmount)
    );
    assertEq(getUserDebt(spoke1, bob, _wethReserveId(spoke1)).totalDebt, 0);

    // Time passes so that interest accrues
    skip(365 days);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiDebtBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    assertGt(
      bobDaiDebtBefore.totalDebt,
      daiBorrowAmount,
      'Accrued interest increased bob dai debt'
    );
    assertEq(bobDaiDebtBefore.premiumDebt, 0, 'premium debt is non zero');

    uint256 repayAmount = 1;
    // Ensure that the repay amount is less than 1 share
    assertEq(hub1.previewRestoreByAssets(daiAssetId, repayAmount), 0, 'Shares nonzero');

    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      bobDaiDebtBefore.drawnDebt,
      bobDaiDebtBefore.premiumDebt,
      repayAmount,
      daiAssetId
    );
    assertEq(baseRestored, 0);
    assertEq(premiumRestored, 0);

    TestReturnValues memory returnValues;

    vm.expectEmit(address(tokenList.dai));
    emit IERC20.Transfer(bob, address(hub1), repayAmount);

    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = spoke1.repay(
      _daiReserveId(spoke1),
      repayAmount,
      bob
    );

    assertEq(returnValues.amount, repayAmount);
    assertEq(returnValues.shares, 0);

    // debt remains unchanged & is donated (premium was already 0)
    assertEq(getUserDebt(spoke1, bob, _daiReserveId(spoke1)), bobDaiDebtBefore);
  }

  // repay less than 1 share of drawn debt, but nonzero premium debt
  function test_repay_zero_shares_nonzero_premium_debt() public {
    // update collateral risk of weth to 20%
    _updateCollateralRisk(spoke1, _wethReserveId(spoke1), 20_00);

    // Accrue interest and ensure it's less than 1 share and pay it off
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = 100;

    // Bob supplies WETH as collateral
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);

    // Alice supplies DAI
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrows DAI
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    ISpoke.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    ISpoke.UserPosition memory bobWethDataBefore = getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    Debts memory bobDaiBefore;
    Debts memory bobWethBefore;

    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.drawnDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    bobWethBefore.totalDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob);
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiBefore.totalDebt, daiBorrowAmount, 'Initial bob dai debt');
    assertEq(
      bobWethBefore.totalDebt,
      spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob),
      'Initial bob weth debt'
    );
    assertEq(
      bobWethBefore.totalDebt,
      spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob),
      'Initial bob weth debt'
    );
    assertEq(
      bobWethDataBefore.suppliedShares,
      hub1.previewAddByAssets(wethAssetId, wethSupplyAmount)
    );
    assertEq(bobWethBefore.totalDebt, 0);

    // Time passes so that interest accrues
    skip(365 days);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.drawnDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    assertGt(bobDaiBefore.totalDebt, daiBorrowAmount, 'Accrued interest increased bob dai debt');

    uint256 repayAmount = 1;

    // Ensure that the repay amount is less than 1 share
    assertEq(hub1.previewRestoreByAssets(daiAssetId, repayAmount), 0, 'Shares nonzero');

    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      bobDaiBefore.drawnDebt,
      bobDaiBefore.premiumDebt,
      repayAmount,
      daiAssetId
    );

    IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
      spoke1,
      bob,
      _daiReserveId(spoke1),
      repayAmount
    );

    // Ensure we are repaying only premium debt, not drawn debt
    assertEq(baseRestored, 0, 'Base debt nonzero');
    assertGt(premiumRestored, 0, 'Premium debt zero');

    // Repay
    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    // 0 drawn shares restored
    emit ISpokeBase.Repay(_daiReserveId(spoke1), bob, bob, 0, repayAmount, expectedPremiumDelta);
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = spoke1.repay(
      _daiReserveId(spoke1),
      repayAmount,
      bob
    );

    assertEq(returnValues.amount, repayAmount);
    assertEq(returnValues.shares, 0);

    ISpoke.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    ISpoke.UserPosition memory bobWethDataAfter = getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    Debts memory bobDaiAfter;
    bobDaiAfter.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiAfter.drawnDebt, bobDaiAfter.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    repayAmount = baseRestored + premiumRestored;

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertApproxEqAbs(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      bobDaiBefore.totalDebt - baseRestored - premiumRestored,
      1,
      'bob dai debt final balance'
    );
    assertApproxEqAbs(
      bobDaiAfter.premiumDebt,
      bobDaiBefore.premiumDebt - premiumRestored,
      1,
      'bob dai premium debt final balance'
    );

    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(bobWethBefore.totalDebt, spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob));
    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - repayAmount,
      'bob dai final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);
  }

  /// repay all accrued drawn debt interest when premium debt is already repaid
  function test_repay_only_base_debt_interest() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;

    // Bob supply weth
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);

    // Alice supply dai
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrow dai
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    ISpoke.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    ISpoke.UserPosition memory bobWethDataBefore = getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    Debts memory bobDaiBefore;
    Debts memory bobWethBefore;
    bobWethBefore.totalDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob);
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.drawnDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');
    assertEq(
      bobWethDataBefore.suppliedShares,
      hub1.previewAddByAssets(wethAssetId, wethSupplyAmount)
    );
    assertEq(bobWethBefore.totalDebt, 0, 'bob weth total debt before time skip');

    // Time passes
    skip(10 days);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.drawnDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    assertGt(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');

    // Bob repays premium
    Utils.repay(spoke1, _daiReserveId(spoke1), bob, bobDaiBefore.premiumDebt, bob);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));

    // Premium debt can be off by 1 due to rounding
    assertApproxEqAbs(bobDaiBefore.premiumDebt, 0, 1, 'bob dai premium debt after premium repay');

    // Bob repays drawn debt
    uint256 daiRepayAmount = bobDaiBefore.drawnDebt - daiBorrowAmount;
    assertGt(daiRepayAmount, 0); // interest is not zero
    (uint256 baseRestored, ) = _calculateExactRestoreAmount(
      bobDaiBefore.drawnDebt,
      bobDaiBefore.premiumDebt,
      daiRepayAmount,
      daiAssetId
    );

    TestReturnValues memory returnValues;
    {
      IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
        spoke1,
        bob,
        _daiReserveId(spoke1),
        daiRepayAmount
      );

      vm.expectEmit(address(spoke1));
      emit ISpokeBase.Repay(
        _daiReserveId(spoke1),
        bob,
        bob,
        hub1.previewRestoreByAssets(daiAssetId, baseRestored),
        daiRepayAmount,
        expectedPremiumDelta
      );
    }
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = spoke1.repay(
      _daiReserveId(spoke1),
      daiRepayAmount,
      bob
    );

    assertEq(returnValues.amount, daiRepayAmount);
    assertEq(returnValues.shares, hub1.previewRestoreByAssets(daiAssetId, baseRestored));

    ISpoke.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    ISpoke.UserPosition memory bobWethDataAfter = getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    Debts memory bobDaiAfter;
    Debts memory bobWethAfter;
    bobWethAfter.totalDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob);
    bobDaiAfter.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiAfter.drawnDebt, bobDaiAfter.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertApproxEqAbs(
      bobDaiAfter.drawnDebt,
      daiBorrowAmount,
      2,
      'bob dai drawn debt final balance'
    );
    assertApproxEqAbs(bobDaiAfter.premiumDebt, 0, 1, 'bob dai premium debt final balance');
    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(bobWethAfter.totalDebt, bobWethBefore.totalDebt);
    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - daiRepayAmount,
      'bob dai final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);
  }

  /// repay all accrued drawn debt interest when premium debt is zero
  function test_repay_only_base_debt_no_premium() public {
    // update collateral risk to zero
    _updateCollateralRisk(spoke1, _wethReserveId(spoke1), 0);

    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;

    // Bob supply weth
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);

    // Alice supply dai
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrow dai
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    ISpoke.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    ISpoke.UserPosition memory bobWethDataBefore = getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    Debts memory bobDaiBefore;
    Debts memory bobWethBefore;
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.drawnDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    bobWethBefore.totalDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');
    assertEq(
      bobWethDataBefore.suppliedShares,
      hub1.previewAddByAssets(wethAssetId, wethSupplyAmount)
    );
    assertEq(bobWethBefore.totalDebt, 0);

    // Time passes
    skip(10 days);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.drawnDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    assertGt(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');
    assertEq(bobDaiBefore.premiumDebt, 0, 'bob dai premium debt before');

    // Bob repays drawn debt
    uint256 daiRepayAmount = bobDaiBefore.drawnDebt - daiBorrowAmount;
    assertGt(daiRepayAmount, 0); // interest is not zero

    IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
      spoke1,
      bob,
      _daiReserveId(spoke1),
      daiRepayAmount
    );

    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Repay(
      _daiReserveId(spoke1),
      bob,
      bob,
      hub1.previewRestoreByAssets(daiAssetId, daiRepayAmount),
      daiRepayAmount,
      expectedPremiumDelta
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = spoke1.repay(
      _daiReserveId(spoke1),
      daiRepayAmount,
      bob
    );

    assertEq(returnValues.amount, daiRepayAmount);
    assertEq(returnValues.shares, hub1.previewRestoreByAssets(daiAssetId, daiRepayAmount));

    ISpoke.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    ISpoke.UserPosition memory bobWethDataAfter = getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    Debts memory bobDaiAfter;
    Debts memory bobWethAfter;
    bobWethAfter.totalDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob);
    bobDaiAfter.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiAfter.drawnDebt, bobDaiAfter.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertApproxEqAbs(
      bobDaiAfter.drawnDebt,
      daiBorrowAmount,
      2,
      'bob dai drawn debt final balance'
    );
    assertEq(bobDaiAfter.premiumDebt, 0, 'bob dai premium debt final balance');
    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(bobWethAfter.totalDebt, bobWethBefore.totalDebt);

    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - daiRepayAmount,
      'bob dai final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);
  }
}
