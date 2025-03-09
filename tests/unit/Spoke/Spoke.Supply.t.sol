// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeSupplyTest is SpokeBase {
  using WadRayMath for uint256;

  function test_supply_revertsWith_ReserveNotListed() public {
    uint256 reserveId = spoke1.reserveCount() + 1; // invalid reserveId
    uint256 amount = 100e18;

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(bob);
    spoke1.supply(reserveId, amount);
  }

  function test_supply_revertsWith_ReserveNotActive() public {
    uint256 daiReserveId = daiReserveId(spoke1);
    uint256 amount = 100e18;

    updateReserveActiveFlag(spoke1, daiReserveId, false);
    assertFalse(spoke1.getReserve(daiReserveId).config.active);

    vm.expectRevert(ISpoke.ReserveNotActive.selector);
    vm.prank(bob);
    spoke1.supply(daiReserveId, amount);
  }

  function test_supply_revertsWith_ReservePaused() public {
    uint256 daiReserveId = daiReserveId(spoke1);
    uint256 amount = 100e18;

    updateReservePausedFlag(spoke1, daiReserveId, true);
    assertTrue(spoke1.getReserve(daiReserveId).config.paused);

    vm.expectRevert(ISpoke.ReservePaused.selector);
    vm.prank(bob);
    spoke1.supply(daiReserveId, amount);
  }

  function test_supply_revertsWith_ReserveFrozen() public {
    uint256 daiReserveId = daiReserveId(spoke1);
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
    spoke1.supply(daiReserveId(spoke1), amount);
    vm.stopPrank();
  }

  function test_supply_revertsWith_invalid_supply_amount() public {
    uint256 amount = 0;

    vm.expectRevert(ILiquidityHub.InvalidSupplyAmount.selector);
    vm.prank(bob);
    spoke1.supply(daiReserveId(spoke1), amount);
  }

  function test_supply() public {
    uint256 amount = 100e18;

    TestUserData[2] memory bobData;
    TestData[2] memory daiData;
    uint256 stage = 0;

    bobData[stage] = loadUserInfo(spoke1, daiReserveId(spoke1), bob);
    daiData[stage] = loadReserveInfo(spoke1, daiReserveId(spoke1));

    // dai balance
    assertEq(tokenList.dai.balanceOf(bob), mintAmount_DAI, 'user token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(hub)), 0, 'hub token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance pre-supply');
    // reserve
    assertEq(daiData[stage].data.baseDebt, 0, 'reserve baseDebt pre-supply');
    assertEq(daiData[stage].data.outstandingPremium, 0, 'reserve outstandingPremium pre-supply');
    assertEq(daiData[stage].data.suppliedShares, 0, 'reserve suppliedShares pre-supply');
    assertEq(daiData[stage].data.lastUpdateTimestamp, 0, 'reserve lastUpdateTimestamp pre-supply');
    // user
    assertEq(bobData[stage].data.baseDebt, 0, 'user baseDebt pre-supply');
    assertEq(bobData[stage].data.outstandingPremium, 0, 'user outstandingPremium pre-supply');
    assertEq(bobData[stage].data.suppliedShares, 0, 'user suppliedShares pre-supply');
    assertEq(bobData[stage].data.lastUpdateTimestamp, 0, 'user lastUpdateTimestamp pre-supply');

    vm.expectEmit(address(spoke1));
    emit ISpoke.Supplied(daiReserveId(spoke1), bob, amount);
    vm.prank(bob);
    spoke1.supply(daiReserveId(spoke1), amount);

    stage = 1;
    bobData[stage] = loadUserInfo(spoke1, daiReserveId(spoke1), bob);
    daiData[stage] = loadReserveInfo(spoke1, daiReserveId(spoke1));

    // dai balance
    assertEq(
      tokenList.dai.balanceOf(bob),
      mintAmount_DAI - amount,
      'user token balance post-supply'
    );
    assertEq(tokenList.dai.balanceOf(address(hub)), amount, 'hub token balance post-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    // reserve
    assertEq(daiData[stage].data.baseDebt, 0, 'reserve baseDebt post-supply');
    assertEq(daiData[stage].data.outstandingPremium, 0, 'reserve outstandingPremium post-supply');
    assertEq(
      daiData[stage].data.suppliedShares,
      hub.convertToShares(daiAssetId, amount),
      'reserve suppliedShares post-supply'
    );
    assertEq(
      daiData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserve lastUpdateTimestamp post-supply'
    );
    // user
    assertEq(bobData[stage].data.baseDebt, 0, 'user baseDebt post-supply');
    assertEq(bobData[stage].data.outstandingPremium, 0, 'user outstandingPremium post-supply');
    assertEq(
      bobData[stage].data.suppliedShares,
      hub.convertToShares(daiAssetId, amount),
      'user suppliedShares post-supply'
    );
    assertEq(
      bobData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'user lastUpdateTimestamp post-supply'
    );
  }

  function test_supply_fuzz_amounts(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    deal(address(tokenList.dai), bob, amount);

    TestUserData[2] memory bobData;
    TestData[2] memory daiData;
    uint256 stage = 0;

    bobData[stage] = loadUserInfo(spoke1, daiReserveId(spoke1), bob);
    daiData[stage] = loadReserveInfo(spoke1, daiReserveId(spoke1));

    // dai balance
    assertEq(tokenList.dai.balanceOf(bob), amount, 'user token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(hub)), 0, 'hub token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance pre-supply');
    // reserve
    assertEq(daiData[stage].data.baseDebt, 0, 'reserve baseDebt pre-supply');
    assertEq(daiData[stage].data.outstandingPremium, 0, 'reserve outstandingPremium pre-supply');
    assertEq(daiData[stage].data.suppliedShares, 0, 'reserve suppliedShares pre-supply');
    assertEq(daiData[stage].data.lastUpdateTimestamp, 0, 'reserve lastUpdateTimestamp pre-supply');
    // user
    assertEq(bobData[stage].data.baseDebt, 0, 'user baseDebt pre-supply');
    assertEq(bobData[stage].data.outstandingPremium, 0, 'user outstandingPremium pre-supply');
    assertEq(bobData[stage].data.suppliedShares, 0, 'user suppliedShares pre-supply');
    assertEq(bobData[stage].data.lastUpdateTimestamp, 0, 'user lastUpdateTimestamp pre-supply');

    vm.expectEmit(address(spoke1));
    emit ISpoke.Supplied(daiReserveId(spoke1), bob, amount);
    vm.prank(bob);
    spoke1.supply(daiReserveId(spoke1), amount);

    stage = 1;
    bobData[stage] = loadUserInfo(spoke1, daiReserveId(spoke1), bob);
    daiData[stage] = loadReserveInfo(spoke1, daiReserveId(spoke1));

    // dai balance
    assertEq(tokenList.dai.balanceOf(bob), 0, 'user token balance post-supply');
    assertEq(tokenList.dai.balanceOf(address(hub)), amount, 'hub token balance post-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    // reserve
    assertEq(daiData[stage].data.baseDebt, 0, 'reserve baseDebt post-supply');
    assertEq(daiData[stage].data.outstandingPremium, 0, 'reserve outstandingPremium post-supply');
    assertEq(
      daiData[stage].data.suppliedShares,
      hub.convertToShares(daiAssetId, amount),
      'reserve suppliedShares post-supply'
    );
    assertEq(
      daiData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserve lastUpdateTimestamp post-supply'
    );
    // user
    assertEq(bobData[stage].data.baseDebt, 0, 'user baseDebt post-supply');
    assertEq(bobData[stage].data.outstandingPremium, 0, 'user outstandingPremium post-supply');
    assertEq(
      bobData[stage].data.suppliedShares,
      hub.convertToShares(daiAssetId, amount),
      'user suppliedShares post-supply'
    );
    assertEq(
      bobData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'user lastUpdateTimestamp post-supply'
    );
  }

  function test_supply_index_increase_no_premium() public {
    // set weth LP to 0 for no premium contribution
    updateLiquidityPremium({
      spoke: spoke1,
      reserveId: wethReserveId(spoke1),
      newLiquidityPremium: 0
    });

    // increase index on reserveId (uses weth as collateral)
    _increaseReserveIndex(spoke1, daiReserveId(spoke1));

    uint256 amount = 1e18;
    uint256 expectedShares = hub.convertToShares(daiAssetId, amount);
    assertGt(amount, expectedShares, 'exchange rate should be > 1');

    TestUserData[2] memory carolData;
    TestData[2] memory daiData;
    TokenData[2] memory tokenData;
    uint256 stage = 0;

    carolData[stage] = loadUserInfo(spoke1, daiReserveId(spoke1), carol);
    daiData[stage] = loadReserveInfo(spoke1, daiReserveId(spoke1));
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    deal(address(tokenList.dai), carol, amount);

    vm.expectEmit(address(spoke1));
    emit ISpoke.Supplied(daiReserveId(spoke1), carol, amount);
    vm.prank(carol);
    spoke1.supply(daiReserveId(spoke1), amount);
    stage = 1;

    carolData[stage] = loadUserInfo(spoke1, daiReserveId(spoke1), carol);
    daiData[stage] = loadReserveInfo(spoke1, daiReserveId(spoke1));
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    // dai balance
    assertEq(tokenList.dai.balanceOf(carol), 0, 'user token balance post-supply');
    assertEq(
      tokenList.dai.balanceOf(address(hub)),
      tokenData[stage - 1].hubBalance + amount,
      'hub token balance post-supply'
    );
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    // reserve
    assertEq(
      daiData[stage].data.baseDebt,
      daiData[stage - 1].data.baseDebt,
      'reserve baseDebt post-supply'
    );
    assertEq(daiData[stage].data.outstandingPremium, 0, 'reserve outstandingPremium post-supply');
    assertEq(
      daiData[stage].data.suppliedShares,
      daiData[stage - 1].data.suppliedShares + expectedShares,
      'reserve suppliedShares post-supply'
    );
    assertEq(
      daiData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserve lastUpdateTimestamp post-supply'
    );
    // user
    assertEq(carolData[stage].data.baseDebt, 0, 'user baseDebt post-supply');
    assertEq(carolData[stage].data.outstandingPremium, 0, 'user outstandingPremium post-supply');
    assertEq(
      carolData[stage].data.suppliedShares,
      expectedShares,
      'user suppliedShares post-supply'
    );
    assertEq(
      carolData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'user lastUpdateTimestamp post-supply'
    );
  }

  struct SupplyFuzzLocal {
    uint256 assetId;
    IERC20 asset;
    uint256 expectedShares;
  }

  function test_supply_fuzz_index_increase_no_premium(
    uint256 amount,
    uint256 rate,
    uint256 reserveId,
    uint256 skipTime
  ) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    rate = bound(rate, 1, MAX_BORROW_RATE).bpsToRay();
    reserveId = bound(reserveId, 0, spokeInfo[spoke1].MAX_RESERVE_ID);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    // set weth LP to 0 for no premium contribution
    updateLiquidityPremium({
      spoke: spoke1,
      reserveId: wethReserveId(spoke1),
      newLiquidityPremium: 0
    });

    // increase index on reserveId
    _executeSpokeSupplyAndBorrow({
      spoke: spoke1,
      collateral: TestReserve({
        reserveId: wethReserveId(spoke1),
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

    (state.assetId, state.asset) = getAssetByReserveId(spoke1, reserveId);

    state.expectedShares = hub.convertToShares(state.assetId, amount);
    vm.assume(state.expectedShares > 0);
    assertGt(amount, state.expectedShares, 'exchange rate should be > 1');

    TestUserData[2] memory carolData;
    TestData[2] memory reserveData;
    TokenData[2] memory tokenData;
    uint256 stage = 0;

    carolData[stage] = loadUserInfo(spoke1, reserveId, carol);
    reserveData[stage] = loadReserveInfo(spoke1, reserveId);
    tokenData[stage] = getTokenBalances(state.asset, address(spoke1));

    vm.assume(hub.convertToShares(daiAssetId, amount) > 0);

    vm.expectEmit(address(spoke1));
    emit ISpoke.Supplied(reserveId, carol, amount);
    vm.prank(carol);
    spoke1.supply(reserveId, amount);
    stage = 1;

    carolData[stage] = loadUserInfo(spoke1, reserveId, carol);
    reserveData[stage] = loadReserveInfo(spoke1, reserveId);
    tokenData[stage] = getTokenBalances(state.asset, address(spoke1));

    // token balance
    assertEq(
      state.asset.balanceOf(carol),
      MAX_SUPPLY_AMOUNT - amount,
      'user token balance post-supply'
    );
    assertEq(
      state.asset.balanceOf(address(hub)),
      tokenData[stage - 1].hubBalance + amount,
      'hub token balance post-supply'
    );
    assertEq(state.asset.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    // reserve
    assertEq(
      reserveData[stage].data.baseDebt,
      reserveData[stage - 1].data.baseDebt,
      'reserve baseDebt post-supply'
    );
    assertEq(
      reserveData[stage].data.outstandingPremium,
      0,
      'reserve outstandingPremium post-supply'
    );
    assertEq(
      reserveData[stage].data.suppliedShares,
      reserveData[stage - 1].data.suppliedShares + state.expectedShares,
      'reserve suppliedShares post-supply'
    );
    assertEq(
      reserveData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserve lastUpdateTimestamp post-supply'
    );
    // user
    assertEq(carolData[stage].data.baseDebt, 0, 'user baseDebt post-supply');
    assertEq(carolData[stage].data.outstandingPremium, 0, 'user outstandingPremium post-supply');
    assertEq(
      carolData[stage].data.suppliedShares,
      state.expectedShares,
      'user suppliedShares post-supply'
    );
    assertEq(
      carolData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'user lastUpdateTimestamp post-supply'
    );
  }

  function test_supply_index_increase_with_premium() public {
    _increaseReserveIndex(spoke1, daiReserveId(spoke1));

    uint256 amount = 1e18;
    uint256 expectedShares = hub.convertToShares(daiAssetId, amount);
    assertGt(amount, expectedShares, 'exchange rate should be > 1');

    TestUserData[2] memory carolData;
    TestData[2] memory daiData;
    TokenData[2] memory tokenData;
    uint256 stage = 0;

    carolData[stage] = loadUserInfo(spoke1, daiReserveId(spoke1), carol);
    daiData[stage] = loadReserveInfo(spoke1, daiReserveId(spoke1));
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    assertGt(daiData[stage].data.outstandingPremium, 0, 'reserve outstandingPremium post-supply');

    deal(address(tokenList.dai), carol, amount);

    vm.prank(carol);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Supplied(daiReserveId(spoke1), carol, amount);
    spoke1.supply(daiReserveId(spoke1), amount);
    stage = 1;

    carolData[stage] = loadUserInfo(spoke1, daiReserveId(spoke1), carol);
    daiData[stage] = loadReserveInfo(spoke1, daiReserveId(spoke1));
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    // dai balance
    assertEq(tokenList.dai.balanceOf(carol), 0, 'user token balance post-supply');
    assertEq(
      tokenList.dai.balanceOf(address(hub)),
      tokenData[stage - 1].hubBalance + amount,
      'hub token balance post-supply'
    );
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    // reserve
    assertEq(
      daiData[stage].data.baseDebt,
      daiData[stage - 1].data.baseDebt,
      'reserve baseDebt post-supply'
    );
    assertEq(
      daiData[stage].data.suppliedShares,
      daiData[stage - 1].data.suppliedShares + expectedShares,
      'reserve suppliedShares post-supply'
    );
    assertEq(
      daiData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserve lastUpdateTimestamp post-supply'
    );
    // user
    assertEq(carolData[stage].data.baseDebt, 0, 'user baseDebt post-supply');
    assertEq(carolData[stage].data.outstandingPremium, 0, 'user outstandingPremium post-supply');
    assertEq(
      carolData[stage].data.suppliedShares,
      expectedShares,
      'user suppliedShares post-supply'
    );
    assertEq(
      carolData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'user lastUpdateTimestamp post-supply'
    );
  }

  function test_supply_fuzz_index_increase_with_premium(
    uint256 amount,
    uint256 rate,
    uint256 reserveId,
    uint256 skipTime
  ) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    rate = bound(rate, 1, MAX_BORROW_RATE).bpsToRay();
    reserveId = bound(reserveId, 0, spokeInfo[spoke1].MAX_RESERVE_ID);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    (uint256 assetId, IERC20 asset) = getAssetByReserveId(spoke1, reserveId);

    // alice supplies usdx as collateral, borrows dai
    _executeSpokeSupplyAndBorrow({
      spoke: spoke1,
      collateral: TestReserve({
        reserveId: wethReserveId(spoke1),
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

    uint256 expectedShares = hub.convertToShares(assetId, amount);
    vm.assume(expectedShares > 0);
    assertGt(amount, expectedShares, 'exchange rate should be > 1');

    TestUserData[2] memory carolData;
    TestData[2] memory reserveData;
    TokenData[2] memory tokenData;
    uint256 stage = 0;

    carolData[stage] = loadUserInfo(spoke1, reserveId, carol);
    reserveData[stage] = loadReserveInfo(spoke1, reserveId);
    tokenData[stage] = getTokenBalances(asset, address(spoke1));

    assertGt(
      reserveData[stage].data.outstandingPremium,
      0,
      'reserve outstandingPremium pre-supply'
    );

    deal(address(asset), carol, amount);

    vm.expectEmit(address(spoke1));
    emit ISpoke.Supplied(reserveId, carol, amount);
    vm.prank(carol);
    spoke1.supply(reserveId, amount);

    stage = 1;

    carolData[stage] = loadUserInfo(spoke1, reserveId, carol);
    reserveData[stage] = loadReserveInfo(spoke1, reserveId);
    tokenData[stage] = getTokenBalances(asset, address(spoke1));

    // token balance
    assertEq(asset.balanceOf(carol), 0, 'user token balance post-supply');
    assertEq(
      asset.balanceOf(address(hub)),
      tokenData[stage - 1].hubBalance + amount,
      'hub token balance post-supply'
    );
    assertEq(asset.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    // reserve
    assertEq(
      reserveData[stage].data.baseDebt,
      reserveData[stage - 1].data.baseDebt,
      'reserve baseDebt post-supply'
    );
    assertTrue(
      reserveData[stage].data.outstandingPremium > 0,
      'reserve outstandingPremium post-supply'
    );
    assertEq(
      reserveData[stage].data.suppliedShares,
      reserveData[stage - 1].data.suppliedShares + expectedShares,
      'reserve suppliedShares post-supply'
    );
    assertEq(
      reserveData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserve lastUpdateTimestamp post-supply'
    );
    // user
    assertEq(carolData[stage].data.baseDebt, 0, 'user baseDebt post-supply');
    assertEq(carolData[stage].data.outstandingPremium, 0, 'user outstandingPremium post-supply');
    assertEq(
      carolData[stage].data.suppliedShares,
      expectedShares,
      'user suppliedShares post-supply'
    );
    assertEq(
      carolData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'user lastUpdateTimestamp post-supply'
    );
  }
}
