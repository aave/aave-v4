// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeBorrowTest is SpokeBase {
  function test_borrow_revertsWith_ReserveNotBorrowable() public {
    vm.skip(true, 'pending refactor');

//     uint256 daiReserveId = _daiReserveId(spoke1);

//     // set reserve not borrowable
//     updateReserveBorrowableFlag(spoke1, daiReserveId, false);
//     assertFalse(spoke1.getReserve(daiReserveId).config.borrowable);

//     // Bob try to draw some dai
//     vm.expectRevert(abi.encodeWithSelector(ISpoke.ReserveNotBorrowable.selector, daiReserveId));
//     vm.prank(bob);
//     spoke1.borrow(daiReserveId, 1, bob);
  
}

  function test_borrow_revertsWith_ReserveNotActive() public {
    vm.skip(true, 'pending refactor');

//     uint256 daiReserveId = _daiReserveId(spoke1);

//     updateReserveActiveFlag(spoke1, daiReserveId, false);
//     assertFalse(spoke1.getReserve(daiReserveId).config.active);

//     // Bob try to draw some dai
//     vm.expectRevert(ISpoke.ReserveNotActive.selector);
//     vm.prank(bob);
//     spoke1.borrow(daiReserveId, 1, bob);
  
}

  function test_borrow_revertsWith_ReserveNotListed() public {
    vm.skip(true, 'pending refactor');

//     uint256 reserveId = spoke1.reserveCount() + 1; // invalid reserveId

//     // Bob try to draw some dai
//     vm.expectRevert(ISpoke.ReserveNotListed.selector);
//     vm.prank(bob);
//     spoke1.borrow(reserveId, 1, bob);
  
}

  function test_borrow_revertsWith_ReservePaused() public {
    vm.skip(true, 'pending refactor');

//     uint256 daiReserveId = _daiReserveId(spoke1);

//     updateReservePausedFlag(spoke1, daiReserveId, true);
//     assertTrue(spoke1.getReserve(daiReserveId).config.paused);

//     // Bob try to draw some dai

//     vm.expectRevert(ISpoke.ReservePaused.selector);
//     vm.prank(bob);
//     spoke1.borrow(daiReserveId, 1, bob);
  
}

  function test_borrow_revertsWith_ReserveFrozen() public {
    vm.skip(true, 'pending refactor');

//     uint256 daiReserveId = _daiReserveId(spoke1);

//     updateReserveFrozenFlag(spoke1, daiReserveId, true);
//     assertTrue(spoke1.getReserve(daiReserveId).config.frozen);

//     // Bob try to draw some dai

//     vm.expectRevert(ISpoke.ReserveFrozen.selector);
//     vm.prank(bob);
//     spoke1.borrow(daiReserveId, 1, bob);
  
}

  function test_borrow_revertsWith_asset_not_active() public {
    vm.skip(true, 'pending refactor');

//     uint256 daiReserveId = _daiReserveId(spoke1);

//     // set asset not active
//     updateAssetActive(hub, daiAssetId, false);

//     // Bob try to draw some dai

//     vm.expectRevert(ILiquidityHub.AssetNotActive.selector);
//     vm.prank(bob);
//     spoke1.borrow(daiReserveId, 1, bob);
  
}

  function test_borrow() public {
    vm.skip(true, 'pending refactor');

//     uint256 daiReserveId = _daiReserveId(spoke1);
//     uint256 wethReserveId = _wethReserveId(spoke1);

//     uint256 daiSupplyAmount = 100e18;
//     uint256 wethSupplyAmount = 10e18;
//     uint256 daiBorrowAmount = daiSupplyAmount / 2;

//     // Bob supply weth
//     Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);
//     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

//     // Alice supply dai
//     Utils.spokeSupply(spoke1, daiReserveId, alice, daiSupplyAmount, alice);

//     DataTypes.UserPosition memory bobDaiData = getUserInfo(spoke1, bob, daiReserveId);
//     DataTypes.UserPosition memory bobWethData = getUserInfo(spoke1, bob, wethReserveId);
//     DataTypes.UserPosition memory aliceDaiData = getUserInfo(spoke1, alice, daiReserveId);
//     DataTypes.UserPosition memory aliceWethData = getUserInfo(spoke1, alice, wethReserveId);

//     uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
//     uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);
//     uint256 aliceDaiBalanceBefore = tokenList.dai.balanceOf(alice);
//     uint256 aliceWethBalanceBefore = tokenList.weth.balanceOf(alice);

//     assertEq(bobDaiData.suppliedShares, 0, 'bob dai supply shares before');
//     assertEq(bobDaiData.baseDebt, 0, 'bob dai base debt before');
//     assertEq(
//       bobWethData.suppliedShares,
//       hub.convertToShares(wethAssetId, wethSupplyAmount),
//       'bob supply shares before'
//     );
//     assertEq(bobWethData.baseDebt, 0, 'bob weth base debt before');

//     assertEq(
//       aliceDaiData.suppliedShares,
//       hub.convertToShares(daiAssetId, daiSupplyAmount),
//       'alice dai supply shares before'
//     );
//     assertEq(aliceDaiData.baseDebt, 0, 'alice dai base debt before');
//     assertEq(aliceWethData.suppliedShares, 0, 'alice weth supply shares before');
//     assertEq(aliceWethData.baseDebt, 0, 'alice weth base debt before');

//     assertEq(tokenList.dai.balanceOf(bob), bobDaiBalanceBefore, 'bob dai balance before');
//     assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore, 'bob weth balance before');
//     assertEq(tokenList.dai.balanceOf(alice), aliceDaiBalanceBefore, 'alice dai balance before');
//     assertEq(tokenList.weth.balanceOf(alice), aliceWethBalanceBefore, 'alice weth balance before');

//     // Bob draw half of dai reserve liquidity
//     vm.prank(bob);
//     vm.expectEmit(address(spoke1));
//     emit ISpoke.Borrowed(daiReserveId, bob, daiBorrowAmount);
//     spoke1.borrow(daiReserveId, daiBorrowAmount, bob);

//     bobDaiData = getUserInfo(spoke1, bob, daiReserveId);
//     bobWethData = getUserInfo(spoke1, bob, wethReserveId);
//     aliceDaiData = getUserInfo(spoke1, alice, daiReserveId);
//     aliceWethData = getUserInfo(spoke1, alice, wethReserveId);

//     assertEq(bobDaiData.suppliedShares, 0, 'bob dai supply shares final balance');
//     assertEq(bobDaiData.baseDebt, daiBorrowAmount, 'bob dai base debt final balance');
//     assertEq(
//       bobWethData.suppliedShares,
//       hub.convertToShares(wethAssetId, wethSupplyAmount),
//       'bob weth supply shares final balance'
//     );
//     assertEq(bobWethData.baseDebt, 0, 'bob weth base debt  final balance');

//     assertEq(
//       aliceDaiData.suppliedShares,
//       hub.convertToShares(daiAssetId, daiSupplyAmount),
//       'alice dai supply shares final balance'
//     );
//     assertEq(aliceDaiData.baseDebt, 0, 'alice dai base debt final');
//     assertEq(aliceWethData.suppliedShares, 0, 'alice weth supply shares final balance');
//     assertEq(aliceWethData.baseDebt, 0, 'alice weth base debt final');

//     assertEq(
//       tokenList.dai.balanceOf(bob),
//       bobDaiBalanceBefore + daiBorrowAmount,
//       'bob dai final balance'
//     );
//     assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore, 'bob weth final balance');
//     assertEq(tokenList.dai.balanceOf(alice), aliceDaiBalanceBefore, 'alice dai final balance');
//     assertEq(tokenList.weth.balanceOf(alice), aliceWethBalanceBefore, 'alice weth final balance');
  
}

  function test_borrow_revertsWith_not_available_liquidity() public {
    vm.skip(true, 'pending refactor');

//     uint256 daiReserveId = _daiReserveId(spoke1);
//     uint256 wethReserveId = _wethReserveId(spoke1);

//     uint256 daiAmount = 100e18;
//     uint256 wethAmount = 10e18;

//     // Bob supply weth
//     Utils.spokeSupply(spoke1, wethReserveId, bob, wethAmount, bob);

//     // Alice supply dai
//     Utils.spokeSupply(spoke1, daiReserveId, alice, daiAmount, alice);

//     // Bob draw more than supplied dai amount

//     vm.expectRevert(
//       abi.encodeWithSelector(ILiquidityHub.NotAvailableLiquidity.selector, daiAmount)
//     );
//     vm.prank(bob);
//     spoke1.borrow(daiReserveId, daiAmount + 1, bob);
  
}

  function test_borrow_revertsWith_invalid_draw_amount() public {
    vm.skip(true, 'pending refactor');

//     // Bob draw 0 dai

//     vm.expectRevert(ILiquidityHub.InvalidDrawAmount.selector);
//     vm.prank(bob);
//     spoke1.borrow(_daiReserveId(spoke1), 0, bob);
  
}

  function test_borrow_fuzz_amounts(uint256 wethSupplyAmount, uint256 daiBorrowAmount) public {
    vm.skip(true, 'pending refactor');

//     uint256 daiReserveId = _daiReserveId(spoke1);
//     uint256 wethReserveId = _wethReserveId(spoke1);

//     wethSupplyAmount = bound(wethSupplyAmount, 1, MAX_SUPPLY_AMOUNT);
//     daiBorrowAmount = bound(daiBorrowAmount, 1, wethSupplyAmount / 2 + 1);

//     // Bob supply weth
//     Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);
//     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

//     // Alice supply dai
//     Utils.spokeSupply(spoke1, daiReserveId, alice, daiBorrowAmount, alice);

//     DataTypes.UserPosition memory bobDaiData = getUserInfo(spoke1, bob, daiReserveId);
//     DataTypes.UserPosition memory bobWethData = getUserInfo(spoke1, bob, wethReserveId);
//     DataTypes.UserPosition memory aliceDaiData = getUserInfo(spoke1, alice, daiReserveId);
//     DataTypes.UserPosition memory aliceWethData = getUserInfo(spoke1, alice, wethReserveId);

//     uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
//     uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);
//     uint256 aliceDaiBalanceBefore = tokenList.dai.balanceOf(alice);

//     assertEq(
//       bobWethData.suppliedShares,
//       hub.convertToShares(wethAssetId, wethSupplyAmount),
//       'bob weth supply shares before'
//     );
//     assertEq(bobWethData.baseDebt, 0, 'bob weth base debt before');
//     assertEq(bobDaiData.suppliedShares, 0, 'bob dai supply shares before');
//     assertEq(bobDaiData.baseDebt, 0, 'bob dai base debt before');

//     assertEq(
//       aliceDaiData.suppliedShares,
//       hub.convertToShares(daiAssetId, daiBorrowAmount),
//       'alice dai supply shares before'
//     );
//     assertEq(aliceDaiData.baseDebt, 0, 'alice dai base debt before');
//     assertEq(aliceWethData.suppliedShares, 0, 'alice weth supply shares before');
//     assertEq(aliceWethData.baseDebt, 0, 'alice weth base debt before');

//     assertEq(tokenList.dai.balanceOf(bob), bobDaiBalanceBefore, 'bob dai balance before');
//     assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore, 'bob weth balance before');
//     assertEq(tokenList.dai.balanceOf(alice), aliceDaiBalanceBefore, 'alice dai balance before');

//     // Bob draw dai
//     vm.prank(bob);
//     vm.expectEmit(address(spoke1));
//     emit ISpoke.Borrowed(daiReserveId, bob, daiBorrowAmount);
//     spoke1.borrow(daiReserveId, daiBorrowAmount, bob);

//     bobDaiData = getUserInfo(spoke1, bob, daiReserveId);
//     bobWethData = getUserInfo(spoke1, bob, wethReserveId);
//     aliceDaiData = getUserInfo(spoke1, alice, daiReserveId);
//     aliceWethData = getUserInfo(spoke1, alice, wethReserveId);

//     assertEq(bobDaiData.suppliedShares, 0, 'bob dai supply shares final balance');
//     assertEq(bobDaiData.baseDebt, daiBorrowAmount, 'bob dai base debt final balance');
//     assertEq(
//       bobWethData.suppliedShares,
//       hub.convertToShares(wethAssetId, wethSupplyAmount),
//       'bob supply shares final balance'
//     );
//     assertEq(bobWethData.baseDebt, 0, 'bob base debt weth final balance');

//     assertEq(
//       aliceDaiData.suppliedShares,
//       hub.convertToShares(daiAssetId, daiBorrowAmount),
//       'alice supply shares final balance'
//     );
//     assertEq(aliceDaiData.baseDebt, 0, 'alice base debt final');
//     assertEq(aliceWethData.suppliedShares, 0, 'alice supply shares final balance');
//     assertEq(aliceWethData.baseDebt, 0, 'alice base debt final');

//     assertEq(
//       tokenList.dai.balanceOf(bob),
//       bobDaiBalanceBefore + daiBorrowAmount,
//       'bob dai final balance'
//     );
//     assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore, 'bob weth final balance');
//     assertEq(tokenList.dai.balanceOf(alice), aliceDaiBalanceBefore, 'alice dai final balance');
  
}

  function test_borrow_revertsWith_draw_cap_exceeded() public {
    vm.skip(true, 'pending refactor');

//     uint256 daiReserveId = _daiReserveId(spoke1);
//     uint256 drawCap = 100e18;
//     uint256 drawAmount = drawCap + 1;

//     updateDrawCap(hub, daiAssetId, address(spoke1), drawCap);

//     // Bob borrow dai amount exceeding draw cap

//     vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.DrawCapExceeded.selector, drawCap));
//     vm.prank(bob);
//     spoke1.borrow(daiReserveId, drawAmount, bob);
  
}

  function test_borrow_revertsWith_draw_cap_exceeded_due_to_interest() public {
    vm.skip(true, 'pending refactor');

//     uint256 daiReserveId = _daiReserveId(spoke1);
//     uint256 wethReserveId = _wethReserveId(spoke1);

//     uint256 daiAmount = 100e18;
//     uint256 drawCap = daiAmount;
//     uint256 wethSupplyAmount = 10e18;
//     uint256 drawAmount = drawCap - 1;

//     updateDrawCap(hub, daiAssetId, address(spoke1), drawCap);

//     // Bob supply weth
//     Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);
//     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

//     // Alice supply dai
//     Utils.spokeSupply(spoke1, daiReserveId, alice, daiAmount, alice);

//     // Bob draw dai
//     Utils.spokeBorrow(spoke1, daiReserveId, bob, drawAmount, bob);

//     assertGt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

//     skip(365 days);

//     // Additional supply to accrue interest
//     Utils.spokeSupply(spoke1, daiReserveId, bob, 1e18, bob);

//     vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.DrawCapExceeded.selector, drawCap));
//     Utils.spokeBorrow(spoke1, daiReserveId, bob, 1, bob);
  
}

  function test_borrow_fuzz_multiple_reserves(
    uint256 daiBorrowAmount,
    uint256 wethBorrowAmount,
    uint256 usdxBorrowAmount,
    uint256 wbtcBorrowAmount
  ) public {
    vm.skip(true, 'pending refactor');

//     uint256 daiReserveId = spokeInfo[spoke2].dai.reserveId;
//     uint256 wethReserveId = spokeInfo[spoke2].weth.reserveId;
//     uint256 usdxReserveId = spokeInfo[spoke2].usdx.reserveId;
//     uint256 wbtcReserveId = spokeInfo[spoke2].wbtc.reserveId;

//     daiBorrowAmount = bound(daiBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);
//     wethBorrowAmount = bound(wethBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);
//     usdxBorrowAmount = bound(usdxBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);
//     wbtcBorrowAmount = bound(wbtcBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);

//     // Bob supply all reserves
//     Utils.spokeSupply(spoke2, daiReserveId, bob, MAX_SUPPLY_AMOUNT, bob);
//     Utils.spokeSupply(spoke2, wethReserveId, bob, MAX_SUPPLY_AMOUNT, bob);
//     Utils.spokeSupply(spoke2, usdxReserveId, bob, MAX_SUPPLY_AMOUNT, bob);
//     Utils.spokeSupply(spoke2, wbtcReserveId, bob, MAX_SUPPLY_AMOUNT, bob);
//     // set all as collateral to allow borrowing
//     setUsingAsCollateral(spoke2, bob, daiReserveId, true);
//     setUsingAsCollateral(spoke2, bob, wethReserveId, true);
//     setUsingAsCollateral(spoke2, bob, usdxReserveId, true);
//     setUsingAsCollateral(spoke2, bob, wbtcReserveId, true);

//     DataTypes.UserPosition memory bobData = getUserInfo(spoke2, bob, daiReserveId);
//     assertEq(
//       bobData.suppliedShares,
//       hub.convertToShares(daiAssetId, MAX_SUPPLY_AMOUNT),
//       'bob supply shares before'
//     );
//     assertEq(bobData.baseDebt, 0, 'bob base debt before');
//     bobData = getUserInfo(spoke2, bob, wethReserveId);
//     assertEq(
//       bobData.suppliedShares,
//       hub.convertToShares(wethAssetId, MAX_SUPPLY_AMOUNT),
//       'bob supply shares before'
//     );
//     assertEq(bobData.baseDebt, 0, 'bob base debt before');
//     bobData = getUserInfo(spoke2, bob, usdxReserveId);
//     assertEq(
//       bobData.suppliedShares,
//       hub.convertToShares(usdxAssetId, MAX_SUPPLY_AMOUNT),
//       'bob supply shares before'
//     );
//     assertEq(bobData.baseDebt, 0, 'bob base debt before');
//     bobData = getUserInfo(spoke2, bob, wbtcReserveId);
//     assertEq(
//       bobData.suppliedShares,
//       hub.convertToShares(wbtcAssetId, MAX_SUPPLY_AMOUNT),
//       'bob supply shares before'
//     );
//     assertEq(bobData.baseDebt, 0, 'bob base debt before');

//     // Bob borrow all reserves
//     if (daiBorrowAmount > 0) {
//       assertGt(spoke2.getHealthFactor(bob), spoke2.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());
//       Utils.spokeBorrow(spoke2, daiReserveId, bob, daiBorrowAmount, bob);
//     }
//     if (wethBorrowAmount > 0) {
//       assertGt(spoke2.getHealthFactor(bob), spoke2.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());
//       Utils.spokeBorrow(spoke2, wethReserveId, bob, wethBorrowAmount, bob);
//     }
//     if (usdxBorrowAmount > 0) {
//       assertGt(spoke2.getHealthFactor(bob), spoke2.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());
//       Utils.spokeBorrow(spoke2, usdxReserveId, bob, usdxBorrowAmount, bob);
//     }
//     if (wbtcBorrowAmount > 0) {
//       assertGt(spoke2.getHealthFactor(bob), spoke2.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());
//       Utils.spokeBorrow(spoke2, wbtcReserveId, bob, wbtcBorrowAmount, bob);
//     }

//     bobData = getUserInfo(spoke2, bob, daiReserveId);
//     assertEq(
//       bobData.suppliedShares,
//       hub.convertToShares(daiAssetId, MAX_SUPPLY_AMOUNT),
//       'bob supply shares final balance'
//     );
//     assertEq(bobData.baseDebt, daiBorrowAmount, 'bob base debt dai final balance');
//     bobData = getUserInfo(spoke2, bob, wethReserveId);
//     assertEq(
//       bobData.suppliedShares,
//       hub.convertToShares(wethAssetId, MAX_SUPPLY_AMOUNT),
//       'bob supply shares final balance'
//     );
//     assertEq(bobData.baseDebt, wethBorrowAmount, 'bob base debt weth final balance');
//     bobData = getUserInfo(spoke2, bob, usdxReserveId);
//     assertEq(
//       bobData.suppliedShares,
//       hub.convertToShares(usdxAssetId, MAX_SUPPLY_AMOUNT),
//       'bob supply shares final balance'
//     );
//     assertEq(bobData.baseDebt, usdxBorrowAmount, 'bob base debt usdx final balance');
//     bobData = getUserInfo(spoke2, bob, wbtcReserveId);
//     assertEq(
//       bobData.suppliedShares,
//       hub.convertToShares(wbtcAssetId, MAX_SUPPLY_AMOUNT),
//       'bob supply shares final balance'
//     );
//     assertEq(bobData.baseDebt, wbtcBorrowAmount, 'bob base debt wbtc final balance');
  
}

  /// @dev basic case, cannot borrow an amount that leads to HF < 1
  function test_borrow_revertsWith_HealthFactorBelowThreshold() public {
    vm.skip(true, 'pending refactor');

//     uint256 daiReserveId = _daiReserveId(spoke1);
//     uint256 wethReserveId = _wethReserveId(spoke1);

//     uint256 wethSupplyAmount = 1e18;
//     uint256 maxDebtAmount = _calcMaxDebtAmount({
//       spoke: spoke1,
//       collReserveId: wethReserveId,
//       debtReserveId: daiReserveId,
//       collAmount: wethSupplyAmount
//     });

//     // Bob supply weth
//     Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);
//     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

//     // Alice supply dai
//     Utils.spokeSupply(spoke1, daiReserveId, alice, maxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

//     // Bob draw max allowed debt amt of dai reserve liquidity
//     vm.prank(bob);
//     spoke1.borrow(daiReserveId, maxDebtAmount, bob);

//     // valid HF after borrow
//     assertEq(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

//     // cannot borrow a non trivial amount that brings HF below threshold
//     vm.prank(bob);
//     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
//     spoke1.borrow(daiReserveId, 1e4, bob); // TODO: update with exact amount, resolve precision
  
}

  /// @dev cannot borrow any amount after interest has brought HF already < 1
  function test_borrow_revertsWith_HealthFactorBelowThreshold_with_interest() public {
    vm.skip(true, 'pending refactor');

//     uint256 daiReserveId = _daiReserveId(spoke1);
//     uint256 wethReserveId = _wethReserveId(spoke1);

//     uint256 wethSupplyAmount = 10e18;
//     uint256 maxDebtAmount = _calcMaxDebtAmount({
//       spoke: spoke1,
//       collReserveId: wethReserveId,
//       debtReserveId: daiReserveId,
//       collAmount: wethSupplyAmount
//     });

//     // Bob supply weth
//     Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);
//     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

//     // Alice supply dai
//     Utils.spokeSupply(spoke1, daiReserveId, alice, maxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

//     // Bob draw max allowed debt amt of dai reserve liquidity
//     vm.prank(bob);
//     spoke1.borrow(daiReserveId, maxDebtAmount, bob);

//     assertEq(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

//     // accrue debt to decrease HF
//     skip(365 days);

//     // now HF is < 1
//     assertLt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

//     vm.prank(bob);
//     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
//     spoke1.borrow(daiReserveId, 1, bob);
  
}

  /// @dev fuzz - cannot borrow any amount after interest has brought HF already < 1
  function test_borrow_fuzz_revertsWith_HealthFactorBelowThreshold_with_interest(
    uint256 skipTime
  ) public {
    vm.skip(true, 'pending refactor');

//     skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
//     uint256 daiReserveId = _daiReserveId(spoke1);
//     uint256 wethReserveId = _wethReserveId(spoke1);

//     uint256 wethSupplyAmount = 10e18;
//     uint256 maxDebtAmount = _calcMaxDebtAmount({
//       spoke: spoke1,
//       collReserveId: wethReserveId,
//       debtReserveId: daiReserveId,
//       collAmount: wethSupplyAmount
//     });

//     // Bob supply weth
//     Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);
//     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

//     // Alice supply dai
//     Utils.spokeSupply(spoke1, daiReserveId, alice, maxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

//     // Bob draw max allowed debt amt of dai reserve liquidity
//     vm.prank(bob);
//     spoke1.borrow(daiReserveId, maxDebtAmount, bob);

//     assertEq(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

//     // accrue debt to decrease HF
//     skip(skipTime);

//     vm.prank(bob);
//     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
//     spoke1.borrow(daiReserveId, 1, bob);
  
}

  /// @dev cannot borrow an amount that brings HF < 1 with multiple debts for same collateral
  function test_borrow_revertsWith_HealthFactorBelowThreshold_multiple_debts() public {
    vm.skip(true, 'pending refactor');

//     // weth collateral
//     uint256 wethReserveId = _wethReserveId(spoke1);
//     // dai/usdx debt
//     uint256 daiReserveId = _daiReserveId(spoke1);
//     uint256 usdxReserveId = _usdxReserveId(spoke1);

//     uint256 daiDebtAmount = 2000e18;
//     uint256 usdxDebtAmount = 3000e6;

//     uint256 wethCollAmountDai = _calcMinimumCollAmount({
//       spoke: spoke1,
//       collReserveId: wethReserveId,
//       debtReserveId: daiReserveId,
//       debtAmount: daiDebtAmount
//     });
//     uint256 wethCollAmountUsdx = _calcMinimumCollAmount({
//       spoke: spoke1,
//       collReserveId: wethReserveId,
//       debtReserveId: usdxReserveId,
//       debtAmount: usdxDebtAmount
//     });

//     // Bob supply weth
//     Utils.spokeSupply(spoke1, wethReserveId, bob, wethCollAmountDai + wethCollAmountUsdx, bob);
//     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

//     // Alice supply dai
//     Utils.spokeSupply(spoke1, daiReserveId, alice, daiDebtAmount * 2, alice); // supply enough buffer for multiple borrows
//     // Alice supply usdx
//     Utils.spokeSupply(spoke1, usdxReserveId, alice, usdxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

//     // Bob draw max allowed debt amt of dai/usdx reserve liquidity
//     vm.prank(bob);
//     spoke1.borrow(daiReserveId, daiDebtAmount, bob);
//     vm.prank(bob);
//     spoke1.borrow(usdxReserveId, usdxDebtAmount, bob);

//     // valid HF
//     assertEq(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

//     // cannot borrow more dai
//     vm.prank(bob);
//     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
//     spoke1.borrow(daiReserveId, 1e12, bob); // todo: update with exact amount, resolve precision

//     // cannot borrow more usdx
//     vm.prank(bob);
//     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
//     spoke1.borrow(usdxReserveId, 1, bob); // todo: update with exact amount, resolve precision
  
}

  /// @dev fuzz - cannot borrow an amount that brings HF < 1 with multiple debts for same collateral
  function test_borrow_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_debts(
    uint256 wethCollAmountDai,
    uint256 wethCollAmountUsdx
  ) public {
    vm.skip(true, 'pending refactor');

//     // todo: resolve precision bounds for wethCollAmountDai, wethCollAmountUsdx
//     // at high ratios between them, borrowing additional amounts won't bring HF < 1
//     wethCollAmountDai = bound(wethCollAmountDai, 1e10, MAX_SUPPLY_AMOUNT / 2);
//     wethCollAmountUsdx = bound(wethCollAmountUsdx, 1e10, MAX_SUPPLY_AMOUNT / 2);

//     // weth collateral
//     uint256 wethReserveId = _wethReserveId(spoke1);
//     // dai/usdx debt
//     uint256 daiReserveId = _daiReserveId(spoke1);
//     uint256 usdxReserveId = _usdxReserveId(spoke1);

//     uint256 daiDebtAmount = _calcMaxDebtAmount({
//       spoke: spoke1,
//       collReserveId: wethReserveId,
//       debtReserveId: daiReserveId,
//       collAmount: wethCollAmountDai
//     });
//     uint256 usdxDebtAmount = _calcMaxDebtAmount({
//       spoke: spoke1,
//       collReserveId: wethReserveId,
//       debtReserveId: usdxReserveId,
//       collAmount: wethCollAmountUsdx
//     });

//     vm.assume(usdxDebtAmount < MAX_SUPPLY_AMOUNT / 2 && usdxDebtAmount > 0);
//     vm.assume(daiDebtAmount < MAX_SUPPLY_AMOUNT / 2 && daiDebtAmount > 1e12); // dai is 1e18, keep within similar bounds to usdx (at 1e6)

//     // Bob supply weth
//     Utils.spokeSupply(spoke1, wethReserveId, bob, wethCollAmountDai + wethCollAmountUsdx, bob);
//     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

//     // Alice supply dai
//     Utils.spokeSupply(spoke1, daiReserveId, alice, daiDebtAmount * 2, alice); // supply enough buffer for multiple borrows
//     // Alice supply usdx
//     Utils.spokeSupply(spoke1, usdxReserveId, alice, usdxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

//     // Bob draw max allowed debt amt of dai/usdx reserve liquidity
//     vm.prank(bob);
//     spoke1.borrow(daiReserveId, daiDebtAmount, bob);
//     vm.prank(bob);
//     spoke1.borrow(usdxReserveId, usdxDebtAmount, bob);

//     // valid HF
//     assertGe(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD()); // can be GE due to low debt/coll amounts

//     // todo: should these failed amounts be 1? Could be off due to extremely edge low debt/coll amounts
//     uint256 daiFailedBorrowAmount = daiDebtAmount; // some amount guaranteed to cause HF < 1
//     uint256 usdxFailedBorrowAmount = usdxDebtAmount; // some amount guaranteed to cause HF < 1

//     // cannot borrow more dai
//     vm.prank(bob);
//     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
//     spoke1.borrow(daiReserveId, daiFailedBorrowAmount, bob);

//     // cannot borrow more usdx
//     vm.prank(bob);
//     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
//     spoke1.borrow(usdxReserveId, usdxFailedBorrowAmount, bob); // todo: update with exact amount, resolve precision
  
}

  /// @dev cannot borrow any amount if HF < 1 due to interest growth (multiple debts for same collateral)
  function test_borrow_revertsWith_HealthFactorBelowThreshold_multiple_debts_with_interest()
    public
  {
    vm.skip(true, 'pending refactor');

//     // weth collateral
//     uint256 wethReserveId = _wethReserveId(spoke1);
//     // dai/usdx debt
//     uint256 daiReserveId = _daiReserveId(spoke1);
//     uint256 usdxReserveId = _usdxReserveId(spoke1);

//     uint256 daiDebtAmount = 1_000e18;
//     uint256 usdxDebtAmount = 2_000e6;

//     uint256 wethCollAmount = _calcMinimumCollAmount({
//       spoke: spoke1,
//       collReserveId: wethReserveId,
//       debtReserveId: daiReserveId,
//       debtAmount: daiDebtAmount
//     }) +
//       _calcMinimumCollAmount({
//         spoke: spoke1,
//         collReserveId: wethReserveId,
//         debtReserveId: usdxReserveId,
//         debtAmount: usdxDebtAmount
//       });

//     // Bob supply weth
//     Utils.spokeSupply(spoke1, wethReserveId, bob, wethCollAmount, bob);
//     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

//     // Alice supply dai
//     Utils.spokeSupply(spoke1, daiReserveId, alice, daiDebtAmount * 2, alice); // supply enough buffer for multiple borrows
//     // Alice supply usdx
//     Utils.spokeSupply(spoke1, usdxReserveId, alice, usdxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

//     // Bob draw max allowed debt amt of dai/usdx reserve liquidity
//     vm.prank(bob);
//     spoke1.borrow(daiReserveId, daiDebtAmount, bob);
//     vm.prank(bob);
//     spoke1.borrow(usdxReserveId, usdxDebtAmount, bob);

//     // valid HF
//     assertApproxEqAbs(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD(), 1);

//     skip(365 days);

//     // after accrual, invalid HF
//     assertLt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

//     // cannot borrow more dai
//     vm.prank(bob);
//     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
//     spoke1.borrow(daiReserveId, 1, bob);

//     // cannot borrow more usdx
//     vm.prank(bob);
//     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
//     spoke1.borrow(usdxReserveId, 1, bob);
  
}

  /// @dev fuzz - cannot borrow any amount if HF < 1 due to interest growth (multiple debts for same collateral)
  function test_borrow_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_debts_with_interest(
    uint256 wethCollForDai,
    uint256 wethCollForUsdx,
    uint256 skipTime
  ) public {
    vm.skip(true, 'pending refactor');

//     wethCollForDai = bound(wethCollForDai, 1, MAX_SUPPLY_AMOUNT / 2);
//     wethCollForUsdx = bound(wethCollForUsdx, 1, MAX_SUPPLY_AMOUNT / 2);
//     skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

//     // weth collateral
//     uint256 wethReserveId = _wethReserveId(spoke1);
//     // dai/usdx debt
//     uint256 daiReserveId = _daiReserveId(spoke1);
//     uint256 usdxReserveId = _usdxReserveId(spoke1);

//     uint256 daiDebtAmount = _calcMaxDebtAmount({
//       spoke: spoke1,
//       collReserveId: wethReserveId,
//       debtReserveId: daiReserveId,
//       collAmount: wethCollForDai
//     });
//     uint256 usdxDebtAmount = _calcMaxDebtAmount({
//       spoke: spoke1,
//       collReserveId: wethReserveId,
//       debtReserveId: usdxReserveId,
//       collAmount: wethCollForUsdx
//     });

//     vm.assume(daiDebtAmount < MAX_SUPPLY_AMOUNT / 2 && daiDebtAmount > 0);
//     vm.assume(usdxDebtAmount < MAX_SUPPLY_AMOUNT / 2 && usdxDebtAmount > 0);

//     // Bob supply weth
//     Utils.spokeSupply(spoke1, wethReserveId, bob, wethCollForDai + wethCollForUsdx, bob);
//     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

//     // Alice supply dai
//     Utils.spokeSupply(spoke1, daiReserveId, alice, daiDebtAmount * 2, alice); // supply enough buffer for multiple borrows
//     // Alice supply usdx
//     Utils.spokeSupply(spoke1, usdxReserveId, alice, usdxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

//     // Bob draw max allowed debt amt of dai/usdx reserve liquidity
//     vm.prank(bob);
//     spoke1.borrow(daiReserveId, daiDebtAmount, bob);
//     vm.prank(bob);
//     spoke1.borrow(usdxReserveId, usdxDebtAmount, bob);

//     // valid HF
//     assertGe(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD()); // can be GE for edge cases of coll/debt amount, ie 1

//     skip(skipTime);
//     vm.assume(spoke1.getHealthFactor(bob) < spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

//     // cannot borrow more dai
//     vm.prank(bob);
//     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
//     spoke1.borrow(daiReserveId, 1, bob);

//     // cannot borrow more usdx
//     vm.prank(bob);
//     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
//     spoke1.borrow(usdxReserveId, 1, bob);
  
}

  /// @dev if HF drops below threshold due to price drop, user cannot borrow more
  function test_borrow_revertsWith_HealthFactorBelowThreshold_price_drop_weth() public {
    vm.skip(true, 'pending refactor');

//     uint256 daiReserveId = _daiReserveId(spoke1); // debt
//     uint256 wethReserveId = _wethReserveId(spoke1); // collateral

//     uint256 wethSupplyAmount = 10e18;
//     uint256 maxDebtAmount = _calcMaxDebtAmount({
//       spoke: spoke1,
//       collReserveId: wethReserveId,
//       debtReserveId: daiReserveId,
//       collAmount: wethSupplyAmount
//     });

//     // Bob supply weth
//     Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);
//     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

//     // Alice supply dai
//     Utils.spokeSupply(spoke1, daiReserveId, alice, maxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

//     // Bob draw max allowed debt amt of dai reserve liquidity
//     vm.prank(bob);
//     spoke1.borrow(daiReserveId, maxDebtAmount, bob);

//     assertEq(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

//     // collateral price drop by half so that bob is undercollateralized
//     uint256 newPrice = calcNewPrice(oracle.getAssetPrice(wethAssetId), 50_00); // 50% price drop
//     oracle.setAssetPrice(wethAssetId, newPrice);
//     assertLt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

//     vm.prank(bob);
//     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
//     spoke1.borrow(daiReserveId, 1, bob);
  
}

  /// @dev fuzz - if HF drops below threshold due to price drop, user cannot borrow more
  function test_borrow_fuzz_revertsWith_HealthFactorBelowThreshold_price_drop(
    uint256 wethSupplyAmount,
    uint256 newPrice
  ) public {
    vm.skip(true, 'pending refactor');

//     uint256 currPrice = oracle.getAssetPrice(wethAssetId);
//     newPrice = bound(newPrice, 0, currPrice - 1);
//     // weth collateral
//     wethSupplyAmount = bound(wethSupplyAmount, 1, MAX_SUPPLY_AMOUNT);

//     uint256 daiReserveId = _daiReserveId(spoke1); // debt
//     uint256 wethReserveId = _wethReserveId(spoke1); // collateral

//     uint256 wethSupplyAmount = 10e18;
//     uint256 maxDebtAmount = _calcMaxDebtAmount({
//       spoke: spoke1,
//       collReserveId: wethReserveId,
//       debtReserveId: daiReserveId,
//       collAmount: wethSupplyAmount
//     });

//     vm.assume(maxDebtAmount < MAX_SUPPLY_AMOUNT / 2 && maxDebtAmount > 0);

//     // Bob supply weth
//     Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);
//     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

//     // Alice supply dai
//     Utils.spokeSupply(spoke1, daiReserveId, alice, maxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

//     // Bob draw max allowed debt amt of dai reserve liquidity
//     vm.prank(bob);
//     spoke1.borrow(daiReserveId, maxDebtAmount, bob);

//     assertEq(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

//     // collateral price drop so that bob is undercollateralized
//     oracle.setAssetPrice(wethAssetId, newPrice);
//     assertLt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

//     vm.prank(bob);
//     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
//     spoke1.borrow(daiReserveId, 1, bob);
  
}

  /// @dev cannot borrow an amount that brings HF < 1 with multiple colls for same debt
  function test_borrow_revertsWith_HealthFactorBelowThreshold_multiple_colls() public {
    vm.skip(true, 'pending refactor');

//     // weth/dai collateral
//     uint256 wethReserveId = _wethReserveId(spoke1);
//     uint256 daiReserveId = _daiReserveId(spoke1);
//     // usdx debt
//     uint256 usdxReserveId = _usdxReserveId(spoke1);

//     uint256 usdxDebtAmountWeth = 3000e6;
//     uint256 usdxDebtAmountDai = 5000e6;

//     uint256 wethCollAmount = _calcMinimumCollAmount({
//       spoke: spoke1,
//       collReserveId: wethReserveId,
//       debtReserveId: usdxReserveId,
//       debtAmount: usdxDebtAmountWeth
//     });
//     uint256 daiCollAmount = _calcMinimumCollAmount({
//       spoke: spoke1,
//       collReserveId: daiReserveId,
//       debtReserveId: usdxReserveId,
//       debtAmount: usdxDebtAmountDai
//     });

//     // Bob supply weth collateral
//     Utils.spokeSupply(spoke1, wethReserveId, bob, wethCollAmount, bob);
//     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

//     // Bob supply dai collateral
//     Utils.spokeSupply(spoke1, daiReserveId, bob, daiCollAmount, bob);
//     setUsingAsCollateral(spoke1, bob, daiReserveId, true);

//     // Alice supply usdx
//     Utils.spokeSupply(
//       spoke1,
//       usdxReserveId,
//       alice,
//       (usdxDebtAmountWeth + usdxDebtAmountDai) * 2,
//       alice
//     ); // supply enough buffer for multiple borrows

//     // Bob draw max allowed usdx debt
//     vm.prank(bob);
//     spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

//     // valid HF
//     assertEq(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

//     // cannot borrow more usdx
//     vm.prank(bob);
//     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
//     spoke1.borrow(usdxReserveId, 1, bob);
  
}

  /// @dev fuzz - cannot borrow an amount that brings HF < 1 with multiple colls for same debt
  function test_borrow_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_colls(
    uint256 usdxDebtAmountWeth,
    uint256 usdxDebtAmountDai
  ) public {
    vm.skip(true, 'pending refactor');

//     usdxDebtAmountWeth = bound(usdxDebtAmountWeth, 1, MAX_SUPPLY_AMOUNT / 2 - 1); // so that liquidity is sufficient for next draw attempt
//     usdxDebtAmountDai = bound(usdxDebtAmountDai, 1, MAX_SUPPLY_AMOUNT / 2 - 1); // so that liquidity is sufficient for next draw attempt

//     // weth/dai collateral
//     uint256 wethReserveId = _wethReserveId(spoke1);
//     uint256 daiReserveId = _daiReserveId(spoke1);
//     // usdx debt
//     uint256 usdxReserveId = _usdxReserveId(spoke1);

//     uint256 wethCollAmount = _calcMinimumCollAmount({
//       spoke: spoke1,
//       collReserveId: wethReserveId,
//       debtReserveId: usdxReserveId,
//       debtAmount: usdxDebtAmountWeth
//     });
//     uint256 daiCollAmount = _calcMinimumCollAmount({
//       spoke: spoke1,
//       collReserveId: daiReserveId,
//       debtReserveId: usdxReserveId,
//       debtAmount: usdxDebtAmountDai
//     });

//     vm.assume(wethCollAmount < MAX_SUPPLY_AMOUNT && wethCollAmount > 0);
//     vm.assume(daiCollAmount < MAX_SUPPLY_AMOUNT && daiCollAmount > 0);

//     // Bob supply weth collateral
//     Utils.spokeSupply(spoke1, wethReserveId, bob, wethCollAmount, bob);
//     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

//     // Bob supply dai collateral
//     Utils.spokeSupply(spoke1, daiReserveId, bob, daiCollAmount, bob);
//     setUsingAsCollateral(spoke1, bob, daiReserveId, true);

//     // Alice supply usdx
//     Utils.spokeSupply(
//       spoke1,
//       usdxReserveId,
//       alice,
//       (usdxDebtAmountWeth + usdxDebtAmountDai) + 1,
//       alice
//     ); // supply enough buffer for multiple borrows

//     // Bob draw max allowed usdx debt
//     vm.prank(bob);
//     spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

//     // valid HF
//     assertGe(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD()); // can be GE due to edge cases of coll/debt ratios

//     // cannot borrow more usdx
//     vm.prank(bob);
//     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
//     spoke1.borrow(usdxReserveId, 1, bob);
  
}

  /// @dev cannot borrow any amount with multiple colls for same debt, once HF < 1 due to interest
  function test_borrow_revertsWith_HealthFactorBelowThreshold_multiple_colls_with_interest()
    public
  {
    vm.skip(true, 'pending refactor');

//     // weth/dai collateral
//     uint256 wethReserveId = _wethReserveId(spoke1);
//     uint256 daiReserveId = _daiReserveId(spoke1);
//     // usdx debt
//     uint256 usdxReserveId = _usdxReserveId(spoke1);

//     uint256 usdxDebtAmountWeth = 3000e6;
//     uint256 usdxDebtAmountDai = 5000e6;

//     uint256 wethCollAmount = _calcMinimumCollAmount({
//       spoke: spoke1,
//       collReserveId: wethReserveId,
//       debtReserveId: usdxReserveId,
//       debtAmount: usdxDebtAmountWeth
//     });
//     uint256 daiCollAmount = _calcMinimumCollAmount({
//       spoke: spoke1,
//       collReserveId: daiReserveId,
//       debtReserveId: usdxReserveId,
//       debtAmount: usdxDebtAmountDai
//     });

//     // Bob supply weth collateral
//     Utils.spokeSupply(spoke1, wethReserveId, bob, wethCollAmount, bob);
//     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

//     // Bob supply dai collateral
//     Utils.spokeSupply(spoke1, daiReserveId, bob, daiCollAmount, bob);
//     setUsingAsCollateral(spoke1, bob, daiReserveId, true);

//     // Alice supply usdx
//     Utils.spokeSupply(
//       spoke1,
//       usdxReserveId,
//       alice,
//       (usdxDebtAmountWeth + usdxDebtAmountDai) * 2,
//       alice
//     ); // supply enough buffer for multiple borrows

//     // Bob draw max allowed usdx debt
//     vm.prank(bob);
//     spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

//     // valid HF
//     assertEq(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

//     // skip time to accrue debt and reduce HF < 1
//     skip(365 days);

//     // invalid HF
//     assertLt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

//     // cannot borrow more usdx
//     vm.prank(bob);
//     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
//     spoke1.borrow(usdxReserveId, 1, bob);
  
}

  /// @dev fuzz - cannot borrow any amount with multiple colls for same debt, once HF < 1 due to interest
  function test_borrow_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_colls_with_interest(
    uint256 usdxDebtAmountWeth,
    uint256 usdxDebtAmountDai,
    uint256 skipTime
  ) public {
    vm.skip(true, 'pending refactor');

//     usdxDebtAmountWeth = bound(usdxDebtAmountWeth, 1, MAX_SUPPLY_AMOUNT / 2 - 1); // so that additional draw has liquidity
//     usdxDebtAmountDai = bound(usdxDebtAmountDai, 1, MAX_SUPPLY_AMOUNT / 2 - 1); // so that additional draw has liquidity
//     skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

//     // weth/dai collateral
//     uint256 wethReserveId = _wethReserveId(spoke1);
//     uint256 daiReserveId = _daiReserveId(spoke1);
//     // usdx debt
//     uint256 usdxReserveId = _usdxReserveId(spoke1);

//     uint256 wethCollAmount = _calcMinimumCollAmount({
//       spoke: spoke1,
//       collReserveId: wethReserveId,
//       debtReserveId: usdxReserveId,
//       debtAmount: usdxDebtAmountWeth
//     });
//     uint256 daiCollAmount = _calcMinimumCollAmount({
//       spoke: spoke1,
//       collReserveId: daiReserveId,
//       debtReserveId: usdxReserveId,
//       debtAmount: usdxDebtAmountDai
//     });

//     vm.assume(wethCollAmount < MAX_SUPPLY_AMOUNT && wethCollAmount > 0);
//     vm.assume(daiCollAmount < MAX_SUPPLY_AMOUNT && daiCollAmount > 0);

//     // Bob supply weth collateral
//     Utils.spokeSupply(spoke1, wethReserveId, bob, wethCollAmount, bob);
//     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

//     // Bob supply dai collateral
//     Utils.spokeSupply(spoke1, daiReserveId, bob, daiCollAmount, bob);
//     setUsingAsCollateral(spoke1, bob, daiReserveId, true);

//     // Alice supply usdx
//     Utils.spokeSupply(spoke1, usdxReserveId, alice, MAX_SUPPLY_AMOUNT, alice); // supply enough buffer for multiple borrows

//     // Bob draw max allowed usdx debt
//     vm.prank(bob);
//     spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

//     // valid HF
//     assertGe(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD()); // can be GE due to edge cases of coll/debt ratios

//     // skip time to accrue debt and reduce HF < 1
//     skip(skipTime);

//     // invalid HF
//     vm.assume(spoke1.getHealthFactor(bob) < spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());
//     vm.assume(hub.getAvailableLiquidity(usdxAssetId) > 0);

//     // cannot borrow more usdx
//     vm.prank(bob);
//     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
//     spoke1.borrow(usdxReserveId, 1, bob);
  
}

  /// @dev cannot borrow more with multiple colls for same debt, if HF drops below threshold due to price drop
  function test_borrow_revertsWith_HealthFactorBelowThreshold_multiple_colls_price_drop_weth()
    public
  {
    vm.skip(true, 'pending refactor');

//     // weth/dai collateral
//     uint256 wethReserveId = _wethReserveId(spoke1);
//     uint256 daiReserveId = _daiReserveId(spoke1);
//     // usdx debt
//     uint256 usdxReserveId = _usdxReserveId(spoke1);

//     uint256 usdxDebtAmountWeth = 3000e6;
//     uint256 usdxDebtAmountDai = 5000e6;

//     uint256 wethCollAmount = _calcMinimumCollAmount({
//       spoke: spoke1,
//       collReserveId: wethReserveId,
//       debtReserveId: usdxReserveId,
//       debtAmount: usdxDebtAmountWeth
//     });
//     uint256 daiCollAmount = _calcMinimumCollAmount({
//       spoke: spoke1,
//       collReserveId: daiReserveId,
//       debtReserveId: usdxReserveId,
//       debtAmount: usdxDebtAmountDai
//     });

//     // Bob supply weth collateral
//     Utils.spokeSupply(spoke1, wethReserveId, bob, wethCollAmount, bob);
//     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

//     // Bob supply dai collateral
//     Utils.spokeSupply(spoke1, daiReserveId, bob, daiCollAmount, bob);
//     setUsingAsCollateral(spoke1, bob, daiReserveId, true);

//     // Alice supply usdx
//     Utils.spokeSupply(
//       spoke1,
//       usdxReserveId,
//       alice,
//       (usdxDebtAmountWeth + usdxDebtAmountDai) * 2,
//       alice
//     ); // supply enough buffer for multiple borrows

//     // Bob draw max allowed usdx debt
//     vm.prank(bob);
//     spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

//     // valid HF
//     assertEq(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

//     // collateral price drop by half so that bob is undercollateralized
//     uint256 newPrice = calcNewPrice(oracle.getAssetPrice(wethAssetId), 50_00); // 50% price drop
//     oracle.setAssetPrice(wethAssetId, newPrice);

//     // invalid HF
//     assertLt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

//     // cannot borrow more usdx
//     vm.prank(bob);
//     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
//     spoke1.borrow(usdxReserveId, 1, bob);
  
}

  /// @dev fuzz - cannot borrow more with multiple colls for same debt, if HF drops below threshold due to price drop
  function test_fuzz_borrow_revertsWith_HealthFactorBelowThreshold_multiple_colls_price_drop_weth(
    uint256 newPrice,
    uint256 usdxDebtAmountWeth,
    uint256 usdxDebtAmountDai
  ) public {
    vm.skip(true, 'pending refactor');

//     uint256 currPrice = oracle.getAssetPrice(wethAssetId);
//     newPrice = bound(newPrice, 0, currPrice - 1);
//     usdxDebtAmountWeth = bound(usdxDebtAmountWeth, 1, MAX_SUPPLY_AMOUNT / 4);
//     usdxDebtAmountDai = bound(usdxDebtAmountDai, 1, MAX_SUPPLY_AMOUNT / 4);

//     // weth/dai collateral
//     uint256 wethReserveId = _wethReserveId(spoke1);
//     uint256 daiReserveId = _daiReserveId(spoke1);
//     // usdx debt
//     uint256 usdxReserveId = _usdxReserveId(spoke1);

//     uint256 wethCollAmount = _calcMinimumCollAmount({
//       spoke: spoke1,
//       collReserveId: wethReserveId,
//       debtReserveId: usdxReserveId,
//       debtAmount: usdxDebtAmountWeth
//     });
//     uint256 daiCollAmount = _calcMinimumCollAmount({
//       spoke: spoke1,
//       collReserveId: daiReserveId,
//       debtReserveId: usdxReserveId,
//       debtAmount: usdxDebtAmountDai
//     });

//     vm.assume(wethCollAmount < MAX_SUPPLY_AMOUNT && wethCollAmount > 0);
//     vm.assume(daiCollAmount < MAX_SUPPLY_AMOUNT && daiCollAmount > 0);

//     // Bob supply weth collateral
//     Utils.spokeSupply(spoke1, wethReserveId, bob, wethCollAmount, bob);
//     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

//     // Bob supply dai collateral
//     Utils.spokeSupply(spoke1, daiReserveId, bob, daiCollAmount, bob);
//     setUsingAsCollateral(spoke1, bob, daiReserveId, true);

//     // Alice supply usdx
//     Utils.spokeSupply(spoke1, usdxReserveId, alice, MAX_SUPPLY_AMOUNT, alice); // supply enough buffer for multiple borrows

//     // Bob draw max allowed usdx debt
//     vm.prank(bob);
//     spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

//     // valid HF
//     assertGe(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD()); // can be GE due to edge cases

//     // collateral price drop by half so that bob is undercollateralized
//     uint256 newPrice = calcNewPrice(oracle.getAssetPrice(wethAssetId), 50_00); // 50% price drop
//     oracle.setAssetPrice(wethAssetId, newPrice);

//     // invalid HF
//     assertLt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

//     // cannot borrow more usdx
//     vm.prank(bob);
//     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
//     spoke1.borrow(usdxReserveId, 1, bob);
  
}

  /// @dev cannot borrow more with multiple colls for same debt, if HF drops below threshold due to price drop
  function test_borrow_revertsWith_HealthFactorBelowThreshold_multiple_colls_price_drop_dai()
    public
  {
    vm.skip(true, 'pending refactor');

//     // weth/dai collateral
//     uint256 wethReserveId = _wethReserveId(spoke1);
//     uint256 daiReserveId = _daiReserveId(spoke1);
//     // usdx debt
//     uint256 usdxReserveId = _usdxReserveId(spoke1);

//     uint256 usdxDebtAmountWeth = 3000e6;
//     uint256 usdxDebtAmountDai = 5000e6;

//     uint256 wethCollAmount = _calcMinimumCollAmount({
//       spoke: spoke1,
//       collReserveId: wethReserveId,
//       debtReserveId: usdxReserveId,
//       debtAmount: usdxDebtAmountWeth
//     });
//     uint256 daiCollAmount = _calcMinimumCollAmount({
//       spoke: spoke1,
//       collReserveId: daiReserveId,
//       debtReserveId: usdxReserveId,
//       debtAmount: usdxDebtAmountDai
//     });

//     // Bob supply weth collateral
//     Utils.spokeSupply(spoke1, wethReserveId, bob, wethCollAmount, bob);
//     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

//     // Bob supply dai collateral
//     Utils.spokeSupply(spoke1, daiReserveId, bob, daiCollAmount, bob);
//     setUsingAsCollateral(spoke1, bob, daiReserveId, true);

//     // Alice supply usdx
//     Utils.spokeSupply(
//       spoke1,
//       usdxReserveId,
//       alice,
//       (usdxDebtAmountWeth + usdxDebtAmountDai) * 2,
//       alice
//     ); // supply enough buffer for multiple borrows

//     // Bob draw max allowed usdx debt
//     vm.prank(bob);
//     spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

//     // valid HF
//     assertEq(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

//     // collateral price drop by half so that bob is undercollateralized
//     uint256 newPrice = calcNewPrice(oracle.getAssetPrice(daiAssetId), 50_00); // 50% price drop
//     oracle.setAssetPrice(daiAssetId, newPrice);

//     // invalid HF
//     assertLt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

//     // cannot borrow more usdx
//     vm.prank(bob);
//     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
//     spoke1.borrow(usdxReserveId, 1, bob);
  
}

  /// @dev fuzz - cannot borrow more with multiple colls for same debt, if HF drops below threshold due to price drop
  function test_fuzz_borrow_revertsWith_HealthFactorBelowThreshold_multiple_colls_price_drop_dai(
    uint256 newPrice,
    uint256 usdxDebtAmountWeth,
    uint256 usdxDebtAmountDai
  ) public {
    vm.skip(true, 'pending refactor');

//     uint256 currPrice = oracle.getAssetPrice(wethAssetId);
//     newPrice = bound(newPrice, 0, currPrice - 1);
//     usdxDebtAmountWeth = bound(usdxDebtAmountWeth, 1, MAX_SUPPLY_AMOUNT / 4);
//     usdxDebtAmountDai = bound(usdxDebtAmountDai, 1, MAX_SUPPLY_AMOUNT / 4);

//     // weth/dai collateral
//     uint256 wethReserveId = _wethReserveId(spoke1);
//     uint256 daiReserveId = _daiReserveId(spoke1);
//     // usdx debt
//     uint256 usdxReserveId = _usdxReserveId(spoke1);

//     uint256 wethCollAmount = _calcMinimumCollAmount({
//       spoke: spoke1,
//       collReserveId: wethReserveId,
//       debtReserveId: usdxReserveId,
//       debtAmount: usdxDebtAmountWeth
//     });
//     uint256 daiCollAmount = _calcMinimumCollAmount({
//       spoke: spoke1,
//       collReserveId: daiReserveId,
//       debtReserveId: usdxReserveId,
//       debtAmount: usdxDebtAmountDai
//     });

//     vm.assume(wethCollAmount < MAX_SUPPLY_AMOUNT && wethCollAmount > 0);
//     vm.assume(daiCollAmount < MAX_SUPPLY_AMOUNT && daiCollAmount > 0);

//     // Bob supply weth collateral
//     Utils.spokeSupply(spoke1, wethReserveId, bob, wethCollAmount, bob);
//     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

//     // Bob supply dai collateral
//     Utils.spokeSupply(spoke1, daiReserveId, bob, daiCollAmount, bob);
//     setUsingAsCollateral(spoke1, bob, daiReserveId, true);

//     // Alice supply usdx
//     Utils.spokeSupply(spoke1, usdxReserveId, alice, MAX_SUPPLY_AMOUNT, alice); // supply enough buffer for multiple borrows

//     // Bob draw max allowed usdx debt
//     vm.prank(bob);
//     spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

//     // valid HF
//     assertGe(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD()); // can be GE due to edge cases

//     // collateral price drop by half so that bob is undercollateralized
//     uint256 newPrice = calcNewPrice(oracle.getAssetPrice(daiAssetId), 50_00); // 50% price drop
//     oracle.setAssetPrice(daiAssetId, newPrice);

//     // invalid HF
//     assertLt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

//     // cannot borrow more usdx
//     vm.prank(bob);
//     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
//     spoke1.borrow(usdxReserveId, 1, bob);
  
}

  // TODO: tests with other combos of collateral/debt, particularly with different units
  // - 2 colls, 1e18/1e6, with 1 debt, 1e0
  // - 2 colls, 1e18/1e0, with 1 debt, 1e6
  // - 2 colls, 1e6/1e0, with 1 debt, 1e18
  // - 1 coll, 1e0, with 2 debts, 1e18/1e6
  // - 1 coll, 1e6, with 2 debts, 1e18/1e0
  // - 1 coll, 1e18, with 2 debts, 1e6/1e0
}
