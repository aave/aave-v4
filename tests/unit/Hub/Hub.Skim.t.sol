// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubSkimTest is HubBase {
  using SharesMath for uint256;
  using SafeCast for uint256;

  MockSkimSpoke skimSpoke;

  function setUp() public override {
    super.setUp();

    skimSpoke = new MockSkimSpoke(address(hub1));

    /// @dev add a minimum decimal asset to test add cap rounding
    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      paused: false,
      addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK
    });
    vm.startPrank(ADMIN);
    // add skim spoke
    hub1.addSpoke(wethAssetId, address(skimSpoke), spokeConfig);
    hub1.addSpoke(wbtcAssetId, address(skimSpoke), spokeConfig);
    hub1.addSpoke(daiAssetId, address(skimSpoke), spokeConfig);
    hub1.addSpoke(usdxAssetId, address(skimSpoke), spokeConfig);
    hub1.addSpoke(usdyAssetId, address(skimSpoke), spokeConfig);
    vm.stopPrank();
  }

  function test_skimAdd_fuzz_donationAfterAdd(
    uint256 assetId,
    uint256 amount,
    uint256 donationAmount
  ) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 3); // Exclude usdy & usdz
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT / 10);
    donationAmount = bound(donationAmount, 1, MAX_SUPPLY_AMOUNT / 10);

    IERC20 underlying = IERC20(hub1.getAsset(assetId).underlying);

    uint256 liquidityBefore = hub1.getAssetLiquidity(assetId);

    uint256 shares = hub1.previewAddByAssets(assetId, amount);
    uint256 skimShares = hub1.previewAddByAssets(assetId, donationAmount);

    // normal deposit
    vm.startPrank(address(spoke1));
    underlying.transferFrom(alice, address(hub1), amount);

    vm.expectEmit(address(hub1));
    emit IHubBase.Add(assetId, address(spoke1), shares, amount);

    uint256 addedShares = hub1.add(assetId, amount);
    vm.stopPrank();

    // donation : wrong transfer to hub
    vm.prank(bob);
    underlying.transfer(address(hub1), donationAmount);

    // skimming donation
    vm.expectEmit(address(hub1));
    emit IHubBase.Add(assetId, address(skimSpoke), skimShares, donationAmount);
    uint256 skimmedShares = skimSpoke.skimAdd(assetId, donationAmount);

    // hub
    assertEq(addedShares, shares);
    assertEq(skimmedShares, skimShares);
    assertEq(hub1.getAddedAssets(assetId), amount + donationAmount, 'hub asset addedAmount after');
    assertEq(hub1.getAddedShares(assetId), shares + skimShares, 'hub asset addedShares after');
    assertEq(
      hub1.getSpokeAddedAssets(assetId, address(spoke1)),
      amount,
      'hub spoke addedAmount after'
    );
    assertEq(
      hub1.getSpokeAddedShares(assetId, address(spoke1)),
      shares,
      'hub spoke addedShares after'
    );
    assertEq(
      hub1.getSpokeAddedAssets(assetId, address(skimSpoke)),
      donationAmount,
      'hub skimSpoke addedAmount after'
    );
    assertEq(
      hub1.getSpokeAddedShares(assetId, address(skimSpoke)),
      skimShares,
      'hub skimSpoke addedShares after'
    );
    assertEq(
      hub1.getAsset(assetId).liquidity,
      liquidityBefore + amount + donationAmount,
      'hub available liquidity after'
    );
    _assertBorrowRateSynced(hub1, assetId, 'hub1.skimAdd');
    _assertHubLiquidity(hub1, assetId, 'hub1.skimAdd');
    // token balance
    assertEq(
      underlying.balanceOf(address(hub1)),
      amount + donationAmount,
      'hub token balance post-add'
    );
  }

  function test_skimAdd_fuzz_donationBeforeAdd(
    uint256 assetId,
    uint256 amount,
    uint256 donationAmount
  ) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 3); // Exclude usdy & usdz
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT / 10);
    donationAmount = bound(donationAmount, 1, MAX_SUPPLY_AMOUNT / 10);

    IERC20 underlying = IERC20(hub1.getAsset(assetId).underlying);

    uint256 liquidityBefore = hub1.getAssetLiquidity(assetId);

    uint256 shares = hub1.previewAddByAssets(assetId, amount);
    uint256 skimShares = hub1.previewAddByAssets(assetId, donationAmount);

    // donation : wrong transfer to hub
    vm.prank(bob);
    underlying.transfer(address(hub1), donationAmount);

    // normal deposit
    vm.startPrank(address(spoke1));
    underlying.transferFrom(alice, address(hub1), amount);

    vm.expectEmit(address(hub1));
    emit IHubBase.Add(assetId, address(spoke1), shares, amount);

    uint256 addedShares = hub1.add(assetId, amount);
    vm.stopPrank();

    // skimming donation
    vm.expectEmit(address(hub1));
    emit IHubBase.Add(assetId, address(skimSpoke), skimShares, donationAmount);
    uint256 skimmedShares = skimSpoke.skimAdd(assetId, donationAmount);

    // hub
    assertEq(addedShares, shares);
    assertEq(skimmedShares, skimShares);
    assertEq(hub1.getAddedAssets(assetId), amount + donationAmount, 'hub asset addedAmount after');
    assertEq(hub1.getAddedShares(assetId), shares + skimShares, 'hub asset addedShares after');
    assertEq(
      hub1.getSpokeAddedAssets(assetId, address(spoke1)),
      amount,
      'hub spoke addedAmount after'
    );
    assertEq(
      hub1.getSpokeAddedShares(assetId, address(spoke1)),
      shares,
      'hub spoke addedShares after'
    );
    assertEq(
      hub1.getSpokeAddedAssets(assetId, address(skimSpoke)),
      donationAmount,
      'hub skimSpoke addedAmount after'
    );
    assertEq(
      hub1.getSpokeAddedShares(assetId, address(skimSpoke)),
      skimShares,
      'hub skimSpoke addedShares after'
    );
    assertEq(
      hub1.getAsset(assetId).liquidity,
      liquidityBefore + amount + donationAmount,
      'hub available liquidity after'
    );
    _assertBorrowRateSynced(hub1, assetId, 'hub1.skimAdd');
    _assertHubLiquidity(hub1, assetId, 'hub1.skimAdd');
    // token balance
    assertEq(
      underlying.balanceOf(address(hub1)),
      amount + donationAmount,
      'hub token balance post-add'
    );
  }

  function test_skimAdd_fuzz_wrongSpokeTransfer(
    uint256 assetId,
    uint256 amount,
    uint256 donationAmount
  ) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 3); // Exclude usdy & usdz
    amount = bound(amount, 1e4, MAX_SUPPLY_AMOUNT / 10);
    donationAmount = bound(donationAmount, 1, amount / 2);
    uint256 addAmount = amount - donationAmount;

    IERC20 underlying = IERC20(hub1.getAsset(assetId).underlying);

    uint256 liquidityBefore = hub1.getAssetLiquidity(assetId);

    uint256 shares = hub1.previewAddByAssets(assetId, addAmount);
    uint256 skimShares = hub1.previewAddByAssets(assetId, donationAmount);

    // normal deposit but with wrong transfer to Hub
    vm.startPrank(address(spoke1));
    underlying.transferFrom(alice, address(hub1), amount);

    vm.expectEmit(address(hub1));
    emit IHubBase.Add(assetId, address(spoke1), shares, addAmount);

    uint256 addedShares = hub1.add(assetId, addAmount);
    vm.stopPrank();

    // skimming donation
    vm.expectEmit(address(hub1));
    emit IHubBase.Add(assetId, address(skimSpoke), skimShares, donationAmount);
    uint256 skimmedShares = skimSpoke.skimAdd(assetId, donationAmount);

    // hub
    assertEq(addedShares, shares);
    assertEq(skimmedShares, skimShares);
    assertEq(hub1.getAddedAssets(assetId), amount, 'hub asset addedAmount after');
    assertEq(hub1.getAddedShares(assetId), shares + skimShares, 'hub asset addedShares after');
    assertEq(
      hub1.getSpokeAddedAssets(assetId, address(spoke1)),
      addAmount,
      'hub spoke addedAmount after'
    );
    assertEq(
      hub1.getSpokeAddedShares(assetId, address(spoke1)),
      shares,
      'hub spoke addedShares after'
    );
    assertEq(
      hub1.getSpokeAddedAssets(assetId, address(skimSpoke)),
      donationAmount,
      'hub skimSpoke addedAmount after'
    );
    assertEq(
      hub1.getSpokeAddedShares(assetId, address(skimSpoke)),
      skimShares,
      'hub skimSpoke addedShares after'
    );
    assertEq(
      hub1.getAsset(assetId).liquidity,
      liquidityBefore + amount,
      'hub available liquidity after'
    );
    _assertBorrowRateSynced(hub1, assetId, 'hub1.skimAdd');
    _assertHubLiquidity(hub1, assetId, 'hub1.skimAdd');
    // token balance
    assertEq(underlying.balanceOf(address(hub1)), amount, 'hub token balance post-add');
  }

  function test_skimRestore_fuzz_liquidityDonation(
    uint256 assetId,
    uint256 drawAmount,
    uint256 donationAmount
  ) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 3); // Exclude usdy & usdz
    drawAmount = bound(drawAmount, 1, MAX_SUPPLY_AMOUNT / 10);
    donationAmount = bound(donationAmount, 1, drawAmount);
    _addAndDrawLiquidity({
      hub: hub1,
      assetId: assetId,
      addUser: bob,
      addAmount: drawAmount * 2,
      addSpoke: address(spoke1),
      drawUser: alice,
      drawSpoke: address(skimSpoke),
      drawAmount: drawAmount,
      skipTime: 0
    });

    IERC20 underlying = IERC20(hub1.getAsset(assetId).underlying);

    (uint256 drawn, uint256 premium) = hub1.getSpokeOwed(assetId, address(skimSpoke));
    uint256 liquidityBefore = hub1.getAssetLiquidity(assetId);
    uint256 hubBalanceBefore = underlying.balanceOf(address(hub1));

    // no premium accrued
    assertEq(premium, 0);

    // send donation to hub
    vm.prank(alice);
    underlying.transfer(address(hub1), donationAmount);

    uint256 skimShares = hub1.previewRestoreByAssets(assetId, donationAmount);

    vm.expectEmit(address(hub1));
    emit IHubBase.Restore(
      assetId,
      address(skimSpoke),
      skimShares,
      ZERO_PREMIUM_DELTA,
      donationAmount,
      0
    );
    uint256 skimmedShares = skimSpoke.skimRestore(assetId, donationAmount);

    (uint256 newDrawn, ) = hub1.getSpokeOwed(assetId, address(skimSpoke));

    // hub
    assertEq(skimmedShares, skimShares);
    assertEq(newDrawn, drawn - donationAmount, 'hub drawn asset after');
    assertEq(
      hub1.getAssetLiquidity(assetId),
      liquidityBefore + donationAmount,
      'hub available liquidity after'
    );
    _assertBorrowRateSynced(hub1, assetId, 'hub1.skimRestore');
    _assertHubLiquidity(hub1, assetId, 'hub1.skimRestore');
    // token balance
    assertEq(
      underlying.balanceOf(address(hub1)),
      hubBalanceBefore + donationAmount,
      'hub token balance post-add'
    );
  }
}
