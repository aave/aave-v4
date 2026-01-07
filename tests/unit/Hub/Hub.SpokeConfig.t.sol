// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubSpokeConfigTest is HubBase {
  function setUp() public override {
    super.setUp();

    // deploy borrowable liquidity
    _addLiquidity(usdxAssetId, MAX_SUPPLY_AMOUNT);
  }

  function test_mintFeeShares_active_paused_scenarios() public {
    address feeReceiver = _getFeeReceiver(hub1, usdxAssetId);

    // set spoke to active / paused; reverts
    _accrueLiquidityFees(hub1, spoke1, usdxAssetId);
    _updateSpokePaused(hub1, usdxAssetId, feeReceiver, true);
    _updateSpokeActive(hub1, usdxAssetId, feeReceiver, true);

    vm.prank(HUB_ADMIN);
    hub1.mintFeeShares(usdxAssetId);

    // set spoke to inactive / paused; reverts
    _accrueLiquidityFees(hub1, spoke1, usdxAssetId);
    _updateSpokePaused(hub1, usdxAssetId, feeReceiver, true);
    _updateSpokeActive(hub1, usdxAssetId, feeReceiver, false);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(HUB_ADMIN);
    hub1.mintFeeShares(usdxAssetId);

    // set spoke to active / not paused; succeeds
    _accrueLiquidityFees(hub1, spoke1, usdxAssetId);
    _updateSpokePaused(hub1, usdxAssetId, feeReceiver, false);
    _updateSpokeActive(hub1, usdxAssetId, feeReceiver, true);

    vm.prank(HUB_ADMIN);
    hub1.mintFeeShares(usdxAssetId);

    // set spoke to inactive / not paused; reverts
    _accrueLiquidityFees(hub1, spoke1, usdxAssetId);
    _updateSpokePaused(hub1, usdxAssetId, feeReceiver, false);
    _updateSpokeActive(hub1, usdxAssetId, feeReceiver, false);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(HUB_ADMIN);
    hub1.mintFeeShares(usdxAssetId);
  }

  function test_add_active_paused_scenarios() public {
    // set spoke to active / paused; reverts
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), true);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true);

    vm.expectRevert(IHub.SpokePaused.selector);
    vm.prank(address(spoke1));
    hub1.add(usdxAssetId, 1);

    // set spoke to inactive / paused; reverts
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), true);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.add(usdxAssetId, 1);

    // set spoke to active / not paused; succeeds
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), false);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true);

    Utils.add(hub1, usdxAssetId, address(spoke1), 1, alice);

    // set spoke to inactive / not paused; reverts
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), false);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.add(usdxAssetId, 1);
  }

  function test_remove_active_paused_scenarios() public {
    Utils.add(hub1, usdxAssetId, address(spoke1), 100, alice);

    // set spoke to active / paused; reverts
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), true);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true);

    vm.expectRevert(IHub.SpokePaused.selector);
    vm.prank(address(spoke1));
    hub1.remove(usdxAssetId, 1, alice);

    // set spoke to inactive / paused; reverts
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), true);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.remove(usdxAssetId, 1, alice);

    // set spoke to active / not paused; succeeds
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), false);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true);

    Utils.remove(hub1, usdxAssetId, address(spoke1), 1, alice);

    // set spoke to inactive / not paused; reverts
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), false);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.remove(usdxAssetId, 1, alice);
  }

  function test_draw_active_paused_scenarios() public {
    // set spoke to active / paused; reverts
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), true);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true);

    vm.expectRevert(IHub.SpokePaused.selector);
    vm.prank(address(spoke1));
    hub1.draw(usdxAssetId, 1, alice);

    // set spoke to inactive / paused; reverts
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), true);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.draw(usdxAssetId, 1, alice);

    // set spoke to active / not paused; succeeds
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), false);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true);

    Utils.draw(hub1, usdxAssetId, address(spoke1), alice, 1);

    // set spoke to inactive / not paused; reverts
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), false);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.draw(usdxAssetId, 1, alice);
  }

  function test_restore_active_paused_scenarios() public {
    Utils.draw(hub1, usdxAssetId, address(spoke1), alice, 100);

    // set spoke to active / paused; reverts
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), true);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true);

    vm.expectRevert(IHub.SpokePaused.selector);
    vm.prank(address(spoke1));
    hub1.restore(usdxAssetId, 1, ZERO_PREMIUM_DELTA);

    // set spoke to inactive / paused; reverts
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), true);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.restore(usdxAssetId, 1, ZERO_PREMIUM_DELTA);

    // set spoke to active / not paused; succeeds
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), false);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true);

    Utils.restoreDrawn(hub1, usdxAssetId, address(spoke1), 1, alice);

    // set spoke to inactive / not paused; reverts
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), false);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.restore(usdxAssetId, 1, ZERO_PREMIUM_DELTA);
  }

  function test_reportDeficit_active_paused_scenarios() public {
    // draw usdx liquidity to be restored
    _drawLiquidity({
      assetId: usdxAssetId,
      amount: 1,
      withPremium: true,
      skipTime: true,
      spoke: address(spoke1)
    });

    // set spoke to active / paused; succeeds
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), true);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true);

    vm.prank(address(spoke1));
    hub1.reportDeficit(usdxAssetId, 1, ZERO_PREMIUM_DELTA);

    // set spoke to inactive and paused; reverts
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), true);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.reportDeficit(usdxAssetId, 1, ZERO_PREMIUM_DELTA);

    // set spoke to active and not paused; succeeds
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), false);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true);

    vm.prank(address(spoke1));
    hub1.reportDeficit(usdxAssetId, 1, ZERO_PREMIUM_DELTA);

    // set spoke to inactive and not paused; reverts
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), false);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.reportDeficit(usdxAssetId, 1, ZERO_PREMIUM_DELTA);
  }

  function test_eliminateDeficit_active_paused_scenarios() public {
    address coveredSpoke = address(spoke1);
    address callerSpoke = address(spoke2);

    // create reported deficit on spoke1
    _createReportedDeficit(hub1, coveredSpoke, usdxAssetId);
    Utils.add(hub1, usdxAssetId, callerSpoke, 1e18, alice);

    // covered spoke status does not matter
    _updateSpokePaused(hub1, usdxAssetId, coveredSpoke, true);
    _updateSpokeActive(hub1, usdxAssetId, coveredSpoke, false);

    // set caller spoke to active / not paused; succeeds
    _updateSpokePaused(hub1, usdxAssetId, callerSpoke, true);
    _updateSpokeActive(hub1, usdxAssetId, callerSpoke, true);

    vm.prank(callerSpoke);
    hub1.eliminateDeficit(usdxAssetId, 1, coveredSpoke);

    // set spoke to inactive / paused; succeeds
    _updateSpokePaused(hub1, usdxAssetId, callerSpoke, true);
    _updateSpokeActive(hub1, usdxAssetId, callerSpoke, false);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(callerSpoke);
    hub1.eliminateDeficit(usdxAssetId, 1, coveredSpoke);

    // set spoke to active / not paused; succeeds
    _updateSpokePaused(hub1, usdxAssetId, callerSpoke, false);
    _updateSpokeActive(hub1, usdxAssetId, callerSpoke, true);

    vm.prank(callerSpoke);
    hub1.eliminateDeficit(usdxAssetId, 1, coveredSpoke);

    // set spoke to inactive / not paused; reverts
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), false);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.eliminateDeficit(usdxAssetId, 1, coveredSpoke);
  }

  function test_refreshPremium_active_paused_scenarios() public {
    // set spoke to active / paused; reverts
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), true);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true);

    vm.prank(address(spoke1));
    hub1.refreshPremium(usdxAssetId, ZERO_PREMIUM_DELTA);

    // set spoke to inactive / paused; reverts
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), true);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.refreshPremium(usdxAssetId, ZERO_PREMIUM_DELTA);

    // set spoke to active / not paused; succeeds
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), false);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true);

    vm.prank(address(spoke1));
    hub1.refreshPremium(usdxAssetId, ZERO_PREMIUM_DELTA);

    // set spoke to inactive / not paused; reverts
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), false);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.refreshPremium(usdxAssetId, ZERO_PREMIUM_DELTA);
  }

  function test_payFeeShares_active_paused_scenarios() public {
    address feeReceiver = _getFeeReceiver(hub1, usdxAssetId);
    Utils.add(hub1, usdxAssetId, address(spoke1), 1e18, alice);

    // set fee receiver to inactive / paused; does not matter
    _updateSpokePaused(hub1, usdxAssetId, feeReceiver, true);
    _updateSpokeActive(hub1, usdxAssetId, feeReceiver, false);

    // set spoke to active / paused; reverts
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), true);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true);

    vm.expectRevert(IHub.SpokePaused.selector);
    vm.prank(address(spoke1));
    hub1.payFeeShares(usdxAssetId, 1);

    // set spoke to inactive / paused; reverts
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), true);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.payFeeShares(usdxAssetId, 1);

    // set spoke to active / not paused; succeeds
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), false);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true);

    vm.prank(address(spoke1));
    hub1.payFeeShares(usdxAssetId, 1);

    // set spoke to inactive / not paused; reverts
    _updateSpokePaused(hub1, usdxAssetId, address(spoke1), false);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.payFeeShares(usdxAssetId, 1);
  }

  function test_transferShares_fuzz_active_paused_scenarios(
    bool senderPaused,
    bool receiverPaused,
    bool senderActive,
    bool receiverActive
  ) public {
    address sender = address(spoke1);
    address receiver = address(spoke2);
    Utils.add(hub1, usdxAssetId, sender, 1e18, alice);

    // set sender
    _updateSpokePaused(hub1, usdxAssetId, sender, senderPaused);
    _updateSpokeActive(hub1, usdxAssetId, sender, senderActive);
    // set receiver
    _updateSpokePaused(hub1, usdxAssetId, receiver, receiverPaused);
    _updateSpokeActive(hub1, usdxAssetId, receiver, receiverActive);

    if (!senderActive || !receiverActive) {
      vm.expectRevert(IHub.SpokeNotActive.selector);
    } else if (senderPaused || receiverPaused) {
      vm.expectRevert(IHub.SpokePaused.selector);
    }
    vm.prank(sender);
    hub1.transferShares(usdxAssetId, 1, receiver);
  }

  function _accrueLiquidityFees(IHub hub, ISpoke spoke, uint256 assetId) internal {
    Utils.add(hub, wbtcAssetId, address(spoke), 1e18, alice);
    Utils.draw(hub, assetId, address(spoke), alice, 1e18);

    skip(365 days);
    Utils.add(hub, assetId, address(spoke), 1e18, alice);

    assertGt(hub.getAsset(assetId).realizedFees, 0);
  }

  function _createReportedDeficit(IHub hub, address spoke, uint256 assetId) internal {
    Utils.add(hub, wbtcAssetId, spoke, 1e18, alice);
    Utils.draw(hub, assetId, spoke, alice, 1e18);

    skip(365 days);
    Utils.add(hub, assetId, spoke, 1e18, alice);

    vm.prank(spoke);
    hub.reportDeficit(assetId, 1e18, ZERO_PREMIUM_DELTA);

    assertGt(hub.getAssetDeficitRay(assetId), 0);
  }
}
