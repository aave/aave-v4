// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubDrawTest is HubBase {
  using SharesMath for uint256;

  function test_draw_fuzz_amounts_same_block(uint256 assetId, uint256 amount) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 3); // Exclude duplicated DAI and usdy
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    IERC20 underlying = IERC20(hub1.getAsset(assetId).underlying);

    // spoke2, bob add dai
    Utils.add({hub: hub1, assetId: assetId, caller: address(spoke2), amount: amount, user: bob});

    uint256 shares = hub1.previewDrawByAssets(assetId, amount);

    DataTypes.Asset memory assetBefore = hub1.getAsset(assetId);
    (, uint256 premium) = hub1.getAssetOwed(assetId);
    vm.expectCall(
      address(irStrategy),
      abi.encodeCall(
        IBasicInterestRateStrategy.calculateInterestRate,
        (
          assetId,
          assetBefore.liquidity - amount,
          hub1.convertToDrawnAssets(assetId, assetBefore.drawnShares + shares),
          premium
        )
      )
    );

    vm.expectEmit(address(hub1));
    emit IHub.AssetUpdated(
      assetId,
      hub1.getAssetDrawnIndex(assetId),
      IBasicInterestRateStrategy(irStrategy).calculateInterestRate({
        assetId: assetId,
        liquidity: assetBefore.liquidity - amount,
        drawn: hub1.convertToDrawnAssets(assetId, assetBefore.drawnShares + shares),
        premium: premium
      }),
      vm.getBlockTimestamp()
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
    assertEq(hub1.getLiquidity(assetId), 0, 'asset liquidity after');
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
    assertBorrowRateSynced(hub1, assetId, 'hub1.draw');
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
  }

  function test_draw_fuzz_IncreasedBorrowRate(uint256 assetId, uint256 amount) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 3); // Exclude duplicated DAI and usdy
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT / 10);

    _addLiquidity(assetId, amount * 2);
    _drawLiquidity(assetId, amount, true);
    skip(365 days);

    uint256 shares = hub1.previewDrawByAssets(assetId, amount);

    DataTypes.Asset memory assetBefore = hub1.getAsset(assetId);
    (, uint256 premium) = hub1.getAssetOwed(assetId);
    vm.expectCall(
      address(irStrategy),
      abi.encodeCall(
        IBasicInterestRateStrategy.calculateInterestRate,
        (
          assetId,
          assetBefore.liquidity - amount,
          hub1.convertToDrawnAssets(assetId, assetBefore.drawnShares + shares),
          premium
        )
      )
    );

    vm.expectEmit(address(hub1));
    emit IHub.AssetUpdated(
      assetId,
      hub1.getAssetDrawnIndex(assetId),
      IBasicInterestRateStrategy(irStrategy).calculateInterestRate({
        assetId: assetId,
        liquidity: assetBefore.liquidity - amount,
        drawn: hub1.convertToDrawnAssets(assetId, assetBefore.drawnShares + shares),
        premium: premium
      }),
      vm.getBlockTimestamp()
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

    assertBorrowRateSynced(hub1, assetId, 'hub1.draw');
  }

  function test_draw_revertsWith_SpokeNotActive() public {
    updateSpokeActive(hub1, daiAssetId, address(spoke1), false);
    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.draw(daiAssetId, 100e18, alice);
  }

  function test_draw_revertsWith_NotLiquidity() public {
    uint256 drawAmount = 1;

    assertTrue(hub1.getLiquidity(daiAssetId) == 0);

    vm.expectRevert(abi.encodeWithSelector(IHub.NotLiquidity.selector, 0));
    vm.prank(address(spoke1));
    hub1.draw(daiAssetId, drawAmount, address(spoke1));
  }

  function test_draw_fuzz_revertsWith_NotLiquidity(uint256 assetId, uint256 drawAmount) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 3); // Exclude duplicated DAI and usdy
    drawAmount = bound(drawAmount, 1, MAX_SUPPLY_AMOUNT);

    assertTrue(hub1.getLiquidity(assetId) == 0);

    vm.expectRevert(abi.encodeWithSelector(IHub.NotLiquidity.selector, 0));
    vm.prank(address(spoke2));
    hub1.draw(assetId, drawAmount, address(spoke2));
  }

  function test_draw_revertsWith_NotLiquidity_due_to_remove() public {
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

    assertTrue(hub1.getLiquidity(daiAssetId) == 0);

    uint256 drawAmount = 1;

    vm.expectRevert(abi.encodeWithSelector(IHub.NotLiquidity.selector, 0));
    vm.prank(address(spoke1));
    hub1.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_fuzz_revertsWith_NotLiquidity_due_to_remove(uint256 daiAmount) public {
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

    assertTrue(hub1.getLiquidity(daiAssetId) == 0);

    uint256 drawAmount = 1;

    vm.expectRevert(abi.encodeWithSelector(IHub.NotLiquidity.selector, 0));
    vm.prank(address(spoke1));
    hub1.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_revertsWith_NotLiquidity_due_to_draw() public {
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

    assertTrue(hub1.getLiquidity(daiAssetId) == 0);

    uint256 drawAmount = 1;

    vm.expectRevert(abi.encodeWithSelector(IHub.NotLiquidity.selector, 0));
    vm.prank(address(spoke1));
    hub1.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_fuzz_revertsWith_NotLiquidity_due_to_draw(uint256 daiAmount) public {
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

    assertTrue(hub1.getLiquidity(daiAssetId) == 0);

    uint256 drawAmount = 1;

    vm.expectRevert(abi.encodeWithSelector(IHub.NotLiquidity.selector, 0));
    vm.prank(address(spoke1));
    hub1.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_revertsWith_InvalidDrawAmount() public {
    uint256 drawAmount = 0;

    vm.expectRevert(IHub.InvalidDrawAmount.selector);
    vm.prank(address(spoke1));
    hub1.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_revertsWith_DrawCapExceeded_due_to_interest() public {
    // Set collateral risk of dai to 0
    updateCollateralRisk(spoke1, _daiReserveId(spoke1), 0);
    assertEq(_getCollateralRisk(spoke1, _daiReserveId(spoke1)), 0);

    uint256 daiAmount = 100e18;
    uint256 drawCap = daiAmount;
    uint256 drawAmount = drawCap;

    updateDrawCap(hub1, daiAssetId, address(spoke1), drawCap);

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

    (uint256 drawn, ) = hub1.getAssetOwed(daiAssetId);
    assertGt(drawn, drawCap);

    // restore to provide liquidity
    // Must restore at least one full share
    vm.startPrank(address(spoke1));
    hub1.restore({
      assetId: daiAssetId,
      drawnAmount: minimumAssetsPerDrawnShare(daiAssetId),
      premiumAmount: 0,
      premiumDelta: DataTypes.PremiumDelta(0, 0, 0),
      from: alice
    });

    vm.expectRevert(abi.encodeWithSelector(IHub.DrawCapExceeded.selector, drawCap));
    hub1.draw({assetId: daiAssetId, amount: 1, to: bob});
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
    uint256 singleShareInAssets = minimumAssetsPerDrawnShare(daiAssetId);
    // Need the drawn to be greater than the drawCap from interest, past the share we restore
    vm.assume(drawn > drawCap + singleShareInAssets);

    // restore to provide liquidity
    // Must restore at least one full share;
    vm.startPrank(address(spoke1));
    hub1.restore({
      assetId: daiAssetId,
      drawnAmount: singleShareInAssets,
      premiumAmount: 0,
      premiumDelta: DataTypes.PremiumDelta(0, 0, 0),
      from: alice
    });

    vm.expectRevert(abi.encodeWithSelector(IHub.DrawCapExceeded.selector, drawCap));
    hub1.draw({assetId: daiAssetId, amount: 1, to: bob});
    vm.stopPrank();
  }

  /// Tests that the draw cap is checked against spoke's debt, not the hub's debt
  function test_draw_DifferentSpokes() public {
    uint256 daiAmount = 100e18;
    uint256 drawCap = daiAmount;
    uint256 drawAmount = drawCap;

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
    hub1.restore({
      assetId: daiAssetId,
      drawnAmount: minimumAssetsPerDrawnShare(daiAssetId),
      premiumAmount: 0,
      premiumDelta: DataTypes.PremiumDelta(0, 0, 0),
      from: alice
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

  function test_draw_revertsWith_DrawCapExceeded() public {
    uint256 daiAmount = 100e18;
    uint256 drawCap = daiAmount;
    uint256 drawAmount = drawCap + 1;

    updateDrawCap(hub1, daiAssetId, address(spoke1), drawCap);

    vm.expectRevert(abi.encodeWithSelector(IHub.DrawCapExceeded.selector, drawCap));
    vm.prank(address(spoke1));
    hub1.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_fuzz_revertsWith_DrawCapExceeded(uint256 daiAmount) public {
    daiAmount = bound(daiAmount, 1, MAX_SUPPLY_AMOUNT);
    uint256 drawCap = daiAmount;
    uint256 drawAmount = drawCap + 1;

    updateDrawCap(hub1, daiAssetId, address(spoke1), drawCap);

    vm.expectRevert(abi.encodeWithSelector(IHub.DrawCapExceeded.selector, drawCap));
    vm.prank(address(spoke1));
    hub1.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_fuzz_revertsWith_InvalidToAddress(uint256 daiAmount) public {
    vm.expectRevert(IHub.InvalidToAddress.selector);
    vm.prank(address(spoke1));
    hub1.draw({assetId: daiAssetId, amount: daiAmount, to: address(hub1)});
  }
}
