// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract LiquidityHubDonateTest is LiquidityHubBase {
  function test_donate_revertsWith_ERC20InsufficientAllowance() public {
    uint256 amount = 100e18;

    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(hub),
        0,
        amount
      )
    );
    vm.prank(address(spoke1));
    hub.donate(daiAssetId, amount, makeAddr('randomUser'));
  }

  function test_donate_fuzz_revertsWith_ERC20InsufficientAllowance(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(hub),
        0,
        amount
      )
    );
    vm.prank(address(spoke1));
    hub.donate(daiAssetId, amount, makeAddr('randomUser'));
  }

  function test_donate_revertsWith_InvalidFeeReceiver() public {
    uint256 amount = 100e18;

    updateAssetFeeReceiver(hub, daiAssetId, address(0));
    assertEq(hub.getAsset(daiAssetId).config.feeReceiver, address(0));

    vm.expectRevert(ILiquidityHub.InvalidFeeReceiver.selector);
    vm.prank(address(spoke1));
    hub.donate(daiAssetId, amount, alice);
  }

  function test_donate_revertsWith_AssetNotActive() public {
    uint256 amount = 100e18;

    updateAssetActive(hub, daiAssetId, false);
    assertFalse(hub.getAsset(daiAssetId).config.active);

    vm.expectRevert(ILiquidityHub.AssetNotActive.selector);
    vm.prank(address(spoke1));
    hub.donate(daiAssetId, amount, alice);
  }

  function test_donate_revertsWith_AssetPaused() public {
    uint256 amount = 100e18;

    updateAssetPaused(hub, daiAssetId, true);
    assertTrue(hub.getAsset(daiAssetId).config.paused);

    vm.expectRevert(ILiquidityHub.AssetPaused.selector);
    vm.prank(address(spoke1));
    hub.donate(daiAssetId, amount, alice);
  }

  function test_donate_revertsWith_AssetFrozen() public {
    uint256 amount = 100e18;

    updateAssetFrozen(hub, daiAssetId, true);
    assertTrue(hub.getAsset(daiAssetId).config.frozen);

    vm.expectRevert(ILiquidityHub.AssetFrozen.selector);
    vm.prank(address(spoke1));
    hub.donate(daiAssetId, amount, alice);
  }

  function test_donate_revertsWith_SupplyCapExceeded() public {
    uint256 amount = 100e18;

    uint256 newSupplyCap = amount - 1;
    _updateSupplyCap(daiAssetId, _getFeeReceiver(daiAssetId), newSupplyCap);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SupplyCapExceeded.selector, newSupplyCap));
    vm.prank(address(spoke1));
    hub.donate(daiAssetId, amount, alice);
  }

  function test_donate_fuzz_revertsWith_SupplyCapExceeded(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    uint256 newSupplyCap = amount - 1;
    _updateSupplyCap(daiAssetId, _getFeeReceiver(daiAssetId), newSupplyCap);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SupplyCapExceeded.selector, newSupplyCap));
    vm.prank(address(spoke1));
    hub.donate(daiAssetId, amount, alice);
  }

  function test_donate_revertsWith_SupplyCapExceeded_due_to_interest() public {
    uint256 daiAmount = 100e18;

    uint256 newSupplyCap = daiAmount + 1;
    _updateSupplyCap(daiAssetId, _getFeeReceiver(daiAssetId), newSupplyCap);

    _supplyAndDrawLiquidity({
      assetId: daiAssetId,
      supplyUser: bob,
      supplySpoke: _getFeeReceiver(daiAssetId),
      supplyAmount: daiAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: daiAmount,
      skipTime: 365 days
    });

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SupplyCapExceeded.selector, newSupplyCap));
    vm.prank(address(spoke2));
    hub.donate(daiAssetId, 1, alice);
  }

  function test_donate_fuzz_revertsWith_SupplyCapExceeded_due_to_interest(
    uint256 daiAmount,
    uint256 drawAmount,
    uint256 rate,
    uint256 skipTime
  ) public {
    daiAmount = bound(daiAmount, 1, MAX_SUPPLY_AMOUNT);
    drawAmount = bound(drawAmount, 1, daiAmount);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    uint256 newSupplyCap = daiAmount + 1;
    rate = bound(rate, 1, MAX_BORROW_RATE); // 0.01% to 1000%

    _updateSupplyCap(daiAssetId, _getFeeReceiver(daiAssetId), newSupplyCap);
    _mockInterestRate(rate);
    _supplyAndDrawLiquidity({
      assetId: daiAssetId,
      supplyUser: bob,
      supplySpoke: _getFeeReceiver(daiAssetId),
      supplyAmount: daiAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: drawAmount,
      skipTime: skipTime
    });
    vm.assume(hub.convertToSuppliedShares(daiAssetId, daiAmount) < daiAmount);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SupplyCapExceeded.selector, newSupplyCap));
    vm.prank(address(spoke2));
    hub.donate(daiAssetId, 1, alice); // cannot supply any additional amount
  }
  function test_donate_single_asset() public {
    uint256 amount = 100e18;
    uint256 expectedSupplyShares = hub.convertToSuppliedShares(daiAssetId, amount);

    // hub
    assertEq(hub.getAssetSuppliedAmount(daiAssetId), 0);
    assertEq(hub.getAssetSuppliedShares(daiAssetId), 0);
    assertEq(hub.getSpokeSuppliedAmount(daiAssetId, address(spoke1)), 0);
    assertEq(hub.getSpokeSuppliedShares(daiAssetId, address(spoke1)), 0);
    assertEq(hub.getAsset(daiAssetId).lastUpdateTimestamp, vm.getBlockTimestamp());
    // token balance
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0);
    assertEq(tokenList.dai.balanceOf(address(hub)), 0);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.Donate(daiAssetId, address(spoke1), amount, amount);
    vm.prank(address(spoke1));
    hub.donate(daiAssetId, amount, alice);

    // hub
    assertEq(hub.getAssetSuppliedAmount(daiAssetId), amount, 'hub asset suppliedAmount after');
    assertEq(
      hub.getAssetSuppliedShares(daiAssetId),
      expectedSupplyShares,
      'hub asset suppliedShares after'
    );
    assertEq(
      hub.getSpokeSuppliedAmount(daiAssetId, _getFeeReceiver(daiAssetId)),
      amount,
      'hub spoke suppliedAmount after'
    );
    assertEq(
      hub.getSpokeSuppliedShares(daiAssetId, _getFeeReceiver(daiAssetId)),
      expectedSupplyShares,
      'hub spoke suppliedShares after'
    );
    assertEq(hub.getAsset(daiAssetId).lastUpdateTimestamp, vm.getBlockTimestamp());
    // token balance
    assertEq(
      tokenList.dai.balanceOf(alice),
      MAX_SUPPLY_AMOUNT - amount,
      'user token balance post-supply'
    );
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    assertEq(tokenList.dai.balanceOf(address(hub)), amount, 'hub token balance post-supply');
  }

  /// @dev User makes a first supply, shares and assets amounts are correct, no precision loss
  function test_donate_fuzz_single_asset(uint256 assetId, address user, uint256 amount) public {
    _assumeValidSupplier(user);

    assetId = bound(assetId, 0, hub.assetCount() - 2); // Exclude duplicated DAI
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    uint256 expectedSupplyShares = hub.convertToSuppliedShares(daiAssetId, amount);
    IERC20 asset = hub.assetsList(assetId);

    deal(address(asset), user, MAX_SUPPLY_AMOUNT);
    vm.prank(user);
    asset.approve(address(hub), amount);

    vm.expectEmit(address(asset));
    emit IERC20.Transfer(user, address(hub), amount);
    vm.expectEmit(address(hub));
    emit ILiquidityHub.Donate(assetId, address(spoke1), amount, amount);

    vm.prank(address(spoke1));
    hub.donate(assetId, amount, user);

    // hub
    assertEq(hub.getAssetSuppliedAmount(assetId), amount, 'hub asset suppliedAmount after');
    assertEq(
      hub.getAssetSuppliedShares(assetId),
      expectedSupplyShares,
      'hub asset suppliedShares after'
    );
    assertEq(
      hub.getSpokeSuppliedAmount(assetId, _getFeeReceiver(daiAssetId)),
      amount,
      'hub spoke suppliedAmount after'
    );
    assertEq(
      hub.getSpokeSuppliedShares(assetId, _getFeeReceiver(daiAssetId)),
      expectedSupplyShares,
      'hub spoke suppliedShares after'
    );
    assertEq(hub.getAsset(assetId).lastUpdateTimestamp, vm.getBlockTimestamp());
    // token balance
    assertEq(asset.balanceOf(user), MAX_SUPPLY_AMOUNT - amount, 'user token balance post-supply');
    assertEq(asset.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    assertEq(asset.balanceOf(address(hub)), amount, 'hub token balance post-supply');
  }

  /// @dev single user, 2 spokes, 2 assets, 2 amounts
  // test that assets across different spokes don't affect each others' accounting
  function test_donate_fuzz_multi_asset_multi_spoke(
    uint256 assetId,
    uint256 amount,
    uint256 amount2
  ) public {
    assetId = bound(assetId, 0, hub.assetCount() - 3); // Exclude duplicated DAI
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    amount2 = bound(amount2, 1, MAX_SUPPLY_AMOUNT);

    uint256 assetId2 = assetId + 1;

    IERC20 asset = hub.assetsList(assetId);
    IERC20 asset2 = hub.assetsList(assetId2);

    vm.expectEmit(address(asset));
    emit IERC20.Transfer(alice, address(hub), amount);
    vm.expectEmit(address(hub));
    emit ILiquidityHub.Donate(assetId, address(spoke1), amount, amount);

    vm.prank(address(spoke1));
    hub.donate(assetId, amount, alice);

    vm.expectEmit(address(asset2));
    emit IERC20.Transfer(alice, address(hub), amount2);
    vm.expectEmit(address(hub));
    emit ILiquidityHub.Donate(assetId2, address(spoke2), amount2, amount2);

    vm.prank(address(spoke2));
    hub.donate(assetId2, amount2, alice);

    uint256 timestamp = vm.getBlockTimestamp();

    // asset1
    assertEq(
      hub.getAssetSuppliedShares(assetId),
      hub.convertToSuppliedShares(assetId, amount),
      'asset suppliedShares after'
    );
    assertEq(hub.getAssetSuppliedAmount(assetId), amount, 'asset suppliedAmount after');
    assertEq(hub.getAvailableLiquidity(assetId), amount, 'asset availableLiquidity after');
    assertEq(
      hub.getAsset(assetId).lastUpdateTimestamp,
      timestamp,
      'asset lastUpdateTimestamp after'
    );
    assertEq(
      hub.getSpokeSuppliedShares(assetId, _getFeeReceiver(daiAssetId)),
      hub.convertToSuppliedShares(assetId, amount),
      'spoke1 suppliedShares after'
    );
    assertEq(
      hub.getSpokeSuppliedAmount(assetId, _getFeeReceiver(daiAssetId)),
      amount,
      'spoke1 suppliedAmount after'
    );
    assertEq(asset.balanceOf(alice), MAX_SUPPLY_AMOUNT - amount, 'user asset1 balance after');
    assertEq(asset.balanceOf(address(spoke1)), 0, 'spoke1 asset1 balance after');
    assertEq(asset.balanceOf(address(hub)), amount, 'hub asset1 balance after');
    // asset2
    assertEq(
      hub.getAssetSuppliedShares(assetId2),
      hub.convertToSuppliedShares(assetId2, amount2),
      'asset2 suppliedShares after'
    );
    assertEq(hub.getAvailableLiquidity(assetId2), amount2, 'asset2 availableLiquidity after');
    assertEq(
      hub.getAsset(assetId2).lastUpdateTimestamp,
      timestamp,
      'asset2 lastUpdateTimestamp after'
    );
    assertEq(
      hub.getSpokeSuppliedShares(assetId2, _getFeeReceiver(daiAssetId)),
      hub.convertToSuppliedShares(assetId2, amount2),
      'spoke2 suppliedShares after'
    );
    assertEq(
      hub.getSpokeSuppliedAmount(assetId2, _getFeeReceiver(daiAssetId)),
      amount2,
      'spoke2 suppliedAmount after'
    );
    assertEq(asset2.balanceOf(alice), MAX_SUPPLY_AMOUNT - amount2, 'user asset2 balance after');
    assertEq(asset2.balanceOf(address(spoke2)), 0, 'spoke2 asset2 balance after');
    assertEq(asset2.balanceOf(address(hub)), amount2, 'hub asset2 balance after');
  }

  function test_donate_revertsWith_InvalidSupplyAmount() public {
    uint256 assetId = 0;
    uint256 amount = 0;

    vm.expectRevert(ILiquidityHub.InvalidSupplyAmount.selector);
    vm.prank(address(spoke1));
    hub.donate(assetId, amount, alice);
  }

  function test_donate_revertsWith_InvalidSharesAmount() public {
    // inflate exchange rate
    uint256 daiAmount = 1e9 * 1e18;
    uint256 drawAmount = daiAmount;

    _mockInterestRate(MAX_BORROW_RATE);
    _supplyAndDrawLiquidity({
      assetId: daiAssetId,
      supplyUser: bob,
      supplySpoke: address(spoke2),
      supplyAmount: daiAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: drawAmount,
      skipTime: 365 days * 10
    });
    assertLt(hub.convertToSuppliedShares(daiAssetId, daiAmount), daiAmount); // index increased

    // supply < 1 share
    uint256 amount = 1;
    assertTrue(hub.convertToSuppliedShares(daiAssetId, amount) == 0);

    vm.expectRevert(ILiquidityHub.InvalidSharesAmount.selector);
    vm.prank(address(spoke1));
    hub.donate(daiAssetId, amount, alice);
  }

  function test_donate_fuzz_revertsWith_InvalidSharesAmount_due_to_index(
    uint256 daiAmount,
    uint256 supplyAmount,
    uint256 skipTime,
    uint256 rate
  ) public {
    // inflate exchange rate using large values
    daiAmount = bound(daiAmount, 1e20, MAX_SUPPLY_AMOUNT);
    skipTime = bound(skipTime, 365 days, 100 * 365 days);
    rate = bound(rate, MAX_BORROW_RATE / 10, MAX_BORROW_RATE);
    _mockInterestRate(rate);
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

    uint256 minAllowedSupplyAmount = hub.convertToSuppliedAssets(daiAssetId, 1);
    // 1 share converts to > 1 amount
    vm.assume(minAllowedSupplyAmount > 1);

    // supply < 1 share with an amount > 0
    supplyAmount = bound(supplyAmount, 1, minAllowedSupplyAmount - 1);

    vm.expectRevert(ILiquidityHub.InvalidSharesAmount.selector);
    vm.prank(address(spoke1));
    hub.donate(daiAssetId, supplyAmount, alice);
  }

  function test_donate_revertsWith_InvalidAddFromHub() public {
    vm.expectRevert(ILiquidityHub.InvalidAddFromHub.selector, address(hub));

    vm.prank(address(spoke1));
    hub.donate(daiAssetId, 100e18, address(hub));
  }

  function test_donate_with_increased_index() public {
    uint256 daiAmount = 100e18;

    _supplyAndDrawLiquidity({
      assetId: daiAssetId,
      supplyUser: bob,
      supplySpoke: address(spoke2),
      supplyAmount: daiAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: daiAmount,
      skipTime: 365 days
    });
    assertLt(hub.convertToSuppliedShares(daiAssetId, daiAmount), daiAmount); // index increased, exch rate > 1

    (, uint256 premiumDebt) = hub.getAssetDebt(daiAssetId);
    assertEq(premiumDebt, 0); // zero premium debt

    uint256 supplyAmount = 10e18; // this can be 0
    uint256 expectedSupplyShares = hub.convertToSuppliedShares(daiAssetId, supplyAmount);

    uint256 suppliedAssetsBefore = hub.getSpokeSuppliedAmount(
      daiAssetId,
      _getFeeReceiver(daiAssetId)
    );
    uint256 suppliedSharesBefore = hub.getSpokeSuppliedShares(
      daiAssetId,
      _getFeeReceiver(daiAssetId)
    );

    vm.startPrank(bob);
    hub.assetsList(daiAssetId).approve(address(hub), supplyAmount);
    vm.stopPrank();

    vm.prank(address(spoke2));
    hub.donate(daiAssetId, supplyAmount, bob);

    assertEq(
      hub.getSpokeSuppliedAmount(daiAssetId, _getFeeReceiver(daiAssetId)),
      suppliedAssetsBefore + supplyAmount,
      'spoke suppliedAssets after'
    );
    assertEq(
      hub.getSpokeSuppliedShares(daiAssetId, _getFeeReceiver(daiAssetId)),
      suppliedSharesBefore + expectedSupplyShares,
      'spoke suppliedShares after'
    );
    // Hub and Spoke accounting do not match because of liquidity fees
    assertGe(
      hub.getAssetSuppliedAmount(daiAssetId),
      suppliedAssetsBefore + supplyAmount,
      'hub suppliedAssets after'
    );
    assertGe(
      hub.getAssetSuppliedShares(daiAssetId),
      suppliedSharesBefore + expectedSupplyShares,
      'hub suppliedShares after'
    );
  }

  function test_donate_with_increased_index_with_premium() public {
    uint256 daiAmount = 100e18;
    _addLiquidity(daiAssetId, daiAmount);
    _drawLiquidity(daiAssetId, daiAmount, true);
    assertLt(hub.convertToSuppliedShares(daiAssetId, daiAmount), daiAmount); // index increased, exch rate > 1

    uint256 supplyAmount = 10e18;
    uint256 expectedSupplyShares = hub.convertToSuppliedShares(daiAssetId, supplyAmount);

    uint256 suppliedAssetsBefore = hub.getSpokeSuppliedAmount(daiAssetId, address(spoke2));
    uint256 suppliedSharesBefore = hub.getSpokeSuppliedShares(daiAssetId, address(spoke2));
    // effective supply amount (taking into account potential donation)
    uint256 spokeSuppliedAmount = calculateEffectiveSuppliedAssets(
      supplyAmount,
      hub.getTotalSuppliedAssets(daiAssetId),
      hub.getTotalSuppliedShares(daiAssetId)
    );

    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: supplyAmount,
      user: bob,
      to: address(spoke2)
    });

    assertEq(
      hub.getSpokeSuppliedAmount(daiAssetId, address(spoke2)),
      suppliedAssetsBefore + spokeSuppliedAmount,
      'spoke suppliedAssets after'
    );
    assertEq(
      hub.getSpokeSuppliedShares(daiAssetId, address(spoke2)),
      suppliedSharesBefore + expectedSupplyShares,
      'spoke suppliedShares after'
    );
    // Hub and Spoke accounting do not match because of liquidity fees
    assertGe(
      hub.getAssetSuppliedAmount(daiAssetId),
      suppliedAssetsBefore + spokeSuppliedAmount,
      'hub suppliedAssets after'
    );
    assertGe(
      hub.getAssetSuppliedShares(daiAssetId),
      suppliedSharesBefore + expectedSupplyShares,
      'hub suppliedShares after'
    );
  }

  function test_donate_multi_donate_minimal_shares() public {
    uint256 amount = 100e18;

    (, uint256 drawnAmount) = _supplyAndDrawLiquidity({
      assetId: daiAssetId,
      supplyUser: bob,
      supplySpoke: address(spoke2),
      supplyAmount: amount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: amount,
      skipTime: 365 days
    });

    uint256 suppliedAssetsBefore = hub.getSpokeSuppliedAmount(
      daiAssetId,
      _getFeeReceiver(daiAssetId)
    );
    uint256 suppliedSharesBefore = hub.getSpokeSuppliedShares(
      daiAssetId,
      _getFeeReceiver(daiAssetId)
    );

    uint256 supplyShares = 1; // minimum for 1 share
    uint256 supplyAmount = minimumAssetsPerSuppliedShare(daiAssetId);
    // effective supply amount (taking into account potential donation)
    uint256 spokeSuppliedAmount = calculateEffectiveSuppliedAssets(
      supplyAmount,
      hub.getTotalSuppliedAssets(daiAssetId),
      hub.getTotalSuppliedShares(daiAssetId)
    );

    vm.prank(bob);
    tokenList.dai.approve(address(hub), amount);

    vm.prank(address(spoke1));
    hub.donate(daiAssetId, supplyAmount, bob);

    // spoke1
    assertEq(
      hub.getSpokeSuppliedAmount(daiAssetId, _getFeeReceiver(daiAssetId)),
      suppliedAssetsBefore + spokeSuppliedAmount,
      'spoke1 suppliedAssets after'
    );
    assertEq(
      hub.getSpokeSuppliedShares(daiAssetId, _getFeeReceiver(daiAssetId)),
      suppliedSharesBefore + supplyShares,
      'spoke1 suppliedShares after'
    );
  }
}
