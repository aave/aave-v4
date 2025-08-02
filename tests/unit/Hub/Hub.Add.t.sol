// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubAddTest is HubBase {
  using SharesMath for uint256;

  function test_add_revertsWith_ERC20InsufficientAllowance() public {
    uint256 amount = 100e18;

    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(hub1),
        0,
        amount
      )
    );
    vm.prank(address(spoke1));
    hub1.add(daiAssetId, amount, makeAddr('randomUser'));
  }

  function test_add_fuzz_revertsWith_ERC20InsufficientAllowance(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(hub1),
        0,
        amount
      )
    );
    vm.prank(address(spoke1));
    hub1.add(daiAssetId, amount, makeAddr('randomUser'));
  }

  function test_add_revertsWith_SpokeNotActive() public {
    updateSpokeActive(hub1, daiAssetId, address(spoke1), false);
    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.add(daiAssetId, 100e18, alice);
  }

  function test_add_revertsWith_AddCapExceeded() public {
    uint256 amount = 100e18;

    uint256 newAddCap = amount - 1;
    _updateAddCap(daiAssetId, address(spoke1), newAddCap);

    vm.expectRevert(abi.encodeWithSelector(IHub.AddCapExceeded.selector, newAddCap));
    vm.prank(address(spoke1));
    hub1.add(daiAssetId, amount, alice);
  }

  /// add reverts if the cap is exceeded, with proper rounding (up) applied to shares into assets conversion
  function test_add_revertsWith_AddCapExceeded_due_to_rounding() public {
    _addLiquidity(daiAssetId, 100e18);
    _drawLiquidity(daiAssetId, 45e18, true);

    uint256 totalAddedAssets = hub1.getTotalAddedAssets(daiAssetId);
    uint256 totalAddedShares = hub1.getAssetAddedShares(daiAssetId);

    // Depending on the borrow rate, this may not be true
    // It can be adjusted by changing the amount of assets passed to _addLiquidity and _drawLiquidity
    assertNotEq(
      totalAddedAssets % totalAddedShares,
      0,
      'totalAddedAssets % totalAddedShares is zero'
    );

    // The asset amount is 1 share worth of assets (rounded down) + 1
    // The added share is 1, which rounded up is equal to the
    // amount of assets added
    uint256 addedAmount = totalAddedAssets / totalAddedShares + 1;

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: addedAmount,
      user: alice
    });

    // set add cap to amount of assets added * 2 - 1, given
    // that the same asset amount is provided again below
    uint256 newAddCap = 2 * addedAmount - 1;
    _updateAddCap(daiAssetId, address(spoke1), newAddCap);

    // this cap will be exceeded only if the existing added
    // shares are rounded up
    vm.expectRevert(abi.encodeWithSelector(IHub.AddCapExceeded.selector, newAddCap));
    vm.prank(address(spoke1));
    hub1.add(daiAssetId, addedAmount, alice);

    // check that add cap is not exceeded if assets are rounded down
    uint256 addedAssetsRoundedDown = hub1.getSpokeAddedAmount(daiAssetId, address(spoke1));
    assertEq(addedAssetsRoundedDown + addedAmount, newAddCap);
  }

  function test_add_fuzz_revertsWith_AddCapExceeded(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    uint256 newAddCap = amount - 1;
    _updateAddCap(daiAssetId, address(spoke1), newAddCap);

    vm.expectRevert(abi.encodeWithSelector(IHub.AddCapExceeded.selector, newAddCap));
    vm.prank(address(spoke1));
    hub1.add(daiAssetId, amount, alice);
  }

  function test_add_revertsWith_AddCapExceeded_due_to_interest() public {
    uint256 daiAmount = 100e18;

    uint256 newAddCap = daiAmount + 1;
    _updateAddCap(daiAssetId, address(spoke2), newAddCap);

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke2),
      addAmount: daiAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: daiAmount,
      skipTime: 365 days
    });

    vm.expectRevert(abi.encodeWithSelector(IHub.AddCapExceeded.selector, newAddCap));
    vm.prank(address(spoke2));
    hub1.add(daiAssetId, 1, alice);
  }

  function test_add_fuzz_revertsWith_AddCapExceeded_due_to_interest(
    uint256 daiAmount,
    uint256 drawAmount,
    uint256 skipTime
  ) public {
    daiAmount = bound(daiAmount, 1, MAX_SUPPLY_AMOUNT);
    drawAmount = bound(drawAmount, 1, daiAmount);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    uint256 newAddCap = daiAmount + 1;

    _updateAddCap(daiAssetId, address(spoke2), newAddCap);
    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke2),
      addAmount: daiAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: drawAmount,
      skipTime: skipTime
    });
    vm.assume(hub1.convertToAddedShares(daiAssetId, daiAmount) < daiAmount);

    vm.expectRevert(abi.encodeWithSelector(IHub.AddCapExceeded.selector, newAddCap));
    vm.prank(address(spoke2));
    hub1.add(daiAssetId, 1, alice); // cannot add any additional amount
  }

  // add succeeds if cap is reached but not exceeded
  function test_add_AddCapReachedButNotExceeded() public {
    _addLiquidity(daiAssetId, 100e18);
    _drawLiquidity(daiAssetId, 45e18, true);

    uint256 totalAddedAssets = hub1.getTotalAddedAssets(daiAssetId);
    uint256 totalAddedShares = hub1.getAssetAddedShares(daiAssetId);

    // Depending on the borrow rate, this may not be true
    // It can be adjusted by changing the amount of assets passed to _addLiquidity and _drawLiquidity
    assertNotEq(
      totalAddedAssets % totalAddedShares,
      0,
      'totalAddedAssets % totalAddedShares is zero'
    );

    // The asset amount is 1 share worth of assets (rounded down) + 1
    // The added share is 1, which rounded up is equal to the
    // amount of assets added
    uint256 addedAmount = totalAddedAssets / totalAddedShares + 1;

    uint256 spokeAddedShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    uint256 spokeAddedAssetsRoundedUp = spokeAddedShares.toAssetsUp(
      totalAddedAssets,
      totalAddedShares
    );

    uint256 newAddCap = spokeAddedAssetsRoundedUp + addedAmount;
    _updateAddCap(daiAssetId, address(spoke1), newAddCap);

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: addedAmount,
      user: alice
    });
  }

  function test_add_single_asset() public {
    test_add_fuzz_single_asset(daiAssetId, alice, 100e18);
  }

  /// @dev User makes a first add, shares and assets amounts are correct, no precision loss
  function test_add_fuzz_single_asset(uint256 assetId, address user, uint256 amount) public {
    _assumeValidSupplier(user);

    assetId = bound(assetId, 0, hub1.getAssetCount() - 3); // Exclude duplicated DAI and usdy
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    IERC20 underlying = IERC20(hub1.getAsset(assetId).underlying);

    (uint256 drawnBefore, uint256 premiumBefore) = hub1.getAssetOwed(assetId);
    uint256 liquidityBefore = hub1.getLiquidity(assetId);
    vm.expectCall(
      address(irStrategy),
      abi.encodeCall(
        IBasicInterestRateStrategy.calculateInterestRate,
        (assetId, liquidityBefore + amount, drawnBefore, premiumBefore)
      )
    );

    vm.prank(user);
    underlying.approve(address(hub1), amount);
    deal(address(underlying), user, amount);

    uint256 shares = hub1.convertToAddedShares(assetId, amount);
    vm.expectEmit(address(underlying));
    emit IERC20.Transfer(user, address(hub1), amount);
    vm.expectEmit(address(hub1));
    emit IHubBase.Add(assetId, address(spoke1), shares, amount);

    vm.prank(address(spoke1));
    hub1.add(assetId, amount, user);

    // hub
    assertEq(hub1.getAssetAddedAmount(assetId), amount, 'hub asset addedAmount after');
    assertEq(hub1.getAssetAddedShares(assetId), shares, 'hub asset addedShares after');
    assertEq(
      hub1.getSpokeAddedAmount(assetId, address(spoke1)),
      amount,
      'hub spoke addedAmount after'
    );
    assertEq(
      hub1.getSpokeAddedShares(assetId, address(spoke1)),
      shares,
      'hub spoke addedShares after'
    );
    assertEq(hub1.getAsset(assetId).lastUpdateTimestamp, vm.getBlockTimestamp());
    assertEq(
      hub1.getAsset(assetId).liquidity,
      liquidityBefore + amount,
      'hub available liquidity after'
    );
    (uint256 drawnAfter, ) = hub1.getAssetOwed(assetId);
    assertEq(drawnAfter, drawnBefore, 'hub drawn debt after');
    assertBorrowRateSynced(hub1, assetId, 'hub1.add');
    // token balance
    assertEq(underlying.balanceOf(address(spoke1)), 0, 'spoke token balance post-add');
    assertEq(underlying.balanceOf(address(hub1)), amount, 'hub token balance post-add');
  }

  /// @dev single user, 2 spokes, 2 assets, 2 amounts
  // test that assets across different spokes don't affect each others' accounting
  function test_add_fuzz_multi_asset_multi_spoke(
    uint256 assetId,
    uint256 amount,
    uint256 amount2
  ) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 4); // Exclude duplicated DAI and usdy
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    amount2 = bound(amount2, 1, MAX_SUPPLY_AMOUNT);

    uint256 assetId2 = assetId + 1;

    IERC20 underlying = IERC20(hub1.getAsset(assetId).underlying);
    IERC20 underlying2 = IERC20(hub1.getAsset(assetId2).underlying);

    vm.expectEmit(address(underlying));
    emit IERC20.Transfer(alice, address(hub1), amount);
    vm.expectEmit(address(hub1));
    emit IHubBase.Add(assetId, address(spoke1), amount, amount);

    vm.prank(address(spoke1));
    hub1.add(assetId, amount, alice);

    vm.expectEmit(address(underlying2));
    emit IERC20.Transfer(alice, address(hub1), amount2);
    vm.expectEmit(address(hub1));
    emit IHubBase.Add(assetId2, address(spoke2), amount2, amount2);

    vm.prank(address(spoke2));
    hub1.add(assetId2, amount2, alice);

    uint256 timestamp = vm.getBlockTimestamp();

    // asset1
    assertEq(
      hub1.getAssetAddedShares(assetId),
      hub1.convertToAddedShares(assetId, amount),
      'asset addedShares after'
    );
    assertEq(hub1.getAssetAddedAmount(assetId), amount, 'asset addedAmount after');
    assertEq(hub1.getLiquidity(assetId), amount, 'asset liquidity after');
    assertEq(
      hub1.getAsset(assetId).lastUpdateTimestamp,
      timestamp,
      'asset lastUpdateTimestamp after'
    );
    assertEq(
      hub1.getSpokeAddedShares(assetId, address(spoke1)),
      hub1.convertToAddedShares(assetId, amount),
      'spoke1 addedShares after'
    );
    assertEq(
      hub1.getSpokeAddedAmount(assetId, address(spoke1)),
      amount,
      'spoke1 addedAmount after'
    );
    assertEq(underlying.balanceOf(alice), MAX_SUPPLY_AMOUNT - amount, 'user asset1 balance after');
    assertEq(underlying.balanceOf(address(spoke1)), 0, 'spoke1 asset1 balance after');
    assertEq(underlying.balanceOf(address(hub1)), amount, 'hub asset1 balance after');
    // asset2
    assertEq(
      hub1.getAssetAddedShares(assetId2),
      hub1.convertToAddedShares(assetId2, amount2),
      'asset2 addedShares after'
    );
    assertEq(hub1.getLiquidity(assetId2), amount2, 'asset2 liquidity after');
    assertEq(
      hub1.getAsset(assetId2).lastUpdateTimestamp,
      timestamp,
      'asset2 lastUpdateTimestamp after'
    );
    assertEq(
      hub1.getSpokeAddedShares(assetId2, address(spoke2)),
      hub1.convertToAddedShares(assetId2, amount2),
      'spoke2 addedShares after'
    );
    assertEq(
      hub1.getSpokeAddedAmount(assetId2, address(spoke2)),
      amount2,
      'spoke2 addedAmount after'
    );
    assertEq(
      underlying2.balanceOf(alice),
      MAX_SUPPLY_AMOUNT - amount2,
      'user asset2 balance after'
    );
    assertEq(underlying2.balanceOf(address(spoke2)), 0, 'spoke2 asset2 balance after');
    assertEq(underlying2.balanceOf(address(hub1)), amount2, 'hub asset2 balance after');
  }

  function test_add_revertsWith_InvalidAddAmount() public {
    uint256 assetId = 0;
    uint256 amount = 0;

    vm.expectRevert(IHub.InvalidAddAmount.selector);
    vm.prank(address(spoke1));
    hub1.add(assetId, amount, alice);
  }

  function test_add_revertsWith_InvalidSharesAmount() public {
    // inflate exchange rate
    uint256 daiAmount = 1e9 * 1e18;
    uint256 drawAmount = daiAmount;

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke2),
      addAmount: daiAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: drawAmount,
      skipTime: 365 days * 10
    });
    assertLt(hub1.convertToAddedShares(daiAssetId, daiAmount), daiAmount); // index increased

    // add < 1 share
    uint256 amount = 1;
    assertTrue(hub1.convertToAddedShares(daiAssetId, amount) == 0);

    vm.expectRevert(IHub.InvalidSharesAmount.selector);
    vm.prank(address(spoke1));
    hub1.add(daiAssetId, amount, alice);
  }

  function test_add_fuzz_revertsWith_InvalidSharesAmount_due_to_index(
    uint256 daiAmount,
    uint256 addAmount,
    uint256 skipTime
  ) public {
    // inflate exchange rate using large values
    daiAmount = bound(daiAmount, 1e20, MAX_SUPPLY_AMOUNT);
    skipTime = bound(skipTime, 365 days, 100 * 365 days);
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

    uint256 minAllowedAddedAmount = hub1.convertToAddedAssets(daiAssetId, 1);
    // 1 share converts to > 1 amount
    vm.assume(minAllowedAddedAmount > 1);

    // add < 1 share with an amount > 0
    addAmount = bound(addAmount, 1, minAllowedAddedAmount - 1);

    vm.expectRevert(IHub.InvalidSharesAmount.selector);
    vm.prank(address(spoke1));
    hub1.add(daiAssetId, addAmount, alice);
  }

  function test_add_revertsWith_InvalidFromAddress() public {
    vm.expectRevert(IHub.InvalidFromAddress.selector);
    vm.prank(address(spoke1));
    hub1.add(daiAssetId, 100e18, address(hub1));
  }

  function test_add_with_increased_index() public {
    uint256 daiAmount = 100e18;

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke2),
      addAmount: daiAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: daiAmount,
      skipTime: 365 days
    });

    (, uint256 premium) = hub1.getAssetOwed(daiAssetId);
    assertEq(premium, 0); // zero premium debt

    uint256 addAmount = 10e18; // this can be 0
    uint256 shares = hub1.convertToAddedShares(daiAssetId, addAmount);
    assertLt(shares, addAmount); // index increased, exch rate > 1

    uint256 addedAssetsBefore = hub1.getAssetAddedAmount(daiAssetId);
    uint256 addedSharesBefore = hub1.getAssetAddedShares(daiAssetId);

    (uint256 drawnBefore, uint256 premiumBefore) = hub1.getAssetOwed(daiAssetId);
    uint256 liquidityBefore = hub1.getLiquidity(daiAssetId);
    vm.expectCall(
      address(irStrategy),
      abi.encodeCall(
        IBasicInterestRateStrategy.calculateInterestRate,
        (daiAssetId, liquidityBefore + addAmount, drawnBefore, premiumBefore)
      )
    );

    vm.prank(alice);
    tokenList.dai.approve(address(hub1), addAmount);

    vm.expectEmit(address(tokenList.dai));
    emit IERC20.Transfer(alice, address(hub1), addAmount);
    vm.expectEmit(address(hub1));
    emit IHubBase.Add(daiAssetId, address(spoke2), shares, addAmount);

    vm.prank(address(spoke2));
    hub1.add(daiAssetId, addAmount, alice);

    assertEq(
      hub1.getSpokeAddedAmount(daiAssetId, address(spoke2)),
      addedAssetsBefore + addAmount,
      'spoke addedAssets after'
    );
    assertEq(
      hub1.getSpokeAddedShares(daiAssetId, address(spoke2)),
      addedSharesBefore + shares,
      'spoke addedShares after'
    );
    // Hub and Spoke accounting do not match because of liquidity fees
    assertGe(
      hub1.getAssetAddedAmount(daiAssetId),
      addedAssetsBefore + addAmount,
      'hub addedAssets after'
    );
    assertGe(
      hub1.getAssetAddedShares(daiAssetId),
      addedSharesBefore + shares,
      'hub addedShares after'
    );
    assertEq(
      hub1.getAsset(daiAssetId).liquidity,
      liquidityBefore + addAmount,
      'hub available liquidity after'
    );
    (uint256 drawnAfter, ) = hub1.getAssetOwed(daiAssetId);
    assertEq(drawnAfter, drawnBefore, 'hub drawn debt after');
    assertBorrowRateSynced(hub1, daiAssetId, 'hub1.add');
  }

  function test_add_with_increased_index_with_premium() public {
    uint256 daiAmount = 100e18;
    _addLiquidity(daiAssetId, daiAmount);
    _drawLiquidity(daiAssetId, daiAmount, true);
    assertLt(hub1.convertToAddedShares(daiAssetId, daiAmount), daiAmount); // index increased, exch rate > 1

    uint256 addAmount = 10e18;
    uint256 expectedAddedShares = hub1.convertToAddedShares(daiAssetId, addAmount);

    uint256 addedAssetsBefore = hub1.getSpokeAddedAmount(daiAssetId, address(spoke2));
    uint256 addedSharesBefore = hub1.getSpokeAddedShares(daiAssetId, address(spoke2));
    // effective add amount (taking into account potential donation)
    uint256 spokeAddedAmount = calculateEffectiveAddedAssets(
      addAmount,
      hub1.getTotalAddedAssets(daiAssetId),
      hub1.getTotalAddedShares(daiAssetId)
    );

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: addAmount,
      user: bob
    });

    assertEq(
      hub1.getSpokeAddedAmount(daiAssetId, address(spoke2)),
      addedAssetsBefore + spokeAddedAmount,
      'spoke addedAssets after'
    );
    assertEq(
      hub1.getSpokeAddedShares(daiAssetId, address(spoke2)),
      addedSharesBefore + expectedAddedShares,
      'spoke addedShares after'
    );
    // Hub and Spoke accounting do not match because of liquidity fees
    assertGe(
      hub1.getAssetAddedAmount(daiAssetId),
      addedAssetsBefore + spokeAddedAmount,
      'hub addedAssets after'
    );
    assertGe(
      hub1.getAssetAddedShares(daiAssetId),
      addedSharesBefore + expectedAddedShares,
      'hub addedShares after'
    );
  }

  function test_add_multi_add_minimal_shares() public {
    uint256 amount = 100e18;

    (, uint256 drawnAmount) = _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke2),
      addAmount: amount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: amount,
      skipTime: 365 days
    });

    uint256 addedAssetsBefore1 = hub1.getSpokeAddedAmount(daiAssetId, address(spoke1));
    uint256 addedSharesBefore1 = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    uint256 addedAssetsBefore2 = hub1.getSpokeAddedAmount(daiAssetId, address(spoke2));
    uint256 addedSharesBefore2 = hub1.getSpokeAddedShares(daiAssetId, address(spoke2));
    uint256 addShares = 1; // minimum for 1 share
    uint256 addAmount = minimumAssetsPerAddedShare(hub1, daiAssetId);
    // effective add amount (taking into account potential donation)
    uint256 spokeAddedAmount = calculateEffectiveAddedAssets(
      addAmount,
      hub1.getTotalAddedAssets(daiAssetId),
      hub1.getTotalAddedShares(daiAssetId)
    );

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: addAmount,
      user: bob
    });

    // debt exists
    (uint256 drawn, uint256 premium) = hub1.getAssetOwed(daiAssetId);
    assertGt(drawn, 0);
    (drawn, premium) = hub1.getSpokeOwed(daiAssetId, address(spoke1));
    assertGt(drawn, 0);

    // hub
    assertGe(
      hub1.getAssetAddedAmount(daiAssetId),
      addedAssetsBefore1 + addedAssetsBefore2 + spokeAddedAmount,
      'hub addedAssets after'
    );
    assertGe(
      hub1.getAssetAddedShares(daiAssetId),
      addedSharesBefore1 + addShares,
      'hub addedShares after'
    );
    assertEq(
      hub1.getLiquidity(daiAssetId),
      amount + addAmount - drawnAmount,
      'asset liquidity after'
    );
    assertEq(
      hub1.getAsset(daiAssetId).lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'asset lastUpdateTimestamp after'
    );
    // spoke1
    assertEq(
      hub1.getSpokeAddedAmount(daiAssetId, address(spoke1)),
      spokeAddedAmount,
      'spoke1 addedAssets after'
    );
    assertEq(
      hub1.getSpokeAddedShares(daiAssetId, address(spoke1)),
      addShares,
      'spoke1 addedShares after'
    );
    // spoke2
    assertGe(
      hub1.getSpokeAddedAmount(daiAssetId, address(spoke2)),
      addedAssetsBefore2,
      'spoke2 addedAmount after'
    );
    assertEq(
      hub1.getSpokeAddedShares(daiAssetId, address(spoke2)),
      addedSharesBefore2,
      'spoke2 addedShares after'
    );
    // token balance
    assertEq(
      tokenList.dai.balanceOf(address(hub1)),
      addAmount + amount - drawnAmount,
      'hub token balance after'
    );
    assertEq(
      tokenList.dai.balanceOf(alice),
      MAX_SUPPLY_AMOUNT + drawnAmount,
      'alice token balance after'
    );
    assertEq(
      tokenList.dai.balanceOf(bob),
      MAX_SUPPLY_AMOUNT - amount - addAmount,
      'bob token balance after'
    );
  }

  function test_add_fuzz_single_spoke_multi_add(uint256 amount, uint256 skipTime) public {
    uint256 assetId = daiAssetId;
    uint256 numAdds = 5;

    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT / numAdds);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    TestAddParams memory params;
    (params.assetAddedShares, params.drawnShares) = _addAndDrawLiquidity({
      hub: hub1,
      assetId: assetId,
      addUser: bob,
      addSpoke: address(spoke2),
      addAmount: amount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: amount,
      skipTime: skipTime
    });
    vm.assume(hub1.convertToAddedShares(assetId, amount) < amount);

    params.drawnAmount = amount;
    params.assetAddedAmount = hub1.convertToAddedAssets(assetId, params.assetAddedShares);
    params.availableLiq = amount - params.drawnAmount;
    params.spoke2AddedShares = hub1.getSpokeAddedShares(assetId, address(spoke2));
    params.spoke2AddedAmount = hub1.convertToAddedAssets(assetId, params.spoke2AddedShares);
    params.aliceBalance = MAX_SUPPLY_AMOUNT + params.drawnAmount;
    params.bobBalance = MAX_SUPPLY_AMOUNT - amount;

    uint256 addShares = 1; // minimum for 1 share
    uint256 addAmount;
    for (uint256 i = 0; i < numAdds; i++) {
      addAmount = minimumAssetsPerAddedShare(hub1, assetId);

      // bob add minimal amount
      Utils.add({
        hub: hub1,
        assetId: assetId,
        caller: address(spoke1),
        amount: addAmount,
        user: bob
      });

      (uint256 drawn, ) = hub1.getAssetOwed(assetId);
      assertGt(drawn, 0);
      (drawn, ) = hub1.getSpokeOwed(assetId, address(spoke1));
      assertGt(drawn, 0);

      params.availableLiq += addAmount;
      params.assetAddedShares += addShares;
      params.assetAddedAmount = hub1.convertToAddedAssets(assetId, params.assetAddedShares);
      params.spoke1AddedShares += addShares;
      params.spoke1AddedAmount = hub1.convertToAddedAssets(assetId, params.spoke1AddedShares);
      params.bobBalance -= addAmount;

      // hub
      assertGe(hub1.getAssetAddedAmount(assetId), params.assetAddedAmount, 'hub addedAmount after');
      assertGe(hub1.getAssetAddedShares(assetId), params.assetAddedShares, 'hub addedShares after');
      assertEq(hub1.getLiquidity(assetId), params.availableLiq, 'asset liquidity after');
      assertEq(
        hub1.getAsset(assetId).lastUpdateTimestamp,
        vm.getBlockTimestamp(),
        'asset lastUpdateTimestamp after'
      );
      // spoke1
      assertEq(
        hub1.getSpokeAddedAmount(assetId, address(spoke1)),
        hub1.convertToAddedAssets(assetId, params.spoke1AddedShares),
        'spoke1 addedAmount after'
      );
      assertEq(
        hub1.getSpokeAddedShares(assetId, address(spoke1)),
        params.spoke1AddedShares,
        'spoke1 addedShares after'
      );
      // spoke2
      assertEq(
        hub1.getSpokeAddedAmount(assetId, address(spoke2)),
        hub1.convertToAddedAssets(assetId, params.spoke2AddedShares),
        'spoke2 addedAmount after'
      );
      assertEq(
        hub1.getSpokeAddedShares(assetId, address(spoke2)),
        params.spoke2AddedShares,
        'spoke2 addedShares after'
      );
      // token balance
      assertEq(
        tokenList.dai.balanceOf(address(hub1)),
        params.availableLiq,
        'hub token balance after'
      );
      assertEq(tokenList.dai.balanceOf(alice), params.aliceBalance, 'alice token balance after');
      assertEq(tokenList.dai.balanceOf(bob), params.bobBalance, 'bob token balance after');

      skip(randomizer(1 days, 365 days));
    }
  }
}
