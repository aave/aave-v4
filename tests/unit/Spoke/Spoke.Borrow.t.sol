// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeBorrowTest is SpokeBase {
  // TODO: clean up unneeded vars
  struct BorrowTestData {
    DataTypes.UserPosition bobDaiData;
    DataTypes.UserPosition bobWethData;
    DataTypes.UserPosition bobUsdxData;
    DataTypes.UserPosition bobWbtcData;
    DataTypes.UserPosition bobDaiData2;
    DataTypes.UserPosition bobUsdxData2;
    DataTypes.UserPosition bobDaiDataFinal;
    DataTypes.UserPosition bobUsdxDataFinal;
    DataTypes.UserPosition bobDaiData2Final;
    DataTypes.UserPosition bobUsdxData2Final;
    DataTypes.UserPosition aliceDaiData;
    DataTypes.UserPosition aliceWethData;
    DataTypes.UserPosition aliceUsdxData;
    DataTypes.UserPosition aliceDaiDataCalc;
    DataTypes.UserPosition aliceUsdxDataCalc;
    DataTypes.UserPosition bobDaiDataCalc;
    DataTypes.UserPosition bobWethDataCalc;
    DataTypes.UserPosition bobUsdxDataCalc;
    DataTypes.UserPosition bobWbtcDataCalc;
    DataTypes.UserPosition bobDaiDataCalc2;
    DataTypes.UserPosition bobUsdxDataCalc2;
    uint256 daiReserveId;
    uint256 wethReserveId;
    uint256 daiSupplyAmount;
    uint256 daiSupplyAmount2;
    uint256 usdxSupplyAmount;
    uint256 usdxSupplyAmount2;
    uint256 wethSupplyAmount;
    uint256 daiBorrowAmount;
    uint256 bobDaiBalanceBefore;
    uint256 bobWethBalanceBefore;
    uint256 aliceDaiBalanceBefore;
    uint256 aliceWethBalanceBefore;
    uint256 bobDaiBalanceAfter;
    uint256 bobWethBalanceAfter;
    uint256 aliceDaiBalanceAfter;
    uint256 aliceWethBalanceAfter;
  }
  function test_borrow_revertsWith_ReserveNotBorrowable() public {
    uint256 daiReserveId = _daiReserveId(spoke1);

    // set reserve not borrowable
    updateReserveBorrowableFlag(spoke1, daiReserveId, false);
    assertFalse(spoke1.getReserve(daiReserveId).config.borrowable);

    // Bob try to draw some dai
    vm.expectRevert(abi.encodeWithSelector(ISpoke.ReserveNotBorrowable.selector, daiReserveId));
    vm.prank(bob);
    spoke1.borrow(daiReserveId, 1, bob);
  }

  function test_borrow_fuzz_revertsWith_ReserveNotBorrowable(
    uint256 reserveId,
    uint256 amount
  ) public {
    reserveId = bound(reserveId, 0, spoke1.reserveCount() - 1);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    // set reserve not borrowable
    updateReserveBorrowableFlag(spoke1, reserveId, false);
    assertFalse(spoke1.getReserve(reserveId).config.borrowable);

    // Bob tries to draw
    vm.expectRevert(abi.encodeWithSelector(ISpoke.ReserveNotBorrowable.selector, reserveId));
    vm.prank(bob);
    spoke1.borrow(reserveId, amount, bob);
  }

  function test_borrow_revertsWith_ReserveNotActive() public {
    uint256 daiReserveId = _daiReserveId(spoke1);

    updateReserveActiveFlag(spoke1, daiReserveId, false);
    assertFalse(spoke1.getReserve(daiReserveId).config.active);

    // Bob try to draw some dai
    vm.expectRevert(ISpoke.ReserveNotActive.selector);
    vm.prank(bob);
    spoke1.borrow(daiReserveId, 1, bob);
  }

  function test_borrow_fuzz_revertsWith_ReserveNotActive(uint256 reserveId, uint256 amount) public {
    reserveId = bound(reserveId, 0, spoke1.reserveCount() - 1);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    updateReserveActiveFlag(spoke1, reserveId, false);
    assertFalse(spoke1.getReserve(reserveId).config.active);

    // Bob tries to draw
    vm.expectRevert(ISpoke.ReserveNotActive.selector);
    vm.prank(bob);
    spoke1.borrow(reserveId, amount, bob);
  }

  function test_borrow_revertsWith_ReserveNotListed() public {
    uint256 reserveId = spoke1.reserveCount() + 1; // invalid reserveId

    // Bob try to draw some dai
    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(bob);
    spoke1.borrow(reserveId, 1, bob);
  }

  function test_borrow_fuzz_revertsWith_ReserveNotListed(uint256 reserveId, uint256 amount) public {
    vm.assume(reserveId >= spoke1.reserveCount());
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    // Bob try to draw some dai
    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(bob);
    spoke1.borrow(reserveId, amount, bob);
  }

  function test_borrow_revertsWith_ReservePaused() public {
    uint256 daiReserveId = _daiReserveId(spoke1);

    updateReservePausedFlag(spoke1, daiReserveId, true);
    assertTrue(spoke1.getReserve(daiReserveId).config.paused);

    // Bob try to draw some dai
    vm.expectRevert(ISpoke.ReservePaused.selector);
    vm.prank(bob);
    spoke1.borrow(daiReserveId, 1, bob);
  }

  function test_borrow_fuzz_revertsWith_ReservePaused(uint256 reserveId, uint256 amount) public {
    reserveId = bound(reserveId, 0, spoke1.reserveCount() - 1);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    updateReservePausedFlag(spoke1, reserveId, true);
    assertTrue(spoke1.getReserve(reserveId).config.paused);

    // Bob try to draw
    vm.expectRevert(ISpoke.ReservePaused.selector);
    vm.prank(bob);
    spoke1.borrow(reserveId, 1, bob);
  }

  function test_borrow_revertsWith_ReserveFrozen() public {
    uint256 daiReserveId = _daiReserveId(spoke1);

    updateReserveFrozenFlag(spoke1, daiReserveId, true);
    assertTrue(spoke1.getReserve(daiReserveId).config.frozen);

    // Bob try to draw some dai
    vm.expectRevert(ISpoke.ReserveFrozen.selector);
    vm.prank(bob);
    spoke1.borrow(daiReserveId, 1, bob);
  }

  function test_borrow_fuzz_revertsWith_ReserveFrozen(uint256 reserveId, uint256 amount) public {
    reserveId = bound(reserveId, 0, spoke1.reserveCount() - 1);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    updateReserveFrozenFlag(spoke1, reserveId, true);
    assertTrue(spoke1.getReserve(reserveId).config.frozen);

    // Bob try to draw
    vm.expectRevert(ISpoke.ReserveFrozen.selector);
    vm.prank(bob);
    spoke1.borrow(reserveId, 1, bob);
  }

  function test_borrow_revertsWith_AssetNotActive() public {
    uint256 daiReserveId = _daiReserveId(spoke1);

    // set asset not active
    updateAssetActive(hub, daiAssetId, false);

    // Bob try to draw some dai

    vm.expectRevert(ILiquidityHub.AssetNotActive.selector);
    vm.prank(bob);
    spoke1.borrow(daiReserveId, 1, bob);
  }

  function test_borrow_fuzz_revertsWith_AssetNotActive(uint256 reserveId, uint256 amount) public {
    reserveId = bound(reserveId, 0, spoke1.reserveCount() - 1);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    // set asset not active
    updateAssetActive(hub, spoke1.getReserve(reserveId).assetId, false);

    // Bob try to draw
    vm.expectRevert(ILiquidityHub.AssetNotActive.selector);
    vm.prank(bob);
    spoke1.borrow(reserveId, 1, bob);
  }

  function test_borrow_revertsWith_NotAvailableLiquidity() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 wethReserveId = _wethReserveId(spoke1);

    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethAmount, bob);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiAmount, alice);

    // Bob draw more than supplied dai amount
    vm.expectRevert(
      abi.encodeWithSelector(ILiquidityHub.NotAvailableLiquidity.selector, daiAmount)
    );
    vm.prank(bob);
    spoke1.borrow(daiReserveId, daiAmount + 1, bob);
  }

  function test_borrow_revertsWith_InvalidDrawAmount() public {
    // Bob draw 0 dai

    vm.expectRevert(ILiquidityHub.InvalidDrawAmount.selector);
    vm.prank(bob);
    spoke1.borrow(_daiReserveId(spoke1), 0, bob);
  }

  function test_borrow_revertsWith_DrawCapExceeded() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 drawCap = 100e18;
    uint256 drawAmount = drawCap + 1;

    updateDrawCap(hub, daiAssetId, address(spoke1), drawCap);

    // Bob borrow dai amount exceeding draw cap
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.DrawCapExceeded.selector, drawCap));
    vm.prank(bob);
    spoke1.borrow(daiReserveId, drawAmount, bob);
  }

  function test_borrow_fuzz_revertsWith_DrawCapExceeded(uint256 reserveId, uint256 drawCap) public {
    reserveId = bound(reserveId, 0, spoke1.reserveCount() - 1);
    drawCap = bound(drawCap, 1, MAX_SUPPLY_AMOUNT);

    uint256 drawAmount = drawCap + 1;

    uint256 assetId = spoke1.getReserve(reserveId).assetId;
    updateDrawCap(hub, assetId, address(spoke1), drawCap);
    assertEq(hub.getSpoke(assetId, address(spoke1)).config.drawCap, drawCap);

    // Bob borrow dai amount exceeding draw cap
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.DrawCapExceeded.selector, drawCap));
    vm.prank(bob);
    spoke1.borrow(reserveId, drawAmount, bob);
  }

  function test_borrow_revertsWith_DrawCapExceeded_due_to_interest() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 wethReserveId = _wethReserveId(spoke1);

    uint256 daiAmount = 100e18;
    uint256 drawCap = daiAmount;
    uint256 wethSupplyAmount = 10e18;
    uint256 drawAmount = drawCap - 1;

    updateDrawCap(hub, daiAssetId, address(spoke1), drawCap);

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiAmount, alice);

    // Bob draw dai
    Utils.spokeBorrow(spoke1, daiReserveId, bob, drawAmount, bob);

    assertGt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    skip(365 days);

    // Additional supply to accrue interest
    Utils.spokeSupply(spoke1, daiReserveId, bob, 1e18, bob);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.DrawCapExceeded.selector, drawCap));
    Utils.spokeBorrow(spoke1, daiReserveId, bob, 1, bob);
  }

  function test_borrow() public {
    BorrowTestData memory state;

    state.daiReserveId = _daiReserveId(spoke1);
    state.wethReserveId = _wethReserveId(spoke1);

    state.daiSupplyAmount = 100e18;
    state.wethSupplyAmount = 10e18;
    state.daiBorrowAmount = state.daiSupplyAmount;

    // Bob supply weth
    Utils.spokeSupply(spoke1, state.wethReserveId, bob, state.wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, state.wethReserveId, true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, state.daiReserveId, alice, state.daiSupplyAmount, alice);

    state.bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    state.bobWethBalanceBefore = tokenList.weth.balanceOf(bob);
    state.aliceDaiBalanceBefore = tokenList.dai.balanceOf(alice);
    state.aliceWethBalanceBefore = tokenList.weth.balanceOf(alice);

    _assertUserDebtAndSuppliedShares({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: bob,
      borrowAmount: 0,
      suppliedAmount: 0,
      label: 'bob dai data before'
    });
    _assertUserDebtAndSuppliedShares({
      spoke: spoke1,
      reserveId: state.wethReserveId,
      user: bob,
      borrowAmount: 0,
      suppliedAmount: state.wethSupplyAmount,
      label: 'bob weth data before'
    });
    _assertUserDebtAndSuppliedShares({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: alice,
      borrowAmount: 0,
      suppliedAmount: state.daiSupplyAmount,
      label: 'alice dai data before'
    });
    _assertUserDebtAndSuppliedShares({
      spoke: spoke1,
      reserveId: state.wethReserveId,
      user: alice,
      borrowAmount: 0,
      suppliedAmount: 0,
      label: 'alice weth data before'
    });

    // token balance
    assertEq(tokenList.dai.balanceOf(bob), state.bobDaiBalanceBefore);
    assertEq(tokenList.weth.balanceOf(bob), state.bobWethBalanceBefore);
    assertEq(tokenList.dai.balanceOf(alice), state.aliceDaiBalanceBefore);
    assertEq(tokenList.weth.balanceOf(alice), state.aliceWethBalanceBefore);

    // Bob draw half of dai reserve liquidity
    vm.startPrank(bob);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Borrow(
      state.daiReserveId,
      bob,
      hub.convertToDrawnShares(daiAssetId, state.daiBorrowAmount),
      bob
    );
    spoke1.borrow(state.daiReserveId, state.daiBorrowAmount, bob);
    vm.stopPrank();

    state.bobDaiBalanceAfter = tokenList.dai.balanceOf(bob);
    state.bobWethBalanceAfter = tokenList.weth.balanceOf(bob);
    state.aliceDaiBalanceAfter = tokenList.dai.balanceOf(alice);
    state.aliceWethBalanceAfter = tokenList.weth.balanceOf(alice);

    _assertUserDebtAndSuppliedShares({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: bob,
      borrowAmount: state.daiBorrowAmount,
      suppliedAmount: 0,
      label: 'bob dai data after'
    });
    _assertUserDebtAndSuppliedShares({
      spoke: spoke1,
      reserveId: state.wethReserveId,
      user: bob,
      borrowAmount: 0,
      suppliedAmount: state.wethSupplyAmount,
      label: 'bob weth data after'
    });
    _assertUserDebtAndSuppliedShares({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: alice,
      borrowAmount: 0,
      suppliedAmount: state.daiSupplyAmount,
      label: 'alice dai data after'
    });
    _assertUserDebtAndSuppliedShares({
      spoke: spoke1,
      reserveId: state.wethReserveId,
      user: alice,
      borrowAmount: 0,
      suppliedAmount: 0,
      label: 'alice weth data after'
    });

    // spoke
    assertEq(
      spoke1.getReserveSuppliedShares(state.daiReserveId),
      spoke1.getUserSuppliedShares(state.daiReserveId, alice),
      'spoke dai suppliedShares'
    );
    assertEq(
      spoke1.getReserveSuppliedShares(state.wethReserveId),
      spoke1.getUserSuppliedShares(state.wethReserveId, bob),
      'spoke weth suppliedShares'
    );

    _assertUserAndReserveDebt(spoke1, state.daiReserveId, bob, 'bob dai after');
  }

  function test_borrow_fuzz_amounts(uint256 wethSupplyAmount, uint256 daiBorrowAmount) public {
    BorrowTestData memory state;

    wethSupplyAmount = bound(wethSupplyAmount, 1, MAX_SUPPLY_AMOUNT);
    daiBorrowAmount = bound(daiBorrowAmount, 1, wethSupplyAmount); // to maintain HF

    state.daiReserveId = _daiReserveId(spoke1);
    state.wethReserveId = _wethReserveId(spoke1);

    // Bob supply weth
    Utils.spokeSupply(spoke1, state.wethReserveId, bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, state.wethReserveId, true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, state.daiReserveId, alice, daiBorrowAmount, alice);

    state.bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    state.bobWethBalanceBefore = tokenList.weth.balanceOf(bob);
    state.aliceDaiBalanceBefore = tokenList.dai.balanceOf(alice);
    state.aliceWethBalanceBefore = tokenList.weth.balanceOf(alice);
    // token balance
    assertEq(tokenList.dai.balanceOf(bob), state.bobDaiBalanceBefore);
    assertEq(tokenList.weth.balanceOf(bob), state.bobWethBalanceBefore);
    assertEq(tokenList.dai.balanceOf(alice), state.aliceDaiBalanceBefore);
    assertEq(tokenList.weth.balanceOf(alice), state.aliceWethBalanceBefore);

    _assertUserDebtAndSuppliedShares({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: bob,
      borrowAmount: 0,
      suppliedAmount: 0,
      label: 'bob dai data before'
    });
    _assertUserDebtAndSuppliedShares({
      spoke: spoke1,
      reserveId: state.wethReserveId,
      user: bob,
      borrowAmount: 0,
      suppliedAmount: wethSupplyAmount,
      label: 'bob weth data before'
    });
    _assertUserDebtAndSuppliedShares({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: alice,
      borrowAmount: 0,
      suppliedAmount: daiBorrowAmount,
      label: 'alice dai data before'
    });
    _assertUserDebtAndSuppliedShares({
      spoke: spoke1,
      reserveId: state.wethReserveId,
      user: alice,
      borrowAmount: 0,
      suppliedAmount: 0,
      label: 'alice weth data before'
    });

    // Bob draw dai
    vm.expectEmit(address(spoke1));
    emit ISpoke.Borrow(
      state.daiReserveId,
      bob,
      hub.convertToDrawnShares(daiAssetId, daiBorrowAmount),
      bob
    );
    vm.prank(bob);
    spoke1.borrow(state.daiReserveId, daiBorrowAmount, bob);

    state.bobDaiBalanceAfter = tokenList.dai.balanceOf(bob);
    state.bobWethBalanceAfter = tokenList.weth.balanceOf(bob);
    state.aliceDaiBalanceAfter = tokenList.dai.balanceOf(alice);
    state.aliceWethBalanceAfter = tokenList.weth.balanceOf(alice);

    // token balance
    assertEq(tokenList.dai.balanceOf(bob), state.bobDaiBalanceAfter, 'bob dai balance after');
    assertEq(tokenList.weth.balanceOf(bob), state.bobWethBalanceAfter, 'bob weth balance after');
    assertEq(tokenList.dai.balanceOf(alice), state.aliceDaiBalanceAfter, 'alice dai balance after');
    assertEq(
      tokenList.weth.balanceOf(alice),
      state.aliceWethBalanceAfter,
      'alice weth balance after'
    );

    _assertUserDebtAndSuppliedShares({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: bob,
      borrowAmount: daiBorrowAmount,
      suppliedAmount: 0,
      label: 'bob dai data after'
    });
    _assertUserDebtAndSuppliedShares({
      spoke: spoke1,
      reserveId: state.wethReserveId,
      user: bob,
      borrowAmount: 0,
      suppliedAmount: wethSupplyAmount,
      label: 'bob weth data after'
    });
    _assertUserDebtAndSuppliedShares({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: alice,
      borrowAmount: 0,
      suppliedAmount: daiBorrowAmount,
      label: 'alice dai data after'
    });
    _assertUserDebtAndSuppliedShares({
      spoke: spoke1,
      reserveId: state.wethReserveId,
      user: alice,
      borrowAmount: 0,
      suppliedAmount: 0,
      label: 'alice weth data after'
    });

    _assertUserAndReserveDebt(spoke1, state.daiReserveId, bob, 'bob dai after');
  }

  /// fuzz - 2 users borrowing 2 assets from 1 spoke
  function test_borrow_fuzz_single_spoke_multi_reserves_multi_user(
    uint256 daiBorrowAmount,
    uint256 usdxBorrowAmount,
    uint256 daiBorrowAmount2,
    uint256 usdxBorrowAmount2,
    uint256 skipTime
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 4);
    usdxBorrowAmount = bound(usdxBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 4);
    daiBorrowAmount2 = bound(daiBorrowAmount2, 0, MAX_SUPPLY_AMOUNT / 4);
    usdxBorrowAmount2 = bound(usdxBorrowAmount2, 0, MAX_SUPPLY_AMOUNT / 4);
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME);

    BorrowTestData memory state;

    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    state.daiSupplyAmount = state.usdxSupplyAmount = state.daiSupplyAmount2 = state
      .usdxSupplyAmount2 = MAX_SUPPLY_AMOUNT / 2;

    // Alice supply through spoke1
    Utils.spokeSupply(spoke1, daiReserveId, alice, state.daiSupplyAmount, alice);
    Utils.spokeSupply(spoke1, usdxReserveId, alice, state.usdxSupplyAmount, alice);
    // Bob supply through spoke1
    Utils.spokeSupply(spoke1, daiReserveId, bob, state.daiSupplyAmount2, bob);
    Utils.spokeSupply(spoke1, usdxReserveId, bob, state.usdxSupplyAmount2, bob);

    // set all as collateral to allow borrowing
    setUsingAsCollateral(spoke1, alice, daiReserveId, true);
    setUsingAsCollateral(spoke1, alice, usdxReserveId, true);
    setUsingAsCollateral(spoke1, bob, daiReserveId, true);
    setUsingAsCollateral(spoke1, bob, usdxReserveId, true);

    _assertUserDebtAndSuppliedShares({
      spoke: spoke1,
      reserveId: daiReserveId,
      user: alice,
      borrowAmount: 0,
      suppliedAmount: state.daiSupplyAmount,
      label: 'alice dai data before'
    });
    _assertUserDebtAndSuppliedShares({
      spoke: spoke1,
      reserveId: usdxReserveId,
      user: alice,
      borrowAmount: 0,
      suppliedAmount: state.usdxSupplyAmount,
      label: 'alice usdx data before'
    });
    _assertUserDebtAndSuppliedShares({
      spoke: spoke1,
      reserveId: daiReserveId,
      user: bob,
      borrowAmount: 0,
      suppliedAmount: state.daiSupplyAmount2,
      label: 'bob dai data before'
    });
    _assertUserDebtAndSuppliedShares({
      spoke: spoke1,
      reserveId: usdxReserveId,
      user: bob,
      borrowAmount: 0,
      suppliedAmount: state.usdxSupplyAmount2,
      label: 'bob usdx data before'
    });

    // Alice borrow all reserves
    if (daiBorrowAmount > 0) {
      assertGt(spoke1.getHealthFactor(alice), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());
      Utils.spokeBorrow(spoke1, daiReserveId, alice, daiBorrowAmount, alice);
    }
    if (usdxBorrowAmount > 0) {
      assertGt(spoke1.getHealthFactor(alice), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());
      Utils.spokeBorrow(spoke1, usdxReserveId, alice, usdxBorrowAmount, alice);
    }
    // Bob borrow all reserves
    if (daiBorrowAmount2 > 0) {
      assertGt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());
      Utils.spokeBorrow(spoke1, daiReserveId, bob, daiBorrowAmount2, bob);
    }
    if (usdxBorrowAmount2 > 0) {
      assertGt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());
      Utils.spokeBorrow(spoke1, usdxReserveId, bob, usdxBorrowAmount2, bob);
    }

    _assertUserDebtAndSuppliedShares({
      spoke: spoke1,
      reserveId: daiReserveId,
      user: alice,
      borrowAmount: daiBorrowAmount,
      suppliedAmount: state.daiSupplyAmount,
      label: 'alice dai data after'
    });
    _assertUserDebtAndSuppliedShares({
      spoke: spoke1,
      reserveId: usdxReserveId,
      user: alice,
      borrowAmount: usdxBorrowAmount,
      suppliedAmount: state.usdxSupplyAmount,
      label: 'alice usdx data after'
    });
    _assertUserDebtAndSuppliedShares({
      spoke: spoke1,
      reserveId: daiReserveId,
      user: bob,
      borrowAmount: daiBorrowAmount2,
      suppliedAmount: state.daiSupplyAmount2,
      label: 'bob dai data after'
    });
    _assertUserDebtAndSuppliedShares({
      spoke: spoke1,
      reserveId: usdxReserveId,
      user: bob,
      borrowAmount: usdxBorrowAmount2,
      suppliedAmount: state.usdxSupplyAmount2,
      label: 'bob usdx data after'
    });

    address[] memory users = new address[](2);
    users[0] = alice;
    users[1] = bob;

    _assertUsersAndReserveDebt(spoke1, daiReserveId, users, 'dai total after');
    _assertUsersAndReserveDebt(spoke1, usdxReserveId, users, 'usdx total after');
  }

  /// fuzz - 1 user borrowing 4 assets from 1 spoke
  function test_borrow_fuzz_single_spoke_multi_reserves(
    uint256 daiBorrowAmount,
    uint256 wethBorrowAmount,
    uint256 usdxBorrowAmount,
    uint256 wbtcBorrowAmount
  ) public {
    BorrowTestData memory state;

    uint256 daiReserveId = _daiReserveId(spoke2);
    uint256 wethReserveId = _wethReserveId(spoke2);
    uint256 usdxReserveId = _usdxReserveId(spoke2);
    uint256 wbtcReserveId = _wbtcReserveId(spoke2);

    daiBorrowAmount = bound(daiBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);
    wethBorrowAmount = bound(wethBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);
    usdxBorrowAmount = bound(usdxBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);
    wbtcBorrowAmount = bound(wbtcBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);

    // Bob supply all reserves
    Utils.spokeSupply(spoke2, daiReserveId, bob, MAX_SUPPLY_AMOUNT, bob);
    Utils.spokeSupply(spoke2, wethReserveId, bob, MAX_SUPPLY_AMOUNT, bob);
    Utils.spokeSupply(spoke2, usdxReserveId, bob, MAX_SUPPLY_AMOUNT, bob);
    Utils.spokeSupply(spoke2, wbtcReserveId, bob, MAX_SUPPLY_AMOUNT, bob);
    // set all as collateral to allow borrowing
    setUsingAsCollateral(spoke2, bob, daiReserveId, true);
    setUsingAsCollateral(spoke2, bob, wethReserveId, true);
    setUsingAsCollateral(spoke2, bob, usdxReserveId, true);
    setUsingAsCollateral(spoke2, bob, wbtcReserveId, true);

    _assertUserDebtAndSuppliedShares({
      spoke: spoke2,
      reserveId: daiReserveId,
      user: bob,
      borrowAmount: 0,
      suppliedAmount: MAX_SUPPLY_AMOUNT,
      label: 'bob dai data before'
    });
    _assertUserDebtAndSuppliedShares({
      spoke: spoke2,
      reserveId: wethReserveId,
      user: bob,
      borrowAmount: 0,
      suppliedAmount: MAX_SUPPLY_AMOUNT,
      label: 'bob weth data before'
    });
    _assertUserDebtAndSuppliedShares({
      spoke: spoke2,
      reserveId: usdxReserveId,
      user: bob,
      borrowAmount: 0,
      suppliedAmount: MAX_SUPPLY_AMOUNT,
      label: 'bob usdx data before'
    });
    _assertUserDebtAndSuppliedShares({
      spoke: spoke2,
      reserveId: wbtcReserveId,
      user: bob,
      borrowAmount: 0,
      suppliedAmount: MAX_SUPPLY_AMOUNT,
      label: 'bob wbtc data before'
    });

    // Bob borrow all reserves
    if (daiBorrowAmount > 0) {
      assertGt(spoke2.getHealthFactor(bob), spoke2.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());
      Utils.spokeBorrow(spoke2, daiReserveId, bob, daiBorrowAmount, bob);
    }
    if (wethBorrowAmount > 0) {
      assertGt(spoke2.getHealthFactor(bob), spoke2.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());
      Utils.spokeBorrow(spoke2, wethReserveId, bob, wethBorrowAmount, bob);
    }
    if (usdxBorrowAmount > 0) {
      assertGt(spoke2.getHealthFactor(bob), spoke2.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());
      Utils.spokeBorrow(spoke2, usdxReserveId, bob, usdxBorrowAmount, bob);
    }
    if (wbtcBorrowAmount > 0) {
      assertGt(spoke2.getHealthFactor(bob), spoke2.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());
      Utils.spokeBorrow(spoke2, wbtcReserveId, bob, wbtcBorrowAmount, bob);
    }

    _assertUserDebtAndSuppliedShares({
      spoke: spoke2,
      reserveId: daiReserveId,
      user: bob,
      borrowAmount: daiBorrowAmount,
      suppliedAmount: MAX_SUPPLY_AMOUNT,
      label: 'bob dai data after'
    });
    _assertUserDebtAndSuppliedShares({
      spoke: spoke2,
      reserveId: wethReserveId,
      user: bob,
      borrowAmount: wethBorrowAmount,
      suppliedAmount: MAX_SUPPLY_AMOUNT,
      label: 'bob weth data after'
    });
    _assertUserDebtAndSuppliedShares({
      spoke: spoke2,
      reserveId: usdxReserveId,
      user: bob,
      borrowAmount: usdxBorrowAmount,
      suppliedAmount: MAX_SUPPLY_AMOUNT,
      label: 'bob usdx data after'
    });
    _assertUserDebtAndSuppliedShares({
      spoke: spoke2,
      reserveId: wbtcReserveId,
      user: bob,
      borrowAmount: wbtcBorrowAmount,
      suppliedAmount: MAX_SUPPLY_AMOUNT,
      label: 'bob wbtc data after'
    });

    _assertUserAndReserveDebt(spoke2, daiReserveId, bob, 'bob dai after');
    _assertUserAndReserveDebt(spoke2, wethReserveId, bob, 'bob weth after');
    _assertUserAndReserveDebt(spoke2, usdxReserveId, bob, 'bob usdx after');
    _assertUserAndReserveDebt(spoke2, wbtcReserveId, bob, 'bob wbtc after');
  }

  // TODO: delete
  function test_y() public {
    test_borrow_fuzz_multi_spoke_multi_reserves(82512, 1000000000001, 2708, 10526, 21927);
  }

  /// 1 user borrowing 2 assets across 2 different spokes
  function test_borrow_fuzz_multi_spoke_multi_reserves(
    uint256 daiBorrowAmount,
    uint256 usdxBorrowAmount,
    uint256 daiBorrowAmount2,
    uint256 usdxBorrowAmount2,
    uint256 skipTime
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 4);
    usdxBorrowAmount = bound(usdxBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 4);
    daiBorrowAmount2 = bound(daiBorrowAmount2, 0, MAX_SUPPLY_AMOUNT / 4);
    usdxBorrowAmount2 = bound(usdxBorrowAmount2, 0, MAX_SUPPLY_AMOUNT / 4);
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME);

    BorrowTestData memory state;

    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);
    uint256 daiReserveId2 = _daiReserveId(spoke2);
    uint256 usdxReserveId2 = _usdxReserveId(spoke2);

    state.daiSupplyAmount = state.usdxSupplyAmount = state.daiSupplyAmount2 = state
      .usdxSupplyAmount2 = MAX_SUPPLY_AMOUNT / 2;

    // Bob supply through spoke1
    Utils.spokeSupply(spoke1, daiReserveId, bob, state.daiSupplyAmount, bob);
    Utils.spokeSupply(spoke1, usdxReserveId, bob, state.usdxSupplyAmount, bob);
    // Bob supply through spoke1
    Utils.spokeSupply(spoke2, daiReserveId2, bob, state.daiSupplyAmount2, bob);
    Utils.spokeSupply(spoke2, usdxReserveId2, bob, state.usdxSupplyAmount2, bob);

    // set all as collateral to allow borrowing
    setUsingAsCollateral(spoke1, bob, daiReserveId, true);
    setUsingAsCollateral(spoke1, bob, usdxReserveId, true);
    setUsingAsCollateral(spoke2, bob, daiReserveId, true);
    setUsingAsCollateral(spoke2, bob, usdxReserveId, true);

    _assertUserDebtAndSuppliedShares(
      spoke1,
      daiReserveId,
      bob,
      0,
      state.daiSupplyAmount,
      'spoke1 dai before'
    );
    _assertUserDebtAndSuppliedShares(
      spoke1,
      usdxReserveId,
      bob,
      0,
      state.usdxSupplyAmount,
      'spoke1 usdx before'
    );
    _assertUserDebtAndSuppliedShares(
      spoke2,
      daiReserveId2,
      bob,
      0,
      state.daiSupplyAmount2,
      'spoke2 dai before'
    );
    _assertUserDebtAndSuppliedShares(
      spoke2,
      usdxReserveId2,
      bob,
      0,
      state.usdxSupplyAmount2,
      'spoke2 usdx before'
    );

    // Bob borrow all reserves
    if (daiBorrowAmount > 0) {
      assertGt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());
      Utils.spokeBorrow(spoke1, daiReserveId, bob, daiBorrowAmount, bob);
    }
    if (usdxBorrowAmount > 0) {
      assertGt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());
      Utils.spokeBorrow(spoke1, usdxReserveId, bob, usdxBorrowAmount, bob);
    }
    if (daiBorrowAmount2 > 0) {
      assertGt(spoke2.getHealthFactor(bob), spoke2.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());
      Utils.spokeBorrow(spoke2, daiReserveId2, bob, daiBorrowAmount2, bob);
    }
    if (usdxBorrowAmount2 > 0) {
      assertGt(spoke2.getHealthFactor(bob), spoke2.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());
      Utils.spokeBorrow(spoke2, usdxReserveId2, bob, usdxBorrowAmount2, bob);
    }

    // spoke1
    // dai
    _assertUserDebtAndSuppliedShares(
      spoke1,
      daiReserveId,
      bob,
      daiBorrowAmount,
      state.daiSupplyAmount,
      'spoke1 dai after'
    );
    // usdx
    _assertUserDebtAndSuppliedShares(
      spoke1,
      usdxReserveId,
      bob,
      usdxBorrowAmount,
      state.usdxSupplyAmount,
      'spoke1 usdx after'
    );

    // spoke2
    // dai
    _assertUserDebtAndSuppliedShares(
      spoke2,
      daiReserveId2,
      bob,
      daiBorrowAmount2,
      state.daiSupplyAmount2,
      'spoke2 dai after'
    );
    // usdx
    _assertUserDebtAndSuppliedShares(
      spoke2,
      usdxReserveId2,
      bob,
      usdxBorrowAmount2,
      state.usdxSupplyAmount2,
      'spoke2 usdx after'
    );

    // user accounting should match reserve accounting
    _assertUserAndReserveDebt(spoke1, daiReserveId, bob, 'spoke1 bob dai after');
    _assertUserAndReserveDebt(spoke1, usdxReserveId, bob, 'spoke1 bob usdx after');
    _assertUserAndReserveDebt(spoke2, daiReserveId2, bob, 'spoke2 bob dai after');
    _assertUserAndReserveDebt(spoke2, usdxReserveId2, bob, 'spoke2 bob usdx after');
  }

  /// basic case, cannot borrow an amount that leads to HF < 1
  function test_borrow_revertsWith_HealthFactorBelowThreshold() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 wethReserveId = _wethReserveId(spoke1);

    uint256 wethSupplyAmount = 1e18;
    uint256 maxDebtAmount = _calcMaxDebtAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: daiReserveId,
      collAmount: wethSupplyAmount
    });

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, maxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed debt amt of dai reserve liquidity
    vm.prank(bob);
    spoke1.borrow(daiReserveId, maxDebtAmount, bob);

    // valid HF after borrow
    assertEq(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    // cannot borrow a non trivial amount that brings HF below threshold
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(daiReserveId, 1e4, bob); // TODO: update with exact amount, resolve precision
  }

  /// cannot borrow any amount after interest has brought HF already < 1
  function test_borrow_revertsWith_HealthFactorBelowThreshold_with_interest() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 wethReserveId = _wethReserveId(spoke1);

    uint256 wethSupplyAmount = 10e18;
    uint256 maxDebtAmount = _calcMaxDebtAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: daiReserveId,
      collAmount: wethSupplyAmount
    });

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, maxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed debt amt of dai reserve liquidity
    vm.prank(bob);
    spoke1.borrow(daiReserveId, maxDebtAmount, bob);

    assertEq(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    // accrue debt to decrease HF
    skip(365 days);

    // now HF is < 1
    assertLt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(daiReserveId, 1, bob);
  }

  /// fuzz - cannot borrow any amount after interest has brought HF already < 1
  function test_borrow_fuzz_revertsWith_HealthFactorBelowThreshold_with_interest(
    uint256 skipTime
  ) public {
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 wethReserveId = _wethReserveId(spoke1);

    uint256 wethSupplyAmount = 10e18;
    uint256 maxDebtAmount = _calcMaxDebtAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: daiReserveId,
      collAmount: wethSupplyAmount
    });

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, maxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed debt amt of dai reserve liquidity
    vm.prank(bob);
    spoke1.borrow(daiReserveId, maxDebtAmount, bob);

    assertEq(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    // accrue debt to decrease HF
    skip(skipTime);

    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(daiReserveId, 1, bob);
  }

  /// cannot borrow an amount that brings HF < 1 with multiple debts for same collateral
  function test_borrow_revertsWith_HealthFactorBelowThreshold_multiple_debts() public {
    // weth collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    // dai/usdx debt
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 daiDebtAmount = 2000e18;
    uint256 usdxDebtAmount = 3000e6;

    uint256 wethCollAmountDai = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: daiReserveId,
      debtAmount: daiDebtAmount
    });
    uint256 wethCollAmountUsdx = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmount
    });

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethCollAmountDai + wethCollAmountUsdx, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiDebtAmount * 2, alice); // supply enough buffer for multiple borrows
    // Alice supply usdx
    Utils.spokeSupply(spoke1, usdxReserveId, alice, usdxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed debt amt of dai/usdx reserve liquidity
    vm.prank(bob);
    spoke1.borrow(daiReserveId, daiDebtAmount, bob);
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, usdxDebtAmount, bob);

    // valid HF
    assertEq(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    // cannot borrow more dai
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(daiReserveId, 1e12, bob); // todo: update with exact amount, resolve precision

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(usdxReserveId, 1, bob); // todo: update with exact amount, resolve precision
  }

  /// fuzz - cannot borrow an amount that brings HF < 1 with multiple debts for same collateral
  function test_borrow_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_debts(
    uint256 wethCollAmountDai,
    uint256 wethCollAmountUsdx
  ) public {
    // todo: resolve precision bounds for wethCollAmountDai, wethCollAmountUsdx
    // at high ratios between them, borrowing additional amounts won't bring HF < 1
    wethCollAmountDai = bound(wethCollAmountDai, 1e10, MAX_SUPPLY_AMOUNT / 2);
    wethCollAmountUsdx = bound(wethCollAmountUsdx, 1e10, MAX_SUPPLY_AMOUNT / 2);

    // weth collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    // dai/usdx debt
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 daiDebtAmount = _calcMaxDebtAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: daiReserveId,
      collAmount: wethCollAmountDai
    });
    uint256 usdxDebtAmount = _calcMaxDebtAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      collAmount: wethCollAmountUsdx
    });

    vm.assume(usdxDebtAmount < MAX_SUPPLY_AMOUNT / 2 && usdxDebtAmount > 0);
    vm.assume(daiDebtAmount < MAX_SUPPLY_AMOUNT / 2 && daiDebtAmount > 1e12); // dai is 1e18, keep within similar bounds to usdx (at 1e6)

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethCollAmountDai + wethCollAmountUsdx, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiDebtAmount * 2, alice); // supply enough buffer for multiple borrows
    // Alice supply usdx
    Utils.spokeSupply(spoke1, usdxReserveId, alice, usdxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed debt amt of dai/usdx reserve liquidity
    vm.prank(bob);
    spoke1.borrow(daiReserveId, daiDebtAmount, bob);
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, usdxDebtAmount, bob);

    // valid HF
    assertGe(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD()); // can be GE due to low debt/coll amounts

    // todo: should these failed amounts be 1? Could be off due to extremely edge low debt/coll amounts
    uint256 daiFailedBorrowAmount = daiDebtAmount; // some amount guaranteed to cause HF < 1
    uint256 usdxFailedBorrowAmount = usdxDebtAmount; // some amount guaranteed to cause HF < 1

    // cannot borrow more dai
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(daiReserveId, daiFailedBorrowAmount, bob);

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(usdxReserveId, usdxFailedBorrowAmount, bob); // todo: update with exact amount, resolve precision
  }

  /// cannot borrow any amount if HF < 1 due to interest growth (multiple debts for same collateral)
  function test_borrow_revertsWith_HealthFactorBelowThreshold_multiple_debts_with_interest()
    public
  {
    // weth collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    // dai/usdx debt
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 daiDebtAmount = 1_000e18;
    uint256 usdxDebtAmount = 2_000e6;

    uint256 wethCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: daiReserveId,
      debtAmount: daiDebtAmount
    }) +
      _calcMinimumCollAmount({
        spoke: spoke1,
        collReserveId: wethReserveId,
        debtReserveId: usdxReserveId,
        debtAmount: usdxDebtAmount
      });

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethCollAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiDebtAmount * 2, alice); // supply enough buffer for multiple borrows
    // Alice supply usdx
    Utils.spokeSupply(spoke1, usdxReserveId, alice, usdxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed debt amt of dai/usdx reserve liquidity
    vm.prank(bob);
    spoke1.borrow(daiReserveId, daiDebtAmount, bob);
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, usdxDebtAmount, bob);

    // valid HF
    assertApproxEqAbs(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD(), 1);

    skip(365 days);

    // after accrual, invalid HF
    assertLt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    // cannot borrow more dai
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(daiReserveId, 1, bob);

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(usdxReserveId, 1, bob);
  }

  /// fuzz - cannot borrow any amount if HF < 1 due to interest growth (multiple debts for same collateral)
  function test_borrow_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_debts_with_interest(
    uint256 wethCollForDai,
    uint256 wethCollForUsdx,
    uint256 skipTime
  ) public {
    wethCollForDai = bound(wethCollForDai, 1, MAX_SUPPLY_AMOUNT / 2);
    wethCollForUsdx = bound(wethCollForUsdx, 1, MAX_SUPPLY_AMOUNT / 2);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    // weth collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    // dai/usdx debt
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 daiDebtAmount = _calcMaxDebtAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: daiReserveId,
      collAmount: wethCollForDai
    });
    uint256 usdxDebtAmount = _calcMaxDebtAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      collAmount: wethCollForUsdx
    });

    vm.assume(daiDebtAmount < MAX_SUPPLY_AMOUNT / 2 && daiDebtAmount > 0);
    vm.assume(usdxDebtAmount < MAX_SUPPLY_AMOUNT / 2 && usdxDebtAmount > 0);

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethCollForDai + wethCollForUsdx, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiDebtAmount * 2, alice); // supply enough buffer for multiple borrows
    // Alice supply usdx
    Utils.spokeSupply(spoke1, usdxReserveId, alice, usdxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed debt amt of dai/usdx reserve liquidity
    vm.prank(bob);
    spoke1.borrow(daiReserveId, daiDebtAmount, bob);
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, usdxDebtAmount, bob);

    // valid HF
    assertGe(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD()); // can be GE for edge cases of coll/debt amount, ie 1

    skip(skipTime);
    vm.assume(spoke1.getHealthFactor(bob) < spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    // cannot borrow more dai
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(daiReserveId, 1, bob);

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(usdxReserveId, 1, bob);
  }

  /// if HF drops below threshold due to price drop, user cannot borrow more
  function test_borrow_revertsWith_HealthFactorBelowThreshold_price_drop_weth() public {
    uint256 daiReserveId = _daiReserveId(spoke1); // debt
    uint256 wethReserveId = _wethReserveId(spoke1); // collateral

    uint256 wethSupplyAmount = 10e18;
    uint256 maxDebtAmount = _calcMaxDebtAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: daiReserveId,
      collAmount: wethSupplyAmount
    });

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, maxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed debt amt of dai reserve liquidity
    vm.prank(bob);
    spoke1.borrow(daiReserveId, maxDebtAmount, bob);

    assertEq(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    // collateral price drop by half so that bob is undercollateralized
    uint256 newPrice = calcNewPrice(oracle.getAssetPrice(wethAssetId), 50_00); // 50% price drop
    oracle.setAssetPrice(wethAssetId, newPrice);
    assertLt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(daiReserveId, 1, bob);
  }

  /// fuzz - if HF drops below threshold due to price drop, user cannot borrow more
  function test_borrow_fuzz_revertsWith_HealthFactorBelowThreshold_price_drop(
    uint256 wethSupplyAmount,
    uint256 newPrice
  ) public {
    uint256 currPrice = oracle.getAssetPrice(wethAssetId);
    newPrice = bound(newPrice, 0, currPrice - 1);
    // weth collateral
    wethSupplyAmount = bound(wethSupplyAmount, 1, MAX_SUPPLY_AMOUNT);

    uint256 daiReserveId = _daiReserveId(spoke1); // debt
    uint256 wethReserveId = _wethReserveId(spoke1); // collateral

    uint256 wethSupplyAmount = 10e18;
    uint256 maxDebtAmount = _calcMaxDebtAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: daiReserveId,
      collAmount: wethSupplyAmount
    });

    vm.assume(maxDebtAmount < MAX_SUPPLY_AMOUNT / 2 && maxDebtAmount > 0);

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, maxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed debt amt of dai reserve liquidity
    vm.prank(bob);
    spoke1.borrow(daiReserveId, maxDebtAmount, bob);

    assertEq(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    // collateral price drop so that bob is undercollateralized
    oracle.setAssetPrice(wethAssetId, newPrice);
    assertLt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(daiReserveId, 1, bob);
  }

  /// cannot borrow an amount that brings HF < 1 with multiple colls for same debt
  function test_borrow_revertsWith_HealthFactorBelowThreshold_multiple_colls() public {
    // weth/dai collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    // usdx debt
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 usdxDebtAmountWeth = 3000e6;
    uint256 usdxDebtAmountDai = 5000e6;

    uint256 wethCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountWeth
    });
    uint256 daiCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: daiReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountDai
    });

    // Bob supply weth collateral
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethCollAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    // Bob supply dai collateral
    Utils.spokeSupply(spoke1, daiReserveId, bob, daiCollAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiReserveId, true);

    // Alice supply usdx
    Utils.spokeSupply(
      spoke1,
      usdxReserveId,
      alice,
      (usdxDebtAmountWeth + usdxDebtAmountDai) * 2,
      alice
    ); // supply enough buffer for multiple borrows

    // Bob draw max allowed usdx debt
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    // valid HF
    assertEq(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(usdxReserveId, 1, bob);
  }

  /// fuzz - cannot borrow an amount that brings HF < 1 with multiple colls for same debt
  function test_borrow_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_colls(
    uint256 usdxDebtAmountWeth,
    uint256 usdxDebtAmountDai
  ) public {
    usdxDebtAmountWeth = bound(usdxDebtAmountWeth, 1, MAX_SUPPLY_AMOUNT / 2 - 1); // so that liquidity is sufficient for next draw attempt
    usdxDebtAmountDai = bound(usdxDebtAmountDai, 1, MAX_SUPPLY_AMOUNT / 2 - 1); // so that liquidity is sufficient for next draw attempt

    // weth/dai collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    // usdx debt
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 wethCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountWeth
    });
    uint256 daiCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: daiReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountDai
    });

    vm.assume(wethCollAmount < MAX_SUPPLY_AMOUNT && wethCollAmount > 0);
    vm.assume(daiCollAmount < MAX_SUPPLY_AMOUNT && daiCollAmount > 0);

    // Bob supply weth collateral
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethCollAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    // Bob supply dai collateral
    Utils.spokeSupply(spoke1, daiReserveId, bob, daiCollAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiReserveId, true);

    // Alice supply usdx
    Utils.spokeSupply(
      spoke1,
      usdxReserveId,
      alice,
      (usdxDebtAmountWeth + usdxDebtAmountDai) + 1,
      alice
    ); // supply enough buffer for multiple borrows

    // Bob draw max allowed usdx debt
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    // valid HF
    assertGe(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD()); // can be GE due to edge cases of coll/debt ratios

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(usdxReserveId, 1, bob);
  }

  /// cannot borrow any amount with multiple colls for same debt, once HF < 1 due to interest
  function test_borrow_revertsWith_HealthFactorBelowThreshold_multiple_colls_with_interest()
    public
  {
    // weth/dai collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    // usdx debt
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 usdxDebtAmountWeth = 3000e6;
    uint256 usdxDebtAmountDai = 5000e6;

    uint256 wethCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountWeth
    });
    uint256 daiCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: daiReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountDai
    });

    // Bob supply weth collateral
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethCollAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    // Bob supply dai collateral
    Utils.spokeSupply(spoke1, daiReserveId, bob, daiCollAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiReserveId, true);

    // Alice supply usdx
    Utils.spokeSupply(
      spoke1,
      usdxReserveId,
      alice,
      (usdxDebtAmountWeth + usdxDebtAmountDai) * 2,
      alice
    ); // supply enough buffer for multiple borrows

    // Bob draw max allowed usdx debt
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    // valid HF
    assertEq(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    // skip time to accrue debt and reduce HF < 1
    skip(365 days);

    // invalid HF
    assertLt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(usdxReserveId, 1, bob);
  }

  /// fuzz - cannot borrow any amount with multiple colls for same debt, once HF < 1 due to interest
  function test_borrow_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_colls_with_interest(
    uint256 usdxDebtAmountWeth,
    uint256 usdxDebtAmountDai,
    uint256 skipTime
  ) public {
    usdxDebtAmountWeth = bound(usdxDebtAmountWeth, 1, MAX_SUPPLY_AMOUNT / 2 - 1); // so that additional draw has liquidity
    usdxDebtAmountDai = bound(usdxDebtAmountDai, 1, MAX_SUPPLY_AMOUNT / 2 - 1); // so that additional draw has liquidity
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    // weth/dai collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    // usdx debt
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 wethCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountWeth
    });
    uint256 daiCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: daiReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountDai
    });

    vm.assume(wethCollAmount < MAX_SUPPLY_AMOUNT && wethCollAmount > 0);
    vm.assume(daiCollAmount < MAX_SUPPLY_AMOUNT && daiCollAmount > 0);

    // Bob supply weth collateral
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethCollAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    // Bob supply dai collateral
    Utils.spokeSupply(spoke1, daiReserveId, bob, daiCollAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiReserveId, true);

    // Alice supply usdx
    Utils.spokeSupply(spoke1, usdxReserveId, alice, MAX_SUPPLY_AMOUNT, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed usdx debt
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    // valid HF
    assertGe(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD()); // can be GE due to edge cases of coll/debt ratios

    // skip time to accrue debt and reduce HF < 1
    skip(skipTime);

    // invalid HF
    vm.assume(spoke1.getHealthFactor(bob) < spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());
    vm.assume(hub.getAvailableLiquidity(usdxAssetId) > 0);

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(usdxReserveId, 1, bob);
  }

  /// cannot borrow more with multiple colls for same debt, if HF drops below threshold due to price drop
  function test_borrow_revertsWith_HealthFactorBelowThreshold_multiple_colls_price_drop_weth()
    public
  {
    // weth/dai collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    // usdx debt
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 usdxDebtAmountWeth = 3000e6;
    uint256 usdxDebtAmountDai = 5000e6;

    uint256 wethCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountWeth
    });
    uint256 daiCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: daiReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountDai
    });

    // Bob supply weth collateral
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethCollAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    // Bob supply dai collateral
    Utils.spokeSupply(spoke1, daiReserveId, bob, daiCollAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiReserveId, true);

    // Alice supply usdx
    Utils.spokeSupply(
      spoke1,
      usdxReserveId,
      alice,
      (usdxDebtAmountWeth + usdxDebtAmountDai) * 2,
      alice
    ); // supply enough buffer for multiple borrows

    // Bob draw max allowed usdx debt
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    // valid HF
    assertEq(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    // collateral price drop by half so that bob is undercollateralized
    uint256 newPrice = calcNewPrice(oracle.getAssetPrice(wethAssetId), 50_00); // 50% price drop
    oracle.setAssetPrice(wethAssetId, newPrice);

    // invalid HF
    assertLt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(usdxReserveId, 1, bob);
  }

  /// fuzz - cannot borrow more with multiple colls for same debt, if HF drops below threshold due to price drop
  function test_fuzz_borrow_revertsWith_HealthFactorBelowThreshold_multiple_colls_price_drop_weth(
    uint256 newPrice,
    uint256 usdxDebtAmountWeth,
    uint256 usdxDebtAmountDai
  ) public {
    uint256 currPrice = oracle.getAssetPrice(wethAssetId);
    newPrice = bound(newPrice, 0, currPrice - 1);
    usdxDebtAmountWeth = bound(usdxDebtAmountWeth, 1, MAX_SUPPLY_AMOUNT / 4);
    usdxDebtAmountDai = bound(usdxDebtAmountDai, 1, MAX_SUPPLY_AMOUNT / 4);

    // weth/dai collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    // usdx debt
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 wethCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountWeth
    });
    uint256 daiCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: daiReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountDai
    });

    vm.assume(wethCollAmount < MAX_SUPPLY_AMOUNT && wethCollAmount > 0);
    vm.assume(daiCollAmount < MAX_SUPPLY_AMOUNT && daiCollAmount > 0);

    // Bob supply weth collateral
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethCollAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    // Bob supply dai collateral
    Utils.spokeSupply(spoke1, daiReserveId, bob, daiCollAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiReserveId, true);

    // Alice supply usdx
    Utils.spokeSupply(spoke1, usdxReserveId, alice, MAX_SUPPLY_AMOUNT, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed usdx debt
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    // valid HF
    assertGe(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD()); // can be GE due to edge cases

    // collateral price drop by half so that bob is undercollateralized
    uint256 newPrice = calcNewPrice(oracle.getAssetPrice(wethAssetId), 50_00); // 50% price drop
    oracle.setAssetPrice(wethAssetId, newPrice);

    // invalid HF
    assertLt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(usdxReserveId, 1, bob);
  }

  /// cannot borrow more with multiple colls for same debt, if HF drops below threshold due to price drop
  function test_borrow_revertsWith_HealthFactorBelowThreshold_multiple_colls_price_drop_dai()
    public
  {
    // weth/dai collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    // usdx debt
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 usdxDebtAmountWeth = 3000e6;
    uint256 usdxDebtAmountDai = 5000e6;

    uint256 wethCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountWeth
    });
    uint256 daiCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: daiReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountDai
    });

    // Bob supply weth collateral
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethCollAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    // Bob supply dai collateral
    Utils.spokeSupply(spoke1, daiReserveId, bob, daiCollAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiReserveId, true);

    // Alice supply usdx
    Utils.spokeSupply(
      spoke1,
      usdxReserveId,
      alice,
      (usdxDebtAmountWeth + usdxDebtAmountDai) * 2,
      alice
    ); // supply enough buffer for multiple borrows

    // Bob draw max allowed usdx debt
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    // valid HF
    assertEq(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    // collateral price drop by half so that bob is undercollateralized
    uint256 newPrice = calcNewPrice(oracle.getAssetPrice(daiAssetId), 50_00); // 50% price drop
    oracle.setAssetPrice(daiAssetId, newPrice);

    // invalid HF
    assertLt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(usdxReserveId, 1, bob);
  }

  /// fuzz - cannot borrow more with multiple colls for same debt, if HF drops below threshold due to price drop
  function test_fuzz_borrow_revertsWith_HealthFactorBelowThreshold_multiple_colls_price_drop_dai(
    uint256 newPrice,
    uint256 usdxDebtAmountWeth,
    uint256 usdxDebtAmountDai
  ) public {
    uint256 currPrice = oracle.getAssetPrice(wethAssetId);
    newPrice = bound(newPrice, 0, currPrice - 1);
    usdxDebtAmountWeth = bound(usdxDebtAmountWeth, 1, MAX_SUPPLY_AMOUNT / 4);
    usdxDebtAmountDai = bound(usdxDebtAmountDai, 1, MAX_SUPPLY_AMOUNT / 4);

    // weth/dai collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    // usdx debt
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 wethCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountWeth
    });
    uint256 daiCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: daiReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountDai
    });

    vm.assume(wethCollAmount < MAX_SUPPLY_AMOUNT && wethCollAmount > 0);
    vm.assume(daiCollAmount < MAX_SUPPLY_AMOUNT && daiCollAmount > 0);

    // Bob supply weth collateral
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethCollAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    // Bob supply dai collateral
    Utils.spokeSupply(spoke1, daiReserveId, bob, daiCollAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiReserveId, true);

    // Alice supply usdx
    Utils.spokeSupply(spoke1, usdxReserveId, alice, MAX_SUPPLY_AMOUNT, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed usdx debt
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    // valid HF
    assertGe(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD()); // can be GE due to edge cases

    // collateral price drop by half so that bob is undercollateralized
    uint256 newPrice = calcNewPrice(oracle.getAssetPrice(daiAssetId), 50_00); // 50% price drop
    oracle.setAssetPrice(daiAssetId, newPrice);

    // invalid HF
    assertLt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(usdxReserveId, 1, bob);
  }

  // TODO: tests with other combos of collateral/debt, particularly with different units
  // - 2 colls, 1e18/1e6, with 1 debt, 1e0
  // - 2 colls, 1e18/1e0, with 1 debt, 1e6
  // - 2 colls, 1e6/1e0, with 1 debt, 1e18
  // - 1 coll, 1e0, with 2 debts, 1e18/1e6
  // - 1 coll, 1e6, with 2 debts, 1e18/1e0
  // - 1 coll, 1e18, with 2 debts, 1e6/1e0
}
