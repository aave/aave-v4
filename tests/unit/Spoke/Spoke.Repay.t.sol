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

    vm.stopPrank();
  }

  function test_riskPremium_postActions() public {
    vm.prank(alice);
    spoke1.supply(_daiReserveId(spoke1), 1000e18);

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

  function _assertUserRpUnchanged(uint256 reserveId, ISpoke spoke, address user) internal {
    DataTypes.UserPosition memory pos = spoke.getUserPosition(reserveId, user);
    uint256 riskPremiumStored = pos.premiumDrawnShares.percentDiv(pos.baseDrawnShares);
    (uint256 riskPremiumCurrent, , , , ) = spoke.getUserAccountData(user);
    assertEq(riskPremiumCurrent, riskPremiumStored, 'user risk premium mismatch');
  }

  function test_repay_same_block() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;
    uint256 daiRepayAmount = daiSupplyAmount / 4;

    // Bob supply weth
    Utils.spokeSupply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

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
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);

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
    Utils.spokeSupply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

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
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);

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
    vm.prank(bob);
    spoke1.repay(daiReserveId, amount);
  }

  function test_repay_revertsWith_ReservePaused() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;

    updateReservePausedFlag(spoke1, daiReserveId, true);
    assertTrue(spoke1.getReserve(daiReserveId).config.paused);

    vm.expectRevert(ISpoke.ReservePaused.selector);
    vm.prank(bob);
    spoke1.repay(daiReserveId, amount);
  }

  function test_repay_revertsWith_ReserveNotListed() public {
    uint256 reserveId = spoke1.reserveCount() + 1; // invalid reserveId
    uint256 amount = 100e18;

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(bob);
    spoke1.repay(reserveId, amount);
  }

  /// repay all debt interest
  function test_repay_only_interest() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;

    // Bob supply weth
    Utils.spokeSupply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

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

    (uint256 baseRestored, uint256 premiumRestored) = _calculateRestoreAmount(
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
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);

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
    assertEq(bobDaiAfter.premiumDebt, 0, 'bob dai outstanding premium final balance');
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

  /// repay all outstanding premium debt
  function test_repay_only_premium() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;

    // Bob supply weth
    Utils.spokeSupply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

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
    skip(10 days);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiDebtBefore = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (uint256 bobDaiBaseDebtBefore, ) = spoke1.getUserDebt(_daiReserveId(spoke1), bob);
    assertGt(bobDaiDebtBefore, daiBorrowAmount, 'bob dai debt before');

    // Bob repays premium
    (, uint256 daiRepayAmount) = spoke1.getUserDebt(_daiReserveId(spoke1), bob);
    assertGt(daiRepayAmount, 0); // interest is not zero

    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(_daiReserveId(spoke1), bob, 0);
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
      spoke1,
      bob,
      _wethReserveId(spoke1)
    );

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      bobDaiBaseDebtBefore,
      'bob dai debt final balance'
    );
    (, uint256 bobDaiPremiumDebtAfter) = spoke1.getUserDebt(_daiReserveId(spoke1), bob);
    assertEq(bobDaiPremiumDebtAfter, 0, 'bob dai outstanding premium final balance');
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
    Utils.spokeSupply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supplies DAI
    Utils.spokeSupply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrows DAI
    Utils.spokeBorrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

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
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), type(uint256).max);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    Debts memory bobDaiAfter;
    bobDaiAfter.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiAfter.baseDebt, bobDaiAfter.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    uint256 bobDaiBalanceAfter = tokenList.dai.balanceOf(bob);

    // Verify that Bob's debt is fully cleared after repayment
    assertEq(bobDaiAfter.totalDebt, 0, "Bob's dai debt should be cleared");

    // Verify that his DAI balance was reduced by the full debt amount
    assertEq(
      bobDaiBalanceAfter,
      bobDaiBalanceBefore - fullDebt,
      "Bob's dai balance decreased by full debt repaid"
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
    Utils.spokeSupply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supplies DAI
    Utils.spokeSupply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrows DAI
    Utils.spokeBorrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

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

    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), partialRepayAmount);

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
      "Bob's dai debt should be reduced"
    );
    // Verify that his DAI balance was reduced by the partial debt amount
    assertEq(
      bobDaiBalanceAfter,
      bobDaiBalanceBefore - partialRepayAmount,
      "Bob's dai balance decreased by partial debt repaid"
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
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), type(uint256).max);

    bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiAfter.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiAfter.baseDebt, bobDaiAfter.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    bobDaiBalanceAfter = tokenList.dai.balanceOf(bob);

    // Verify that Bob's debt is fully cleared after repayment
    assertEq(bobDaiAfter.totalDebt, 0, "Bob's dai debt should be cleared");

    // Verify that his DAI balance was reduced by the full debt amount
    assertEq(
      bobDaiBalanceAfter,
      bobDaiBalanceBefore - fullDebt,
      "Bob's dai balance decreased by full debt repaid"
    );

    // Verify reserve debt is 0
    (uint256 baseDaiDebt, uint256 premiumDaiDebt) = spoke1.getReserveDebt(_daiReserveId(spoke1));
    assertEq(baseDaiDebt, 0);
    assertEq(premiumDaiDebt, 0);

    // verify LH asset debt is 0
    assertEq(hub.getAssetTotalDebt(_daiReserveId(spoke1)), 0);
  }

  function test_repay_less_than_share() public {
    // Accrue interest and ensure it's less than 1 share and pay it off
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = 100;

    // Bob supplies WETH as collateral
    Utils.spokeSupply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supplies DAI
    Utils.spokeSupply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrows DAI
    Utils.spokeBorrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

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

    (uint256 repaidBase, ) = _calculateRestoreAmount(
      bobDaiBefore.baseDebt,
      bobDaiBefore.premiumDebt,
      repayAmount
    );

    // Repay
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(_daiReserveId(spoke1), bob, hub.convertToDrawnShares(daiAssetId, repaidBase));

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

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      bobDaiBefore.totalDebt - repayAmount,
      'bob dai debt final balance'
    );
    assertEq(bobDaiAfter.premiumDebt, 0, 'bob dai outstanding premium final balance');

    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(bobWethBefore.totalDebt, spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob));
    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - repayAmount,
      'bob dai final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);
  }

  function test_repay_fuzz_max_amount_gt_current_debt(uint256 repayAmount) public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;

    // Bob supplies WETH as collateral
    Utils.spokeSupply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supplies DAI
    Utils.spokeSupply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrows DAI
    Utils.spokeBorrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    DataTypes.UserPosition memory bobDaiDataBefore = getUserInfo(
      spoke1,
      bob,
      _daiReserveId(spoke1)
    );
    Debts memory bobDaiBefore;
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.baseDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );

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
    uint256 fullDebt = bobDaiBefore.totalDebt;
    uint256 repayAmount = bound(repayAmount, fullDebt + 1, type(uint256).max);

    // How much will actually be repaid
    (uint256 repaidBase, uint256 repaidPremium) = _calculateRestoreAmount(
      bobDaiBefore.baseDebt,
      bobDaiBefore.premiumDebt,
      repayAmount
    );
    uint256 repaidAmount = repaidBase + repaidPremium;

    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
      _daiReserveId(spoke1),
      bob,
      hub.convertToDrawnShares(daiAssetId, bobDaiBefore.baseDebt)
    );
    // Bob repays using repay Amount > full debt
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), repayAmount);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    Debts memory bobDaiAfter;
    uint256 bobDaiBalanceAfter = tokenList.dai.balanceOf(bob);
    bobDaiAfter.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiAfter.baseDebt, bobDaiAfter.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    assertEq(bobDaiAfter.totalDebt, 0, "Bob's dai debt should be cleared");
    assertEq(
      bobDaiBalanceAfter,
      bobDaiBalanceBefore - repaidAmount,
      "Bob's dai balance decreased by full debt repaid"
    );

    // Verify reserve debt is 0
    (uint256 baseDaiDebt, uint256 premiumDaiDebt) = spoke1.getReserveDebt(_daiReserveId(spoke1));
    assertEq(baseDaiDebt, 0);
    assertEq(premiumDaiDebt, 0);

    // verify LH asset debt is 0
    uint256 lhAssetDebt = hub.getAssetTotalDebt(_daiReserveId(spoke1));
    assertEq(lhAssetDebt, 0);
  }

  function test_repay_max_amount_gt_current_debt() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;

    // Bob supplies WETH as collateral
    Utils.spokeSupply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supplies DAI
    Utils.spokeSupply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrows DAI
    Utils.spokeBorrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

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
    uint256 fullDebt = bobDaiBefore.totalDebt;

    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
      _daiReserveId(spoke1),
      bob,
      hub.convertToDrawnShares(daiAssetId, bobDaiBefore.baseDebt)
    );
    // Bob repays using a value gt full debt to signal full repayment
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), fullDebt + 1);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    Debts memory bobDaiAfter;
    bobDaiAfter.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiAfter.baseDebt, bobDaiAfter.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    uint256 bobDaiBalanceAfter = tokenList.dai.balanceOf(bob);

    // Verify that Bob's debt is fully cleared after repayment
    assertEq(bobDaiAfter.totalDebt, 0, "Bob's dai debt should be cleared");
    // Verify that his DAI balance was reduced by the full debt amount
    assertEq(
      bobDaiBalanceAfter,
      bobDaiBalanceBefore - fullDebt,
      "Bob's dai balance decreased by full debt repaid"
    );

    // Verify reserve debt is 0
    (uint256 baseDaiDebt, uint256 premiumDaiDebt) = spoke1.getReserveDebt(_daiReserveId(spoke1));
    assertEq(baseDaiDebt, 0);
    assertEq(premiumDaiDebt, 0);

    // verify LH asset debt is 0
    uint256 lhAssetDebt = hub.getAssetTotalDebt(_daiReserveId(spoke1));
    assertEq(lhAssetDebt, 0);
  }

  /// repay all accrued base debt when premium debt is already repaid
  function test_repay_only_base_debt() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;

    // Bob supply weth
    Utils.spokeSupply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

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
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), bobDaiBefore.premiumDebt);

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
    assertEq(bobDaiAfter.premiumDebt, 0, 'bob dai outstanding premium final balance');
    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(bobWethAfter.totalDebt, bobWethBefore.totalDebt);
    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - daiRepayAmount,
      'bob dai final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);
  }

  /// repay all accrued base debt when outstanding premium is zero
  function test_repay_only_base_debt_no_premium() public {
    // update liquidity premium to zero
    updateLiquidityPremium(spoke1, _wethReserveId(spoke1), 0);

    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;

    // Bob supply weth
    Utils.spokeSupply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

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
    assertEq(bobDaiBefore.premiumDebt, 0, 'bob dai outstanding premium before');

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
    assertEq(bobDaiAfter.premiumDebt, 0, 'bob dai outstanding premium final balance');
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
    Utils.spokeSupply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, _daiReserveId(spoke1), alice, daiBorrowAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

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

  /// repay all or a portion of total debt
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
    Utils.spokeSupply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, _daiReserveId(spoke1), alice, daiBorrowAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

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
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);

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
    daiBorrowAmount = bound(
      daiBorrowAmount,
      hub.convertToDrawnAssets(daiAssetId, 1),
      MAX_SUPPLY_AMOUNT / 2
    );
    // Borrow amount must be in shares
    daiBorrowAmount = hub.convertToDrawnAssets(
      daiAssetId,
      hub.convertToDrawnShares(daiAssetId, daiBorrowAmount)
    );

    // calculate weth collateral
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      daiBorrowAmount
    );

    // Bob supply weth
    Utils.spokeSupply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, _daiReserveId(spoke1), alice, daiBorrowAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

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
    if (bobDaiInterest == 0) {
      // not enough time travel for interest accrual
      daiRepayAmount = 0;
      vm.expectRevert(ILiquidityHub.InvalidRestoreAmount.selector);
      vm.prank(bob);
      spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);
    } else {
      // Assume interest is at least 1 share
      uint256 singleShareAmount = hub.convertToDrawnAssets(daiAssetId, 1);
      vm.assume(bobDaiInterest >= singleShareAmount);
      daiRepayAmount = bound(daiRepayAmount, singleShareAmount, bobDaiInterest);
      deal(address(tokenList.dai), bob, daiRepayAmount);

      (uint256 baseRepaid, ) = _calculateRestoreAmount(
        bobDaiBefore.baseDebt,
        bobDaiBefore.premiumDebt,
        daiRepayAmount
      );

      vm.expectEmit(address(spoke1));
      emit ISpoke.Repay(
        _daiReserveId(spoke1),
        bob,
        hub.convertToDrawnShares(daiAssetId, baseRepaid)
      );
      vm.prank(bob);
      spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);

      DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(
        spoke1,
        bob,
        _daiReserveId(spoke1)
      );
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
  }

  /// repay all or a portion of outstanding premium debt
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
    Utils.spokeSupply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, _daiReserveId(spoke1), alice, daiBorrowAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

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
      vm.expectRevert(ILiquidityHub.InvalidRestoreAmount.selector);
      vm.prank(bob);
      spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);
    } else {
      // interest is at least 1
      daiRepayAmount = bound(daiRepayAmount, 1, bobDaiPremium);
      deal(address(tokenList.dai), bob, daiRepayAmount);

      (uint256 baseRepaid, uint256 premiumRepaid) = _calculateRestoreAmount(
        bobDaiBefore.baseDebt,
        bobDaiBefore.premiumDebt,
        daiRepayAmount
      );

      vm.expectEmit(address(spoke1));
      emit ISpoke.Repay(
        _daiReserveId(spoke1),
        bob,
        hub.convertToDrawnShares(daiAssetId, baseRepaid)
      );
      vm.prank(bob);
      spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);

      DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(
        spoke1,
        bob,
        _daiReserveId(spoke1)
      );
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
        'bob dai outstanding premium final balance'
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
  }

  /// repay all or a portion of accrued base debt when outstanding premium is already repaid
  function test_repay_fuzz_amounts_base_debt(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount,
    uint40 skipTime
  ) public {
    daiBorrowAmount = bound(
      daiBorrowAmount,
      hub.convertToDrawnAssets(daiAssetId, 1),
      MAX_SUPPLY_AMOUNT / 2
    );
    // Borrow amount needs to be in whole shares amounts
    daiBorrowAmount = hub.convertToDrawnAssets(
      daiAssetId,
      hub.convertToDrawnShares(daiAssetId, daiBorrowAmount)
    );

    // calculate weth collateral
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      daiBorrowAmount
    );

    // Bob supply weth
    Utils.spokeSupply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, _daiReserveId(spoke1), alice, daiBorrowAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

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
      vm.prank(bob);
      spoke1.repay(_daiReserveId(spoke1), bobDaiBefore.premiumDebt);
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
    if (bobDaiBaseDebt == 0) {
      // not enough time travel for premium accrual
      daiRepayAmount = 0;
      vm.expectRevert(ILiquidityHub.InvalidRestoreAmount.selector);
      vm.prank(bob);
      spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);
    } else {
      // interest is at least 1
      uint256 singleShareAmount = hub.convertToDrawnAssets(daiAssetId, 1);
      daiRepayAmount = bobDaiBaseDebt >= singleShareAmount
        ? bound(daiRepayAmount, singleShareAmount, bobDaiBaseDebt)
        : singleShareAmount;
      deal(address(tokenList.dai), bob, daiRepayAmount);

      vm.expectEmit(address(spoke1));
      emit ISpoke.Repay(
        _daiReserveId(spoke1),
        bob,
        hub.convertToDrawnShares(daiAssetId, daiRepayAmount)
      );
      vm.prank(bob);
      spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);

      DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(
        spoke1,
        bob,
        _daiReserveId(spoke1)
      );
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
      assertEq(bobDaiAfter.premiumDebt, 0, 'bob dai outstanding premium final balance');
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
  }

  /// repay all or a portion of accrued base debt when outstanding premium is zero
  function test_repay_fuzz_amounts_base_debt_no_premium(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount,
    uint40 skipTime
  ) public {
    daiBorrowAmount = bound(
      daiBorrowAmount,
      hub.convertToDrawnAssets(daiAssetId, 1),
      MAX_SUPPLY_AMOUNT / 2
    );
    // Borrow amount needs to be in whole shares amounts
    daiBorrowAmount = hub.convertToDrawnAssets(
      daiAssetId,
      hub.convertToDrawnShares(daiAssetId, daiBorrowAmount)
    );

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
    Utils.spokeSupply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, _daiReserveId(spoke1), alice, daiBorrowAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

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
    assertEq(bobDaiBefore.premiumDebt, 0, 'bob dai outstanding premium before');

    // Bob repays
    uint256 bobDaiBaseDebt = bobDaiBefore.baseDebt - daiBorrowAmount;
    if (bobDaiBaseDebt == 0) {
      // not enough time travel for interest accrual
      daiRepayAmount = 0;
      vm.expectRevert(ILiquidityHub.InvalidRestoreAmount.selector);
      vm.prank(bob);
      spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);
    } else {
      // interest is at least 1
      uint256 singleShareAmount = hub.convertToDrawnAssets(daiAssetId, 1);
      daiRepayAmount = bobDaiBaseDebt >= singleShareAmount
        ? bound(daiRepayAmount, singleShareAmount, bobDaiBaseDebt)
        : singleShareAmount;
      deal(address(tokenList.dai), bob, daiRepayAmount);

      vm.expectEmit(address(spoke1));
      emit ISpoke.Repay(
        _daiReserveId(spoke1),
        bob,
        hub.convertToDrawnShares(daiAssetId, daiRepayAmount)
      );
      vm.prank(bob);
      spoke1.repay(_daiReserveId(spoke1), daiRepayAmount);

      DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(
        spoke1,
        bob,
        _daiReserveId(spoke1)
      );
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
  }

  struct RepayMultipleLocal {
    uint256 borrowAmount;
    uint256 repayAmount;
    DataTypes.UserPosition posBefore; // positionBefore
    DataTypes.UserPosition posAfter; // positionAfter
  }

  /// borrow and repay multiple reserves
  function test_repay_multiple_reserves_fuzz_amountsAndWait(
    uint256 daiBorrowAmount,
    uint256 wethBorrowAmount,
    uint256 usdxBorrowAmount,
    uint256 wbtcBorrowAmount,
    uint256 repayPortion,
    uint256 skipTime
  ) public {
    RepayMultipleLocal memory daiInfo;
    RepayMultipleLocal memory wethInfo;
    RepayMultipleLocal memory usdxInfo;
    RepayMultipleLocal memory wbtcInfo;

    daiInfo.borrowAmount = bound(
      daiBorrowAmount,
      hub.convertToDrawnAssets(daiAssetId, 1),
      MAX_SUPPLY_AMOUNT / 2
    );
    wethInfo.borrowAmount = bound(
      wethBorrowAmount,
      hub.convertToDrawnAssets(wethAssetId, 1),
      MAX_SUPPLY_AMOUNT / 2
    );
    usdxInfo.borrowAmount = bound(
      usdxBorrowAmount,
      hub.convertToDrawnAssets(usdxAssetId, 1),
      MAX_SUPPLY_AMOUNT / 2
    );
    wbtcInfo.borrowAmount = bound(
      wbtcBorrowAmount,
      hub.convertToDrawnAssets(wbtcAssetId, 1),
      MAX_SUPPLY_AMOUNT / 2
    );
    repayPortion = bound(repayPortion, 0, PercentageMath.PERCENTAGE_FACTOR);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    daiInfo.repayAmount = daiInfo.borrowAmount.percentMul(repayPortion);
    wethInfo.repayAmount = wethInfo.borrowAmount.percentMul(repayPortion);
    usdxInfo.repayAmount = usdxInfo.borrowAmount.percentMul(repayPortion);
    wbtcInfo.repayAmount = wbtcInfo.borrowAmount.percentMul(repayPortion);

    // Ensure borrow amounts are in whole shares
    daiInfo.borrowAmount = hub.convertToDrawnAssets(
      daiAssetId,
      hub.convertToDrawnShares(daiAssetId, daiInfo.borrowAmount)
    );
    wethInfo.borrowAmount = hub.convertToDrawnAssets(
      wethAssetId,
      hub.convertToDrawnShares(wethAssetId, wethInfo.borrowAmount)
    );
    usdxInfo.borrowAmount = hub.convertToDrawnAssets(
      usdxAssetId,
      hub.convertToDrawnShares(usdxAssetId, usdxInfo.borrowAmount)
    );
    wbtcInfo.borrowAmount = hub.convertToDrawnAssets(
      wbtcAssetId,
      hub.convertToDrawnShares(wbtcAssetId, wbtcInfo.borrowAmount)
    );

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
      Utils.spokeSupply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
      setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);
      deal(address(tokenList.wbtc), bob, wbtcSupplyAmount);
      Utils.spokeSupply(spoke1, _wbtcReserveId(spoke1), bob, wbtcSupplyAmount, bob);
      setUsingAsCollateral(spoke1, bob, _wbtcReserveId(spoke1), true);
    }

    // Alice supply liquidity
    Utils.spokeSupply(spoke1, _daiReserveId(spoke1), alice, daiInfo.borrowAmount, alice);
    Utils.spokeSupply(spoke1, _wethReserveId(spoke1), alice, wethInfo.borrowAmount, alice);
    Utils.spokeSupply(spoke1, _usdxReserveId(spoke1), alice, usdxInfo.borrowAmount, alice);
    Utils.spokeSupply(spoke1, _wbtcReserveId(spoke1), alice, wbtcInfo.borrowAmount, alice);

    // Bob borrows
    Utils.spokeBorrow(spoke1, _daiReserveId(spoke1), bob, daiInfo.borrowAmount, bob);
    Utils.spokeBorrow(spoke1, _wethReserveId(spoke1), bob, wethInfo.borrowAmount, bob);
    Utils.spokeBorrow(spoke1, _usdxReserveId(spoke1), bob, usdxInfo.borrowAmount, bob);
    Utils.spokeBorrow(spoke1, _wbtcReserveId(spoke1), bob, wbtcInfo.borrowAmount, bob);

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

    // Ensure repay amounts are in whole shares
    daiInfo.repayAmount = hub.convertToDrawnAssets(
      daiAssetId,
      hub.convertToDrawnShares(daiAssetId, daiInfo.repayAmount)
    );
    wethInfo.repayAmount = hub.convertToDrawnAssets(
      wethAssetId,
      hub.convertToDrawnShares(wethAssetId, wethInfo.repayAmount)
    );
    usdxInfo.repayAmount = hub.convertToDrawnAssets(
      usdxAssetId,
      hub.convertToDrawnShares(usdxAssetId, usdxInfo.repayAmount)
    );
    wbtcInfo.repayAmount = hub.convertToDrawnAssets(
      wbtcAssetId,
      hub.convertToDrawnShares(wbtcAssetId, wbtcInfo.repayAmount)
    );

    // Repayments
    if (daiInfo.repayAmount > 0) {
      deal(address(tokenList.dai), bob, daiInfo.repayAmount);
      Utils.spokeRepay(spoke1, _daiReserveId(spoke1), bob, daiInfo.repayAmount);
    }
    if (wethInfo.repayAmount > 0) {
      deal(address(tokenList.weth), bob, wethInfo.repayAmount);
      Utils.spokeRepay(spoke1, _wethReserveId(spoke1), bob, wethInfo.repayAmount);
    }
    if (wbtcInfo.repayAmount > 0) {
      deal(address(tokenList.wbtc), bob, wbtcInfo.repayAmount);
      Utils.spokeRepay(spoke1, _wbtcReserveId(spoke1), bob, wbtcInfo.repayAmount);
    }
    if (usdxInfo.repayAmount > 0) {
      deal(address(tokenList.usdx), bob, usdxInfo.repayAmount);
      Utils.spokeRepay(spoke1, _usdxReserveId(spoke1), bob, usdxInfo.repayAmount);
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
    assertEq(
      bobDaiAfter.totalDebt,
      bobDaiBefore.totalDebt - daiInfo.repayAmount,
      'bob dai debt final balance'
    );
    assertEq(
      bobWethAfter.totalDebt,
      bobWethBefore.totalDebt - wethInfo.repayAmount,
      'bob weth debt final balance'
    );
    assertEq(
      bobUsdxAfter.totalDebt,
      bobUsdxBefore.totalDebt - usdxInfo.repayAmount,
      'bob usdx debt final balance'
    );
    assertEq(
      bobWbtcAfter.totalDebt,
      bobWbtcBefore.totalDebt - wbtcInfo.repayAmount,
      'bob wbtc debt final balance'
    );
  }

  function _calculateRestoreAmount(
    uint256 baseDebt,
    uint256 premiumDebt,
    uint256 amount
  ) internal view returns (uint256, uint256) {
    if (amount >= baseDebt + premiumDebt) {
      return (baseDebt, premiumDebt);
    }
    if (amount <= premiumDebt) {
      return (0, amount);
    }
    return (amount - premiumDebt, premiumDebt);
  }

  /// todo: borrow, repay, borrow more, repay
  /// todo: multiple users repay different reserves
}
