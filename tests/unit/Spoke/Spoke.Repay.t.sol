// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeRepayTest is SpokeBase {
  using PercentageMath for uint256;

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

    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

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
    bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));

    assertGe(bobDaiBefore.baseDebt, daiBorrowAmount, 'bob dai debt before');
    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      bobDaiBefore.baseDebt,
      bobDaiBefore.premiumDebt,
      daiRepayAmount,
      daiAssetId
    );

    // Bob repays half of principal debt
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
      _daiReserveId(spoke1),
      bob,
      bob,
      hub.convertToDrawnShares(daiAssetId, baseRestored)
    );
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount, bob);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
      spoke1,
      bob,
      _wethReserveId(spoke1)
    );

    daiRepayAmount = baseRestored + premiumRestored;

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertApproxEqAbs(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      bobDaiBefore.baseDebt + bobDaiBefore.premiumDebt - daiRepayAmount,
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
  }

  function test_repay_all_with_accruals() public {
    uint256 supplyAmount = 5000e18;
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, supplyAmount, bob);

    uint256 borrowAmount = 1000e18;
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, borrowAmount, bob);

    skip(365 days);
    spoke1.getUserDebt(_daiReserveId(spoke1), bob);

    Utils.repay(spoke1, _daiReserveId(spoke1), bob, borrowAmount, bob);

    skip(365 days);

    DataTypes.UserPosition memory pos = spoke1.getUserPosition(_daiReserveId(spoke1), bob);
    assertGt(pos.baseDrawnShares, 0, 'user baseDrawnShares after repay');
    assertGt(hub.convertToDrawnAssets(daiAssetId, pos.baseDrawnShares), 0, 'user baseDrawnAssets');

    Utils.repay(spoke1, _daiReserveId(spoke1), bob, type(uint256).max, bob);

    pos = spoke1.getUserPosition(_daiReserveId(spoke1), bob);
    assertEq(pos.baseDrawnShares, 0, 'user baseDrawnShares after full repay');
    assertEq(hub.convertToDrawnAssets(daiAssetId, pos.baseDrawnShares), 0, 'user baseDrawnAssets');
    assertEq(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      0,
      'user total debt after full repay'
    );
    assertFalse(spoke1.isBorrowing(_daiReserveId(spoke1), bob));
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
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);
    uint256 bobTotalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (uint256 bobWethBaseDebtBefore, uint256 bobWethPremiumDebtBefore) = spoke1.getUserDebt(
      _wethReserveId(spoke1),
      bob
    );

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobTotalDebt, daiBorrowAmount, 'bob dai debt before');
    assertEq(
      bobWethDataBefore.suppliedShares,
      hub.convertToSuppliedShares(wethAssetId, wethSupplyAmount)
    );
    assertEq(bobWethBaseDebtBefore, 0, 'bob weth base debt before');
    assertEq(bobWethPremiumDebtBefore, 0, 'bob weth premium debt before');

    // Bob repays half of principal debt
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(_daiReserveId(spoke1), bob, bob, daiRepayAmount);
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount, bob);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
      spoke1,
      bob,
      _wethReserveId(spoke1)
    );
    (uint256 bobWethBaseDebtAfter, uint256 bobWethPremiumDebtAfter) = spoke1.getUserDebt(
      _wethReserveId(spoke1),
      bob
    );

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      bobTotalDebt - daiRepayAmount,
      'bob dai debt final balance'
    );
    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(bobWethBaseDebtAfter, bobWethBaseDebtBefore);
    assertEq(bobWethPremiumDebtAfter, bobWethPremiumDebtBefore);

    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - daiRepayAmount,
      'bob dai final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);
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
    bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    assertGt(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');

    // Bob repays interest
    uint256 daiRepayAmount = bobDaiBefore.baseDebt + bobDaiBefore.premiumDebt - daiBorrowAmount;
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
      bob,
      hub.convertToDrawnShares(daiAssetId, baseRestored)
    );
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount, bob);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
      spoke1,
      bob,
      _wethReserveId(spoke1)
    );
    Debts memory bobDaiAfter;

    (bobDaiAfter.baseDebt, bobDaiAfter.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertApproxEqAbs(bobDaiAfter.premiumDebt, 0, 1, 'bob dai premium debt final balance');
    assertApproxEqAbs(bobDaiAfter.baseDebt, daiBorrowAmount, 1, 'bob dai base debt final balance');
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
  }

  /// repay partial or full premium debt, but no base debt
  function test_fuzz_repay_only_premium(uint256 daiBorrowAmount, uint40 skipTime) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      daiBorrowAmount
    );
    skipTime = uint40(bound(skipTime, 1, MAX_SKIP_TIME));

    // Bob supply weth as collateral
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);

    // Alice supply dai for Bob to borrow
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiBorrowAmount, alice);

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
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);
    uint256 bobDaiDebtBefore = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    uint256 bobWethDebtBefore = spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiDebtBefore, daiBorrowAmount, 'bob dai debt before');
    assertEq(
      bobWethDataBefore.suppliedShares,
      hub.convertToSuppliedShares(wethAssetId, wethSupplyAmount)
    );
    assertEq(bobWethDebtBefore, 0);

    // Time passes
    skip(skipTime);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiDebtBefore = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (uint256 bobDaiBaseDebtBefore, uint256 bobDaiPremiumDebtBefore) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    vm.assume(bobDaiPremiumDebtBefore > 0); // assume time passes enough to accrue premium debt

    // Bob repays any amount of premium debt
    uint256 daiRepayAmount;
    daiRepayAmount = bound(daiRepayAmount, 1, bobDaiPremiumDebtBefore);

    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(_daiReserveId(spoke1), bob, bob, 0);
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount, bob);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
      spoke1,
      bob,
      _wethReserveId(spoke1)
    );

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertApproxEqAbs(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      bobDaiBaseDebtBefore + bobDaiPremiumDebtBefore - daiRepayAmount,
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

    DataTypes.UserPosition memory bobDaiDataBefore = getUserInfo(
      spoke1,
      bob,
      _daiReserveId(spoke1)
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

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiBefore.totalDebt, daiBorrowAmount, 'Initial bob dai debt');

    // Time passes so that interest accrues
    skip(10 days);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.baseDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    // Bob's debt (base debt + premium) is greater than the original borrow amount
    assertGt(bobDaiBefore.totalDebt, daiBorrowAmount, 'Accrued interest increased bob dai debt');

    // Calculate full debt before repayment
    uint256 fullDebt = bobDaiBefore.baseDebt + bobDaiBefore.premiumDebt;

    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
      _daiReserveId(spoke1),
      bob,
      bob,
      hub.convertToDrawnShares(daiAssetId, bobDaiBefore.baseDebt)
    );

    // Bob repays using the max value to signal full repayment
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), type(uint256).max, bob);

    Debts memory bobDaiAfter;
    bobDaiAfter.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiAfter.baseDebt, bobDaiAfter.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    uint256 bobDaiBalanceAfter = tokenList.dai.balanceOf(bob);

    // Verify that Bob's debt is fully cleared after repayment
    assertEq(bobDaiAfter.totalDebt, 0, 'Bob dai debt should be cleared');
    assertFalse(spoke1.isBorrowing(_daiReserveId(spoke1), bob));

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
    uint256 lhAssetDebt = hub.getAssetTotalDebt(_daiReserveId(spoke1));
    assertEq(lhAssetDebt, 0);
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
    assertEq(bobWethBefore.totalDebt, 0);

    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      bobDaiBefore.baseDebt,
      bobDaiBefore.premiumDebt,
      daiRepayAmount,
      daiAssetId
    );

    // Bob repays
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
      _daiReserveId(spoke1),
      bob,
      bob,
      hub.convertToDrawnShares(daiAssetId, baseRestored)
    );
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount, bob);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
      spoke1,
      bob,
      _wethReserveId(spoke1)
    );
    Debts memory bobDaiAfter = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    Debts memory bobWethAfter = getUserDebt(spoke1, bob, _wethReserveId(spoke1));
    daiRepayAmount = baseRestored + premiumRestored;

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

    _repayAll(spoke1, _daiReserveId);
  }

  /// repay all or a portion of total debt - handles partial base debt repay case
  function test_repay_fuzz_amountsAndWait(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount,
    uint40 skipTime
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    daiRepayAmount = bound(daiRepayAmount, 1, daiBorrowAmount);
    skipTime = uint40(bound(skipTime, 0, MAX_SKIP_TIME));

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
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    // Time passes
    skip(skipTime);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.baseDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    assertGe(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');

    // Calculate minimum repay amount
    if (hub.convertToDrawnShares(daiAssetId, daiRepayAmount) == 0) {
      daiRepayAmount = hub.convertToDrawnAssets(daiAssetId, 1);
    }

    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      bobDaiBefore.baseDebt,
      bobDaiBefore.premiumDebt,
      daiRepayAmount,
      daiAssetId
    );

    // Bob repays
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
      _daiReserveId(spoke1),
      bob,
      bob,
      hub.convertToDrawnShares(daiAssetId, baseRestored)
    );
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount, bob);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
      spoke1,
      bob,
      _wethReserveId(spoke1)
    );
    Debts memory bobDaiAfter = getUserDebt(spoke1, bob, _daiReserveId(spoke1));

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertApproxEqAbs(
      bobDaiAfter.totalDebt,
      bobDaiBefore.totalDebt - baseRestored - premiumRestored,
      2,
      'bob dai debt final balance'
    );

    // If any base debt was repaid, then premium debt must be zero, or one
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

    _repayAll(spoke1, _daiReserveId);
  }

  /// repay all or a portion of debt interest
  function test_fuzz_repay_amounts_only_interest(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount,
    uint40 skipTime
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    skipTime = uint40(bound(skipTime, 0, MAX_SKIP_TIME));

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
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);
    Debts memory bobDaiBefore;
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.baseDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');
    assertEq(
      bobWethDataBefore.suppliedShares,
      hub.convertToSuppliedShares(wethAssetId, wethSupplyAmount)
    );
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    // Time passes
    skip(skipTime);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    assertGe(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');

    // Bob repays
    uint256 bobDaiInterest = bobDaiBefore.totalDebt - daiBorrowAmount;
    daiRepayAmount = bound(daiRepayAmount, 0, bobDaiInterest);
    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      bobDaiBefore.baseDebt,
      bobDaiBefore.premiumDebt,
      daiRepayAmount,
      daiAssetId
    );
    deal(address(tokenList.dai), bob, daiRepayAmount);

    if (daiRepayAmount == 0) {
      vm.expectRevert(ILiquidityHub.InvalidRestoreAmount.selector);
    } else {
      vm.expectEmit(address(spoke1));
      emit ISpoke.Repay(
        _daiReserveId(spoke1),
        bob,
        bob,
        hub.convertToDrawnShares(daiAssetId, baseRestored)
      );
    }
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount, bob);

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
    daiRepayAmount = baseRestored + premiumRestored;

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertApproxEqAbs(
      bobDaiAfter.totalDebt,
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
    assertGe(bobDaiAfter.totalDebt, daiBorrowAmount);
  }

  /// repay all or a portion of premium debt
  function test_fuzz_amounts_repay_only_premium(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount,
    uint40 skipTime
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    skipTime = uint40(bound(skipTime, 0, MAX_SKIP_TIME));

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
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);
    Debts memory bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(
      bobDaiBefore.baseDebt + bobDaiBefore.premiumDebt,
      daiBorrowAmount,
      'bob dai debt before'
    );
    assertEq(
      bobWethDataBefore.suppliedShares,
      hub.convertToSuppliedShares(wethAssetId, wethSupplyAmount)
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
    if (bobDaiPremium == 0) {
      // not enough time travel for premium accrual
      daiRepayAmount = 0;
      premiumRestored = 0;
      deal(address(tokenList.dai), bob, daiRepayAmount);
      vm.expectRevert(ILiquidityHub.InvalidRestoreAmount.selector);
    } else {
      // interest is at least 1
      daiRepayAmount = bound(daiRepayAmount, 1, bobDaiPremium);
      (, premiumRestored) = _calculateExactRestoreAmount(
        bobDaiBefore.baseDebt,
        bobDaiBefore.premiumDebt,
        daiRepayAmount,
        daiAssetId
      );
      deal(address(tokenList.dai), bob, daiRepayAmount);
      vm.expectEmit(address(spoke1));
      emit ISpoke.Repay(_daiReserveId(spoke1), bob, bob, 0);
    }
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount, bob);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
      spoke1,
      bob,
      _wethReserveId(spoke1)
    );
    Debts memory bobDaiAfter;
    bobDaiAfter = getUserDebt(spoke1, bob, _daiReserveId(spoke1));

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(bobDaiAfter.baseDebt, bobDaiBefore.baseDebt, 'bob dai base debt final balance');
    assertApproxEqAbs(
      bobDaiAfter.premiumDebt,
      bobDaiBefore.premiumDebt - premiumRestored,
      1,
      'bob dai premium debt final balance'
    );
    assertApproxEqAbs(
      bobDaiAfter.baseDebt + bobDaiAfter.premiumDebt,
      bobDaiBefore.baseDebt + bobDaiBefore.premiumDebt - premiumRestored,
      1,
      'bob dai debt final balance'
    );
    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    assertEq(tokenList.dai.balanceOf(bob), 0, 'bob dai final balance');
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

    // repays only premium
    assertGe(bobDaiAfter.premiumDebt, 0);
  }

  /// repay all or a portion of accrued base debt when premium debt is already repaid
  function test_repay_fuzz_amounts_base_debt(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount,
    uint40 skipTime
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    skipTime = uint40(bound(skipTime, 0, MAX_SKIP_TIME));

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
    Debts memory bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');
    assertEq(
      bobWethDataBefore.suppliedShares,
      hub.convertToSuppliedShares(wethAssetId, wethSupplyAmount)
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
      bobDaiBefore.baseDebt,
      bobDaiBefore.premiumDebt,
      daiRepayAmount,
      daiAssetId
    );
    deal(address(tokenList.dai), bob, daiRepayAmount);

    if (daiRepayAmount == 0) {
      vm.expectRevert(ILiquidityHub.InvalidRestoreAmount.selector);
    } else {
      vm.expectEmit(address(spoke1));
      emit ISpoke.Repay(
        _daiReserveId(spoke1),
        bob,
        bob,
        hub.convertToDrawnShares(daiAssetId, baseRestored)
      );
    }
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount, bob);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
      spoke1,
      bob,
      _wethReserveId(spoke1)
    );
    Debts memory bobDaiAfter = getUserDebt(spoke1, bob, _daiReserveId(spoke1));

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
    // repays only base debt
    assertApproxEqAbs(
      bobDaiAfter.baseDebt,
      daiRepayAmount > bobDaiBefore.baseDebt ? 0 : bobDaiBefore.baseDebt - baseRestored,
      1,
      'bob dai base debt final balance'
    );

    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);
    assertEq(tokenList.dai.balanceOf(bob), 0, 'bob dai final balance');
  }

  /// repay all or a portion of accrued base debt when premium debt is zero
  function test_repay_fuzz_amounts_base_debt_no_premium(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount,
    uint40 skipTime
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);

    // update collateral risk to zero
    updateCollateralRisk(spoke1, _wethReserveId(spoke1), 0);

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
    Debts memory bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');
    assertEq(
      bobWethDataBefore.suppliedShares,
      hub.convertToSuppliedShares(wethAssetId, wethSupplyAmount)
    );
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    // Time passes
    skip(skipTime);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));

    assertGe(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');
    assertEq(bobDaiBefore.premiumDebt, 0, 'bob dai premium debt before');

    // Bob repays
    uint256 bobDaiBaseDebt = bobDaiBefore.baseDebt - daiBorrowAmount;
    daiRepayAmount = bound(daiRepayAmount, 0, bobDaiBaseDebt);
    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      bobDaiBaseDebt,
      0,
      daiRepayAmount,
      daiAssetId
    );
    deal(address(tokenList.dai), bob, daiRepayAmount);

    if (daiRepayAmount == 0) {
      vm.expectRevert(ILiquidityHub.InvalidRestoreAmount.selector);
    } else {
      vm.expectEmit(address(spoke1));
      emit ISpoke.Repay(
        _daiReserveId(spoke1),
        bob,
        bob,
        hub.convertToDrawnShares(daiAssetId, baseRestored)
      );
    }

    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount, bob);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
      spoke1,
      bob,
      _wethReserveId(spoke1)
    );
    Debts memory bobDaiAfter = getUserDebt(spoke1, bob, _daiReserveId(spoke1));

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertApproxEqAbs(
      bobDaiAfter.baseDebt,
      daiRepayAmount >= bobDaiBefore.baseDebt ? 0 : bobDaiBefore.baseDebt - baseRestored,
      1,
      'bob dai base debt final balance'
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

    // repays only base debt
    assertGe(
      bobDaiAfter.baseDebt,
      daiRepayAmount >= bobDaiBefore.baseDebt ? 0 : bobDaiBefore.baseDebt - daiRepayAmount,
      'bob dai base debt final balance'
    );
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
    skipTime = uint40(bound(skipTime, 1, MAX_SKIP_TIME));

    daiInfo.repayAmount = daiInfo.borrowAmount.percentMulUp(repayPortion);
    wethInfo.repayAmount = wethInfo.borrowAmount.percentMulUp(repayPortion);
    usdxInfo.repayAmount = usdxInfo.borrowAmount.percentMulUp(repayPortion);
    wbtcInfo.repayAmount = wbtcInfo.borrowAmount.percentMulUp(repayPortion);

    // weth collateral for dai and usdx
    // wbtc collateral for weth and wbtc
    // calculate weth collateral
    // calculate wbtc collateral
    {
      uint256 wethSupplyAmount = _calcMinimumCollAmount(
        spoke1,
        _wethReserveId(spoke1),
        _daiReserveId(spoke1),
        daiInfo.borrowAmount
      ) +
        _calcMinimumCollAmount(
          spoke1,
          _wethReserveId(spoke1),
          _usdxReserveId(spoke1),
          usdxInfo.borrowAmount
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

    // Repayments
    vm.startPrank(bob);
    daiInfo.posBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    assertGe(bobDaiBefore.totalDebt, daiInfo.borrowAmount);
    if (daiInfo.repayAmount > 0) {
      (daiInfo.baseRestored, daiInfo.premiumRestored) = _calculateExactRestoreAmount(
        bobDaiBefore.baseDebt,
        bobDaiBefore.premiumDebt,
        daiInfo.repayAmount,
        daiAssetId
      );
      deal(address(tokenList.dai), bob, daiInfo.repayAmount);
      spoke1.repay(_daiReserveId(spoke1), daiInfo.repayAmount, bob);
    }
    Debts memory bobDaiAfter = getUserDebt(spoke1, bob, _daiReserveId(spoke1));

    wethInfo.posBefore = getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    bobWethBefore = getUserDebt(spoke1, bob, _wethReserveId(spoke1));
    assertGe(bobWethBefore.totalDebt, wethInfo.borrowAmount);
    if (wethInfo.repayAmount > 0) {
      (wethInfo.baseRestored, wethInfo.premiumRestored) = _calculateExactRestoreAmount(
        bobWethBefore.baseDebt,
        bobWethBefore.premiumDebt,
        wethInfo.repayAmount,
        wethAssetId
      );
      deal(address(tokenList.weth), bob, wethInfo.repayAmount);
      spoke1.repay(_wethReserveId(spoke1), wethInfo.repayAmount, bob);
    }
    Debts memory bobWethAfter = getUserDebt(spoke1, bob, _wethReserveId(spoke1));

    wbtcInfo.posBefore = getUserInfo(spoke1, bob, _wbtcReserveId(spoke1));
    bobWbtcBefore = getUserDebt(spoke1, bob, _wbtcReserveId(spoke1));
    assertGe(bobWbtcBefore.totalDebt, wbtcInfo.borrowAmount);
    if (wbtcInfo.repayAmount > 0) {
      (wbtcInfo.baseRestored, wbtcInfo.premiumRestored) = _calculateExactRestoreAmount(
        bobWbtcBefore.baseDebt,
        bobWbtcBefore.premiumDebt,
        wbtcInfo.repayAmount,
        wbtcAssetId
      );
      deal(address(tokenList.wbtc), bob, wbtcInfo.repayAmount);
      spoke1.repay(_wbtcReserveId(spoke1), wbtcInfo.repayAmount, bob);
    }
    Debts memory bobWbtcAfter = getUserDebt(spoke1, bob, _wbtcReserveId(spoke1));

    usdxInfo.posBefore = getUserInfo(spoke1, bob, _usdxReserveId(spoke1));
    bobUsdxBefore = getUserDebt(spoke1, bob, _usdxReserveId(spoke1));
    assertGe(bobUsdxBefore.totalDebt, usdxInfo.borrowAmount);
    if (usdxInfo.repayAmount > 0) {
      (usdxInfo.baseRestored, usdxInfo.premiumRestored) = _calculateExactRestoreAmount(
        bobUsdxBefore.baseDebt,
        bobUsdxBefore.premiumDebt,
        usdxInfo.repayAmount,
        usdxAssetId
      );
      deal(address(tokenList.usdx), bob, usdxInfo.repayAmount);
      spoke1.repay(_usdxReserveId(spoke1), usdxInfo.repayAmount, bob);
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
        bobDaiAfter.baseDebt,
        bobDaiBefore.baseDebt - daiInfo.baseRestored,
        1,
        'bob dai base debt final balance'
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
        bobWethAfter.baseDebt,
        bobWethBefore.baseDebt - wethInfo.baseRestored,
        1,
        'bob weth base debt final balance'
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
        bobUsdxAfter.baseDebt,
        usdxInfo.baseRestored >= bobUsdxBefore.baseDebt
          ? 0
          : bobUsdxBefore.baseDebt - usdxInfo.baseRestored,
        1,
        'bob usdx base debt final balance'
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
        bobWbtcAfter.baseDebt,
        wbtcInfo.baseRestored >= bobWbtcBefore.baseDebt
          ? 0
          : bobWbtcBefore.baseDebt - wbtcInfo.baseRestored,
        1,
        'bob wbtc base debt final balance'
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
    vm.stopPrank();

    _repayAll(spoke1, _daiReserveId);
    _repayAll(spoke1, _wethReserveId);
    _repayAll(spoke1, _usdxReserveId);
    _repayAll(spoke1, _wbtcReserveId);
  }

  // Borrow X amount, receive Y Shares. Repay all, ensure Y shares repaid
  function test_fuzz_repay_x_y_shares(uint256 borrowAmount, uint40 skipTime) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 10);
    skipTime = uint40(bound(skipTime, 1, MAX_SKIP_TIME));

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

    uint256 expectedDrawnShares = hub.convertToDrawnShares(daiAssetId, borrowAmount);

    // Bob borrow dai
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, borrowAmount, bob);

    DataTypes.UserPosition memory bobDaiDataBefore = getUserInfo(
      spoke1,
      bob,
      _daiReserveId(spoke1)
    );
    assertEq(bobDaiDataBefore.baseDrawnShares, expectedDrawnShares, 'bob drawn shares');
    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore + borrowAmount,
      'bob dai balance after borrow'
    );

    // Time passes
    skip(skipTime);

    // Bob should still have same number of drawn shares
    assertEq(
      spoke1.getUserPosition(_daiReserveId(spoke1), bob).baseDrawnShares,
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

    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
      _daiReserveId(spoke1),
      bob,
      bob,
      hub.convertToDrawnShares(daiAssetId, baseRestored)
    );
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), type(uint256).max, bob);

    // Bob should have 0 drawn shares
    assertEq(
      spoke1.getUserPosition(_daiReserveId(spoke1), bob).baseDrawnShares,
      0,
      'bob drawn shares after repay'
    );
    // Bob's debt should be 0
    assertEq(spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob), 0, 'bob total debt after repay');
  }
}
