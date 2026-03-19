// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

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
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: wethSupplyAmount,
      onBehalfOf: bob
    });
    // Alice supply dai such that usage ratio after bob borrows is ~45%, drawn rate ~7.5%
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: daiBorrowAmount.percentDivDown(45_00),
      onBehalfOf: alice
    });
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: daiBorrowAmount,
      onBehalfOf: bob
    });
    skip(skipTime); // initial increase in index, no time passes for subsequent checks

    DebtData memory bobDebt = _getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    uint256 addExRateBefore = _getAddExRate(hub1, daiAssetId);
    uint256 debtExRateBefore = _getDebtExRate(hub1, daiAssetId);

    // repay partial premium debt
    vm.assume(bobDebt.premiumDebt > 1);
    uint256 daiRepayAmount = vm.randomUint(1, bobDebt.premiumDebt - 1);

    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      hub1,
      daiAssetId,
      bobDebt.drawnDebt,
      bobDebt.premiumDebt,
      daiRepayAmount
    );

    IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
      spoke1,
      bob,
      _daiReserveId(spoke1),
      daiRepayAmount
    );

    SharesAndAmount memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
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
      _getAddExRate(hub1, daiAssetId),
      'after partial premium debt repay'
    );
    _checkDebtRateConstant(
      debtExRateBefore,
      _getDebtExRate(hub1, daiAssetId),
      'after partial premium debt repay'
    );

    bobDebt = _getUserDebt(spoke1, bob, _daiReserveId(spoke1));

    // repay partial drawn debt
    daiRepayAmount = bobDebt.premiumDebt + bound(vm.randomUint(), 1, bobDebt.drawnDebt - 1);
    addExRateBefore = _getAddExRate(hub1, daiAssetId);
    debtExRateBefore = _getDebtExRate(hub1, daiAssetId);

    SpokeActions.repay({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: daiRepayAmount,
      onBehalfOf: bob
    });

    _checkSupplyRateIncreasing(
      addExRateBefore,
      _getAddExRate(hub1, daiAssetId),
      'after partial drawn debt repay'
    );
    _checkDebtRateConstant(
      debtExRateBefore,
      _getDebtExRate(hub1, daiAssetId),
      'after partial drawn debt repay'
    );

    addExRateBefore = _getAddExRate(hub1, daiAssetId);
    debtExRateBefore = _getDebtExRate(hub1, daiAssetId);

    SpokeActions.repay({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: UINT256_MAX,
      onBehalfOf: bob
    });

    _checkSupplyRateIncreasing(
      addExRateBefore,
      _getAddExRate(hub1, daiAssetId),
      'after partial full debt repay'
    );
    _checkDebtRateConstant(
      debtExRateBefore,
      _getDebtExRate(hub1, daiAssetId),
      'after full debt repay'
    );
  }

  function test_repay_supply_ex_rate_decr() public {
    // inflate ex rate to 1.5
    _mockDrawnRateBps({irStrategy: address(irStrategy), drawnRateBps: 50_00});
    _updateCollateralRisk(spoke1, _daiReserveId(spoke1), 0);
    _updateCollateralRisk(spoke1, _wethReserveId(spoke1), 0);
    _updateLiquidityFee(hub1, daiAssetId, 0);

    // enough coll
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: alice,
      amount: 1e18,
      onBehalfOf: alice
    });
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: 1e18,
      onBehalfOf: bob
    });
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: carol,
      amount: 1e18,
      onBehalfOf: carol
    });

    _openSupplyPosition(spoke1, _daiReserveId(spoke1), 20e18);
    // carol borrows to inflate ex rate
    vm.prank(carol);
    spoke1.borrow(_daiReserveId(spoke1), 20e18, carol);

    skip(365 days);

    // inflated to 1.5
    uint256 addExRateBefore = _getAddExRate(hub1, daiAssetId);
    uint256 exchangeRateBefore = hub1.previewRemoveByShares(daiAssetId, MAX_SUPPLY_AMOUNT);
    assertApproxEqAbs(exchangeRateBefore, 1.5e30, 0.0000001e30);

    _openSupplyPosition(spoke1, _daiReserveId(spoke1), 30);

    // 30% rp
    _updateCollateralRisk(spoke1, _wethReserveId(spoke1), 30_00);

    vm.prank(alice);
    spoke1.borrow(_daiReserveId(spoke1), 15, alice);
    vm.prank(bob);
    spoke1.borrow(_daiReserveId(spoke1), 15, bob);

    _checkSupplyRateIncreasing(addExRateBefore, _getAddExRate(hub1, daiAssetId), 'after borrows');
    addExRateBefore = _getAddExRate(hub1, daiAssetId);

    // alice repays full
    SpokeActions.repay({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: UINT256_MAX,
      onBehalfOf: alice
    });

    _checkSupplyRateIncreasing(
      addExRateBefore,
      _getAddExRate(hub1, daiAssetId),
      'after alice full repay'
    );
  }

  function test_repay_supply_ex_rate_decr_skip_time() public {
    // inflate ex rate to 1.5
    _mockDrawnRateBps({irStrategy: address(irStrategy), drawnRateBps: 50_00});
    _updateCollateralRisk(spoke1, _daiReserveId(spoke1), 0);
    _updateCollateralRisk(spoke1, _wethReserveId(spoke1), 0);
    _updateLiquidityFee(hub1, daiAssetId, 0);

    // enough coll
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: alice,
      amount: 1e18,
      onBehalfOf: alice
    });
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: 1e18,
      onBehalfOf: bob
    });
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: carol,
      amount: 1e18,
      onBehalfOf: carol
    });

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
    SpokeActions.repay({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: UINT256_MAX,
      onBehalfOf: alice
    });

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
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: wethSupplyAmount,
      onBehalfOf: bob
    });

    // Alice supplies DAI
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: daiSupplyAmount,
      onBehalfOf: alice
    });

    // Bob borrows DAI
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: daiBorrowAmount,
      onBehalfOf: bob
    });

    DebtData memory bobDaiDebtBefore = _getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    assertEq(bobDaiDebtBefore.totalDebt, daiBorrowAmount, 'Initial bob dai debt');
    assertEq(_getUserDebt(spoke1, bob, _wethReserveId(spoke1)).totalDebt, 0);

    // Time passes so that interest accrues
    skip(365 days);

    bobDaiDebtBefore = _getUserDebt(spoke1, bob, _daiReserveId(spoke1));
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

    // debt remains unchanged & repay amount is donated (premium was already 0)
    assertEq(_getUserDebt(spoke1, bob, _daiReserveId(spoke1)), bobDaiDebtBefore);
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
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: wethSupplyAmount,
      onBehalfOf: bob
    });

    // Alice supplies DAI
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: daiSupplyAmount,
      onBehalfOf: alice
    });

    // Bob borrows DAI
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: daiBorrowAmount,
      onBehalfOf: bob
    });

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
    emit ISpoke.Repay(_daiReserveId(spoke1), bob, bob, 0, repayAmount, expectedPremiumDelta);

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
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: wethSupplyAmount,
      onBehalfOf: bob
    });

    // Alice supply dai
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: daiSupplyAmount,
      onBehalfOf: alice
    });

    // Bob borrow dai
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: daiBorrowAmount,
      onBehalfOf: bob
    });

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

    DebtData memory bobDaiBefore = _getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    assertGt(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');

    // Bob repays premium
    SpokeActions.repay({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: bobDaiBefore.premiumDebt,
      onBehalfOf: bob
    });

    bobDaiBefore = _getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    // Premium debt can be off by 1 due to rounding
    assertApproxEqAbs(bobDaiBefore.premiumDebt, 0, 1, 'bob dai premium debt after premium repay');

    // Bob repays drawn debt interest
    uint256 daiRepayAmount = bobDaiBefore.drawnDebt - daiBorrowAmount;
    assertGt(daiRepayAmount, 0); // interest is not zero

    {
      (uint256 baseRestored, ) = _calculateExactRestoreAmount(
        hub1,
        daiAssetId,
        bobDaiBefore.drawnDebt,
        bobDaiBefore.premiumDebt,
        daiRepayAmount
      );
      IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
        spoke1,
        bob,
        _daiReserveId(spoke1),
        daiRepayAmount
      );
      vm.expectEmit(address(spoke1));
      emit ISpoke.Repay(
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
    _updateCollateralRisk(spoke1, _wethReserveId(spoke1), 0);

    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;

    // Bob supply weth
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: wethSupplyAmount,
      onBehalfOf: bob
    });

    // Alice supply dai
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: daiSupplyAmount,
      onBehalfOf: alice
    });

    // Bob borrow dai
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: daiBorrowAmount,
      onBehalfOf: bob
    });

    assertEq(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      daiBorrowAmount,
      'bob dai debt before'
    );
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    // Time passes
    skip(10 days);

    DebtData memory bobDaiBefore = _getUserDebt(spoke1, bob, _daiReserveId(spoke1));
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
    emit ISpoke.Repay(
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
