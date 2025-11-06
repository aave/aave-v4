// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubRescueTest is HubBase {
  address rescueSpoke;

  function setUp() public override {
    super.setUp();

    rescueSpoke = makeAddr('rescueSpoke');

    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      paused: false,
      addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK
    });
    vm.prank(ADMIN);
    hub1.addSpoke(daiAssetId, rescueSpoke, spokeConfig);
  }

  /// @dev Recovery of funds directly transferred to the hub & ensure asset liquidity tracking is not impacted.
  function test_rescuey_scenario_fuzz(uint256 lostAmount) public {
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
    uint256 prevRecoveryBalance = underlying.balanceOf(rescueSpoke);

    (uint256 rescueAmount, uint256 rescueAddedShares, uint256 rescueWithdrawnShares) = _rescue(
      hub1,
      rescueSpoke,
      daiAssetId,
      underlying
    );

    uint256 finalHubBalance = underlying.balanceOf(address(hub1));
    uint256 finalRecoveryBalance = underlying.balanceOf(rescueSpoke);

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
    assertEq(finalRecoveryBalance, prevRecoveryBalance + lostAmount, 'rescuey balance');
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

  function _rescue(
    IHub hub,
    address rescueSpoke,
    uint256 assetId,
    IERC20 underlying
  ) internal returns (uint256, uint256, uint256) {
    uint256 currentBalance = underlying.balanceOf(address(hub));
    uint256 recordedLiquidity = hub.getAssetLiquidity(assetId);
    uint256 rescueAmount = currentBalance - recordedLiquidity;

    vm.startPrank(rescueSpoke);
    uint256 rescueedAddedShares = hub.add(assetId, rescueAmount);
    uint256 rescueedWithdrawnShares = hub.remove(assetId, rescueAmount, rescueSpoke);
    vm.stopPrank();

    return (rescueAmount, rescueedAddedShares, rescueedWithdrawnShares);
  }
}
