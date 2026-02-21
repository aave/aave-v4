// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/setup/Base.t.sol';

contract SpokeRepayEdgeCaseTest is Base {
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
    SpokeActions.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    // Alice supply dai such that usage ratio after bob borrows is ~45%, borrow rate ~7.5%
    SpokeActions.supply(
      spoke1,
      _daiReserveId(spoke1),
      alice,
      daiBorrowAmount.percentDivDown(45_00),
      alice
    );
    SpokeActions.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);
    skip(skipTime); // initial increase in index, no time passes for subsequent checks

    DebtData memory bobDebt = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    uint256 addExRateBefore = getAddExRate(hub1, daiAssetId);
    uint256 debtExRateBefore = getDebtExRate(hub1, daiAssetId);

    // repay partial premium debt
    vm.assume(bobDebt.premiumDebt > 1);
    uint256 daiRepayAmount = vm.randomUint(1, bobDebt.premiumDebt - 1);

    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      bobDebt.drawnDebt,
      bobDebt.premiumDebt,
      daiRepayAmount,
      hub1,
      daiAssetId
    );

    IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
      spoke1,
      bob,
      _daiReserveId(spoke1),
      daiRepayAmount
    );

    SharesAndAmount memory returnValues;
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
      getAddExRate(hub1, daiAssetId),
      'after partial premium debt repay'
    );
    _checkDebtRateConstant(
      debtExRateBefore,
      getDebtExRate(hub1, daiAssetId),
      'after partial premium debt repay'
    );

    bobDebt = getUserDebt(spoke1, bob, _daiReserveId(spoke1));

    // repay partial drawn debt
    daiRepayAmount = bobDebt.premiumDebt + bound(vm.randomUint(), 1, bobDebt.drawnDebt - 1);
    addExRateBefore = getAddExRate(hub1, daiAssetId);
    debtExRateBefore = getDebtExRate(hub1, daiAssetId);

    SpokeActions.repay(spoke1, _daiReserveId(spoke1), bob, daiRepayAmount, bob);

    _checkSupplyRateIncreasing(
      addExRateBefore,
      getAddExRate(hub1, daiAssetId),
      'after partial drawn debt repay'
    );
    _checkDebtRateConstant(
      debtExRateBefore,
      getDebtExRate(hub1, daiAssetId),
      'after partial drawn debt repay'
    );

    addExRateBefore = getAddExRate(hub1, daiAssetId);
    debtExRateBefore = getDebtExRate(hub1, daiAssetId);

    SpokeActions.repay(spoke1, _daiReserveId(spoke1), bob, UINT256_MAX, bob);

    _checkSupplyRateIncreasing(
      addExRateBefore,
      getAddExRate(hub1, daiAssetId),
      'after partial full debt repay'
    );
    _checkDebtRateConstant(
      debtExRateBefore,
      getDebtExRate(hub1, daiAssetId),
      'after full debt repay'
    );
  }

  function test_repay_supply_ex_rate_decr() public {
    // inflate ex rate to 1.5
    _mockInterestRateBps(address(irStrategy), 50_00);
    _updateCollateralRisk(spoke1, _daiReserveId(spoke1), 0, SPOKE_ADMIN);
    _updateCollateralRisk(spoke1, _wethReserveId(spoke1), 0, SPOKE_ADMIN);
    _updateLiquidityFee(hub1, daiAssetId, 0, HUB_ADMIN);

    // enough coll
    SpokeActions.supplyCollateral(spoke1, _wethReserveId(spoke1), alice, 1e18, alice);
    SpokeActions.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, 1e18, bob);
    SpokeActions.supplyCollateral(spoke1, _wethReserveId(spoke1), carol, 1e18, carol);

    _openSupplyPosition(spoke1, _daiReserveId(spoke1), 20e18);
    // carol borrows to inflate ex rate
    vm.prank(carol);
    spoke1.borrow(_daiReserveId(spoke1), 20e18, carol);

    skip(365 days);

    // inflated to 1.5
    uint256 addExRateBefore = getAddExRate(hub1, daiAssetId);
    uint256 exchangeRateBefore = hub1.previewRemoveByShares(daiAssetId, MAX_SUPPLY_AMOUNT);
    assertApproxEqAbs(exchangeRateBefore, 1.5e30, 0.0000001e30);

    _openSupplyPosition(spoke1, _daiReserveId(spoke1), 30);

    // 30% rp
    _updateCollateralRisk(spoke1, _wethReserveId(spoke1), 30_00, SPOKE_ADMIN);

    vm.prank(alice);
    spoke1.borrow(_daiReserveId(spoke1), 15, alice);
    vm.prank(bob);
    spoke1.borrow(_daiReserveId(spoke1), 15, bob);

    _checkSupplyRateIncreasing(addExRateBefore, getAddExRate(hub1, daiAssetId), 'after borrows');
    addExRateBefore = getAddExRate(hub1, daiAssetId);

    // alice repays full
    SpokeActions.repay(spoke1, _daiReserveId(spoke1), alice, UINT256_MAX, alice);

    _checkSupplyRateIncreasing(
      addExRateBefore,
      getAddExRate(hub1, daiAssetId),
      'after alice full repay'
    );
  }

  function test_repay_supply_ex_rate_decr_skip_time() public {
    // inflate ex rate to 1.5
    _mockInterestRateBps(address(irStrategy), 50_00);
    _updateCollateralRisk(spoke1, _daiReserveId(spoke1), 0, SPOKE_ADMIN);
    _updateCollateralRisk(spoke1, _wethReserveId(spoke1), 0, SPOKE_ADMIN);
    _updateLiquidityFee(hub1, daiAssetId, 0, HUB_ADMIN);

    // enough coll
    SpokeActions.supplyCollateral(spoke1, _wethReserveId(spoke1), alice, 1e18, alice);
    SpokeActions.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, 1e18, bob);
    SpokeActions.supplyCollateral(spoke1, _wethReserveId(spoke1), carol, 1e18, carol);

    _openSupplyPosition(spoke1, _daiReserveId(spoke1), 20e18);
    vm.prank(carol);
    spoke1.borrow(_daiReserveId(spoke1), 20e18, carol);

    skip(365 days);

    // inflated to 1.5
    uint256 exchangeRateBefore = hub1.previewRemoveByShares(daiAssetId, MAX_SUPPLY_AMOUNT);
    assertApproxEqAbs(exchangeRateBefore, 1.5e30, 0.0000001e30);

    _openSupplyPosition(spoke1, _daiReserveId(spoke1), 30e18);

    // 30% rp
    _updateCollateralRisk(spoke1, _wethReserveId(spoke1), 30_00, SPOKE_ADMIN);

    vm.prank(alice);
    spoke1.borrow(_daiReserveId(spoke1), 15, alice);
    vm.prank(bob);
    spoke1.borrow(_daiReserveId(spoke1), 15, bob);

    uint256 exchangeRateAfter = hub1.previewRemoveByShares(daiAssetId, MAX_SUPPLY_AMOUNT);
    assertGt(exchangeRateAfter, exchangeRateBefore);
    exchangeRateBefore = exchangeRateAfter;

    skip(1);

    // alice repays full
    SpokeActions.repay(spoke1, _daiReserveId(spoke1), alice, UINT256_MAX, alice);

    exchangeRateAfter = hub1.previewRemoveByShares(daiAssetId, MAX_SUPPLY_AMOUNT);
    assertGt(exchangeRateAfter, exchangeRateBefore, 'supply rate decreased');
  }

  function test_repay_less_than_share() public {
    // update collateral risk to zero
    _updateCollateralRisk(spoke1, _wethReserveId(spoke1), 0, SPOKE_ADMIN);

    // Accrue interest and ensure it's less than 1 share and pay it off
    uint256 daiSupplyAmount = 1000e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = 100e18;

    // Bob supplies WETH as collateral
    SpokeActions.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);

    // Alice supplies DAI
    SpokeActions.supply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrows DAI
    SpokeActions.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    DebtData memory bobDaiDebtBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    assertEq(bobDaiDebtBefore.totalDebt, daiBorrowAmount, 'Initial bob dai debt');
    assertEq(getUserDebt(spoke1, bob, _wethReserveId(spoke1)).totalDebt, 0);

    // Time passes so that interest accrues
    skip(365 days);

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

    vm.expectEmit(address(tokenList.dai));
    emit IERC20.Transfer(bob, address(hub1), repayAmount);

    CheckedRepayResult memory r = _checkedRepay(
      CheckedRepayParams({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        user: bob,
        amount: repayAmount,
        onBehalfOf: bob
      })
    );

    assertEq(r.amount, repayAmount);
    assertEq(r.shares, 0);
    assertEq(r.baseRestored, 0);
    assertEq(r.premiumRestored, 0);

    // debt remains unchanged & is donated (premium was already 0)
    assertEq(getUserDebt(spoke1, bob, _daiReserveId(spoke1)), bobDaiDebtBefore);
  }

  // repay less than 1 share of drawn debt, but nonzero premium debt
  function test_repay_zero_shares_nonzero_premium_debt() public {
    // update collateral risk of weth to 20%
    _updateCollateralRisk(spoke1, _wethReserveId(spoke1), 20_00, SPOKE_ADMIN);

    // Accrue interest and ensure it's less than 1 share and pay it off
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = 100;

    // Bob supplies WETH as collateral
    SpokeActions.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);

    // Alice supplies DAI
    SpokeActions.supply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrows DAI
    SpokeActions.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    assertEq(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      daiBorrowAmount,
      'Initial bob dai debt'
    );
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    // Time passes so that interest accrues
    skip(365 days);

    uint256 bobDaiTotalDebtBefore = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    assertGt(bobDaiTotalDebtBefore, daiBorrowAmount, 'Accrued interest increased bob dai debt');

    uint256 repayAmount = 1;

    // Ensure that the repay amount is less than 1 share
    assertEq(hub1.previewRestoreByAssets(daiAssetId, repayAmount), 0, 'Shares nonzero');

    IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
      spoke1,
      bob,
      _daiReserveId(spoke1),
      repayAmount
    );

    vm.expectEmit(address(spoke1));
    // 0 drawn shares restored
    emit ISpokeBase.Repay(_daiReserveId(spoke1), bob, bob, 0, repayAmount, expectedPremiumDelta);

    CheckedRepayResult memory r = _checkedRepay(
      CheckedRepayParams({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        user: bob,
        amount: repayAmount,
        onBehalfOf: bob
      })
    );

    // Ensure we are repaying only premium debt, not drawn debt
    assertEq(r.baseRestored, 0, 'Base debt nonzero');
    assertGt(r.premiumRestored, 0, 'Premium debt zero');

    assertEq(r.amount, repayAmount);
    assertEq(r.shares, 0);

    uint256 actualRepayAmount = r.baseRestored + r.premiumRestored;
    assertEq(r.ownerAfter.suppliedShares, r.ownerBefore.suppliedShares);
    assertApproxEqAbs(
      r.ownerAfter.totalDebt,
      r.ownerBefore.totalDebt - r.baseRestored - r.premiumRestored,
      1,
      'bob dai debt final balance'
    );
    assertApproxEqAbs(
      r.ownerAfter.premiumDebt,
      r.ownerBefore.premiumDebt - r.premiumRestored,
      1,
      'bob dai premium debt final balance'
    );

    // weth position unchanged
    UserSnapshot memory bobWethAfter = _snapshotUser(spoke1, _wethReserveId(spoke1), bob);
    assertEq(bobWethAfter.suppliedShares, hub1.previewAddByAssets(wethAssetId, wethSupplyAmount));
    assertEq(bobWethAfter.totalDebt, 0);

    assertEq(
      r.callerAfter.tokenBalance,
      r.callerBefore.tokenBalance - actualRepayAmount,
      'bob dai final balance'
    );
  }

  /// repay all accrued drawn debt interest when premium debt is already repaid
  function test_repay_only_base_debt_interest() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;

    // Bob supply weth
    SpokeActions.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);

    // Alice supply dai
    SpokeActions.supply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrow dai
    SpokeActions.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    assertEq(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      daiBorrowAmount,
      'bob dai debt before'
    );
    assertEq(
      spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob),
      0,
      'bob weth total debt before time skip'
    );

    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    // Time passes
    skip(10 days);

    DebtData memory bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    assertGt(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');

    // Bob repays premium
    SpokeActions.repay(spoke1, _daiReserveId(spoke1), bob, bobDaiBefore.premiumDebt, bob);

    bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    // Premium debt can be off by 1 due to rounding
    assertApproxEqAbs(bobDaiBefore.premiumDebt, 0, 1, 'bob dai premium debt after premium repay');

    // Bob repays drawn debt interest
    uint256 daiRepayAmount = bobDaiBefore.drawnDebt - daiBorrowAmount;
    assertGt(daiRepayAmount, 0); // interest is not zero

    {
      (uint256 baseRestored, ) = _calculateExactRestoreAmount(
        bobDaiBefore.drawnDebt,
        bobDaiBefore.premiumDebt,
        daiRepayAmount,
        hub1,
        daiAssetId
      );
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

    CheckedRepayResult memory r = _checkedRepay(
      CheckedRepayParams({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        user: bob,
        amount: daiRepayAmount,
        onBehalfOf: bob
      })
    );

    assertEq(r.amount, daiRepayAmount);
    assertEq(r.shares, hub1.previewRestoreByAssets(daiAssetId, r.baseRestored));

    assertEq(r.ownerAfter.suppliedShares, r.ownerBefore.suppliedShares);
    assertApproxEqAbs(
      r.ownerAfter.drawnDebt,
      daiBorrowAmount,
      2,
      'bob dai drawn debt final balance'
    );
    assertApproxEqAbs(r.ownerAfter.premiumDebt, 0, 1, 'bob dai premium debt final balance');
    assertEq(
      r.callerAfter.tokenBalance,
      r.callerBefore.tokenBalance - daiRepayAmount,
      'bob dai final balance'
    );

    // weth position unchanged
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);
  }

  /// repay all accrued drawn debt interest when premium debt is zero
  function test_repay_only_base_debt_no_premium() public {
    // update collateral risk to zero
    _updateCollateralRisk(spoke1, _wethReserveId(spoke1), 0, SPOKE_ADMIN);

    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;

    // Bob supply weth
    SpokeActions.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);

    // Alice supply dai
    SpokeActions.supply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrow dai
    SpokeActions.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    assertEq(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      daiBorrowAmount,
      'bob dai debt before'
    );
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    // Time passes
    skip(10 days);

    DebtData memory bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    assertGt(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');
    assertEq(bobDaiBefore.premiumDebt, 0, 'bob dai premium debt before');

    // Bob repays drawn debt interest
    uint256 daiRepayAmount = bobDaiBefore.drawnDebt - daiBorrowAmount;
    assertGt(daiRepayAmount, 0); // interest is not zero

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
      hub1.previewRestoreByAssets(daiAssetId, daiRepayAmount),
      daiRepayAmount,
      expectedPremiumDelta
    );

    CheckedRepayResult memory r = _checkedRepay(
      CheckedRepayParams({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        user: bob,
        amount: daiRepayAmount,
        onBehalfOf: bob
      })
    );

    assertEq(r.amount, daiRepayAmount);
    assertEq(r.shares, hub1.previewRestoreByAssets(daiAssetId, daiRepayAmount));

    assertEq(r.ownerAfter.suppliedShares, r.ownerBefore.suppliedShares);
    assertApproxEqAbs(
      r.ownerAfter.drawnDebt,
      daiBorrowAmount,
      2,
      'bob dai drawn debt final balance'
    );
    assertEq(r.ownerAfter.premiumDebt, 0, 'bob dai premium debt final balance');
    assertEq(
      r.callerAfter.tokenBalance,
      r.callerBefore.tokenBalance - daiRepayAmount,
      'bob dai final balance'
    );

    // weth position unchanged
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);
  }
}
