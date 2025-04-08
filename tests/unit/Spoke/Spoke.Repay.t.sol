// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeRepayTest is SpokeBase {
  using PercentageMath for uint256;

  struct Debts {
    uint256 baseDebt;
    uint256 premiumDebt;
    uint256 totalDebt;
  }

  struct RepayMultipleLocal {
    uint256 borrowAmount;
    uint256 repayAmount;
    DataTypes.UserPosition posBefore; // positionBefore
    DataTypes.UserPosition posAfter; // positionAfter
    uint256 premiumRestored;
  }

  struct Action {
    uint256 supplyAmount;
    uint256 borrowAmount;
    uint256 repayAmount;
    uint40 skipTime;
  }

  struct AssetInfo {
    uint256 borrowAmount;
    uint256 repayAmount;
    uint256 premiumRestored;
    uint256 suppliedShares;
  }

  struct UserAction {
    uint256 suppliedShares;
    uint256 borrowAmount;
    uint256 repayAmount;
    uint256 premiumRestored;
    address user;
  }

  struct UserAssetInfo {
    AssetInfo daiInfo;
    AssetInfo wethInfo;
    AssetInfo usdxInfo;
    AssetInfo wbtcInfo;
    address user;
  }

  function test_repay_all_with_accruals() public {
    vm.startPrank(bob);

    uint256 supplyAmount = 5000e18;
    spoke1.supply(_daiReserveId(spoke1), supplyAmount);
    spoke1.setUsingAsCollateral(_daiReserveId(spoke1), true);

    uint256 borrowAmount = 1000e18;
    spoke1.borrow(_daiReserveId(spoke1), borrowAmount, bob);

    skip(365 days);
    spoke1.getUserDebt(_daiReserveId(spoke1), bob);

    spoke1.repay(_daiReserveId(spoke1), borrowAmount);

    skip(365 days);

    DataTypes.UserPosition memory pos = spoke1.getUserPosition(_daiReserveId(spoke1), bob);
    assertGt(pos.baseDrawnShares, 0, 'user baseDrawnShares after repay');
    assertGt(hub.convertToDrawnAssets(daiAssetId, pos.baseDrawnShares), 0, 'user baseDrawnAssets');

    spoke1.repay(_daiReserveId(spoke1), type(uint256).max);

    pos = spoke1.getUserPosition(_daiReserveId(spoke1), bob);
    assertEq(pos.baseDrawnShares, 0, 'user baseDrawnShares after full repay');
    assertEq(hub.convertToDrawnAssets(daiAssetId, pos.baseDrawnShares), 0, 'user baseDrawnAssets');
    assertEq(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      0,
      'user total debt after full repay'
    );

    vm.stopPrank();
  }

  function test_riskPremium_postActions() public {
    vm.startPrank(alice);
    spoke1.supply(_daiReserveId(spoke1), 1000e18);
    vm.stopPrank();

    vm.startPrank(bob);
    spoke1.setUsingAsCollateral(_daiReserveId(spoke1), true);
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true);

    spoke1.supply(_daiReserveId(spoke1), 1000e18);
    spoke1.supply(_usdxReserveId(spoke1), 1000e6);

    spoke1.borrow(_daiReserveId(spoke1), 500e18, bob);
    _assertUserRpUnchanged(_daiReserveId(spoke1), spoke1, bob);
    spoke1.borrow(_usdxReserveId(spoke1), 750e6, bob);
    _assertUserRpUnchanged(_usdxReserveId(spoke1), spoke1, bob);

    skip(123 days);

    spoke1.withdraw(_daiReserveId(spoke1), 0.01e18, bob);
    _assertUserRpUnchanged(_daiReserveId(spoke1), spoke1, bob);
    _assertUserRpUnchanged(_usdxReserveId(spoke1), spoke1, bob);

    spoke1.withdraw(_usdxReserveId(spoke1), 0.01e6, bob);
    _assertUserRpUnchanged(_daiReserveId(spoke1), spoke1, bob);
    _assertUserRpUnchanged(_usdxReserveId(spoke1), spoke1, bob);

    skip(232 days);

    spoke1.repay(_daiReserveId(spoke1), 25e18);
    _assertUserRpUnchanged(_daiReserveId(spoke1), spoke1, bob);
    _assertUserRpUnchanged(_usdxReserveId(spoke1), spoke1, bob);

    vm.stopPrank();
  }

  function test_repay_same_block() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;
    uint256 daiRepayAmount = daiSupplyAmount / 4;

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
    emit ISpoke.Repay(_daiReserveId(spoke1), bob, daiRepayAmount);
    vm.startPrank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);
    vm.stopPrank();

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

  function test_repay() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;
    uint256 daiRepayAmount = daiSupplyAmount / 4;

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
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.baseDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    assertGe(bobDaiBefore.baseDebt, daiBorrowAmount, 'bob dai debt before');

    (uint256 baseRestored, uint256 premiumRestored) = _calculateRestoreAmount(
      bobDaiBefore.baseDebt,
      bobDaiBefore.premiumDebt,
      daiRepayAmount
    );

    // Bob repays half of principal debt
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
      _daiReserveId(spoke1),
      bob,
      hub.convertToDrawnShares(daiAssetId, baseRestored)
    );
    vm.startPrank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);
    vm.stopPrank();

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
      spoke1,
      bob,
      _wethReserveId(spoke1)
    );

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      bobDaiBefore.baseDebt + bobDaiBefore.premiumDebt - daiRepayAmount,
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

  function test_repay_revertsWith_ReserveNotActive() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;

    updateReserveActiveFlag(spoke1, daiReserveId, false);
    assertFalse(spoke1.getReserve(daiReserveId).config.active);

    vm.expectRevert(ISpoke.ReserveNotActive.selector);
    vm.startPrank(bob);
    spoke1.repay(daiReserveId, amount);
    vm.stopPrank();
  }

  function test_repay_revertsWith_ReservePaused() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;

    updateReservePausedFlag(spoke1, daiReserveId, true);
    assertTrue(spoke1.getReserve(daiReserveId).config.paused);

    vm.expectRevert(ISpoke.ReservePaused.selector);
    vm.startPrank(bob);
    spoke1.repay(daiReserveId, amount);
    vm.stopPrank();
  }

  function test_repay_revertsWith_ReserveNotListed() public {
    uint256 reserveId = spoke1.reserveCount() + 1; // invalid reserveId
    uint256 amount = 100e18;

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.startPrank(bob);
    spoke1.repay(reserveId, amount);
    vm.stopPrank();
  }

  /// repay all debt interest
  function test_repay_only_interest() public {
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

    // Bob repays interest
    uint256 daiRepayAmount = bobDaiBefore.baseDebt + bobDaiBefore.premiumDebt - daiBorrowAmount;
    assertGt(daiRepayAmount, 0); // interest is not zero

    (uint256 baseRestored, ) = _calculateRestoreAmount(
      bobDaiBefore.baseDebt,
      bobDaiBefore.premiumDebt,
      daiRepayAmount
    );

    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
      _daiReserveId(spoke1),
      bob,
      hub.convertToDrawnShares(daiAssetId, baseRestored)
    );
    vm.startPrank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);
    vm.stopPrank();

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
    assertEq(bobDaiAfter.premiumDebt, 0, 'bob dai premium debt final balance');
    assertEq(bobDaiAfter.baseDebt, daiBorrowAmount, 'bob dai base debt final balance');
    assertEq(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      daiBorrowAmount,
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
  function test_repay_only_premium(uint256 daiBorrowAmount, uint40 skipTime) public {
    uint256 daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      daiBorrowAmount
    );
    skipTime = uint40(bound(skipTime, 1, MAX_SKIP_TIME));

    // Bob supply weth as collateral
    Utils.supply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

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
    emit ISpoke.Repay(_daiReserveId(spoke1), bob, 0);
    vm.startPrank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);
    vm.stopPrank();

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
      spoke1,
      bob,
      _wethReserveId(spoke1)
    );

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      bobDaiBaseDebtBefore + bobDaiPremiumDebtBefore - daiRepayAmount,
      'bob dai debt final balance'
    );
    (, uint256 bobDaiPremiumDebtAfter) = spoke1.getUserDebt(_daiReserveId(spoke1), bob);
    assertEq(
      bobDaiPremiumDebtAfter,
      bobDaiPremiumDebtBefore - daiRepayAmount,
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
      hub.convertToDrawnShares(daiAssetId, bobDaiBefore.baseDebt)
    );

    // Bob repays using the max value to signal full repayment
    vm.startPrank(bob);
    spoke1.repay(_daiReserveId(spoke1), type(uint256).max);
    vm.stopPrank();

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    Debts memory bobDaiAfter;
    bobDaiAfter.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiAfter.baseDebt, bobDaiAfter.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    uint256 bobDaiBalanceAfter = tokenList.dai.balanceOf(bob);

    // Verify that Bob's debt is fully cleared after repayment
    assertEq(bobDaiAfter.totalDebt, 0, 'Bob dai debt should be cleared');

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

  function test_repay_partial_then_max() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;

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
    uint256 partialRepayAmount = fullDebt / 2;

    (uint256 baseRestored, ) = _calculateRestoreAmount(
      bobDaiBefore.baseDebt,
      bobDaiBefore.premiumDebt,
      partialRepayAmount
    );

    // Partial repay
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
      _daiReserveId(spoke1),
      bob,
      hub.convertToDrawnShares(daiAssetId, baseRestored)
    );

    vm.startPrank(bob);
    spoke1.repay(_daiReserveId(spoke1), partialRepayAmount);
    vm.stopPrank();

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    Debts memory bobDaiAfter;
    bobDaiAfter.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiAfter.baseDebt, bobDaiAfter.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    uint256 bobDaiBalanceAfter = tokenList.dai.balanceOf(bob);

    // Verify that Bob's debt is reduced after partial repayment
    assertEq(
      bobDaiAfter.totalDebt,
      fullDebt - partialRepayAmount,
      'Bob dai debt should be reduced'
    );
    // Verify that his DAI balance was reduced by the partial debt amount
    assertEq(
      bobDaiBalanceAfter,
      bobDaiBalanceBefore - partialRepayAmount,
      'Bob dai balance decreased by partial debt repaid'
    );
    // Verify reserve debt was decreased by partial repayment
    assertEq(spoke1.getReserveTotalDebt(_daiReserveId(spoke1)), fullDebt - partialRepayAmount);

    // verify LH asset debt is decreased by partial repayment
    assertEq(hub.getAssetTotalDebt(_daiReserveId(spoke1)), fullDebt - partialRepayAmount);

    (baseRestored, ) = _calculateRestoreAmount(
      bobDaiAfter.baseDebt,
      bobDaiAfter.premiumDebt,
      bobDaiAfter.totalDebt
    );

    // Full repay
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
      _daiReserveId(spoke1),
      bob,
      hub.convertToDrawnShares(daiAssetId, baseRestored)
    );

    // Bob repays using the max value to signal full repayment
    vm.startPrank(bob);
    spoke1.repay(_daiReserveId(spoke1), type(uint256).max);
    vm.stopPrank();

    bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiAfter.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiAfter.baseDebt, bobDaiAfter.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    bobDaiBalanceAfter = tokenList.dai.balanceOf(bob);

    // Verify that Bob's debt is fully cleared after repayment
    assertEq(bobDaiAfter.totalDebt, 0, 'Bob dai debt should be cleared');

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
    assertEq(hub.getAssetTotalDebt(_daiReserveId(spoke1)), 0);
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
    Debts memory bobDaiBefore;
    Debts memory bobWethBefore;

    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.baseDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    bobWethBefore.totalDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob);

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

    (uint256 repaidBase, uint256 repaidPremium) = _calculateRestoreAmount(
      bobDaiBefore.baseDebt,
      bobDaiBefore.premiumDebt,
      repayAmount
    );

    // Ensure we are trying to repay a nonzero base amount, less than 1 share
    assertGt(repaidBase, 0, 'Base debt nonzero');

    vm.startPrank(bob);
    spoke1.repay(_daiReserveId(spoke1), repayAmount);
    vm.stopPrank();
  }

  // repay less than 1 share of base debt, but nonzero premium debt
  function test_repay_zero_shares_nonzero_premium_debt() public {
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
    skip(55 days);

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

    (uint256 repaidBase, uint256 repaidPremium) = _calculateRestoreAmount(
      bobDaiBefore.baseDebt,
      bobDaiBefore.premiumDebt,
      repayAmount
    );

    // If repay amount is less than 1 share, then it must all be premium debt
    assertEq(repaidBase, 0, 'Base debt nonzero');
    assertGt(repaidPremium, 0, 'Premium debt zero');

    // Repay
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(_daiReserveId(spoke1), bob, 0);

    vm.startPrank(bob);
    spoke1.repay(_daiReserveId(spoke1), repayAmount);
    vm.stopPrank();

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

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      bobDaiBefore.totalDebt - repayAmount,
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

    // Bob repays premium
    vm.startPrank(bob);
    spoke1.repay(_daiReserveId(spoke1), bobDaiBefore.premiumDebt);
    vm.stopPrank();

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.baseDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );

    assertEq(bobDaiBefore.premiumDebt, 0);

    // Bob repays base debt
    uint256 daiRepayAmount = bobDaiBefore.baseDebt - daiBorrowAmount;
    assertGt(daiRepayAmount, 0); // interest is not zero

    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
      _daiReserveId(spoke1),
      bob,
      hub.convertToDrawnShares(daiAssetId, daiRepayAmount)
    );
    vm.startPrank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);
    vm.stopPrank();

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
    vm.startPrank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);
    vm.stopPrank();

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

  /// repay all or a portion of total debt in same block
  function test_repay_same_block_fuzz_amounts(
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
    Utils.supply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

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

    (uint256 baseRestored, uint256 premiumRestored) = _calculateRestoreAmount(
      bobDaiBefore.baseDebt,
      bobDaiBefore.premiumDebt,
      daiRepayAmount
    );

    // Bob repays
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
      _daiReserveId(spoke1),
      bob,
      hub.convertToDrawnShares(daiAssetId, baseRestored)
    );
    vm.startPrank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);
    vm.stopPrank();

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
  }

  /// repay all or a portion of total debt - handles partial base debt repay case
  function test_repay_fuzz_amountsAndWait(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount,
    uint40 skipTime
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
    Utils.supply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

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

    (uint256 baseRestored, uint256 premiumRestored) = _calculateRestoreAmount(
      bobDaiBefore.baseDebt,
      bobDaiBefore.premiumDebt,
      daiRepayAmount
    );

    // Bob repays
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
      _daiReserveId(spoke1),
      bob,
      hub.convertToDrawnShares(daiAssetId, baseRestored)
    );
    vm.startPrank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);
    vm.stopPrank();

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

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(
      bobDaiAfter.totalDebt,
      bobDaiBefore.totalDebt - daiRepayAmount,
      'bob dai debt final balance'
    );

    // If any base debt was repaid, then premium debt must be zero
    if (baseRestored > 0) {
      assertEq(bobDaiAfter.premiumDebt, 0, 'bob dai premium debt final balance when base repaid');
    }

    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - daiRepayAmount,
      'bob dai final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);
  }

  /// repay all or a portion of debt interest
  function test_repay_fuzz_amounts_only_interest(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount,
    uint40 skipTime
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);

    // calculate weth collateral
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      daiBorrowAmount
    );

    // Bob supply weth
    Utils.supply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

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
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.baseDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    assertGe(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');

    // Bob repays
    uint256 bobDaiInterest = bobDaiBefore.baseDebt + bobDaiBefore.premiumDebt - daiBorrowAmount;
    daiRepayAmount = bound(daiRepayAmount, 0, bobDaiInterest);
    (uint256 baseRepaid, uint256 premiumRepaid) = _calculateRestoreAmount(
      bobDaiBefore.baseDebt,
      bobDaiBefore.premiumDebt,
      daiRepayAmount
    );

    deal(address(tokenList.dai), bob, daiRepayAmount);

    if (daiRepayAmount == 0) {
      vm.expectRevert(ILiquidityHub.InvalidRestoreAmount.selector);
    } else {
      vm.expectEmit(address(spoke1));
      emit ISpoke.Repay(
        _daiReserveId(spoke1),
        bob,
        hub.convertToDrawnShares(daiAssetId, baseRepaid)
      );
    }
    vm.startPrank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);
    vm.stopPrank();

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

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(
      bobDaiAfter.totalDebt,
      daiRepayAmount >= bobDaiBefore.totalDebt ? 0 : bobDaiBefore.totalDebt - daiRepayAmount,
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
  function test_repay_fuzz_amounts_only_premium(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount,
    uint40 skipTime
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);

    // calculate weth collateral
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      daiBorrowAmount
    );

    // Bob supply weth
    Utils.supply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

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
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.baseDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    assertGe(bobDaiBefore.totalDebt, daiBorrowAmount, 'bob dai debt before');

    // Bob repays
    uint256 bobDaiPremium = bobDaiBefore.premiumDebt;
    if (bobDaiPremium == 0) {
      // not enough time travel for premium accrual
      daiRepayAmount = 0;
      deal(address(tokenList.dai), bob, daiRepayAmount);
      vm.expectRevert(ILiquidityHub.InvalidRestoreAmount.selector);
    } else {
      // interest is at least 1
      daiRepayAmount = bound(daiRepayAmount, 1, bobDaiPremium);
      deal(address(tokenList.dai), bob, daiRepayAmount);
      vm.expectEmit(address(spoke1));
      emit ISpoke.Repay(_daiReserveId(spoke1), bob, 0);
    }

    vm.startPrank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);
    vm.stopPrank();

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

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(bobDaiAfter.baseDebt, bobDaiBefore.baseDebt, 'bob dai base debt final balance');
    assertEq(
      bobDaiAfter.premiumDebt,
      bobDaiBefore.premiumDebt - daiRepayAmount,
      'bob dai premium debt final balance'
    );
    assertEq(
      bobDaiAfter.baseDebt + bobDaiAfter.premiumDebt,
      bobDaiBefore.baseDebt + bobDaiBefore.premiumDebt - daiRepayAmount,
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

    // calculate weth collateral
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      daiBorrowAmount
    );

    // Bob supply weth
    Utils.supply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

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

    // Bob repays premium first if any
    if (bobDaiBefore.premiumDebt > 0) {
      deal(address(tokenList.dai), bob, bobDaiBefore.premiumDebt);
      vm.startPrank(bob);
      spoke1.repay(_daiReserveId(spoke1), bobDaiBefore.premiumDebt);
      vm.stopPrank();
    }

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.baseDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );

    assertEq(bobDaiBefore.premiumDebt, 0);

    // Bob repays
    uint256 bobDaiBaseDebt = bobDaiBefore.baseDebt - daiBorrowAmount;
    daiRepayAmount = bound(daiRepayAmount, 0, bobDaiBaseDebt);
    deal(address(tokenList.dai), bob, daiRepayAmount);
    if (daiRepayAmount == 0) {
      vm.expectRevert(ILiquidityHub.InvalidRestoreAmount.selector);
    } else {
      vm.expectEmit(address(spoke1));
      emit ISpoke.Repay(
        _daiReserveId(spoke1),
        bob,
        hub.convertToDrawnShares(daiAssetId, daiRepayAmount)
      );
    }

    vm.startPrank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);
    vm.stopPrank();

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

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(
      bobDaiAfter.baseDebt,
      daiRepayAmount >= bobDaiBefore.baseDebt ? 0 : bobDaiBefore.baseDebt - daiRepayAmount,
      'bob dai base debt final balance'
    );
    assertEq(bobDaiAfter.premiumDebt, 0, 'bob dai premium debt final balance');
    assertEq(
      bobDaiAfter.totalDebt,
      daiRepayAmount >= bobDaiBefore.totalDebt ? 0 : bobDaiBefore.totalDebt - daiRepayAmount,
      'bob dai debt final balance'
    );
    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    assertEq(tokenList.dai.balanceOf(bob), 0, 'bob dai final balance');
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

    // repays only base debt
    assertEq(
      bobDaiAfter.baseDebt,
      daiRepayAmount >= bobDaiBefore.baseDebt ? 0 : bobDaiBefore.baseDebt - daiRepayAmount,
      'bob dai base debt final balance'
    );
  }

  /// repay all or a portion of accrued base debt when premium debt is zero
  function test_repay_fuzz_amounts_base_debt_no_premium(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount,
    uint40 skipTime
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);

    // update liquidity premium to zero
    updateLiquidityPremium(spoke1, _wethReserveId(spoke1), 0);

    // calculate weth collateral
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      daiBorrowAmount
    );

    // Bob supply weth
    Utils.supply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

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
    assertEq(bobDaiBefore.premiumDebt, 0, 'bob dai premium debt before');

    // Bob repays
    uint256 bobDaiBaseDebt = bobDaiBefore.baseDebt - daiBorrowAmount;
    daiRepayAmount = bound(daiRepayAmount, 0, bobDaiBaseDebt);

    deal(address(tokenList.dai), bob, daiRepayAmount);

    if (daiRepayAmount == 0) {
      vm.expectRevert(ILiquidityHub.InvalidRestoreAmount.selector);
    } else {
      vm.expectEmit(address(spoke1));
      emit ISpoke.Repay(
        _daiReserveId(spoke1),
        bob,
        hub.convertToDrawnShares(daiAssetId, daiRepayAmount)
      );
    }

    vm.startPrank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);
    vm.stopPrank();

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

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(
      bobDaiAfter.baseDebt,
      daiRepayAmount >= bobDaiBefore.baseDebt ? 0 : bobDaiBefore.baseDebt - daiRepayAmount,
      'bob dai base debt final balance'
    );
    assertEq(bobDaiAfter.premiumDebt, 0, 'bob dai premium debt final balance');
    assertEq(
      bobDaiAfter.totalDebt,
      daiRepayAmount >= bobDaiBefore.totalDebt ? 0 : bobDaiBefore.totalDebt - daiRepayAmount,
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

    daiInfo.repayAmount = daiInfo.borrowAmount.percentMul(repayPortion);
    wethInfo.repayAmount = wethInfo.borrowAmount.percentMul(repayPortion);
    usdxInfo.repayAmount = usdxInfo.borrowAmount.percentMul(repayPortion);
    wbtcInfo.repayAmount = wbtcInfo.borrowAmount.percentMul(repayPortion);

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
      Utils.supply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
      setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);
      deal(address(tokenList.wbtc), bob, wbtcSupplyAmount);
      Utils.supply(spoke1, _wbtcReserveId(spoke1), bob, wbtcSupplyAmount, bob);
      setUsingAsCollateral(spoke1, bob, _wbtcReserveId(spoke1), true);
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

    Debts memory bobDaiBefore;
    Debts memory bobWethBefore;
    Debts memory bobUsdxBefore;
    Debts memory bobWbtcBefore;

    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    bobWethBefore.totalDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob);
    bobUsdxBefore.totalDebt = spoke1.getUserTotalDebt(_usdxReserveId(spoke1), bob);
    bobWbtcBefore.totalDebt = spoke1.getUserTotalDebt(_wbtcReserveId(spoke1), bob);

    (bobDaiBefore.baseDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    (bobWethBefore.baseDebt, bobWethBefore.premiumDebt) = spoke1.getUserDebt(
      _wethReserveId(spoke1),
      bob
    );
    (bobUsdxBefore.baseDebt, bobUsdxBefore.premiumDebt) = spoke1.getUserDebt(
      _usdxReserveId(spoke1),
      bob
    );
    (bobWbtcBefore.baseDebt, bobWbtcBefore.premiumDebt) = spoke1.getUserDebt(
      _wbtcReserveId(spoke1),
      bob
    );

    assertEq(bobDaiBefore.totalDebt, daiInfo.borrowAmount);
    assertEq(bobWethBefore.totalDebt, wethInfo.borrowAmount);
    assertEq(bobWbtcBefore.totalDebt, wbtcInfo.borrowAmount);
    assertEq(bobUsdxBefore.totalDebt, usdxInfo.borrowAmount);

    // Time passes
    skip(skipTime);

    daiInfo.posBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    wethInfo.posBefore = getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    usdxInfo.posBefore = getUserInfo(spoke1, bob, _usdxReserveId(spoke1));
    wbtcInfo.posBefore = getUserInfo(spoke1, bob, _wbtcReserveId(spoke1));

    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    bobWethBefore.totalDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob);
    bobUsdxBefore.totalDebt = spoke1.getUserTotalDebt(_usdxReserveId(spoke1), bob);
    bobWbtcBefore.totalDebt = spoke1.getUserTotalDebt(_wbtcReserveId(spoke1), bob);

    (bobDaiBefore.baseDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    (bobWethBefore.baseDebt, bobWethBefore.premiumDebt) = spoke1.getUserDebt(
      _wethReserveId(spoke1),
      bob
    );
    (bobUsdxBefore.baseDebt, bobUsdxBefore.premiumDebt) = spoke1.getUserDebt(
      _usdxReserveId(spoke1),
      bob
    );
    (bobWbtcBefore.baseDebt, bobWbtcBefore.premiumDebt) = spoke1.getUserDebt(
      _wbtcReserveId(spoke1),
      bob
    );

    assertGe(bobDaiBefore.totalDebt, daiInfo.borrowAmount);
    assertGe(bobWethBefore.totalDebt, wethInfo.borrowAmount);
    assertGe(bobWbtcBefore.totalDebt, wbtcInfo.borrowAmount);
    assertGe(bobUsdxBefore.totalDebt, usdxInfo.borrowAmount);

    // Repayments
    vm.startPrank(bob);
    if (daiInfo.repayAmount > 0) {
      deal(address(tokenList.dai), bob, daiInfo.repayAmount);
      spoke1.repay(_daiReserveId(spoke1), daiInfo.repayAmount);
    }
    if (wethInfo.repayAmount > 0) {
      deal(address(tokenList.weth), bob, wethInfo.repayAmount);
      spoke1.repay(_wethReserveId(spoke1), wethInfo.repayAmount);
    }
    if (wbtcInfo.repayAmount > 0) {
      deal(address(tokenList.wbtc), bob, wbtcInfo.repayAmount);
      spoke1.repay(_wbtcReserveId(spoke1), wbtcInfo.repayAmount);
    }
    if (usdxInfo.repayAmount > 0) {
      deal(address(tokenList.usdx), bob, usdxInfo.repayAmount);
      spoke1.repay(_usdxReserveId(spoke1), usdxInfo.repayAmount);
    }

    daiInfo.posAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    wethInfo.posAfter = getUserInfo(spoke1, bob, _wethReserveId(spoke1));
    usdxInfo.posAfter = getUserInfo(spoke1, bob, _usdxReserveId(spoke1));
    wbtcInfo.posAfter = getUserInfo(spoke1, bob, _wbtcReserveId(spoke1));

    Debts memory bobDaiAfter;
    Debts memory bobWethAfter;
    Debts memory bobUsdxAfter;
    Debts memory bobWbtcAfter;

    bobDaiAfter.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    bobWethAfter.totalDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob);
    bobUsdxAfter.totalDebt = spoke1.getUserTotalDebt(_usdxReserveId(spoke1), bob);
    bobWbtcAfter.totalDebt = spoke1.getUserTotalDebt(_wbtcReserveId(spoke1), bob);

    (bobDaiAfter.baseDebt, bobDaiAfter.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    (bobWethAfter.baseDebt, bobWethAfter.premiumDebt) = spoke1.getUserDebt(
      _wethReserveId(spoke1),
      bob
    );
    (bobUsdxAfter.baseDebt, bobUsdxAfter.premiumDebt) = spoke1.getUserDebt(
      _usdxReserveId(spoke1),
      bob
    );
    (bobWbtcAfter.baseDebt, bobWbtcAfter.premiumDebt) = spoke1.getUserDebt(
      _wbtcReserveId(spoke1),
      bob
    );

    // collateral remains the same
    assertEq(daiInfo.posAfter.suppliedShares, daiInfo.posBefore.suppliedShares);
    assertEq(wethInfo.posAfter.suppliedShares, wethInfo.posBefore.suppliedShares);
    assertEq(usdxInfo.posAfter.suppliedShares, usdxInfo.posBefore.suppliedShares);
    assertEq(wbtcInfo.posAfter.suppliedShares, wbtcInfo.posBefore.suppliedShares);

    // debt
    if (daiInfo.repayAmount > 0) {
      assertEq(
        bobDaiAfter.totalDebt,
        bobDaiBefore.totalDebt - daiInfo.repayAmount,
        'bob dai debt final balance'
      );
    } else {
      assertEq(bobDaiAfter.totalDebt, bobDaiBefore.totalDebt);
    }
    if (wethInfo.repayAmount > 0) {
      assertEq(
        bobWethAfter.totalDebt,
        bobWethBefore.totalDebt - wethInfo.repayAmount,
        'bob weth debt final balance'
      );
    } else {
      assertEq(bobWethAfter.totalDebt, bobWethBefore.totalDebt);
    }
    if (usdxInfo.repayAmount > 0) {
      assertEq(
        bobUsdxAfter.totalDebt,
        bobUsdxBefore.totalDebt - usdxInfo.repayAmount,
        'bob usdx debt final balance'
      );
    } else {
      assertEq(bobUsdxAfter.totalDebt, bobUsdxBefore.totalDebt);
    }
    if (wbtcInfo.repayAmount > 0) {
      assertEq(
        bobWbtcAfter.totalDebt,
        bobWbtcBefore.totalDebt - wbtcInfo.repayAmount,
        'bob wbtc debt final balance'
      );
    } else {
      assertEq(bobWbtcAfter.totalDebt, bobWbtcBefore.totalDebt);
    }
  }

  /// Borrow, repay, borrow more, repay
  function test_repay_borrow_twice_repay_twice(
    Action memory action1,
    Action memory action2
  ) public {
    action1.skipTime = uint40(bound(action1.skipTime, 1, MAX_SKIP_TIME / 2));
    action2.skipTime = uint40(bound(action2.skipTime, 1, MAX_SKIP_TIME / 2));
    action1.borrowAmount = bound(action1.borrowAmount, 1, MAX_SUPPLY_AMOUNT / 4);
    action2.borrowAmount = bound(action2.borrowAmount, 1, MAX_SUPPLY_AMOUNT / 4);
    action1.repayAmount = bound(action1.repayAmount, 1, action1.borrowAmount);
    action2.repayAmount = bound(action2.repayAmount, 1, action2.borrowAmount);

    // Enough funds to cover 2 repayments
    deal(address(tokenList.dai), bob, action1.repayAmount + action2.repayAmount);

    // Bob supply weth as collateral
    action1.supplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      action1.borrowAmount
    );
    Utils.supply(spoke1, _wethReserveId(spoke1), bob, action1.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.supply(
      spoke1,
      _daiReserveId(spoke1),
      alice,
      action1.borrowAmount + action2.borrowAmount,
      alice
    );

    // Bob borrow dai
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, action1.borrowAmount, bob);

    DataTypes.UserPosition memory bobDaiDataBefore = getUserInfo(
      spoke1,
      bob,
      _daiReserveId(spoke1)
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
    assertEq(bobDaiBefore.totalDebt, action1.borrowAmount, 'bob dai debt before');
    assertEq(
      spoke1.getUserSuppliedShares(_wethReserveId(spoke1), bob),
      hub.convertToSuppliedShares(wethAssetId, action1.supplyAmount)
    );
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);
    assertEq(bobDaiBefore.premiumDebt, 0, 'bob dai premium debt before');

    // Time passes
    skip(action1.skipTime);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.baseDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    assertGe(bobDaiBefore.totalDebt, action1.borrowAmount, 'bob dai debt before');
    assertGe(bobDaiBefore.premiumDebt, 0, 'bob dai premium debt before');

    // Bob repays the first repay amount
    (uint256 baseRestored, uint256 premiumRestored) = _calculateRestoreAmount(
      bobDaiBefore.baseDebt,
      bobDaiBefore.premiumDebt,
      action1.repayAmount
    );

    if (action1.repayAmount == 0) {
      vm.expectRevert(ILiquidityHub.InvalidRestoreAmount.selector);
    } else {
      vm.expectEmit(address(spoke1));
      emit ISpoke.Repay(
        _daiReserveId(spoke1),
        bob,
        hub.convertToDrawnShares(daiAssetId, baseRestored)
      );
    }

    vm.startPrank(bob);
    spoke1.repay(_daiReserveId(spoke1), action1.repayAmount);
    vm.stopPrank();

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    Debts memory bobDaiAfter;
    bobDaiAfter.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiAfter.baseDebt, bobDaiAfter.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(
      bobDaiAfter.totalDebt,
      bobDaiBefore.totalDebt - action1.repayAmount,
      'bob dai debt final balance'
    );
    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - action1.repayAmount,
      'bob dai final balance'
    );
    assertEq(
      spoke1.getUserSuppliedShares(_wethReserveId(spoke1), bob),
      hub.convertToSuppliedShares(wethAssetId, action1.supplyAmount)
    );
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

    // Supply more collateral if not enough
    {
      uint256 totalCollateral = _calcMinimumCollAmount(
        spoke1,
        _wethReserveId(spoke1),
        _daiReserveId(spoke1),
        spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob) + action2.borrowAmount
      );
      action2.supplyAmount = action1.supplyAmount > totalCollateral
        ? 0
        : totalCollateral - action1.supplyAmount;
      if (action2.supplyAmount > 0) {
        Utils.supply(spoke1, _wethReserveId(spoke1), bob, action2.supplyAmount, bob);
      }
    }

    // Reuse variables for second borrow and repay round
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);

    // Bob borrows more dai
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, action2.borrowAmount, bob);

    assertEq(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      bobDaiBefore.totalDebt + action2.borrowAmount,
      'bob dai debt after second borrow'
    );

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.baseDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(
      spoke1.getUserSuppliedShares(_wethReserveId(spoke1), bob),
      hub.convertToSuppliedShares(wethAssetId, action1.supplyAmount + action2.supplyAmount)
    );
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    // Time passes
    skip(action2.skipTime);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    assertGe(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      bobDaiBefore.totalDebt,
      'bob dai debt before second repay'
    );
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.baseDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );

    // Bob repays the second repay amount
    (baseRestored, premiumRestored) = _calculateRestoreAmount(
      bobDaiBefore.baseDebt,
      bobDaiBefore.premiumDebt,
      action2.repayAmount
    );

    if (action2.repayAmount == 0) {
      vm.expectRevert(ILiquidityHub.InvalidRestoreAmount.selector);
    } else {
      vm.expectEmit(address(spoke1));
      emit ISpoke.Repay(
        _daiReserveId(spoke1),
        bob,
        hub.convertToDrawnShares(daiAssetId, baseRestored)
      );
    }

    vm.startPrank(bob);
    spoke1.repay(_daiReserveId(spoke1), action2.repayAmount);
    vm.stopPrank();

    bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiAfter.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(
      bobDaiAfter.totalDebt,
      bobDaiBefore.totalDebt - action2.repayAmount,
      'bob dai debt final balance'
    );
    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - action2.repayAmount,
      'bob dai final balance'
    );
    assertEq(
      spoke1.getUserSuppliedShares(_wethReserveId(spoke1), bob),
      hub.convertToSuppliedShares(wethAssetId, action1.supplyAmount + action2.supplyAmount)
    );
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);
  }

  // Borrow X amount, receive Y Shares. Repay all, ensure Y shares repaid
  function test_repay_x_y_shares(uint256 borrowAmount, uint40 skipTime) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
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
    Utils.supply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supply dai
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
      hub.convertToDrawnShares(daiAssetId, baseRestored)
    );
    vm.startPrank(bob);
    spoke1.repay(_daiReserveId(spoke1), type(uint256).max);
    vm.stopPrank();

    // Bob should have 0 drawn shares
    assertEq(
      spoke1.getUserPosition(_daiReserveId(spoke1), bob).baseDrawnShares,
      0,
      'bob drawn shares after repay'
    );
    // Bob's debt should be 0
    assertEq(spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob), 0, 'bob total debt after repay');
  }

  function test_repay_multiple_users_multiple_assets(
    UserAssetInfo memory bobInfo,
    UserAssetInfo memory aliceInfo,
    UserAssetInfo memory carolInfo,
    uint40 skipTime
  ) public {
    vm.skip(true, 'Pending fix for underflow issue');
    bobInfo = _bound(bobInfo);
    aliceInfo = _bound(aliceInfo);
    carolInfo = _bound(carolInfo);
    skipTime = uint40(bound(skipTime, 1, MAX_SKIP_TIME));

    // Assign user addresses to the structs
    bobInfo.user = bob;
    aliceInfo.user = alice;
    carolInfo.user = carol;

    // Put structs into array
    UserAssetInfo[3] memory usersInfo = [bobInfo, aliceInfo, carolInfo];

    // Calculate needed supply for each asset
    uint256 totalDaiNeeded = 0;
    uint256 totalWethNeeded = 0;
    uint256 totalUsdxNeeded = 0;
    uint256 totalWbtcNeeded = 0;

    for (uint256 i = 0; i < usersInfo.length; i++) {
      totalDaiNeeded += usersInfo[i].daiInfo.borrowAmount;
      totalWethNeeded += usersInfo[i].wethInfo.borrowAmount;
      totalUsdxNeeded += usersInfo[i].usdxInfo.borrowAmount;
      totalWbtcNeeded += usersInfo[i].wbtcInfo.borrowAmount;
    }

    // Derl supplies needed assets
    Utils.supply(spoke1, _daiReserveId(spoke1), derl, totalDaiNeeded, derl);
    Utils.supply(spoke1, _wethReserveId(spoke1), derl, totalWethNeeded, derl);
    Utils.supply(spoke1, _usdxReserveId(spoke1), derl, totalUsdxNeeded, derl);
    Utils.supply(spoke1, _wbtcReserveId(spoke1), derl, totalWbtcNeeded, derl);

    // Each user supplies collateral and borrows
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // Calculate needed collateral for this user
      uint256 wethCollateralNeeded = 0;
      uint256 wbtcCollateralNeeded = 0;

      if (usersInfo[i].daiInfo.borrowAmount > 0) {
        wethCollateralNeeded += _calcMinimumCollAmount(
          spoke1,
          _wethReserveId(spoke1),
          _daiReserveId(spoke1),
          usersInfo[i].daiInfo.borrowAmount
        );
      }

      if (usersInfo[i].usdxInfo.borrowAmount > 0) {
        wethCollateralNeeded += _calcMinimumCollAmount(
          spoke1,
          _wethReserveId(spoke1),
          _usdxReserveId(spoke1),
          usersInfo[i].usdxInfo.borrowAmount
        );
      }

      if (usersInfo[i].wethInfo.borrowAmount > 0) {
        wbtcCollateralNeeded += _calcMinimumCollAmount(
          spoke1,
          _wbtcReserveId(spoke1),
          _wethReserveId(spoke1),
          usersInfo[i].wethInfo.borrowAmount
        );
      }

      if (usersInfo[i].wbtcInfo.borrowAmount > 0) {
        wbtcCollateralNeeded += _calcMinimumCollAmount(
          spoke1,
          _wbtcReserveId(spoke1),
          _wbtcReserveId(spoke1),
          usersInfo[i].wbtcInfo.borrowAmount
        );
      }

      // Supply weth and wbtc as collateral
      if (wethCollateralNeeded > 0) {
        deal(address(tokenList.weth), user, wethCollateralNeeded);
        Utils.supply(spoke1, _wethReserveId(spoke1), user, wethCollateralNeeded, user);
        setUsingAsCollateral(spoke1, user, _wethReserveId(spoke1), true);
      }

      if (wbtcCollateralNeeded > 0) {
        deal(address(tokenList.wbtc), user, wbtcCollateralNeeded);
        Utils.supply(spoke1, _wbtcReserveId(spoke1), user, wbtcCollateralNeeded, user);
        setUsingAsCollateral(spoke1, user, _wbtcReserveId(spoke1), true);
      }

      // Borrow assets based on fuzzed amounts
      if (usersInfo[i].daiInfo.borrowAmount > 0) {
        Utils.borrow(spoke1, _daiReserveId(spoke1), user, usersInfo[i].daiInfo.borrowAmount, user);
      }

      if (usersInfo[i].wethInfo.borrowAmount > 0) {
        Utils.borrow(
          spoke1,
          _wethReserveId(spoke1),
          user,
          usersInfo[i].wethInfo.borrowAmount,
          user
        );
      }

      if (usersInfo[i].usdxInfo.borrowAmount > 0) {
        Utils.borrow(
          spoke1,
          _usdxReserveId(spoke1),
          user,
          usersInfo[i].usdxInfo.borrowAmount,
          user
        );
      }

      if (usersInfo[i].wbtcInfo.borrowAmount > 0) {
        Utils.borrow(
          spoke1,
          _wbtcReserveId(spoke1),
          user,
          usersInfo[i].wbtcInfo.borrowAmount,
          user
        );
      }

      // Store supply positions before time skipping
      usersInfo[i].daiInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _daiReserveId(spoke1),
        user
      );
      usersInfo[i].wethInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _wethReserveId(spoke1),
        user
      );
      usersInfo[i].usdxInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _usdxReserveId(spoke1),
        user
      );
      usersInfo[i].wbtcInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _wbtcReserveId(spoke1),
        user
      );

      // Verify initial borrowing state
      uint256 totalDaiDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), user);
      assertEq(totalDaiDebt, usersInfo[i].daiInfo.borrowAmount, 'Initial DAI debt incorrect');

      uint256 totalWethDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), user);
      assertEq(totalWethDebt, usersInfo[i].wethInfo.borrowAmount, 'Initial WETH debt incorrect');

      uint256 totalUsdxDebt = spoke1.getUserTotalDebt(_usdxReserveId(spoke1), user);
      assertEq(totalUsdxDebt, usersInfo[i].usdxInfo.borrowAmount, 'Initial USDX debt incorrect');

      uint256 totalWbtcDebt = spoke1.getUserTotalDebt(_wbtcReserveId(spoke1), user);
      assertEq(totalWbtcDebt, usersInfo[i].wbtcInfo.borrowAmount, 'Initial WBTC debt incorrect');
    }

    // Time passes, interest accrues
    skip(skipTime);

    // Fetch current debts before repayment
    Debts[4][3] memory debtsBefore; // 4 assets, 3 users
    // [dai, weth, usdx, wbtc] order
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // Get updated supply positions after interest accrual
      usersInfo[i].daiInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _daiReserveId(spoke1),
        user
      );
      usersInfo[i].wethInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _wethReserveId(spoke1),
        user
      );
      usersInfo[i].usdxInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _usdxReserveId(spoke1),
        user
      );
      usersInfo[i].wbtcInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _wbtcReserveId(spoke1),
        user
      );

      // Store debts before repayment
      debtsBefore[i][0].totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), user);
      (debtsBefore[i][0].baseDebt, debtsBefore[i][0].premiumDebt) = spoke1.getUserDebt(
        _daiReserveId(spoke1),
        user
      );
      debtsBefore[i][1].totalDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), user);
      (debtsBefore[i][1].baseDebt, debtsBefore[i][1].premiumDebt) = spoke1.getUserDebt(
        _wethReserveId(spoke1),
        user
      );
      debtsBefore[i][2].totalDebt = spoke1.getUserTotalDebt(_usdxReserveId(spoke1), user);
      (debtsBefore[i][2].baseDebt, debtsBefore[i][2].premiumDebt) = spoke1.getUserDebt(
        _usdxReserveId(spoke1),
        user
      );
      debtsBefore[i][3].totalDebt = spoke1.getUserTotalDebt(_wbtcReserveId(spoke1), user);
      (debtsBefore[i][3].baseDebt, debtsBefore[i][3].premiumDebt) = spoke1.getUserDebt(
        _wbtcReserveId(spoke1),
        user
      );

      // Verify interest accrual
      assertGe(
        debtsBefore[i][0].totalDebt,
        usersInfo[i].daiInfo.borrowAmount,
        'DAI debt should accrue interest'
      );

      assertGe(
        debtsBefore[i][1].totalDebt,
        usersInfo[i].wethInfo.borrowAmount,
        'WETH debt should accrue interest'
      );

      assertGe(
        debtsBefore[i][2].totalDebt,
        usersInfo[i].usdxInfo.borrowAmount,
        'USDX debt should accrue interest'
      );

      assertGe(
        debtsBefore[i][3].totalDebt,
        usersInfo[i].wbtcInfo.borrowAmount,
        'WBTC debt should accrue interest'
      );
    }

    // Repayments
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // DAI repayment
      (uint256 baseRestored, uint256 premiumRestored) = _calculateRestoreAmount(
        debtsBefore[i][0].baseDebt,
        debtsBefore[i][0].premiumDebt,
        usersInfo[i].daiInfo.repayAmount
      );
      usersInfo[i].daiInfo.premiumRestored = premiumRestored;
      if (baseRestored >= minimumAssetsPerDrawnShare(daiAssetId) || premiumRestored > 0) {
        deal(address(tokenList.dai), user, usersInfo[i].daiInfo.repayAmount);
        vm.startPrank(user);
        spoke1.repay(_daiReserveId(spoke1), usersInfo[i].daiInfo.repayAmount);
        vm.stopPrank();
      }

      // WETH repayment
      (baseRestored, premiumRestored) = _calculateRestoreAmount(
        debtsBefore[i][1].baseDebt,
        debtsBefore[i][1].premiumDebt,
        usersInfo[i].wethInfo.repayAmount
      );
      usersInfo[i].wethInfo.premiumRestored = premiumRestored;
      if (baseRestored >= minimumAssetsPerDrawnShare(wethAssetId) || premiumRestored > 0) {
        deal(address(tokenList.weth), user, usersInfo[i].wethInfo.repayAmount);
        vm.startPrank(user);
        spoke1.repay(_wethReserveId(spoke1), usersInfo[i].wethInfo.repayAmount);
        vm.stopPrank();
      }

      // USDX repayment
      (baseRestored, premiumRestored) = _calculateRestoreAmount(
        debtsBefore[i][2].baseDebt,
        debtsBefore[i][2].premiumDebt,
        usersInfo[i].usdxInfo.repayAmount
      );
      usersInfo[i].usdxInfo.premiumRestored = premiumRestored;
      if (baseRestored >= minimumAssetsPerDrawnShare(usdxAssetId) || premiumRestored > 0) {
        deal(address(tokenList.usdx), user, usersInfo[i].usdxInfo.repayAmount);
        vm.startPrank(user);
        spoke1.repay(_usdxReserveId(spoke1), usersInfo[i].usdxInfo.repayAmount);
        vm.stopPrank();
      }

      // WBTC repayment
      (baseRestored, premiumRestored) = _calculateRestoreAmount(
        debtsBefore[i][3].baseDebt,
        debtsBefore[i][3].premiumDebt,
        usersInfo[i].wbtcInfo.repayAmount
      );
      usersInfo[i].wbtcInfo.premiumRestored = premiumRestored;
      if (baseRestored >= minimumAssetsPerDrawnShare(wbtcAssetId) || premiumRestored > 0) {
        deal(address(tokenList.wbtc), user, usersInfo[i].wbtcInfo.repayAmount);
        vm.startPrank(user);
        spoke1.repay(_wbtcReserveId(spoke1), usersInfo[i].wbtcInfo.repayAmount);
        vm.stopPrank();
      }
    }

    // Verify final state for each user
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // Verify repayments have been applied correctly
      if (
        usersInfo[i].daiInfo.repayAmount >= minimumAssetsPerDrawnShare(daiAssetId) ||
        usersInfo[i].daiInfo.premiumRestored > 0
      ) {
        uint256 expectedDaiDebt = usersInfo[i].daiInfo.repayAmount >= debtsBefore[i][0].totalDebt
          ? 0
          : debtsBefore[i][0].totalDebt - usersInfo[i].daiInfo.repayAmount;
        uint256 actualDaiDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), user);
        assertEq(actualDaiDebt, expectedDaiDebt, 'DAI debt not reduced correctly');
      }

      if (
        usersInfo[i].wethInfo.repayAmount >= minimumAssetsPerDrawnShare(wethAssetId) ||
        usersInfo[i].wethInfo.premiumRestored > 0
      ) {
        uint256 expectedWethDebt = usersInfo[i].wethInfo.repayAmount >= debtsBefore[i][1].totalDebt
          ? 0
          : debtsBefore[i][1].totalDebt - usersInfo[i].wethInfo.repayAmount;
        uint256 actualWethDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), user);
        assertEq(actualWethDebt, expectedWethDebt, 'WETH debt not reduced correctly');
      }

      if (
        usersInfo[i].usdxInfo.repayAmount >= minimumAssetsPerDrawnShare(usdxAssetId) ||
        usersInfo[i].usdxInfo.premiumRestored > 0
      ) {
        uint256 expectedUsdxDebt = usersInfo[i].usdxInfo.repayAmount >= debtsBefore[i][2].totalDebt
          ? 0
          : debtsBefore[i][2].totalDebt - usersInfo[i].usdxInfo.repayAmount;
        uint256 actualUsdxDebt = spoke1.getUserTotalDebt(_usdxReserveId(spoke1), user);
        assertEq(actualUsdxDebt, expectedUsdxDebt, 'USDX debt not reduced correctly');
      }

      if (
        usersInfo[i].wbtcInfo.repayAmount >= minimumAssetsPerDrawnShare(wbtcAssetId) ||
        usersInfo[i].wbtcInfo.premiumRestored > 0
      ) {
        uint256 expectedWbtcDebt = usersInfo[i].wbtcInfo.repayAmount >= debtsBefore[i][3].totalDebt
          ? 0
          : debtsBefore[i][3].totalDebt - usersInfo[i].wbtcInfo.repayAmount;
        uint256 actualWbtcDebt = spoke1.getUserTotalDebt(_wbtcReserveId(spoke1), user);
        assertEq(actualWbtcDebt, expectedWbtcDebt, 'WBTC debt not reduced correctly');
      }

      // Verify supply positions remain unchanged
      assertEq(
        spoke1.getUserSuppliedShares(_daiReserveId(spoke1), user),
        usersInfo[i].daiInfo.suppliedShares,
        'DAI supplied shares should remain unchanged'
      );
      assertEq(
        spoke1.getUserSuppliedShares(_wethReserveId(spoke1), user),
        usersInfo[i].wethInfo.suppliedShares,
        'WETH supplied shares should remain unchanged'
      );
      assertEq(
        spoke1.getUserSuppliedShares(_usdxReserveId(spoke1), user),
        usersInfo[i].usdxInfo.suppliedShares,
        'USDX supplied shares should remain unchanged'
      );
      assertEq(
        spoke1.getUserSuppliedShares(_wbtcReserveId(spoke1), user),
        usersInfo[i].wbtcInfo.suppliedShares,
        'WBTC supplied shares should remain unchanged'
      );
    }
  }

  function test_repay_two_users_multiple_assets(
    UserAssetInfo memory bobInfo,
    UserAssetInfo memory aliceInfo,
    uint40 skipTime
  ) public {
    vm.skip(true, 'Pending fix for underflow issue');
    bobInfo = _bound(bobInfo);
    aliceInfo = _bound(aliceInfo);
    skipTime = uint40(bound(skipTime, 1, MAX_SKIP_TIME));

    // Assign user addresses to the structs
    bobInfo.user = bob;
    aliceInfo.user = alice;

    // Put structs into array
    UserAssetInfo[2] memory usersInfo = [bobInfo, aliceInfo];

    // Calculate needed supply for each asset
    uint256 totalDaiNeeded = 0;
    uint256 totalWethNeeded = 0;
    uint256 totalUsdxNeeded = 0;
    uint256 totalWbtcNeeded = 0;

    for (uint256 i = 0; i < usersInfo.length; i++) {
      totalDaiNeeded += usersInfo[i].daiInfo.borrowAmount;
      totalWethNeeded += usersInfo[i].wethInfo.borrowAmount;
      totalUsdxNeeded += usersInfo[i].usdxInfo.borrowAmount;
      totalWbtcNeeded += usersInfo[i].wbtcInfo.borrowAmount;
    }

    // Derl supplies needed assets
    Utils.supply(spoke1, _daiReserveId(spoke1), derl, totalDaiNeeded, derl);
    Utils.supply(spoke1, _wethReserveId(spoke1), derl, totalWethNeeded, derl);
    Utils.supply(spoke1, _usdxReserveId(spoke1), derl, totalUsdxNeeded, derl);
    Utils.supply(spoke1, _wbtcReserveId(spoke1), derl, totalWbtcNeeded, derl);

    // Each user supplies collateral and borrows
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // Calculate needed collateral for this user
      uint256 wethCollateralNeeded = 0;
      uint256 wbtcCollateralNeeded = 0;

      if (usersInfo[i].daiInfo.borrowAmount > 0) {
        wethCollateralNeeded += _calcMinimumCollAmount(
          spoke1,
          _wethReserveId(spoke1),
          _daiReserveId(spoke1),
          usersInfo[i].daiInfo.borrowAmount
        );
      }

      if (usersInfo[i].usdxInfo.borrowAmount > 0) {
        wethCollateralNeeded += _calcMinimumCollAmount(
          spoke1,
          _wethReserveId(spoke1),
          _usdxReserveId(spoke1),
          usersInfo[i].usdxInfo.borrowAmount
        );
      }

      if (usersInfo[i].wethInfo.borrowAmount > 0) {
        wbtcCollateralNeeded += _calcMinimumCollAmount(
          spoke1,
          _wbtcReserveId(spoke1),
          _wethReserveId(spoke1),
          usersInfo[i].wethInfo.borrowAmount
        );
      }

      if (usersInfo[i].wbtcInfo.borrowAmount > 0) {
        wbtcCollateralNeeded += _calcMinimumCollAmount(
          spoke1,
          _wbtcReserveId(spoke1),
          _wbtcReserveId(spoke1),
          usersInfo[i].wbtcInfo.borrowAmount
        );
      }

      // Supply weth and wbtc as collateral
      if (wethCollateralNeeded > 0) {
        deal(address(tokenList.weth), user, wethCollateralNeeded);
        Utils.supply(spoke1, _wethReserveId(spoke1), user, wethCollateralNeeded, user);
        setUsingAsCollateral(spoke1, user, _wethReserveId(spoke1), true);
      }

      if (wbtcCollateralNeeded > 0) {
        deal(address(tokenList.wbtc), user, wbtcCollateralNeeded);
        Utils.supply(spoke1, _wbtcReserveId(spoke1), user, wbtcCollateralNeeded, user);
        setUsingAsCollateral(spoke1, user, _wbtcReserveId(spoke1), true);
      }

      // Borrow assets based on fuzzed amounts
      if (usersInfo[i].daiInfo.borrowAmount > 0) {
        Utils.borrow(spoke1, _daiReserveId(spoke1), user, usersInfo[i].daiInfo.borrowAmount, user);
      }

      if (usersInfo[i].wethInfo.borrowAmount > 0) {
        Utils.borrow(
          spoke1,
          _wethReserveId(spoke1),
          user,
          usersInfo[i].wethInfo.borrowAmount,
          user
        );
      }

      if (usersInfo[i].usdxInfo.borrowAmount > 0) {
        Utils.borrow(
          spoke1,
          _usdxReserveId(spoke1),
          user,
          usersInfo[i].usdxInfo.borrowAmount,
          user
        );
      }

      if (usersInfo[i].wbtcInfo.borrowAmount > 0) {
        Utils.borrow(
          spoke1,
          _wbtcReserveId(spoke1),
          user,
          usersInfo[i].wbtcInfo.borrowAmount,
          user
        );
      }

      // Store supply positions before time skipping
      usersInfo[i].daiInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _daiReserveId(spoke1),
        user
      );
      usersInfo[i].wethInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _wethReserveId(spoke1),
        user
      );
      usersInfo[i].usdxInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _usdxReserveId(spoke1),
        user
      );
      usersInfo[i].wbtcInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _wbtcReserveId(spoke1),
        user
      );

      // Verify initial borrowing state
      uint256 totalDaiDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), user);
      assertEq(totalDaiDebt, usersInfo[i].daiInfo.borrowAmount, 'Initial DAI debt incorrect');

      uint256 totalWethDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), user);
      assertEq(totalWethDebt, usersInfo[i].wethInfo.borrowAmount, 'Initial WETH debt incorrect');

      uint256 totalUsdxDebt = spoke1.getUserTotalDebt(_usdxReserveId(spoke1), user);
      assertEq(totalUsdxDebt, usersInfo[i].usdxInfo.borrowAmount, 'Initial USDX debt incorrect');

      uint256 totalWbtcDebt = spoke1.getUserTotalDebt(_wbtcReserveId(spoke1), user);
      assertEq(totalWbtcDebt, usersInfo[i].wbtcInfo.borrowAmount, 'Initial WBTC debt incorrect');
    }

    // Time passes, interest accrues
    skip(skipTime);

    // Fetch current debts before repayment
    Debts[4][2] memory debtsBefore; // 4 assets, 2 users
    // [dai, weth, usdx, wbtc] order
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // Get updated supply positions after interest accrual
      usersInfo[i].daiInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _daiReserveId(spoke1),
        user
      );
      usersInfo[i].wethInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _wethReserveId(spoke1),
        user
      );
      usersInfo[i].usdxInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _usdxReserveId(spoke1),
        user
      );
      usersInfo[i].wbtcInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _wbtcReserveId(spoke1),
        user
      );

      // Store debts before repayment
      debtsBefore[i][0].totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), user);
      (debtsBefore[i][0].baseDebt, debtsBefore[i][0].premiumDebt) = spoke1.getUserDebt(
        _daiReserveId(spoke1),
        user
      );
      debtsBefore[i][1].totalDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), user);
      (debtsBefore[i][1].baseDebt, debtsBefore[i][1].premiumDebt) = spoke1.getUserDebt(
        _wethReserveId(spoke1),
        user
      );
      debtsBefore[i][2].totalDebt = spoke1.getUserTotalDebt(_usdxReserveId(spoke1), user);
      (debtsBefore[i][2].baseDebt, debtsBefore[i][2].premiumDebt) = spoke1.getUserDebt(
        _usdxReserveId(spoke1),
        user
      );
      debtsBefore[i][3].totalDebt = spoke1.getUserTotalDebt(_wbtcReserveId(spoke1), user);
      (debtsBefore[i][3].baseDebt, debtsBefore[i][3].premiumDebt) = spoke1.getUserDebt(
        _wbtcReserveId(spoke1),
        user
      );

      // Verify interest accrual
      assertGe(
        debtsBefore[i][0].totalDebt,
        usersInfo[i].daiInfo.borrowAmount,
        'DAI debt should accrue interest'
      );

      assertGe(
        debtsBefore[i][1].totalDebt,
        usersInfo[i].wethInfo.borrowAmount,
        'WETH debt should accrue interest'
      );

      assertGe(
        debtsBefore[i][2].totalDebt,
        usersInfo[i].usdxInfo.borrowAmount,
        'USDX debt should accrue interest'
      );

      assertGe(
        debtsBefore[i][3].totalDebt,
        usersInfo[i].wbtcInfo.borrowAmount,
        'WBTC debt should accrue interest'
      );
    }

    // Repayments
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // DAI repayment
      (uint256 baseRestored, uint256 premiumRestored) = _calculateRestoreAmount(
        debtsBefore[i][0].baseDebt,
        debtsBefore[i][0].premiumDebt,
        usersInfo[i].daiInfo.repayAmount
      );
      usersInfo[i].daiInfo.premiumRestored = premiumRestored;
      if (baseRestored >= minimumAssetsPerDrawnShare(daiAssetId) || premiumRestored > 0) {
        deal(address(tokenList.dai), user, usersInfo[i].daiInfo.repayAmount);
        vm.startPrank(user);
        spoke1.repay(_daiReserveId(spoke1), usersInfo[i].daiInfo.repayAmount);
        vm.stopPrank();
      }

      // WETH repayment
      (baseRestored, premiumRestored) = _calculateRestoreAmount(
        debtsBefore[i][1].baseDebt,
        debtsBefore[i][1].premiumDebt,
        usersInfo[i].wethInfo.repayAmount
      );
      usersInfo[i].wethInfo.premiumRestored = premiumRestored;
      if (baseRestored >= minimumAssetsPerDrawnShare(wethAssetId) || premiumRestored > 0) {
        deal(address(tokenList.weth), user, usersInfo[i].wethInfo.repayAmount);
        vm.startPrank(user);
        spoke1.repay(_wethReserveId(spoke1), usersInfo[i].wethInfo.repayAmount);
        vm.stopPrank();
      }

      // USDX repayment
      (baseRestored, premiumRestored) = _calculateRestoreAmount(
        debtsBefore[i][2].baseDebt,
        debtsBefore[i][2].premiumDebt,
        usersInfo[i].usdxInfo.repayAmount
      );
      usersInfo[i].usdxInfo.premiumRestored = premiumRestored;
      if (baseRestored >= minimumAssetsPerDrawnShare(usdxAssetId) || premiumRestored > 0) {
        deal(address(tokenList.usdx), user, usersInfo[i].usdxInfo.repayAmount);
        vm.startPrank(user);
        spoke1.repay(_usdxReserveId(spoke1), usersInfo[i].usdxInfo.repayAmount);
        vm.stopPrank();
      }

      // WBTC repayment
      (baseRestored, premiumRestored) = _calculateRestoreAmount(
        debtsBefore[i][3].baseDebt,
        debtsBefore[i][3].premiumDebt,
        usersInfo[i].wbtcInfo.repayAmount
      );
      usersInfo[i].wbtcInfo.premiumRestored = premiumRestored;
      if (baseRestored >= minimumAssetsPerDrawnShare(wbtcAssetId) || premiumRestored > 0) {
        deal(address(tokenList.wbtc), user, usersInfo[i].wbtcInfo.repayAmount);
        vm.startPrank(user);
        spoke1.repay(_wbtcReserveId(spoke1), usersInfo[i].wbtcInfo.repayAmount);
        vm.stopPrank();
      }
    }

    // Verify final state for each user
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // Verify repayments have been applied correctly
      if (
        usersInfo[i].daiInfo.repayAmount >= minimumAssetsPerDrawnShare(daiAssetId) ||
        usersInfo[i].daiInfo.premiumRestored > 0
      ) {
        uint256 expectedDaiDebt = usersInfo[i].daiInfo.repayAmount >= debtsBefore[i][0].totalDebt
          ? 0
          : debtsBefore[i][0].totalDebt - usersInfo[i].daiInfo.repayAmount;
        uint256 actualDaiDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), user);
        assertEq(actualDaiDebt, expectedDaiDebt, 'DAI debt not reduced correctly');
      }

      if (
        usersInfo[i].wethInfo.repayAmount >= minimumAssetsPerDrawnShare(wethAssetId) ||
        usersInfo[i].wethInfo.premiumRestored > 0
      ) {
        uint256 expectedWethDebt = usersInfo[i].wethInfo.repayAmount >= debtsBefore[i][1].totalDebt
          ? 0
          : debtsBefore[i][1].totalDebt - usersInfo[i].wethInfo.repayAmount;
        uint256 actualWethDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), user);
        assertEq(actualWethDebt, expectedWethDebt, 'WETH debt not reduced correctly');
      }

      if (
        usersInfo[i].usdxInfo.repayAmount >= minimumAssetsPerDrawnShare(usdxAssetId) ||
        usersInfo[i].usdxInfo.premiumRestored > 0
      ) {
        uint256 expectedUsdxDebt = usersInfo[i].usdxInfo.repayAmount >= debtsBefore[i][2].totalDebt
          ? 0
          : debtsBefore[i][2].totalDebt - usersInfo[i].usdxInfo.repayAmount;
        uint256 actualUsdxDebt = spoke1.getUserTotalDebt(_usdxReserveId(spoke1), user);
        assertEq(actualUsdxDebt, expectedUsdxDebt, 'USDX debt not reduced correctly');
      }

      if (
        usersInfo[i].wbtcInfo.repayAmount >= minimumAssetsPerDrawnShare(wbtcAssetId) ||
        usersInfo[i].wbtcInfo.premiumRestored > 0
      ) {
        uint256 expectedWbtcDebt = usersInfo[i].wbtcInfo.repayAmount >= debtsBefore[i][3].totalDebt
          ? 0
          : debtsBefore[i][3].totalDebt - usersInfo[i].wbtcInfo.repayAmount;
        uint256 actualWbtcDebt = spoke1.getUserTotalDebt(_wbtcReserveId(spoke1), user);
        assertEq(actualWbtcDebt, expectedWbtcDebt, 'WBTC debt not reduced correctly');
      }

      // Verify supply positions remain unchanged
      assertEq(
        spoke1.getUserSuppliedShares(_daiReserveId(spoke1), user),
        usersInfo[i].daiInfo.suppliedShares,
        'DAI supplied shares should remain unchanged'
      );
      assertEq(
        spoke1.getUserSuppliedShares(_wethReserveId(spoke1), user),
        usersInfo[i].wethInfo.suppliedShares,
        'WETH supplied shares should remain unchanged'
      );
      assertEq(
        spoke1.getUserSuppliedShares(_usdxReserveId(spoke1), user),
        usersInfo[i].usdxInfo.suppliedShares,
        'USDX supplied shares should remain unchanged'
      );
      assertEq(
        spoke1.getUserSuppliedShares(_wbtcReserveId(spoke1), user),
        usersInfo[i].wbtcInfo.suppliedShares,
        'WBTC supplied shares should remain unchanged'
      );
    }
  }

  function test_repay_multiple_users_repay_same_reserve(
    UserAction memory bobInfo,
    UserAction memory aliceInfo,
    UserAction memory carolInfo,
    uint256 skipTime
  ) public {
    vm.skip(true, 'Pending fix for underflow issue');
    // Bound borrow and repay amounts
    bobInfo = _boundUserAction(bobInfo);
    aliceInfo = _boundUserAction(aliceInfo);
    carolInfo = _boundUserAction(carolInfo);

    skipTime = uint40(bound(skipTime, 1, MAX_SKIP_TIME));

    // Assign user addresses to the structs
    bobInfo.user = bob;
    aliceInfo.user = alice;
    carolInfo.user = carol;

    // Put structs into array
    UserAction[3] memory usersInfo = [bobInfo, aliceInfo, carolInfo];

    // Calculate needed supply for DAI
    uint256 totalDaiNeeded = bobInfo.borrowAmount + aliceInfo.borrowAmount + carolInfo.borrowAmount;

    // Derl supplies needed DAI
    Utils.supply(spoke1, _daiReserveId(spoke1), derl, totalDaiNeeded, derl);

    // Each user supplies needed collateral and borrows
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // Calculate needed collateral for this user
      uint256 wethCollateralNeeded = _calcMinimumCollAmount(
        spoke1,
        _wethReserveId(spoke1),
        _daiReserveId(spoke1),
        usersInfo[i].borrowAmount
      );

      // Supply WETH as collateral
      deal(address(tokenList.weth), user, wethCollateralNeeded);
      Utils.supply(spoke1, _wethReserveId(spoke1), user, wethCollateralNeeded, user);
      setUsingAsCollateral(spoke1, user, _wethReserveId(spoke1), true);

      usersInfo[i].suppliedShares = spoke1.getUserSuppliedShares(_wethReserveId(spoke1), user);

      // Borrow DAI based on fuzzed amounts
      Utils.borrow(spoke1, _daiReserveId(spoke1), user, usersInfo[i].borrowAmount, user);

      // Verify initial borrowing state
      uint256 totalDaiDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), user);
      assertEq(totalDaiDebt, usersInfo[i].borrowAmount, 'Initial DAI debt incorrect');
    }

    // Time passes, interest accrues
    skip(skipTime);

    // Fetch current debts before repayment
    Debts[3] memory debtsBefore; // 3 users
    // [bob, alice, carol] order
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // Store debts before repayment
      debtsBefore[i].totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), user);
      (debtsBefore[i].baseDebt, debtsBefore[i].premiumDebt) = spoke1.getUserDebt(
        _daiReserveId(spoke1),
        user
      );

      // Verify interest accrual
      assertGe(
        debtsBefore[i].totalDebt,
        usersInfo[i].borrowAmount,
        'DAI debt should accrue interest'
      );
    }

    // Repayments
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // DAI repayment
      (uint256 baseRestored, uint256 premiumRestored) = _calculateRestoreAmount(
        debtsBefore[i].baseDebt,
        debtsBefore[i].premiumDebt,
        usersInfo[i].repayAmount
      );
      usersInfo[i].premiumRestored = premiumRestored;
      if (baseRestored >= minimumAssetsPerDrawnShare(daiAssetId) || premiumRestored > 0) {
        deal(address(tokenList.dai), user, usersInfo[i].repayAmount);
        vm.startPrank(user);
        spoke1.repay(_daiReserveId(spoke1), usersInfo[i].repayAmount);
        vm.stopPrank();
      }
    }

    // Verify final state for each user
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // Verify repayments have been applied correctly
      if (
        usersInfo[i].repayAmount >= minimumAssetsPerDrawnShare(daiAssetId) ||
        usersInfo[i].premiumRestored > 0
      ) {
        uint256 expectedDaiDebt = usersInfo[i].repayAmount >= debtsBefore[i].totalDebt
          ? 0
          : debtsBefore[i].totalDebt - usersInfo[i].repayAmount;
        uint256 actualDaiDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), user);
        assertEq(actualDaiDebt, expectedDaiDebt, 'DAI debt not reduced correctly');
      }

      // Verify supply positions remain unchanged
      assertEq(
        spoke1.getUserSuppliedShares(_wethReserveId(spoke1), user),
        usersInfo[i].suppliedShares,
        'WETH supplied shares should remain unchanged'
      );
    }
  }

  function test_repay_two_users_repay_same_reserve(
    UserAction memory bobInfo,
    UserAction memory aliceInfo,
    uint256 skipTime
  ) public {
    vm.skip(true, 'Pending fix for underflow issue');
    // Bound borrow and repay amounts
    bobInfo = _boundUserAction(bobInfo);
    aliceInfo = _boundUserAction(aliceInfo);

    skipTime = uint40(bound(skipTime, 1, MAX_SKIP_TIME));

    // Assign user addresses to the structs
    bobInfo.user = bob;
    aliceInfo.user = alice;

    // Put structs into array
    UserAction[2] memory usersInfo = [bobInfo, aliceInfo];

    // Calculate needed supply for DAI
    uint256 totalDaiNeeded = bobInfo.borrowAmount + aliceInfo.borrowAmount;

    // Derl supplies needed DAI
    Utils.supply(spoke1, _daiReserveId(spoke1), derl, totalDaiNeeded, derl);

    // Each user supplies needed collateral and borrows
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // Calculate needed collateral for this user
      uint256 wethCollateralNeeded = _calcMinimumCollAmount(
        spoke1,
        _wethReserveId(spoke1),
        _daiReserveId(spoke1),
        usersInfo[i].borrowAmount
      );

      // Supply WETH as collateral
      deal(address(tokenList.weth), user, wethCollateralNeeded);
      Utils.supply(spoke1, _wethReserveId(spoke1), user, wethCollateralNeeded, user);
      setUsingAsCollateral(spoke1, user, _wethReserveId(spoke1), true);

      usersInfo[i].suppliedShares = spoke1.getUserSuppliedShares(_wethReserveId(spoke1), user);

      // Borrow DAI based on fuzzed amounts
      Utils.borrow(spoke1, _daiReserveId(spoke1), user, usersInfo[i].borrowAmount, user);

      // Verify initial borrowing state
      uint256 totalDaiDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), user);
      assertEq(totalDaiDebt, usersInfo[i].borrowAmount, 'Initial DAI debt incorrect');
    }

    // Time passes, interest accrues
    skip(skipTime);

    // Fetch current debts before repayment
    Debts[2] memory debtsBefore; // 2 users
    // [bob, alice] order
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // Store debts before repayment
      debtsBefore[i].totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), user);
      (debtsBefore[i].baseDebt, debtsBefore[i].premiumDebt) = spoke1.getUserDebt(
        _daiReserveId(spoke1),
        user
      );

      // Verify interest accrual
      assertGe(
        debtsBefore[i].totalDebt,
        usersInfo[i].borrowAmount,
        'DAI debt should accrue interest'
      );
    }

    // Repayments
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // DAI repayment
      (uint256 baseRestored, uint256 premiumRestored) = _calculateRestoreAmount(
        debtsBefore[i].baseDebt,
        debtsBefore[i].premiumDebt,
        usersInfo[i].repayAmount
      );
      usersInfo[i].premiumRestored = premiumRestored;
      if (baseRestored >= minimumAssetsPerDrawnShare(daiAssetId) || premiumRestored > 0) {
        deal(address(tokenList.dai), user, usersInfo[i].repayAmount);
        vm.startPrank(user);
        spoke1.repay(_daiReserveId(spoke1), usersInfo[i].repayAmount);
        vm.stopPrank();
      }
    }

    // Verify final state for each user
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // Verify repayments have been applied correctly
      if (
        usersInfo[i].repayAmount >= minimumAssetsPerDrawnShare(daiAssetId) ||
        usersInfo[i].premiumRestored > 0
      ) {
        uint256 expectedDaiDebt = usersInfo[i].repayAmount >= debtsBefore[i].totalDebt
          ? 0
          : debtsBefore[i].totalDebt - usersInfo[i].repayAmount;
        uint256 actualDaiDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), user);
        assertApproxEqAbs(actualDaiDebt, expectedDaiDebt, 2, 'DAI debt not reduced correctly');
      }

      // Verify supply positions remain unchanged
      assertEq(
        spoke1.getUserSuppliedShares(_wethReserveId(spoke1), user),
        usersInfo[i].suppliedShares,
        'WETH supplied shares should remain unchanged'
      );
    }
  }

  function _assertUserRpUnchanged(uint256 reserveId, ISpoke spoke, address user) internal {
    DataTypes.UserPosition memory pos = spoke.getUserPosition(reserveId, user);
    uint256 riskPremiumStored = pos.premiumDrawnShares.percentDiv(pos.baseDrawnShares);
    (uint256 riskPremiumCurrent, , , , ) = spoke.getUserAccountData(user);
    assertEq(riskPremiumCurrent, riskPremiumStored, 'user risk premium mismatch');
  }

  function _boundUserAction(UserAction memory action) internal pure returns (UserAction memory) {
    action.borrowAmount = bound(action.borrowAmount, 1, MAX_SUPPLY_AMOUNT / 8);
    action.repayAmount = bound(action.repayAmount, 1, type(uint256).max);

    return action;
  }

  function _bound(UserAssetInfo memory info) internal pure returns (UserAssetInfo memory) {
    // Bound borrow amounts
    info.daiInfo.borrowAmount = bound(info.daiInfo.borrowAmount, 1, MAX_SUPPLY_AMOUNT / 8);
    info.wethInfo.borrowAmount = bound(info.wethInfo.borrowAmount, 1, MAX_SUPPLY_AMOUNT / 8);
    info.usdxInfo.borrowAmount = bound(info.usdxInfo.borrowAmount, 1, MAX_SUPPLY_AMOUNT / 8);
    info.wbtcInfo.borrowAmount = bound(info.wbtcInfo.borrowAmount, 1, MAX_SUPPLY_AMOUNT / 8);

    // Bound repay amounts
    info.daiInfo.repayAmount = bound(info.daiInfo.repayAmount, 1, type(uint256).max);
    info.wethInfo.repayAmount = bound(info.wethInfo.repayAmount, 1, type(uint256).max);
    info.usdxInfo.repayAmount = bound(info.usdxInfo.repayAmount, 1, type(uint256).max);
    info.wbtcInfo.repayAmount = bound(info.wbtcInfo.repayAmount, 1, type(uint256).max);

    return info;
  }
}
