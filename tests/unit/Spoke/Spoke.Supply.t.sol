// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeSupplyTest is SpokeBase {
  using PercentageMath for *;

  function test_supply_revertsWith_ReserveNotListed() public {
    uint256 reserveId = spoke1.getReserveCount() + 1; // invalid reserveId
    uint256 amount = 100e18;

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(bob);
    spoke1.supply(reserveId, amount, bob);
  }

  function test_supply_revertsWith_ReservePaused() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;

    _updateReservePausedFlag(spoke1, daiReserveId, true);
    assertTrue(spoke1.getReserve(daiReserveId).paused);

    vm.expectRevert(ISpoke.ReservePaused.selector);
    vm.prank(bob);
    spoke1.supply(daiReserveId, amount, bob);
  }

  function test_supply_revertsWith_ReserveFrozen() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;

    updateReserveFrozenFlag(spoke1, daiReserveId, true);
    assertTrue(spoke1.getReserve(daiReserveId).frozen);

    vm.expectRevert(ISpoke.ReserveFrozen.selector);
    vm.prank(bob);
    spoke1.supply(daiReserveId, amount, bob);
  }

  function test_supply_revertsWith_TransferFromFailed() public {
    uint256 amount = 100e18;
    uint256 approvalAmount = amount - 1;

    vm.startPrank(bob);
    tokenList.dai.approve(address(spoke1), approvalAmount);
    vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
    spoke1.supply(_daiReserveId(spoke1), amount, bob);
    vm.stopPrank();
  }

  function test_supply_fuzz_revertsWith_TransferFromFailed(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    address randomUser = makeAddr('randomUser');

    vm.startPrank(randomUser);
    tokenList.dai.approve(address(spoke1), amount);
    vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
    spoke1.supply(_daiReserveId(spoke1), amount, randomUser);
    vm.stopPrank();
  }

  function test_supply_revertsWith_InvalidSupplyAmount() public {
    uint256 amount = 0;

    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(bob);
    spoke1.supply(_daiReserveId(spoke1), amount, bob);
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
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0);
    // reserve
    assertEq(daiData[stage].data.drawnShares, 0);
    assertEq(daiData[stage].data.premiumShares, 0);
    assertEq(daiData[stage].data.premiumOffsetRay, 0);
    assertEq(daiData[stage].data.addedShares, 0);
    // user
    assertEq(bobData[stage].data.drawnShares, 0);
    assertEq(bobData[stage].data.premiumShares, 0);
    assertEq(bobData[stage].data.premiumOffsetRay, 0);
    assertEq(bobData[stage].data.suppliedShares, 0);
    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Supply(
      _daiReserveId(spoke1),
      bob,
      bob,
      hub1.previewAddByAssets(daiAssetId, amount),
      amount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = spoke1.supply(_daiReserveId(spoke1), amount, bob);
    stage = 1;
    bobData[stage] = loadUserInfo(spoke1, _daiReserveId(spoke1), bob);
    daiData[stage] = loadReserveInfo(spoke1, _daiReserveId(spoke1));
    assertEq(returnValues.shares, hub1.previewAddByAssets(daiAssetId, amount));
    assertEq(returnValues.amount, amount);
    // dai balance
    assertEq(
      tokenList.dai.balanceOf(bob),
      mintAmount_DAI - amount,
      'user token balance after-supply'
    );
    assertEq(tokenList.dai.balanceOf(address(hub1)), amount, 'hub token balance after-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance after-supply');
    // reserve
    assertEq(daiData[stage].data.drawnShares, 0, 'reserve drawnShares after-supply');
    assertEq(daiData[stage].data.premiumShares, 0, 'reserve premiumShares after-supply');
    assertEq(daiData[stage].data.premiumOffsetRay, 0, 'reserve premiumOffsetRay after-supply');
    assertEq(
      daiData[stage].data.addedShares,
      hub1.previewAddByAssets(daiAssetId, amount),
      'reserve suppliedShares after-supply'
    );
    assertEq(
      amount,
      hub1.getSpokeAddedAssets(daiAssetId, address(spoke1)),
      'spoke supplied amount after-supply'
    );
    assertEq(amount, hub1.getAddedAssets(daiAssetId), 'asset supplied amount after-supply');
    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.supply');

    // user
    assertEq(bobData[stage].data.drawnShares, 0, 'bob drawnShares after-supply');
    assertEq(bobData[stage].data.premiumShares, 0, 'bob premiumShares after-supply');
    assertEq(bobData[stage].data.premiumOffsetRay, 0, 'bob premiumOffsetRay after-supply');
    assertEq(
      bobData[stage].data.suppliedShares,
      hub1.previewAddByAssets(daiAssetId, amount),
      'bob suppliedShares after-supply'
    );
    assertEq(
      amount,
      spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), bob),
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
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0);
    // reserve
    assertEq(daiData[stage].data.drawnShares, 0);
    assertEq(daiData[stage].data.premiumShares, 0);
    assertEq(daiData[stage].data.premiumOffsetRay, 0);
    assertEq(daiData[stage].data.addedShares, 0);
    // user
    assertEq(bobData[stage].data.drawnShares, 0);
    assertEq(bobData[stage].data.premiumShares, 0);
    assertEq(bobData[stage].data.premiumOffsetRay, 0);
    assertEq(bobData[stage].data.suppliedShares, 0);

    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Supply(
      _daiReserveId(spoke1),
      bob,
      bob,
      hub1.previewAddByAssets(daiAssetId, amount),
      amount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = spoke1.supply(_daiReserveId(spoke1), amount, bob);

    stage = 1;
    bobData[stage] = loadUserInfo(spoke1, _daiReserveId(spoke1), bob);
    daiData[stage] = loadReserveInfo(spoke1, _daiReserveId(spoke1));

    assertEq(returnValues.shares, hub1.previewAddByAssets(daiAssetId, amount));
    assertEq(returnValues.amount, amount);
    // dai balance
    assertEq(tokenList.dai.balanceOf(bob), 0, 'user token balance after-supply');
    assertEq(tokenList.dai.balanceOf(address(hub1)), amount, 'hub token balance after-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance after-supply');
    // reserve
    assertEq(daiData[stage].data.drawnShares, 0, 'reserve drawnShares after-supply');
    assertEq(daiData[stage].data.premiumShares, 0, 'reserve premiumShares after-supply');
    assertEq(daiData[stage].data.premiumOffsetRay, 0, 'reserve premiumOffsetRay after-supply');
    assertEq(
      daiData[stage].data.addedShares,
      hub1.previewAddByAssets(daiAssetId, amount),
      'reserve suppliedShares after-supply'
    );
    assertEq(
      amount,
      hub1.getSpokeAddedAssets(daiAssetId, address(spoke1)),
      'spoke supplied amount after-supply'
    );
    assertEq(amount, hub1.getAddedAssets(daiAssetId), 'asset supplied amount after-supply');
    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.supply');

    // user
    assertEq(bobData[stage].data.drawnShares, 0, 'user drawnShares after-supply');
    assertEq(bobData[stage].data.premiumShares, 0, 'user premiumShares after-supply');
    assertEq(bobData[stage].data.premiumOffsetRay, 0, 'user premiumOffsetRay after-supply');
    assertEq(
      bobData[stage].data.suppliedShares,
      hub1.previewAddByAssets(daiAssetId, amount),
      'user suppliedShares after-supply'
    );
    assertEq(
      amount,
      spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), bob),
      'user supplied amount after-supply'
    );
  }

  function test_supply_index_increase_no_premium() public {
    // set weth collateral risk to 0 for no premium contribution
    _updateCollateralRisk({spoke: spoke1, reserveId: _wethReserveId(spoke1), newCollateralRisk: 0});

    // increase index on reserveId (uses weth as collateral)
    _increaseReserveIndex(spoke1, _daiReserveId(spoke1));

    uint256 amount = 1e18;
    uint256 expectedShares = hub1.previewAddByAssets(daiAssetId, amount);
    assertGt(amount, expectedShares, 'exchange rate should be > 1');

    TestUserData[2] memory carolData;
    TestData[2] memory daiData;
    TokenData[2] memory tokenData;
    uint256 stage = 0;

    carolData[stage] = loadUserInfo(spoke1, _daiReserveId(spoke1), carol);
    daiData[stage] = loadReserveInfo(spoke1, _daiReserveId(spoke1));
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    deal(address(tokenList.dai), carol, amount);

    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Supply(_daiReserveId(spoke1), carol, carol, expectedShares, amount);
    _assertRefreshPremiumNotCalled();
    vm.prank(carol);
    (returnValues.shares, returnValues.amount) = spoke1.supply(
      _daiReserveId(spoke1),
      amount,
      carol
    );
    stage = 1;

    carolData[stage] = loadUserInfo(spoke1, _daiReserveId(spoke1), carol);
    daiData[stage] = loadReserveInfo(spoke1, _daiReserveId(spoke1));
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    assertEq(returnValues.shares, expectedShares);
    assertEq(returnValues.amount, amount);
    // dai balance
    assertEq(tokenList.dai.balanceOf(carol), 0, 'user token balance after-supply');
    assertEq(
      tokenList.dai.balanceOf(address(hub1)),
      tokenData[stage - 1].hubBalance + amount,
      'hub token balance after-supply'
    );
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance after-supply');

    // reserve
    assertEq(
      daiData[stage].data.drawnShares,
      daiData[stage - 1].data.drawnShares,
      'reserve drawnShares after-supply'
    );
    assertEq(daiData[stage].data.premiumShares, 0, 'reserve premiumShares after-supply');
    assertEq(daiData[stage].data.premiumOffsetRay, 0, 'reserve premiumOffsetRay after-supply');
    assertEq(
      daiData[stage].data.addedShares,
      daiData[stage - 1].data.addedShares + expectedShares,
      'reserve addedShares after-supply'
    );
    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.supply');

    // user
    assertEq(carolData[stage].data.drawnShares, 0, 'user drawnShares after-supply');
    assertEq(carolData[stage].data.premiumShares, 0, 'user premiumShares after-supply');
    assertEq(carolData[stage].data.premiumOffsetRay, 0, 'user premiumOffsetRay after-supply');
    assertEq(
      carolData[stage].data.suppliedShares,
      expectedShares,
      'user suppliedShares after-supply'
    );
    assertApproxEqAbs(
      amount,
      spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), carol),
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
    reserveId = bound(reserveId, 0, spokeInfo[spoke1].MAX_ALLOWED_ASSET_ID);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    // set weth collateral risk to 0 for no premium contribution
    _updateCollateralRisk({spoke: spoke1, reserveId: _wethReserveId(spoke1), newCollateralRisk: 0});

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
    state.expectedShares = hub1.previewAddByAssets(state.assetId, amount);

    vm.assume(state.expectedShares > 0);
    assertGt(amount, state.expectedShares, 'exchange rate should be > 1');

    TestUserData[2] memory carolData;
    TestData[2] memory reserveData;
    TokenData[2] memory tokenData;
    uint256 stage = 0;

    carolData[stage] = loadUserInfo(spoke1, reserveId, carol);
    reserveData[stage] = loadReserveInfo(spoke1, reserveId);
    tokenData[stage] = getTokenBalances(state.underlying, address(spoke1));

    uint256 expectedSuppliedShares = hub1.previewAddByAssets(state.assetId, amount);
    vm.assume(expectedSuppliedShares > 0);

    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Supply(reserveId, carol, carol, expectedSuppliedShares, amount);
    _assertRefreshPremiumNotCalled();
    vm.prank(carol);
    (returnValues.shares, returnValues.amount) = spoke1.supply(reserveId, amount, carol);
    stage = 1;

    carolData[stage] = loadUserInfo(spoke1, reserveId, carol);
    reserveData[stage] = loadReserveInfo(spoke1, reserveId);
    tokenData[stage] = getTokenBalances(state.underlying, address(spoke1));

    assertEq(returnValues.shares, expectedSuppliedShares);
    assertEq(returnValues.amount, amount);
    // token balance
    assertEq(
      state.underlying.balanceOf(carol),
      MAX_SUPPLY_AMOUNT - amount,
      'user token balance after-supply'
    );
    assertEq(
      state.underlying.balanceOf(address(hub1)),
      tokenData[stage - 1].hubBalance + amount,
      'hub token balance after-supply'
    );
    assertEq(state.underlying.balanceOf(address(spoke1)), 0, 'spoke token balance after-supply');

    // reserve
    assertEq(
      reserveData[stage].data.drawnShares,
      reserveData[stage - 1].data.drawnShares,
      'reserve drawnShares after-supply'
    );
    assertEq(reserveData[stage].data.premiumShares, 0, 'reserve premiumShares after-supply');
    assertEq(reserveData[stage].data.premiumOffsetRay, 0, 'reserve premiumOffsetRay after-supply');
    assertEq(
      reserveData[stage].data.addedShares,
      reserveData[stage - 1].data.addedShares + state.expectedShares,
      'reserve addedShares after-supply'
    );
    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.supply');

    // user
    assertEq(carolData[stage].data.drawnShares, 0, 'user drawnShares after-supply');
    assertEq(carolData[stage].data.premiumShares, 0, 'user premiumShares after-supply');
    assertEq(carolData[stage].data.premiumOffsetRay, 0, 'user premiumOffsetRay after-supply');
    assertEq(
      carolData[stage].data.suppliedShares,
      state.expectedShares,
      'user suppliedShares after-supply'
    );
  }

  function test_supply_index_increase_with_premium() public {
    _increaseReserveIndex(spoke1, _daiReserveId(spoke1));

    uint256 amount = 1e18;
    uint256 expectedShares = hub1.previewAddByAssets(daiAssetId, amount);
    assertGt(amount, expectedShares, 'exchange rate should be > 1');

    TestUserData[2] memory carolData;
    TestData[2] memory daiData;
    TokenData[2] memory tokenData;
    uint256 stage = 0;

    carolData[stage] = loadUserInfo(spoke1, _daiReserveId(spoke1), carol);
    daiData[stage] = loadReserveInfo(spoke1, _daiReserveId(spoke1));
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    assertGt(daiData[stage].data.premiumShares, 0, 'reserve premiumShares after-supply');

    deal(address(tokenList.dai), carol, amount);

    TestReturnValues memory returnValues;
    vm.prank(carol);
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Supply(_daiReserveId(spoke1), carol, carol, expectedShares, amount);
    _assertRefreshPremiumNotCalled();
    (returnValues.shares, returnValues.amount) = spoke1.supply(
      _daiReserveId(spoke1),
      amount,
      carol
    );
    stage = 1;

    carolData[stage] = loadUserInfo(spoke1, _daiReserveId(spoke1), carol);
    daiData[stage] = loadReserveInfo(spoke1, _daiReserveId(spoke1));
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    assertEq(returnValues.shares, expectedShares);
    assertEq(returnValues.amount, amount);
    // dai balance
    assertEq(tokenList.dai.balanceOf(carol), 0, 'user token balance after-supply');
    assertEq(
      tokenList.dai.balanceOf(address(hub1)),
      tokenData[stage - 1].hubBalance + amount,
      'hub token balance after-supply'
    );
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance after-supply');

    // reserve
    assertEq(
      daiData[stage].data.drawnShares,
      daiData[stage - 1].data.drawnShares,
      'reserve drawnShares after-supply'
    );
    assertEq(
      daiData[stage].data.addedShares,
      daiData[stage - 1].data.addedShares + expectedShares,
      'reserve addedShares after-supply'
    );
    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.supply');

    // user
    assertEq(carolData[stage].data.drawnShares, 0, 'user drawnShares after-supply');
    assertEq(carolData[stage].data.premiumShares, 0, 'user premiumShares after-supply');
    assertEq(carolData[stage].data.premiumOffsetRay, 0, 'user premiumOffsetRay after-supply');
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
    reserveId = bound(reserveId, 0, spokeInfo[spoke1].MAX_ALLOWED_ASSET_ID);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    (, IERC20 underlying) = getAssetByReserveId(spoke1, reserveId);

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

    uint256 expectedShares = hub1.previewAddByAssets(spoke1.getReserve(reserveId).assetId, amount);
    vm.assume(expectedShares > 0);
    assertGt(amount, expectedShares, 'exchange rate should be > 1');

    TestUserData[2] memory carolData;
    TestData[2] memory reserveData;
    TokenData[2] memory tokenData;
    uint256 stage = 0;

    carolData[stage] = loadUserInfo(spoke1, reserveId, carol);
    reserveData[stage] = loadReserveInfo(spoke1, reserveId);
    tokenData[stage] = getTokenBalances(underlying, address(spoke1));

    assertGt(reserveData[stage].data.premiumShares, 0);

    deal(address(underlying), carol, amount);

    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Supply(reserveId, carol, carol, expectedShares, amount);
    _assertRefreshPremiumNotCalled();
    vm.prank(carol);
    (returnValues.shares, returnValues.amount) = spoke1.supply(reserveId, amount, carol);

    stage = 1;
    carolData[stage] = loadUserInfo(spoke1, reserveId, carol);
    reserveData[stage] = loadReserveInfo(spoke1, reserveId);
    tokenData[stage] = getTokenBalances(underlying, address(spoke1));

    assertEq(returnValues.shares, expectedShares);
    assertEq(returnValues.amount, amount);
    // token balance
    assertEq(underlying.balanceOf(carol), 0, 'user token balance after-supply');
    assertEq(
      underlying.balanceOf(address(hub1)),
      tokenData[stage - 1].hubBalance + amount,
      'hub token balance after-supply'
    );
    assertEq(underlying.balanceOf(address(spoke1)), 0, 'spoke token balance after-supply');

    // reserve
    assertEq(
      reserveData[stage].data.drawnShares,
      reserveData[stage - 1].data.drawnShares,
      'reserve drawnShares after-supply'
    );
    assertTrue(reserveData[stage].data.premiumShares > 0, 'reserve premiumShares after-supply');
    assertEq(
      reserveData[stage].data.addedShares,
      reserveData[stage - 1].data.addedShares + expectedShares,
      'reserve addedShares after-supply'
    );
    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.supply');

    // user
    assertEq(carolData[stage].data.drawnShares, 0, 'user drawnShares after-supply');
    assertEq(carolData[stage].data.premiumShares, 0, 'user premiumShares after-supply');
    assertEq(carolData[stage].data.premiumOffsetRay, 0, 'user premiumOffsetRay after-supply');
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
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob); // bob collateral
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, amount, bob); // introduce debt

    uint256 supplyExchangeRatio = hub1.previewRemoveByShares(daiAssetId, MAX_SUPPLY_AMOUNT);
    uint256 debtExchangeRatio = hub1.previewRestoreByShares(daiAssetId, MAX_SUPPLY_AMOUNT);

    Utils.supply(spoke1, _daiReserveId(spoke1), alice, amount, alice);

    assertGe(hub1.previewRemoveByShares(daiAssetId, MAX_SUPPLY_AMOUNT), supplyExchangeRatio);
    assertGe(hub1.previewRestoreByShares(daiAssetId, MAX_SUPPLY_AMOUNT), debtExchangeRatio);

    skip(delay); // with interest accrual, both ex rates should strictly

    assertGt(hub1.previewRemoveByShares(daiAssetId, MAX_SUPPLY_AMOUNT), supplyExchangeRatio);
    assertGt(hub1.previewRestoreByShares(daiAssetId, MAX_SUPPLY_AMOUNT), debtExchangeRatio);

    if (hub1.previewAddByAssets(daiAssetId, amount) > 0) {
      supplyExchangeRatio = hub1.previewRemoveByShares(daiAssetId, MAX_SUPPLY_AMOUNT);
      debtExchangeRatio = hub1.previewRestoreByShares(daiAssetId, MAX_SUPPLY_AMOUNT);

      Utils.supply(spoke1, _daiReserveId(spoke1), alice, amount, alice);

      assertGe(hub1.previewRemoveByShares(daiAssetId, MAX_SUPPLY_AMOUNT), supplyExchangeRatio);
      assertGe(hub1.previewRestoreByShares(daiAssetId, MAX_SUPPLY_AMOUNT), debtExchangeRatio);
    }
  }

  /// test that during a supply action with existing debt assets, risk premium is not refreshed
  function test_supply_does_not_update_risk_premium() public {
    _openSupplyPosition(spoke1, _usdxReserveId(spoke1), MAX_SUPPLY_AMOUNT);
    _openSupplyPosition(spoke1, _daiReserveId(spoke1), MAX_SUPPLY_AMOUNT);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, 50_000e18, bob); // bob dai collateral, $50k
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, 1e18, bob); // bob weth collateral, $2k

    // bob borrows 2 assets
    Utils.borrow(spoke1, _usdxReserveId(spoke1), bob, 10_000e6, bob); // bob borrows usdx, $5k
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, 10_000e18, bob); // bob borrows dai, $10k

    uint256 initialRP = _getUserRiskPremium(spoke1, bob);
    assertEq(initialRP, _calculateExpectedUserRP(spoke1, bob));

    assertGt(
      _getCollateralRisk(spoke1, _daiReserveId(spoke1)),
      _getCollateralRisk(spoke1, _wethReserveId(spoke1))
    );
    // bob does another supply action of the lower collateral risk reserve
    // risk premium should not be refreshed
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, 10_000e18, bob);

    // on-the-fly RP calc does not match initial value
    assertNotEq(_getUserRiskPremium(spoke1, bob), initialRP);
    // debt assets retain the same RP as initial
    assertEq(_calcStoredUserRP(spoke1, _usdxReserveId(spoke1), bob), initialRP);
    assertEq(_calcStoredUserRP(spoke1, _daiReserveId(spoke1), bob), initialRP);
  }

  /// calculate user RP based on stored premium shares / drawn shares
  function _calcStoredUserRP(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (uint256) {
    ISpoke.UserPosition memory pos = spoke.getUserPosition(reserveId, user);
    return pos.premiumShares.percentDivDown(pos.drawnShares);
  }
}
