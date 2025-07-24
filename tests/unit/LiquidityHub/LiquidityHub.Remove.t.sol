// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract LiquidityHubRemoveTest is LiquidityHubBase {
  using WadRayMathExtended for uint256;

  function test_remove() public {
    uint256 amount = 100e18;
    uint256 reserveId = _daiReserveId(spoke1);

    test_remove_fuzz(reserveId, amount);
  }

  function test_remove_fuzz(uint256 reserveId, uint256 amount) public {
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    uint256 assetId = spoke1.getReserve(reserveId).assetId;
    IERC20 underlying = IERC20(hub.getAsset(assetId).underlying);

    Utils.add({hub: hub, assetId: assetId, caller: address(spoke1), amount: amount, user: alice});

    vm.expectEmit(address(underlying));
    emit IERC20.Transfer(address(hub), alice, amount);
    vm.expectEmit(address(hub));
    emit ILiquidityHub.Remove(
      assetId,
      address(spoke1),
      hub.convertToAddedSharesUp(assetId, amount),
      amount
    );

    vm.prank(address(spoke1));
    hub.remove(assetId, amount, alice);

    AssetPosition memory assetData = getAssetPosition(hub, assetId);
    SpokePosition memory spokeData = getSpokePosition(spoke1, reserveId);

    // hub
    assertEq(assetData.addedAmount, 0, 'asset added amount after');
    assertEq(assetData.addedShares, 0, 'asset added shares after');
    assertEq(assetData.availableLiquidity, 0, 'asset availableLiquidity after');
    assertEq(assetData.drawn, 0, 'asset drawn after');
    assertEq(assetData.premium, 0, 'asset premium after');
    assertEq(assetData.baseDrawnIndex, WadRayMathExtended.RAY, 'asset baseBorrowIndex after');
    assertEq(assetData.baseDrawnRate, uint256(5_00).bpsToRay(), 'asset baseDrawnRate after');
    assertEq(
      assetData.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'asset lastUpdateTimestamp after'
    );
    // spoke
    assertEq(spokeData, assetData);
    // dai
    assertEq(underlying.balanceOf(address(spoke1)), 0, 'spoke token balance after');
    assertEq(underlying.balanceOf(address(hub)), 0, 'hub token balance after');
    assertEq(underlying.balanceOf(alice), MAX_SUPPLY_AMOUNT, 'user token balance after');
  }

  // single asset, multiple spokes added. No debt
  function test_remove_fuzz_multi_spoke(uint256 amount, uint256 amount2) public {
    uint256 assetId = daiAssetId;
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT - 1);
    amount2 = bound(amount2, 1, MAX_SUPPLY_AMOUNT - amount);

    IERC20 underlying = IERC20(hub.getAsset(assetId).underlying);

    Utils.add({hub: hub, assetId: assetId, caller: address(spoke1), amount: amount, user: alice});
    Utils.add({hub: hub, assetId: assetId, caller: address(spoke2), amount: amount2, user: alice});

    Utils.remove(hub, assetId, address(spoke1), amount, alice);
    Utils.remove(hub, assetId, address(spoke2), amount2, alice);

    AssetPosition memory assetData = getAssetPosition(hub, assetId);
    SpokePosition memory spokePosition1 = getSpokePosition(spoke1, _daiReserveId);
    SpokePosition memory spokePosition2 = getSpokePosition(spoke2, _daiReserveId);

    // asset
    assertEq(assetData.addedAmount, 0, 'asset addedAmount after');
    assertEq(assetData.addedShares, 0, 'asset addedShares after');
    assertEq(assetData.availableLiquidity, 0, 'asset availableLiquidity after');
    assertEq(
      assetData.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'asset lastUpdateTimestamp after'
    );
    // spoke 1
    assertEq(spokePosition1.addedAmount, 0, 'spoke1 addedAmount after');
    assertEq(spokePosition1.addedShares, 0, 'spoke1 addedShares after');
    // spoke 2
    assertEq(spokePosition1, spokePosition2);
    // asset
    assertEq(underlying.balanceOf(address(spoke1)), 0, 'spoke1 token balance after');
    assertEq(underlying.balanceOf(address(spoke2)), 0, 'spoke2 token balance after');
    assertEq(underlying.balanceOf(address(hub)), 0, 'hub token balance after');
    assertEq(underlying.balanceOf(alice), MAX_SUPPLY_AMOUNT, 'user token balance after');
  }

  /// @dev single asset, multiple spokes added, with interest accrued.
  function test_remove_fuzz_multi_spoke_with_interest(
    uint256 amount,
    uint256 amount2,
    uint256 drawAmount,
    uint256 skipTime
  ) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT / 10 - 1);
    amount2 = bound(amount2, 1, MAX_SUPPLY_AMOUNT / 10 - amount);
    drawAmount = bound(drawAmount, 1, amount + amount2);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    uint256 assetId = daiAssetId;
    IERC20 underlying = IERC20(hub.getAsset(assetId).underlying);

    Utils.add({hub: hub, assetId: assetId, caller: address(spoke1), amount: amount, user: alice});
    Utils.add({hub: hub, assetId: assetId, caller: address(spoke2), amount: amount2, user: alice});

    // draw liquidity to accrue interest using spoke3
    Utils.draw({hub: hub, assetId: assetId, caller: address(spoke3), amount: drawAmount, to: bob});
    skip(skipTime);

    (uint256 drawn, uint256 premium) = hub.getAssetOwed(assetId);
    vm.assume(drawn + premium <= MAX_SUPPLY_AMOUNT);

    // restore all drawn liquidity
    Utils.restore({
      hub: hub,
      assetId: assetId,
      caller: address(spoke3),
      baseAmount: drawn,
      premiumAmount: premium,
      restorer: bob
    });

    uint256 aliceBalanceBefore = underlying.balanceOf(alice);
    uint256 spoke1Amount = hub.getSpokeAddedAmount(assetId, address(spoke1));
    Utils.remove(hub, assetId, address(spoke1), spoke1Amount, alice);

    uint256 spoke2Amount = hub.getSpokeAddedAmount(assetId, address(spoke2));
    Utils.remove(hub, assetId, address(spoke2), spoke2Amount, alice);

    AssetPosition memory assetData = getAssetPosition(hub, assetId);
    SpokePosition memory spokePosition1 = getSpokePosition(spoke1, _daiReserveId);
    SpokePosition memory spokePosition2 = getSpokePosition(spoke2, _daiReserveId);

    address feeReceiver = _getFeeReceiver(assetId);

    // asset
    // only remaining added amount are fees
    assertEq(
      assetData.addedAmount,
      hub.getSpokeAddedAmount(assetId, feeReceiver),
      'asset addedAmount after'
    );
    assertEq(
      assetData.addedShares,
      hub.getSpokeAddedShares(assetId, feeReceiver),
      'asset addedShares after'
    );
    assertEq(
      assetData.availableLiquidity,
      hub.getSpokeAddedAmount(assetId, feeReceiver),
      'asset availableLiquidity after'
    );
    assertEq(
      assetData.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'asset lastUpdateTimestamp after'
    );
    // spoke 1
    assertEq(spokePosition1.addedAmount, 0, 'spoke1 addedAmount after');
    assertEq(spokePosition1.addedShares, 0, 'spoke1 addedShares after');
    // spoke 2
    assertEq(spokePosition1, spokePosition2);
    // underlying
    assertEq(underlying.balanceOf(address(spoke1)), 0, 'spoke1 token balance after');
    assertEq(underlying.balanceOf(address(spoke2)), 0, 'spoke2 token balance after');
    assertEq(
      underlying.balanceOf(address(hub)),
      assetData.availableLiquidity,
      'hub token balance after'
    );
    assertApproxEqAbs(
      underlying.balanceOf(alice),
      aliceBalanceBefore + spoke1Amount + spoke2Amount,
      1,
      'alice token balance after'
    );
  }

  function test_remove_all_with_interest() public {
    uint256 addAmount = 100e18;
    uint256 initialAvailableLiquidity = hub.getAsset(daiAssetId).availableLiquidity;

    // add and draw dai liquidity to accrue interest
    // add from spoke2, draw from spoke1
    _addAndDrawLiquidity({
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke2),
      addAmount: addAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: addAmount,
      skipTime: 365 days
    });

    (uint256 drawnRestored, uint256 premiumRestored) = hub.getSpokeOwed(
      daiAssetId,
      address(spoke1)
    );

    // alice restores all debt including accrual for spoke1
    Utils.restore({
      hub: hub,
      assetId: daiAssetId,
      caller: address(spoke1),
      baseAmount: drawnRestored,
      premiumAmount: premiumRestored,
      restorer: alice
    });

    AssetPosition memory asset = getAssetPosition(hub, daiAssetId);
    assertEq(
      asset.availableLiquidity,
      initialAvailableLiquidity + drawnRestored + premiumRestored,
      'dai availableLiquidity'
    );

    // reset available liquidity variable
    initialAvailableLiquidity = hub.getAsset(daiAssetId).availableLiquidity;

    uint256 removeAmount = hub.getSpokeAddedAmount(daiAssetId, address(spoke2));
    uint256 daiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 feeAmount = hub.getSpokeAddedAmount(
      daiAssetId,
      hub.getAssetConfig(daiAssetId).feeReceiver
    );
    uint256 feeShares = hub.getSpokeAddedShares(
      daiAssetId,
      hub.getAssetConfig(daiAssetId).feeReceiver
    );

    // removable amount should exceed initial added amount due to accrued interest
    assertTrue(removeAmount > addAmount);

    // bob removes all possible liquidity
    // some has gone to feeReceiver
    vm.prank(address(spoke2));
    hub.remove(daiAssetId, removeAmount, bob);

    SpokePosition memory spokePosition1 = getSpokePosition(spoke1, _daiReserveId);
    SpokePosition memory spokePosition2 = getSpokePosition(spoke2, _daiReserveId);
    asset = getAssetPosition(hub, daiAssetId);

    // hub
    assertApproxEqAbs(asset.addedAmount, feeAmount, 1, 'asset addedAmount');
    assertEq(asset.addedShares, feeShares, 'asset addedShares');
    assertApproxEqAbs(
      asset.availableLiquidity,
      initialAvailableLiquidity - removeAmount,
      1,
      'dai availableLiquidity'
    );
    assertEq(asset.drawn, 0, 'dai drawn');
    assertEq(asset.premium, 0, 'dai premium');
    assertEq(asset.lastUpdateTimestamp, vm.getBlockTimestamp(), 'dai lastUpdateTimestamp');
    // spoke1
    assertEq(spokePosition1.addedShares, 0, 'spoke1 addedShares');
    assertEq(spokePosition1.addedAmount, 0, 'spoke1 addedAmount');
    assertEq(spokePosition1.drawn, 0, 'spoke1 drawn');
    assertEq(spokePosition1.premium, 0, 'spoke1 premium');
    // spoke2
    assertEq(spokePosition1, spokePosition2);
    // dai
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke1 dai balance');
    assertEq(tokenList.dai.balanceOf(address(spoke2)), 0, 'spoke2 dai balance');
    assertEq(tokenList.dai.balanceOf(bob), daiBalanceBefore + removeAmount, 'bob dai balance');
  }

  function test_remove_fuzz_all_liquidity_with_interest(
    uint256 drawAmount,
    uint256 skipTime
  ) public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    drawAmount = bound(drawAmount, 1, daiAmount); // within added dai amount
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    uint256 lastUpdateTimestamp = vm.getBlockTimestamp();

    // add and draw dai liquidity to accrue interest
    // add from spoke2, draw from spoke1
    _addAndDrawLiquidity({
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke2),
      addAmount: daiAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: drawAmount,
      skipTime: skipTime
    });

    uint256 initialAvailableLiquidity = hub.getAsset(daiAssetId).availableLiquidity;

    // bob adds more DAI
    uint256 add2Amount = 10e18;

    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: add2Amount,
      user: bob
    });

    (uint256 drawnRestored, uint256 premiumRestored) = hub.getSpokeOwed(
      daiAssetId,
      address(spoke1)
    );

    // alice restores all debt including accrual
    Utils.restore({
      hub: hub,
      assetId: daiAssetId,
      caller: address(spoke1),
      baseAmount: drawnRestored,
      premiumAmount: premiumRestored,
      restorer: alice
    });

    AssetPosition memory asset = getAssetPosition(hub, daiAssetId);
    assertEq(
      asset.availableLiquidity,
      initialAvailableLiquidity + drawnRestored + premiumRestored + add2Amount,
      'dai availableLiquidity'
    );

    uint256 removeAmount = hub.getSpokeAddedAmount(daiAssetId, address(spoke2));
    uint256 daiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 feeAmount = hub.getSpokeAddedAmount(
      daiAssetId,
      hub.getAssetConfig(daiAssetId).feeReceiver
    );
    uint256 feeShares = hub.getSpokeAddedShares(
      daiAssetId,
      hub.getAssetConfig(daiAssetId).feeReceiver
    );

    // bob removes all possible liquidity
    // some has gone to feeReceiver
    vm.prank(address(spoke2));
    hub.remove(daiAssetId, removeAmount, bob);

    SpokePosition memory spokePosition1 = getSpokePosition(spoke1, _daiReserveId);
    SpokePosition memory spokePosition2 = getSpokePosition(spoke2, _daiReserveId);
    asset = getAssetPosition(hub, daiAssetId);

    // hub
    assertApproxEqAbs(asset.addedAmount, feeAmount, 1, 'hub addedAmount');
    assertEq(asset.addedShares, feeShares, 'hub addedShares');
    assertApproxEqAbs(asset.availableLiquidity, feeAmount, 1, 'dai availableLiquidity');
    assertEq(asset.drawn, 0, 'dai drawn');
    assertEq(asset.premium, 0, 'dai premium');
    assertEq(asset.lastUpdateTimestamp, vm.getBlockTimestamp(), 'dai lastUpdateTimestamp');
    // spoke1
    assertEq(spokePosition1.addedShares, 0, 'spoke1 addedShares');
    assertEq(spokePosition1.addedAmount, 0, 'spoke1 addedAmount');
    assertEq(spokePosition1.drawn, 0, 'spoke1 drawn');
    assertEq(spokePosition1.premium, 0, 'spoke1 premium');
    // spoke2
    assertEq(spokePosition1, spokePosition2);
    // dai - all to alice
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke1 dai balance');
    assertEq(tokenList.dai.balanceOf(address(spoke2)), 0, 'spoke2 dai balance');
    assertEq(tokenList.dai.balanceOf(bob), daiBalanceBefore + removeAmount, 'bob dai balance');
  }

  function test_remove_revertsWith_AddedAmountExceeded_zero_added() public {
    uint256 amount = 1;

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.AddedAmountExceeded.selector, 0));
    vm.prank(address(spoke1));
    hub.remove(daiAssetId, amount, address(spoke1));
  }

  function test_remove_revertsWith_AddedAmountExceeded() public {
    uint256 assetId = daiAssetId;
    uint256 amount = 100e18;

    // User add
    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: amount,
      user: alice
    });

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.AddedAmountExceeded.selector, amount));
    vm.prank(address(spoke1));
    hub.remove(daiAssetId, amount + 1, alice);

    // advance time, but no accrual
    skip(1e18);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.AddedAmountExceeded.selector, amount));
    vm.prank(address(spoke1));
    hub.remove(daiAssetId, amount + 1, alice);
  }

  function test_remove_revertsWith_NotAvailableLiquidity() public {
    uint256 amount = 100e18;
    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: amount,
      user: alice
    });
    // spoke1 draw all of dai reserve liquidity
    Utils.draw({hub: hub, assetId: daiAssetId, caller: address(spoke1), amount: amount, to: alice});
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.NotAvailableLiquidity.selector, 0));
    vm.prank(address(spoke1));
    hub.remove(daiAssetId, amount, address(spoke1));
  }

  function test_remove_revertsWith_InvalidRemoveAmount() public {
    vm.expectRevert(ILiquidityHub.InvalidRemoveAmount.selector);
    vm.prank(address(spoke1));
    hub.remove(daiAssetId, 0, alice);
  }

  function test_remove_revertsWith_AssetNotActive() public {
    uint256 amount = 100e18;
    updateAssetActive(hub, daiAssetId, false);

    vm.expectRevert(ILiquidityHub.AssetNotActive.selector);
    vm.prank(address(spoke1));
    hub.remove(daiAssetId, amount, alice);
  }

  function test_remove_revertsWith_AssetPaused() public {
    uint256 amount = 100e18;
    updateAssetPaused(hub, daiAssetId, true);

    vm.expectRevert(ILiquidityHub.AssetPaused.selector);
    vm.prank(address(spoke1));
    hub.remove(daiAssetId, amount, alice);
  }
}
