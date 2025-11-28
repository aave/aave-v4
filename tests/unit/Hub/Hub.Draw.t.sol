// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubDrawTest is HubBase {
  using SharesMath for uint256;
  using SafeCast for uint256;

  function test_draw_fuzz_amounts_same_block(uint256 assetId, uint256 amount) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 3); // Exclude usdy & usdz
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    IERC20 underlying = IERC20(hub1.getAsset(assetId).underlying);

    // spoke2, bob add dai
    Utils.add({hub: hub1, assetId: assetId, caller: address(spoke2), amount: amount, user: bob});

    uint256 shares = hub1.previewDrawByAssets(assetId, amount);

    IHub.Asset memory assetBefore = hub1.getAsset(assetId);
    (, uint256 premium) = hub1.getAssetOwed(assetId);
    vm.expectCall(
      address(irStrategy),
      abi.encodeCall(
        IBasicInterestRateStrategy.calculateInterestRate,
        (
          assetId,
          assetBefore.liquidity - assetBefore.swept - amount,
          hub1.previewRestoreByShares(assetId, assetBefore.drawnShares + shares),
          assetBefore.deficitRay,
          assetBefore.swept
        )
      )
    );

    vm.expectEmit(address(hub1));
    emit IHub.UpdateAsset(
      assetId,
      hub1.getAssetDrawnIndex(assetId),
      IBasicInterestRateStrategy(irStrategy).calculateInterestRate({
        assetId: assetId,
        liquidity: assetBefore.liquidity - assetBefore.swept - amount,
        drawn: hub1.previewRestoreByShares(assetId, assetBefore.drawnShares + shares),
        deficit: assetBefore.deficitRay,
        swept: assetBefore.swept
      }),
      hub1.getAssetAccruedFees(assetId)
    );
    vm.expectEmit(address(hub1.getAsset(assetId).underlying));
    emit IERC20.Transfer(address(hub1), alice, amount);
    vm.expectEmit(address(hub1));
    emit IHubBase.Draw(assetId, address(spoke1), shares, amount);

    vm.prank(address(spoke1));
    hub1.draw(assetId, amount, alice);

    // hub
    uint256 drawn;
    (drawn, premium) = hub1.getAssetOwed(assetId);
    assertEq(hub1.getAssetTotalOwed(assetId), amount, 'asset totalDebt after');
    assertEq(drawn, amount, 'asset drawn after');
    assertEq(premium, 0, 'asset premium after');
    assertEq(hub1.getAssetLiquidity(assetId), 0, 'asset liquidity after');
    assertEq(
      hub1.getAsset(assetId).lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'asset lastUpdateTimestamp after'
    );
    assertEq(
      hub1.getAsset(assetId).liquidity,
      assetBefore.liquidity - amount,
      'available liquidity after draw'
    );
    assertEq(
      hub1.getAsset(assetId).drawnShares,
      assetBefore.drawnShares + shares,
      'drawnShares after draw'
    );
    _assertBorrowRateSynced(hub1, assetId, 'hub1.draw');
    _assertHubLiquidity(hub1, assetId, 'hub1.draw');
    // spoke
    (drawn, premium) = hub1.getSpokeOwed(assetId, address(spoke1));
    assertEq(hub1.getSpokeTotalOwed(assetId, address(spoke1)), amount, 'spoke totalDebt after');
    assertEq(drawn, amount, 'spoke drawn after');
    assertEq(premium, 0, 'spoke premium after');
    // token balance
    assertEq(underlying.balanceOf(alice), amount + MAX_SUPPLY_AMOUNT, 'alice asset final balance');
    assertEq(underlying.balanceOf(bob), MAX_SUPPLY_AMOUNT - amount, 'bob asset final balance');
    assertEq(underlying.balanceOf(address(spoke1)), 0, 'spoke1 asset final balance');
    assertEq(underlying.balanceOf(address(spoke2)), 0, 'spoke2 asset final balance');
    assertEq(
      hub1.previewDrawByAssets(assetId, amount),
      hub1.previewRestoreByShares(assetId, amount)
    );
  }

  function test_draw_fuzz_IncreasedBorrowRate(uint256 assetId, uint256 amount) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 3); // Exclude usdy & usdz
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT / 10);

    _addLiquidity(assetId, amount * 2);
    _drawLiquidity(assetId, amount, true);
    skip(365 days);

    uint256 shares = hub1.previewDrawByAssets(assetId, amount);

    IHub.Asset memory assetBefore = hub1.getAsset(assetId);
    vm.expectCall(
      address(irStrategy),
      abi.encodeCall(
        IBasicInterestRateStrategy.calculateInterestRate,
        (
          assetId,
          assetBefore.liquidity - assetBefore.swept - amount,
          hub1.previewRestoreByShares(assetId, assetBefore.drawnShares + shares),
          assetBefore.deficitRay,
          assetBefore.swept
        )
      )
    );

    vm.expectEmit(address(hub1));
    emit IHub.UpdateAsset(
      assetId,
      hub1.getAssetDrawnIndex(assetId),
      IBasicInterestRateStrategy(irStrategy).calculateInterestRate({
        assetId: assetId,
        liquidity: assetBefore.liquidity - assetBefore.swept - amount,
        drawn: hub1.previewRestoreByShares(assetId, assetBefore.drawnShares + shares),
        deficit: assetBefore.deficitRay,
        swept: assetBefore.swept
      }),
      hub1.getAssetAccruedFees(assetId)
    );
    vm.expectEmit(address(hub1.getAsset(assetId).underlying));
    emit IERC20.Transfer(address(hub1), alice, amount);
    vm.expectEmit(address(hub1));
    emit IHubBase.Draw(assetId, address(spoke1), shares, amount);

    vm.prank(address(spoke1));
    hub1.draw(assetId, amount, alice);

    assertEq(
      hub1.getAsset(assetId).liquidity,
      assetBefore.liquidity - amount,
      'available liquidity after draw'
    );
    assertEq(
      hub1.getAsset(assetId).drawnShares,
      assetBefore.drawnShares + shares,
      'drawnShares after draw'
    );

    _assertBorrowRateSynced(hub1, assetId, 'hub1.draw');
    _assertHubLiquidity(hub1, assetId, 'hub1.draw');
  }

  function test_draw_revertsWith_SpokePaused() public {
    _updateSpokePaused(hub1, daiAssetId, address(spoke1), true);
    vm.expectRevert(IHub.SpokePaused.selector);
    vm.prank(address(spoke1));
    hub1.draw(daiAssetId, 100e18, alice);
  }

  function test_draw_revertsWith_SpokeNotActive() public {
    updateSpokeActive(hub1, daiAssetId, address(spoke1), false);
    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.draw(daiAssetId, 100e18, alice);
  }

  function test_draw_revertsWith_InsufficientLiquidity() public {
    uint256 drawAmount = 1;

    assertTrue(hub1.getAssetLiquidity(daiAssetId) == 0);

    vm.expectRevert(abi.encodeWithSelector(IHub.InsufficientLiquidity.selector, 0));
    vm.prank(address(spoke1));
    hub1.draw(daiAssetId, drawAmount, address(spoke1));
  }

  function test_draw_fuzz_revertsWith_InsufficientLiquidity(
    uint256 assetId,
    uint256 drawAmount
  ) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 3); // Exclude usdy & usdz
    drawAmount = bound(drawAmount, 1, MAX_SUPPLY_AMOUNT);

    assertTrue(hub1.getAssetLiquidity(assetId) == 0);

    vm.expectRevert(abi.encodeWithSelector(IHub.InsufficientLiquidity.selector, 0));
    vm.prank(address(spoke2));
    hub1.draw(assetId, drawAmount, address(spoke2));
  }

  function test_draw_revertsWith_InsufficientLiquidity_due_to_remove() public {
    uint256 daiAmount = 100e18;

    // spoke2, bob add dai
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: daiAmount,
      user: bob
    });
    // remove all so no liquidity remains
    Utils.remove({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: daiAmount,
      to: bob
    });

    assertTrue(hub1.getAssetLiquidity(daiAssetId) == 0);

    uint256 drawAmount = 1;

    vm.expectRevert(abi.encodeWithSelector(IHub.InsufficientLiquidity.selector, 0));
    vm.prank(address(spoke1));
    hub1.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_fuzz_revertsWith_InsufficientLiquidity_due_to_remove(
    uint256 daiAmount
  ) public {
    daiAmount = bound(daiAmount, 1, MAX_SUPPLY_AMOUNT);

    // spoke2, bob add dai
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: daiAmount,
      user: bob
    });
    // remove all so no liquidity remains
    Utils.remove({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: daiAmount,
      to: bob
    });

    assertTrue(hub1.getAssetLiquidity(daiAssetId) == 0);

    uint256 drawAmount = 1;

    vm.expectRevert(abi.encodeWithSelector(IHub.InsufficientLiquidity.selector, 0));
    vm.prank(address(spoke1));
    hub1.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_revertsWith_InsufficientLiquidity_due_to_draw() public {
    uint256 daiAmount = 100e18;

    // spoke2, bob add dai
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: daiAmount,
      user: bob
    });
    // draw all so no liquidity remains
    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: daiAmount,
      to: bob
    });

    assertTrue(hub1.getAssetLiquidity(daiAssetId) == 0);

    uint256 drawAmount = 1;

    vm.expectRevert(abi.encodeWithSelector(IHub.InsufficientLiquidity.selector, 0));
    vm.prank(address(spoke1));
    hub1.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_fuzz_revertsWith_InsufficientLiquidity_due_to_draw(uint256 daiAmount) public {
    daiAmount = bound(daiAmount, 1, MAX_SUPPLY_AMOUNT);

    // spoke2, bob add dai
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: daiAmount,
      user: bob
    });
    // draw all so no liquidity remains
    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: daiAmount,
      to: bob
    });

    assertTrue(hub1.getAssetLiquidity(daiAssetId) == 0);

    uint256 drawAmount = 1;

    vm.expectRevert(abi.encodeWithSelector(IHub.InsufficientLiquidity.selector, 0));
    vm.prank(address(spoke1));
    hub1.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_revertsWith_InvalidAmount() public {
    uint256 drawAmount = 0;

    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(address(spoke1));
    hub1.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_fuzz_revertsWith_DrawCapExceeded_due_to_interest(
    uint40 drawCap,
    uint256 rate,
    uint256 skipTime
  ) public {
    drawCap = bound(drawCap, 1, MAX_SUPPLY_AMOUNT / 10 ** tokenList.dai.decimals()).toUint40();
    uint256 daiAmount = drawCap * 10 ** tokenList.dai.decimals() - 1;
    rate = bound(rate, 1, MAX_BORROW_RATE);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    updateDrawCap(hub1, daiAssetId, address(spoke1), drawCap);

    _mockInterestRateBps(rate);
    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke2),
      addAmount: daiAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: daiAmount,
      skipTime: skipTime
    });

    (uint256 drawn, ) = hub1.getAssetOwed(daiAssetId);
    uint256 singleShareInAssets = minimumAssetsPerDrawnShare(hub1, daiAssetId);
    // Need the drawn to be greater than the drawCap from interest, past the share we restore
    vm.assume(drawn > drawCap + singleShareInAssets);

    // restore to provide liquidity
    // Must restore at least one full share;
    vm.startPrank(address(spoke1));
    tokenList.dai.transferFrom(alice, address(hub1), singleShareInAssets);
    hub1.restore({
      assetId: daiAssetId,
      drawnAmount: singleShareInAssets,
      premiumDelta: ZERO_PREMIUM_DELTA
    });

    vm.expectRevert(abi.encodeWithSelector(IHub.DrawCapExceeded.selector, drawCap));
    hub1.draw({assetId: daiAssetId, amount: 1, to: bob});
    vm.stopPrank();
  }

  function test_draw_revertsWith_DrawCapExceeded_due_to_deficit() public {
    uint40 drawCap = 100;
    updateDrawCap(hub1, daiAssetId, address(spoke1), drawCap);

    uint256 amount = drawCap * 10 ** tokenList.dai.decimals();

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: alice,
      addSpoke: address(spoke1),
      addAmount: amount + 1,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: amount,
      skipTime: 0
    });

    vm.prank(address(spoke1));
    hub1.reportDeficit(daiAssetId, amount, ZERO_PREMIUM_DELTA);

    vm.expectRevert(abi.encodeWithSelector(IHub.DrawCapExceeded.selector, drawCap));
    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: 1,
      to: address(spoke1)
    });
  }

  /// Tests that the draw cap is checked against spoke's debt, not the hub's debt
  function test_draw_DifferentSpokes() public {
    uint40 drawCap = 100;
    uint256 daiAmount = drawCap * 10 ** tokenList.dai.decimals();
    uint256 drawAmount = daiAmount;

    updateDrawCap(hub1, daiAssetId, address(spoke1), drawCap);
    updateDrawCap(hub1, daiAssetId, address(spoke2), drawCap);

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke2),
      addAmount: daiAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: drawAmount,
      skipTime: 365 days
    });

    // restore to provide liquidity
    // Must repay at least one full share
    vm.startPrank(address(spoke1));
    tokenList.dai.transferFrom(alice, address(hub1), minimumAssetsPerDrawnShare(hub1, daiAssetId));
    hub1.restore({
      assetId: daiAssetId,
      drawnAmount: minimumAssetsPerDrawnShare(hub1, daiAssetId),
      premiumDelta: ZERO_PREMIUM_DELTA
    });
    vm.stopPrank();

    (uint256 drawn, ) = hub1.getAssetOwed(daiAssetId);
    assertGt(drawn, drawCap);

    vm.expectRevert(abi.encodeWithSelector(IHub.DrawCapExceeded.selector, drawCap));
    vm.prank(address(spoke1));
    hub1.draw({assetId: daiAssetId, amount: 1, to: bob});

    vm.prank(address(spoke2));
    hub1.draw({assetId: daiAssetId, amount: 1, to: bob});
  }

  function test_draw_fuzz_revertsWith_DrawCapExceeded(uint40 drawCap) public {
    drawCap = bound(drawCap, 1, MAX_SUPPLY_AMOUNT / 10 ** tokenList.dai.decimals()).toUint40();
    uint256 daiAmount = drawCap * 10 ** tokenList.dai.decimals();
    uint256 drawAmount = daiAmount + 1;

    updateDrawCap(hub1, daiAssetId, address(spoke1), drawCap);

    vm.expectRevert(abi.encodeWithSelector(IHub.DrawCapExceeded.selector, drawCap));
    vm.prank(address(spoke1));
    hub1.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_fuzz_revertsWith_InvalidAddress(uint256 daiAmount) public {
    vm.expectRevert(IHub.InvalidAddress.selector);
    vm.prank(address(spoke1));
    hub1.draw({assetId: daiAssetId, amount: daiAmount, to: address(hub1)});
  }
}
