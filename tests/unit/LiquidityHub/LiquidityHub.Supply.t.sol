// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract LiquidityHubSupplyTest is LiquidityHubBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  function test_supply_revertsWith_ERC20InsufficientAllowance() public {
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
    hub.add(daiAssetId, amount, address(spoke1));
  }

  function test_supply_fuzz_revertsWith_ERC20InsufficientAllowance(uint256 amount) public {
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
    hub.add(daiAssetId, amount, address(spoke1));
  }

  function test_supply_revertsWith_AssetNotActive() public {
    uint256 amount = 100e18;

    updateAssetActive(hub, daiAssetId, false);
    assertFalse(hub.getAsset(daiAssetId).config.active);

    vm.expectRevert(ILiquidityHub.AssetNotActive.selector);
    vm.prank(address(spoke1));
    hub.add(daiAssetId, amount, alice);
  }

  function test_supply_fuzz_revertsWith_AssetNotActive(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    updateAssetActive(hub, daiAssetId, false);
    assertFalse(hub.getAsset(daiAssetId).config.active);

    vm.expectRevert(ILiquidityHub.AssetNotActive.selector);
    vm.prank(address(spoke1));
    hub.add(daiAssetId, amount, alice);
  }

  function test_supply_revertsWith_AssetPaused() public {
    uint256 amount = 100e18;

    updateAssetPaused(hub, daiAssetId, true);
    assertTrue(hub.getAsset(daiAssetId).config.paused);

    vm.expectRevert(ILiquidityHub.AssetPaused.selector);
    vm.prank(address(spoke1));
    hub.add(daiAssetId, amount, alice);
  }

  function test_supply_fuzz_revertsWith_AssetPaused(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    updateAssetPaused(hub, daiAssetId, true);
    assertTrue(hub.getAsset(daiAssetId).config.paused);

    vm.expectRevert(ILiquidityHub.AssetPaused.selector);
    vm.prank(address(spoke1));
    hub.add(daiAssetId, amount, alice);
  }

  function test_supply_revertsWith_AssetFrozen() public {
    uint256 amount = 100e18;

    updateAssetFrozen(hub, daiAssetId, true);
    assertTrue(hub.getAsset(daiAssetId).config.frozen);

    vm.expectRevert(ILiquidityHub.AssetFrozen.selector);
    vm.prank(address(spoke1));
    hub.add(daiAssetId, amount, alice);
  }

  function test_supply_revertsWith_AssetFrozen(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    updateAssetFrozen(hub, daiAssetId, true);
    assertTrue(hub.getAsset(daiAssetId).config.frozen);

    vm.expectRevert(ILiquidityHub.AssetFrozen.selector);
    vm.prank(address(spoke1));
    hub.add(daiAssetId, amount, alice);
  }

  function test_supply_revertsWith_SupplyCapExceeded() public {
    uint256 amount = 100e18;

    uint256 newSupplyCap = amount - 1;
    _updateSupplyCap(daiAssetId, address(spoke1), newSupplyCap);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SupplyCapExceeded.selector, newSupplyCap));
    vm.prank(address(spoke1));
    hub.add(daiAssetId, amount, alice);
  }

  /// supply reverts if the cap is exceeded, with proper rounding (up) applied to shares into assets conversion
  function test_supply_revertsWith_SupplyCapExceeded_due_to_rounding() public {
    _increaseExchangeRate(daiAssetId, 100e18);

    uint256 totalSuppliedAssets = hub.getTotalSuppliedAssets(daiAssetId);
    uint256 totalSuppliedShares = hub.getAssetSuppliedShares(daiAssetId);

    // Depending on the borrow rate, this may not be true
    // It can be adjusted by changing the amount of assets passed to _increaseExchangeRate
    assertNotEq(
      totalSuppliedAssets % totalSuppliedShares,
      0,
      'totalSuppliedAssets % totalSuppliedShares is zero'
    );

    // The asset amount is 1 share worth of assets (rounded down) + 1
    // The supplied share is 1, which rounded up is equal to the
    // amount of assets supplied
    uint256 supplyAmount = totalSuppliedAssets / totalSuppliedShares + 1;

    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke1),
      amount: supplyAmount,
      user: alice,
      to: address(spoke1)
    });

    // set supply cap to amount of assets supplied * 2 - 1, given
    // that the same asset amount is provided again below
    uint256 newSupplyCap = 2 * supplyAmount - 1;
    _updateSupplyCap(daiAssetId, address(spoke1), newSupplyCap);

    // this cap will be exceeded only if the existing supplied
    // shares are rounded up
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SupplyCapExceeded.selector, newSupplyCap));
    vm.prank(address(spoke1));
    hub.add(daiAssetId, supplyAmount, alice);

    // check that supply cap is not exceeded if assets are rounded down
    uint256 suppliedAssetsRoundedDown = hub.getSpokeSuppliedAmount(daiAssetId, address(spoke1));
    assertEq(suppliedAssetsRoundedDown + supplyAmount, newSupplyCap);
  }

  function test_supply_fuzz_revertsWith_SupplyCapExceeded(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    uint256 newSupplyCap = amount - 1;
    _updateSupplyCap(daiAssetId, address(spoke1), newSupplyCap);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SupplyCapExceeded.selector, newSupplyCap));
    vm.prank(address(spoke1));
    hub.add(daiAssetId, amount, alice);
  }

  function test_supply_revertsWith_SupplyCapExceeded_due_to_interest() public {
    uint256 daiAmount = 100e18;

    uint256 newSupplyCap = daiAmount + 1;
    _updateSupplyCap(daiAssetId, address(spoke2), newSupplyCap);
  
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

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SupplyCapExceeded.selector, newSupplyCap));
    vm.prank(address(spoke2));
    hub.add(daiAssetId, 1, alice);
  }

  function test_supply_fuzz_revertsWith_SupplyCapExceeded_due_to_interest(
    uint256 daiAmount,
    uint256 drawAmount,
    uint256 rate,
    uint256 skipTime
  ) public {
    daiAmount = bound(daiAmount, 1, MAX_SUPPLY_AMOUNT);
    drawAmount = bound(drawAmount, 1, daiAmount);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    uint256 newSupplyCap = daiAmount + 1;
    rate = bound(rate, 1, MAX_BORROW_RATE).bpsToRay(); // 0.01% to 1000%

    _updateSupplyCap(daiAssetId, address(spoke2), newSupplyCap);
    _mockRate(rate);
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
    vm.assume(hub.convertToSuppliedShares(daiAssetId, daiAmount) < daiAmount);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SupplyCapExceeded.selector, newSupplyCap));
    vm.prank(address(spoke2));
    hub.add(daiAssetId, 1, alice); // cannot supply any additional amount
  }

  // supply succeeds if cap is reached but not exceeded
  function test_supply_SupplyCapReachedButNotExceeded() public {
    _increaseExchangeRate(daiAssetId, 100e18);

    uint256 totalSuppliedAssets = hub.getTotalSuppliedAssets(daiAssetId);
    uint256 totalSuppliedShares = hub.getAssetSuppliedShares(daiAssetId);

    // Depending on the borrow rate, this may not be true
    // It can be adjusted by changing the amount of assets passed to _increaseExchangeRate
    assertNotEq(
      totalSuppliedAssets % totalSuppliedShares,
      0,
      'totalSuppliedAssets % totalSuppliedShares is zero'
    );

    // The asset amount is 1 share worth of assets (rounded down) + 1
    // The supplied share is 1, which rounded up is equal to the
    // amount of assets supplied
    uint256 supplyAmount = totalSuppliedAssets / totalSuppliedShares + 1;

    uint256 spokeSuppliedShares = hub.getSpokeSuppliedShares(daiAssetId, address(spoke1));
    uint256 spokeSuppliedAssetsRoundedUp = spokeSuppliedShares.toAssetsUp(
      totalSuppliedAssets,
      totalSuppliedShares
    );

    uint256 newSupplyCap = spokeSuppliedAssetsRoundedUp + supplyAmount;
    _updateSupplyCap(daiAssetId, address(spoke1), newSupplyCap);

    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke1),
      amount: supplyAmount,
      user: alice,
      to: address(spoke1)
    });
  }

  function test_supply_single_asset() public {
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
    emit ILiquidityHub.Add(daiAssetId, address(spoke1), amount, amount);
    vm.prank(address(spoke1));
    hub.add(daiAssetId, amount, alice);

    // hub
    assertEq(hub.getAssetSuppliedAmount(daiAssetId), amount, 'hub asset suppliedAmount after');
    assertEq(
      hub.getAssetSuppliedShares(daiAssetId),
      expectedSupplyShares,
      'hub asset suppliedShares after'
    );
    assertEq(
      hub.getSpokeSuppliedAmount(daiAssetId, address(spoke1)),
      amount,
      'hub spoke suppliedAmount after'
    );
    assertEq(
      hub.getSpokeSuppliedShares(daiAssetId, address(spoke1)),
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
  function test_supply_fuzz_single_asset(uint256 assetId, uint256 amount) public {
    assetId = bound(assetId, 0, hub.assetCount() - 2); // Exclude duplicated DAI
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    uint256 expectedSupplyShares = hub.convertToSuppliedShares(daiAssetId, amount);
    IERC20 asset = hub.assetsList(assetId);
    vm.expectEmit(address(asset));
    emit IERC20.Transfer(alice, address(hub), amount);
    vm.expectEmit(address(hub));
    emit ILiquidityHub.Add(assetId, address(spoke1), amount, amount);

    vm.prank(address(spoke1));
    hub.add(assetId, amount, alice);

    // hub
    assertEq(hub.getAssetSuppliedAmount(assetId), amount, 'hub asset suppliedAmount after');
    assertEq(
      hub.getAssetSuppliedShares(assetId),
      expectedSupplyShares,
      'hub asset suppliedShares after'
    );
    assertEq(
      hub.getSpokeSuppliedAmount(assetId, address(spoke1)),
      amount,
      'hub spoke suppliedAmount after'
    );
    assertEq(
      hub.getSpokeSuppliedShares(assetId, address(spoke1)),
      expectedSupplyShares,
      'hub spoke suppliedShares after'
    );
    assertEq(hub.getAsset(assetId).lastUpdateTimestamp, vm.getBlockTimestamp());
    // token balance
    assertEq(asset.balanceOf(alice), MAX_SUPPLY_AMOUNT - amount, 'user token balance post-supply');
    assertEq(asset.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    assertEq(asset.balanceOf(address(hub)), amount, 'hub token balance post-supply');
  }

  /// @dev single user, 2 spokes, 2 assets, 2 amounts
  // test that assets across different spokes don't affect each others' accounting
  function test_supply_fuzz_multi_asset_multi_spoke(
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
    emit ILiquidityHub.Add(assetId, address(spoke1), amount, amount);

    vm.prank(address(spoke1));
    hub.add(assetId, amount, alice);

    vm.expectEmit(address(asset2));
    emit IERC20.Transfer(alice, address(hub), amount2);
    vm.expectEmit(address(hub));
    emit ILiquidityHub.Add(assetId2, address(spoke2), amount2, amount2);

    vm.prank(address(spoke2));
    hub.add(assetId2, amount2, alice);

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
      hub.getSpokeSuppliedShares(assetId, address(spoke1)),
      hub.convertToSuppliedShares(assetId, amount),
      'spoke1 suppliedShares after'
    );
    assertEq(
      hub.getSpokeSuppliedAmount(assetId, address(spoke1)),
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
      hub.getSpokeSuppliedShares(assetId2, address(spoke2)),
      hub.convertToSuppliedShares(assetId2, amount2),
      'spoke2 suppliedShares after'
    );
    assertEq(
      hub.getSpokeSuppliedAmount(assetId2, address(spoke2)),
      amount2,
      'spoke2 suppliedAmount after'
    );
    assertEq(asset2.balanceOf(alice), MAX_SUPPLY_AMOUNT - amount2, 'user asset2 balance after');
    assertEq(asset2.balanceOf(address(spoke2)), 0, 'spoke2 asset2 balance after');
    assertEq(asset2.balanceOf(address(hub)), amount2, 'hub asset2 balance after');
  }

  function test_supply_revertsWith_InvalidSupplyAmount() public {
    uint256 assetId = 0;
    uint256 amount = 0;

    vm.expectRevert(ILiquidityHub.InvalidSupplyAmount.selector);
    vm.prank(address(spoke1));
    hub.add(assetId, amount, alice);
  }

  function test_supply_revertsWith_InvalidSharesAmount() public {
    // inflate exchange rate
    uint256 daiAmount = 1e9 * 1e18;
    uint256 drawAmount = daiAmount;
    uint256 rate = uint256(MAX_BORROW_RATE).bpsToRay();

    _mockRate(rate);
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
    hub.add(daiAssetId, amount, alice);
  }

  function test_supply_fuzz_revertsWith_InvalidSharesAmount_due_to_index(
    uint256 daiAmount,
    uint256 supplyAmount,
    uint256 skipTime,
    uint256 rate
  ) public {
    // inflate exchange rate using large values
    daiAmount = bound(daiAmount, 1e20, MAX_SUPPLY_AMOUNT);
    skipTime = bound(skipTime, 365 days, 100 * 365 days);
    rate = bound(rate, MAX_BORROW_RATE / 10, MAX_BORROW_RATE).bpsToRay();

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

    uint256 minAllowedSupplyAmount = hub.convertToSuppliedAssets(daiAssetId, 1);
    // 1 share converts to > 1 amount
    vm.assume(minAllowedSupplyAmount > 1);

    // supply < 1 share with an amount > 0
    supplyAmount = bound(supplyAmount, 1, minAllowedSupplyAmount - 1);

    vm.expectRevert(ILiquidityHub.InvalidSharesAmount.selector);
    vm.prank(address(spoke1));
    hub.add(daiAssetId, supplyAmount, alice);
  }

  function test_supply_with_increased_index() public {
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

    uint256 initialSuppliedAssets = hub.getAssetSuppliedAmount(daiAssetId);
    uint256 initialSuppliedShares = hub.getAssetSuppliedShares(daiAssetId);

    uint256 supplyAmount = 10e18;
    uint256 expectedSupplyShares = hub.convertToSuppliedShares(daiAssetId, supplyAmount);

    (, uint256 premiumDebt) = hub.getAssetDebt(daiAssetId);
    assertEq(premiumDebt, 0); // zero premium debt

    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: supplyAmount,
      user: bob,
      to: address(spoke2)
    });

    assertEq(
      hub.getAssetSuppliedAmount(daiAssetId),
      initialSuppliedAssets + supplyAmount,
      'hub suppliedAssets after'
    );
    assertEq(
      hub.getAssetSuppliedShares(daiAssetId),
      expectedSupplyShares + initialSuppliedShares,
      'hub suppliedShares after'
    );
    assertEq(
      hub.getAssetSuppliedShares(daiAssetId),
      hub.getSpokeSuppliedShares(daiAssetId, address(spoke2)),
      'spoke suppliedShares after'
    );
  }

  function test_supply_with_increased_index_with_premium() public {
    uint256 daiAmount = 100e18;

    _createPremiumDebt(spoke2, daiAmount);
    assertLt(hub.convertToSuppliedShares(daiAssetId, daiAmount), daiAmount); // index increased, exch rate > 1

    uint256 initialSuppliedAssets = hub.getAssetSuppliedAmount(daiAssetId);
    uint256 initialSuppliedShares = hub.getAssetSuppliedShares(daiAssetId);

    uint256 supplyAmount = 10e18;
    uint256 expectedSupplyShares = hub.convertToSuppliedShares(daiAssetId, supplyAmount);

    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: supplyAmount,
      user: bob,
      to: address(spoke2)
    });

    assertEq(
      hub.getAssetSuppliedAmount(daiAssetId),
      initialSuppliedAssets + supplyAmount,
      'hub suppliedAssets after'
    );
    assertEq(
      hub.getAssetSuppliedShares(daiAssetId),
      expectedSupplyShares + initialSuppliedShares,
      'hub suppliedShares after'
    );
    assertEq(
      hub.getAssetSuppliedShares(daiAssetId),
      hub.getSpokeSuppliedShares(daiAssetId, address(spoke2)),
      'spoke suppliedShares after'
    );
  }

  function test_supply_multi_supply_minimal_shares() public {
    uint256 assetId = daiAssetId;
    uint256 amount = 100e18;

    (, uint256 drawnAmount) = _supplyAndDrawLiquidity({
      assetId: assetId,
      supplyUser: bob,
      supplySpoke: address(spoke2),
      supplyAmount: amount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: amount,
      skipTime: 365 days
    });

    uint256 initialSupplyAmount = hub.getAssetSuppliedAmount(assetId);
    uint256 initialSupplyShares = hub.getAssetSuppliedShares(assetId);

    uint256 supplyShares = 1; // minimum for 1 share
    uint256 supplyAmount = hub.convertToSuppliedAssets(assetId, supplyShares);
    supplyAmount = hub.convertToSuppliedShares(assetId, supplyAmount) < 1
      ? supplyAmount + 1
      : supplyAmount; // account for rounding down on assets
    // bob supply minimal amount
    Utils.add({
      hub: hub,
      assetId: assetId,
      spoke: address(spoke1),
      amount: supplyAmount,
      user: bob,
      to: address(spoke1)
    });

    // debt exists
    uint256 baseDebt;
    uint256 premiumDebt;
    (baseDebt, premiumDebt) = hub.getAssetDebt(assetId);
    assertGt(baseDebt, 0);
    (baseDebt, premiumDebt) = hub.getSpokeDebt(assetId, address(spoke1));
    assertGt(baseDebt, 0);

    // hub
    assertEq(
      hub.getAssetSuppliedAmount(assetId),
      initialSupplyAmount + supplyAmount,
      'asset suppliedAmount after'
    );
    assertEq(
      hub.getAssetSuppliedShares(assetId),
      initialSupplyShares + supplyShares,
      'asset suppliedShares after'
    );
    assertEq(
      hub.getAvailableLiquidity(assetId),
      amount + supplyAmount - drawnAmount,
      'asset availableLiquidity after'
    );
    assertEq(
      hub.getAsset(assetId).lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'asset lastUpdateTimestamp after'
    );
    // spoke1
    assertEq(
      hub.getSpokeSuppliedAmount(assetId, address(spoke1)),
      hub.convertToSuppliedAssets(assetId, 1),
      'spoke1 suppliedAmount after'
    );
    assertEq(
      hub.getSpokeSuppliedShares(assetId, address(spoke1)),
      supplyShares,
      'spoke1 suppliedShares after'
    );
    // spoke2
    assertEq(
      hub.getSpokeSuppliedAmount(assetId, address(spoke2)),
      hub.convertToSuppliedAssets(assetId, initialSupplyShares),
      'spoke2 suppliedAmount after'
    );
    assertEq(
      hub.getSpokeSuppliedShares(assetId, address(spoke2)),
      initialSupplyShares,
      'spoke2 suppliedShares after'
    );
    // token balance
    assertEq(
      tokenList.dai.balanceOf(address(hub)),
      supplyAmount + amount - drawnAmount,
      'hub token balance after'
    );
    assertEq(
      tokenList.dai.balanceOf(alice),
      MAX_SUPPLY_AMOUNT + drawnAmount,
      'alice token balance after'
    );
    assertEq(
      tokenList.dai.balanceOf(bob),
      MAX_SUPPLY_AMOUNT - amount - supplyAmount,
      'bob token balance after'
    );
  }

  function test_supply_fuzz_single_spoke_multi_supply(
    uint256 amount,
    uint256 skipTime,
    uint256 rate
  ) public {
    uint256 assetId = daiAssetId;
    uint256 numSupplies = 5;

    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT / numSupplies);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    rate = bound(rate, 1, MAX_BORROW_RATE).bpsToRay();

    TestSupplyParams memory params;

    _mockRate(rate);
    (params.assetSuppliedShares, params.drawnShares) = _supplyAndDrawLiquidity({
      assetId: assetId,
      supplyUser: bob,
      supplySpoke: address(spoke2),
      supplyAmount: amount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: amount,
      skipTime: skipTime
    });
    vm.assume(hub.convertToSuppliedShares(assetId, amount) < amount);

    params.drawnAmount = amount;
    params.assetSuppliedAmount = hub.convertToSuppliedAssets(assetId, params.assetSuppliedShares);
    params.availableLiq = amount - params.drawnAmount;
    params.spoke2SuppliedShares = hub.getSpokeSuppliedShares(assetId, address(spoke2));
    params.spoke2SuppliedAmount = hub.convertToSuppliedAssets(assetId, params.spoke2SuppliedShares);
    params.aliceBalance = MAX_SUPPLY_AMOUNT + params.drawnAmount;
    params.bobBalance = MAX_SUPPLY_AMOUNT - amount;

    for (uint256 i = 0; i < numSupplies; i++) {
      uint256 supplyShares = 1; // minimum for 1 share
      uint256 supplyAmount = hub.convertToSuppliedAssets(assetId, supplyShares);
      supplyAmount = hub.convertToSuppliedShares(assetId, supplyAmount) < 1
        ? supplyAmount + 1
        : supplyAmount; // account for rounding down on assets
      // bob supply minimal amount
      Utils.add({
        hub: hub,
        assetId: assetId,
        spoke: address(spoke1),
        amount: supplyAmount,
        user: bob,
        to: address(spoke1)
      });

      uint256 baseDebt;
      (baseDebt, ) = hub.getAssetDebt(assetId);
      assertGt(baseDebt, 0);
      (baseDebt, ) = hub.getSpokeDebt(assetId, address(spoke1));
      assertGt(baseDebt, 0);

      params.availableLiq += supplyAmount;
      params.assetSuppliedShares += supplyShares;
      params.assetSuppliedAmount = hub.convertToSuppliedAssets(assetId, params.assetSuppliedShares);
      params.spoke1SuppliedShares += supplyShares;
      params.spoke1SuppliedAmount = hub.convertToSuppliedAssets(
        assetId,
        params.spoke1SuppliedShares
      );
      params.bobBalance -= supplyAmount;

      // hub
      assertEq(
        hub.getAssetSuppliedAmount(assetId),
        params.assetSuppliedAmount,
        'asset suppliedAmount after'
      );
      assertEq(
        hub.getAssetSuppliedShares(assetId),
        params.assetSuppliedShares,
        'asset suppliedShares after'
      );
      assertEq(
        hub.getAvailableLiquidity(assetId),
        params.availableLiq,
        'asset availableLiquidity after'
      );
      assertEq(
        hub.getAsset(assetId).lastUpdateTimestamp,
        vm.getBlockTimestamp(),
        'asset lastUpdateTimestamp after'
      );
      // spoke1
      assertEq(
        hub.getSpokeSuppliedAmount(assetId, address(spoke1)),
        hub.convertToSuppliedAssets(assetId, params.spoke1SuppliedShares),
        'spoke1 suppliedAmount after'
      );
      assertEq(
        hub.getSpokeSuppliedShares(assetId, address(spoke1)),
        params.spoke1SuppliedShares,
        'spoke1 suppliedShares after'
      );
      // spoke2
      assertEq(
        hub.getSpokeSuppliedAmount(assetId, address(spoke2)),
        hub.convertToSuppliedAssets(assetId, params.spoke2SuppliedShares),
        'spoke2 suppliedAmount after'
      );
      assertEq(
        hub.getSpokeSuppliedShares(assetId, address(spoke2)),
        params.spoke2SuppliedShares,
        'spoke2 suppliedShares after'
      );
      // token balance
      assertEq(
        tokenList.dai.balanceOf(address(hub)),
        params.availableLiq,
        'hub token balance after'
      );
      assertEq(tokenList.dai.balanceOf(alice), params.aliceBalance, 'alice token balance after');
      assertEq(tokenList.dai.balanceOf(bob), params.bobBalance, 'bob token balance after');

      skip(randomizer(1 days, 365 days, i));
    }
  }
}
