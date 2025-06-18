// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeRepayEdgeCaseTest is SpokeBase {
  using WadRayMath for uint256;

  /// repay partial premium, base & full debt, with no interest accrual (no time pass)
  /// supply ex rate can increase while debt ex rate should remain the same
  /// this is due to donation on available liquidity
  function test_fuzz_repay_effect_on_ex_rates(uint256 daiBorrowAmount, uint256 skipTime) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      daiBorrowAmount
    );

    // Bob supply weth as collateral
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiBorrowAmount, alice);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);
    skip(skipTime); // initial increase in index, no time passes for subsequent checks

    Debts memory bobDebt = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    uint256 supplyExRateBefore = getSupplyExRate(daiAssetId);
    uint256 debtExRateBefore = getDebtExRate(daiAssetId);

    // repay partial premium debt
    vm.assume(bobDebt.premiumDebt > 1);
    uint256 daiRepayAmount = vm.randomUint(1, bobDebt.premiumDebt - 1);

    (uint256 baseToRestore, uint256 premiumToRestore) = _calculateExactRestoreAmount(
      bobDebt.baseDebt,
      bobDebt.premiumDebt,
      daiRepayAmount,
      daiAssetId
    );

    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(_daiReserveId(spoke1), bob, 0);
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);

    _checkSupplyRateIncreasing(
      supplyExRateBefore,
      getSupplyExRate(daiAssetId),
      false,
      'after partial premium debt repay'
    );
    _checkDebtRateConstant(
      debtExRateBefore,
      getDebtExRate(daiAssetId),
      'after partial premium debt repay'
    );

    bobDebt = getUserDebt(spoke1, bob, _daiReserveId(spoke1));

    // repay partial base debt
    daiRepayAmount = bobDebt.premiumDebt + bound(vm.randomUint(), 1, bobDebt.baseDebt - 1);
    supplyExRateBefore = getSupplyExRate(daiAssetId);
    debtExRateBefore = getDebtExRate(daiAssetId);

    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);

    _checkSupplyRateIncreasing(
      supplyExRateBefore,
      getSupplyExRate(daiAssetId),
      false,
      'after partial base debt repay'
    );
    _checkDebtRateConstant(
      debtExRateBefore,
      getDebtExRate(daiAssetId),
      'after partial base debt repay'
    );

    supplyExRateBefore = getSupplyExRate(daiAssetId);
    debtExRateBefore = getDebtExRate(daiAssetId);

    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), type(uint256).max);

    _checkSupplyRateIncreasing(
      supplyExRateBefore,
      getSupplyExRate(daiAssetId),
      false,
      'after partial full debt repay'
    );
    _checkDebtRateConstant(debtExRateBefore, getDebtExRate(daiAssetId), 'after full debt repay');
  }

  function test_repay_supply_ex_rate_decr() public {
    // inflate ex rate to 1.5
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(uint256(50_00).bpsToRay())
    );
    updateLiquidityPremium(spoke1, _daiReserveId(spoke1), 0);
    updateLiquidityPremium(spoke1, _wethReserveId(spoke1), 0);

    // enough coll
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), alice, 1e18, alice);
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, 1e18, bob);
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), carol, 1e18, carol);

    _openSupplyPosition(spoke1, _daiReserveId(spoke1), 20);
    // carol borrows to inflate ex rate
    vm.prank(carol);
    spoke1.borrow(_daiReserveId(spoke1), 20, carol);

    skip(365 days);

    // inflated to 1.5
    uint256 supplyExRateBefore = getSupplyExRate(daiAssetId);
    uint256 exchangeRateBefore = hub.convertToSuppliedAssets(daiAssetId, MAX_SUPPLY_AMOUNT);
    assertEq(exchangeRateBefore, 1.5e30);

    _openSupplyPosition(spoke1, _daiReserveId(spoke1), 30);

    // 30% rp
    updateLiquidityPremium(spoke1, _wethReserveId(spoke1), 30_00);

    vm.prank(alice);
    spoke1.borrow(_daiReserveId(spoke1), 15, alice);
    vm.prank(bob);
    spoke1.borrow(_daiReserveId(spoke1), 15, bob);

    _checkSupplyRateIncreasing(
      supplyExRateBefore,
      getSupplyExRate(daiAssetId),
      false,
      'after borrows'
    );
    supplyExRateBefore = getSupplyExRate(daiAssetId);

    // alice repays full
    vm.prank(alice);
    spoke1.repay(_daiReserveId(spoke1), type(uint256).max);

    _checkSupplyRateIncreasing(
      supplyExRateBefore,
      getSupplyExRate(daiAssetId),
      false,
      'after alice full repay'
    );
  }

  function test_repay_supply_ex_rate_decr_skip_time() public {
    // inflate ex rate to 1.5
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(uint256(50_00).bpsToRay())
    );
    updateLiquidityPremium(spoke1, _daiReserveId(spoke1), 0);
    updateLiquidityPremium(spoke1, _wethReserveId(spoke1), 0);

    // enough coll
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), alice, 1e18, alice);
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, 1e18, bob);
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), carol, 1e18, carol);

    _openSupplyPosition(spoke1, _daiReserveId(spoke1), 20);
    vm.prank(carol);
    spoke1.borrow(_daiReserveId(spoke1), 20, carol);

    skip(365 days);

    // inflated to 1.5
    uint256 exchangeRateBefore = hub.convertToSuppliedAssets(daiAssetId, MAX_SUPPLY_AMOUNT);
    assertEq(exchangeRateBefore, 1.5e30);

    _openSupplyPosition(spoke1, _daiReserveId(spoke1), 30);

    // 30% rp
    updateLiquidityPremium(spoke1, _wethReserveId(spoke1), 30_00);

    vm.prank(alice);
    spoke1.borrow(_daiReserveId(spoke1), 15, alice);
    vm.prank(bob);
    spoke1.borrow(_daiReserveId(spoke1), 15, bob);

    uint256 exchangeRateAfter = hub.convertToSuppliedAssets(daiAssetId, MAX_SUPPLY_AMOUNT);
    assertGt(exchangeRateAfter, exchangeRateBefore);
    exchangeRateBefore = exchangeRateAfter;

    skip(1);

    // alice repays full
    vm.prank(alice);
    spoke1.repay(_daiReserveId(spoke1), type(uint256).max);

    exchangeRateAfter = hub.convertToSuppliedAssets(daiAssetId, MAX_SUPPLY_AMOUNT);
    assertGt(exchangeRateAfter, exchangeRateBefore, 'supply rate decreased');
  }

  function test_repay_less_than_share() public {
    // update liquidity premium to zero
    updateLiquidityPremium(spoke1, _wethReserveId(spoke1), 0);

    // Accrue interest and ensure it's less than 1 share and pay it off
    uint256 daiSupplyAmount = 1000e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = 100e18;

    // Bob supplies WETH as collateral
    Utils.supply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supplies DAI
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrows DAI
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    DataTypes.UserPosition memory bobDaiDataBefore = getUserInfo(
      spoke1,
      bob,
      _daiReserveId(spoke1)
    );
    DataTypes.UserPosition memory bobWethDataBefore = getUserInfo(
      spoke1,
      bob,
      _wethReserveId(spoke1)
    );
    Debts memory bobDaiDebtBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiDebtBefore.totalDebt, daiBorrowAmount, 'Initial bob dai debt');
    assertEq(
      bobWethDataBefore.suppliedShares,
      hub.convertToSuppliedShares(wethAssetId, wethSupplyAmount)
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
    assertEq(hub.convertToDrawnShares(daiAssetId, repayAmount), 0, 'Shares nonzero');

    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      bobDaiDebtBefore.baseDebt,
      bobDaiDebtBefore.premiumDebt,
      repayAmount,
      daiAssetId
    );
    assertEq(baseRestored, 0);
    assertEq(premiumRestored, 0);

    vm.expectEmit(address(tokenList.dai));
    emit IERC20.Transfer(bob, address(hub), repayAmount);
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), repayAmount);

    // debt remains unchanged & is donated (premium was already 0)
    assertEq(getUserDebt(spoke1, bob, _daiReserveId(spoke1)), bobDaiDebtBefore);
  }

  // repay less than 1 share of base debt, but nonzero premium debt
  function test_repay_zero_shares_nonzero_premium_debt() public {
    // update liquidity premium of weth to 20%
    updateLiquidityPremium(spoke1, _wethReserveId(spoke1), 20_00);

    // Accrue interest and ensure it's less than 1 share and pay it off
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = 100;

    // Bob supplies WETH as collateral
    Utils.supply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supplies DAI
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrows DAI
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    DataTypes.UserPosition memory bobDaiDataBefore = getUserInfo(
      spoke1,
      bob,
      _daiReserveId(spoke1)
    );
    DataTypes.UserPosition memory bobWethDataBefore = getUserInfo(
      spoke1,
      bob,
      _wethReserveId(spoke1)
    );
    Debts memory bobDaiBefore;
    Debts memory bobWethBefore;

    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.baseDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
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
      hub.convertToSuppliedShares(wethAssetId, wethSupplyAmount)
    );
    assertEq(bobWethBefore.totalDebt, 0);

    // Time passes so that interest accrues
    skip(365 days);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.baseDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    assertGt(bobDaiBefore.totalDebt, daiBorrowAmount, 'Accrued interest increased bob dai debt');

    uint256 repayAmount = 1;

    // Ensure that the repay amount is less than 1 share
    assertEq(hub.convertToDrawnShares(daiAssetId, repayAmount), 0, 'Shares nonzero');

    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      bobDaiBefore.baseDebt,
      bobDaiBefore.premiumDebt,
      repayAmount,
      daiAssetId
    );

    // Ensure we are repaying only premium debt, not base debt
    assertEq(baseRestored, 0, 'Base debt nonzero');
    assertGt(premiumRestored, 0, 'Premium debt zero');

    // Repay
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(_daiReserveId(spoke1), bob, 0);

    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), repayAmount);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
      spoke1,
      bob,
      _wethReserveId(spoke1)
    );
    Debts memory bobDaiAfter;
    bobDaiAfter.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiAfter.baseDebt, bobDaiAfter.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    repayAmount = baseRestored + premiumRestored;

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      bobDaiBefore.totalDebt - baseRestored - premiumRestored,
      'bob dai debt final balance'
    );
    assertEq(bobDaiAfter.premiumDebt, 0, 'bob dai premium debt final balance');

    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(bobWethBefore.totalDebt, spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob));
    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - repayAmount,
      'bob dai final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);
  }

  /// repay all accrued base debt interest when premium debt is already repaid
  function test_repay_only_base_debt_interest() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;

    // Bob supply weth
    Utils.supply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrow dai
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    DataTypes.UserPosition memory bobDaiDataBefore = getUserInfo(
      spoke1,
      bob,
      _daiReserveId(spoke1)
    );
    DataTypes.UserPosition memory bobWethDataBefore = getUserInfo(
      spoke1,
      bob,
      _wethReserveId(spoke1)
    );
    Debts memory bobDaiBefore;
    Debts memory bobWethBefore;
    bobWethBefore.totalDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob);
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.baseDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');
    assertEq(
      bobWethDataBefore.suppliedShares,
      hub.convertToSuppliedShares(wethAssetId, wethSupplyAmount)
    );
    assertEq(bobWethBefore.totalDebt, 0, 'bob weth total debt before time skip');

    // Time passes
    skip(10 days);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.baseDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    assertGt(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');

    // Bob repays premium
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), bobDaiBefore.premiumDebt);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));

    // Premium debt can be off by 1 due to rounding
    assertApproxEqAbs(bobDaiBefore.premiumDebt, 0, 1, 'bob dai premium debt after premium repay');

    // Bob repays base debt
    uint256 daiRepayAmount = bobDaiBefore.baseDebt - daiBorrowAmount;
    assertGt(daiRepayAmount, 0); // interest is not zero
    (uint256 baseRestored, ) = _calculateExactRestoreAmount(
      bobDaiBefore.baseDebt,
      bobDaiBefore.premiumDebt,
      daiRepayAmount,
      daiAssetId
    );

    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
      _daiReserveId(spoke1),
      bob,
      hub.convertToDrawnShares(daiAssetId, baseRestored)
    );
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
      spoke1,
      bob,
      _wethReserveId(spoke1)
    );
    Debts memory bobDaiAfter;
    Debts memory bobWethAfter;
    bobWethAfter.totalDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob);
    bobDaiAfter.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiAfter.baseDebt, bobDaiAfter.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertApproxEqAbs(bobDaiAfter.baseDebt, daiBorrowAmount, 1, 'bob dai base debt final balance');
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

  /// repay all accrued base debt interest when premium debt is zero
  function test_repay_only_base_debt_no_premium() public {
    // update liquidity premium to zero
    updateLiquidityPremium(spoke1, _wethReserveId(spoke1), 0);

    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;

    // Bob supply weth
    Utils.supply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrow dai
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    DataTypes.UserPosition memory bobDaiDataBefore = getUserInfo(
      spoke1,
      bob,
      _daiReserveId(spoke1)
    );
    DataTypes.UserPosition memory bobWethDataBefore = getUserInfo(
      spoke1,
      bob,
      _wethReserveId(spoke1)
    );
    Debts memory bobDaiBefore;
    Debts memory bobWethBefore;
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.baseDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    bobWethBefore.totalDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');
    assertEq(
      bobWethDataBefore.suppliedShares,
      hub.convertToSuppliedShares(wethAssetId, wethSupplyAmount)
    );
    assertEq(bobWethBefore.totalDebt, 0);

    // Time passes
    skip(10 days);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.baseDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    assertGt(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');
    assertEq(bobDaiBefore.premiumDebt, 0, 'bob dai premium debt before');

    // Bob repays base debt
    uint256 daiRepayAmount = bobDaiBefore.baseDebt - daiBorrowAmount;
    assertGt(daiRepayAmount, 0); // interest is not zero

    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
      _daiReserveId(spoke1),
      bob,
      hub.convertToDrawnShares(daiAssetId, daiRepayAmount)
    );
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
      spoke1,
      bob,
      _wethReserveId(spoke1)
    );
    Debts memory bobDaiAfter;
    Debts memory bobWethAfter;
    bobWethAfter.totalDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob);
    bobDaiAfter.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiAfter.baseDebt, bobDaiAfter.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(bobDaiAfter.baseDebt, daiBorrowAmount, 'bob dai base debt final balance');
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
