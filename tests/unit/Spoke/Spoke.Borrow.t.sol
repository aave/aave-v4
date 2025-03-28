// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeBorrowTest is SpokeBase {
  using PercentageMath for uint256;
  using WadRayMath for uint256;

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
    uint256 lastUpdateTimestamp;
    uint256 cumulatedInterest;
  }

  struct DebtData {
    uint256 reserveBaseDebt;
    uint256 reservePremiumDebt;
    uint256 bobBaseDebt;
    uint256 bobPremiumDebt;
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

    state.bobDaiData = getUserInfo(spoke1, bob, state.daiReserveId);
    state.bobWethData = getUserInfo(spoke1, bob, state.wethReserveId);
    state.aliceDaiData = getUserInfo(spoke1, alice, state.daiReserveId);
    state.aliceWethData = getUserInfo(spoke1, alice, state.wethReserveId);

    state.bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    state.bobWethBalanceBefore = tokenList.weth.balanceOf(bob);
    state.aliceDaiBalanceBefore = tokenList.dai.balanceOf(alice);
    state.aliceWethBalanceBefore = tokenList.weth.balanceOf(alice);

    // bob
    // dai
    assertEq(state.bobDaiData.suppliedShares, 0);
    assertEq(state.bobDaiData.baseDrawnShares, 0);
    assertEq(state.bobDaiData.premiumDrawnShares, 0);
    assertEq(state.bobDaiData.premiumOffset, 0);
    assertEq(state.bobDaiData.realizedPremium, 0);
    assertFalse(state.bobDaiData.usingAsCollateral);
    // weth
    assertEq(
      state.bobWethData.suppliedShares,
      hub.convertToSuppliedShares(wethAssetId, state.wethSupplyAmount)
    );
    assertEq(state.bobWethData.baseDrawnShares, 0);
    assertEq(state.bobWethData.premiumDrawnShares, 0);
    assertEq(state.bobWethData.premiumOffset, 0);
    assertEq(state.bobWethData.realizedPremium, 0);
    assertTrue(state.bobWethData.usingAsCollateral);
    // Alice
    // dai
    assertEq(
      state.aliceDaiData.suppliedShares,
      hub.convertToSuppliedShares(daiAssetId, state.daiSupplyAmount)
    );
    assertEq(state.aliceDaiData.baseDrawnShares, 0);
    assertEq(state.aliceDaiData.premiumDrawnShares, 0);
    assertEq(state.aliceDaiData.premiumOffset, 0);
    assertEq(state.aliceDaiData.realizedPremium, 0);
    // weth
    assertEq(state.aliceWethData.suppliedShares, 0);
    assertEq(state.aliceWethData.baseDrawnShares, 0);
    assertEq(state.aliceWethData.premiumDrawnShares, 0);
    assertEq(state.aliceWethData.premiumOffset, 0);
    assertEq(state.aliceWethData.realizedPremium, 0);
    // toke balance
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

    state.bobDaiData = getUserInfo(spoke1, bob, state.daiReserveId);
    state.bobWethData = getUserInfo(spoke1, bob, state.wethReserveId);
    state.aliceDaiData = getUserInfo(spoke1, alice, state.daiReserveId);
    state.aliceWethData = getUserInfo(spoke1, alice, state.wethReserveId);

    state.bobDaiBalanceAfter = tokenList.dai.balanceOf(bob);
    state.bobWethBalanceAfter = tokenList.weth.balanceOf(bob);
    state.aliceDaiBalanceAfter = tokenList.dai.balanceOf(alice);
    state.aliceWethBalanceAfter = tokenList.weth.balanceOf(alice);

    state.bobDaiDataCalc = _calcExpectedDebtAccounting(
      spoke1,
      bob,
      daiAssetId,
      state.daiBorrowAmount,
      0
    );

    // bob
    // dai
    assertEq(state.bobDaiData.suppliedShares, 0, 'bob dai suppliedShares after');
    assertEq(
      state.bobDaiData.baseDrawnShares,
      state.bobDaiDataCalc.baseDrawnShares,
      'bob dai baseDrawnShares after'
    );
    assertEq(
      state.bobDaiData.premiumDrawnShares,
      state.bobDaiDataCalc.premiumDrawnShares,
      'bob dai premiumDrawnShares after'
    );
    assertEq(
      state.bobDaiData.premiumOffset,
      state.bobDaiDataCalc.premiumOffset,
      'bob dai premiumOffset after'
    );
    assertEq(state.bobDaiData.realizedPremium, 0, 'bob dai realizedPremium after');
    assertFalse(state.bobDaiData.usingAsCollateral, 'bob dai usingAsCollateral after');
    // weth
    assertEq(
      state.bobWethData.suppliedShares,
      hub.convertToSuppliedShares(wethAssetId, state.wethSupplyAmount),
      'bob weth suppliedShares after'
    );
    assertEq(state.bobWethData.baseDrawnShares, 0, 'bob weth baseDrawnShares after');
    assertEq(state.bobWethData.premiumDrawnShares, 0, 'bob weth premiumDrawnShares after');
    assertEq(state.bobWethData.premiumOffset, 0, 'bob weth premiumOffset after');
    assertEq(state.bobWethData.realizedPremium, 0, 'bob weth realizedPremium after');
    assertTrue(state.bobWethData.usingAsCollateral, 'bob weth usingAsCollateral after');
    // Alice
    // dai
    assertEq(
      state.aliceDaiData.suppliedShares,
      hub.convertToSuppliedShares(daiAssetId, state.daiSupplyAmount),
      'alice dai suppliedShares after'
    );
    assertEq(state.aliceDaiData.baseDrawnShares, 0, 'alice dai baseDrawnShares after');
    assertEq(state.aliceDaiData.premiumDrawnShares, 0, 'alice dai premiumDrawnShares after');
    assertEq(state.aliceDaiData.premiumOffset, 0, 'alice dai premiumOffset after');
    assertEq(state.aliceDaiData.realizedPremium, 0, 'alice dai realizedPremium after');
    // weth
    assertEq(state.aliceWethData.suppliedShares, 0, 'alice weth suppliedShares after');
    assertEq(state.aliceWethData.baseDrawnShares, 0, 'alice weth baseDrawnShares after');
    assertEq(state.aliceWethData.premiumDrawnShares, 0, 'alice weth premiumDrawnShares after');
    assertEq(state.aliceWethData.premiumOffset, 0, 'alice weth premiumOffset after');
    assertEq(state.aliceWethData.realizedPremium, 0, 'alice weth realizedPremium after');
    // token balance
    assertEq(tokenList.dai.balanceOf(bob), state.bobDaiBalanceAfter, 'bob dai balance after');
    assertEq(tokenList.weth.balanceOf(bob), state.bobWethBalanceAfter, 'bob weth balance after');
    assertEq(tokenList.dai.balanceOf(alice), state.aliceDaiBalanceAfter, 'alice dai balance after');
    assertEq(
      tokenList.weth.balanceOf(alice),
      state.aliceWethBalanceAfter,
      'alice weth balance after'
    );

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

    DebtData memory debtData;
    (debtData.reserveBaseDebt, debtData.reservePremiumDebt) = spoke1.getReserveDebt(
      state.daiReserveId
    );
    (debtData.bobBaseDebt, debtData.bobPremiumDebt) = spoke1.getUserDebt(state.daiReserveId, bob);

    assertEq(
      debtData.bobBaseDebt,
      hub.convertToDrawnAssets(daiAssetId, state.bobDaiData.baseDrawnShares),
      'bob base debt'
    );
    assertEq(
      debtData.bobPremiumDebt,
      state.bobDaiData.realizedPremium +
        hub.convertToDrawnAssets(daiAssetId, state.bobDaiData.premiumDrawnShares) -
        state.bobDaiData.premiumOffset,
      'bob premium debt'
    );
    assertEq(debtData.reserveBaseDebt, debtData.bobBaseDebt, 'base debt');
    assertEq(debtData.reservePremiumDebt, debtData.bobPremiumDebt, 'premium debt');
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

    state.bobDaiData = getUserInfo(spoke1, bob, state.daiReserveId);
    state.bobWethData = getUserInfo(spoke1, bob, state.wethReserveId);
    state.aliceDaiData = getUserInfo(spoke1, alice, state.daiReserveId);
    state.aliceWethData = getUserInfo(spoke1, alice, state.wethReserveId);

    state.bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    state.bobWethBalanceBefore = tokenList.weth.balanceOf(bob);
    state.aliceDaiBalanceBefore = tokenList.dai.balanceOf(alice);
    state.aliceWethBalanceBefore = tokenList.weth.balanceOf(alice);

    // bob
    // dai
    assertEq(state.bobDaiData.suppliedShares, 0);
    assertEq(state.bobDaiData.baseDrawnShares, 0);
    assertEq(state.bobDaiData.premiumDrawnShares, 0);
    assertEq(state.bobDaiData.premiumOffset, 0);
    assertEq(state.bobDaiData.realizedPremium, 0);
    assertFalse(state.bobDaiData.usingAsCollateral);
    // weth
    assertEq(
      state.bobWethData.suppliedShares,
      hub.convertToSuppliedShares(wethAssetId, wethSupplyAmount)
    );
    assertEq(state.bobWethData.baseDrawnShares, 0);
    assertEq(state.bobWethData.premiumDrawnShares, 0);
    assertEq(state.bobWethData.premiumOffset, 0);
    assertEq(state.bobWethData.realizedPremium, 0);
    assertTrue(state.bobWethData.usingAsCollateral);
    // Alice
    // dai
    assertEq(
      state.aliceDaiData.suppliedShares,
      hub.convertToSuppliedShares(daiAssetId, daiBorrowAmount)
    );
    assertEq(state.aliceDaiData.baseDrawnShares, 0);
    assertEq(state.aliceDaiData.premiumDrawnShares, 0);
    assertEq(state.aliceDaiData.premiumOffset, 0);
    assertEq(state.aliceDaiData.realizedPremium, 0);
    // weth
    assertEq(state.aliceWethData.suppliedShares, 0);
    assertEq(state.aliceWethData.baseDrawnShares, 0);
    assertEq(state.aliceWethData.premiumDrawnShares, 0);
    assertEq(state.aliceWethData.premiumOffset, 0);
    assertEq(state.aliceWethData.realizedPremium, 0);
    // token balance
    assertEq(tokenList.dai.balanceOf(bob), state.bobDaiBalanceBefore);
    assertEq(tokenList.weth.balanceOf(bob), state.bobWethBalanceBefore);
    assertEq(tokenList.dai.balanceOf(alice), state.aliceDaiBalanceBefore);
    assertEq(tokenList.weth.balanceOf(alice), state.aliceWethBalanceBefore);

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

    state.bobDaiData = getUserInfo(spoke1, bob, state.daiReserveId);
    state.bobWethData = getUserInfo(spoke1, bob, state.wethReserveId);
    state.aliceDaiData = getUserInfo(spoke1, alice, state.daiReserveId);
    state.aliceWethData = getUserInfo(spoke1, alice, state.wethReserveId);

    state.bobDaiBalanceAfter = tokenList.dai.balanceOf(bob);
    state.bobWethBalanceAfter = tokenList.weth.balanceOf(bob);
    state.aliceDaiBalanceAfter = tokenList.dai.balanceOf(alice);
    state.aliceWethBalanceAfter = tokenList.weth.balanceOf(alice);

    state.bobDaiDataCalc = _calcExpectedDebtAccounting(spoke1, bob, daiAssetId, daiBorrowAmount, 0);

    // bob
    // dai
    assertEq(state.bobDaiData.suppliedShares, 0, 'bob dai suppliedShares after');
    assertEq(
      state.bobDaiData.baseDrawnShares,
      state.bobDaiDataCalc.baseDrawnShares,
      'bob dai baseDrawnShares after'
    );
    assertEq(
      state.bobDaiData.premiumDrawnShares,
      state.bobDaiDataCalc.premiumDrawnShares,
      'bob dai premiumDrawnShares after'
    );
    assertEq(
      state.bobDaiData.premiumOffset,
      state.bobDaiDataCalc.premiumOffset,
      'bob dai premiumOffset after'
    );
    assertEq(state.bobDaiData.realizedPremium, 0, 'bob dai realizedPremium after');
    assertFalse(state.bobDaiData.usingAsCollateral, 'bob dai usingAsCollateral after');
    // weth
    assertEq(
      state.bobWethData.suppliedShares,
      hub.convertToSuppliedShares(wethAssetId, wethSupplyAmount),
      'bob weth suppliedShares after'
    );
    assertEq(state.bobWethData.baseDrawnShares, 0, 'bob weth baseDrawnShares after');
    assertEq(state.bobWethData.premiumDrawnShares, 0, 'bob weth premiumDrawnShares after');
    assertEq(state.bobWethData.premiumOffset, 0, 'bob weth premiumOffset after');
    assertEq(state.bobWethData.realizedPremium, 0, 'bob weth realizedPremium after');
    assertTrue(state.bobWethData.usingAsCollateral, 'bob weth usingAsCollateral after');
    // Alice
    // dai
    assertEq(
      state.aliceDaiData.suppliedShares,
      hub.convertToSuppliedShares(daiAssetId, daiBorrowAmount),
      'alice dai suppliedShares after'
    );
    assertEq(state.aliceDaiData.baseDrawnShares, 0, 'alice dai baseDrawnShares after');
    assertEq(state.aliceDaiData.premiumDrawnShares, 0, 'alice dai premiumDrawnShares after');
    assertEq(state.aliceDaiData.premiumOffset, 0, 'alice dai premiumOffset after');
    assertEq(state.aliceDaiData.realizedPremium, 0, 'alice dai realizedPremium after');
    // weth
    assertEq(state.aliceWethData.suppliedShares, 0, 'alice weth suppliedShares after');
    assertEq(state.aliceWethData.baseDrawnShares, 0, 'alice weth baseDrawnShares after');
    assertEq(state.aliceWethData.premiumDrawnShares, 0, 'alice weth premiumDrawnShares after');
    assertEq(state.aliceWethData.premiumOffset, 0, 'alice weth premiumOffset after');
    assertEq(state.aliceWethData.realizedPremium, 0, 'alice weth realizedPremium after');
    // token balance
    assertEq(tokenList.dai.balanceOf(bob), state.bobDaiBalanceAfter, 'bob dai balance after');
    assertEq(tokenList.weth.balanceOf(bob), state.bobWethBalanceAfter, 'bob weth balance after');
    assertEq(tokenList.dai.balanceOf(alice), state.aliceDaiBalanceAfter, 'alice dai balance after');
    assertEq(
      tokenList.weth.balanceOf(alice),
      state.aliceWethBalanceAfter,
      'alice weth balance after'
    );

    DebtData memory debtData;
    (debtData.reserveBaseDebt, debtData.reservePremiumDebt) = spoke1.getReserveDebt(
      state.daiReserveId
    );
    (debtData.bobBaseDebt, debtData.bobPremiumDebt) = spoke1.getUserDebt(state.daiReserveId, bob);

    assertEq(
      debtData.bobBaseDebt,
      hub.convertToDrawnAssets(daiAssetId, state.bobDaiData.baseDrawnShares),
      'bob base debt'
    );
    assertEq(
      debtData.bobPremiumDebt,
      state.bobDaiData.realizedPremium +
        hub.convertToDrawnAssets(daiAssetId, state.bobDaiData.premiumDrawnShares) -
        state.bobDaiData.premiumOffset,
      'bob premium debt'
    );
    assertEq(debtData.reserveBaseDebt, debtData.bobBaseDebt, 'base debt');
    assertEq(debtData.reservePremiumDebt, debtData.bobPremiumDebt, 'premium debt');
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

    state.bobDaiData = getUserInfo(spoke2, bob, daiReserveId);
    state.bobWethData = getUserInfo(spoke2, bob, wethReserveId);
    state.bobUsdxData = getUserInfo(spoke2, bob, usdxReserveId);
    state.bobWbtcData = getUserInfo(spoke2, bob, wbtcReserveId);

    // bob
    // dai
    assertEq(
      state.bobDaiData.suppliedShares,
      hub.convertToSuppliedShares(daiAssetId, MAX_SUPPLY_AMOUNT),
      'bob dai suppliedShares before'
    );
    assertEq(state.bobDaiData.baseDrawnShares, 0, 'bob dai baseDrawnShares before');
    assertEq(state.bobDaiData.premiumDrawnShares, 0, 'bob dai premiumDrawnShares before');
    assertEq(state.bobDaiData.premiumOffset, 0, 'bob dai premiumOffset before');
    assertEq(state.bobDaiData.realizedPremium, 0, 'bob dai realizedPremium before');
    assertTrue(state.bobDaiData.usingAsCollateral, 'bob dai usingAsCollateral before');
    // weth
    assertEq(
      state.bobWethData.suppliedShares,
      hub.convertToSuppliedShares(wethAssetId, MAX_SUPPLY_AMOUNT),
      'bob weth suppliedShares before'
    );
    assertEq(state.bobWethData.baseDrawnShares, 0, 'bob weth baseDrawnShares before');
    assertEq(state.bobWethData.premiumDrawnShares, 0, 'bob weth premiumDrawnShares before');
    assertEq(state.bobWethData.premiumOffset, 0, 'bob weth premiumOffset before');
    assertEq(state.bobWethData.realizedPremium, 0, 'bob weth realizedPremium before');
    assertTrue(state.bobWethData.usingAsCollateral, 'bob weth usingAsCollateral before');
    // usdx
    assertEq(
      state.bobUsdxData.suppliedShares,
      hub.convertToSuppliedShares(usdxAssetId, MAX_SUPPLY_AMOUNT),
      'bob usdx suppliedShares before'
    );
    assertEq(state.bobUsdxData.baseDrawnShares, 0, 'bob usdx baseDrawnShares before');
    assertEq(state.bobUsdxData.premiumDrawnShares, 0, 'bob usdx premiumDrawnShares before');
    assertEq(state.bobUsdxData.premiumOffset, 0, 'bob usdx premiumOffset before');
    assertEq(state.bobUsdxData.realizedPremium, 0, 'bob usdx realizedPremium before');
    assertTrue(state.bobUsdxData.usingAsCollateral, 'bob usdx usingAsCollateral before');
    // wbtc
    assertEq(
      state.bobWbtcData.suppliedShares,
      hub.convertToSuppliedShares(wbtcAssetId, MAX_SUPPLY_AMOUNT),
      'bob wbtc suppliedShares before'
    );
    assertEq(state.bobWbtcData.baseDrawnShares, 0, 'bob wbtc baseDrawnShares before');
    assertEq(state.bobWbtcData.premiumDrawnShares, 0, 'bob wbtc premiumDrawnShares before');
    assertEq(state.bobWbtcData.premiumOffset, 0, 'bob wbtc premiumOffset before');
    assertEq(state.bobWbtcData.realizedPremium, 0, 'bob wbtc realizedPremium before');
    assertTrue(state.bobWbtcData.usingAsCollateral, 'bob wbtc usingAsCollateral before');

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

    state.bobDaiData = getUserInfo(spoke2, bob, daiReserveId);
    state.bobWethData = getUserInfo(spoke2, bob, wethReserveId);
    state.bobUsdxData = getUserInfo(spoke2, bob, usdxReserveId);
    state.bobWbtcData = getUserInfo(spoke2, bob, wbtcReserveId);

    state.bobDaiDataCalc = _calcExpectedDebtAccounting(spoke2, bob, daiAssetId, daiBorrowAmount, 0);
    state.bobWethDataCalc = _calcExpectedDebtAccounting(
      spoke2,
      bob,
      wethAssetId,
      wethBorrowAmount,
      0
    );
    state.bobUsdxDataCalc = _calcExpectedDebtAccounting(
      spoke2,
      bob,
      usdxAssetId,
      usdxBorrowAmount,
      0
    );
    state.bobWbtcDataCalc = _calcExpectedDebtAccounting(
      spoke2,
      bob,
      wbtcAssetId,
      wbtcBorrowAmount,
      0
    );

    // dai
    assertEq(
      state.bobDaiData.suppliedShares,
      hub.convertToSuppliedShares(daiAssetId, MAX_SUPPLY_AMOUNT),
      'bob dai suppliedShares after'
    );
    assertEq(
      state.bobDaiData.baseDrawnShares,
      state.bobDaiDataCalc.baseDrawnShares,
      'bob dai baseDrawnShares after'
    );
    assertEq(
      state.bobDaiData.premiumDrawnShares,
      state.bobDaiDataCalc.premiumDrawnShares,
      'bob dai premiumDrawnShares after'
    );
    assertEq(
      state.bobDaiData.premiumOffset,
      state.bobDaiDataCalc.premiumOffset,
      'bob dai premiumOffset after'
    );
    assertEq(state.bobDaiData.realizedPremium, 0, 'bob dai realizedPremium after');
    // weth
    assertEq(
      state.bobWethData.suppliedShares,
      hub.convertToSuppliedShares(wethAssetId, MAX_SUPPLY_AMOUNT),
      'bob weth suppliedShares after'
    );
    assertEq(
      state.bobWethData.baseDrawnShares,
      state.bobWethDataCalc.baseDrawnShares,
      'bob weth baseDrawnShares after'
    );
    assertEq(
      state.bobWethData.premiumDrawnShares,
      state.bobWethDataCalc.premiumDrawnShares,
      'bob weth premiumDrawnShares after'
    );
    assertEq(
      state.bobWethData.premiumOffset,
      state.bobWethDataCalc.premiumOffset,
      'bob weth premiumOffset after'
    );
    assertEq(state.bobWethData.realizedPremium, 0, 'bob weth realizedPremium after');
    // usdx
    assertEq(
      state.bobUsdxData.suppliedShares,
      hub.convertToSuppliedShares(usdxAssetId, MAX_SUPPLY_AMOUNT),
      'bob usdx suppliedShares after'
    );
    assertEq(
      state.bobUsdxData.baseDrawnShares,
      state.bobUsdxDataCalc.baseDrawnShares,
      'bob usdx baseDrawnShares after'
    );
    assertEq(
      state.bobUsdxData.premiumDrawnShares,
      state.bobUsdxDataCalc.premiumDrawnShares,
      'bob usdx premiumDrawnShares after'
    );
    assertEq(
      state.bobUsdxData.premiumOffset,
      state.bobUsdxDataCalc.premiumOffset,
      'bob usdx premiumOffset after'
    );
    assertEq(state.bobUsdxData.realizedPremium, 0, 'bob usdx realizedPremium after');
    // wbtc
    assertEq(
      state.bobWbtcData.suppliedShares,
      hub.convertToSuppliedShares(wbtcAssetId, MAX_SUPPLY_AMOUNT),
      'bob wbtc suppliedShares after'
    );
    assertEq(
      state.bobWbtcData.baseDrawnShares,
      state.bobWbtcDataCalc.baseDrawnShares,
      'bob wbtc baseDrawnShares after'
    );
    assertEq(
      state.bobWbtcData.premiumDrawnShares,
      state.bobWbtcDataCalc.premiumDrawnShares,
      'bob wbtc premiumDrawnShares after'
    );
    assertEq(
      state.bobWbtcData.premiumOffset,
      state.bobWbtcDataCalc.premiumOffset,
      'bob wbtc premiumOffset after'
    );
    assertEq(state.bobWbtcData.realizedPremium, 0, 'bob wbtc realizedPremium after');
  }

  function test_br() public {
    test_borrow_fuzz_multi_spoke_multi_reserves_with_accrual(5e18, 4e18, 3e18, 2e18, 365 days);
  }

  /// @dev 1 user borrowing 2 assets across 2 different spokes
  function test_borrow_fuzz_multi_spoke_multi_reserves_with_accrual(
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

    state.bobDaiData = getUserInfo(spoke1, bob, daiReserveId);
    state.bobUsdxData = getUserInfo(spoke1, bob, usdxReserveId);
    state.bobDaiData2 = getUserInfo(spoke2, bob, daiReserveId);
    state.bobUsdxData2 = getUserInfo(spoke2, bob, usdxReserveId);

    // bob - spoke1
    // dai
    assertEq(
      state.bobDaiData.suppliedShares,
      hub.convertToSuppliedShares(daiAssetId, state.daiSupplyAmount),
      'bob dai suppliedShares before'
    );
    assertEq(state.bobDaiData.baseDrawnShares, 0, 'bob dai baseDrawnShares before');
    assertEq(state.bobDaiData.premiumDrawnShares, 0, 'bob dai premiumDrawnShares before');
    assertEq(state.bobDaiData.premiumOffset, 0, 'bob dai premiumOffset before');
    assertEq(state.bobDaiData.realizedPremium, 0, 'bob dai realizedPremium before');
    assertTrue(state.bobDaiData.usingAsCollateral, 'bob dai usingAsCollateral before');
    // usdx
    assertEq(
      state.bobUsdxData.suppliedShares,
      hub.convertToSuppliedShares(usdxAssetId, state.usdxSupplyAmount),
      'bob usdx suppliedShares before'
    );
    assertEq(state.bobUsdxData.baseDrawnShares, 0, 'bob usdx baseDrawnShares before');
    assertEq(state.bobUsdxData.premiumDrawnShares, 0, 'bob usdx premiumDrawnShares before');
    assertEq(state.bobUsdxData.premiumOffset, 0, 'bob usdx premiumOffset before');
    assertEq(state.bobUsdxData.realizedPremium, 0, 'bob usdx realizedPremium before');
    assertTrue(state.bobUsdxData.usingAsCollateral, 'bob usdx usingAsCollateral before');
    // bob - spoke2
    // dai
    assertEq(
      state.bobDaiData2.suppliedShares,
      hub.convertToSuppliedShares(daiAssetId, state.daiSupplyAmount2),
      'bob dai suppliedShares before'
    );
    assertEq(state.bobDaiData2.baseDrawnShares, 0, 'bob dai baseDrawnShares before');
    assertEq(state.bobDaiData2.premiumDrawnShares, 0, 'bob dai premiumDrawnShares before');
    assertEq(state.bobDaiData2.premiumOffset, 0, 'bob dai premiumOffset before');
    assertEq(state.bobDaiData2.realizedPremium, 0, 'bob dai realizedPremium before');
    assertTrue(state.bobDaiData2.usingAsCollateral, 'bob dai usingAsCollateral before');
    // usdx
    assertEq(
      state.bobUsdxData2.suppliedShares,
      hub.convertToSuppliedShares(usdxAssetId, state.usdxSupplyAmount2),
      'bob usdx suppliedShares before'
    );
    assertEq(state.bobUsdxData2.baseDrawnShares, 0, 'bob usdx baseDrawnShares before');
    assertEq(state.bobUsdxData2.premiumDrawnShares, 0, 'bob usdx premiumDrawnShares before');
    assertEq(state.bobUsdxData2.premiumOffset, 0, 'bob usdx premiumOffset before');
    assertEq(state.bobUsdxData2.realizedPremium, 0, 'bob usdx realizedPremium before');
    assertTrue(state.bobUsdxData2.usingAsCollateral, 'bob usdx usingAsCollateral before');

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
    state.bobDaiData = getUserInfo(spoke1, bob, daiReserveId);
    state.bobUsdxData = getUserInfo(spoke1, bob, usdxReserveId);
    state.bobDaiDataCalc = _calcExpectedDebtAccounting(spoke1, bob, daiAssetId, daiBorrowAmount, 0);
    state.bobUsdxDataCalc = _calcExpectedDebtAccounting(
      spoke1,
      bob,
      usdxAssetId,
      usdxBorrowAmount,
      0
    );

    // spoke2
    state.bobDaiData2 = getUserInfo(spoke2, bob, daiReserveId2);
    state.bobUsdxData2 = getUserInfo(spoke2, bob, usdxReserveId2);
    state.bobDaiDataCalc2 = _calcExpectedDebtAccounting(
      spoke2,
      bob,
      daiAssetId,
      daiBorrowAmount2,
      0
    );
    state.bobUsdxDataCalc2 = _calcExpectedDebtAccounting(
      spoke2,
      bob,
      usdxAssetId,
      usdxBorrowAmount2,
      0
    );

    // spoke1
    // dai
    assertEq(
      state.bobDaiData.suppliedShares,
      hub.convertToSuppliedShares(daiAssetId, state.daiSupplyAmount),
      'bob dai suppliedShares after'
    );
    assertEq(
      state.bobDaiData.baseDrawnShares,
      state.bobDaiDataCalc.baseDrawnShares,
      'bob dai baseDrawnShares after'
    );
    assertEq(
      state.bobDaiData.premiumDrawnShares,
      state.bobDaiDataCalc.premiumDrawnShares,
      'bob dai premiumDrawnShares after'
    );
    assertEq(
      state.bobDaiData.premiumOffset,
      state.bobDaiDataCalc.premiumOffset,
      'bob dai premiumOffset after'
    );
    assertEq(state.bobDaiData.realizedPremium, 0, 'bob dai realizedPremium after');
    // usdx
    assertEq(
      state.bobUsdxData.suppliedShares,
      hub.convertToSuppliedShares(usdxAssetId, state.usdxSupplyAmount),
      'bob usdx suppliedShares after'
    );
    assertEq(
      state.bobUsdxData.baseDrawnShares,
      state.bobUsdxDataCalc.baseDrawnShares,
      'bob usdx baseDrawnShares after'
    );
    assertEq(
      state.bobUsdxData.premiumDrawnShares,
      state.bobUsdxDataCalc.premiumDrawnShares,
      'bob usdx premiumDrawnShares after'
    );
    assertEq(
      state.bobUsdxData.premiumOffset,
      state.bobUsdxDataCalc.premiumOffset,
      'bob usdx premiumOffset after'
    );
    assertEq(state.bobUsdxData.realizedPremium, 0, 'bob usdx realizedPremium after');

    // spoke2
    // dai
    assertEq(
      state.bobDaiData2.suppliedShares,
      hub.convertToSuppliedShares(daiAssetId, state.daiSupplyAmount2),
      'bob dai suppliedShares after'
    );
    assertEq(
      state.bobDaiData2.baseDrawnShares,
      state.bobDaiDataCalc2.baseDrawnShares,
      'bob dai baseDrawnShares after'
    );
    assertEq(
      state.bobDaiData2.premiumDrawnShares,
      state.bobDaiDataCalc2.premiumDrawnShares,
      'bob dai premiumDrawnShares after'
    );
    assertEq(
      state.bobDaiData2.premiumOffset,
      state.bobDaiDataCalc2.premiumOffset,
      'bob dai premiumOffset after'
    );
    assertEq(state.bobDaiData2.realizedPremium, 0, 'bob dai realizedPremium after');
    // usdx
    assertEq(
      state.bobUsdxData2.suppliedShares,
      hub.convertToSuppliedShares(usdxAssetId, state.usdxSupplyAmount2),
      'bob usdx suppliedShares after'
    );
    assertEq(
      state.bobUsdxDataCalc2.baseDrawnShares,
      state.bobUsdxDataCalc2.baseDrawnShares,
      'bob usdx baseDrawnShares after'
    );
    assertEq(
      state.bobUsdxData2.premiumDrawnShares,
      state.bobUsdxDataCalc2.premiumDrawnShares,
      'bob usdx premiumDrawnShares after'
    );
    assertEq(
      state.bobUsdxData2.premiumOffset,
      state.bobUsdxDataCalc2.premiumOffset,
      'bob usdx premiumOffset after'
    );
    assertEq(state.bobUsdxData2.realizedPremium, 0, 'bob usdx realizedPremium after');

    // state.lastUpdateTimestamp = vm.getBlockTimestamp();

    // skip(skipTime);

    // state.cumulatedInterest = MathUtils.calculateLinearInterest(
    //   hub.getAsset(daiAssetId).baseBorrowRate,
    //   uint40(state.lastUpdateTimestamp)
    // );

    // // spoke1
    // state.bobDaiDataFinal = getUserInfo(spoke1, bob, daiReserveId);
    // state.bobUsdxDataFinal = getUserInfo(spoke1, bob, usdxReserveId);
    // state.bobDaiDataCalc = _calcExpectedDebtAccounting(
    //   spoke1,
    //   bob,
    //   daiAssetId,
    //   daiBorrowAmount.rayMul(state.cumulatedInterest),
    //   state.userRp
    // );
    // state.bobUsdxDataCalc = _calcExpectedDebtAccounting(
    //   spoke1,
    //   bob,
    //   usdxAssetId,
    //   usdxBorrowAmount.rayMul(state.cumulatedInterest),
    //   state.userRp
    // );

    // // // spoke2
    // // state.bobDaiData2 = getUserInfo(spoke2, bob, daiReserveId2);
    // // state.bobUsdxData2 = getUserInfo(spoke2, bob, usdxReserveId2);
    // // state.bobDaiDataCalc2 = _calcExpectedDebtAccounting(spoke2, bob, daiAssetId, daiBorrowAmount2);
    // // state.bobUsdxDataCalc2 = _calcExpectedDebtAccounting(
    // //   spoke2,
    // //   bob,
    // //   usdxAssetId,
    // //   usdxBorrowAmount2
    // // );

    // // spoke1
    // // dai
    // assertEq(
    //   state.bobDaiDataFinal.suppliedShares,
    //   state.bobDaiData.suppliedShares,
    //   'bob dai suppliedShares after'
    // );
    // assertEq(
    //   state.bobDaiDataFinal.baseDrawnShares,
    //   state.bobDaiData.baseDrawnShares,
    //   'bob dai baseDrawnShares after'
    // );
    // assertEq(
    //   state.bobDaiData.baseDrawnShares,
    //   state.bobDaiData.baseDrawnShares,
    //   'bob dai baseDrawnShares after'
    // );
    // assertEq(
    //   state.bobDaiDataFinal.premiumDrawnShares,
    //   state.bobDaiData.premiumDrawnShares,
    //   'bob dai premiumDrawnShares after'
    // );
    // assertEq(
    //   state.bobDaiDataFinal.premiumOffset,
    //   state.bobDaiData.premiumOffset,
    //   'bob dai premiumOffset after'
    // );
    // assertEq(state.bobDaiDataFinal.realizedPremium, 0, 'bob dai realizedPremium after');
    // // usdx
    // assertEq(
    //   state.bobUsdxDataFinal.suppliedShares,
    //   state.bobUsdxData.suppliedShares,
    //   'bob usdx suppliedShares after'
    // );
    // assertEq(
    //   state.bobUsdxDataFinal.baseDrawnShares,
    //   state.bobUsdxData.baseDrawnShares,
    //   'bob usdx baseDrawnShares after'
    // );
    // assertEq(
    //   state.bobUsdxDataFinal.premiumDrawnShares,
    //   state.bobUsdxData.premiumDrawnShares,
    //   'bob usdx premiumDrawnShares after'
    // );
    // assertEq(
    //   state.bobUsdxDataFinal.premiumOffset,
    //   state.bobUsdxData.premiumOffset,
    //   'bob usdx premiumOffset after'
    // );
    // assertEq(state.bobUsdxDataFinal.realizedPremium, 0, 'bob usdx realizedPremium after');
  }

  /// @dev basic case, cannot borrow an amount that leads to HF < 1
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

  /// @dev cannot borrow any amount after interest has brought HF already < 1
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

  /// @dev fuzz - cannot borrow any amount after interest has brought HF already < 1
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

  /// @dev cannot borrow an amount that brings HF < 1 with multiple debts for same collateral
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

  /// @dev fuzz - cannot borrow an amount that brings HF < 1 with multiple debts for same collateral
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

  /// @dev cannot borrow any amount if HF < 1 due to interest growth (multiple debts for same collateral)
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

  /// @dev fuzz - cannot borrow any amount if HF < 1 due to interest growth (multiple debts for same collateral)
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

  /// @dev if HF drops below threshold due to price drop, user cannot borrow more
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

  /// @dev fuzz - if HF drops below threshold due to price drop, user cannot borrow more
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

  /// @dev cannot borrow an amount that brings HF < 1 with multiple colls for same debt
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

  /// @dev fuzz - cannot borrow an amount that brings HF < 1 with multiple colls for same debt
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

  /// @dev cannot borrow any amount with multiple colls for same debt, once HF < 1 due to interest
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

  /// @dev fuzz - cannot borrow any amount with multiple colls for same debt, once HF < 1 due to interest
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

  /// @dev cannot borrow more with multiple colls for same debt, if HF drops below threshold due to price drop
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

  /// @dev fuzz - cannot borrow more with multiple colls for same debt, if HF drops below threshold due to price drop
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

  /// @dev cannot borrow more with multiple colls for same debt, if HF drops below threshold due to price drop
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

  /// @dev fuzz - cannot borrow more with multiple colls for same debt, if HF drops below threshold due to price drop
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

  function _calcExpectedDebtAccounting(
    ISpoke spoke,
    address user,
    uint256 assetId,
    uint256 borrowAmount,
    uint256 riskPremium
  ) internal view returns (DataTypes.UserPosition memory userPos) {
    // if 0, then calculate updated RP
    if (riskPremium == 0) {
      (riskPremium, , , , ) = spoke.getUserAccountData(user);
    }

    userPos.baseDrawnShares = hub.convertToDrawnShares(assetId, borrowAmount);
    userPos.premiumDrawnShares = hub.convertToDrawnShares(assetId, borrowAmount).percentMul(
      riskPremium
    );
    userPos.premiumOffset = hub.convertToDrawnAssets(assetId, userPos.premiumDrawnShares);
  }

  // TODO: tests with other combos of collateral/debt, particularly with different units
  // - 2 colls, 1e18/1e6, with 1 debt, 1e0
  // - 2 colls, 1e18/1e0, with 1 debt, 1e6
  // - 2 colls, 1e6/1e0, with 1 debt, 1e18
  // - 1 coll, 1e0, with 2 debts, 1e18/1e6
  // - 1 coll, 1e6, with 2 debts, 1e18/1e0
  // - 1 coll, 1e18, with 2 debts, 1e6/1e0
}
