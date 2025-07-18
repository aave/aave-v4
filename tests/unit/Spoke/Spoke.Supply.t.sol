// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeSupplyTest is SpokeBase {
  function test_supply_revertsWith_ReserveNotListed() public {
    uint256 reserveId = spoke1.getReserveCount() + 1; // invalid reserveId
    uint256 amount = 100e18;

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(bob);
    spoke1.supply(reserveId, amount);
  }

  function test_supply_revertsWith_ReserveNotActive() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;

    updateReserveActiveFlag(spoke1, daiReserveId, false);
    assertFalse(spoke1.getReserve(daiReserveId).config.active);

    vm.expectRevert(ISpoke.ReserveNotActive.selector);
    vm.prank(bob);
    spoke1.supply(daiReserveId, amount);
  }

  function test_supply_revertsWith_ReservePaused() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;

    updateReservePausedFlag(spoke1, daiReserveId, true);
    assertTrue(spoke1.getReserve(daiReserveId).config.paused);

    vm.expectRevert(ISpoke.ReservePaused.selector);
    vm.prank(bob);
    spoke1.supply(daiReserveId, amount);
  }

  function test_supply_revertsWith_ReserveFrozen() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;

    updateReserveFrozenFlag(spoke1, daiReserveId, true);
    assertTrue(spoke1.getReserve(daiReserveId).config.frozen);

    vm.expectRevert(ISpoke.ReserveFrozen.selector);
    vm.prank(bob);
    spoke1.supply(daiReserveId, amount);
  }

  function test_supply_revertsWith_ERC20InsufficientAllowance() public {
    uint256 amount = 100e18;
    uint256 approvalAmount = amount - 1;

    vm.startPrank(bob);
    tokenList.dai.approve(address(hub), approvalAmount);
    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(hub),
        approvalAmount,
        amount
      )
    );
    spoke1.supply(_daiReserveId(spoke1), amount);
    vm.stopPrank();
  }

  function test_supply_revertsWith_invalid_supply_amount() public {
    uint256 amount = 0;

    vm.expectRevert(ILiquidityHub.InvalidAddAmount.selector);
    vm.prank(bob);
    spoke1.supply(_daiReserveId(spoke1), amount);
  }

  function test_supply() public {
    uint256 amount = 100e18;
    TestUserData[2] memory bobData;
    TestData[2] memory daiData;
    uint256 stage = 0;
    bobData[stage] = loadUserInfo(spoke1, _daiReserveId(spoke1), bob);
    daiData[stage] = loadReserveInfo(spoke1, _daiReserveId(spoke1));
    // dai balance
    assertEq(tokenList.dai.balanceOf(bob), mintAmount_DAI);
    assertEq(tokenList.dai.balanceOf(address(hub)), 0);
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0);
    // reserve
    assertEq(daiData[stage].data.baseDrawnShares, 0);
    assertEq(daiData[stage].data.premiumDrawnShares, 0);
    assertEq(daiData[stage].data.premiumOffset, 0);
    assertEq(daiData[stage].data.realizedPremium, 0);
    assertEq(daiData[stage].data.suppliedShares, 0);
    // user
    assertEq(bobData[stage].data.baseDrawnShares, 0);
    assertEq(bobData[stage].data.premiumDrawnShares, 0);
    assertEq(bobData[stage].data.premiumOffset, 0);
    assertEq(bobData[stage].data.realizedPremium, 0);
    assertEq(bobData[stage].data.suppliedShares, 0);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Supply(_daiReserveId(spoke1), bob, amount);
    vm.prank(bob);
    spoke1.supply(_daiReserveId(spoke1), amount);
    stage = 1;
    bobData[stage] = loadUserInfo(spoke1, _daiReserveId(spoke1), bob);
    daiData[stage] = loadReserveInfo(spoke1, _daiReserveId(spoke1));
    // dai balance
    assertEq(
      tokenList.dai.balanceOf(bob),
      mintAmount_DAI - amount,
      'user token balance after-supply'
    );
    assertEq(tokenList.dai.balanceOf(address(hub)), amount, 'hub token balance after-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance after-supply');
    // reserve
    assertEq(daiData[stage].data.baseDrawnShares, 0, 'reserve baseDrawnShares after-supply');
    assertEq(daiData[stage].data.premiumDrawnShares, 0, 'reserve premiumDrawnShares after-supply');
    assertEq(daiData[stage].data.premiumOffset, 0, 'reserve premiumOffset after-supply');
    assertEq(daiData[stage].data.realizedPremium, 0, 'reserve realizedPremium after-supply');
    assertEq(
      daiData[stage].data.suppliedShares,
      hub.convertToSuppliedShares(daiAssetId, amount),
      'reserve suppliedShares after-supply'
    );
    assertEq(
      amount,
      hub.getSpokeSuppliedAmount(daiAssetId, address(spoke1)),
      'spoke supplied amount after-supply'
    );
    assertEq(amount, hub.getAssetSuppliedAmount(daiAssetId), 'asset supplied amount after-supply');

    // user
    assertEq(bobData[stage].data.baseDrawnShares, 0, 'bob baseDrawnShares after-supply');
    assertEq(bobData[stage].data.premiumDrawnShares, 0, 'bob premiumDrawnShares after-supply');
    assertEq(bobData[stage].data.premiumOffset, 0, 'bob premiumOffset after-supply');
    assertEq(bobData[stage].data.realizedPremium, 0, 'bob realizedPremium after-supply');
    assertEq(
      bobData[stage].data.suppliedShares,
      hub.convertToSuppliedShares(daiAssetId, amount),
      'bob suppliedShares after-supply'
    );
    assertEq(
      amount,
      spoke1.getUserSuppliedAmount(_daiReserveId(spoke1), bob),
      'user supplied amount after-supply'
    );
  }

  function test_supply_fuzz_amounts(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    deal(address(tokenList.dai), bob, amount);

    TestUserData[2] memory bobData;
    TestData[2] memory daiData;
    uint256 stage = 0;

    bobData[stage] = loadUserInfo(spoke1, _daiReserveId(spoke1), bob);
    daiData[stage] = loadReserveInfo(spoke1, _daiReserveId(spoke1));

    // dai balance
    assertEq(tokenList.dai.balanceOf(bob), amount);
    assertEq(tokenList.dai.balanceOf(address(hub)), 0);
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0);
    // reserve
    assertEq(daiData[stage].data.baseDrawnShares, 0);
    assertEq(daiData[stage].data.premiumDrawnShares, 0);
    assertEq(daiData[stage].data.premiumOffset, 0);
    assertEq(daiData[stage].data.realizedPremium, 0);
    assertEq(daiData[stage].data.suppliedShares, 0);
    // user
    assertEq(bobData[stage].data.baseDrawnShares, 0);
    assertEq(bobData[stage].data.premiumDrawnShares, 0);
    assertEq(bobData[stage].data.premiumOffset, 0);
    assertEq(bobData[stage].data.realizedPremium, 0);
    assertEq(bobData[stage].data.suppliedShares, 0);

    vm.expectEmit(address(spoke1));
    emit ISpoke.Supply(_daiReserveId(spoke1), bob, amount);
    vm.prank(bob);
    spoke1.supply(_daiReserveId(spoke1), amount);

    stage = 1;
    bobData[stage] = loadUserInfo(spoke1, _daiReserveId(spoke1), bob);
    daiData[stage] = loadReserveInfo(spoke1, _daiReserveId(spoke1));

    // dai balance
    assertEq(tokenList.dai.balanceOf(bob), 0, 'user token balance after-supply');
    assertEq(tokenList.dai.balanceOf(address(hub)), amount, 'hub token balance after-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance after-supply');
    // reserve
    assertEq(daiData[stage].data.baseDrawnShares, 0, 'reserve baseDrawnShares after-supply');
    assertEq(daiData[stage].data.premiumDrawnShares, 0, 'reserve premiumDrawnShares after-supply');
    assertEq(daiData[stage].data.premiumOffset, 0, 'reserve premiumOffset after-supply');
    assertEq(daiData[stage].data.realizedPremium, 0, 'reserve realizedPremium after-supply');
    assertEq(
      daiData[stage].data.suppliedShares,
      hub.convertToSuppliedShares(daiAssetId, amount),
      'reserve suppliedShares after-supply'
    );
    assertEq(
      amount,
      hub.getSpokeSuppliedAmount(daiAssetId, address(spoke1)),
      'spoke supplied amount after-supply'
    );
    assertEq(amount, hub.getAssetSuppliedAmount(daiAssetId), 'asset supplied amount after-supply');

    // user
    assertEq(bobData[stage].data.baseDrawnShares, 0, 'user baseDrawnShares after-supply');
    assertEq(bobData[stage].data.premiumDrawnShares, 0, 'user premiumDrawnShares after-supply');
    assertEq(bobData[stage].data.premiumOffset, 0, 'user premiumOffset after-supply');
    assertEq(bobData[stage].data.realizedPremium, 0, 'user realizedPremium after-supply');
    assertEq(
      bobData[stage].data.suppliedShares,
      hub.convertToSuppliedShares(daiAssetId, amount),
      'user suppliedShares after-supply'
    );
    assertEq(
      amount,
      spoke1.getUserSuppliedAmount(_daiReserveId(spoke1), bob),
      'user supplied amount after-supply'
    );
  }

  function test_supply_index_increase_no_premium() public {
    // set weth LP to 0 for no premium contribution
    updateLiquidityPremium({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      newLiquidityPremium: 0
    });

    // increase index on reserveId (uses weth as collateral)
    _increaseReserveIndex(spoke1, _daiReserveId(spoke1));

    uint256 amount = 1e18;
    uint256 expectedShares = hub.convertToSuppliedShares(daiAssetId, amount);
    assertGt(amount, expectedShares, 'exchange rate should be > 1');

    TestUserData[2] memory carolData;
    TestData[2] memory daiData;
    TokenData[2] memory tokenData;
    uint256 stage = 0;

    carolData[stage] = loadUserInfo(spoke1, _daiReserveId(spoke1), carol);
    daiData[stage] = loadReserveInfo(spoke1, _daiReserveId(spoke1));
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    deal(address(tokenList.dai), carol, amount);

    vm.expectEmit(address(spoke1));
    emit ISpoke.Supply(_daiReserveId(spoke1), carol, expectedShares);
    vm.prank(carol);
    spoke1.supply(_daiReserveId(spoke1), amount);
    stage = 1;

    carolData[stage] = loadUserInfo(spoke1, _daiReserveId(spoke1), carol);
    daiData[stage] = loadReserveInfo(spoke1, _daiReserveId(spoke1));
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    // dai balance
    assertEq(tokenList.dai.balanceOf(carol), 0, 'user token balance after-supply');
    assertEq(
      tokenList.dai.balanceOf(address(hub)),
      tokenData[stage - 1].hubBalance + amount,
      'hub token balance after-supply'
    );
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance after-supply');

    // reserve
    assertEq(
      daiData[stage].data.baseDrawnShares,
      daiData[stage - 1].data.baseDrawnShares,
      'reserve baseDrawnShares after-supply'
    );
    assertEq(daiData[stage].data.premiumDrawnShares, 0, 'reserve premiumDrawnShares after-supply');
    assertEq(daiData[stage].data.premiumOffset, 0, 'reserve premiumOffset after-supply');
    assertEq(daiData[stage].data.realizedPremium, 0, 'reserve realizedPremium after-supply');
    assertEq(
      daiData[stage].data.suppliedShares,
      daiData[stage - 1].data.suppliedShares + expectedShares,
      'reserve suppliedShares after-supply'
    );

    // user
    assertEq(carolData[stage].data.baseDrawnShares, 0, 'user baseDrawnShares after-supply');
    assertEq(carolData[stage].data.premiumDrawnShares, 0, 'user premiumDrawnShares after-supply');
    assertEq(carolData[stage].data.premiumOffset, 0, 'user premiumOffset after-supply');
    assertEq(carolData[stage].data.realizedPremium, 0, 'user realizedPremium after-supply');
    assertEq(
      carolData[stage].data.suppliedShares,
      expectedShares,
      'user suppliedShares after-supply'
    );
    assertApproxEqAbs(
      amount,
      spoke1.getUserSuppliedAmount(_daiReserveId(spoke1), carol),
      1,
      'user supplied amount after-supply'
    );
  }

  struct SupplyFuzzLocal {
    uint256 assetId;
    IERC20 underlying;
    uint256 expectedShares;
  }

  function test_supply_fuzz_index_increase_no_premium(
    uint256 amount,
    uint256 rate,
    uint256 reserveId,
    uint256 skipTime
  ) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    rate = bound(rate, 1, MAX_BORROW_RATE);
    reserveId = bound(reserveId, 0, spokeInfo[spoke1].MAX_RESERVE_ID);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    // set weth LP to 0 for no premium contribution
    updateLiquidityPremium({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      newLiquidityPremium: 0
    });

    // increase index on reserveId
    _executeSpokeSupplyAndBorrow({
      spoke: spoke1,
      collateral: TestReserve({
        reserveId: _wethReserveId(spoke1),
        supplier: alice,
        borrower: address(0),
        supplyAmount: 100e18,
        borrowAmount: 0
      }),
      borrow: TestReserve({
        reserveId: reserveId,
        borrowAmount: 10e18,
        supplyAmount: 20e18,
        supplier: bob,
        borrower: alice
      }),
      rate: rate,
      isMockRate: true,
      skipTime: skipTime
    });

    SupplyFuzzLocal memory state;
    (state.assetId, state.underlying) = getAssetByReserveId(spoke1, reserveId);
    state.expectedShares = hub.convertToSuppliedShares(state.assetId, amount);

    vm.assume(state.expectedShares > 0);
    assertGt(amount, state.expectedShares, 'exchange rate should be > 1');

    TestUserData[2] memory carolData;
    TestData[2] memory reserveData;
    TokenData[2] memory tokenData;
    uint256 stage = 0;

    carolData[stage] = loadUserInfo(spoke1, reserveId, carol);
    reserveData[stage] = loadReserveInfo(spoke1, reserveId);
    tokenData[stage] = getTokenBalances(state.underlying, address(spoke1));

    uint256 expectedSuppliedShares = hub.convertToSuppliedShares(state.assetId, amount);
    vm.assume(expectedSuppliedShares > 0);

    vm.expectEmit(address(spoke1));
    emit ISpoke.Supply(reserveId, carol, expectedSuppliedShares);
    vm.prank(carol);
    spoke1.supply(reserveId, amount);
    stage = 1;

    carolData[stage] = loadUserInfo(spoke1, reserveId, carol);
    reserveData[stage] = loadReserveInfo(spoke1, reserveId);
    tokenData[stage] = getTokenBalances(state.underlying, address(spoke1));

    // token balance
    assertEq(
      state.underlying.balanceOf(carol),
      MAX_SUPPLY_AMOUNT - amount,
      'user token balance after-supply'
    );
    assertEq(
      state.underlying.balanceOf(address(hub)),
      tokenData[stage - 1].hubBalance + amount,
      'hub token balance after-supply'
    );
    assertEq(state.underlying.balanceOf(address(spoke1)), 0, 'spoke token balance after-supply');

    // reserve
    assertEq(
      reserveData[stage].data.baseDrawnShares,
      reserveData[stage - 1].data.baseDrawnShares,
      'reserve baseDrawnShares after-supply'
    );
    assertEq(
      reserveData[stage].data.premiumDrawnShares,
      0,
      'reserve premiumDrawnShares after-supply'
    );
    assertEq(reserveData[stage].data.premiumOffset, 0, 'reserve premiumOffset after-supply');
    assertEq(reserveData[stage].data.realizedPremium, 0, 'reserve realizedPremium after-supply');
    assertEq(
      reserveData[stage].data.suppliedShares,
      reserveData[stage - 1].data.suppliedShares + state.expectedShares,
      'reserve suppliedShares after-supply'
    );

    // user
    assertEq(carolData[stage].data.baseDrawnShares, 0, 'user baseDrawnShares after-supply');
    assertEq(carolData[stage].data.premiumDrawnShares, 0, 'user premiumDrawnShares after-supply');
    assertEq(carolData[stage].data.premiumOffset, 0, 'user premiumOffset after-supply');
    assertEq(carolData[stage].data.realizedPremium, 0, 'user realizedPremium after-supply');
    assertEq(
      carolData[stage].data.suppliedShares,
      state.expectedShares,
      'user suppliedShares after-supply'
    );
  }

  function test_supply_index_increase_with_premium() public {
    _increaseReserveIndex(spoke1, _daiReserveId(spoke1));

    uint256 amount = 1e18;
    uint256 expectedShares = hub.convertToSuppliedShares(daiAssetId, amount);
    assertGt(amount, expectedShares, 'exchange rate should be > 1');

    TestUserData[2] memory carolData;
    TestData[2] memory daiData;
    TokenData[2] memory tokenData;
    uint256 stage = 0;

    carolData[stage] = loadUserInfo(spoke1, _daiReserveId(spoke1), carol);
    daiData[stage] = loadReserveInfo(spoke1, _daiReserveId(spoke1));
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    assertGt(daiData[stage].data.premiumDrawnShares, 0, 'reserve premiumDrawnShares after-supply');

    deal(address(tokenList.dai), carol, amount);

    vm.prank(carol);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Supply(_daiReserveId(spoke1), carol, expectedShares);
    spoke1.supply(_daiReserveId(spoke1), amount);
    stage = 1;

    carolData[stage] = loadUserInfo(spoke1, _daiReserveId(spoke1), carol);
    daiData[stage] = loadReserveInfo(spoke1, _daiReserveId(spoke1));
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    // dai balance
    assertEq(tokenList.dai.balanceOf(carol), 0, 'user token balance after-supply');
    assertEq(
      tokenList.dai.balanceOf(address(hub)),
      tokenData[stage - 1].hubBalance + amount,
      'hub token balance after-supply'
    );
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance after-supply');

    // reserve
    assertEq(
      daiData[stage].data.baseDrawnShares,
      daiData[stage - 1].data.baseDrawnShares,
      'reserve baseDrawnShares after-supply'
    );
    assertEq(
      daiData[stage].data.suppliedShares,
      daiData[stage - 1].data.suppliedShares + expectedShares,
      'reserve suppliedShares after-supply'
    );

    // user
    assertEq(carolData[stage].data.baseDrawnShares, 0, 'user baseDrawnShares after-supply');
    assertEq(carolData[stage].data.premiumDrawnShares, 0, 'user premiumDrawnShares after-supply');
    assertEq(carolData[stage].data.premiumOffset, 0, 'user premiumOffset after-supply');
    assertEq(carolData[stage].data.realizedPremium, 0, 'user realizedPremium after-supply');
    assertEq(
      carolData[stage].data.suppliedShares,
      expectedShares,
      'user suppliedShares after-supply'
    );
  }

  function test_supply_fuzz_index_increase_with_premium(
    uint256 amount,
    uint256 rate,
    uint256 reserveId,
    uint256 skipTime
  ) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    rate = bound(rate, 1, MAX_BORROW_RATE);
    reserveId = bound(reserveId, 0, spokeInfo[spoke1].MAX_RESERVE_ID);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    (uint256 assetId, IERC20 underlying) = getAssetByReserveId(spoke1, reserveId);

    // alice supplies WETH as collateral, borrows DAI
    _executeSpokeSupplyAndBorrow({
      spoke: spoke1,
      collateral: TestReserve({
        reserveId: _wethReserveId(spoke1),
        supplier: alice,
        supplyAmount: 100e18,
        borrower: address(0),
        borrowAmount: 0
      }),
      borrow: TestReserve({
        reserveId: reserveId,
        borrowAmount: 10e18,
        supplyAmount: 20e18,
        borrower: alice,
        supplier: bob
      }),
      rate: rate,
      isMockRate: true,
      skipTime: skipTime
    });

    uint256 expectedShares = hub.convertToSuppliedShares(assetId, amount);
    vm.assume(expectedShares > 0);
    assertGt(amount, expectedShares, 'exchange rate should be > 1');

    TestUserData[2] memory carolData;
    TestData[2] memory reserveData;
    TokenData[2] memory tokenData;
    uint256 stage = 0;

    carolData[stage] = loadUserInfo(spoke1, reserveId, carol);
    reserveData[stage] = loadReserveInfo(spoke1, reserveId);
    tokenData[stage] = getTokenBalances(underlying, address(spoke1));

    assertGt(reserveData[stage].data.premiumDrawnShares, 0);

    deal(address(underlying), carol, amount);

    vm.expectEmit(address(spoke1));
    emit ISpoke.Supply(reserveId, carol, expectedShares);
    vm.prank(carol);
    spoke1.supply(reserveId, amount);

    stage = 1;
    carolData[stage] = loadUserInfo(spoke1, reserveId, carol);
    reserveData[stage] = loadReserveInfo(spoke1, reserveId);
    tokenData[stage] = getTokenBalances(underlying, address(spoke1));

    // token balance
    assertEq(underlying.balanceOf(carol), 0, 'user token balance after-supply');
    assertEq(
      underlying.balanceOf(address(hub)),
      tokenData[stage - 1].hubBalance + amount,
      'hub token balance after-supply'
    );
    assertEq(underlying.balanceOf(address(spoke1)), 0, 'spoke token balance after-supply');

    // reserve
    assertEq(
      reserveData[stage].data.baseDrawnShares,
      reserveData[stage - 1].data.baseDrawnShares,
      'reserve baseDrawnShares after-supply'
    );
    assertTrue(
      reserveData[stage].data.premiumDrawnShares > 0,
      'reserve premiumDrawnShares after-supply'
    );
    assertEq(
      reserveData[stage].data.suppliedShares,
      reserveData[stage - 1].data.suppliedShares + expectedShares,
      'reserve suppliedShares after-supply'
    );

    // user
    assertEq(carolData[stage].data.baseDrawnShares, 0, 'user baseDrawnShares after-supply');
    assertEq(carolData[stage].data.premiumDrawnShares, 0, 'user premiumDrawnShares after-supply');
    assertEq(carolData[stage].data.premiumOffset, 0, 'user premiumOffset after-supply');
    assertEq(carolData[stage].data.realizedPremium, 0, 'user realizedPremium after-supply');
    assertEq(
      carolData[stage].data.suppliedShares,
      expectedShares,
      'user suppliedShares after-supply'
    );
  }

  /// supply an asset with existing debt, with no interest accrual the two ex rates
  /// can increase due to rounding, with interest accrual should strictly increase
  function test_fuzz_supply_effect_on_ex_rates(uint256 amount, uint256 delay) public {
    delay = bound(delay, 1, MAX_SKIP_TIME);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT / 2);
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      amount
    );
    Utils.supply(spoke1, _daiReserveId(spoke1), bob, amount, bob);
    Utils.supply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob); // bob collateral
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, amount, bob); // introduce debt

    uint256 supplyExchangeRatio = hub.convertToSuppliedAssets(daiAssetId, MAX_SUPPLY_AMOUNT);
    uint256 debtExchangeRatio = hub.convertToDrawnAssets(daiAssetId, MAX_SUPPLY_AMOUNT);

    Utils.supply(spoke1, _daiReserveId(spoke1), alice, amount, alice);

    assertGe(hub.convertToSuppliedAssets(daiAssetId, MAX_SUPPLY_AMOUNT), supplyExchangeRatio);
    assertGe(hub.convertToDrawnAssets(daiAssetId, MAX_SUPPLY_AMOUNT), debtExchangeRatio);

    skip(delay); // with interest accrual, both ex rates should strictly

    assertGt(hub.convertToSuppliedAssets(daiAssetId, MAX_SUPPLY_AMOUNT), supplyExchangeRatio);
    assertGt(hub.convertToDrawnAssets(daiAssetId, MAX_SUPPLY_AMOUNT), debtExchangeRatio);

    if (hub.convertToSuppliedShares(daiAssetId, amount) > 0) {
      supplyExchangeRatio = hub.convertToSuppliedAssets(daiAssetId, MAX_SUPPLY_AMOUNT);
      debtExchangeRatio = hub.convertToDrawnAssets(daiAssetId, MAX_SUPPLY_AMOUNT);

      Utils.supply(spoke1, _daiReserveId(spoke1), alice, amount, alice);

      assertGe(hub.convertToSuppliedAssets(daiAssetId, MAX_SUPPLY_AMOUNT), supplyExchangeRatio);
      assertGe(hub.convertToDrawnAssets(daiAssetId, MAX_SUPPLY_AMOUNT), debtExchangeRatio);
    }
  }
}
