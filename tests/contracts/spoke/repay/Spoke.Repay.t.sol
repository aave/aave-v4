// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract SpokeRepayTest is Base {
  using PercentageMath for uint256;
  using SafeCast for uint256;

  struct RepayMultipleLocal {
    uint256 borrowAmount;
    uint256 repayAmount;
    ISpoke.UserPosition posBefore;
    ISpoke.UserPosition posAfter;
    uint256 baseRestored;
    uint256 premiumRestored;
  }

  function test_repay_revertsWith_ERC20InsufficientAllowance() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;
    uint256 daiRepayAmount = daiSupplyAmount / 4;
    uint256 approvalAmount = daiRepayAmount - 1;

    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: wethSupplyAmount,
      onBehalfOf: bob
    });
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: daiSupplyAmount,
      onBehalfOf: alice
    });
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: daiBorrowAmount,
      onBehalfOf: bob
    });

    vm.startPrank(bob);
    tokenList.dai.approve(address(spoke1), approvalAmount);
    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(spoke1),
        approvalAmount,
        daiRepayAmount
      )
    );
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount, bob);
    vm.stopPrank();
  }

  function test_repay_fuzz_revertsWith_ERC20InsufficientBalance(uint256 daiRepayAmount) public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;
    daiRepayAmount = bound(daiRepayAmount, 1, daiBorrowAmount);

    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: wethSupplyAmount,
      onBehalfOf: bob
    });
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: daiSupplyAmount,
      onBehalfOf: alice
    });
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: daiBorrowAmount,
      onBehalfOf: bob
    });

    vm.startPrank(bob);
    tokenList.dai.transfer(alice, tokenList.dai.balanceOf(bob)); // make bob have insufficient balance

    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientBalance.selector,
        address(bob),
        0,
        daiRepayAmount
      )
    );
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount, bob);
    vm.stopPrank();
  }

  function test_repay_revertsWith_ReentrancyGuardReentrantCall() public {
    uint256 amount = 100e18;

    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: amount * 2,
      onBehalfOf: bob
    });

    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: amount,
      onBehalfOf: bob
    });

    MockReentrantCaller reentrantCaller = new MockReentrantCaller(
      address(spoke1),
      ISpoke.repay.selector
    );
    vm.mockFunction(
      address(_hub(spoke1, _daiReserveId(spoke1))),
      address(reentrantCaller),
      abi.encodeCall(
        IHubBase.restore,
        (
          daiAssetId,
          amount,
          _getExpectedPremiumDeltaForRestore(spoke1, bob, _daiReserveId(spoke1), amount)
        )
      )
    );

    vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), amount, bob);
  }

  function test_repay() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;
    uint256 daiRepayAmount = daiSupplyAmount / 4;

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

    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    // Time passes
    skip(10 days);

    DebtData memory bobDaiBefore = _getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    assertGe(bobDaiBefore.drawnDebt, daiBorrowAmount, 'bob dai debt before');

    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
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
    uint256 expectedShares = hub1.previewRestoreByAssets(daiAssetId, baseRestored);

    // Bob repays half of principal debt
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
      _daiReserveId(spoke1),
      bob,
      bob,
      expectedShares,
      daiRepayAmount,
      expectedPremiumDelta
    );
    _assertRefreshPremiumNotCalled(hub1);

    CheckedRepayResult memory r = _checkedRepay(
      CheckedRepayParams({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        user: bob,
        amount: daiRepayAmount,
        onBehalfOf: bob
      })
    );

    daiRepayAmount = baseRestored + premiumRestored;

    assertEq(r.amount, daiRepayAmount);
    assertEq(r.shares, expectedShares);

    assertEq(r.ownerAfter.suppliedShares, r.ownerBefore.suppliedShares);
    assertApproxEqAbs(
      r.ownerAfter.totalDebt,
      r.ownerBefore.totalDebt - daiRepayAmount,
      2,
      'bob dai debt final balance'
    );

    // weth position unchanged
    UserSnapshot memory bobWethAfter = _snapshotUser(spoke1, _wethReserveId(spoke1), bob);
    assertEq(bobWethAfter.suppliedShares, hub1.previewAddByAssets(wethAssetId, wethSupplyAmount));
    assertEq(
      r.callerAfter.tokenBalance,
      r.callerBefore.tokenBalance - daiRepayAmount,
      'bob dai final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repay');
  }

  function test_repay_all_with_accruals() public {
    uint256 supplyAmount = 5000e18;
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: supplyAmount,
      onBehalfOf: bob
    });

    uint256 borrowAmount = 1000e18;
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });

    skip(365 days);
    spoke1.getUserDebt(_daiReserveId(spoke1), bob);

    _assertRefreshPremiumNotCalled(hub1);
    SpokeActions.repay({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });

    skip(365 days);

    ISpoke.UserPosition memory pos = spoke1.getUserPosition(_daiReserveId(spoke1), bob);
    assertGt(pos.drawnShares, 0, 'user drawnShares after repay');
    assertGt(hub1.previewRestoreByShares(daiAssetId, pos.drawnShares), 0, 'user baseDrawnAssets');

    SpokeActions.repay({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: UINT256_MAX,
      onBehalfOf: bob
    });

    pos = spoke1.getUserPosition(_daiReserveId(spoke1), bob);
    assertEq(pos.drawnShares, 0, 'user drawnShares after full repay');
    assertEq(hub1.previewRestoreByShares(daiAssetId, pos.drawnShares), 0, 'user baseDrawnAssets');
    assertEq(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      0,
      'user total debt after full repay'
    );
    assertFalse(_isBorrowing(spoke1, _daiReserveId(spoke1), bob));

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repay');
  }

  function test_repay_same_block() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;
    uint256 daiRepayAmount = daiSupplyAmount / 4;

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

    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    (uint256 bobDaiDrawnDebtBefore, uint256 bobDaiPremiumDebtBefore) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    assertEq(
      bobDaiDrawnDebtBefore + bobDaiPremiumDebtBefore,
      daiBorrowAmount,
      'bob dai debt before'
    );

    IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
      spoke1,
      bob,
      _daiReserveId(spoke1),
      daiRepayAmount
    );
    (uint256 baseRestored, ) = _calculateExactRestoreAmount(
      hub1,
      daiAssetId,
      bobDaiDrawnDebtBefore,
      bobDaiPremiumDebtBefore,
      daiRepayAmount
    );

    // Bob repays half of principal debt
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
      _daiReserveId(spoke1),
      bob,
      bob,
      hub1.previewRestoreByAssets(daiAssetId, baseRestored),
      daiRepayAmount,
      expectedPremiumDelta
    );
    _assertRefreshPremiumNotCalled(hub1);

    CheckedRepayResult memory r = _checkedRepay(
      CheckedRepayParams({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        user: bob,
        amount: daiRepayAmount,
        onBehalfOf: bob
      })
    );

    assertEq(r.shares, daiRepayAmount);
    assertEq(r.amount, daiRepayAmount);

    assertEq(r.ownerAfter.suppliedShares, r.ownerBefore.suppliedShares);
    assertEq(
      r.ownerAfter.totalDebt,
      r.ownerBefore.totalDebt - daiRepayAmount,
      'bob dai debt final balance'
    );
    assertEq(
      r.callerAfter.tokenBalance,
      r.callerBefore.tokenBalance - daiRepayAmount,
      'bob dai final balance'
    );

    // weth position unchanged
    UserSnapshot memory bobWethAfter = _snapshotUser(spoke1, _wethReserveId(spoke1), bob);
    assertEq(bobWethAfter.suppliedShares, hub1.previewAddByAssets(wethAssetId, wethSupplyAmount));
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repay');
  }

  /// repay all debt interest
  function test_repay_only_interest() public {
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

    // Bob repays interest
    uint256 daiRepayAmount = bobDaiBefore.drawnDebt + bobDaiBefore.premiumDebt - daiBorrowAmount;
    assertGt(daiRepayAmount, 0); // interest is not zero

    uint256 expectedShares;
    {
      (uint256 baseRestored, ) = _calculateExactRestoreAmount(
        hub1,
        daiAssetId,
        bobDaiBefore.drawnDebt,
        bobDaiBefore.premiumDebt,
        daiRepayAmount
      );
      expectedShares = hub1.previewRestoreByAssets(daiAssetId, baseRestored);
    }

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
      expectedShares,
      daiRepayAmount,
      expectedPremiumDelta
    );
    _assertRefreshPremiumNotCalled(hub1);

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
    assertEq(r.shares, expectedShares);

    assertEq(r.ownerAfter.suppliedShares, r.ownerBefore.suppliedShares);
    assertApproxEqAbs(r.ownerAfter.premiumDebt, 0, 1, 'bob dai premium debt final balance');
    assertApproxEqAbs(
      r.ownerAfter.drawnDebt,
      daiBorrowAmount,
      1,
      'bob dai drawn debt final balance'
    );
    assertApproxEqAbs(r.ownerAfter.totalDebt, daiBorrowAmount, 2, 'bob dai debt final balance');
    assertEq(
      r.callerAfter.tokenBalance,
      r.callerBefore.tokenBalance - daiRepayAmount,
      'bob dai final balance'
    );

    // weth position unchanged
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repay');
  }

  /// repay partial or full premium debt, but no drawn debt
  function test_fuzz_repay_only_premium(uint256 daiBorrowAmount, uint40 skipTime) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      daiBorrowAmount
    );
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME).toUint40();

    // Bob supply weth as collateral
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: wethSupplyAmount,
      onBehalfOf: bob
    });

    // Alice supply dai for Bob to borrow
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: daiBorrowAmount,
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
    skip(skipTime);

    (, uint256 bobDaiPremiumDebtBefore) = spoke1.getUserDebt(_daiReserveId(spoke1), bob);
    vm.assume(bobDaiPremiumDebtBefore > 0); // assume time passes enough to accrue premium debt

    // Bob repays any amount of premium debt
    uint256 daiRepayAmount;
    daiRepayAmount = bound(daiRepayAmount, 1, bobDaiPremiumDebtBefore);

    IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
      spoke1,
      bob,
      _daiReserveId(spoke1),
      daiRepayAmount
    );

    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(_daiReserveId(spoke1), bob, bob, 0, daiRepayAmount, expectedPremiumDelta);
    _assertRefreshPremiumNotCalled(hub1);

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
    assertEq(r.shares, 0);

    assertEq(r.ownerAfter.suppliedShares, r.ownerBefore.suppliedShares);
    assertApproxEqAbs(
      r.ownerAfter.totalDebt,
      r.ownerBefore.totalDebt - daiRepayAmount,
      1,
      'bob dai debt final balance'
    );
    assertApproxEqAbs(
      r.ownerAfter.premiumDebt,
      r.ownerBefore.premiumDebt - daiRepayAmount,
      1,
      'bob dai premium debt final balance'
    );

    // weth position unchanged
    UserSnapshot memory bobWethAfter = _snapshotUser(spoke1, _wethReserveId(spoke1), bob);
    assertEq(bobWethAfter.suppliedShares, hub1.previewAddByAssets(wethAssetId, wethSupplyAmount));
    assertEq(bobWethAfter.totalDebt, 0);

    assertEq(
      r.callerAfter.tokenBalance,
      r.callerBefore.tokenBalance - daiRepayAmount,
      'bob dai final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repay');
  }

  function test_repay_max() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;

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

    // Time passes so that interest accrues
    skip(10 days);

    DebtData memory bobDaiBefore = _getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    assertGt(bobDaiBefore.totalDebt, daiBorrowAmount, 'Accrued interest increased bob dai debt');

    uint256 fullDebt = bobDaiBefore.drawnDebt + bobDaiBefore.premiumDebt;
    uint256 expectedShares = hub1.previewRestoreByAssets(daiAssetId, bobDaiBefore.drawnDebt);

    IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
      spoke1,
      bob,
      _daiReserveId(spoke1),
      UINT256_MAX
    );

    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
      _daiReserveId(spoke1),
      bob,
      bob,
      expectedShares,
      fullDebt,
      expectedPremiumDelta
    );
    _assertRefreshPremiumNotCalled(hub1);

    CheckedRepayResult memory r = _checkedRepay(
      CheckedRepayParams({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        user: bob,
        amount: UINT256_MAX,
        onBehalfOf: bob
      })
    );

    assertEq(r.amount, fullDebt);
    assertEq(r.shares, expectedShares);

    // Verify that Bob's debt is fully cleared after repayment
    assertEq(r.ownerAfter.totalDebt, 0, 'Bob dai debt should be cleared');
    assertFalse(_isBorrowing(spoke1, _daiReserveId(spoke1), bob));

    // Verify that his DAI balance was reduced by the full debt amount
    assertEq(
      r.callerAfter.tokenBalance,
      r.callerBefore.tokenBalance - fullDebt,
      'Bob dai balance decreased by full debt repaid'
    );

    // Verify reserve debt is 0
    assertEq(r.reserveAfter.totalDrawnDebt, 0);
    assertEq(r.reserveAfter.totalPremiumDebt, 0);

    // verify LH asset debt is 0
    assertEq(hub1.getAssetTotalOwed(_daiReserveId(spoke1)), 0);

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repay');
  }

  /// repay all or a portion of total debt in same block
  function test_fuzz_repay_same_block_fuzz_amounts(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    daiRepayAmount = bound(daiRepayAmount, 1, daiBorrowAmount);

    // calculate weth collateral
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      daiBorrowAmount
    );

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
      amount: daiBorrowAmount,
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

    DebtData memory bobDaiBefore = _getUserDebt(spoke1, bob, _daiReserveId(spoke1));

    uint256 expectedShares;
    {
      (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
        hub1,
        daiAssetId,
        bobDaiBefore.drawnDebt,
        bobDaiBefore.premiumDebt,
        daiRepayAmount
      );
      expectedShares = hub1.previewRestoreByAssets(daiAssetId, baseRestored);
      daiRepayAmount = baseRestored + premiumRestored;
    }

    {
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
        expectedShares,
        daiRepayAmount,
        expectedPremiumDelta
      );
    }
    _assertRefreshPremiumNotCalled(hub1);

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
    assertEq(r.shares, expectedShares);

    assertEq(r.ownerAfter.suppliedShares, r.ownerBefore.suppliedShares);
    assertEq(
      r.ownerAfter.totalDebt,
      r.ownerBefore.totalDebt - daiRepayAmount,
      'bob dai debt final balance'
    );
    assertEq(
      r.callerAfter.tokenBalance,
      r.callerBefore.tokenBalance - daiRepayAmount,
      'bob dai final balance'
    );

    // weth position unchanged
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repay');

    _repayAll(spoke1, _daiReserveId(spoke1), _defaultUsers());
  }

  /// repay all or a portion of total debt - handles partial drawn debt repay case
  function test_repay_fuzz_amountsAndWait(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount,
    uint40 skipTime
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    daiRepayAmount = bound(daiRepayAmount, 1, daiBorrowAmount);
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME).toUint40();

    // calculate weth collateral
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      daiBorrowAmount
    );

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
      amount: daiBorrowAmount,
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
    skip(skipTime);

    DebtData memory bobDaiBefore = _getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    assertGe(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');

    // Calculate minimum repay amount
    if (hub1.previewRestoreByAssets(daiAssetId, daiRepayAmount) == 0) {
      daiRepayAmount = hub1.previewRestoreByShares(daiAssetId, 1);
    }

    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      hub1,
      daiAssetId,
      bobDaiBefore.drawnDebt,
      bobDaiBefore.premiumDebt,
      daiRepayAmount
    );

    {
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
    _assertRefreshPremiumNotCalled(hub1);

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
    assertEq(r.shares, hub1.previewRestoreByAssets(daiAssetId, baseRestored));

    assertEq(r.ownerAfter.suppliedShares, r.ownerBefore.suppliedShares);
    assertApproxEqAbs(
      r.ownerAfter.totalDebt,
      r.ownerBefore.totalDebt - baseRestored - premiumRestored,
      2,
      'bob dai debt final balance'
    );

    // If any drawn debt was repaid, then premium debt must be zero, or one
    if (baseRestored > 0) {
      assertApproxEqAbs(
        r.ownerAfter.premiumDebt,
        0,
        1,
        'bob dai premium debt final balance when base repaid'
      );
    }

    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);
    assertEq(
      r.callerAfter.tokenBalance,
      r.callerBefore.tokenBalance - daiRepayAmount,
      'bob dai final balance'
    );
    assertGe(daiRepayAmount, baseRestored + premiumRestored); // excess amount donated
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repay');

    _repayAll(spoke1, _daiReserveId(spoke1), _defaultUsers());
  }

  /// repay all or a portion of debt interest
  function test_fuzz_repay_amounts_only_interest(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount,
    uint40 skipTime
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME).toUint40();

    // calculate weth collateral
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      daiBorrowAmount
    );

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
      amount: daiBorrowAmount,
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

    assertEq(_getUserInfo(spoke1, bob, _daiReserveId(spoke1)).suppliedShares, 0);
    assertEq(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      daiBorrowAmount,
      'bob dai debt before'
    );
    assertEq(
      _getUserInfo(spoke1, bob, _wethReserveId(spoke1)).suppliedShares,
      hub1.previewAddByAssets(wethAssetId, wethSupplyAmount)
    );
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    // Time passes
    skip(skipTime);

    DebtData memory bobDaiBefore = _getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    assertGe(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');

    // Bob repays
    // bobDaiInterest = bobDaiBefore.totalDebt - daiBorrowAmount
    daiRepayAmount = bound(daiRepayAmount, 0, bobDaiBefore.totalDebt - daiBorrowAmount);

    if (daiRepayAmount == 0) {
      vm.expectRevert(IHub.InvalidAmount.selector);
      vm.prank(bob);
      spoke1.repay(_daiReserveId(spoke1), daiRepayAmount, bob);
      return;
    }

    (uint256 baseRestored, ) = _calculateExactRestoreAmount(
      hub1,
      daiAssetId,
      bobDaiBefore.drawnDebt,
      bobDaiBefore.premiumDebt,
      daiRepayAmount
    );
    deal(address(tokenList.dai), bob, daiRepayAmount);

    {
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
    _assertRefreshPremiumNotCalled(hub1);

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
    assertEq(r.shares, hub1.previewRestoreByAssets(daiAssetId, baseRestored));

    assertEq(r.ownerAfter.suppliedShares, r.ownerBefore.suppliedShares);
    assertApproxEqAbs(
      r.ownerAfter.totalDebt,
      r.ownerBefore.totalDebt - (r.baseRestored + r.premiumRestored),
      2,
      'bob dai debt final balance'
    );

    // weth position unchanged
    UserSnapshot memory bobWethAfter = _snapshotUser(spoke1, _wethReserveId(spoke1), bob);
    assertEq(bobWethAfter.suppliedShares, hub1.previewAddByAssets(wethAssetId, wethSupplyAmount));
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    assertEq(tokenList.dai.balanceOf(bob), 0, 'bob dai final balance');
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

    // repays only interest
    // it can be equal because of 1 wei rounding issue when repaying
    assertGe(r.ownerAfter.totalDebt, daiBorrowAmount);

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repay');
  }

  /// repay all or a portion of premium debt
  function test_fuzz_amounts_repay_only_premium(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount,
    uint40 skipTime
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME).toUint40();

    // calculate weth collateral
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      daiBorrowAmount
    );

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
      amount: daiBorrowAmount,
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

    assertEq(_getUserInfo(spoke1, bob, _daiReserveId(spoke1)).suppliedShares, 0);
    assertEq(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      daiBorrowAmount,
      'bob dai debt before'
    );
    assertEq(
      _getUserInfo(spoke1, bob, _wethReserveId(spoke1)).suppliedShares,
      hub1.previewAddByAssets(wethAssetId, wethSupplyAmount)
    );
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    // Time passes
    skip(skipTime);

    DebtData memory bobDaiBefore = _getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    assertGe(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');

    // Bob repays
    uint256 bobDaiPremium = bobDaiBefore.premiumDebt;
    if (bobDaiPremium == 0) {
      // not enough time travel for premium accrual
      vm.expectRevert(IHub.InvalidAmount.selector);
      vm.prank(bob);
      spoke1.repay(_daiReserveId(spoke1), 0, bob);
      return;
    }

    // interest is at least 1
    daiRepayAmount = bound(daiRepayAmount, 1, bobDaiPremium);
    deal(address(tokenList.dai), bob, daiRepayAmount);

    {
      IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
        spoke1,
        bob,
        _daiReserveId(spoke1),
        daiRepayAmount
      );
      vm.expectEmit(address(spoke1));
      emit ISpoke.Repay(_daiReserveId(spoke1), bob, bob, 0, daiRepayAmount, expectedPremiumDelta);
    }
    _assertRefreshPremiumNotCalled(hub1);

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
    assertEq(r.shares, 0);

    assertEq(r.ownerAfter.suppliedShares, r.ownerBefore.suppliedShares);
    assertEq(r.ownerAfter.drawnDebt, r.ownerBefore.drawnDebt, 'bob dai drawn debt final balance');
    assertApproxEqAbs(
      r.ownerAfter.premiumDebt,
      r.ownerBefore.premiumDebt - r.premiumRestored,
      1,
      'bob dai premium debt final balance'
    );
    assertApproxEqAbs(
      r.ownerAfter.totalDebt,
      r.ownerBefore.totalDebt - r.premiumRestored,
      1,
      'bob dai debt final balance'
    );

    // weth position unchanged
    UserSnapshot memory bobWethAfter = _snapshotUser(spoke1, _wethReserveId(spoke1), bob);
    assertEq(bobWethAfter.suppliedShares, hub1.previewAddByAssets(wethAssetId, wethSupplyAmount));
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    assertEq(tokenList.dai.balanceOf(bob), 0, 'bob dai final balance');
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

    // repays only premium
    assertGe(r.ownerAfter.premiumDebt, 0);

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repay');
  }

  /// repay all or a portion of accrued drawn debt when premium debt is already repaid
  function test_repay_fuzz_amounts_base_debt(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount,
    uint40 skipTime
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME).toUint40();

    // calculate weth collateral
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      daiBorrowAmount
    );

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
      amount: daiBorrowAmount,
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

    assertEq(_getUserInfo(spoke1, bob, _daiReserveId(spoke1)).suppliedShares, 0);
    assertEq(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      daiBorrowAmount,
      'bob dai debt before'
    );
    assertEq(
      _getUserInfo(spoke1, bob, _wethReserveId(spoke1)).suppliedShares,
      hub1.previewAddByAssets(wethAssetId, wethSupplyAmount)
    );
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    // Time passes
    skip(skipTime);

    DebtData memory bobDaiBefore = _getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    assertGe(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');

    // Bob repays premium first if any
    if (bobDaiBefore.premiumDebt > 0) {
      deal(address(tokenList.dai), bob, bobDaiBefore.premiumDebt);
      SpokeActions.repay({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        caller: bob,
        amount: bobDaiBefore.premiumDebt,
        onBehalfOf: bob
      });
    }

    bobDaiBefore = _getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    assertApproxEqAbs(bobDaiBefore.premiumDebt, 0, 1);

    // Bob repays
    daiRepayAmount = bound(daiRepayAmount, 0, bobDaiBefore.totalDebt - daiBorrowAmount);

    if (daiRepayAmount == 0) {
      vm.expectRevert(IHub.InvalidAmount.selector);
      vm.prank(bob);
      spoke1.repay(_daiReserveId(spoke1), daiRepayAmount, bob);
      return;
    }

    (uint256 baseRestored, ) = _calculateExactRestoreAmount(
      hub1,
      daiAssetId,
      bobDaiBefore.drawnDebt,
      bobDaiBefore.premiumDebt,
      daiRepayAmount
    );
    deal(address(tokenList.dai), bob, daiRepayAmount);

    {
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
    _assertRefreshPremiumNotCalled(hub1);

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
    assertEq(r.shares, hub1.previewRestoreByAssets(daiAssetId, baseRestored));

    assertEq(r.ownerAfter.suppliedShares, r.ownerBefore.suppliedShares);
    assertApproxEqAbs(r.ownerAfter.premiumDebt, 0, 1, 'bob dai premium debt final balance');
    assertApproxEqAbs(
      r.ownerAfter.totalDebt,
      r.ownerBefore.totalDebt - (r.baseRestored + r.premiumRestored),
      2,
      'bob dai debt final balance'
    );
    // repays only drawn debt
    assertApproxEqAbs(
      r.ownerAfter.drawnDebt,
      r.ownerBefore.drawnDebt - r.baseRestored,
      1,
      'bob dai drawn debt final balance'
    );

    // weth position unchanged
    UserSnapshot memory bobWethAfter = _snapshotUser(spoke1, _wethReserveId(spoke1), bob);
    assertEq(bobWethAfter.suppliedShares, hub1.previewAddByAssets(wethAssetId, wethSupplyAmount));
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);
    assertEq(tokenList.dai.balanceOf(bob), 0, 'bob dai final balance');

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repay');
  }

  /// repay all or a portion of accrued drawn debt when premium debt is zero
  function test_repay_fuzz_amounts_base_debt_no_premium(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount,
    uint40 skipTime
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME).toUint40();

    // update collateral risk to zero
    _updateCollateralRisk(spoke1, _wethReserveId(spoke1), 0);

    // calculate weth collateral
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      daiBorrowAmount
    );

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
      amount: daiBorrowAmount,
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

    assertEq(_getUserInfo(spoke1, bob, _daiReserveId(spoke1)).suppliedShares, 0);
    assertEq(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      daiBorrowAmount,
      'bob dai debt before'
    );
    assertEq(
      _getUserInfo(spoke1, bob, _wethReserveId(spoke1)).suppliedShares,
      hub1.previewAddByAssets(wethAssetId, wethSupplyAmount)
    );
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    // Time passes
    skip(skipTime);

    DebtData memory bobDaiBefore = _getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    assertGe(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');
    assertEq(bobDaiBefore.premiumDebt, 0, 'bob dai premium debt before');

    // Bob repays
    uint256 bobDaiDrawnDebt = bobDaiBefore.drawnDebt - daiBorrowAmount;
    daiRepayAmount = bound(daiRepayAmount, 0, bobDaiDrawnDebt);

    if (daiRepayAmount == 0) {
      vm.expectRevert(IHub.InvalidAmount.selector);
      vm.prank(bob);
      spoke1.repay(_daiReserveId(spoke1), daiRepayAmount, bob);
      return;
    }

    uint256 baseRestored;
    {
      (baseRestored, ) = _calculateExactRestoreAmount(
        hub1,
        daiAssetId,
        bobDaiDrawnDebt,
        0,
        daiRepayAmount
      );
    }
    deal(address(tokenList.dai), bob, daiRepayAmount);

    {
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
    _assertRefreshPremiumNotCalled(hub1);

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
    assertEq(r.shares, hub1.previewRestoreByAssets(daiAssetId, baseRestored));

    assertEq(r.ownerAfter.suppliedShares, r.ownerBefore.suppliedShares);
    assertApproxEqAbs(
      r.ownerAfter.drawnDebt,
      r.ownerBefore.drawnDebt - r.baseRestored,
      1,
      'bob dai drawn debt final balance'
    );
    assertEq(r.ownerAfter.premiumDebt, 0, 'bob dai premium debt final balance');
    assertApproxEqAbs(
      r.ownerAfter.totalDebt,
      r.ownerBefore.totalDebt - (r.baseRestored + r.premiumRestored),
      1,
      'bob dai debt final balance'
    );

    // weth position unchanged
    UserSnapshot memory bobWethAfter = _snapshotUser(spoke1, _wethReserveId(spoke1), bob);
    assertEq(bobWethAfter.suppliedShares, hub1.previewAddByAssets(wethAssetId, wethSupplyAmount));
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    assertEq(tokenList.dai.balanceOf(bob), 0, 'bob dai final balance');
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

    // repays only drawn debt
    assertGe(
      r.ownerAfter.drawnDebt,
      r.ownerBefore.drawnDebt - daiRepayAmount,
      'bob dai drawn debt final balance'
    );

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repay');
  }

  /// borrow and repay multiple reserves
  function test_repay_multiple_reserves_fuzz_amountsAndWait(
    uint256 daiBorrowAmount,
    uint256 wethBorrowAmount,
    uint256 usdxBorrowAmount,
    uint256 wbtcBorrowAmount,
    uint256 repayPortion,
    uint40 skipTime
  ) public {
    RepayMultipleLocal memory daiInfo;
    RepayMultipleLocal memory wethInfo;
    RepayMultipleLocal memory usdxInfo;
    RepayMultipleLocal memory wbtcInfo;

    daiInfo.borrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT_DAI / 2);
    wethInfo.borrowAmount = bound(wethBorrowAmount, 1, MAX_SUPPLY_AMOUNT_WETH / 2);
    usdxInfo.borrowAmount = bound(usdxBorrowAmount, 1, MAX_SUPPLY_AMOUNT_USDX / 2);
    wbtcInfo.borrowAmount = bound(wbtcBorrowAmount, 1, MAX_SUPPLY_AMOUNT_WBTC / 2);
    repayPortion = bound(repayPortion, 0, PercentageMath.PERCENTAGE_FACTOR);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME).toUint40();

    daiInfo.repayAmount = daiInfo.borrowAmount.percentMulUp(repayPortion);
    wethInfo.repayAmount = wethInfo.borrowAmount.percentMulUp(repayPortion);
    usdxInfo.repayAmount = usdxInfo.borrowAmount.percentMulUp(repayPortion);
    wbtcInfo.repayAmount = wbtcInfo.borrowAmount.percentMulUp(repayPortion);

    // weth collateral for dai
    // wbtc collateral for usdx, weth and wbtc
    // calculate weth collateral
    // calculate wbtc collateral
    {
      uint256 wethSupplyAmount = _calcMinimumCollAmount(
        spoke1,
        _wethReserveId(spoke1),
        _daiReserveId(spoke1),
        daiInfo.borrowAmount
      );
      uint256 wbtcSupplyAmount = _calcMinimumCollAmount(
        spoke1,
        _wbtcReserveId(spoke1),
        _wethReserveId(spoke1),
        wethInfo.borrowAmount
      ) +
        _calcMinimumCollAmount(
          spoke1,
          _wbtcReserveId(spoke1),
          _wbtcReserveId(spoke1),
          wbtcInfo.borrowAmount
        ) +
        _calcMinimumCollAmount(
          spoke1,
          _wbtcReserveId(spoke1),
          _usdxReserveId(spoke1),
          usdxInfo.borrowAmount
        );

      // Bob supply weth and wbtc
      deal(address(tokenList.weth), bob, wethSupplyAmount);
      SpokeActions.supplyCollateral({
        spoke: spoke1,
        reserveId: _wethReserveId(spoke1),
        caller: bob,
        amount: wethSupplyAmount,
        onBehalfOf: bob
      });
      deal(address(tokenList.wbtc), bob, wbtcSupplyAmount);
      SpokeActions.supplyCollateral({
        spoke: spoke1,
        reserveId: _wbtcReserveId(spoke1),
        caller: bob,
        amount: wbtcSupplyAmount,
        onBehalfOf: bob
      });
    }

    // Alice supply liquidity
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: daiInfo.borrowAmount,
      onBehalfOf: alice
    });
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: alice,
      amount: wethInfo.borrowAmount,
      onBehalfOf: alice
    });
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _usdxReserveId(spoke1),
      caller: alice,
      amount: usdxInfo.borrowAmount,
      onBehalfOf: alice
    });
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _wbtcReserveId(spoke1),
      caller: alice,
      amount: wbtcInfo.borrowAmount,
      onBehalfOf: alice
    });

    // Bob borrows
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: daiInfo.borrowAmount,
      onBehalfOf: bob
    });
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: wethInfo.borrowAmount,
      onBehalfOf: bob
    });
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _usdxReserveId(spoke1),
      caller: bob,
      amount: usdxInfo.borrowAmount,
      onBehalfOf: bob
    });
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _wbtcReserveId(spoke1),
      caller: bob,
      amount: wbtcInfo.borrowAmount,
      onBehalfOf: bob
    });

    daiInfo.posBefore = _getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    wethInfo.posBefore = _getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    usdxInfo.posBefore = _getUserInfo(spoke1, bob, _usdxReserveId(spoke1));
    wbtcInfo.posBefore = _getUserInfo(spoke1, bob, _wbtcReserveId(spoke1));

    DebtData memory bobDaiBefore = _getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    DebtData memory bobWethBefore = _getUserDebt(spoke1, bob, _wethReserveId(spoke1));
    DebtData memory bobUsdxBefore = _getUserDebt(spoke1, bob, _usdxReserveId(spoke1));
    DebtData memory bobWbtcBefore = _getUserDebt(spoke1, bob, _wbtcReserveId(spoke1));

    assertEq(bobDaiBefore.totalDebt, daiInfo.borrowAmount);
    assertEq(bobWethBefore.totalDebt, wethInfo.borrowAmount);
    assertEq(bobWbtcBefore.totalDebt, wbtcInfo.borrowAmount);
    assertEq(bobUsdxBefore.totalDebt, usdxInfo.borrowAmount);

    // Time passes
    skip(skipTime);
    _assertRefreshPremiumNotCalled(hub1);

    // Repayments
    daiInfo.posBefore = _getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore = _getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    assertGe(bobDaiBefore.totalDebt, daiInfo.borrowAmount);
    if (daiInfo.repayAmount > 0) {
      (daiInfo.baseRestored, daiInfo.premiumRestored) = _calculateExactRestoreAmount(
        hub1,
        daiAssetId,
        bobDaiBefore.drawnDebt,
        bobDaiBefore.premiumDebt,
        daiInfo.repayAmount
      );
      deal(address(tokenList.dai), bob, daiInfo.repayAmount);
      SpokeActions.repay({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        caller: bob,
        amount: daiInfo.repayAmount,
        onBehalfOf: bob
      });
    }
    DebtData memory bobDaiAfter = _getUserDebt(spoke1, bob, _daiReserveId(spoke1));

    wethInfo.posBefore = _getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    bobWethBefore = _getUserDebt(spoke1, bob, _wethReserveId(spoke1));
    assertGe(bobWethBefore.totalDebt, wethInfo.borrowAmount);
    if (wethInfo.repayAmount > 0) {
      (wethInfo.baseRestored, wethInfo.premiumRestored) = _calculateExactRestoreAmount(
        hub1,
        wethAssetId,
        bobWethBefore.drawnDebt,
        bobWethBefore.premiumDebt,
        wethInfo.repayAmount
      );
      deal(address(tokenList.weth), bob, wethInfo.repayAmount);
      SpokeActions.repay({
        spoke: spoke1,
        reserveId: _wethReserveId(spoke1),
        caller: bob,
        amount: wethInfo.repayAmount,
        onBehalfOf: bob
      });
    }
    DebtData memory bobWethAfter = _getUserDebt(spoke1, bob, _wethReserveId(spoke1));

    wbtcInfo.posBefore = _getUserInfo(spoke1, bob, _wbtcReserveId(spoke1));
    bobWbtcBefore = _getUserDebt(spoke1, bob, _wbtcReserveId(spoke1));
    assertGe(bobWbtcBefore.totalDebt, wbtcInfo.borrowAmount);
    if (wbtcInfo.repayAmount > 0) {
      (wbtcInfo.baseRestored, wbtcInfo.premiumRestored) = _calculateExactRestoreAmount(
        hub1,
        wbtcAssetId,
        bobWbtcBefore.drawnDebt,
        bobWbtcBefore.premiumDebt,
        wbtcInfo.repayAmount
      );
      deal(address(tokenList.wbtc), bob, wbtcInfo.repayAmount);
      SpokeActions.repay({
        spoke: spoke1,
        reserveId: _wbtcReserveId(spoke1),
        caller: bob,
        amount: wbtcInfo.repayAmount,
        onBehalfOf: bob
      });
    }
    DebtData memory bobWbtcAfter = _getUserDebt(spoke1, bob, _wbtcReserveId(spoke1));

    usdxInfo.posBefore = _getUserInfo(spoke1, bob, _usdxReserveId(spoke1));
    bobUsdxBefore = _getUserDebt(spoke1, bob, _usdxReserveId(spoke1));
    assertGe(bobUsdxBefore.totalDebt, usdxInfo.borrowAmount);
    if (usdxInfo.repayAmount > 0) {
      (usdxInfo.baseRestored, usdxInfo.premiumRestored) = _calculateExactRestoreAmount(
        hub1,
        usdxAssetId,
        bobUsdxBefore.drawnDebt,
        bobUsdxBefore.premiumDebt,
        usdxInfo.repayAmount
      );
      deal(address(tokenList.usdx), bob, usdxInfo.repayAmount);
      SpokeActions.repay({
        spoke: spoke1,
        reserveId: _usdxReserveId(spoke1),
        caller: bob,
        amount: usdxInfo.repayAmount,
        onBehalfOf: bob
      });
    }
    DebtData memory bobUsdxAfter = _getUserDebt(spoke1, bob, _usdxReserveId(spoke1));

    daiInfo.posAfter = _getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    wethInfo.posAfter = _getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    usdxInfo.posAfter = _getUserInfo(spoke1, bob, _usdxReserveId(spoke1));
    wbtcInfo.posAfter = _getUserInfo(spoke1, bob, _wbtcReserveId(spoke1));

    // collateral remains the same
    assertEq(daiInfo.posAfter.suppliedShares, daiInfo.posBefore.suppliedShares);
    assertEq(wethInfo.posAfter.suppliedShares, wethInfo.posBefore.suppliedShares);
    assertEq(usdxInfo.posAfter.suppliedShares, usdxInfo.posBefore.suppliedShares);
    assertEq(wbtcInfo.posAfter.suppliedShares, wbtcInfo.posBefore.suppliedShares);

    // debt
    if (daiInfo.repayAmount > 0) {
      assertApproxEqAbs(
        bobDaiAfter.drawnDebt,
        bobDaiBefore.drawnDebt - daiInfo.baseRestored,
        1,
        'bob dai drawn debt final balance'
      );
      assertApproxEqAbs(
        bobDaiAfter.premiumDebt,
        bobDaiBefore.premiumDebt - daiInfo.premiumRestored,
        1,
        'bob dai premium debt final balance'
      );
    } else {
      assertEq(bobDaiAfter.totalDebt, bobDaiBefore.totalDebt);
    }
    if (wethInfo.repayAmount > 0) {
      assertApproxEqAbs(
        bobWethAfter.drawnDebt,
        bobWethBefore.drawnDebt - wethInfo.baseRestored,
        1,
        'bob weth drawn debt final balance'
      );
      assertApproxEqAbs(
        bobWethAfter.premiumDebt,
        wethInfo.premiumRestored >= bobWethBefore.premiumDebt
          ? 0
          : bobWethBefore.premiumDebt - wethInfo.premiumRestored,
        1,
        'bob weth premium debt final balance'
      );
    } else {
      assertEq(bobWethAfter.totalDebt, bobWethBefore.totalDebt);
    }
    if (usdxInfo.repayAmount > 0) {
      assertApproxEqAbs(
        bobUsdxAfter.drawnDebt,
        usdxInfo.baseRestored >= bobUsdxBefore.drawnDebt
          ? 0
          : bobUsdxBefore.drawnDebt - usdxInfo.baseRestored,
        1,
        'bob usdx drawn debt final balance'
      );
      assertApproxEqAbs(
        bobUsdxAfter.premiumDebt,
        bobUsdxBefore.premiumDebt - usdxInfo.premiumRestored,
        1,
        'bob usdx premium debt final balance'
      );
    } else {
      assertEq(bobUsdxAfter.totalDebt, bobUsdxBefore.totalDebt);
    }
    if (wbtcInfo.repayAmount > 0) {
      assertApproxEqAbs(
        bobWbtcAfter.drawnDebt,
        wbtcInfo.baseRestored >= bobWbtcBefore.drawnDebt
          ? 0
          : bobWbtcBefore.drawnDebt - wbtcInfo.baseRestored,
        1,
        'bob wbtc drawn debt final balance'
      );
      assertApproxEqAbs(
        bobWbtcAfter.premiumDebt,
        wbtcInfo.premiumRestored >= bobWbtcBefore.premiumDebt
          ? 0
          : bobWbtcBefore.premiumDebt - wbtcInfo.premiumRestored,
        1,
        'bob wbtc premium debt final balance'
      );
    } else {
      assertEq(bobWbtcAfter.totalDebt, bobWbtcBefore.totalDebt);
    }

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repay');
    _assertHubLiquidity(hub1, wethAssetId, 'spoke1.repay');
    _assertHubLiquidity(hub1, usdxAssetId, 'spoke1.repay');
    _assertHubLiquidity(hub1, wbtcAssetId, 'spoke1.repay');

    _repayAll(spoke1, _daiReserveId(spoke1), _defaultUsers());
    _repayAll(spoke1, _wethReserveId(spoke1), _defaultUsers());
    _repayAll(spoke1, _usdxReserveId(spoke1), _defaultUsers());
    _repayAll(spoke1, _wbtcReserveId(spoke1), _defaultUsers());
  }

  // Borrow X amount, receive Y Shares. Repay all, ensure Y shares repaid
  function test_fuzz_repay_x_y_shares(uint256 borrowAmount, uint40 skipTime) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 10);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME).toUint40();

    // calculate weth collateral
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      borrowAmount
    );

    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);

    // Bob supply weth
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
      amount: borrowAmount,
      onBehalfOf: alice
    });

    uint256 expectedDrawnShares = hub1.previewRestoreByAssets(daiAssetId, borrowAmount);

    // Bob borrow dai
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });

    ISpoke.UserPosition memory bobDaiDataBefore = _getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    assertEq(bobDaiDataBefore.drawnShares, expectedDrawnShares, 'bob drawn shares');
    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore + borrowAmount,
      'bob dai balance after borrow'
    );

    // Time passes
    skip(skipTime);

    // Bob should still have same number of drawn shares
    assertEq(
      spoke1.getUserPosition(_daiReserveId(spoke1), bob).drawnShares,
      expectedDrawnShares,
      'bob drawn shares after time passed'
    );
    // Bob's debt might have grown or stayed the same
    assertGe(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      borrowAmount,
      'bob total debt after time passed'
    );

    // Bob repays all
    (uint256 baseDebt, uint256 premiumDebt) = spoke1.getUserDebt(_daiReserveId(spoke1), bob);

    IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
      spoke1,
      bob,
      _daiReserveId(spoke1),
      UINT256_MAX
    );

    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
      _daiReserveId(spoke1),
      bob,
      bob,
      hub1.previewRestoreByAssets(daiAssetId, baseDebt),
      baseDebt + premiumDebt,
      expectedPremiumDelta
    );
    _assertRefreshPremiumNotCalled(hub1);

    CheckedRepayResult memory r = _checkedRepay(
      CheckedRepayParams({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        user: bob,
        amount: UINT256_MAX,
        onBehalfOf: bob
      })
    );

    assertEq(r.amount, baseDebt + premiumDebt);
    assertEq(r.shares, expectedDrawnShares);

    // Bob should have 0 drawn shares
    assertEq(r.ownerAfter.position.drawnShares, 0, 'bob drawn shares after repay');
    // Bob's debt should be 0
    assertEq(r.ownerAfter.totalDebt, 0, 'bob total debt after repay');
    // Bob's debt change vs the amount repaid
    assertEq(
      stdMath.delta(r.ownerAfter.totalDebt, r.ownerBefore.totalDebt),
      stdMath.delta(r.callerAfter.tokenBalance, r.callerBefore.tokenBalance),
      'bob balance vs debt change'
    );
    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repay');
  }
}
