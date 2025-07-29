// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract LiquidityHubRemoveTest is LiquidityHubBase {
  using WadRayMath for uint256;

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
      hub.previewRemoveByAssets(assetId, amount),
      amount
    );

    vm.prank(address(spoke1));
    hub.remove(assetId, amount, alice);

    AssetPosition memory assetData = getAssetPosition(hub, assetId);
    ReservePosition memory reserve = getReservePosition(spoke1, reserveId);

    // hub
    assertEq(assetData.suppliedAmount, 0, 'asset supplied amount after');
    assertEq(assetData.suppliedShares, 0, 'asset supplied shares after');
    assertEq(assetData.availableLiquidity, 0, 'asset availableLiquidity after');
    assertEq(assetData.baseDebt, 0, 'asset baseDebt after');
    assertEq(assetData.premiumDebt, 0, 'asset premiumDebt after');
    assertEq(assetData.baseDebtIndex, WadRayMath.RAY, 'asset baseBorrowIndex after');
    assertEq(assetData.baseBorrowRate, uint256(5_00).bpsToRay(), 'asset baseBorrowRate after');
    assertEq(
      assetData.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'asset lastUpdateTimestamp after'
    );
    // spoke
    assertEq(reserve, assetData);
    // dai
    assertEq(underlying.balanceOf(address(spoke1)), 0, 'spoke token balance after');
    assertEq(underlying.balanceOf(address(hub)), 0, 'hub token balance after');
    assertEq(underlying.balanceOf(alice), MAX_SUPPLY_AMOUNT, 'user token balance after');
  }

  // single asset, multiple spokes supplied. No debt
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
    ReservePosition memory reservePosition1 = getReservePosition(spoke1, _daiReserveId);
    ReservePosition memory reservePosition2 = getReservePosition(spoke2, _daiReserveId);

    // asset
    assertEq(assetData.suppliedAmount, 0, 'asset suppliedAmount after');
    assertEq(assetData.suppliedShares, 0, 'asset suppliedShares after');
    assertEq(assetData.availableLiquidity, 0, 'asset availableLiquidity after');
    assertEq(
      assetData.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'asset lastUpdateTimestamp after'
    );
    // spoke 1
    assertEq(reservePosition1.suppliedAmount, 0, 'spoke1 suppliedAmount after');
    assertEq(reservePosition1.suppliedShares, 0, 'spoke1 suppliedShares after');
    // spoke 2
    assertEq(reservePosition1, reservePosition2);
    // asset
    assertEq(underlying.balanceOf(address(spoke1)), 0, 'spoke1 token balance after');
    assertEq(underlying.balanceOf(address(spoke2)), 0, 'spoke2 token balance after');
    assertEq(underlying.balanceOf(address(hub)), 0, 'hub token balance after');
    assertEq(underlying.balanceOf(alice), MAX_SUPPLY_AMOUNT, 'user token balance after');
  }

  /// @dev single asset, multiple spokes supplied, with interest accrued.
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

    (uint256 baseDebt, uint256 premiumDebt) = hub.getAssetDebt(assetId);
    vm.assume(baseDebt + premiumDebt <= MAX_SUPPLY_AMOUNT);

    // restore all drawn liquidity
    Utils.restore({
      hub: hub,
      assetId: assetId,
      caller: address(spoke3),
      baseAmount: baseDebt,
      premiumAmount: premiumDebt,
      repayer: bob
    });

    uint256 aliceBalanceBefore = underlying.balanceOf(alice);
    uint256 spoke1Amount = hub.getSpokeSuppliedAmount(assetId, address(spoke1));
    Utils.remove(hub, assetId, address(spoke1), spoke1Amount, alice);

    uint256 spoke2Amount = hub.getSpokeSuppliedAmount(assetId, address(spoke2));
    Utils.remove(hub, assetId, address(spoke2), spoke2Amount, alice);

    AssetPosition memory assetData = getAssetPosition(hub, assetId);
    ReservePosition memory reservePosition1 = getReservePosition(spoke1, _daiReserveId);
    ReservePosition memory reservePosition2 = getReservePosition(spoke2, _daiReserveId);

    address feeReceiver = _getFeeReceiver(assetId);

    // asset
    // only remaining supplied amount are fees
    assertEq(
      assetData.suppliedAmount,
      hub.getSpokeSuppliedAmount(assetId, feeReceiver),
      'asset suppliedAmount after'
    );
    assertEq(
      assetData.suppliedShares,
      hub.getSpokeSuppliedShares(assetId, feeReceiver),
      'asset suppliedShares after'
    );
    assertEq(
      assetData.availableLiquidity,
      hub.getSpokeSuppliedAmount(assetId, feeReceiver),
      'asset availableLiquidity after'
    );
    assertEq(
      assetData.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'asset lastUpdateTimestamp after'
    );
    // spoke 1
    assertEq(reservePosition1.suppliedAmount, 0, 'spoke1 suppliedAmount after');
    assertEq(reservePosition1.suppliedShares, 0, 'spoke1 suppliedShares after');
    // spoke 2
    assertEq(reservePosition1, reservePosition2);
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
    uint256 supplyAmount = 100e18;
    uint256 initialAvailableLiquidity = hub.getAsset(daiAssetId).availableLiquidity;

    // supply and draw dai liquidity to accrue interest
    // supply from spoke2, draw from spoke1
    _supplyAndDrawLiquidity({
      assetId: daiAssetId,
      supplyUser: bob,
      supplySpoke: address(spoke2),
      supplyAmount: supplyAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: supplyAmount,
      skipTime: 365 days
    });

    (uint256 baseDebtRestored, uint256 premiumDebtRestored) = hub.getSpokeDebt(
      daiAssetId,
      address(spoke1)
    );

    // alice restores all debt including accrual for spoke1
    Utils.restore({
      hub: hub,
      assetId: daiAssetId,
      caller: address(spoke1),
      baseAmount: baseDebtRestored,
      premiumAmount: premiumDebtRestored,
      repayer: alice
    });

    AssetPosition memory asset = getAssetPosition(hub, daiAssetId);
    assertEq(
      asset.availableLiquidity,
      initialAvailableLiquidity + baseDebtRestored + premiumDebtRestored,
      'dai availableLiquidity'
    );

    // reset available liquidity variable
    initialAvailableLiquidity = hub.getAsset(daiAssetId).availableLiquidity;

    uint256 removeAmount = hub.getSpokeSuppliedAmount(daiAssetId, address(spoke2));
    uint256 daiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 feeAmount = hub.getSpokeSuppliedAmount(
      daiAssetId,
      hub.getAssetConfig(daiAssetId).feeReceiver
    );
    uint256 feeShares = hub.getSpokeSuppliedShares(
      daiAssetId,
      hub.getAssetConfig(daiAssetId).feeReceiver
    );

    // removable amount should exceed initial supplied amount due to accrued interest
    assertTrue(removeAmount > supplyAmount);

    // bob withdraws all possible liquidity
    // some has gone to feeReceiver
    vm.prank(address(spoke2));
    hub.remove(daiAssetId, removeAmount, bob);

    ReservePosition memory reserve1 = getReservePosition(spoke1, _daiReserveId);
    ReservePosition memory reserve2 = getReservePosition(spoke2, _daiReserveId);
    asset = getAssetPosition(hub, daiAssetId);

    // hub
    assertApproxEqAbs(asset.suppliedAmount, feeAmount, 1, 'asset suppliedAmount');
    assertEq(asset.suppliedShares, feeShares, 'asset suppliedShares');
    assertApproxEqAbs(
      asset.availableLiquidity,
      initialAvailableLiquidity - removeAmount,
      1,
      'dai availableLiquidity'
    );
    assertEq(asset.baseDebt, 0, 'dai baseDebt');
    assertEq(asset.premiumDebt, 0, 'dai premiumDebt');
    assertEq(asset.lastUpdateTimestamp, vm.getBlockTimestamp(), 'dai lastUpdateTimestamp');
    // spoke1
    assertEq(reserve1.suppliedShares, 0, 'spoke1 suppliedShares');
    assertEq(reserve1.suppliedAmount, 0, 'spoke1 suppliedAmount');
    assertEq(reserve1.baseDebt, 0, 'spoke1 baseDebt');
    assertEq(reserve1.premiumDebt, 0, 'spoke1 premiumDebt');
    // spoke2
    assertEq(reserve1, reserve2);
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

    drawAmount = bound(drawAmount, 1, daiAmount); // within supplied dai amount
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    uint256 lastUpdateTimestamp = vm.getBlockTimestamp();

    // supply and draw dai liquidity to accrue interest
    // supply from spoke2, draw from spoke1
    _supplyAndDrawLiquidity({
      assetId: daiAssetId,
      supplyUser: bob,
      supplySpoke: address(spoke2),
      supplyAmount: daiAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: drawAmount,
      skipTime: skipTime
    });

    uint256 initialAvailableLiquidity = hub.getAsset(daiAssetId).availableLiquidity;

    // bob supplies more DAI
    uint256 supply2Amount = 10e18;

    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: supply2Amount,
      user: bob
    });

    (uint256 baseDebtRestored, uint256 premiumDebtRestored) = hub.getSpokeDebt(
      daiAssetId,
      address(spoke1)
    );

    // alice restores all debt including accrual
    Utils.restore({
      hub: hub,
      assetId: daiAssetId,
      caller: address(spoke1),
      baseAmount: baseDebtRestored,
      premiumAmount: premiumDebtRestored,
      repayer: alice
    });

    AssetPosition memory asset = getAssetPosition(hub, daiAssetId);
    assertEq(
      asset.availableLiquidity,
      initialAvailableLiquidity + baseDebtRestored + premiumDebtRestored + supply2Amount,
      'dai availableLiquidity'
    );

    uint256 withdrawAmount = hub.getSpokeSuppliedAmount(daiAssetId, address(spoke2));
    uint256 daiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 feeAmount = hub.getSpokeSuppliedAmount(
      daiAssetId,
      hub.getAssetConfig(daiAssetId).feeReceiver
    );
    uint256 feeShares = hub.getSpokeSuppliedShares(
      daiAssetId,
      hub.getAssetConfig(daiAssetId).feeReceiver
    );

    // bob withdraws all possible liquidity
    // some has gone to feeReceiver
    vm.prank(address(spoke2));
    hub.remove(daiAssetId, withdrawAmount, bob);

    ReservePosition memory reserve1 = getReservePosition(spoke1, _daiReserveId);
    ReservePosition memory reserve2 = getReservePosition(spoke2, _daiReserveId);
    asset = getAssetPosition(hub, daiAssetId);

    // hub
    assertApproxEqAbs(asset.suppliedAmount, feeAmount, 1, 'hub suppliedAmount');
    assertEq(asset.suppliedShares, feeShares, 'hub suppliedShares');
    assertApproxEqAbs(asset.availableLiquidity, feeAmount, 1, 'dai availableLiquidity');
    assertEq(asset.baseDebt, 0, 'dai baseDebt');
    assertEq(asset.premiumDebt, 0, 'dai premiumDebt');
    assertEq(asset.lastUpdateTimestamp, vm.getBlockTimestamp(), 'dai lastUpdateTimestamp');
    // spoke1
    assertEq(reserve1.suppliedShares, 0, 'spoke1 suppliedShares');
    assertEq(reserve1.suppliedAmount, 0, 'spoke1 suppliedAmount');
    assertEq(reserve1.baseDebt, 0, 'spoke1 baseDebt');
    assertEq(reserve1.premiumDebt, 0, 'spoke1 premiumDebt');
    // spoke2
    assertEq(reserve1, reserve2);
    // dai - all to alice
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke1 dai balance');
    assertEq(tokenList.dai.balanceOf(address(spoke2)), 0, 'spoke2 dai balance');
    assertEq(tokenList.dai.balanceOf(bob), daiBalanceBefore + withdrawAmount, 'bob dai balance');
  }

  function test_remove_revertsWith_SuppliedAmountExceeded_zero_supplied() public {
    uint256 amount = 1;

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SuppliedAmountExceeded.selector, 0));
    vm.prank(address(spoke1));
    hub.remove(daiAssetId, amount, address(spoke1));
  }

  function test_remove_revertsWith_SuppliedAmountExceeded() public {
    uint256 assetId = daiAssetId;
    uint256 amount = 100e18;

    // User supply
    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: amount,
      user: alice
    });

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SuppliedAmountExceeded.selector, amount));
    vm.prank(address(spoke1));
    hub.remove(daiAssetId, amount + 1, alice);

    // advance time, but no accrual
    skip(1e18);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SuppliedAmountExceeded.selector, amount));
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

  function test_remove_revertsWith_SpokeNotActive() public {
    updateSpokeActive(hub, daiAssetId, address(spoke1), false);
    vm.expectRevert(ILiquidityHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub.remove(daiAssetId, 100e18, alice);
  }

  function test_remove_revertsWith_InvalidToAddress() public {
    vm.expectRevert(ILiquidityHub.InvalidToAddress.selector);
    vm.prank(address(spoke1));
    hub.remove(daiAssetId, 100e18, address(hub));
  }
}
