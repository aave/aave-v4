// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubRescueTest is HubBase {
  address internal _rescueSpoke;

  function setUp() public override {
    super.setUp();

    _rescueSpoke = makeAddr('rescueSpoke');

    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      paused: false,
      addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK
    });
    vm.prank(ADMIN);
    hub1.addSpoke(daiAssetId, _rescueSpoke, spokeConfig);
  }

  /// @dev Rescue of funds directly transferred to the hub & ensure asset liquidity tracking is not impacted.
  function test_rescue_scenario_fuzz(uint256 lostAmount) public {
    lostAmount = bound(lostAmount, 1, MAX_SUPPLY_AMOUNT / 10);

    IERC20 underlying = IERC20(hub1.getAsset(daiAssetId).underlying);

    deal(address(underlying), address(hub1), lostAmount);

    // spoke1, alice add dai
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: 10e20,
      user: alice
    });
    // spoke2, bob add dai
    Utils.add({hub: hub1, assetId: daiAssetId, caller: address(spoke2), amount: 7.5e22, user: bob});

    uint256 prevHubBalance = underlying.balanceOf(address(hub1));
    uint256 prevRescueBalance = underlying.balanceOf(_rescueSpoke);

    (uint256 rescueAmount, uint256 rescueAddedShares, uint256 rescueWithdrawnShares) = _rescue(
      hub1,
      _rescueSpoke,
      daiAssetId,
      underlying
    );

    uint256 finalHubBalance = underlying.balanceOf(address(hub1));
    uint256 finalRescueBalance = underlying.balanceOf(_rescueSpoke);

    // spoke1, alice remove dai
    Utils.remove({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: 5e20,
      to: alice
    });
    // spoke2, bob add dai
    Utils.add({hub: hub1, assetId: daiAssetId, caller: address(spoke2), amount: 2.5e22, user: bob});

    // check amounts & balances
    assertEq(rescueAmount, lostAmount, 'rescue amount');
    assertEq(rescueAddedShares, rescueWithdrawnShares, 'rescue shares');
    assertEq(finalHubBalance, prevHubBalance - lostAmount, 'hub balance');
    assertEq(finalRescueBalance, prevRescueBalance + lostAmount, 'rescue balance');
    _assertHubLiquidity(hub1, daiAssetId, 'hub1.rescue');

    // remove all, ensure there is enough liquidity to honor all withdrawals.
    Utils.remove({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: 5e20,
      to: alice
    });
    Utils.remove({hub: hub1, assetId: daiAssetId, caller: address(spoke2), amount: 10e22, to: bob});

    assertEq(underlying.balanceOf(address(hub1)), 0, 'final hub amount');
  }

  /// @dev Rescue of funds directly transferred to the hub including interest accrual
  function test_rescue_fuzz_with_interest(uint256 lostAmount, uint256 skipTime) public {
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME);
    lostAmount = bound(lostAmount, 1, MAX_SUPPLY_AMOUNT / 10);

    IERC20 underlying = IERC20(hub1.getAsset(daiAssetId).underlying);

    deal(address(underlying), address(hub1), lostAmount);

    // spoke1, alice add dai
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: 10e20,
      user: alice
    });
    // spoke2, bob add dai
    Utils.add({hub: hub1, assetId: daiAssetId, caller: address(spoke2), amount: 7.5e22, user: bob});
    Utils.draw({hub: hub1, assetId: daiAssetId, caller: address(spoke1), to: alice, amount: 10e20});

    skip(skipTime);

    Utils.restoreDrawn({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      drawnAmount: hub1.getSpokeTotalOwed(daiAssetId, address(spoke1)),
      restorer: alice
    });

    // remove all
    Utils.remove({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: hub1.getSpokeAddedAssets(daiAssetId, address(spoke1)),
      to: alice
    });
    Utils.remove({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: hub1.getSpokeAddedAssets(daiAssetId, address(spoke2)),
      to: alice
    });

    uint256 prevHubBalance = underlying.balanceOf(address(hub1));
    uint256 prevRescueBalance = underlying.balanceOf(_rescueSpoke);

    (uint256 rescueAmount, uint256 rescueAddedShares, uint256 rescueWithdrawnShares) = _rescue(
      hub1,
      _rescueSpoke,
      daiAssetId,
      underlying
    );

    uint256 finalHubBalance = underlying.balanceOf(address(hub1));
    uint256 finalRescueBalance = underlying.balanceOf(_rescueSpoke);

    // check amounts & balances
    assertApproxEqAbs(
      rescueAmount,
      lostAmount,
      hub1.previewAddByShares(daiAssetId, 1),
      'rescue amount'
    ); // can differ by up to 1 share worth of assets due to remove donation rounding
    assertEq(rescueAddedShares, rescueWithdrawnShares, 'rescue shares');
    assertEq(finalHubBalance, prevHubBalance - rescueAmount, 'hub balance');
    assertEq(finalRescueBalance, prevRescueBalance + rescueAmount, 'rescue balance');
    _assertHubLiquidity(hub1, daiAssetId, 'hub1.rescue');
  }

  /// @dev Another spoke cannot improperly rescue liquidity fee without transferring underlying tokens
  function test_cannot_rescue_liquidity_fee_reverts_with_InsufficientTransferred() public {
    // spoke1, alice add dai
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: 10e20,
      user: alice
    });
    // spoke2, bob add dai
    Utils.add({hub: hub1, assetId: daiAssetId, caller: address(spoke2), amount: 7.5e22, user: bob});
    Utils.draw({hub: hub1, assetId: daiAssetId, caller: address(spoke1), to: alice, amount: 10e20});

    skip(322 days);

    Utils.restoreDrawn({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      drawnAmount: hub1.getSpokeTotalOwed(daiAssetId, address(spoke1)),
      restorer: alice
    });

    uint256 liquidityFee = hub1.getAssetAccruedFees(daiAssetId);
    assertGt(liquidityFee, 0);

    // Cannot add liquidity fee amount without transferring underlying tokens
    vm.expectRevert(abi.encodeWithSelector(IHub.InsufficientTransferred.selector, liquidityFee));

    vm.prank(address(_rescueSpoke));
    hub1.add(daiAssetId, liquidityFee);

    assertEq(hub1.getAssetAccruedFees(daiAssetId), liquidityFee, 'accrued liquidity fee');
  }

  function _rescue(
    IHub hub,
    address rescueSpoke,
    uint256 assetId,
    IERC20 underlying
  ) internal returns (uint256, uint256, uint256) {
    uint256 recordedLiquidity = hub.getAssetLiquidity(assetId);
    uint256 rescueAmount = underlying.balanceOf(address(hub)) - recordedLiquidity;

    // ensure enough rescueAmount to add
    vm.assume(hub.previewAddByAssets(assetId, rescueAmount) > 0);

    vm.startPrank(rescueSpoke);
    uint256 rescuedAddedShares = hub.add(assetId, rescueAmount);
    rescueAmount = hub1.getSpokeAddedAssets(assetId, rescueSpoke);
    uint256 rescuedWithdrawnShares = hub.remove(assetId, rescueAmount, rescueSpoke);
    vm.stopPrank();

    return (rescueAmount, rescuedAddedShares, rescuedWithdrawnShares);
  }
}
