// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeRepaySkimmedTest is SpokeBase {
  using PercentageMath for uint256;
  using SafeCast for uint256;
  using ReserveFlagsMap for ReserveFlags;

  function test_repaySkimmed_revertsWith_Unauthorized() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;
    uint256 daiRepayAmount = daiSupplyAmount / 4;

    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    deal(address(tokenList.dai), carol, daiRepayAmount);
    vm.prank(carol);
    tokenList.dai.transfer(address(hub1), daiRepayAmount);

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(carol);
    spoke1.repaySkimmed(_daiReserveId(spoke1), daiRepayAmount, bob);
  }

  function test_repaySkimmed_revertsWith_ReserveNotListed() public {
    uint256 reserveId = spoke1.getReserveCount() + 1;
    uint256 amount = 100e18;

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(bob);
    spoke1.repaySkimmed(reserveId, amount, bob);
  }

  function test_repaySkimmed_revertsWith_ReservePaused() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;
    uint256 daiRepayAmount = daiSupplyAmount / 4;

    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    _updateReservePausedFlag(spoke1, _daiReserveId(spoke1), true);
    assertTrue(spoke1.getReserve(_daiReserveId(spoke1)).flags.paused());

    vm.expectRevert(ISpoke.ReservePaused.selector);
    vm.prank(bob);
    spoke1.repaySkimmed(_daiReserveId(spoke1), daiRepayAmount, bob);
  }

  function test_repaySkimmed_revertsWith_InsufficientTransferred() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;
    uint256 daiRepayAmount = daiSupplyAmount / 4;

    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    vm.expectRevert(abi.encodeWithSelector(IHub.InsufficientTransferred.selector, daiRepayAmount));
    vm.prank(bob);
    spoke1.repaySkimmed(_daiReserveId(spoke1), daiRepayAmount, bob);
  }

  function test_repaySkimmed_revertsWith_ReentrancyGuardReentrantCall() public {
    uint256 amount = 100e18;

    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: amount * 2,
      onBehalfOf: bob
    });

    Utils.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: amount,
      onBehalfOf: bob
    });

    MockReentrantCaller reentrantCaller = new MockReentrantCaller(
      address(spoke1),
      ISpokeBase.repaySkimmed.selector
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
    spoke1.repaySkimmed(_daiReserveId(spoke1), amount, bob);
  }

  function test_repaySkimmed() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;
    uint256 daiRepayAmount = daiSupplyAmount / 4;

    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    ISpoke.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    ISpoke.UserPosition memory bobWethDataBefore = getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    Debts memory bobDaiBefore;
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);

    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');
    assertEq(
      bobWethDataBefore.suppliedShares,
      hub1.previewAddByAssets(wethAssetId, wethSupplyAmount)
    );

    skip(10 days);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));

    assertGe(bobDaiBefore.drawnDebt, daiBorrowAmount, 'bob dai debt before');
    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      bobDaiBefore.drawnDebt,
      bobDaiBefore.premiumDebt,
      daiRepayAmount,
      daiAssetId
    );

    IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
      spoke1,
      bob,
      _daiReserveId(spoke1),
      daiRepayAmount
    );

    uint256 expectedShares = hub1.previewRestoreByAssets(daiAssetId, baseRestored);

    vm.prank(bob);
    tokenList.dai.transfer(address(hub1), daiRepayAmount);

    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Repay(
      _daiReserveId(spoke1),
      bob,
      bob,
      expectedShares,
      daiRepayAmount,
      expectedPremiumDelta
    );
    _assertRefreshPremiumNotCalled();
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = spoke1.repaySkimmed(
      _daiReserveId(spoke1),
      daiRepayAmount,
      bob
    );

    ISpoke.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    ISpoke.UserPosition memory bobWethDataAfter = getUserInfo(spoke1, bob, _wethReserveId(spoke1));

    daiRepayAmount = baseRestored + premiumRestored;

    assertEq(returnValues.amount, daiRepayAmount);
    assertEq(returnValues.shares, expectedShares);

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertApproxEqAbs(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      bobDaiBefore.drawnDebt + bobDaiBefore.premiumDebt - daiRepayAmount,
      2,
      'bob dai debt final balance'
    );
    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);

    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - daiRepayAmount,
      'bob dai final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repaySkimmed');
  }

  function test_repaySkimmed_all_with_accruals() public {
    uint256 supplyAmount = 5000e18;
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, supplyAmount, bob);

    uint256 borrowAmount = 1000e18;
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, borrowAmount, bob);

    skip(365 days);
    spoke1.getUserDebt(_daiReserveId(spoke1), bob);

    uint256 totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    deal(address(tokenList.dai), bob, totalDebt);
    vm.prank(bob);
    tokenList.dai.transfer(address(hub1), totalDebt);

    _assertRefreshPremiumNotCalled();
    vm.prank(bob);
    spoke1.repaySkimmed(_daiReserveId(spoke1), UINT256_MAX, bob);

    ISpoke.UserPosition memory pos = spoke1.getUserPosition(_daiReserveId(spoke1), bob);
    assertEq(pos.drawnShares, 0, 'user drawnShares after full repay');
    assertEq(hub1.previewRestoreByShares(daiAssetId, pos.drawnShares), 0, 'user baseDrawnAssets');
    assertEq(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      0,
      'user total debt after full repay'
    );
    assertFalse(_isBorrowing(spoke1, _daiReserveId(spoke1), bob));

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repaySkimmed');
  }

  function test_repaySkimmed_same_block() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;
    uint256 daiRepayAmount = daiSupplyAmount / 4;

    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    ISpoke.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    ISpoke.UserPosition memory bobWethDataBefore = getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);
    (uint256 bobDaiDrawnDebtBefore, uint256 bobDaiPremiumDebtBefore) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );

    IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
      spoke1,
      bob,
      _daiReserveId(spoke1),
      daiRepayAmount
    );

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(
      bobDaiDrawnDebtBefore + bobDaiPremiumDebtBefore,
      daiBorrowAmount,
      'bob dai debt before'
    );
    assertEq(
      bobWethDataBefore.suppliedShares,
      hub1.previewAddByAssets(wethAssetId, wethSupplyAmount)
    );

    (uint256 baseRestored, ) = _calculateExactRestoreAmount(
      bobDaiDrawnDebtBefore,
      bobDaiPremiumDebtBefore,
      daiRepayAmount,
      daiAssetId
    );

    vm.prank(bob);
    tokenList.dai.transfer(address(hub1), daiRepayAmount);

    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Repay(
      _daiReserveId(spoke1),
      bob,
      bob,
      hub1.previewRestoreByAssets(daiAssetId, baseRestored),
      daiRepayAmount,
      expectedPremiumDelta
    );
    _assertRefreshPremiumNotCalled();
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = spoke1.repaySkimmed(
      _daiReserveId(spoke1),
      daiRepayAmount,
      bob
    );

    ISpoke.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    ISpoke.UserPosition memory bobWethDataAfter = getUserInfo(spoke1, bob, _wethReserveId(spoke1));

    assertEq(returnValues.shares, daiRepayAmount);
    assertEq(returnValues.amount, daiRepayAmount);

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      bobDaiDrawnDebtBefore + bobDaiPremiumDebtBefore - daiRepayAmount,
      'bob dai debt final balance'
    );
    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);

    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - daiRepayAmount,
      'bob dai final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repaySkimmed');
  }

  function test_repaySkimmed_max() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;

    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    ISpoke.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    Debts memory bobDaiBefore;
    Debts memory bobWethBefore;
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.drawnDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    bobWethBefore.totalDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiBefore.totalDebt, daiBorrowAmount, 'Initial bob dai debt');

    skip(10 days);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.drawnDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    assertGt(bobDaiBefore.totalDebt, daiBorrowAmount, 'Accrued interest increased bob dai debt');

    uint256 fullDebt = bobDaiBefore.drawnDebt + bobDaiBefore.premiumDebt;

    IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
      spoke1,
      bob,
      _daiReserveId(spoke1),
      UINT256_MAX
    );

    uint256 expectedShares = hub1.previewRestoreByAssets(daiAssetId, bobDaiBefore.drawnDebt);

    deal(address(tokenList.dai), bob, fullDebt);
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    vm.prank(bob);
    tokenList.dai.transfer(address(hub1), fullDebt);

    TestReturnValues memory returnValues;

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Repay(
      _daiReserveId(spoke1),
      bob,
      bob,
      expectedShares,
      fullDebt,
      expectedPremiumDelta
    );
    _assertRefreshPremiumNotCalled();
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = spoke1.repaySkimmed(
      _daiReserveId(spoke1),
      UINT256_MAX,
      bob
    );

    Debts memory bobDaiAfter;
    bobDaiAfter.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiAfter.drawnDebt, bobDaiAfter.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    uint256 bobDaiBalanceAfter = tokenList.dai.balanceOf(bob);

    assertEq(returnValues.amount, fullDebt);
    assertEq(returnValues.shares, expectedShares);

    assertEq(bobDaiAfter.totalDebt, 0, 'Bob dai debt should be cleared');
    assertFalse(_isBorrowing(spoke1, _daiReserveId(spoke1), bob));

    assertEq(
      bobDaiBalanceAfter,
      bobDaiBalanceBefore - fullDebt,
      'Bob dai balance decreased by full debt repaid'
    );

    (uint256 baseDaiDebt, uint256 premiumDaiDebt) = spoke1.getReserveDebt(_daiReserveId(spoke1));
    assertEq(baseDaiDebt, 0);
    assertEq(premiumDaiDebt, 0);

    uint256 lhAssetDebt = hub1.getAssetTotalOwed(_daiReserveId(spoke1));
    assertEq(lhAssetDebt, 0);

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repaySkimmed');
  }

  function test_fuzz_repaySkimmed_same_block_fuzz_amounts(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    daiRepayAmount = bound(daiRepayAmount, 1, daiBorrowAmount);

    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      daiBorrowAmount
    );

    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiBorrowAmount, alice);
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
    assertEq(bobWethBefore.totalDebt, 0);

    uint256 expectedShares;
    TestReturnValues memory returnValues;
    {
      (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
        bobDaiBefore.drawnDebt,
        bobDaiBefore.premiumDebt,
        daiRepayAmount,
        daiAssetId
      );
      expectedShares = hub1.previewRestoreByAssets(daiAssetId, baseRestored);
      daiRepayAmount = baseRestored + premiumRestored;
    }

    vm.prank(bob);
    tokenList.dai.transfer(address(hub1), daiRepayAmount);

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
        expectedShares,
        daiRepayAmount,
        expectedPremiumDelta
      );
    }
    _assertRefreshPremiumNotCalled();
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = spoke1.repaySkimmed(
      _daiReserveId(spoke1),
      daiRepayAmount,
      bob
    );

    ISpoke.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    ISpoke.UserPosition memory bobWethDataAfter = getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    Debts memory bobDaiAfter = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    Debts memory bobWethAfter = getUserDebt(spoke1, bob, _wethReserveId(spoke1));

    assertEq(returnValues.amount, daiRepayAmount);
    assertEq(returnValues.shares, expectedShares);

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(
      bobDaiAfter.totalDebt,
      bobDaiBefore.totalDebt - daiRepayAmount,
      'bob dai debt final balance'
    );
    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(bobWethAfter.totalDebt, bobWethBefore.totalDebt);

    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - daiRepayAmount,
      'bob dai final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repaySkimmed');

    _repayAll(spoke1, _daiReserveId);
  }

  function test_repaySkimmed_fuzz_amountsAndWait(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount,
    uint40 skipTime
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    daiRepayAmount = bound(daiRepayAmount, 1, daiBorrowAmount);
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME).toUint40();

    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      daiBorrowAmount
    );

    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiBorrowAmount, alice);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    ISpoke.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    ISpoke.UserPosition memory bobWethDataBefore = getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    Debts memory bobDaiBefore;
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
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    skip(skipTime);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.drawnDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    assertGe(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');

    if (hub1.previewRestoreByAssets(daiAssetId, daiRepayAmount) == 0) {
      daiRepayAmount = hub1.previewRestoreByShares(daiAssetId, 1);
    }

    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      bobDaiBefore.drawnDebt,
      bobDaiBefore.premiumDebt,
      daiRepayAmount,
      daiAssetId
    );

    vm.prank(bob);
    tokenList.dai.transfer(address(hub1), daiRepayAmount);

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

    TestReturnValues memory returnValues;
    _assertRefreshPremiumNotCalled();
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = spoke1.repaySkimmed(
      _daiReserveId(spoke1),
      daiRepayAmount,
      bob
    );

    ISpoke.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    ISpoke.UserPosition memory bobWethDataAfter = getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    Debts memory bobDaiAfter = getUserDebt(spoke1, bob, _daiReserveId(spoke1));

    assertEq(returnValues.amount, daiRepayAmount);
    assertEq(returnValues.shares, hub1.previewRestoreByAssets(daiAssetId, baseRestored));

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertApproxEqAbs(
      bobDaiAfter.totalDebt,
      bobDaiBefore.totalDebt - baseRestored - premiumRestored,
      2,
      'bob dai debt final balance'
    );

    if (baseRestored > 0) {
      assertApproxEqAbs(
        bobDaiAfter.premiumDebt,
        0,
        1,
        'bob dai premium debt final balance when base repaid'
      );
    }

    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - daiRepayAmount,
      'bob dai final balance'
    );
    assertGe(daiRepayAmount, baseRestored + premiumRestored);
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repaySkimmed');

    _repayAll(spoke1, _daiReserveId);
  }

  function test_fuzz_repaySkimmed_x_y_shares(uint256 borrowAmount, uint40 skipTime) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 10);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME).toUint40();

    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      borrowAmount
    );

    uint256 bobDaiBalanceInitial = tokenList.dai.balanceOf(bob);

    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, borrowAmount, alice);

    uint256 expectedDrawnShares = hub1.previewRestoreByAssets(daiAssetId, borrowAmount);

    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, borrowAmount, bob);

    ISpoke.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    assertEq(bobDaiDataBefore.drawnShares, expectedDrawnShares, 'bob drawn shares');
    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceInitial + borrowAmount,
      'bob dai balance after borrow'
    );

    skip(skipTime);

    assertEq(
      spoke1.getUserPosition(_daiReserveId(spoke1), bob).drawnShares,
      expectedDrawnShares,
      'bob drawn shares after time passed'
    );
    assertGe(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      borrowAmount,
      'bob total debt after time passed'
    );

    (uint256 baseRestored, uint256 premiumRestored) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    uint256 totalRepayAmount = baseRestored + premiumRestored;

    IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
      spoke1,
      bob,
      _daiReserveId(spoke1),
      UINT256_MAX
    );

    deal(address(tokenList.dai), bob, totalRepayAmount);
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    vm.prank(bob);
    tokenList.dai.transfer(address(hub1), totalRepayAmount);

    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Repay(
      _daiReserveId(spoke1),
      bob,
      bob,
      hub1.previewRestoreByAssets(daiAssetId, baseRestored),
      totalRepayAmount,
      expectedPremiumDelta
    );

    _assertRefreshPremiumNotCalled();
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = spoke1.repaySkimmed(
      _daiReserveId(spoke1),
      UINT256_MAX,
      bob
    );

    uint256 bobDaiBalanceAfter = tokenList.dai.balanceOf(bob);
    uint256 bobTotalDebtAfter = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);

    assertEq(returnValues.amount, totalRepayAmount);
    assertEq(returnValues.shares, expectedDrawnShares);

    assertEq(
      spoke1.getUserPosition(_daiReserveId(spoke1), bob).drawnShares,
      0,
      'bob drawn shares after repay'
    );
    assertEq(bobTotalDebtAfter, 0, 'bob total debt after repay');
    assertEq(
      bobDaiBalanceBefore - bobDaiBalanceAfter,
      totalRepayAmount,
      'bob dai balance decreased by repay amount'
    );
    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repaySkimmed');
  }
}
