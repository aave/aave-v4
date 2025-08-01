// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract LiquidityHubAddTest is LiquidityHubBase {
  using SharesMath for uint256;

  function test_add_revertsWith_ERC20InsufficientAllowance() public {
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
    hub.add(daiAssetId, amount, makeAddr('randomUser'));
  }

  function test_add_fuzz_revertsWith_ERC20InsufficientAllowance(uint256 amount) public {
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
    hub.add(daiAssetId, amount, makeAddr('randomUser'));
  }

  function test_add_revertsWith_SpokeNotActive() public {
    updateSpokeActive(hub, daiAssetId, address(spoke1), false);
    vm.expectRevert(ILiquidityHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub.add(daiAssetId, 100e18, alice);
  }

  function test_add_revertsWith_SupplyCapExceeded() public {
    uint256 amount = 100e18;

    uint256 newSupplyCap = amount - 1;
    _updateSupplyCap(daiAssetId, address(spoke1), newSupplyCap);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SupplyCapExceeded.selector, newSupplyCap));
    vm.prank(address(spoke1));
    hub.add(daiAssetId, amount, alice);
  }

  /// supply reverts if the cap is exceeded, with proper rounding (up) applied to shares into assets conversion
  function test_add_revertsWith_SupplyCapExceeded_due_to_rounding() public {
    _addLiquidity(daiAssetId, 100e18);
    _drawLiquidity(daiAssetId, 45e18, true);

    uint256 totalSuppliedAssets = hub.getTotalSuppliedAssets(daiAssetId);
    uint256 totalSuppliedShares = hub.getAssetSuppliedShares(daiAssetId);

    // Depending on the borrow rate, this may not be true
    // It can be adjusted by changing the amount of assets passed to _addLiquidity and _drawLiquidity
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
      caller: address(spoke1),
      amount: supplyAmount,
      user: alice
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

  function test_add_fuzz_revertsWith_SupplyCapExceeded(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    uint256 newSupplyCap = amount - 1;
    _updateSupplyCap(daiAssetId, address(spoke1), newSupplyCap);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SupplyCapExceeded.selector, newSupplyCap));
    vm.prank(address(spoke1));
    hub.add(daiAssetId, amount, alice);
  }

  function test_add_revertsWith_SupplyCapExceeded_due_to_interest() public {
    uint256 daiAmount = 100e18;

    uint256 newSupplyCap = daiAmount + 1;
    _updateSupplyCap(daiAssetId, address(spoke2), newSupplyCap);

    _supplyAndDrawLiquidity({
      liquidityHub: hub,
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

  function test_add_fuzz_revertsWith_SupplyCapExceeded_due_to_interest(
    uint256 daiAmount,
    uint256 drawAmount,
    uint256 skipTime
  ) public {
    daiAmount = bound(daiAmount, 1, MAX_SUPPLY_AMOUNT);
    drawAmount = bound(drawAmount, 1, daiAmount);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    uint256 newSupplyCap = daiAmount + 1;

    _updateSupplyCap(daiAssetId, address(spoke2), newSupplyCap);
    _supplyAndDrawLiquidity({
      liquidityHub: hub,
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
  function test_add_SupplyCapReachedButNotExceeded() public {
    _addLiquidity(daiAssetId, 100e18);
    _drawLiquidity(daiAssetId, 45e18, true);

    uint256 totalSuppliedAssets = hub.getTotalSuppliedAssets(daiAssetId);
    uint256 totalSuppliedShares = hub.getAssetSuppliedShares(daiAssetId);

    // Depending on the borrow rate, this may not be true
    // It can be adjusted by changing the amount of assets passed to _addLiquidity and _drawLiquidity
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
      caller: address(spoke1),
      amount: supplyAmount,
      user: alice
    });
  }

  function test_add_single_asset() public {
    test_add_fuzz_single_asset(daiAssetId, alice, 100e18);
  }

  /// @dev User makes a first supply, shares and assets amounts are correct, no precision loss
  function test_add_fuzz_single_asset(uint256 assetId, address user, uint256 amount) public {
    _assumeValidSupplier(user);

    assetId = bound(assetId, 0, hub.getAssetCount() - 3); // Exclude duplicated DAI and usdy
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    IERC20 underlying = IERC20(hub.getAsset(assetId).underlying);

    (uint256 baseDebtBefore, uint256 premiumDebtBefore) = hub.getAssetDebt(assetId);
    uint256 availableLiquidityBefore = hub.getAvailableLiquidity(assetId);
    vm.expectCall(
      address(irStrategy),
      abi.encodeCall(
        IBasicInterestRateStrategy.calculateInterestRate,
        (assetId, availableLiquidityBefore + amount, baseDebtBefore, premiumDebtBefore)
      )
    );

    vm.prank(user);
    underlying.approve(address(hub), amount);
    deal(address(underlying), user, amount);

    uint256 shares = hub.convertToSuppliedShares(assetId, amount);
    vm.expectEmit(address(underlying));
    emit IERC20.Transfer(user, address(hub), amount);
    vm.expectEmit(address(hub));
    emit ILiquidityHub.Add(assetId, address(spoke1), shares, amount);

    vm.prank(address(spoke1));
    hub.add(assetId, amount, user);

    // hub
    assertEq(hub.getAssetSuppliedAmount(assetId), amount, 'hub asset suppliedAmount after');
    assertEq(hub.getAssetSuppliedShares(assetId), shares, 'hub asset suppliedShares after');
    assertEq(
      hub.getSpokeSuppliedAmount(assetId, address(spoke1)),
      amount,
      'hub spoke suppliedAmount after'
    );
    assertEq(
      hub.getSpokeSuppliedShares(assetId, address(spoke1)),
      shares,
      'hub spoke suppliedShares after'
    );
    assertEq(hub.getAsset(assetId).lastUpdateTimestamp, vm.getBlockTimestamp());
    assertEq(
      hub.getAsset(assetId).availableLiquidity,
      availableLiquidityBefore + amount,
      'hub available liquidity after'
    );
    (uint256 baseDebtAfter, ) = hub.getAssetDebt(assetId);
    assertEq(baseDebtAfter, baseDebtBefore, 'hub base debt after');
    assertBorrowRateSynced(hub, assetId, 'hub.add');
    // token balance
    assertEq(underlying.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    assertEq(underlying.balanceOf(address(hub)), amount, 'hub token balance post-supply');
  }

  /// @dev single user, 2 spokes, 2 assets, 2 amounts
  // test that assets across different spokes don't affect each others' accounting
  function test_add_fuzz_multi_asset_multi_spoke(
    uint256 assetId,
    uint256 amount,
    uint256 amount2
  ) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 4); // Exclude duplicated DAI and usdy
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    amount2 = bound(amount2, 1, MAX_SUPPLY_AMOUNT);

    uint256 assetId2 = assetId + 1;

    IERC20 underlying = IERC20(hub.getAsset(assetId).underlying);
    IERC20 underlying2 = IERC20(hub.getAsset(assetId2).underlying);

    vm.expectEmit(address(underlying));
    emit IERC20.Transfer(alice, address(hub), amount);
    vm.expectEmit(address(hub));
    emit ILiquidityHub.Add(assetId, address(spoke1), amount, amount);

    vm.prank(address(spoke1));
    hub.add(assetId, amount, alice);

    vm.expectEmit(address(underlying2));
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
    assertEq(underlying.balanceOf(alice), MAX_SUPPLY_AMOUNT - amount, 'user asset1 balance after');
    assertEq(underlying.balanceOf(address(spoke1)), 0, 'spoke1 asset1 balance after');
    assertEq(underlying.balanceOf(address(hub)), amount, 'hub asset1 balance after');
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
    assertEq(
      underlying2.balanceOf(alice),
      MAX_SUPPLY_AMOUNT - amount2,
      'user asset2 balance after'
    );
    assertEq(underlying2.balanceOf(address(spoke2)), 0, 'spoke2 asset2 balance after');
    assertEq(underlying2.balanceOf(address(hub)), amount2, 'hub asset2 balance after');
  }

  function test_add_revertsWith_InvalidAddAmount() public {
    uint256 assetId = 0;
    uint256 amount = 0;

    vm.expectRevert(ILiquidityHub.InvalidAddAmount.selector);
    vm.prank(address(spoke1));
    hub.add(assetId, amount, alice);
  }

  function test_add_revertsWith_InvalidSharesAmount() public {
    // inflate exchange rate
    uint256 daiAmount = 1e9 * 1e18;
    uint256 drawAmount = daiAmount;

    _supplyAndDrawLiquidity({
      liquidityHub: hub,
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

  function test_add_fuzz_revertsWith_InvalidSharesAmount_due_to_index(
    uint256 daiAmount,
    uint256 supplyAmount,
    uint256 skipTime
  ) public {
    // inflate exchange rate using large values
    daiAmount = bound(daiAmount, 1e20, MAX_SUPPLY_AMOUNT);
    skipTime = bound(skipTime, 365 days, 100 * 365 days);
    _supplyAndDrawLiquidity({
      liquidityHub: hub,
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

  function test_add_revertsWith_InvalidFromAddress() public {
    vm.expectRevert(ILiquidityHub.InvalidFromAddress.selector);
    vm.prank(address(spoke1));
    hub.add(daiAssetId, 100e18, address(hub));
  }

  function test_add_with_increased_index() public {
    uint256 daiAmount = 100e18;

    _supplyAndDrawLiquidity({
      liquidityHub: hub,
      assetId: daiAssetId,
      supplyUser: bob,
      supplySpoke: address(spoke2),
      supplyAmount: daiAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: daiAmount,
      skipTime: 365 days
    });

    (, uint256 premiumDebt) = hub.getAssetDebt(daiAssetId);
    assertEq(premiumDebt, 0); // zero premium debt

    uint256 supplyAmount = 10e18; // this can be 0
    uint256 shares = hub.convertToSuppliedShares(daiAssetId, supplyAmount);
    assertLt(shares, supplyAmount); // index increased, exch rate > 1

    uint256 suppliedAssetsBefore = hub.getAssetSuppliedAmount(daiAssetId);
    uint256 suppliedSharesBefore = hub.getAssetSuppliedShares(daiAssetId);

    (uint256 baseDebtBefore, uint256 premiumDebtBefore) = hub.getAssetDebt(daiAssetId);
    uint256 availableLiquidityBefore = hub.getAvailableLiquidity(daiAssetId);
    vm.expectCall(
      address(irStrategy),
      abi.encodeCall(
        IBasicInterestRateStrategy.calculateInterestRate,
        (daiAssetId, availableLiquidityBefore + supplyAmount, baseDebtBefore, premiumDebtBefore)
      )
    );

    vm.prank(alice);
    tokenList.dai.approve(address(hub), supplyAmount);

    vm.expectEmit(address(tokenList.dai));
    emit IERC20.Transfer(alice, address(hub), supplyAmount);
    vm.expectEmit(address(hub));
    emit ILiquidityHub.Add(daiAssetId, address(spoke2), shares, supplyAmount);

    vm.prank(address(spoke2));
    hub.add(daiAssetId, supplyAmount, alice);

    assertEq(
      hub.getSpokeSuppliedAmount(daiAssetId, address(spoke2)),
      suppliedAssetsBefore + supplyAmount,
      'spoke suppliedAssets after'
    );
    assertEq(
      hub.getSpokeSuppliedShares(daiAssetId, address(spoke2)),
      suppliedSharesBefore + shares,
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
      suppliedSharesBefore + shares,
      'hub suppliedShares after'
    );
    assertEq(
      hub.getAsset(daiAssetId).availableLiquidity,
      availableLiquidityBefore + supplyAmount,
      'hub available liquidity after'
    );
    (uint256 baseDebtAfter, ) = hub.getAssetDebt(daiAssetId);
    assertEq(baseDebtAfter, baseDebtBefore, 'hub base debt after');
    assertBorrowRateSynced(hub, daiAssetId, 'hub.add');
  }

  function test_add_with_increased_index_with_premium() public {
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
      caller: address(spoke2),
      amount: supplyAmount,
      user: bob
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

  function test_add_multi_supply_minimal_shares() public {
    uint256 amount = 100e18;

    (, uint256 drawnAmount) = _supplyAndDrawLiquidity({
      liquidityHub: hub,
      assetId: daiAssetId,
      supplyUser: bob,
      supplySpoke: address(spoke2),
      supplyAmount: amount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: amount,
      skipTime: 365 days
    });

    uint256 suppliedAssetsBefore1 = hub.getSpokeSuppliedAmount(daiAssetId, address(spoke1));
    uint256 suppliedSharesBefore1 = hub.getSpokeSuppliedShares(daiAssetId, address(spoke1));
    uint256 suppliedAssetsBefore2 = hub.getSpokeSuppliedAmount(daiAssetId, address(spoke2));
    uint256 suppliedSharesBefore2 = hub.getSpokeSuppliedShares(daiAssetId, address(spoke2));
    uint256 supplyShares = 1; // minimum for 1 share
    uint256 supplyAmount = minimumAssetsPerSuppliedShare(daiAssetId);
    // effective supply amount (taking into account potential donation)
    uint256 spokeSuppliedAmount = calculateEffectiveSuppliedAssets(
      supplyAmount,
      hub.getTotalSuppliedAssets(daiAssetId),
      hub.getTotalSuppliedShares(daiAssetId)
    );

    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: supplyAmount,
      user: bob
    });

    // debt exists
    (uint256 baseDebt, uint256 premiumDebt) = hub.getAssetDebt(daiAssetId);
    assertGt(baseDebt, 0);
    (baseDebt, premiumDebt) = hub.getSpokeDebt(daiAssetId, address(spoke1));
    assertGt(baseDebt, 0);

    // hub
    assertGe(
      hub.getAssetSuppliedAmount(daiAssetId),
      suppliedAssetsBefore1 + suppliedAssetsBefore2 + spokeSuppliedAmount,
      'hub suppliedAssets after'
    );
    assertGe(
      hub.getAssetSuppliedShares(daiAssetId),
      suppliedSharesBefore1 + supplyShares,
      'hub suppliedShares after'
    );
    assertEq(
      hub.getAvailableLiquidity(daiAssetId),
      amount + supplyAmount - drawnAmount,
      'asset availableLiquidity after'
    );
    assertEq(
      hub.getAsset(daiAssetId).lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'asset lastUpdateTimestamp after'
    );
    // spoke1
    assertEq(
      hub.getSpokeSuppliedAmount(daiAssetId, address(spoke1)),
      spokeSuppliedAmount,
      'spoke1 suppliedAssets after'
    );
    assertEq(
      hub.getSpokeSuppliedShares(daiAssetId, address(spoke1)),
      supplyShares,
      'spoke1 suppliedShares after'
    );
    // spoke2
    assertGe(
      hub.getSpokeSuppliedAmount(daiAssetId, address(spoke2)),
      suppliedAssetsBefore2,
      'spoke2 suppliedAmount after'
    );
    assertEq(
      hub.getSpokeSuppliedShares(daiAssetId, address(spoke2)),
      suppliedSharesBefore2,
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

  function test_add_fuzz_single_spoke_multi_supply(uint256 amount, uint256 skipTime) public {
    uint256 assetId = daiAssetId;
    uint256 numSupplies = 5;

    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT / numSupplies);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    TestSupplyParams memory params;
    (params.assetSuppliedShares, params.drawnShares) = _supplyAndDrawLiquidity({
      liquidityHub: hub,
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

    uint256 supplyShares = 1; // minimum for 1 share
    uint256 supplyAmount;
    for (uint256 i = 0; i < numSupplies; i++) {
      supplyAmount = minimumAssetsPerSuppliedShare(assetId);

      // bob supply minimal amount
      Utils.add({
        hub: hub,
        assetId: assetId,
        caller: address(spoke1),
        amount: supplyAmount,
        user: bob
      });

      (uint256 baseDebt, ) = hub.getAssetDebt(assetId);
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
      assertGe(
        hub.getAssetSuppliedAmount(assetId),
        params.assetSuppliedAmount,
        'hub suppliedAmount after'
      );
      assertGe(
        hub.getAssetSuppliedShares(assetId),
        params.assetSuppliedShares,
        'hub suppliedShares after'
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

      skip(randomizer(1 days, 365 days));
    }
  }
}
