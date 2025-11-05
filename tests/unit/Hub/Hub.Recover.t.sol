// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubRecoverTest is HubBase {
  address recoverSpoke;

  function setUp() public override {
    super.setUp();

    recoverSpoke = makeAddr('recoverSpoke');

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

  /// @dev Recovery of funds directly transferred to the hub including interest accrual
  function test_recovery_fuzz_with_interest(uint256 lostAmount, uint256 skipTime) public {
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

    vm.assume(lostAmount > _calculateBurntInterest(hub1, daiAssetId));

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

    uint256 burntInterest = _calculateBurntInterest(hub1, daiAssetId);
    lostAmount -= burntInterest;

    // check amounts & balances
    assertApproxEqAbs(
      recoverAmount,
      lostAmount,
      hub1.previewAddByShares(daiAssetId, 1),
      'recover amount'
    ); // can differ by up to 1 share worth of assets due to precision loss from remove donation
    assertEq(recoverAddedShares, recoverWithdrawnShares, 'recover shares');
    assertEq(finalHubBalance, prevHubBalance - recoverAmount, 'hub balance');
    assertEq(finalRecoveryBalance, prevRecoveryBalance + recoverAmount, 'recovery balance');
    // note: cannot assert hub liquidity as due to rounding, there is dust remaining that cannot be withdrawn (<1 share)
    // assertHubLiquidity(hub1, daiAssetId, 'hub1.recover');
  }

  /// @dev Another spoke cannot improperly recover liquidity fee without transferring underlying tokens
  function test_cannot_steal_liquidity_fee_reverts_with_InvalidAmountReceived() public {
    IERC20 underlying = IERC20(hub1.getAsset(daiAssetId).underlying);

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
    vm.expectRevert(IHub.InvalidAmountReceived.selector);

    vm.prank(address(recoverSpoke));
    hub1.add(daiAssetId, liquidityFee);
  }

  function _recover(
    IHub hub,
    address recoverSpoke,
    uint256 assetId,
    IERC20 underlying
  ) internal returns (uint256, uint256, uint256) {
    uint256 recordedLiquidity = hub.getAssetLiquidity(assetId);
    uint256 recoverAmount = underlying.balanceOf(address(hub)) -
      recordedLiquidity -
      _calculateBurntInterest(hub, assetId);
    vm.startPrank(recoverSpoke);
    uint256 recoveredAddedShares = hub.add(assetId, recoverAmount);
    recoverAmount = hub1.getSpokeAddedAssets(assetId, recoverSpoke);
    uint256 recoveredWithdrawnShares = hub.remove(assetId, recoverAmount, recoverSpoke);
    vm.stopPrank();

    return (recoverAmount, recoveredAddedShares, recoveredWithdrawnShares);
  }
}
