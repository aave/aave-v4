// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeBorrowTest is SpokeBase {
  function test_borrow_revertsWith_reserve_not_borrowable() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;

    // set reserve not borrowable
    updateBorrowable(spoke1, daiReserveId, false);

    // Bob try to draw some dai
    vm.prank(bob);
    vm.expectRevert(abi.encodeWithSelector(ISpoke.ReserveNotBorrowable.selector, daiReserveId));
    spoke1.borrow(daiReserveId, 1, bob);
  }

  function test_borrow_revertsWith_asset_not_active() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;

    // set asset not active
    updateAssetActive(hub, daiAssetId, false);

    // Bob try to draw some dai
    vm.prank(bob);
    vm.expectRevert(ILiquidityHub.AssetNotActive.selector);
    spoke1.borrow(daiReserveId, 1, bob);
  }

  function test_borrow() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiSupplyAmount, alice);

    DataTypes.UserPosition memory bobDaiData = getUserInfo(spoke1, bob, daiReserveId);
    DataTypes.UserPosition memory bobWethData = getUserInfo(spoke1, bob, wethReserveId);
    DataTypes.UserPosition memory aliceDaiData = getUserInfo(spoke1, alice, daiReserveId);
    DataTypes.UserPosition memory aliceWethData = getUserInfo(spoke1, alice, wethReserveId);

    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);
    uint256 aliceDaiBalanceBefore = tokenList.dai.balanceOf(alice);
    uint256 aliceWethBalanceBefore = tokenList.weth.balanceOf(alice);

    assertEq(bobDaiData.suppliedShares, 0, 'bob dai supply shares before');
    assertEq(bobDaiData.baseDebt, 0, 'bob dai base debt before');
    assertEq(
      bobWethData.suppliedShares,
      hub.convertToShares(wethAssetId, wethSupplyAmount),
      'bob supply shares before'
    );
    assertEq(bobWethData.baseDebt, 0, 'bob weth base debt before');

    assertEq(
      aliceDaiData.suppliedShares,
      hub.convertToShares(daiAssetId, daiSupplyAmount),
      'alice dai supply shares before'
    );
    assertEq(aliceDaiData.baseDebt, 0, 'alice dai base debt before');
    assertEq(aliceWethData.suppliedShares, 0, 'alice weth supply shares before');
    assertEq(aliceWethData.baseDebt, 0, 'alice weth base debt before');

    assertEq(tokenList.dai.balanceOf(bob), bobDaiBalanceBefore, 'bob dai balance before');
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore, 'bob weth balance before');
    assertEq(tokenList.dai.balanceOf(alice), aliceDaiBalanceBefore, 'alice dai balance before');
    assertEq(tokenList.weth.balanceOf(alice), aliceWethBalanceBefore, 'alice weth balance before');

    // Bob draw half of dai reserve liquidity
    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Borrowed(daiReserveId, bob, daiBorrowAmount);
    spoke1.borrow(daiReserveId, daiBorrowAmount, bob);

    bobDaiData = getUserInfo(spoke1, bob, daiReserveId);
    bobWethData = getUserInfo(spoke1, bob, wethReserveId);
    aliceDaiData = getUserInfo(spoke1, alice, daiReserveId);
    aliceWethData = getUserInfo(spoke1, alice, wethReserveId);

    assertEq(bobDaiData.suppliedShares, 0, 'bob dai supply shares final balance');
    assertEq(bobDaiData.baseDebt, daiBorrowAmount, 'bob dai base debt final balance');
    assertEq(
      bobWethData.suppliedShares,
      hub.convertToShares(wethAssetId, wethSupplyAmount),
      'bob weth supply shares final balance'
    );
    assertEq(bobWethData.baseDebt, 0, 'bob weth base debt  final balance');

    assertEq(
      aliceDaiData.suppliedShares,
      hub.convertToShares(daiAssetId, daiSupplyAmount),
      'alice dai supply shares final balance'
    );
    assertEq(aliceDaiData.baseDebt, 0, 'alice dai base debt final');
    assertEq(aliceWethData.suppliedShares, 0, 'alice weth supply shares final balance');
    assertEq(aliceWethData.baseDebt, 0, 'alice weth base debt final');

    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore + daiBorrowAmount,
      'bob dai final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore, 'bob weth final balance');
    assertEq(tokenList.dai.balanceOf(alice), aliceDaiBalanceBefore, 'alice dai final balance');
    assertEq(tokenList.weth.balanceOf(alice), aliceWethBalanceBefore, 'alice weth final balance');
  }

  function test_borrow_revertsWith_not_available_liquidity() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethAmount, bob);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiAmount, alice);

    // Bob draw more than supplied dai amount
    vm.prank(bob);
    vm.expectRevert(
      abi.encodeWithSelector(ILiquidityHub.NotAvailableLiquidity.selector, daiAmount)
    );
    spoke1.borrow(daiReserveId, daiAmount + 1, bob);
  }

  function test_borrow_revertsWith_invalid_draw_amount() public {
    // Bob draw 0 dai
    vm.prank(bob);
    vm.expectRevert(ILiquidityHub.InvalidDrawAmount.selector);
    spoke1.borrow(spokeInfo[spoke1].dai.reserveId, 0, bob);
  }

  function test_borrow_fuzz_amounts(uint256 wethSupplyAmount, uint256 daiBorrowAmount) public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

    wethSupplyAmount = bound(wethSupplyAmount, 1, MAX_SUPPLY_AMOUNT);
    daiBorrowAmount = bound(daiBorrowAmount, 1, wethSupplyAmount / 2 + 1);

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiBorrowAmount, alice);

    DataTypes.UserPosition memory bobDaiData = getUserInfo(spoke1, bob, daiReserveId);
    DataTypes.UserPosition memory bobWethData = getUserInfo(spoke1, bob, wethReserveId);
    DataTypes.UserPosition memory aliceDaiData = getUserInfo(spoke1, alice, daiReserveId);
    DataTypes.UserPosition memory aliceWethData = getUserInfo(spoke1, alice, wethReserveId);

    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);
    uint256 aliceDaiBalanceBefore = tokenList.dai.balanceOf(alice);

    assertEq(
      bobWethData.suppliedShares,
      hub.convertToShares(wethAssetId, wethSupplyAmount),
      'bob weth supply shares before'
    );
    assertEq(bobWethData.baseDebt, 0, 'bob weth base debt before');
    assertEq(bobDaiData.suppliedShares, 0, 'bob dai supply shares before');
    assertEq(bobDaiData.baseDebt, 0, 'bob dai base debt before');

    assertEq(
      aliceDaiData.suppliedShares,
      hub.convertToShares(daiAssetId, daiBorrowAmount),
      'alice dai supply shares before'
    );
    assertEq(aliceDaiData.baseDebt, 0, 'alice dai base debt before');
    assertEq(aliceWethData.suppliedShares, 0, 'alice weth supply shares before');
    assertEq(aliceWethData.baseDebt, 0, 'alice weth base debt before');

    assertEq(tokenList.dai.balanceOf(bob), bobDaiBalanceBefore, 'bob dai balance before');
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore, 'bob weth balance before');
    assertEq(tokenList.dai.balanceOf(alice), aliceDaiBalanceBefore, 'alice dai balance before');

    // Bob draw dai
    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Borrowed(daiReserveId, bob, daiBorrowAmount);
    spoke1.borrow(daiReserveId, daiBorrowAmount, bob);

    bobDaiData = getUserInfo(spoke1, bob, daiReserveId);
    bobWethData = getUserInfo(spoke1, bob, wethReserveId);
    aliceDaiData = getUserInfo(spoke1, alice, daiReserveId);
    aliceWethData = getUserInfo(spoke1, alice, wethReserveId);

    assertEq(bobDaiData.suppliedShares, 0, 'bob dai supply shares final balance');
    assertEq(bobDaiData.baseDebt, daiBorrowAmount, 'bob dai base debt final balance');
    assertEq(
      bobWethData.suppliedShares,
      hub.convertToShares(wethAssetId, wethSupplyAmount),
      'bob supply shares final balance'
    );
    assertEq(bobWethData.baseDebt, 0, 'bob base debt weth final balance');

    assertEq(
      aliceDaiData.suppliedShares,
      hub.convertToShares(daiAssetId, daiBorrowAmount),
      'alice supply shares final balance'
    );
    assertEq(aliceDaiData.baseDebt, 0, 'alice base debt final');
    assertEq(aliceWethData.suppliedShares, 0, 'alice supply shares final balance');
    assertEq(aliceWethData.baseDebt, 0, 'alice base debt final');

    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore + daiBorrowAmount,
      'bob dai final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore, 'bob weth final balance');
    assertEq(tokenList.dai.balanceOf(alice), aliceDaiBalanceBefore, 'alice dai final balance');
  }

  function test_borrow_revertsWith_draw_cap_exceeded() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 drawCap = 100e18;
    uint256 drawAmount = drawCap + 1;

    updateDrawCap(hub, daiAssetId, address(spoke1), drawCap);

    // Bob borrow dai amount exceeding draw cap
    vm.prank(bob);
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.DrawCapExceeded.selector, drawCap));
    spoke1.borrow(daiReserveId, drawAmount, bob);
  }

  function test_borrow_revertsWith_draw_cap_exceeded_due_to_interest() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

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

  function test_borrow_fuzz_multiple_reserves(
    uint256 daiBorrowAmount,
    uint256 wethBorrowAmount,
    uint256 usdxBorrowAmount,
    uint256 wbtcBorrowAmount
  ) public {
    uint256 daiReserveId = spokeInfo[spoke2].dai.reserveId;
    uint256 wethReserveId = spokeInfo[spoke2].weth.reserveId;
    uint256 usdxReserveId = spokeInfo[spoke2].usdx.reserveId;
    uint256 wbtcReserveId = spokeInfo[spoke2].wbtc.reserveId;

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

    DataTypes.UserPosition memory bobData = getUserInfo(spoke2, bob, daiReserveId);
    assertEq(
      bobData.suppliedShares,
      hub.convertToShares(daiAssetId, MAX_SUPPLY_AMOUNT),
      'bob supply shares before'
    );
    assertEq(bobData.baseDebt, 0, 'bob base debt before');
    bobData = getUserInfo(spoke2, bob, wethReserveId);
    assertEq(
      bobData.suppliedShares,
      hub.convertToShares(wethAssetId, MAX_SUPPLY_AMOUNT),
      'bob supply shares before'
    );
    assertEq(bobData.baseDebt, 0, 'bob base debt before');
    bobData = getUserInfo(spoke2, bob, usdxReserveId);
    assertEq(
      bobData.suppliedShares,
      hub.convertToShares(usdxAssetId, MAX_SUPPLY_AMOUNT),
      'bob supply shares before'
    );
    assertEq(bobData.baseDebt, 0, 'bob base debt before');
    bobData = getUserInfo(spoke2, bob, wbtcReserveId);
    assertEq(
      bobData.suppliedShares,
      hub.convertToShares(wbtcAssetId, MAX_SUPPLY_AMOUNT),
      'bob supply shares before'
    );
    assertEq(bobData.baseDebt, 0, 'bob base debt before');

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

    bobData = getUserInfo(spoke2, bob, daiReserveId);
    assertEq(
      bobData.suppliedShares,
      hub.convertToShares(daiAssetId, MAX_SUPPLY_AMOUNT),
      'bob supply shares final balance'
    );
    assertEq(bobData.baseDebt, daiBorrowAmount, 'bob base debt dai final balance');
    bobData = getUserInfo(spoke2, bob, wethReserveId);
    assertEq(
      bobData.suppliedShares,
      hub.convertToShares(wethAssetId, MAX_SUPPLY_AMOUNT),
      'bob supply shares final balance'
    );
    assertEq(bobData.baseDebt, wethBorrowAmount, 'bob base debt weth final balance');
    bobData = getUserInfo(spoke2, bob, usdxReserveId);
    assertEq(
      bobData.suppliedShares,
      hub.convertToShares(usdxAssetId, MAX_SUPPLY_AMOUNT),
      'bob supply shares final balance'
    );
    assertEq(bobData.baseDebt, usdxBorrowAmount, 'bob base debt usdx final balance');
    bobData = getUserInfo(spoke2, bob, wbtcReserveId);
    assertEq(
      bobData.suppliedShares,
      hub.convertToShares(wbtcAssetId, MAX_SUPPLY_AMOUNT),
      'bob supply shares final balance'
    );
    assertEq(bobData.baseDebt, wbtcBorrowAmount, 'bob base debt wbtc final balance');
  }

  function test_borrow_revertsWith_HealthFactorLowerThanLiquidationThreshold() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

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

    // valid HF after borrow
    assertEq(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    // cannot borrow a non trivial amount that brings HF below threshold
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorLowerThanLiquidationThreshold.selector);
    spoke1.borrow(daiReserveId, 1e4, bob); // TODO: update with exact amount, resolve precision
  }

  function test_borrow_revertsWith_HealthFactorLowerThanLiquidationThreshold_with_interest()
    public
  {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

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

    assertLt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorLowerThanLiquidationThreshold.selector);
    spoke1.borrow(daiReserveId, 1, bob);
  }

  function test_borrow_fuzz_revertsWith_HealthFactorLowerThanLiquidationThreshold_with_interest(
    uint256 skipTime
  ) public {
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

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
    vm.expectRevert(ISpoke.HealthFactorLowerThanLiquidationThreshold.selector);
    spoke1.borrow(daiReserveId, 1, bob);
  }

  function test_borrow_revertsWith_HealthFactorLowerThanLiquidationThreshold_multiple_colls()
    public
  {
    // weth collateral
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;
    // dai/usdx debt
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 usdxReserveId = spokeInfo[spoke1].usdx.reserveId;

    uint256 wethCollAmountDai = 1e18;
    uint256 wethCollAmountUsdx = 2e18;

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

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethCollAmountDai + wethCollAmountUsdx, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiDebtAmount * 2, alice); // supply enough buffer for multiple borrows
    // Alice supply usdx
    Utils.spokeSupply(spoke1, usdxReserveId, alice, usdxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed debt amt of dai reserve liquidity
    vm.prank(bob);
    spoke1.borrow(daiReserveId, daiDebtAmount, bob);

    vm.prank(bob);
    spoke1.borrow(usdxReserveId, usdxDebtAmount, bob);

    // valid HF
    assertGe(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    // cannot borrow more dai
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorLowerThanLiquidationThreshold.selector);
    spoke1.borrow(daiReserveId, 1e13, bob); // todo: update with exact amount, resolve precision which is 1e18/1e5

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorLowerThanLiquidationThreshold.selector);
    spoke1.borrow(usdxReserveId, 1e1, bob); // todo: update with exact amount, resolve precision which is 1e6/1e5
  }

  function test_borrow_fuzz_revertsWith_HealthFactorLowerThanLiquidationThreshold_multiple_colls(
    uint256 wethCollAmountDai,
    uint256 wethCollAmountUsdx
  ) public {
    // todo: resolve precision bounds for wethCollAmountDai, wethCollAmountUsdx
    // at high ratios between them, borrowing additional amounts won't bring HF < 1
    wethCollAmountDai = bound(wethCollAmountDai, 1e10, MAX_SUPPLY_AMOUNT / 2);
    wethCollAmountUsdx = bound(wethCollAmountUsdx, 1e10, MAX_SUPPLY_AMOUNT / 2);

    // weth collateral
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;
    // dai/usdx debt
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 usdxReserveId = spokeInfo[spoke1].usdx.reserveId;

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

    // Bob draw max allowed debt amt of dai reserve liquidity
    vm.prank(bob);
    spoke1.borrow(daiReserveId, daiDebtAmount, bob);

    vm.prank(bob);
    spoke1.borrow(usdxReserveId, usdxDebtAmount, bob);

    // valid HF
    assertGe(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD()); // can be GE due to low debt/coll amounts

    // todo: should this be 1? Could be off due to extremely edge low debt/coll amounts
    uint256 daiFailedBorrowAmount = daiDebtAmount; // some amount guaranteed to cause HF < 1
    uint256 usdxFailedBorrowAmount = usdxDebtAmount; // some amount guaranteed to cause HF < 1

    // cannot borrow more dai
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorLowerThanLiquidationThreshold.selector);
    spoke1.borrow(daiReserveId, daiFailedBorrowAmount, bob);

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorLowerThanLiquidationThreshold.selector);
    spoke1.borrow(usdxReserveId, usdxFailedBorrowAmount, bob); // todo: update with exact amount, resolve precision which is 1e6/1e5
  }

  function test_borrow_revertsWith_HealthFactorLowerThanLiquidationThreshold_multiple_colls_with_interest()
    public
  {
    // weth collateral
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;
    // dai/usdx debt
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 usdxReserveId = spokeInfo[spoke1].usdx.reserveId;

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

    // Bob draw max allowed debt amt of dai reserve liquidity
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
    vm.expectRevert(ISpoke.HealthFactorLowerThanLiquidationThreshold.selector);
    spoke1.borrow(daiReserveId, 1, bob);

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorLowerThanLiquidationThreshold.selector);
    spoke1.borrow(usdxReserveId, 1, bob);
  }
  function test_borrow_fuzz_revertsWith_HealthFactorLowerThanLiquidationThreshold_multiple_colls_with_interest(
    uint256 wethCollForDai,
    uint256 wethCollForUsdx,
    uint256 skipTime
  ) public {
    wethCollForDai = bound(wethCollForDai, 1, MAX_SUPPLY_AMOUNT / 2);
    wethCollForUsdx = bound(wethCollForUsdx, 1, MAX_SUPPLY_AMOUNT / 2);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    // weth collateral
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;
    // dai/usdx debt
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 usdxReserveId = spokeInfo[spoke1].usdx.reserveId;

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

    // Bob draw max allowed debt amt of dai reserve liquidity
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
    vm.expectRevert(ISpoke.HealthFactorLowerThanLiquidationThreshold.selector);
    spoke1.borrow(daiReserveId, 1, bob);

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorLowerThanLiquidationThreshold.selector);
    spoke1.borrow(usdxReserveId, 1, bob);
  }

  /// if HF drops below threshold due to price drop, user cannot borrow more
  function test_borrow_revertsWith_HealthFactorLowerThanLiquidationThreshold_price_drop() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId; // debt
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId; // collateral

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
    oracle.setAssetPrice(wethAssetId, 1000e8);
    assertLt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorLowerThanLiquidationThreshold.selector);
    spoke1.borrow(daiReserveId, 1, bob);
  }

  function test_borrow_revertsWith_HealthFactorLowerThanLiquidationThreshold_price_drop(
    uint256 newPrice
  ) public {
    // weth collateral
    uint256 currPrice = oracle.getAssetPrice(wethAssetId);
    newPrice = bound(newPrice, 0, currPrice - 1);

    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId; // debt
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId; // collateral

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
    oracle.setAssetPrice(wethAssetId, newPrice);
    assertLt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorLowerThanLiquidationThreshold.selector);
    spoke1.borrow(daiReserveId, 1, bob);
  }
}
