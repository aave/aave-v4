// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubAddTest is HubBase {
  address recoverSpoke;

  function setUp() public override {
    super.setUp();

    recoverSpoke = makeAddr('recoverSpoke');

    /// @dev add a minimum decimal asset to test add cap rounding
    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      paused: false,
      addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK
    });
    vm.prank(ADMIN);
    hub1.addSpoke(daiAssetId, recoverSpoke, spokeConfig);
  }

  function _recover(
    IHub hub,
    address recoverSpoke,
    uint256 assetId,
    IERC20 underlying
  ) internal returns (uint256, uint256, uint256) {
    uint256 currentBalance = underlying.balanceOf(address(hub));
    uint256 recordedLiquidity = hub.getAssetLiquidity(assetId);
    uint256 recoverAmount = currentBalance - recordedLiquidity;

    vm.startPrank(recoverSpoke);
    uint256 recoverAddedShares = hub.add(assetId, recoverAmount);
    uint256 recoverWithdrawnShares = hub.remove(assetId, recoverAmount, recoverSpoke);
    vm.stopPrank();

    return (recoverAmount, recoverAddedShares, recoverWithdrawnShares);
  }

  function test_recovery_scenario_fuzz(uint256 lostAmount) public {
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
    uint256 prevRecoveryBalance = underlying.balanceOf(recoverSpoke);

    (uint256 recoverAmount, uint256 recoverAddedShares, uint256 recoverWithdrawnShares) = _recover(
      hub1,
      recoverSpoke,
      daiAssetId,
      underlying
    );

    uint256 finalHubBalance = underlying.balanceOf(address(hub1));
    uint256 finalRecoveryBalance = underlying.balanceOf(recoverSpoke);

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
    assertEq(recoverAmount, lostAmount, 'recover amount');
    assertEq(recoverAddedShares, recoverWithdrawnShares, 'recover shares');
    assertEq(finalHubBalance, prevHubBalance - lostAmount, 'hub balance');
    assertEq(finalRecoveryBalance, prevRecoveryBalance + lostAmount, 'recovery balance');
    assertHubLiquidity(hub1, daiAssetId, 'hub1.recover');

    // remove all
    Utils.remove({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: 5e20,
      to: alice
    });
    Utils.remove({hub: hub1, assetId: daiAssetId, caller: address(spoke2), amount: 10e22, to: bob});
  }
}
