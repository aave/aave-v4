// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

contract SpokeBorrowTest is Base {
  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

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
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.AssetNotActive.selector, daiAssetId));
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

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiSupplyAmount, alice);

    DataTypes.UserConfig memory bobDaiData = getUserInfo(spoke1, bob, daiReserveId);
    DataTypes.UserConfig memory bobWethData = getUserInfo(spoke1, bob, wethReserveId);
    DataTypes.UserConfig memory aliceDaiData = getUserInfo(spoke1, alice, daiReserveId);
    DataTypes.UserConfig memory aliceWethData = getUserInfo(spoke1, alice, wethReserveId);

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

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiBorrowAmount, alice);

    DataTypes.UserConfig memory bobDaiData = getUserInfo(spoke1, bob, daiReserveId);
    DataTypes.UserConfig memory bobWethData = getUserInfo(spoke1, bob, wethReserveId);
    DataTypes.UserConfig memory aliceDaiData = getUserInfo(spoke1, alice, daiReserveId);
    DataTypes.UserConfig memory aliceWethData = getUserInfo(spoke1, alice, wethReserveId);

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

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiAmount, alice);

    // Bob draw dai
    Utils.spokeBorrow(spoke1, daiReserveId, bob, drawAmount, bob);

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
    uint256 dai2ReserveId = spokeInfo[spoke2].dai2.reserveId;

    daiBorrowAmount = bound(daiBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);
    wethBorrowAmount = bound(wethBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);
    usdxBorrowAmount = bound(usdxBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);
    wbtcBorrowAmount = bound(wbtcBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);

    // Account for dai and dai2 supply actions
    deal(address(tokenList.dai), bob, 2 * MAX_SUPPLY_AMOUNT);

    // Bob supply all reserves
    Utils.spokeSupply(spoke2, daiReserveId, bob, MAX_SUPPLY_AMOUNT, bob);
    Utils.spokeSupply(spoke2, wethReserveId, bob, MAX_SUPPLY_AMOUNT, bob);
    Utils.spokeSupply(spoke2, usdxReserveId, bob, MAX_SUPPLY_AMOUNT, bob);
    Utils.spokeSupply(spoke2, wbtcReserveId, bob, MAX_SUPPLY_AMOUNT, bob);
    Utils.spokeSupply(spoke2, dai2ReserveId, bob, MAX_SUPPLY_AMOUNT, bob);

    DataTypes.UserConfig memory bobData = getUserInfo(spoke2, bob, daiReserveId);
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
      Utils.spokeBorrow(spoke2, daiReserveId, bob, daiBorrowAmount, bob);
    }
    if (wethBorrowAmount > 0) {
      Utils.spokeBorrow(spoke2, wethReserveId, bob, wethBorrowAmount, bob);
    }
    if (usdxBorrowAmount > 0) {
      Utils.spokeBorrow(spoke2, usdxReserveId, bob, usdxBorrowAmount, bob);
    }
    if (wbtcBorrowAmount > 0) {
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
}
