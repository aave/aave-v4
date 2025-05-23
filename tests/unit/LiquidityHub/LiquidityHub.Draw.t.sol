// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract LiquidityHubDrawTest is LiquidityHubBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  function test_draw_same_block() public {
    uint256 daiAmount = 100e18;
    uint256 drawAmount = daiAmount;

    // hub
    (uint256 baseDebt, uint256 premiumDebt) = hub.getAssetDebt(daiAssetId);
    assertEq(hub.getAssetTotalDebt(daiAssetId), 0);
    assertEq(baseDebt, 0);
    assertEq(premiumDebt, 0);
    assertEq(hub.getAvailableLiquidity(daiAssetId), 0);
    assertEq(hub.getAsset(daiAssetId).lastUpdateTimestamp, vm.getBlockTimestamp());
    // spoke
    (baseDebt, premiumDebt) = hub.getSpokeDebt(daiAssetId, address(spoke1));
    assertEq(hub.getSpokeTotalDebt(daiAssetId, address(spoke1)), 0);
    assertEq(baseDebt, 0);
    assertEq(premiumDebt, 0);

    // spoke2, bob supply dai
    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      user: bob,
      to: address(spoke2)
    });

    // spoke1 draw all dai reserve liquidity
    vm.expectEmit(address(hub));
    emit ILiquidityHub.Draw(daiAssetId, address(spoke1), drawAmount, drawAmount);
    vm.prank(address(spoke1));
    hub.draw({assetId: daiAssetId, amount: drawAmount, to: alice});

    // hub
    (baseDebt, premiumDebt) = hub.getAssetDebt(daiAssetId);
    assertEq(hub.getAssetTotalDebt(daiAssetId), drawAmount, 'asset totalDebt after');
    assertEq(baseDebt, drawAmount, 'asset baseDebt after');
    assertEq(premiumDebt, 0, 'asset premiumDebt after');
    assertEq(hub.getAvailableLiquidity(daiAssetId), 0, 'asset availableLiquidity after');
    assertEq(
      hub.getAsset(daiAssetId).lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'asset lastUpdateTimestamp after'
    );
    // spoke
    (baseDebt, premiumDebt) = hub.getSpokeDebt(daiAssetId, address(spoke1));
    assertEq(
      hub.getSpokeTotalDebt(daiAssetId, address(spoke1)),
      drawAmount,
      'spoke totalDebt after'
    );
    assertEq(baseDebt, drawAmount, 'spoke baseDebt after');
    assertEq(premiumDebt, 0, 'spoke premiumDebt after');
    // dai balance
    assertEq(
      tokenList.dai.balanceOf(alice),
      drawAmount + MAX_SUPPLY_AMOUNT,
      'alice dai final balance'
    );
    assertEq(tokenList.dai.balanceOf(bob), MAX_SUPPLY_AMOUNT - daiAmount, 'bob dai final balance');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke1 dai final balance');
    assertEq(tokenList.dai.balanceOf(address(spoke2)), 0, 'spoke2 dai final balance');
  }

  function test_draw_fuzz_amounts_same_block(uint256 assetId, uint256 daiAmount) public {
    assetId = bound(assetId, 0, hub.assetCount() - 2); // Exclude duplicated DAI
    daiAmount = bound(daiAmount, 1, MAX_SUPPLY_AMOUNT);
    uint256 drawAmount = daiAmount;

    IERC20 asset = hub.assetsList(assetId);

    // spoke2, bob supply dai
    Utils.add({
      hub: hub,
      assetId: assetId,
      spoke: address(spoke2),
      amount: daiAmount,
      user: bob,
      to: address(spoke2)
    });

    // spoke1 draw all dai reserve liquidity
    vm.expectEmit(address(hub));
    emit ILiquidityHub.Draw(assetId, address(spoke1), drawAmount, drawAmount);
    vm.prank(address(spoke1));
    hub.draw({assetId: assetId, amount: drawAmount, to: alice});

    // hub
    (uint256 baseDebt, uint256 premiumDebt) = hub.getAssetDebt(assetId);
    assertEq(hub.getAssetTotalDebt(assetId), drawAmount, 'asset totalDebt after');
    assertEq(baseDebt, drawAmount, 'asset baseDebt after');
    assertEq(premiumDebt, 0, 'asset premiumDebt after');
    assertEq(hub.getAvailableLiquidity(assetId), 0, 'asset availableLiquidity after');
    assertEq(
      hub.getAsset(assetId).lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'asset lastUpdateTimestamp after'
    );
    // spoke
    (baseDebt, premiumDebt) = hub.getSpokeDebt(assetId, address(spoke1));
    assertEq(hub.getSpokeTotalDebt(assetId, address(spoke1)), drawAmount, 'spoke totalDebt after');
    assertEq(baseDebt, drawAmount, 'spoke baseDebt after');
    assertEq(premiumDebt, 0, 'spoke premiumDebt after');
    // token balance
    assertEq(asset.balanceOf(alice), drawAmount + MAX_SUPPLY_AMOUNT, 'alice asset final balance');
    assertEq(asset.balanceOf(bob), MAX_SUPPLY_AMOUNT - daiAmount, 'bob asset final balance');
    assertEq(asset.balanceOf(address(spoke1)), 0, 'spoke1 asset final balance');
    assertEq(asset.balanceOf(address(spoke2)), 0, 'spoke2 asset final balance');
  }

  function test_draw_revertsWith_AssetNotActive() public {
    uint256 drawAmount = 1;
    updateAssetActive(hub, daiAssetId, false);

    assertFalse(hub.getAsset(daiAssetId).config.active);

    vm.expectRevert(ILiquidityHub.AssetNotActive.selector);
    vm.prank(address(spoke1));
    hub.draw(daiAssetId, drawAmount, address(spoke1));
  }

  function test_draw_fuzz_revertsWith_AssetNotActive(uint256 assetId, uint256 drawAmount) public {
    drawAmount = bound(drawAmount, 1, MAX_SUPPLY_AMOUNT);
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    updateAssetActive(hub, assetId, false);

    assertFalse(hub.getAsset(assetId).config.active);

    vm.expectRevert(ILiquidityHub.AssetNotActive.selector);
    vm.prank(address(spoke1));
    hub.draw(assetId, drawAmount, address(spoke1));
  }

  function test_draw_revertsWith_AssetPaused() public {
    uint256 drawAmount = 1;
    updateAssetPaused(hub, daiAssetId, true);

    assertTrue(hub.getAsset(daiAssetId).config.paused);

    vm.expectRevert(ILiquidityHub.AssetPaused.selector);
    vm.prank(address(spoke1));
    hub.draw(daiAssetId, drawAmount, address(spoke1));
  }

  function test_draw_fuzz_revertsWith_AssetPaused(uint256 assetId, uint256 drawAmount) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    drawAmount = bound(drawAmount, 1, MAX_SUPPLY_AMOUNT);
    updateAssetPaused(hub, assetId, true);

    assertTrue(hub.getAsset(assetId).config.paused);

    vm.expectRevert(ILiquidityHub.AssetPaused.selector);
    vm.prank(address(spoke1));
    hub.draw(assetId, drawAmount, address(spoke1));
  }

  function test_draw_revertsWith_AssetFrozen() public {
    uint256 drawAmount = 1;
    updateAssetFrozen(hub, daiAssetId, true);

    assertTrue(hub.getAsset(daiAssetId).config.frozen);

    vm.expectRevert(ILiquidityHub.AssetFrozen.selector);
    vm.prank(address(spoke1));
    hub.draw(daiAssetId, drawAmount, address(spoke1));
  }

  function test_draw_fuzz_revertsWith_AssetFrozen(uint256 assetId, uint256 drawAmount) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    drawAmount = bound(drawAmount, 1, MAX_SUPPLY_AMOUNT);
    updateAssetFrozen(hub, assetId, true);

    assertTrue(hub.getAsset(assetId).config.frozen);

    vm.expectRevert(ILiquidityHub.AssetFrozen.selector);
    vm.prank(address(spoke1));
    hub.draw(assetId, drawAmount, address(spoke1));
  }

  function test_draw_revertsWith_NotAvailableLiquidity() public {
    uint256 drawAmount = 1;

    assertTrue(hub.getAvailableLiquidity(daiAssetId) == 0);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.NotAvailableLiquidity.selector, 0));
    vm.prank(address(spoke1));
    hub.draw(daiAssetId, drawAmount, address(spoke1));
  }

  function test_draw_fuzz_revertsWith_NotAvailableLiquidity(
    uint256 assetId,
    uint256 drawAmount
  ) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    drawAmount = bound(drawAmount, 1, MAX_SUPPLY_AMOUNT);

    assertTrue(hub.getAvailableLiquidity(assetId) == 0);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.NotAvailableLiquidity.selector, 0));
    vm.prank(address(spoke2));
    hub.draw(assetId, drawAmount, address(spoke2));
  }

  function test_draw_revertsWith_NotAvailableLiquidity_due_to_remove() public {
    uint256 daiAmount = 100e18;

    // spoke2, bob supply dai
    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      user: bob,
      to: address(spoke2)
    });
    // withdraw all so no liquidity remains
    Utils.remove({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      to: bob
    });

    assertTrue(hub.getAvailableLiquidity(daiAssetId) == 0);

    uint256 drawAmount = 1;

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.NotAvailableLiquidity.selector, 0));
    vm.prank(address(spoke1));
    hub.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_fuzz_revertsWith_NotAvailableLiquidity_due_to_remove(
    uint256 daiAmount
  ) public {
    daiAmount = bound(daiAmount, 1, MAX_SUPPLY_AMOUNT);

    // spoke2, bob supply dai
    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      user: bob,
      to: address(spoke2)
    });
    // withdraw all so no liquidity remains
    Utils.remove({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      to: bob
    });

    assertTrue(hub.getAvailableLiquidity(daiAssetId) == 0);

    uint256 drawAmount = 1;

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.NotAvailableLiquidity.selector, 0));
    vm.prank(address(spoke1));
    hub.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_revertsWith_NotAvailableLiquidity_due_to_draw() public {
    uint256 daiAmount = 100e18;

    // spoke2, bob supply dai
    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      user: bob,
      to: address(spoke2)
    });
    // draw all so no liquidity remains
    Utils.draw({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      to: bob,
      onBehalfOf: bob
    });

    assertTrue(hub.getAvailableLiquidity(daiAssetId) == 0);

    uint256 drawAmount = 1;

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.NotAvailableLiquidity.selector, 0));
    vm.prank(address(spoke1));
    hub.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_fuzz_revertsWith_NotAvailableLiquidity_due_to_draw(uint256 daiAmount) public {
    daiAmount = bound(daiAmount, 1, MAX_SUPPLY_AMOUNT);

    // spoke2, bob supply dai
    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      user: bob,
      to: address(spoke2)
    });
    // draw all so no liquidity remains
    Utils.draw({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      to: bob,
      onBehalfOf: bob
    });

    assertTrue(hub.getAvailableLiquidity(daiAssetId) == 0);

    uint256 drawAmount = 1;

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.NotAvailableLiquidity.selector, 0));
    vm.prank(address(spoke1));
    hub.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_revertsWith_InvalidDrawAmount() public {
    uint256 drawAmount = 0;

    vm.expectRevert(ILiquidityHub.InvalidDrawAmount.selector);
    vm.prank(address(spoke1));
    hub.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_revertsWith_DrawCapExceeded_due_to_interest() public {
    // Set liquidity premium of dai to 0
    updateLiquidityPremium(spoke1, _daiReserveId(spoke1), 0);
    assertEq(spoke1.getLiquidityPremium(_daiReserveId(spoke1)), 0);

    uint256 daiAmount = 100e18;
    uint256 drawCap = daiAmount;
    uint256 drawAmount = drawCap;

    updateDrawCap(hub, daiAssetId, address(spoke1), drawCap);

    _supplyAndDrawLiquidity({
      assetId: daiAssetId,
      supplyUser: bob,
      supplySpoke: address(spoke2),
      supplyAmount: daiAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: drawAmount,
      skipTime: 365 days
    });

    (uint256 baseDebt, ) = hub.getAssetDebt(daiAssetId);
    assertGt(baseDebt, drawCap);

    // restore to provide liquidity
    // Must repay at least one full share
    vm.startPrank(address(spoke1));
    hub.restore({
      assetId: daiAssetId,
      baseAmount: minimumAssetsPerDrawnShare(daiAssetId),
      premiumAmount: 0,
      from: alice
    });

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.DrawCapExceeded.selector, drawCap));
    hub.draw({assetId: daiAssetId, amount: 1, to: bob});
    vm.stopPrank();
  }

  function test_draw_fuzz_revertsWith_DrawCapExceeded_due_to_interest(
    uint256 daiAmount,
    uint256 rate,
    uint256 skipTime
  ) public {
    daiAmount = bound(daiAmount, 1, MAX_SUPPLY_AMOUNT);
    rate = bound(rate, 1, MAX_BORROW_RATE).bpsToRay();
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    uint256 drawCap = daiAmount;
    uint256 drawAmount = drawCap;

    updateDrawCap(hub, daiAssetId, address(spoke1), drawCap);

    _mockRate(rate);
    _supplyAndDrawLiquidity({
      assetId: daiAssetId,
      supplyUser: bob,
      supplySpoke: address(spoke2),
      supplyAmount: daiAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: daiAmount,
      skipTime: skipTime
    });

    (uint256 baseDebt, ) = hub.getAssetDebt(daiAssetId);
    uint256 singleShareInAssets = minimumAssetsPerDrawnShare(daiAssetId);
    // Need the baseDebt to be greater than the drawCap from interest, past the share we restore
    vm.assume(baseDebt > drawCap + singleShareInAssets);

    // restore to provide liquidity
    // Must repay at least one full share;
    vm.startPrank(address(spoke1));
    hub.restore({
      assetId: daiAssetId,
      baseAmount: singleShareInAssets,
      premiumAmount: 0,
      from: alice
    });

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.DrawCapExceeded.selector, drawCap));
    hub.draw({assetId: daiAssetId, amount: 1, to: bob});
    vm.stopPrank();
  }

  function test_draw_revertsWith_DrawCapExceeded() public {
    uint256 daiAmount = 100e18;
    uint256 drawCap = daiAmount;
    uint256 drawAmount = drawCap + 1;

    updateDrawCap(hub, daiAssetId, address(spoke1), drawCap);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.DrawCapExceeded.selector, drawCap));
    vm.prank(address(spoke1));
    hub.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }

  function test_draw_fuzz_revertsWith_DrawCapExceeded(uint256 daiAmount) public {
    daiAmount = bound(daiAmount, 1, MAX_SUPPLY_AMOUNT);
    uint256 drawCap = daiAmount;
    uint256 drawAmount = drawCap + 1;

    updateDrawCap(hub, daiAssetId, address(spoke1), drawCap);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.DrawCapExceeded.selector, drawCap));
    vm.prank(address(spoke1));
    hub.draw({assetId: daiAssetId, amount: drawAmount, to: address(spoke1)});
  }
}
