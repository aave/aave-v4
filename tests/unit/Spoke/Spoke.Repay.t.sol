// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeRepayTest is SpokeBase {
  using PercentageMath for uint256;
  using SafeCast for uint256;

  function test_repay_revertsWith_TransferFromFailed() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;
    uint256 daiRepayAmount = daiSupplyAmount / 4;
    uint256 approvalAmount = daiRepayAmount - 1;

    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    vm.startPrank(bob);
    tokenList.dai.approve(address(spoke1), approvalAmount);
    vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount, bob);
    vm.stopPrank();
  }

  function test_repay_fuzz_revertsWith_TransferFromFailed(uint256 daiRepayAmount) public {
    vm.assume(daiRepayAmount > 0);
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;

    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    vm.startPrank(bob);
    tokenList.dai.transfer(alice, tokenList.dai.balanceOf(bob)); // make bob have insufficient balance

    vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount, bob);
    vm.stopPrank();
  }

  function test_repay() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;
    uint256 daiRepayAmount = daiSupplyAmount / 4;

    // Bob supply weth
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);

    // Alice supply dai
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrow dai
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

    // Time passes
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

    // Bob repays half of principal debt
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
    (returnValues.shares, returnValues.amount) = spoke1.repay(
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

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repay');
  }

  function test_repay_all_with_accruals() public {
    uint256 supplyAmount = 5000e18;
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, supplyAmount, bob);

    uint256 borrowAmount = 1000e18;
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, borrowAmount, bob);

    skip(365 days);
    spoke1.getUserDebt(_daiReserveId(spoke1), bob);

    _assertRefreshPremiumNotCalled();
    Utils.repay(spoke1, _daiReserveId(spoke1), bob, borrowAmount, bob);

    skip(365 days);

    ISpoke.UserPosition memory pos = spoke1.getUserPosition(_daiReserveId(spoke1), bob);
    assertGt(pos.drawnShares, 0, 'user drawnShares after repay');
    assertGt(hub1.previewRestoreByShares(daiAssetId, pos.drawnShares), 0, 'user baseDrawnAssets');

    Utils.repay(spoke1, _daiReserveId(spoke1), bob, UINT256_MAX, bob);

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
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);

    // Alice supply dai
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrow dai
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

    // Bob repays half of principal debt
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
    (returnValues.shares, returnValues.amount) = spoke1.repay(
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

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repay');
  }

  /// repay all debt interest
  function test_repay_only_interest() public {
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
    bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    assertGt(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');

    // Bob repays interest
    uint256 daiRepayAmount = bobDaiBefore.drawnDebt + bobDaiBefore.premiumDebt - daiBorrowAmount;
    assertGt(daiRepayAmount, 0); // interest is not zero

    uint256 expectedShares;
    {
      (uint256 baseRestored, ) = _calculateExactRestoreAmount(
        bobDaiBefore.drawnDebt,
        bobDaiBefore.premiumDebt,
        daiRepayAmount,
        daiAssetId
      );
      expectedShares = hub1.previewRestoreByAssets(daiAssetId, baseRestored);
    }

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
      expectedShares,
      daiRepayAmount,
      expectedPremiumDelta
    );
    _assertRefreshPremiumNotCalled();
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = spoke1.repay(
      _daiReserveId(spoke1),
      daiRepayAmount,
      bob
    );

    ISpoke.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    ISpoke.UserPosition memory bobWethDataAfter = getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    Debts memory bobDaiAfter;

    assertEq(returnValues.amount, daiRepayAmount);
    assertEq(returnValues.shares, expectedShares);

    (bobDaiAfter.drawnDebt, bobDaiAfter.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertApproxEqAbs(bobDaiAfter.premiumDebt, 0, 1, 'bob dai premium debt final balance');
    assertApproxEqAbs(
      bobDaiAfter.drawnDebt,
      daiBorrowAmount,
      1,
      'bob dai drawn debt final balance'
    );
    assertApproxEqAbs(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      daiBorrowAmount,
      2,
      'bob dai debt final balance'
    );
    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(bobWethBefore.totalDebt, spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob));

    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - daiRepayAmount,
      'bob dai final balance'
    );
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
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);

    // Alice supply dai for Bob to borrow
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiBorrowAmount, alice);

    // Bob borrow dai
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    ISpoke.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    ISpoke.UserPosition memory bobWethDataBefore = getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);
    uint256 bobDaiDebtBefore = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    uint256 bobWethDebtBefore = spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiDebtBefore, daiBorrowAmount, 'bob dai debt before');
    assertEq(
      bobWethDataBefore.suppliedShares,
      hub1.previewAddByAssets(wethAssetId, wethSupplyAmount)
    );
    assertEq(bobWethDebtBefore, 0);

    // Time passes
    skip(skipTime);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiDebtBefore = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (uint256 bobDaiDrawnDebtBefore, uint256 bobDaiPremiumDebtBefore) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
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

    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Repay(_daiReserveId(spoke1), bob, bob, 0, daiRepayAmount, expectedPremiumDelta);
    _assertRefreshPremiumNotCalled();
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = spoke1.repay(
      _daiReserveId(spoke1),
      daiRepayAmount,
      bob
    );

    ISpoke.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    ISpoke.UserPosition memory bobWethDataAfter = getUserInfo(spoke1, bob, _wethReserveId(spoke1));

    assertEq(returnValues.amount, daiRepayAmount);
    assertEq(returnValues.shares, 0);

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertApproxEqAbs(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      bobDaiDrawnDebtBefore + bobDaiPremiumDebtBefore - daiRepayAmount,
      1,
      'bob dai debt final balance'
    );
    (, uint256 bobDaiPremiumDebtAfter) = spoke1.getUserDebt(_daiReserveId(spoke1), bob);
    assertApproxEqAbs(
      bobDaiPremiumDebtAfter,
      bobDaiPremiumDebtBefore - daiRepayAmount,
      1,
      'bob dai premium debt final balance'
    );
    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(bobWethDebtBefore, spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob));

    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - daiRepayAmount,
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
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);

    // Alice supplies DAI
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrows DAI
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

    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiBefore.totalDebt, daiBorrowAmount, 'Initial bob dai debt');

    // Time passes so that interest accrues
    skip(10 days);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.drawnDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    // Bob's debt (drawn debt + premium) is greater than the original borrow amount
    assertGt(bobDaiBefore.totalDebt, daiBorrowAmount, 'Accrued interest increased bob dai debt');

    // Calculate full debt before repayment
    uint256 fullDebt = bobDaiBefore.drawnDebt + bobDaiBefore.premiumDebt;

    IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
      spoke1,
      bob,
      _daiReserveId(spoke1),
      UINT256_MAX
    );

    uint256 expectedShares = hub1.previewRestoreByAssets(daiAssetId, bobDaiBefore.drawnDebt);

    // Bob repays using the max value to signal full repayment
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
    (returnValues.shares, returnValues.amount) = spoke1.repay(
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

    // Verify that Bob's debt is fully cleared after repayment
    assertEq(bobDaiAfter.totalDebt, 0, 'Bob dai debt should be cleared');
    assertFalse(_isBorrowing(spoke1, _daiReserveId(spoke1), bob));

    // Verify that his DAI balance was reduced by the full debt amount
    assertEq(
      bobDaiBalanceAfter,
      bobDaiBalanceBefore - fullDebt,
      'Bob dai balance decreased by full debt repaid'
    );

    // Verify reserve debt is 0
    (uint256 baseDaiDebt, uint256 premiumDaiDebt) = spoke1.getReserveDebt(_daiReserveId(spoke1));
    assertEq(baseDaiDebt, 0);
    assertEq(premiumDaiDebt, 0);

    // verify LH asset debt is 0
    uint256 lhAssetDebt = hub1.getAssetTotalOwed(_daiReserveId(spoke1));
    assertEq(lhAssetDebt, 0);

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
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);

    // Alice supply dai
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiBorrowAmount, alice);

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

    {
      IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
        spoke1,
        bob,
        _daiReserveId(spoke1),
        daiRepayAmount
      );

      // Bob repays
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
    (returnValues.shares, returnValues.amount) = spoke1.repay(
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

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repay');

    _repayAll(spoke1, _daiReserveId);
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
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);

    // Alice supply dai
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiBorrowAmount, alice);

    // Bob borrow dai
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

    // Time passes
    skip(skipTime);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.drawnDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    assertGe(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');

    // Calculate minimum repay amount
    if (hub1.previewRestoreByAssets(daiAssetId, daiRepayAmount) == 0) {
      daiRepayAmount = hub1.previewRestoreByShares(daiAssetId, 1);
    }

    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      bobDaiBefore.drawnDebt,
      bobDaiBefore.premiumDebt,
      daiRepayAmount,
      daiAssetId
    );

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
    // Bob repays
    TestReturnValues memory returnValues;
    _assertRefreshPremiumNotCalled();
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = spoke1.repay(
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

    // If any drawn debt was repaid, then premium debt must be zero, or one
    // because of the difference in rounding for offset & premium drawn shares
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
    assertGe(daiRepayAmount, baseRestored + premiumRestored); // excess amount donated
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repay');

    _repayAll(spoke1, _daiReserveId);
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
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);

    // Alice supply dai
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiBorrowAmount, alice);

    // Bob borrow dai
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    ISpoke.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    ISpoke.UserPosition memory bobWethDataBefore = getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);
    Debts memory bobDaiBefore;
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.drawnDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');
    assertEq(
      bobWethDataBefore.suppliedShares,
      hub1.previewAddByAssets(wethAssetId, wethSupplyAmount)
    );
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    // Time passes
    skip(skipTime);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    assertGe(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');

    // Bob repays
    // bobDaiInterest = bobDaiBefore.totalDebt - daiBorrowAmount
    daiRepayAmount = bound(daiRepayAmount, 0, bobDaiBefore.totalDebt - daiBorrowAmount);
    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      bobDaiBefore.drawnDebt,
      bobDaiBefore.premiumDebt,
      daiRepayAmount,
      daiAssetId
    );
    deal(address(tokenList.dai), bob, daiRepayAmount);

    TestReturnValues memory returnValues;
    {
      IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
        spoke1,
        bob,
        _daiReserveId(spoke1),
        daiRepayAmount
      );

      if (daiRepayAmount == 0) {
        vm.expectRevert(IHub.InvalidAmount.selector);
      } else {
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
    }
    _assertRefreshPremiumNotCalled();
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
    daiRepayAmount = baseRestored + premiumRestored;

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertApproxEqAbs(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      daiRepayAmount >= bobDaiBefore.totalDebt ? 0 : bobDaiBefore.totalDebt - daiRepayAmount,
      2,
      'bob dai debt final balance'
    );
    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    assertEq(tokenList.dai.balanceOf(bob), 0, 'bob dai final balance');
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

    // repays only interest
    // it can be equal because of 1 wei rounding issue when repaying
    assertGe(spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob), daiBorrowAmount);

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
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);

    // Alice supply dai
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiBorrowAmount, alice);

    // Bob borrow dai
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    ISpoke.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    ISpoke.UserPosition memory bobWethDataBefore = getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);
    Debts memory bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(
      bobDaiBefore.drawnDebt + bobDaiBefore.premiumDebt,
      daiBorrowAmount,
      'bob dai debt before'
    );
    assertEq(
      bobWethDataBefore.suppliedShares,
      hub1.previewAddByAssets(wethAssetId, wethSupplyAmount)
    );
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    // Time passes
    skip(skipTime);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    assertGe(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');

    // Bob repays
    uint256 bobDaiPremium = bobDaiBefore.premiumDebt;
    uint256 premiumRestored;
    TestReturnValues memory returnValues;
    if (bobDaiPremium == 0) {
      // not enough time travel for premium accrual
      daiRepayAmount = 0;
      premiumRestored = 0;
      deal(address(tokenList.dai), bob, daiRepayAmount);
      vm.expectRevert(IHub.InvalidAmount.selector);
    } else {
      // interest is at least 1
      daiRepayAmount = bound(daiRepayAmount, 1, bobDaiPremium);
      (, premiumRestored) = _calculateExactRestoreAmount(
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
      deal(address(tokenList.dai), bob, daiRepayAmount);
      vm.expectEmit(address(spoke1));
      emit ISpokeBase.Repay(
        _daiReserveId(spoke1),
        bob,
        bob,
        0,
        daiRepayAmount,
        expectedPremiumDelta
      );
    }
    _assertRefreshPremiumNotCalled();
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = spoke1.repay(
      _daiReserveId(spoke1),
      daiRepayAmount,
      bob
    );

    ISpoke.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    ISpoke.UserPosition memory bobWethDataAfter = getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    Debts memory bobDaiAfter;
    bobDaiAfter = getUserDebt(spoke1, bob, _daiReserveId(spoke1));

    assertEq(returnValues.amount, daiRepayAmount);
    assertEq(returnValues.shares, 0);

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(bobDaiAfter.drawnDebt, bobDaiBefore.drawnDebt, 'bob dai drawn debt final balance');
    assertApproxEqAbs(
      bobDaiAfter.premiumDebt,
      bobDaiBefore.premiumDebt - premiumRestored,
      1,
      'bob dai premium debt final balance'
    );
    assertApproxEqAbs(
      bobDaiAfter.drawnDebt + bobDaiAfter.premiumDebt,
      bobDaiBefore.drawnDebt + bobDaiBefore.premiumDebt - premiumRestored,
      1,
      'bob dai debt final balance'
    );
    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    assertEq(tokenList.dai.balanceOf(bob), 0, 'bob dai final balance');
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

    // repays only premium
    assertGe(bobDaiAfter.premiumDebt, 0);

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
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);

    // Alice supply dai
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiBorrowAmount, alice);

    // Bob borrow dai
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    ISpoke.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    ISpoke.UserPosition memory bobWethDataBefore = getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    Debts memory bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');
    assertEq(
      bobWethDataBefore.suppliedShares,
      hub1.previewAddByAssets(wethAssetId, wethSupplyAmount)
    );
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    // Time passes
    skip(skipTime);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    assertGe(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');

    // Bob repays premium first if any
    if (bobDaiBefore.premiumDebt > 0) {
      deal(address(tokenList.dai), bob, bobDaiBefore.premiumDebt);
      Utils.repay(spoke1, _daiReserveId(spoke1), bob, bobDaiBefore.premiumDebt, bob);
    }

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);

    assertApproxEqAbs(bobDaiBefore.premiumDebt, 0, 1);

    // Bob repays;
    daiRepayAmount = bound(daiRepayAmount, 0, bobDaiBefore.totalDebt - daiBorrowAmount);
    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      bobDaiBefore.drawnDebt,
      bobDaiBefore.premiumDebt,
      daiRepayAmount,
      daiAssetId
    );
    deal(address(tokenList.dai), bob, daiRepayAmount);

    TestReturnValues memory returnValues;
    if (daiRepayAmount == 0) {
      vm.expectRevert(IHub.InvalidAmount.selector);
    } else {
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
    _assertRefreshPremiumNotCalled();
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = spoke1.repay(
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
    assertApproxEqAbs(bobDaiAfter.premiumDebt, 0, 1, 'bob dai premium debt final balance');
    assertApproxEqAbs(
      bobDaiAfter.totalDebt,
      daiRepayAmount >= bobDaiBefore.totalDebt
        ? 0
        : bobDaiBefore.totalDebt - baseRestored - premiumRestored,
      2,
      'bob dai debt final balance'
    );
    // repays only drawn debt
    assertApproxEqAbs(
      bobDaiAfter.drawnDebt,
      daiRepayAmount > bobDaiBefore.drawnDebt ? 0 : bobDaiBefore.drawnDebt - baseRestored,
      1,
      'bob dai drawn debt final balance'
    );

    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
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
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);

    // Alice supply dai
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiBorrowAmount, alice);

    // Bob borrow dai
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    ISpoke.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    ISpoke.UserPosition memory bobWethDataBefore = getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    Debts memory bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');
    assertEq(
      bobWethDataBefore.suppliedShares,
      hub1.previewAddByAssets(wethAssetId, wethSupplyAmount)
    );
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    // Time passes
    skip(skipTime);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));

    assertGe(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');
    assertEq(bobDaiBefore.premiumDebt, 0, 'bob dai premium debt before');

    // Bob repays
    uint256 baseRestored;
    uint256 premiumRestored;
    {
      uint256 bobDaiDrawnDebt = bobDaiBefore.drawnDebt - daiBorrowAmount;
      daiRepayAmount = bound(daiRepayAmount, 0, bobDaiDrawnDebt);
      (baseRestored, premiumRestored) = _calculateExactRestoreAmount(
        bobDaiDrawnDebt,
        0,
        daiRepayAmount,
        daiAssetId
      );
      deal(address(tokenList.dai), bob, daiRepayAmount);

      IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
        spoke1,
        bob,
        _daiReserveId(spoke1),
        daiRepayAmount
      );

      if (daiRepayAmount == 0) {
        vm.expectRevert(IHub.InvalidAmount.selector);
      } else {
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
    }

    TestReturnValues memory returnValues;
    _assertRefreshPremiumNotCalled();
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = spoke1.repay(
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
      bobDaiAfter.drawnDebt,
      daiRepayAmount >= bobDaiBefore.drawnDebt ? 0 : bobDaiBefore.drawnDebt - baseRestored,
      1,
      'bob dai drawn debt final balance'
    );
    assertEq(bobDaiAfter.premiumDebt, 0, 'bob dai premium debt final balance');
    assertApproxEqAbs(
      bobDaiAfter.totalDebt,
      daiRepayAmount >= bobDaiBefore.totalDebt
        ? 0
        : bobDaiBefore.totalDebt - (baseRestored + premiumRestored),
      1,
      'bob dai debt final balance'
    );
    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    assertEq(tokenList.dai.balanceOf(bob), 0, 'bob dai final balance');
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

    // repays only drawn debt
    assertGe(
      bobDaiAfter.drawnDebt,
      daiRepayAmount >= bobDaiBefore.drawnDebt ? 0 : bobDaiBefore.drawnDebt - daiRepayAmount,
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

    daiInfo.borrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    wethInfo.borrowAmount = bound(wethBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    usdxInfo.borrowAmount = bound(usdxBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    wbtcInfo.borrowAmount = bound(wbtcBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
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
      Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
      deal(address(tokenList.wbtc), bob, wbtcSupplyAmount);
      Utils.supplyCollateral(spoke1, _wbtcReserveId(spoke1), bob, wbtcSupplyAmount, bob);
    }

    // Alice supply liquidity
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiInfo.borrowAmount, alice);
    Utils.supply(spoke1, _wethReserveId(spoke1), alice, wethInfo.borrowAmount, alice);
    Utils.supply(spoke1, _usdxReserveId(spoke1), alice, usdxInfo.borrowAmount, alice);
    Utils.supply(spoke1, _wbtcReserveId(spoke1), alice, wbtcInfo.borrowAmount, alice);

    // Bob borrows
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiInfo.borrowAmount, bob);
    Utils.borrow(spoke1, _wethReserveId(spoke1), bob, wethInfo.borrowAmount, bob);
    Utils.borrow(spoke1, _usdxReserveId(spoke1), bob, usdxInfo.borrowAmount, bob);
    Utils.borrow(spoke1, _wbtcReserveId(spoke1), bob, wbtcInfo.borrowAmount, bob);

    daiInfo.posBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    wethInfo.posBefore = getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    usdxInfo.posBefore = getUserInfo(spoke1, bob, _usdxReserveId(spoke1));
    wbtcInfo.posBefore = getUserInfo(spoke1, bob, _wbtcReserveId(spoke1));

    Debts memory bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    Debts memory bobWethBefore = getUserDebt(spoke1, bob, _wethReserveId(spoke1));
    Debts memory bobUsdxBefore = getUserDebt(spoke1, bob, _usdxReserveId(spoke1));
    Debts memory bobWbtcBefore = getUserDebt(spoke1, bob, _wbtcReserveId(spoke1));

    assertEq(bobDaiBefore.totalDebt, daiInfo.borrowAmount);
    assertEq(bobWethBefore.totalDebt, wethInfo.borrowAmount);
    assertEq(bobWbtcBefore.totalDebt, wbtcInfo.borrowAmount);
    assertEq(bobUsdxBefore.totalDebt, usdxInfo.borrowAmount);

    // Time passes
    skip(skipTime);
    _assertRefreshPremiumNotCalled();

    // Repayments
    daiInfo.posBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    assertGe(bobDaiBefore.totalDebt, daiInfo.borrowAmount);
    if (daiInfo.repayAmount > 0) {
      (daiInfo.baseRestored, daiInfo.premiumRestored) = _calculateExactRestoreAmount(
        bobDaiBefore.drawnDebt,
        bobDaiBefore.premiumDebt,
        daiInfo.repayAmount,
        daiAssetId
      );
      deal(address(tokenList.dai), bob, daiInfo.repayAmount);
      Utils.repay(spoke1, _daiReserveId(spoke1), bob, daiInfo.repayAmount, bob);
    }
    Debts memory bobDaiAfter = getUserDebt(spoke1, bob, _daiReserveId(spoke1));

    wethInfo.posBefore = getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    bobWethBefore = getUserDebt(spoke1, bob, _wethReserveId(spoke1));
    assertGe(bobWethBefore.totalDebt, wethInfo.borrowAmount);
    if (wethInfo.repayAmount > 0) {
      (wethInfo.baseRestored, wethInfo.premiumRestored) = _calculateExactRestoreAmount(
        bobWethBefore.drawnDebt,
        bobWethBefore.premiumDebt,
        wethInfo.repayAmount,
        wethAssetId
      );
      deal(address(tokenList.weth), bob, wethInfo.repayAmount);
      Utils.repay(spoke1, _wethReserveId(spoke1), bob, wethInfo.repayAmount, bob);
    }
    Debts memory bobWethAfter = getUserDebt(spoke1, bob, _wethReserveId(spoke1));

    wbtcInfo.posBefore = getUserInfo(spoke1, bob, _wbtcReserveId(spoke1));
    bobWbtcBefore = getUserDebt(spoke1, bob, _wbtcReserveId(spoke1));
    assertGe(bobWbtcBefore.totalDebt, wbtcInfo.borrowAmount);
    if (wbtcInfo.repayAmount > 0) {
      (wbtcInfo.baseRestored, wbtcInfo.premiumRestored) = _calculateExactRestoreAmount(
        bobWbtcBefore.drawnDebt,
        bobWbtcBefore.premiumDebt,
        wbtcInfo.repayAmount,
        wbtcAssetId
      );
      deal(address(tokenList.wbtc), bob, wbtcInfo.repayAmount);
      Utils.repay(spoke1, _wbtcReserveId(spoke1), bob, wbtcInfo.repayAmount, bob);
    }
    Debts memory bobWbtcAfter = getUserDebt(spoke1, bob, _wbtcReserveId(spoke1));

    usdxInfo.posBefore = getUserInfo(spoke1, bob, _usdxReserveId(spoke1));
    bobUsdxBefore = getUserDebt(spoke1, bob, _usdxReserveId(spoke1));
    assertGe(bobUsdxBefore.totalDebt, usdxInfo.borrowAmount);
    if (usdxInfo.repayAmount > 0) {
      (usdxInfo.baseRestored, usdxInfo.premiumRestored) = _calculateExactRestoreAmount(
        bobUsdxBefore.drawnDebt,
        bobUsdxBefore.premiumDebt,
        usdxInfo.repayAmount,
        usdxAssetId
      );
      deal(address(tokenList.usdx), bob, usdxInfo.repayAmount);
      Utils.repay(spoke1, _usdxReserveId(spoke1), bob, usdxInfo.repayAmount, bob);
    }
    Debts memory bobUsdxAfter = getUserDebt(spoke1, bob, _usdxReserveId(spoke1));

    daiInfo.posAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    wethInfo.posAfter = getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    usdxInfo.posAfter = getUserInfo(spoke1, bob, _usdxReserveId(spoke1));
    wbtcInfo.posAfter = getUserInfo(spoke1, bob, _wbtcReserveId(spoke1));

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

    _repayAll(spoke1, _daiReserveId);
    _repayAll(spoke1, _wethReserveId);
    _repayAll(spoke1, _usdxReserveId);
    _repayAll(spoke1, _wbtcReserveId);
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
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);

    // Alice supply dai such that usage ratio after bob borrows is ~45%, borrow rate ~7.5%
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, borrowAmount, alice);

    uint256 expectedDrawnShares = hub1.previewRestoreByAssets(daiAssetId, borrowAmount);

    // Bob borrow dai
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, borrowAmount, bob);

    ISpoke.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
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
    (uint256 baseRestored, uint256 premiumRestored) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobTotalDebtBefore = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);

    IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
      spoke1,
      bob,
      _daiReserveId(spoke1),
      UINT256_MAX
    );

    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Repay(
      _daiReserveId(spoke1),
      bob,
      bob,
      hub1.previewRestoreByAssets(daiAssetId, baseRestored),
      baseRestored + premiumRestored,
      expectedPremiumDelta
    );

    _assertRefreshPremiumNotCalled();
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = spoke1.repay(
      _daiReserveId(spoke1),
      UINT256_MAX,
      bob
    );

    uint256 bobDaiBalanceAfter = tokenList.dai.balanceOf(bob);
    uint256 bobTotalDebtAfter = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);

    assertEq(returnValues.amount, baseRestored + premiumRestored);
    assertEq(returnValues.shares, expectedDrawnShares);

    // Bob should have 0 drawn shares
    assertEq(
      spoke1.getUserPosition(_daiReserveId(spoke1), bob).drawnShares,
      0,
      'bob drawn shares after repay'
    );
    // Bob's debt should be 0
    assertEq(bobTotalDebtAfter, 0, 'bob total debt after repay');
    // Bob's debt change vs the amount repaid
    assertEq(
      stdMath.delta(bobTotalDebtAfter, bobTotalDebtBefore),
      stdMath.delta(bobDaiBalanceAfter, bobDaiBalanceBefore),
      'bob balance vs debt change'
    );
    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.repay');
  }
}
