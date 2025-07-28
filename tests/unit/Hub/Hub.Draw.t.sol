// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubDrawTest is HubBase {
  using SharesMath for uint256;

  function test_draw_fuzz_amounts_same_block(uint256 assetId, uint256 amount) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 3); // Exclude duplicated DAI and usdy
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    IERC20 underlying = IERC20(hub.getAsset(assetId).underlying);

    // spoke2, bob add dai
    Utils.add({hub: hub, assetId: assetId, caller: address(spoke2), amount: amount, user: bob});

    uint256 shares = hub.previewDrawByAssets(assetId, amount);

    DataTypes.Asset memory assetBefore = hub.getAsset(assetId);
    (, uint256 premium) = hub.getAssetOwed(assetId);
    vm.expectCall(
      address(irStrategy),
      abi.encodeCall(
        IBasicInterestRateStrategy.calculateInterestRate,
        (
          assetId,
          assetBefore.availableLiquidity - amount,
          hub.convertToDrawnAssets(assetId, assetBefore.baseDrawnShares + shares),
          premium
        )
      )
    );

    vm.expectEmit(address(hub));
    emit IHub.AssetUpdated(
      assetId,
      hub.getAssetDrawnIndex(assetId),
      IBasicInterestRateStrategy(irStrategy).calculateInterestRate({
        assetId: assetId,
        availableLiquidity: assetBefore.availableLiquidity - amount,
        drawn: hub.convertToDrawnAssets(assetId, assetBefore.baseDrawnShares + shares),
        premium: premium
      }),
      vm.getBlockTimestamp()
    );
    vm.expectEmit(address(hub.getAsset(assetId).underlying));
    emit IERC20.Transfer(address(hub), alice, amount);
    vm.expectEmit(address(hub));
    emit IHub.Draw(assetId, address(spoke1), shares, amount);

    vm.prank(address(spoke1));
    hub.draw(assetId, amount, alice);

    // hub
    uint256 drawn;
    (drawn, premium) = hub.getAssetOwed(assetId);
    assertEq(hub.getAssetTotalOwed(assetId), amount, 'asset totalDebt after');
    assertEq(drawn, amount, 'asset drawn after');
    assertEq(premium, 0, 'asset premium after');
    assertEq(hub.getAvailableLiquidity(assetId), 0, 'asset availableLiquidity after');
    assertEq(
      hub.getAsset(assetId).lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'asset lastUpdateTimestamp after'
    );
    assertEq(
      hub.getAsset(assetId).availableLiquidity,
      assetBefore.availableLiquidity - amount,
      'available liquidity after draw'
    );
    assertEq(
      hub.getAsset(assetId).baseDrawnShares,
      assetBefore.baseDrawnShares + shares,
      'baseDrawnShares after draw'
    );
    assertBorrowRateSynced(hub, assetId, 'hub.draw');
    // spoke
    (drawn, premium) = hub.getSpokeOwed(assetId, address(spoke1));
    assertEq(hub.getSpokeTotalOwed(assetId, address(spoke1)), amount, 'spoke totalDebt after');
    assertEq(drawn, amount, 'spoke drawn after');
    assertEq(premium, 0, 'spoke premium after');
    // token balance
    assertEq(underlying.balanceOf(alice), amount + MAX_SUPPLY_AMOUNT, 'alice asset final balance');
    assertEq(underlying.balanceOf(bob), MAX_SUPPLY_AMOUNT - amount, 'bob asset final balance');
    assertEq(underlying.balanceOf(address(spoke1)), 0, 'spoke1 asset final balance');
    assertEq(underlying.balanceOf(address(spoke2)), 0, 'spoke2 asset final balance');
  }

  function test_draw_fuzz_IncreasedBorrowRate(uint256 assetId, uint256 amount) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 3); // Exclude duplicated DAI and usdy
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT / 10);

    _addLiquidity(assetId, amount * 2);
    _drawLiquidity(assetId, amount, true);
    skip(365 days);

    uint256 shares = hub.previewDrawByAssets(assetId, amount);

    DataTypes.Asset memory assetBefore = hub.getAsset(assetId);
    (, uint256 premium) = hub.getAssetOwed(assetId);
    vm.expectCall(
      address(irStrategy),
      abi.encodeCall(
        IBasicInterestRateStrategy.calculateInterestRate,
        (
          assetId,
          assetBefore.availableLiquidity - amount,
          hub.convertToDrawnAssets(assetId, assetBefore.baseDrawnShares + shares),
          premium
        )
      )
    );

    vm.expectEmit(address(hub));
    emit IHub.AssetUpdated(
      assetId,
      hub.getAssetDrawnIndex(assetId),
      IBasicInterestRateStrategy(irStrategy).calculateInterestRate({
        assetId: assetId,
        availableLiquidity: assetBefore.availableLiquidity - amount,
        drawn: hub.convertToDrawnAssets(assetId, assetBefore.baseDrawnShares + shares),
        premium: premium
      }),
      vm.getBlockTimestamp()
    );
    vm.expectEmit(address(hub.getAsset(assetId).underlying));
    emit IERC20.Transfer(address(hub), alice, amount);
    vm.expectEmit(address(hub));
    emit IHub.Draw(assetId, address(spoke1), shares, amount);

    vm.prank(address(spoke1));
    hub.draw(assetId, amount, alice);

    assertEq(
      hub.getAsset(assetId).availableLiquidity,
      assetBefore.availableLiquidity - amount,
      'available liquidity after draw'
    );
    assertEq(
      hub.getAsset(assetId).baseDrawnShares,
      assetBefore.baseDrawnShares + shares,
      'baseDrawnShares after draw'
    );

    assertBorrowRateSynced(hub, assetId, 'hub.draw');
  }

  function test_draw_revertsWith_SpokeNotActive() public {
    updateSpokeActive(hub, daiAssetId, address(spoke1), false);
    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub.draw(daiAssetId, 100e18, alice);
  }

  function test_draw_revertsWith_NotAvailableLiquidity() public {
    uint256 drawAmount = 1;

    assertTrue(hub.getAvailableLiquidity(daiAssetId) == 0);

    vm.expectRevert(abi.encodeWithSelector(IHub.NotAvailableLiquidity.selector, 0));
    vm.prank(address(spoke1));
    hub.draw(daiAssetId, drawAmount, address(spoke1));
  }

  function test_draw_fuzz_revertsWith_NotAvailableLiquidity(
    uint256 assetId,
    uint256 drawAmount
  ) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 3); // Exclude duplicated DAI and usdy
    drawAmount = bound(drawAmount, 1, MAX_SUPPLY_AMOUNT);

    assertTrue(hub.getAvailableLiquidity(assetId) == 0);

    vm.expectRevert(abi.encodeWithSelector(IHub.NotAvailableLiquidity.selector, 0));
    vm.prank(address(spoke2));
    hub.draw(assetId, drawAmount, address(spoke2));
  }

  function test_draw_revertsWith_NotAvailableLiquidity_due_to_remove() public {
    uint256 daiAmount = 100e18;

    // spoke2, bob add dai
    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: daiAmount,
      user: bob
    });
    // remove all so no liquidity remains
    Utils.remove({
      hub: hub,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: daiAmount,
      to: bob
    });

    assertTrue(hub.getAvailableLiquidity(daiAssetId) == 0);

    uint256 drawAmount = 1;

    vm.expectRevert(abi.encodeWithSelector(IHub.NotAvailableLiquidity.selector, 0));
    vm.prank(address(spoke1));
    hub.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_fuzz_revertsWith_NotAvailableLiquidity_due_to_remove(
    uint256 daiAmount
  ) public {
    daiAmount = bound(daiAmount, 1, MAX_SUPPLY_AMOUNT);

    // spoke2, bob add dai
    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: daiAmount,
      user: bob
    });
    // remove all so no liquidity remains
    Utils.remove({
      hub: hub,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: daiAmount,
      to: bob
    });

    assertTrue(hub.getAvailableLiquidity(daiAssetId) == 0);

    uint256 drawAmount = 1;

    vm.expectRevert(abi.encodeWithSelector(IHub.NotAvailableLiquidity.selector, 0));
    vm.prank(address(spoke1));
    hub.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_revertsWith_NotAvailableLiquidity_due_to_draw() public {
    uint256 daiAmount = 100e18;

    // spoke2, bob add dai
    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: daiAmount,
      user: bob
    });
    // draw all so no liquidity remains
    Utils.draw({
      hub: hub,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: daiAmount,
      to: bob
    });

    assertTrue(hub.getAvailableLiquidity(daiAssetId) == 0);

    uint256 drawAmount = 1;

    vm.expectRevert(abi.encodeWithSelector(IHub.NotAvailableLiquidity.selector, 0));
    vm.prank(address(spoke1));
    hub.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_fuzz_revertsWith_NotAvailableLiquidity_due_to_draw(uint256 daiAmount) public {
    daiAmount = bound(daiAmount, 1, MAX_SUPPLY_AMOUNT);

    // spoke2, bob add dai
    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: daiAmount,
      user: bob
    });
    // draw all so no liquidity remains
    Utils.draw({
      hub: hub,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: daiAmount,
      to: bob
    });

    assertTrue(hub.getAvailableLiquidity(daiAssetId) == 0);

    uint256 drawAmount = 1;

    vm.expectRevert(abi.encodeWithSelector(IHub.NotAvailableLiquidity.selector, 0));
    vm.prank(address(spoke1));
    hub.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_revertsWith_InvalidDrawAmount() public {
    uint256 drawAmount = 0;

    vm.expectRevert(IHub.InvalidDrawAmount.selector);
    vm.prank(address(spoke1));
    hub.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_revertsWith_DrawCapExceeded_due_to_interest() public {
    // Set collateral risk of dai to 0
    updateCollateralRisk(spoke1, _daiReserveId(spoke1), 0);
    assertEq(_getCollateralRisk(spoke1, _daiReserveId(spoke1)), 0);

    uint256 daiAmount = 100e18;
    uint256 drawCap = daiAmount;
    uint256 drawAmount = drawCap;

    updateDrawCap(hub, daiAssetId, address(spoke1), drawCap);

    _addAndDrawLiquidity({
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke2),
      addAmount: daiAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: drawAmount,
      skipTime: 365 days
    });

    (uint256 drawn, ) = hub.getAssetOwed(daiAssetId);
    assertGt(drawn, drawCap);

    // restore to provide liquidity
    // Must restore at least one full share
    vm.startPrank(address(spoke1));
    hub.restore({
      assetId: daiAssetId,
      baseAmount: minimumAssetsPerDrawnShare(daiAssetId),
      premiumAmount: 0,
      from: alice
    });

    vm.expectRevert(abi.encodeWithSelector(IHub.DrawCapExceeded.selector, drawCap));
    hub.draw({assetId: daiAssetId, amount: 1, to: bob});
    vm.stopPrank();
  }

  function test_draw_fuzz_revertsWith_DrawCapExceeded_due_to_interest(
    uint256 daiAmount,
    uint256 rate,
    uint256 skipTime
  ) public {
    daiAmount = bound(daiAmount, 1, MAX_SUPPLY_AMOUNT);
    rate = bound(rate, 1, MAX_BORROW_RATE);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    uint256 drawCap = daiAmount;
    uint256 drawAmount = drawCap;

    updateDrawCap(hub, daiAssetId, address(spoke1), drawCap);

    _mockInterestRateBps(rate);
    _addAndDrawLiquidity({
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke2),
      addAmount: daiAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: daiAmount,
      skipTime: skipTime
    });

    (uint256 drawn, ) = hub.getAssetOwed(daiAssetId);
    uint256 singleShareInAssets = minimumAssetsPerDrawnShare(daiAssetId);
    // Need the drawn to be greater than the drawCap from interest, past the share we restore
    vm.assume(drawn > drawCap + singleShareInAssets);

    // restore to provide liquidity
    // Must restore at least one full share;
    vm.startPrank(address(spoke1));
    hub.restore({
      assetId: daiAssetId,
      baseAmount: singleShareInAssets,
      premiumAmount: 0,
      from: alice
    });

    vm.expectRevert(abi.encodeWithSelector(IHub.DrawCapExceeded.selector, drawCap));
    hub.draw({assetId: daiAssetId, amount: 1, to: bob});
    vm.stopPrank();
  }

  /// Tests that the draw cap is checked against spoke's debt, not the hub's debt
  function test_draw_DifferentSpokes() public {
    uint256 daiAmount = 100e18;
    uint256 drawCap = daiAmount;
    uint256 drawAmount = drawCap;

    updateDrawCap(hub, daiAssetId, address(spoke1), drawCap);
    updateDrawCap(hub, daiAssetId, address(spoke2), drawCap);

    _addAndDrawLiquidity({
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
    hub.restore({
      assetId: daiAssetId,
      baseAmount: minimumAssetsPerDrawnShare(daiAssetId),
      premiumAmount: 0,
      from: alice
    });
    vm.stopPrank();

    (uint256 drawn, ) = hub.getAssetOwed(daiAssetId);
    assertGt(drawn, drawCap);

    vm.expectRevert(abi.encodeWithSelector(IHub.DrawCapExceeded.selector, drawCap));
    vm.prank(address(spoke1));
    hub.draw({assetId: daiAssetId, amount: 1, to: bob});

    vm.prank(address(spoke2));
    hub.draw({assetId: daiAssetId, amount: 1, to: bob});
  }

  function test_draw_revertsWith_DrawCapExceeded() public {
    uint256 daiAmount = 100e18;
    uint256 drawCap = daiAmount;
    uint256 drawAmount = drawCap + 1;

    updateDrawCap(hub, daiAssetId, address(spoke1), drawCap);

    vm.expectRevert(abi.encodeWithSelector(IHub.DrawCapExceeded.selector, drawCap));
    vm.prank(address(spoke1));
    hub.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_fuzz_revertsWith_DrawCapExceeded(uint256 daiAmount) public {
    daiAmount = bound(daiAmount, 1, MAX_SUPPLY_AMOUNT);
    uint256 drawCap = daiAmount;
    uint256 drawAmount = drawCap + 1;

    updateDrawCap(hub, daiAssetId, address(spoke1), drawCap);

    vm.expectRevert(abi.encodeWithSelector(IHub.DrawCapExceeded.selector, drawCap));
    vm.prank(address(spoke1));
    hub.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_fuzz_revertsWith_InvalidToAddress(uint256 daiAmount) public {
    vm.expectRevert(IHub.InvalidToAddress.selector);
    vm.prank(address(spoke1));
    hub.draw({assetId: daiAssetId, amount: daiAmount, to: address(hub)});
  }
}
